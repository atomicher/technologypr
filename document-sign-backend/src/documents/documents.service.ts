import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Document, DocumentStatus, DocumentCategory, Priority } from './entities/document.entity';
import { DocumentRecipient, RecipientStatus } from './entities/document-recipient.entity';
import { AuditService } from '../audit/audit.service';
import { UsersService } from '../users/users.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class DocumentsService {
  constructor(
    @InjectRepository(Document)
    private docRepo: Repository<Document>,
    @InjectRepository(DocumentRecipient)
    private recipientRepo: Repository<DocumentRecipient>,
    private auditService: AuditService,
    private usersService: UsersService,
    private notificationsService: NotificationsService,
  ) {}

  async create(file: Express.Multer.File, dto: any, user: any) {
    const doc = this.docRepo.create({
      title: dto.title,
      description: dto.description,
      filePath: file.filename,
      originalName: file.originalname,
      fileSize: file.size,
      category: dto.category || DocumentCategory.OTHER,
      priority: dto.priority || Priority.NORMAL,
      status: DocumentStatus.PENDING,
      created_by: user.id,
    });

    const saved = await this.docRepo.save(doc);

    // recipients: [{signerId, step}]
    const recipients = dto.recipients ? JSON.parse(dto.recipients) : [];

    for (const r of recipients) {
      const minStep = await this._getMinStep(saved.id);
      const status = r.step === 1
        ? RecipientStatus.PENDING
        : RecipientStatus.WAITING;

      const recipient = this.recipientRepo.create({
        document_id: saved.id,
        signer_id: r.signerId,
        step: r.step,
        status,
      });
      await this.recipientRepo.save(recipient);
    }
    const firstStepRecipients = recipients.filter(r => r.step === 1);

for (const r of firstStepRecipients) {
  await this.notificationsService.sendToUser(
    r.signerId,
    '📄 Новий документ на підпис',
    `"${dto.title}" очікує вашого підпису`,
    {
      documentId: saved.id,
      type: 'new_document',
    },
  );
}

    await this.auditService.log({
      userId: user.id,
      action: 'upload',
      entityType: 'document',
      entityId: saved.id,
      metadata: { title: dto.title },
    });

    return saved;
  }

  private async _getMinStep(documentId: string): Promise<number> {
    const recipients = await this.recipientRepo.find({ where: { document_id: documentId } });
    if (recipients.length === 0) return 1;
    return Math.min(...recipients.map(r => r.step));
  }

  // Вхідні — документи де я підписант і мій крок активний
  async findIncoming(userId: string) {
    return this.recipientRepo.createQueryBuilder('r')
      .leftJoinAndSelect('r.document', 'doc')
      .leftJoinAndSelect('doc.createdBy', 'creator')
      .leftJoinAndSelect('doc.recipients', 'allRecipients')
      .leftJoinAndSelect('allRecipients.signer', 'signerUser')
      .where('r.signer_id = :userId', { userId })
      .andWhere('r.status IN (:...statuses)', {
        statuses: [RecipientStatus.PENDING, RecipientStatus.SIGNED,
                   RecipientStatus.REJECTED, RecipientStatus.REVIEW],
      })
      .orderBy('r.createdAt', 'DESC')
      .getMany();
  }

  // Вихідні — документи які я створив
  async findOutgoing(userId: string) {
    return this.docRepo.createQueryBuilder('doc')
      .leftJoinAndSelect('doc.createdBy', 'creator')
      .leftJoinAndSelect('doc.recipients', 'recipients')
      .leftJoinAndSelect('recipients.signer', 'signer')
      .leftJoinAndSelect('doc.signatures', 'sig')
      .where('doc.created_by = :userId', { userId })
      .orderBy('doc.createdAt', 'DESC')
      .getMany();
  }

  async findOne(id: string, user: any) {
    const doc = await this.docRepo.findOne({
      where: { id },
      relations: ['createdBy', 'signatures', 'signatures.signedBy',
                  'recipients', 'recipients.signer'],
    });
    if (!doc) throw new NotFoundException('Документ не знайдено');

    await this.auditService.log({
      userId: user.id,
      action: 'view',
      entityType: 'document',
      entityId: id,
    });

    return doc;
  }

  async updateRecipientStatus(
    documentId: string,
    dto: { status: string; rejectionReason?: string },
    userId: string,
  ) {
    const recipient = await this.recipientRepo.findOne({
      where: { document_id: documentId, signer_id: userId },
    });

    if (!recipient) throw new ForbiddenException('Ви не є підписантом цього документа');

    recipient.status = dto.status as RecipientStatus;
    if (dto.status === RecipientStatus.REJECTED) {
      recipient.rejectionReason = dto.rejectionReason;
    }
    if (dto.status === RecipientStatus.SIGNED) {
      recipient.signedAt = new Date();
    }
    await this.recipientRepo.save(recipient);
// Сповіщення ініціатору
const doc = await this.docRepo.findOne({ where: { id: documentId } });
if (doc) {
  if (dto.status === 'signed') {
    await this.notificationsService.sendToUser(
      doc.created_by,
      '✅ Документ підписано',
      `"${doc.title}" підписано`,
      { documentId, type: 'signed' },
    );
  } else if (dto.status === 'rejected') {
    await this.notificationsService.sendToUser(
      doc.created_by,
      '❌ Документ відхилено',
      `"${doc.title}" відхилено`,
      { documentId, type: 'rejected' },
    );
  }
}
    // Перевіряємо чи всі підписали поточний крок
    await this._checkAndActivateNextStep(documentId);

    await this.auditService.log({
      userId,
      action: dto.status,
      entityType: 'document',
      entityId: documentId,
    });

    return { success: true };
  }

  private async _checkAndActivateNextStep(documentId: string) {
    const allRecipients = await this.recipientRepo.find({
      where: { document_id: documentId },
      order: { step: 'ASC' },
    });

    // Знаходимо поточний активний крок
    const activeRecipients = allRecipients.filter(
      r => r.status === RecipientStatus.PENDING || r.status === RecipientStatus.REVIEW
    );

    if (activeRecipients.length === 0) {
      // Всі підписали поточний крок — активуємо наступний
      const waitingRecipients = allRecipients.filter(
        r => r.status === RecipientStatus.WAITING
      );

      if (waitingRecipients.length > 0) {
        const nextStep = Math.min(...waitingRecipients.map(r => r.step));
        for (const r of waitingRecipients.filter(w => w.step === nextStep)) {
          r.status = RecipientStatus.PENDING;
          await this.recipientRepo.save(r);
        }
      } else {
        // Всі кроки завершено
        const rejected = allRecipients.some(r => r.status === RecipientStatus.REJECTED);
        const doc = await this.docRepo.findOne({ where: { id: documentId } });
        if (doc) {
          doc.status = rejected ? DocumentStatus.REJECTED : DocumentStatus.SIGNED;
          if (!rejected) doc.signedAt = new Date();
          await this.docRepo.save(doc);
        }
      }
    }
  }

  async getFile(id: string, user: any) {
    return this.findOne(id, user);
  }

  async getAllUsers() {
    return this.usersService.findAll();
  }
}
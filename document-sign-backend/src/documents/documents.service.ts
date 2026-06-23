import {
  Injectable, NotFoundException, ForbiddenException
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Document, DocumentStatus, DocumentCategory, Priority } from './entities/document.entity';
import { DocumentRecipient, RecipientStatus } from './entities/document-recipient.entity';
import { UserRole } from '../users/entities/user.entity';
import { AuditService } from '../audit/audit.service';
import { UsersService } from '../users/users.service';

@Injectable()
export class DocumentsService {
  constructor(
    @InjectRepository(Document)
    private docRepo: Repository<Document>,
    @InjectRepository(DocumentRecipient)
    private recipientRepo: Repository<DocumentRecipient>,
    private auditService: AuditService,
    private usersService: UsersService,
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
      tags: dto.tags,
      status: DocumentStatus.PENDING,
      created_by: user.id,
    });

    const saved = await this.docRepo.save(doc);

    // Створюємо записи для кожного директора
    const directorIds = dto.directorIds
      ? JSON.parse(dto.directorIds)
      : [];

    if (directorIds.length > 0) {
      for (const directorId of directorIds) {
        const recipient = this.recipientRepo.create({
          document_id: saved.id,
          director_id: directorId,
          status: RecipientStatus.PENDING,
        });
        await this.recipientRepo.save(recipient);
      }
    }

    await this.auditService.log({
      userId: user.id,
      action: 'upload',
      entityType: 'document',
      entityId: saved.id,
      metadata: { title: dto.title, category: dto.category, directors: directorIds },
    });

    return saved;
  }

  async findAll(user: any, query: any) {
    const qb = this.docRepo.createQueryBuilder('doc')
      .leftJoinAndSelect('doc.createdBy', 'creator')
      .leftJoinAndSelect('doc.signatures', 'sig')
      .leftJoinAndSelect('doc.recipients', 'recipient')
      .leftJoinAndSelect('recipient.director', 'director')
      .orderBy('doc.createdAt', 'DESC');

    if (user.role === UserRole.DIRECTOR) {
      qb.where('recipient.director_id = :userId', { userId: user.id });
    } else if (user.role === UserRole.SECRETARY) {
      qb.where('doc.created_by = :userId', { userId: user.id });
    }

    if (query.category) qb.andWhere('doc.category = :cat', { cat: query.category });
    if (query.status) qb.andWhere('recipient.status = :status', { status: query.status });

    return qb.getMany();
  }

  async findOne(id: string, user: any) {
    const doc = await this.docRepo.findOne({
      where: { id },
      relations: ['createdBy', 'signatures', 'signatures.signedBy', 'recipients', 'recipients.director'],
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

  async updateStatus(id: string, dto: any, user: any) {
    if (user.role !== UserRole.DIRECTOR) {
      throw new ForbiddenException('Тільки директор може змінювати статус');
    }

    // Оновлюємо статус для конкретного директора
    const recipient = await this.recipientRepo.findOne({
      where: { document_id: id, director_id: user.id },
    });

    if (recipient) {
      recipient.status = dto.status;
      if (dto.status === RecipientStatus.REJECTED) {
        recipient.rejectionReason = dto.rejectionReason;
      }
      if (dto.status === RecipientStatus.SIGNED) {
        recipient.signedAt = new Date();
      }
      await this.recipientRepo.save(recipient);
    }

    // Якщо всі директори підписали — документ вважається підписаним
    const allRecipients = await this.recipientRepo.find({ where: { document_id: id } });
    const allSigned = allRecipients.every(r => r.status === RecipientStatus.SIGNED);

    const doc = await this.docRepo.findOne({ where: { id } });
    if (doc) {
      if (allSigned) {
        doc.status = DocumentStatus.SIGNED;
        doc.signedAt = new Date();
      } else if (dto.status === RecipientStatus.REJECTED) {
        doc.status = DocumentStatus.REJECTED;
      } else {
        doc.status = DocumentStatus.PENDING;
      }
      doc.reviewed_by = user.id;
      await this.docRepo.save(doc);
    }

    await this.auditService.log({
      userId: user.id,
      action: dto.status === 'signed' ? 'sign' : dto.status === 'rejected' ? 'reject' : 'review',
      entityType: 'document',
      entityId: id,
      metadata: { newStatus: dto.status },
    });

    return { success: true };
  }

  async getDirectors() {
    return this.usersService.findByRole(UserRole.DIRECTOR);
  }
}
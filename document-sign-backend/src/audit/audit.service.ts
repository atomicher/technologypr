import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuditLog } from './entities/audit-log.entity';

@Injectable()
export class AuditService {
  constructor(
    @InjectRepository(AuditLog)
    private auditRepo: Repository<AuditLog>,
  ) {}

  async log(data: {
    userId: string;
    action: string;
    entityType?: string;
    entityId?: string;
    metadata?: any;
    ipAddress?: string;
  }) {
    const log = this.auditRepo.create({
      user_id: data.userId,
      action: data.action,
      entityType: data.entityType,
      entityId: data.entityId,
      metadata: data.metadata,
      ipAddress: data.ipAddress,
    });
    return this.auditRepo.save(log);
  }
  async findAll(userId?: string, limit = 50) {
  const qb = this.auditRepo.createQueryBuilder('log')
    .leftJoinAndSelect('log.user', 'user')
    .orderBy('log.createdAt', 'DESC')
    .take(limit);

  if (userId) {
    qb.where('log.user_id = :userId', { userId });
  }

  return qb.getMany();
}
}
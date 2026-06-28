import {
  Entity, PrimaryGeneratedColumn, Column, ManyToOne,
  OneToMany, CreateDateColumn, UpdateDateColumn, JoinColumn
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Signature } from '../../signatures/entities/signature.entity';
import { DocumentRecipient } from './document-recipient.entity';

export enum DocumentStatus {
  DRAFT    = 'draft',
  PENDING  = 'pending',
  SIGNED   = 'signed',
  REJECTED = 'rejected',
}

export enum DocumentCategory {
  ACCOUNTING  = 'accounting',
  LEGAL       = 'legal',
  INTERNAL    = 'internal',
  FINANCIAL   = 'financial',
  HR          = 'hr',
  CONTRACTS   = 'contracts',
  REPORTS     = 'reports',
  INVOICES    = 'invoices',
  ORDERS      = 'orders',
  OTHER       = 'other',
}

export enum Priority {
  NORMAL    = 'normal',
  IMPORTANT = 'important',
  URGENT    = 'urgent',
}

@Entity('documents')
export class Document {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  title: string;

  @Column({ nullable: true })
  description: string;

  @Column()
  filePath: string;

  @Column()
  originalName: string;

  @Column({ type: 'bigint' })
  fileSize: number;

  @Column({ type: 'enum', enum: DocumentCategory, default: DocumentCategory.OTHER })
  category: DocumentCategory;

  @Column({ type: 'enum', enum: DocumentStatus, default: DocumentStatus.PENDING })
  status: DocumentStatus;

  @Column({ type: 'enum', enum: Priority, default: Priority.NORMAL })
  priority: Priority;

  @Column({ nullable: true })
  tags: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'created_by' })
  createdBy: User;

  @Column()
  created_by: string;

  @Column({ nullable: true })
  rejectionReason: string;

  @OneToMany(() => Signature, (sig) => sig.document)
  signatures: Signature[];

  @OneToMany(() => DocumentRecipient, (r) => r.document)
  recipients: DocumentRecipient[];

  @Column({ nullable: true })
  signedAt: Date;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
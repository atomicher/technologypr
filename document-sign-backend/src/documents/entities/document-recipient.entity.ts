import {
  Entity, PrimaryGeneratedColumn, Column,
  ManyToOne, CreateDateColumn, UpdateDateColumn, JoinColumn
} from 'typeorm';
import { Document } from './document.entity';
import { User } from '../../users/entities/user.entity';

export enum RecipientStatus {
  WAITING  = 'waiting',
  PENDING  = 'pending',
  SIGNED   = 'signed',
  REJECTED = 'rejected',
  REVIEW   = 'review',
}

@Entity('document_recipients')
export class DocumentRecipient {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Document)
  @JoinColumn({ name: 'document_id' })
  document: Document;

  @Column()
  document_id: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'signer_id' })
  signer: User;

  @Column()
  signer_id: string;

  @Column({ default: 1 })
  step: number;

  @Column({ type: 'enum', enum: RecipientStatus, default: RecipientStatus.WAITING })
  status: RecipientStatus;

  @Column({ nullable: true })
  rejectionReason: string;

  @Column({ nullable: true })
  signedAt: Date;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
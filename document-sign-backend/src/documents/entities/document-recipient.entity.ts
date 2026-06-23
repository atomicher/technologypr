import {
  Entity, PrimaryGeneratedColumn, Column,
  ManyToOne, CreateDateColumn, UpdateDateColumn, JoinColumn
} from 'typeorm';
import { Document } from './document.entity';
import { User } from '../../users/entities/user.entity';

export enum RecipientStatus {
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
  @JoinColumn({ name: 'director_id' })
  director: User;

  @Column()
  director_id: string;

  @Column({ type: 'enum', enum: RecipientStatus, default: RecipientStatus.PENDING })
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
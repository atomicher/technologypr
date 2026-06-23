import {
  Entity, PrimaryGeneratedColumn, Column,
  ManyToOne, CreateDateColumn, JoinColumn
} from 'typeorm';
import { Document } from '../../documents/entities/document.entity';
import { User } from '../../users/entities/user.entity';

@Entity('signatures')
export class Signature {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Document, (doc) => doc.signatures)
  @JoinColumn({ name: 'document_id' })
  document: Document;

  @Column()
  document_id: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'signed_by' })
  signedBy: User;

  @Column()
  signed_by: string;

  @Column({ type: 'text' })
  signatureData: string;    // base64 КЕП підпису

  @Column({ nullable: true })
  certificateInfo: string;  // JSON з інформацією про сертифікат

  @Column()
  signatureType: string;    // 'CAdES', 'XAdES', 'PAdES'

  @Column({ nullable: true })
  ipAddress: string;

  @CreateDateColumn()
  createdAt: Date;
}
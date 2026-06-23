import { IsEnum, IsOptional, IsString } from 'class-validator';
import { DocumentStatus } from '../entities/document.entity';

export class UpdateDocumentStatusDto {
  @IsEnum(DocumentStatus)
  status: DocumentStatus;

  @IsOptional()
  @IsString()
  rejectionReason?: string;
}
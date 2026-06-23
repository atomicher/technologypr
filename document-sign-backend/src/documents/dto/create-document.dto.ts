import { IsString, IsOptional, IsEnum } from 'class-validator';
import { DocumentCategory, Priority } from '../entities/document.entity';

export class CreateDocumentDto {
  @IsString()
  title: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsEnum(DocumentCategory)
  category?: DocumentCategory;

  @IsOptional()
  @IsEnum(Priority)
  priority?: Priority;

  @IsOptional()
  @IsString()
  tags?: string;
}
import {
  Controller, Get, Post, Patch, Body, Param,
  UseGuards, Request, UseInterceptors, UploadedFile,
  Query, Res
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { v4 as uuidv4 } from 'uuid';
import { DocumentsService } from './documents.service';
import { CreateDocumentDto } from './dto/create-document.dto';
import { UpdateDocumentStatusDto } from './dto/update-status.dto';

@Controller('documents')
@UseGuards(AuthGuard('jwt'))
export class DocumentsController {
  constructor(private docsService: DocumentsService) {}

  // Секретар завантажує документ
  @Post('upload')
  @UseInterceptors(FileInterceptor('file', {
    storage: diskStorage({
      destination: process.env.UPLOAD_PATH || './uploads',
      filename: (req, file, cb) => {
        const uniqueName = `${uuidv4()}${extname(file.originalname)}`;
        cb(null, uniqueName);
      },
    }),
    fileFilter: (req, file, cb) => {
      const allowedMimes = [
        'application/pdf',
        'application/octet-stream',
        'application/x-pdf',
        'binary/octet-stream',
      ];
      const isPdf = allowedMimes.includes(file.mimetype) || 
                    file.originalname.toLowerCase().endsWith('.pdf');
      if (!isPdf) {
        cb(new Error('Дозволено лише PDF файли'), false);
      } else {
        cb(null, true);
      }
    },
    limits: { fileSize: 50 * 1024 * 1024 }, // 50MB
  }))
  uploadDocument(
    @UploadedFile() file: Express.Multer.File,
    @Body() dto: CreateDocumentDto,
    @Request() req,
  ) {
    return this.docsService.create(file, dto, req.user);
  }

  // Отримання списку директорів (МАЄ БУТИ ДО :id)
  @Get('directors')
  getDirectors() {
    return this.docsService.getDirectors();
  }

  // Список документів (директор бачить тільки PENDING/REVIEW)
  @Get()
  getDocuments(@Request() req, @Query() query: any) {
    return this.docsService.findAll(req.user, query);
  }

  // Один документ
  @Get(':id')
  getDocument(@Param('id') id: string, @Request() req) {
    return this.docsService.findOne(id, req.user);
  }

  @Get(':id/file')
  async getFile(@Param('id') id: string, @Request() req, @Res() res: any) {
    const doc = await this.docsService.findOne(id, req.user);
    const filePath = join(process.env.UPLOAD_PATH || './uploads', doc.filePath);
    res.sendFile(filePath, { root: '.' });
  }

  @Get(':id/signed-file')
  async getSignedFile(@Param('id') id: string, @Request() req, @Res() res: any) {
    const doc = await this.docsService.findOne(id, req.user);
    const signedPath = doc.filePath.replace('.pdf', '_signed.pdf');
    const filePath = join(process.env.UPLOAD_PATH || './uploads', signedPath);
    
    if (require('fs').existsSync(filePath)) {
      res.sendFile(filePath, { root: '.' });
    } else {
      res.status(404).json({ message: 'Підписаний файл не знайдено' });
    }
  }

  // Директор змінює статус (sign/reject/review)
  @Patch(':id/status')
  updateStatus(
    @Param('id') id: string,
    @Body() dto: UpdateDocumentStatusDto,
    @Request() req,
  ) {
    return this.docsService.updateStatus(id, dto, req.user);
  }
}
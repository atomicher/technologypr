import {
  Controller, Get, Post, Patch, Body, Param,
  UseGuards, Request, UseInterceptors, UploadedFile, Res
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { v4 as uuidv4 } from 'uuid';
import { DocumentsService } from './documents.service';

@Controller('documents')
@UseGuards(AuthGuard('jwt'))
export class DocumentsController {
  constructor(private docsService: DocumentsService) {}

  @Post('upload')
  @UseInterceptors(FileInterceptor('file', {
    storage: diskStorage({
      destination: process.env.UPLOAD_PATH || './uploads',
      filename: (req, file, cb) => {
        cb(null, `${uuidv4()}${extname(file.originalname)}`);
      },
    }),
    fileFilter: (req, file, cb) => {
      const allowedMimes = ['application/pdf', 'application/octet-stream',
                            'application/x-pdf', 'binary/octet-stream'];
      const isPdf = allowedMimes.includes(file.mimetype) ||
                    file.originalname.toLowerCase().endsWith('.pdf');
      cb(isPdf ? null : new Error('Дозволено лише PDF'), isPdf);
    },
    limits: { fileSize: 50 * 1024 * 1024 },
  }))
  uploadDocument(
    @UploadedFile() file: Express.Multer.File,
    @Body() dto: any,
    @Request() req,
  ) {
    return this.docsService.create(file, dto, req.user);
  }

  // Вхідні документи
  @Get('incoming')
  getIncoming(@Request() req) {
    return this.docsService.findIncoming(req.user.id);
  }

  // Вихідні документи
  @Get('outgoing')
  getOutgoing(@Request() req) {
    return this.docsService.findOutgoing(req.user.id);
  }

  // Всі співробітники для вибору підписантів
  @Get('users')
  getAllUsers() {
    return this.docsService.getAllUsers();
  }

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

  @Patch(':id/sign')
  updateStatus(
    @Param('id') id: string,
    @Body() dto: any,
    @Request() req,
  ) {
    return this.docsService.updateRecipientStatus(id, dto, req.user.id);
  }
}
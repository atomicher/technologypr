import {
  Controller, Post, Body, Param, Get, Delete, Patch,
  UseGuards, Request, UseInterceptors, UploadedFile,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { v4 as uuidv4 } from 'uuid';
import { SignaturesService } from './signatures.service';
import * as path from 'path';

@Controller('signatures')
@UseGuards(AuthGuard('jwt'))
export class SignaturesController {
  constructor(private sigService: SignaturesService) {}

  // Завантажити новий ключ
  @Post('upload-key')
@UseInterceptors(FileInterceptor('key', {
  storage: diskStorage({
    destination: './keys',
    filename: (req, file, cb) => cb(null, `${uuidv4()}_temp.p12`),
  }),
}))
async uploadKey(
  @UploadedFile() file: Express.Multer.File,
  @Body() body: any,
  @Request() req,
) {
  return this.sigService.uploadKey(
    req.user.id,
    file.path,
    file.originalname,
    body.password,
  );
}

  // Список ключів користувача
  @Get('keys')
  getKeys(@Request() req) {
    return this.sigService.getUserKeys(req.user.id);
  }

  // Перевірка чи є ключі
  @Get('check-key')
  checkKey(@Request() req) {
    return this.sigService.checkKey(req.user.id);
  }

  // Встановити ключ за замовчуванням
  @Patch('keys/:id/default')
  setDefault(@Param('id') id: string, @Request() req) {
    return this.sigService.setDefaultKey(id, req.user.id);
  }

  // Видалити ключ
  @Delete('keys/:id')
  deleteKey(@Param('id') id: string, @Request() req) {
    return this.sigService.deleteKey(id, req.user.id);
  }

  // Підписати документ
  @Post(':documentId/sign')
  async signDocument(
    @Param('documentId') documentId: string,
    @Body() body: { password: string; keyId: string; pdfPath: string },
    @Request() req,
  ) {
    return this.sigService.signDocument(
      documentId,
      req.user.id,
      path.join('./uploads', body.pdfPath),
      body.keyId,
      body.password,
    );
  }

  // Підписи документа
  @Get(':documentId')
  getSignatures(@Param('documentId') documentId: string) {
    return this.sigService.getSignatures(documentId);
  }
}
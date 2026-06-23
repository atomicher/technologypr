import {
  Controller, Post, Body, Param,
  UseGuards, Request, UseInterceptors,
  UploadedFile, Get, NotFoundException,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { SignaturesService } from './signatures.service';
import * as path from 'path';

@Controller('signatures')
@UseGuards(AuthGuard('jwt'))
export class SignaturesController {
  constructor(private sigService: SignaturesService) {}

  // Завантаження p12 ключа
  @Post('upload-key')
  @UseInterceptors(FileInterceptor('key', {
    storage: diskStorage({
      destination: './keys',
      filename: (req, file, cb) => {
        const userId = (req as any).user.id;
        cb(null, `${userId}.p12`);
      },
    }),
  }))
  uploadKey(@UploadedFile() file: Express.Multer.File, @Request() req) {
    return { message: 'Ключ завантажено', userId: req.user.id };
  }
@Get('check-key')
checkKey(@Request() req) {
  const p12Path = path.join('./keys', `${req.user.id}.p12`);
  const exists = require('fs').existsSync(p12Path);
  if (!exists) throw new NotFoundException('Ключ не знайдено');
  return { message: 'Ключ є' };
}
  // Підписання документа
  @Post(':documentId/sign')
  async signDocument(
    @Param('documentId') documentId: string,
    @Body() body: { password: string; pdfPath: string },
    @Request() req,
  ) {
    const p12Path = path.join('./keys', `${req.user.id}.p12`);
    const pdfPath = path.join('./uploads', body.pdfPath);

    return this.sigService.signDocument(
      documentId,
      req.user.id,
      pdfPath,
      p12Path,
      body.password,
    );
  }

  // Отримати підписи документа
  @Get(':documentId')
  getSignatures(@Param('documentId') documentId: string) {
    return this.sigService.getSignatures(documentId);
  }
}
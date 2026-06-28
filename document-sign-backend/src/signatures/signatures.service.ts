import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Signature } from './entities/signature.entity';
import { UserKey } from './entities/user-key.entity';
import * as forge from 'node-forge';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class SignaturesService {
  constructor(
    @InjectRepository(Signature)
    private sigRepo: Repository<Signature>,
    @InjectRepository(UserKey)
    private keyRepo: Repository<UserKey>,
  ) {}

  async uploadKey(userId: string, filePath: string, originalName: string, password: string) {
  // Перевіряємо пароль
  try {
    const p12Buffer = fs.readFileSync(filePath);
    const p12Asn1 = forge.asn1.fromDer(p12Buffer.toString('binary'));
    forge.pkcs12.pkcs12FromAsn1(p12Asn1, password);
  } catch (e) {
    fs.unlinkSync(filePath);
    throw new BadRequestException('Невірний пароль або пошкоджений файл ключа');
  }

  const keyName = originalName.replace(/\.[^/.]+$/, '');
  const destPath = path.join('./keys', `${userId}_${Date.now()}.p12`);

  if (!fs.existsSync('./keys')) fs.mkdirSync('./keys');
  fs.copyFileSync(filePath, destPath);
  fs.unlinkSync(filePath);

  const existingKeys = await this.keyRepo.find({ where: { user_id: userId } });
  const isDefault = existingKeys.length === 0;

  const key = this.keyRepo.create({
    user_id: userId,
    keyName,
    keyPath: destPath,
    isDefault,
  });

  return this.keyRepo.save(key);
}

  async getUserKeys(userId: string) {
    return this.keyRepo.find({
      where: { user_id: userId },
      order: { isDefault: 'DESC', createdAt: 'DESC' },
    });
  }

  async setDefaultKey(keyId: string, userId: string) {
    await this.keyRepo.update({ user_id: userId }, { isDefault: false });
    await this.keyRepo.update({ id: keyId, user_id: userId }, { isDefault: true });
    return { message: 'Ключ за замовчуванням встановлено' };
  }

  async deleteKey(keyId: string, userId: string) {
    const key = await this.keyRepo.findOne({
      where: { id: keyId, user_id: userId },
    });
    if (!key) throw new NotFoundException('Ключ не знайдено');
    if (fs.existsSync(key.keyPath)) fs.unlinkSync(key.keyPath);
    await this.keyRepo.delete(keyId);
    return { message: 'Ключ видалено' };
  }

  async signDocument(
    documentId: string,
    userId: string,
    pdfPath: string,
    keyId: string,
    p12Password: string,
  ) {
    const userKey = await this.keyRepo.findOne({
      where: { id: keyId, user_id: userId },
    });
    if (!userKey) throw new BadRequestException('Ключ не знайдено');

    return this._sign(documentId, userId, pdfPath, userKey.keyPath, p12Password);
  }

  async checkKey(userId: string) {
    const keys = await this.keyRepo.find({ where: { user_id: userId } });
    return { hasKeys: keys.length > 0, count: keys.length };
  }

  private async _sign(
    documentId: string,
    userId: string,
    pdfPath: string,
    p12Path: string,
    p12Password: string,
  ) {
    try {
      const p12Buffer = fs.readFileSync(p12Path);
      const p12Base64 = p12Buffer.toString('binary');
      const p12Asn1 = forge.asn1.fromDer(p12Base64);
      const p12 = forge.pkcs12.pkcs12FromAsn1(p12Asn1, p12Password);

      const certBags = p12.getBags({ bagType: forge.pki.oids.certBag });
      const keyBags = p12.getBags({ bagType: forge.pki.oids.pkcs8ShroudedKeyBag });

      const certBag = certBags[forge.pki.oids.certBag]?.[0];
      const keyBag = keyBags[forge.pki.oids.pkcs8ShroudedKeyBag]?.[0];

      if (!certBag?.cert || !keyBag?.key) {
        throw new BadRequestException('Невірний формат ключа або пароль');
      }

      const cert = certBag.cert;
      const privateKey = keyBag.key;

      const pdfBuffer = fs.readFileSync(pdfPath);
      const p7 = forge.pkcs7.createSignedData();
      p7.content = forge.util.createBuffer(pdfBuffer.toString('binary'));
      p7.addCertificate(cert);
      p7.addSigner({
        key: privateKey as forge.pki.rsa.PrivateKey,
        certificate: cert,
        digestAlgorithm: forge.pki.oids.sha256,
        authenticatedAttributes: [
          { type: forge.pki.oids.contentType, value: forge.pki.oids.data },
          { type: forge.pki.oids.messageDigest },
          { type: forge.pki.oids.signingTime, value: new Date().toString() },
        ],
      });
      p7.sign();

      const signatureData = forge.util.encode64(
        forge.asn1.toDer(p7.toAsn1()).getBytes(),
      );

      const certInfo = {
        subject: cert.subject.getField('CN')?.value,
        issuer: cert.issuer.getField('CN')?.value,
        validFrom: cert.validity.notBefore,
        validTo: cert.validity.notAfter,
      };

      await this.createSignedPdf(documentId, userId, pdfPath, p12Path, p12Password);

      const signature = this.sigRepo.create({
        document_id: documentId,
        signed_by: userId,
        signatureData,
        certificateInfo: JSON.stringify(certInfo),
        signatureType: 'CAdES',
      });

      return this.sigRepo.save(signature);
    } catch (error) {
      if (error instanceof BadRequestException) throw error;
      throw new BadRequestException('Помилка підписання: ' + (error as any).message);
    }
  }

  async createSignedPdf(
    documentId: string,
    userId: string,
    pdfPath: string,
    p12Path: string,
    p12Password: string,
  ) {
    const { PDFDocument, rgb, StandardFonts } = require('pdf-lib');
    const p12Buffer = fs.readFileSync(p12Path);
    const p12Asn1 = forge.asn1.fromDer(p12Buffer.toString('binary'));
    const p12 = forge.pkcs12.pkcs12FromAsn1(p12Asn1, p12Password);
    const certBags = p12.getBags({ bagType: forge.pki.oids.certBag });
    const certBag = certBags[forge.pki.oids.certBag]?.[0];
    if (!certBag?.cert) throw new BadRequestException('Невірний ключ або пароль');

    const cert = certBag.cert;
    const subjectName = cert.subject.getField('CN')?.value || 'Unknown';
    const validTo = cert.validity.notAfter.toLocaleDateString('uk-UA');
    const signDate = new Date().toLocaleString('uk-UA');

    const pdfBytes = fs.readFileSync(pdfPath);
    const pdfDoc = await PDFDocument.load(pdfBytes);
    const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
    const pages = pdfDoc.getPages();
    const lastPage = pages[pages.length - 1];
    const { width } = lastPage.getSize();

    lastPage.drawRectangle({
      x: 30, y: 30, width: width - 60, height: 80,
      borderColor: rgb(0, 0.47, 0.84), borderWidth: 1.5,
      color: rgb(0.95, 0.97, 1),
    });
    lastPage.drawText('QUALIFIED ELECTRONIC SIGNATURE (KEP)', {
      x: 40, y: 95, size: 9, font, color: rgb(0, 0.47, 0.84),
    });
    lastPage.drawText(`Signer: ${subjectName}`, {
      x: 40, y: 78, size: 8, font, color: rgb(0.2, 0.2, 0.2),
    });
    lastPage.drawText(`Sign date: ${signDate}`, {
      x: 40, y: 63, size: 8, font, color: rgb(0.2, 0.2, 0.2),
    });
    lastPage.drawText(`Certificate valid to: ${validTo}`, {
      x: 40, y: 48, size: 8, font, color: rgb(0.2, 0.2, 0.2),
    });
    lastPage.drawText(`Document ID: ${documentId}`, {
      x: 40, y: 33, size: 7, font, color: rgb(0.5, 0.5, 0.5),
    });

    const signedPdfBytes = await pdfDoc.save();
    const signedPath = pdfPath.replace('.pdf', '_signed.pdf');
    fs.writeFileSync(signedPath, signedPdfBytes);
    return signedPath;
  }

  async getSignatures(documentId: string) {
    return this.sigRepo.find({
      where: { document_id: documentId },
      relations: ['signedBy'],
    });
  }
}
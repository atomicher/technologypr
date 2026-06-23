import { Injectable, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Signature } from './entities/signature.entity';
import * as forge from 'node-forge';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class SignaturesService {
  constructor(
    @InjectRepository(Signature)
    private sigRepo: Repository<Signature>,
  ) {}

  async signDocument(
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
      serialNumber: cert.serialNumber,
    };

    // Створюємо підписаний PDF зі штампом
    const signedPdfPath = await this.createSignedPdf(
      documentId, userId, pdfPath, p12Path, p12Password
    );

    const signature = this.sigRepo.create({
      document_id: documentId,
      signed_by: userId,
      signatureData: signatureData,
      certificateInfo: JSON.stringify(certInfo),
      signatureType: 'PAdES',
    });

    const saved = await this.sigRepo.save(signature);
    return { ...saved, signedPdfPath: path.basename(signedPdfPath) };

  } catch (error) {
    if (error instanceof BadRequestException) throw error;
    throw new BadRequestException('Помилка підписання: ' + (error as any).message);
  }
}

  async getSignatures(documentId: string) {
    return this.sigRepo.find({
      where: { document_id: documentId },
      relations: ['signedBy'],
    });
  }

  async uploadP12(userId: string, filePath: string) {
    // Зберігаємо шлях до p12 файлу для користувача
    const userKeyPath = path.join('./keys', `${userId}.p12`);
    if (!fs.existsSync('./keys')) fs.mkdirSync('./keys');
    fs.copyFileSync(filePath, userKeyPath);
    return { message: 'Ключ завантажено успішно' };
  }
async createSignedPdf(
  documentId: string,
  userId: string,
  pdfPath: string,
  p12Path: string,
  p12Password: string,
) {
  const { PDFDocument, rgb, StandardFonts } = require('pdf-lib');

  // Читаємо p12
  const p12Buffer = fs.readFileSync(p12Path);
  const p12Base64 = p12Buffer.toString('binary');
  const p12Asn1 = forge.asn1.fromDer(p12Base64);
  const p12 = forge.pkcs12.pkcs12FromAsn1(p12Asn1, p12Password);

  const certBags = p12.getBags({ bagType: forge.pki.oids.certBag });
  const certBag = certBags[forge.pki.oids.certBag]?.[0];
  if (!certBag?.cert) throw new BadRequestException('Невірний ключ або пароль');

  const cert = certBag.cert;
  const subjectName = cert.subject.getField('CN')?.value || 'Невідомо';
  const validTo = cert.validity.notAfter.toLocaleDateString('uk-UA');
  const signDate = new Date().toLocaleString('uk-UA');

  // Читаємо PDF і додаємо сторінку з підписом
  const pdfBytes = fs.readFileSync(pdfPath);
  const pdfDoc = await PDFDocument.load(pdfBytes);
  const font = await pdfDoc.embedFont(StandardFonts.Helvetica);

  // Додаємо штамп підпису на останню сторінку
  const pages = pdfDoc.getPages();
  const lastPage = pages[pages.length - 1];
  const { width } = lastPage.getSize();

  lastPage.drawRectangle({
    x: 30,
    y: 30,
    width: width - 60,
    height: 80,
    borderColor: rgb(0, 0.47, 0.84),
    borderWidth: 1.5,
    color: rgb(0.95, 0.97, 1),
  });

  lastPage.drawText('QUALIFIED ELECTRONIC SIGNATURE (KEP)', {
  x: 40,
  y: 95,
  size: 9,
  font,
  color: rgb(0, 0.47, 0.84),
});

lastPage.drawText(`Signer: ${subjectName}`, {
  x: 40,
  y: 78,
  size: 8,
  font,
  color: rgb(0.2, 0.2, 0.2),
});

lastPage.drawText(`Sign date: ${signDate}`, {
  x: 40,
  y: 63,
  size: 8,
  font,
  color: rgb(0.2, 0.2, 0.2),
});

lastPage.drawText(`Certificate valid to: ${validTo}`, {
  x: 40,
  y: 48,
  size: 8,
  font,
  color: rgb(0.2, 0.2, 0.2),
});

lastPage.drawText(`Document ID: ${documentId}`, {
  x: 40,
  y: 33,
  size: 7,
  font,
  color: rgb(0.5, 0.5, 0.5),
});

  // Зберігаємо підписаний PDF
  const signedPdfBytes = await pdfDoc.save();
  const signedPath = pdfPath.replace('.pdf', '_signed.pdf');
  fs.writeFileSync(signedPath, signedPdfBytes);

  return signedPath;
}
}
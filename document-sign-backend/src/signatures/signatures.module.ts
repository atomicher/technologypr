import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Signature } from './entities/signature.entity';
import { SignaturesService } from './signatures.service';
import { SignaturesController } from './signatures.controller';
import { MulterModule } from '@nestjs/platform-express';

@Module({
  imports: [
    TypeOrmModule.forFeature([Signature]),
    MulterModule.register({ dest: './keys' }),
  ],
  providers: [SignaturesService],
  controllers: [SignaturesController],
  exports: [SignaturesService],
})
export class SignaturesModule {}
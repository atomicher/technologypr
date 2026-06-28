import { Controller, Get, Query, UseGuards, Request } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AuditService } from './audit.service';

@Controller('audit')
@UseGuards(AuthGuard('jwt'))
export class AuditController {
  constructor(private auditService: AuditService) {}

  @Get()
  findAll(@Query('userId') userId: string, @Request() req) {
    // Адмін бачить всі, інші — тільки свої
    const targetUserId = req.user.role === 'admin' ? userId : req.user.id;
    return this.auditService.findAll(targetUserId);
  }

  @Get('my')
  findMy(@Request() req) {
    return this.auditService.findAll(req.user.id);
  }
}
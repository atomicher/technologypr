import {
  Controller, Get, Post, Patch, Delete,
  Body, Param, UseGuards,Req 
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { UsersService } from './users.service';

@Controller('users')
@UseGuards(AuthGuard('jwt'))
export class UsersController {
  constructor(private usersService: UsersService) {}

  @Get()
  findAll() {
    return this.usersService.findAll();
  }

  @Get('departments')
  getDepartments() {
    return this.usersService.getDepartments();
  }

  @Post()
create(@Body() dto: any) {
  return this.usersService.createUser({ ...dto, createdByAdmin: true });
}

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: any) {
    return this.usersService.updateUser(id, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.usersService.deleteUser(id);
  }
  @UseGuards(AuthGuard('jwt'))
@Post('fcm-token')
  updateFcmToken(@Body() dto: { token: string }, @Req() req: any) {
  return this.usersService.updateUser(req.user.id, { fcmToken: dto.token });
}
}
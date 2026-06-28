import { Controller, Post, Body, Get, Patch, UseGuards, Request } from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { AuthGuard } from '@nestjs/passport';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('register')
register(@Body() dto: any) {
  return this.authService.register(dto);
}

  @UseGuards(AuthGuard('jwt'))
  @Get('me')
  getProfile(@Request() req) {
    return this.authService.getProfile(req.user.id);
  }
  @UseGuards(AuthGuard('jwt'))
  @Patch('change-password')
  changePassword(@Body() dto: any, @Request() req) {
    return this.authService.changePassword(req.user.id, dto);
}
}
import { Injectable, UnauthorizedException, ConflictException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { UsersService } from '../users/users.service';
import { LoginDto } from './dto/login.dto';
import * as bcrypt from 'bcrypt';

@Injectable()
export class AuthService {
  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
  ) {}

  async login(dto: LoginDto) {
    const user = await this.usersService.findByEmail(dto.email);
    if (!user) throw new UnauthorizedException('Невірний email або пароль');

    const isMatch = await bcrypt.compare(dto.password, user.password);
    if (!isMatch) throw new UnauthorizedException('Невірний email або пароль');

    const payload = { sub: user.id, email: user.email, role: user.role };
    return {
  access_token: this.jwtService.sign(payload),
  user: {
    id: user.id,
    email: user.email,
    fullName: user.fullName,
    role: user.role,
    position: user.position,
    department: user.department,
    mustChangePassword: user.mustChangePassword,
  },
};
  }

async register(dto: any) {
  const existing = await this.usersService.findByEmail(dto.email);
  if (existing) throw new ConflictException('Користувач вже існує');
  return this.usersService.createUser(dto);
}

  async getProfile(userId: string) {
    return this.usersService.findById(userId);
  }
  async changePassword(userId: string, dto: { oldPassword: string; newPassword: string }) {
  const user = await this.usersService.findById(userId);
  if (!user) throw new UnauthorizedException();

  const isMatch = await bcrypt.compare(dto.oldPassword, user.password);
  if (!isMatch) throw new UnauthorizedException('Невірний поточний пароль');

  await this.usersService.updateUser(userId, {
    password: dto.newPassword,
    mustChangePassword: false,
  });

  return { message: 'Пароль змінено' };
}
}
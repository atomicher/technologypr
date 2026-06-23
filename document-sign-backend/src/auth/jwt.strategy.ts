import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { UsersService } from '../users/users.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private usersService: UsersService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: process.env.JWT_SECRET || 'super_secret_key_minimum_32_characters_here',
    });
  }

async validate(payload: any) {
  console.log('JWT payload:', payload);
  const user = await this.usersService.findById(payload.sub);
  console.log('Found user:', user);
  if (!user || !user.isActive) {
    throw new UnauthorizedException();
  }
  return user;
}
  
}
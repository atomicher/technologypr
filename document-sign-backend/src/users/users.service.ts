import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './entities/user.entity';
import * as bcrypt from 'bcrypt';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private userRepo: Repository<User>,
  ) {}

  async findByEmail(email: string): Promise<User | null> {
    return this.userRepo.findOne({ where: { email } });
  }

  async findById(id: string): Promise<User | null> {
    return this.userRepo.findOne({ where: { id } });
  }

  async createUser(data: {
    email: string;
    password: string;
    fullName: string;
    role: any;
  }) {
    const hashed = await bcrypt.hash(data.password, 10);
    const user = this.userRepo.create({ ...data, password: hashed });
    return this.userRepo.save(user);
  }
  async findByRole(role: string): Promise<User[]> {
  return this.userRepo.find({ where: { role: role as any, isActive: true } });
}
async findAll(): Promise<User[]> {
    return this.userRepo.find({ order: { createdAt: 'DESC' } });
  }

  async remove(id: string): Promise<void> {
    await this.userRepo.delete(id);
  }
}
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

  async findAll(): Promise<User[]> {
    return this.userRepo.find({
      where: { isActive: true },
      select: ['id', 'email', 'fullName', 'position', 'department', 'role'],
      order: { department: 'ASC', fullName: 'ASC' },
    });
  }

  async findByRole(role: string): Promise<User[]> {
    return this.userRepo.find({
      where: { role: role as any, isActive: true },
      select: ['id', 'email', 'fullName', 'position', 'department'],
    });
  }

  async getDepartments(): Promise<string[]> {
    const users = await this.userRepo
      .createQueryBuilder('u')
      .select('DISTINCT u.department', 'department')
      .where('u.department IS NOT NULL')
      .getRawMany();
    return users.map(u => u.department).filter(Boolean);
  }

async createUser(data: {
  email: string;
  password: string;
  fullName: string;
  role?: any;
  position?: string;
  department?: string;
  createdByAdmin?: boolean;
}) {
  const hashed = await bcrypt.hash(data.password, 10);
  const user = this.userRepo.create({
    ...data,
    password: hashed,
    mustChangePassword: data.createdByAdmin ?? false,
  });
  return this.userRepo.save(user);
}

  async updateUser(id: string, data: any) {
    const user = await this.userRepo.findOne({ where: { id } });
    if (!user) throw new NotFoundException('Користувача не знайдено');
    if (data.password) {
      data.password = await bcrypt.hash(data.password, 10);
    }
    Object.assign(user, data);
    return this.userRepo.save(user);
  }

  async deleteUser(id: string) {
    const user = await this.userRepo.findOne({ where: { id } });
    if (!user) throw new NotFoundException('Користувача не знайдено');
    user.isActive = false;
    return this.userRepo.save(user);
  }
}
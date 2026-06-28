import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../users/entities/user.entity';

// 1. Оновлені модульні імпорти Firebase
import { initializeApp, getApps, cert } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';

@Injectable()
export class NotificationsService {
  private initialized = false;

  constructor(
    @InjectRepository(User)
    private userRepo: Repository<User>,
  ) {
    this._init();
  }

  private _init() {
    try {
      // 2. Використовуємо getApps() замість admin.apps
      if (getApps().length === 0) {
        const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT;
        if (serviceAccount) {
          // 3. Використовуємо initializeApp та cert
          initializeApp({
            credential: cert(JSON.parse(serviceAccount)),
          });
          this.initialized = true;
        }
      } else {
        this.initialized = true;
      }
    } catch (e: any) {
  console.log('Firebase not configured:', e.message);
}
  }

  async sendToUser(userId: string, title: string, body: string, data?: any) {
    if (!this.initialized) return;

    try {
      const user = await this.userRepo.findOne({ where: { id: userId } });
      if (!user?.fcmToken) return;

      // 4. Використовуємо getMessaging() замість admin.messaging()
      await getMessaging().send({
        token: user.fcmToken,
        notification: { title, body },
        data: data || {},
        android: {
          notification: {
            channelId: 'docsign_channel',
            priority: 'high',
            sound: 'default',
          },
        },
      });
    } catch (e: any) {
      console.log('Push notification error:', e.message);
    }
  }

  async sendToUsers(userIds: string[], title: string, body: string, data?: any) {
    for (const userId of userIds) {
      await this.sendToUser(userId, title, body, data);
    }
  }
}
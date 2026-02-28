import { profiles } from '@prisma/client';
import { prisma } from '../db/prisma-client';

export interface CreateProfileData {
  userId: string;
  displayName: string;
  birthDate: Date;
  gender: string;
}

export class ProfileRepository {
  async findByUserId(userId: string): Promise<profiles | null> {
    return prisma.profiles.findUnique({ where: { user_id: userId } });
  }

  async create(data: CreateProfileData): Promise<profiles> {
    return prisma.profiles.create({
      data: {
        user_id: data.userId,
        display_name: data.displayName,
        birth_date: data.birthDate,
        gender: data.gender,
      },
    });
  }
}

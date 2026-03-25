import { Request, Response } from 'express';
import { prisma } from '../db/prisma-client';
import { UserRepository } from '../repositories/user-repository';

const userRepository = new UserRepository();

// Maps answer index to letter: 0=A, 1=B, 2=C, 3=D
const INDEX_TO_LETTER: Record<number, string> = { 0: 'A', 1: 'B', 2: 'C', 3: 'D' };
const NUM_QUESTIONS = 6;

// Personality type labels per letter (from the WeVibe personality doc)
const PERSONALITY_LABELS: Record<string, string> = {
  A: 'Reserved & Seeks Reserved',
  B: 'Reserved & Seeks Outgoing',
  C: 'Outgoing & Seeks Reserved',
  D: 'Outgoing & Seeks Outgoing',
};

function computePersonality(answers: number[]): {
  personality_primary: string;
  personality_secondary: string | null;
  personality_type: string;
} {
  // Count occurrences of each letter
  const counts: Record<string, number> = { A: 0, B: 0, C: 0, D: 0 };
  for (const answer of answers) {
    const letter = INDEX_TO_LETTER[answer];
    if (letter) counts[letter]++;
  }

  const maxCount = Math.max(...Object.values(counts));
  const dominant = Object.keys(counts).filter((k) => counts[k] === maxCount);

  const personality_primary = dominant[0];
  const personality_secondary = dominant.length > 1 ? dominant[1] : null;

  // Hybrid label if tie, otherwise single label
  const personality_type =
    dominant.length > 1
      ? `Hybrid (${dominant.join('/')})`
      : PERSONALITY_LABELS[personality_primary];

  return { personality_primary, personality_secondary, personality_type };
}

async function resolveUserId(firebaseUid: string): Promise<string> {
  const user = await userRepository.findByFirebaseUid(firebaseUid);
  if (!user) throw new Error('USER_NOT_FOUND');
  return user.id;
}

// POST /users/profile/personality
export const submitPersonalityTest = async (req: Request, res: Response) => {
  const firebaseUid = req.auth!.uid;
  const uid = await resolveUserId(firebaseUid);

  const { answers } = req.body;

  // Validate: must be an array of exactly NUM_QUESTIONS integers each 0-3
  if (
    !Array.isArray(answers) ||
    answers.length !== NUM_QUESTIONS ||
    !answers.every((a) => Number.isInteger(a) && a >= 0 && a <= 3)
  ) {
    return res.status(400).json({
      code: 'INVALID_ANSWERS',
      message: `answers must be an array of exactly ${NUM_QUESTIONS} integers each between 0 and 3`,
    });
  }

  const { personality_primary, personality_secondary, personality_type } =
    computePersonality(answers);

  // Update profile with computed personality fields
  await prisma.profiles.update({
    where: { user_id: uid },
    data: {
      personality_primary,
      personality_secondary,
      personality_type,
    },
  });

  // Mark personality test complete on the user record
  await prisma.users.update({
    where: { id: uid },
    data: { is_personality_test_complete: true },
  });

  return res.status(200).json({
    personality_type,
    personality_primary,
    personality_secondary,
  });
};

// GET /users/profile/personality
export const getPersonalityResult = async (req: Request, res: Response) => {
  const firebaseUid = req.auth!.uid;
  const uid = await resolveUserId(firebaseUid);

  const [user, profile] = await Promise.all([
    prisma.users.findUnique({
      where: { id: uid },
      select: { is_personality_test_complete: true },
    }),
    prisma.profiles.findUnique({
      where: { user_id: uid },
      select: {
        personality_type: true,
        personality_primary: true,
        personality_secondary: true,
      },
    }),
  ]);

  if (!profile) {
    return res.status(404).json({ code: 'PROFILE_NOT_FOUND', message: 'Profile not found' });
  }

  return res.status(200).json({
    is_personality_test_complete: user?.is_personality_test_complete ?? false,
    personality_type: profile.personality_type ?? null,
    personality_primary: profile.personality_primary ?? null,
    personality_secondary: profile.personality_secondary ?? null,
  });
};

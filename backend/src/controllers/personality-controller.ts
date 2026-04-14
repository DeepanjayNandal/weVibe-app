import { Request, Response } from 'express';
import { prisma } from '../db/prisma-client';
import { UserRepository } from '../repositories/user-repository';
import { unauthorized } from '../utils/errors';

const userRepository = new UserRepository();

// each answer index maps to a personality letter (A=0, B=1, C=2, D=3)
const INDEX_TO_LETTER: Record<number, string> = { 0: 'A', 1: 'B', 2: 'C', 3: 'D' };
const NUM_QUESTIONS = 6;

// human-readable label for each personality type
const PERSONALITY_LABELS: Record<string, string> = {
  A: 'Serene Soul',
  B: 'Empathetic Companion',
  C: 'Radiant Dreamer',
  D: 'Fierce Spark',
};

// figures out the user's personality type from their 6 answers
// if two letters tie, we call it a hybrid
function computePersonality(answers: number[]): {
  personality_primary: string;
  personality_secondary: string | null;
  personality_type: string;
} {
  // count how many times each letter appeared
  const counts: Record<string, number> = { A: 0, B: 0, C: 0, D: 0 };
  for (const answer of answers) {
    const letter = INDEX_TO_LETTER[answer];
    if (letter) counts[letter]++;
  }

  // find which letter(s) appeared the most
  const maxCount = Math.max(...Object.values(counts));
  const dominant = Object.keys(counts).filter((k) => counts[k] === maxCount);

  const personality_primary = dominant[0];
  const personality_secondary = dominant.length > 1 ? dominant[1] : null;

  // if there's a tie, label it as hybrid — otherwise use the single label
  const personality_type =
    dominant.length > 1
      ? `Hybrid (${dominant.join('/')})`
      : PERSONALITY_LABELS[personality_primary];

  return { personality_primary, personality_secondary, personality_type };
}

// helper to get our internal user id from firebase uid
async function resolveUserId(firebaseUid: string): Promise<string> {
  const user = await userRepository.findByFirebaseUid(firebaseUid);
  if (!user) unauthorized('User not found', 'USER_NOT_FOUND');
  return user.id;
}

// POST /users/profile/personality
// receives the 6 quiz answers, computes personality type, saves to db
export const submitPersonalityTest = async (req: Request, res: Response) => {
  const firebaseUid = req.auth!.uid;
  const uid = await resolveUserId(firebaseUid);

  const { answers } = req.body;

  // answers must be exactly 6 integers, each between 0 and 3
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

  // guard: profile must exist before we can save personality results
  const existingProfile = await prisma.profiles.findUnique({ where: { user_id: uid } });
  if (!existingProfile) {
    return res.status(404).json({
      code: 'PROFILE_NOT_FOUND',
      message: 'Complete your profile before taking the personality test',
    });
  }

  // save the computed personality fields to the user's profile
  await prisma.profiles.update({
    where: { user_id: uid },
    data: {
      personality_primary,
      personality_secondary,
      personality_type,
    },
  });

  // mark the personality test as done on the user record
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

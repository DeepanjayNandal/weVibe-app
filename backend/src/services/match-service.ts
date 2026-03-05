import { profiles } from '@prisma/client';
import { prisma } from '../db/prisma-client';
import {
  computePersonalityScore,
  computeInterestsScore,
  computePreferencesScore,
  normalizeWeightedSum,
  PreferenceWeights,
} from '../utils/match-utils';

export type MatchWeights = {
  personality?: number;
  interests?: number;
  preferences?: number;
  preferenceWeights?: PreferenceWeights;
};

const DEFAULT_WEIGHTS: Required<MatchWeights> = {
  personality: 0.5,
  interests: 0.2,
  preferences: 0.2,
  preferenceWeights: { drinking: 1, smoking: 1, pets: 1, chronotype: 1 },
};

export class MatchService {
  private weights: Required<MatchWeights>;

  constructor(weights?: MatchWeights) {
    this.weights = { ...DEFAULT_WEIGHTS, ...(weights || {}) } as Required<MatchWeights>;
  }

  computeCompatibility(user: Partial<profiles>, candidate: Partial<profiles>): number {
    const pScore = computePersonalityScore(user.personality_primary, candidate.personality_primary);
    const interestsA = (user as any).interests || (user.prompts ? extractInterestsFromPrompts(user.prompts as any) : undefined);
    const interestsB = (candidate as any).interests || (candidate.prompts ? extractInterestsFromPrompts(candidate.prompts as any) : undefined);
    const iScore = computeInterestsScore(interestsA, interestsB);
    const prefScore = computePreferencesScore(user, candidate, this.weights.preferenceWeights);

    const parts = [
      { weight: this.weights.personality, value: pScore },
      { weight: this.weights.interests, value: iScore },
      { weight: this.weights.preferences, value: prefScore },
    ];

    return normalizeWeightedSum(parts);
  }

  async findTopMatches(userId: string, limit = 10): Promise<Array<{ profile: profiles; score: number }>> {
    const userProfile = await prisma.profiles.findUnique({ where: { user_id: userId } });
    if (!userProfile) return [];

    const candidates = await prisma.profiles.findMany({ where: { user_id: { not: userId } } });
    const scored = candidates.map((c) => ({ profile: c, score: this.computeCompatibility(userProfile, c) }));
    scored.sort((a, b) => b.score - a.score);
    return scored.slice(0, limit);
  }
}

function extractInterestsFromPrompts(prompts: any): string[] | undefined {
  try {
    if (!prompts) return undefined;
    if (Array.isArray(prompts)) {
      // Read for stuff that can give an idea about the user's interests
      const parts: string[] = [];
      for (const p of prompts) {
        if (p && typeof p.answer === 'string') {
          parts.push(...p.answer.split(',').map((s: string) => s.trim()).filter(Boolean));
        }
      }
      return parts.length > 0 ? parts : undefined;
    }
  } catch (e) {
    return undefined;
  }
  return undefined;
}

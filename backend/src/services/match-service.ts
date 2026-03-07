import { profiles } from "@prisma/client";
import { prisma } from "../db/prisma-client";
import {
  computePersonalityScore,
  computeInterestsScore,
  computePreferencesScore,
  normalizeWeightedSum,
  hasHardStop,
  PreferenceWeights
} from "../utils/match-utils";

export type MatchWeights = {
  personality?: number;
  interests?: number;
  preferences?: number;
  preferenceWeights?: PreferenceWeights;
};

const DEFAULT_WEIGHTS: Required<MatchWeights> = {
  personality: 0.5,
  interests: 0.25,
  preferences: 0.25,
  preferenceWeights: {
    drinking: 1,
    smoking: 1,
    pets: 1,
    chronotype: 1
  }
};

export class MatchService {

  private weights: Required<MatchWeights>;

  constructor(weights?: MatchWeights) {
    this.weights = {
      ...DEFAULT_WEIGHTS,
      ...(weights || {})
    } as Required<MatchWeights>;
  }

  computeCompatibility(
    user: Partial<profiles>,
    candidate: Partial<profiles>
  ): number {

    if (!user || !candidate) return 0;

    // Hard stop incompatibility
    if (hasHardStop(user, candidate)) {
      return 0;
    }

    const personalityScore = computePersonalityScore(
      user.personality_primary,
      candidate.personality_primary
    );

    const interestsA =
      (user as any).interests ||
      (user.prompts ? extractInterestsFromPrompts(user.prompts as any) : undefined);

    const interestsB =
      (candidate as any).interests ||
      (candidate.prompts ? extractInterestsFromPrompts(candidate.prompts as any) : undefined);

    const interestsScore = computeInterestsScore(interestsA, interestsB);

    const preferenceScore = computePreferencesScore(
      user,
      candidate,
      this.weights.preferenceWeights
    );

    return normalizeWeightedSum([
      { weight: this.weights.personality, value: personalityScore },
      { weight: this.weights.interests, value: interestsScore },
      { weight: this.weights.preferences, value: preferenceScore }
    ]);
  }

  async findTopMatches(
    userId: string,
    limit = 10
  ): Promise<Array<{ profile: profiles; score: number }>> {

    const userProfile = await prisma.profiles.findUnique({
      where: { user_id: userId }
    });

    if (!userProfile) return [];

    const candidates = await prisma.profiles.findMany({
      where: { user_id: { not: userId } }
    });

    const scored = candidates.map((candidate) => ({
      profile: candidate,
      score: this.computeCompatibility(userProfile, candidate)
    }));

    scored.sort((a, b) => b.score - a.score);

    return scored.slice(0, limit);
  }

  async computeCompatibilityBetweenUsers(
    userIdA: string,
    userIdB: string
  ): Promise<number> {

    const [profileA, profileB] = await Promise.all([
      prisma.profiles.findUnique({ where: { user_id: userIdA } }),
      prisma.profiles.findUnique({ where: { user_id: userIdB } })
    ]);

    if (!profileA || !profileB) return 0;

    return this.computeCompatibility(profileA, profileB);
  }
}

//Since we dont have interest data, we extract information from the bip prompts that the user fills up in the start

function extractInterestsFromPrompts(prompts: any): string[] | undefined {

  try {

    if (!prompts) return undefined;

    if (Array.isArray(prompts)) {

      const parts: string[] = [];

      for (const p of prompts) {

        if (p && typeof p.answer === "string") {

          parts.push(
            ...p.answer
              .split(",")
              .map((s: string) => s.trim())
              .filter(Boolean)
          );

        }

      }

      return parts.length > 0 ? parts : undefined;

    }

  } catch {
    return undefined;
  }

  return undefined;
}
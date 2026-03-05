import { profiles } from "@prisma/client";

export type PreferenceWeights = {
  drinking?: number;
  smoking?: number;
  pets?: number;
  chronotype?: number;
};

type WeightedPart = {
  weight: number;
  value: number;
};

export function normalizeWeightedSum(parts: WeightedPart[]): number {
  let totalWeight = 0;
  let totalScore = 0;

  for (const p of parts) {
    totalWeight += p.weight;
    totalScore += p.weight * p.value;
  }

  if (totalWeight === 0) return 0;

  const result = totalScore / totalWeight;

  return Math.max(0, Math.min(1, result));
}

//Instant termination for incompatiblity/incorrect data
export function hasHardStop(user: Partial<profiles>, candidate: Partial<profiles>): boolean {
  if (!user || !candidate) return true;

  // Example for strong incompatibility
  if (user.lifestyle_smoking === "never" && candidate.lifestyle_smoking === "often") {
    return true;
  }

  if (user.lifestyle_drinks === "never" && candidate.lifestyle_drinks === "often") {
    return true;
  }

  return false;
}

//Personality scoring
export function computePersonalityScore(
  primary?: string | null,
  candidate?: string | null
): number {

  if (!primary || !candidate) {
    return 0.3; // reduced confidence
  }
  //same personality is a strong match
  if (primary === candidate) {
    return 1;
  }

  // default compatibility fallback
  return 0.5;
}

// Interest similarity, used jaccard similarity 
export function computeInterestsScore(
  interestsA?: string[],
  interestsB?: string[]
): number {

  if (!interestsA || !interestsB || interestsA.length === 0 || interestsB.length === 0) {
    return 0;
  }

  const setA = new Set(interestsA.map(i => i.toLowerCase()));
  const setB = new Set(interestsB.map(i => i.toLowerCase()));

  const intersection = new Set([...setA].filter(x => setB.has(x)));
  const union = new Set([...setA, ...setB]);

  return intersection.size / union.size;
}

//Preference scoring
export function computePreferencesScore(
  user: Partial<profiles>,
  candidate: Partial<profiles>,
  weights: PreferenceWeights = {}
): number {

  const prefWeights = {
    drinking: 1,
    smoking: 1,
    pets: 1,
    chronotype: 1,
    ...weights
  };

  let totalScore = 0;
  let totalWeight = 0;

  function score(a?: any, b?: any): number {
    if (!a || !b) return 0.5;
    if (a === b) return 1;
    return 0;
  }

  const prefs = [
    { weight: prefWeights.drinking, value: score(user.lifestyle_drinks, candidate.lifestyle_drinks) },
    { weight: prefWeights.smoking, value: score(user.lifestyle_smoking, candidate.lifestyle_smoking) },
    { weight: prefWeights.pets, value: score(user.lifestyle_pets, candidate.lifestyle_pets) },
    { weight: prefWeights.chronotype, value: score(user.lifestyle_sleep, candidate.lifestyle_sleep) }
  ];
  
  for (const p of prefs) {
    totalWeight += p.weight ?? 1;
    totalScore += (p.weight ?? 1) * p.value;
  }

  if (totalWeight === 0) return 0;

  return totalScore / totalWeight;
}
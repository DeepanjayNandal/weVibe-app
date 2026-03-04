import { profiles } from '@prisma/client';

export type PreferenceWeights = {
  drinking?: number;
  smoking?: number;
  pets?: number;
  chronotype?: number;
};

export const PERSON_MATRIX: Record<string, { bestBalance: string[] }> = {
  A: { bestBalance: ['B', 'C'] },
  B: { bestBalance: ['C', 'D'] },
  C: { bestBalance: ['A', 'B'] },
  D: { bestBalance: ['B', 'A'] },
};

export function computePersonalityScore(a?: string | null, b?: string | null): number {
  if (!a || !b) return 0.2;
  const A = a.toUpperCase();
  const B = b.toUpperCase();
  if (A === B) return 1.0;
  const balance = PERSON_MATRIX[A]?.bestBalance || [];
  if (balance.includes(B)) return 0.8;
  return 0.2;
}

export function computeInterestsScore(a?: string[] | null, b?: string[] | null): number {
  if (!a || !b) return 0;
  const sa = new Set(a.map((s) => s.toLowerCase()));
  const sb = new Set(b.map((s) => s.toLowerCase()));
  const intersection = [...sa].filter((x) => sb.has(x));
  const union = new Set([...sa, ...sb]);
  if (union.size === 0) return 0;
  return intersection.length / union.size;
}

function prefStrNorm(s?: string | null): string {
  return (s || '').toLowerCase();
}

function scorePreferencePair(a?: string | null, b?: string | null): number {
  const A = prefStrNorm(a);
  const B = prefStrNorm(b);
  if (!A || !B) return 0.5; // unknown/neutral
  if (A === B) return 1.0;
  // treat some fuzzy matches
  const fuzzyPairs: Array<[string, string]> = [
    ['sometimes', 'often'],
    ['sometimes', 'never'],
    ['occasionally', 'sometimes'],
  ];
  if (fuzzyPairs.some(([x, y]) => (x === A && y === B) || (x === B && y === A))) return 0.7;
  return 0.0;
}

export function computePreferencesScore(
  a?: Partial<profiles> | null,
  b?: Partial<profiles> | null,
  weights: PreferenceWeights = {},
): number {
  const w = {
    drinking: weights.drinking ?? 1,
    smoking: weights.smoking ?? 1,
    pets: weights.pets ?? 1,
    chronotype: weights.chronotype ?? 1,
  };

  const totalWeight = w.drinking + w.smoking + w.pets + w.chronotype;
  if (!a || !b) return 0;

  const s1 = scorePreferencePair(a.lifestyle_drinks, b.lifestyle_drinks) * w.drinking;
  const s2 = scorePreferencePair(a.lifestyle_smoking, b.lifestyle_smoking) * w.smoking;
  const s3 = scorePreferencePair(a.lifestyle_pets, b.lifestyle_pets) * w.pets;
  const s4 = (() => {
    const A = prefStrNorm(a.lifestyle_sleep);
    const B = prefStrNorm(b.lifestyle_sleep);
    if (!A || !B) return 0.5;
    if (A === B) return 1.0;
    // night_owl vs early_bird is less compatible
    return 0.2;
  })() * w.chronotype;

  return (s1 + s2 + s3 + s4) / totalWeight;
}

export function normalizeWeightedSum(parts: Array<{ weight: number; value: number }>): number {
  const totalWeight = parts.reduce((s, p) => s + p.weight, 0);
  if (totalWeight <= 0) return 0;
  const v = parts.reduce((s, p) => s + p.weight * p.value, 0) / totalWeight;
  return Math.max(0, Math.min(1, v));
}

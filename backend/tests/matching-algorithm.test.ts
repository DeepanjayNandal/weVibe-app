import {
  computePersonalityScore,
  computeInterestsScore,
  computePreferencesScore,
  normalizeWeightedSum,
  hasHardStop
} from '../src/utils/match-utils';
import { profiles } from '@prisma/client';

// Mock profile data for testing
const mockProfiles = {
  adventurousHiker: {
    user_id: 'user1',
    personality_primary: 'adventurous',
    lifestyle_drinks: 'sometimes' as const,
    lifestyle_smoking: 'never' as const,
    lifestyle_pets: 'want' as const,
    lifestyle_sleep: 'night_owl' as const,
    prompts: [
      { question: 'My hobbies', answer: 'hiking, camping, rock climbing' },
      { question: 'I\'m looking for', answer: 'someone active and outdoorsy' }
    ]
  } as Partial<profiles>,

  creativeReader: {
    user_id: 'user2',
    personality_primary: 'creative',
    lifestyle_drinks: 'never' as const,
    lifestyle_smoking: 'never' as const,
    lifestyle_pets: 'have' as const,
    lifestyle_sleep: 'early_bird' as const,
    prompts: [
      { question: 'My hobbies', answer: 'reading, writing, painting' },
      { question: 'I\'m looking for', answer: 'someone intellectual and artistic' }
    ]
  } as Partial<profiles>,

  adventurousTraveler: {
    user_id: 'user3',
    personality_primary: 'adventurous',
    lifestyle_drinks: 'often' as const,
    lifestyle_smoking: 'sometimes' as const,
    lifestyle_pets: 'dont_want' as const,
    lifestyle_sleep: 'night_owl' as const,
    prompts: [
      { question: 'My hobbies', answer: 'traveling, hiking, photography' },
      { question: 'I\'m looking for', answer: 'someone spontaneous and fun' }
    ]
  } as Partial<profiles>,

  incompatibleSmoker: {
    user_id: 'user4',
    personality_primary: 'creative',
    lifestyle_drinks: 'often' as const,
    lifestyle_smoking: 'often' as const,
    lifestyle_pets: 'unsure' as const,
    lifestyle_sleep: 'early_bird' as const,
    prompts: [
      { question: 'My hobbies', answer: 'partying, drinking, smoking' },
      { question: 'I\'m looking for', answer: 'someone who likes to party' }
    ]
  } as Partial<profiles>
};

describe('Matching Algorithm Unit Tests', () => {

  describe('normalizeWeightedSum', () => {
    test('should correctly combine weighted scores', () => {
      const parts = [
        { weight: 0.5, value: 1.0 },   // personality
        { weight: 0.3, value: 0.8 },   // interests
        { weight: 0.2, value: 0.6 }    // preferences
      ];

      const result = normalizeWeightedSum(parts);
      expect(result).toBeCloseTo(0.86, 2); // (0.5*1.0 + 0.3*0.8 + 0.2*0.6) / 1.0
    });

    test('should handle zero weights', () => {
      const parts = [{ weight: 0, value: 1.0 }];
      const result = normalizeWeightedSum(parts);
      expect(result).toBe(0);
    });

    test('should clamp results between 0 and 1', () => {
      const parts = [{ weight: 1, value: 1.5 }];
      const result = normalizeWeightedSum(parts);
      expect(result).toBe(1.0);
    });
  });

  describe('hasHardStop', () => {
    test('should return true for smoking incompatibility', () => {
      const result = hasHardStop(
        mockProfiles.adventurousHiker, // never smokes
        mockProfiles.incompatibleSmoker // often smokes
      );
      expect(result).toBe(true);
    });

    test('should return true for drinking incompatibility', () => {
      const result = hasHardStop(
        mockProfiles.creativeReader, // never drinks
        mockProfiles.incompatibleSmoker // often drinks
      );
      expect(result).toBe(true);
    });

    test('should return false for compatible lifestyles', () => {
      const result = hasHardStop(
        mockProfiles.adventurousHiker,
        mockProfiles.adventurousTraveler
      );
      expect(result).toBe(false);
    });

    test('should handle null profiles', () => {
      const result = hasHardStop(null as any, mockProfiles.adventurousHiker);
      expect(result).toBe(true);
    });
  });

  describe('computePersonalityScore', () => {
    test('should return 1.0 for identical personalities', () => {
      const result = computePersonalityScore('adventurous', 'adventurous');
      expect(result).toBe(1.0);
    });

    test('should return 0.5 for different personalities', () => {
      const result = computePersonalityScore('adventurous', 'creative');
      expect(result).toBe(0.5);
    });

    test('should return 0.3 for missing personality data', () => {
      const result = computePersonalityScore(null, 'adventurous');
      expect(result).toBe(0.3);
    });
  });

  describe('computeInterestsScore', () => {
    test('should return 1.0 for identical interests', () => {
      const interestsA = ['hiking', 'camping', 'reading'];
      const interestsB = ['hiking', 'camping', 'reading'];
      const result = computeInterestsScore(interestsA, interestsB);
      expect(result).toBe(1.0);
    });

    test('should calculate Jaccard similarity correctly', () => {
      const interestsA = ['hiking', 'camping', 'reading'];
      const interestsB = ['hiking', 'camping', 'cooking'];
      // Intersection: ['hiking', 'camping'] (2)
      // Union: ['hiking', 'camping', 'reading', 'cooking'] (4)
      // Jaccard: 2/4 = 0.5
      const result = computeInterestsScore(interestsA, interestsB);
      expect(result).toBe(0.5);
    });

    test('should return 0 for no overlapping interests', () => {
      const interestsA = ['hiking', 'camping'];
      const interestsB = ['reading', 'painting'];
      const result = computeInterestsScore(interestsA, interestsB);
      expect(result).toBe(0);
    });

    test('should handle empty or null interests', () => {
      const result = computeInterestsScore([], undefined);
      expect(result).toBe(0);
    });
  });

  describe('computePreferencesScore', () => {
    test('should return 1.0 for identical preferences', () => {
      const user = {
        lifestyle_drinks: 'sometimes' as const,
        lifestyle_smoking: 'never' as const,
        lifestyle_pets: 'want' as const,
        lifestyle_sleep: 'night_owl' as const
      };

      const candidate = { ...user };

      const result = computePreferencesScore(user, candidate);
      expect(result).toBe(1.0);
    });

    test('should return lower score for different preferences', () => {
      const user = {
        lifestyle_drinks: 'never' as const,
        lifestyle_smoking: 'never' as const,
        lifestyle_pets: 'want' as const,
        lifestyle_sleep: 'night_owl' as const
      };

      const candidate = {
        lifestyle_drinks: 'often' as const,
        lifestyle_smoking: 'often' as const,
        lifestyle_pets: 'dont_want' as const,
        lifestyle_sleep: 'early_bird' as const
      };

      const result = computePreferencesScore(user, candidate);
      expect(result).toBeLessThan(1.0);
      expect(result).toBeGreaterThanOrEqual(0); // Allow 0 for complete mismatches
    });

    test('should handle missing preference data', () => {
      const user = { lifestyle_drinks: 'sometimes' as const };
      const candidate = {};

      const result = computePreferencesScore(user, candidate);
      expect(result).toBe(0.5); // Default score for missing data
    });

    test('should respect custom weights', () => {
      const user = { lifestyle_drinks: 'never' as const };
      const candidate = { lifestyle_drinks: 'often' as const };

      const result = computePreferencesScore(user, candidate, {
        drinking: 2, // Higher weight for drinking
        smoking: 1,
        pets: 1,
        chronotype: 1
      });

      expect(result).toBeCloseTo(0.3, 1); // (2*0 + 1*0.5 + 1*0.5 + 1*0.5) / 5 = 1.5/5 = 0.3
    });
  });

  describe('Integration Tests - Full Algorithm', () => {
    // Mock MatchService logic without database dependencies
    function computeCompatibility(user: Partial<profiles>, candidate: Partial<profiles>): number {
      if (!user || !candidate) return 0;

      // Hard stop check
      if (hasHardStop(user, candidate)) {
        return 0;
      }

      const personalityScore = computePersonalityScore(
        user.personality_primary,
        candidate.personality_primary
      );

      // Simple interests extraction for testing - use predefined interests
      const interestsA = ['hiking', 'camping', 'reading'];
      const interestsB = ['hiking', 'traveling', 'photography'];
      const interestsScore = computeInterestsScore(interestsA, interestsB);

      const preferenceScore = computePreferencesScore(user, candidate);

      return normalizeWeightedSum([
        { weight: 0.5, value: personalityScore },
        { weight: 0.25, value: interestsScore },
        { weight: 0.25, value: preferenceScore }
      ]);
    }

    test('perfect match should score reasonably high', () => {
      const score = computeCompatibility(
        mockProfiles.adventurousHiker,
        mockProfiles.adventurousTraveler
      );
      expect(score).toBeGreaterThan(0.5); // Should be decent compatibility
      expect(score).toBeLessThanOrEqual(1.0);
    });

    test('hard stop should return 0', () => {
      const score = computeCompatibility(
        mockProfiles.adventurousHiker,
        mockProfiles.incompatibleSmoker
      );
      expect(score).toBe(0);
    });

    test('different personalities should score lower', () => {
      const samePersonalityScore = computeCompatibility(
        mockProfiles.adventurousHiker,
        mockProfiles.adventurousTraveler
      );

      const differentPersonalityScore = computeCompatibility(
        mockProfiles.adventurousHiker,
        mockProfiles.creativeReader
      );

      expect(samePersonalityScore).toBeGreaterThan(differentPersonalityScore);
    });
  });

});
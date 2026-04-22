import { prisma } from '../db/prisma-client';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { tooManyRequests } from '../utils/errors';

const DAILY_LIMIT = 5;
const COOLDOWN_SECONDS = 60;

export interface GenerateBioResult {
  bio: string;
  remainingToday: number;
}

export class BioGeneratorService {
  private readonly genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!);
  private readonly model = this.genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

  async generateAndSaveBio(userId: string): Promise<GenerateBioResult> {
    const userProfile = await prisma.profiles.findUnique({
      where: { user_id: userId },
    });

    if (!userProfile) {
      throw new Error('User profile not found');
    }

    // Determine today's date as YYYY-MM-DD in UTC
    const today = new Date().toISOString().slice(0, 10);

    // Reset daily count if the stored date is from a previous day
    const dailyCount =
      userProfile.bio_daily_reset_date === today
        ? (userProfile.bio_daily_count ?? 0)
        : 0;

    if (dailyCount >= DAILY_LIMIT) {
      return tooManyRequests(
        'Daily bio generation limit reached. Try again tomorrow.',
        'BIO_LIMIT_EXCEEDED',
      );
    }

    if (userProfile.bio_last_generated_at) {
      const secondsSince =
        (Date.now() - userProfile.bio_last_generated_at.getTime()) / 1000;
      if (secondsSince < COOLDOWN_SECONDS) {
        const waitSeconds = Math.ceil(COOLDOWN_SECONDS - secondsSince);
        return tooManyRequests(
          `Please wait ${waitSeconds}s before generating again.`,
          'BIO_COOLDOWN',
        );
      }
    }

    const userDataJson = JSON.stringify({
      firstName: userProfile.first_name,
      gender: userProfile.gender,
      careerField: userProfile.career_field,
      jobTitle: userProfile.job_title,
      personality: userProfile.personality_primary,
      interests: userProfile.interests,
      relationshipGoals: userProfile.relationship_goals,
    });

    const prompt = `
    You are a world-class dating profile copywriter. Your style is "Punchy, Minimalist, and Unexpected."
    Write a charismatic bio (under 400 characters) based on: ${userDataJson}.

    ### The "Anti-Template" Rules:
    1. VARY THE OPENING: Do not always start with "Unpopular opinion." Switch between a vivid scene, a weirdly specific fact about me, or a playful challenge.
    2. SHOW THE CONTRAST: Use my profile to find an "Odd Couple" trait (e.g., "The logic of a backend dev paired with the chaos of a downhill ski run").
    3. SPECIFICITY OVER ALL: Replace "food" with a specific dish, "AI" with a specific quirk of tech, and "fun" with a concrete moment.
    4. NO AI FILLER: Strictly ban words like "whimsical," "tapestry," "vibrant," "journey," or "delve."
    5. FORMAT: Output ONLY the bio. No intro/outro.

    ### Choose ONE of these "Vibes" randomly for this generation:
    - [The High-IQ Tease]: Smart, slightly cocky, uses technical metaphors for dating.
    - [The Cozy Tactician]: Focuses on slow moments, specific hobbies (like LEGO), and genuine observation.
    - [The Kinetic Adventurer]: High energy, focuses on movement (skiing, tennis) and quick wit.
    `;

    const result = await this.model.generateContent(prompt);
    let generatedBio = result.response.text().trim();

    if (!generatedBio) {
      throw new Error('Bio generation returned an empty response from Gemini');
    }

    if (generatedBio.length > 500) {
      generatedBio = generatedBio.substring(0, 497) + '...';
    }

    const newDailyCount = dailyCount + 1;

    await prisma.profiles.update({
      where: { user_id: userId },
      data: {
        bio: generatedBio,
        bio_last_generated_at: new Date(),
        bio_daily_count: newDailyCount,
        bio_daily_reset_date: today,
      },
    });

    return {
      bio: generatedBio,
      remainingToday: DAILY_LIMIT - newDailyCount,
    };
  }
}

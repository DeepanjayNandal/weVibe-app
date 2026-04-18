import { prisma } from '../db/prisma-client';
import { GoogleGenerativeAI } from '@google/generative-ai';

export class BioGeneratorService {
  async generateAndSaveBio(userId: string): Promise<string> {
    // 1. Fetch relevant user profile data from the database
    const userProfile = await prisma.profiles.findUnique({
      where: { user_id: userId },
    });

    if (!userProfile) {
      throw new Error('User profile not found');
    }

    // 2. Convert required data to JSON format
    const userDataJson = JSON.stringify({
      firstName: userProfile.first_name,
      gender: userProfile.gender,
      careerField: userProfile.career_field,
      jobTitle: userProfile.job_title,
      personality: userProfile.personality_primary,
      interests: userProfile.interests,
      relationshipGoals: userProfile.relationship_goals
    });

    // 3. Call LLM for generation using Gemini
    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!);
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
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
    
    const result = await model.generateContent(prompt);
    let generatedBio = result.response.text();

    // Ensure it doesn't exceed the database column limit (max 500 chars)
    if (generatedBio.length > 500) {
      generatedBio = generatedBio.substring(0, 497) + '...';
    }

    // 4. Save the generated bio back to the user's profile record
    await prisma.profiles.update({
      where: { user_id: userId },
      data: {
        bio: generatedBio,
      },
    });

    return generatedBio;
  }
}
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
    You are a world-class dating profile copywriter known for "Show, Don't Tell" storytelling. 
    Write a fun, charismatic dating bio (under 400 characters) based on this JSON: ${userDataJson}.

    ### Execution Rules:
    1. NO CLICHÉS: Avoid generic phrases like "adventure seeker," "passionate," or "partner in crime."
    2. SPECIFICITY: Instead of saying "I like food," use a specific detail from the JSON (e.g., "Obsessed with finding the perfect sourdough").
    3. HOOK: Start with a strong opening line or a playful "unpopular opinion."
    4. STRUCTURE: Use a mix of short sentences and a call-to-action or a fun question.
    5. FORMAT: Output ONLY the bio. No quotes, no intro, no "Here is your bio."
    6. Add one specific, grounded hobby or contrast to prevent the bio from sounding too abstract.
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
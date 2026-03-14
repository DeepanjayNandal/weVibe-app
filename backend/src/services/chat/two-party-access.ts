import { AppError, forbidden } from '../../utils/errors';

export type TwoPartyParticipants = {
  user_a_id: string | null;
  user_b_id: string | null;
};

export function assertTwoPartyParticipant(record: TwoPartyParticipants, userId: string): void {
  const isParticipant = record.user_a_id === userId || record.user_b_id === userId;
  if (!isParticipant) {
    forbidden('You are not allowed to access this chat', 'CHAT_FORBIDDEN');
  }
}

export function getTwoPartyParticipantIds(record: TwoPartyParticipants): { userAId: string; userBId: string } {
  if (!record.user_a_id || !record.user_b_id) {
    throw new AppError('Chat participants are incomplete', 400, 'CHAT_PARTICIPANTS_INVALID');
  }

  return {
    userAId: record.user_a_id,
    userBId: record.user_b_id,
  };
}

export function isUserAInTwoParty(record: TwoPartyParticipants, userId: string): boolean {
  const participants = getTwoPartyParticipantIds(record);
  return participants.userAId === userId;
}

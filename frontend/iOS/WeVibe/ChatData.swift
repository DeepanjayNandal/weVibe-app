//let anonymousChats: [ChatListItem] = [
//   ChatListItem(matchId: "anon-1", name: nil, avatarSystemIcon: nil,
//                lastMessage: "Sticker 😍", isMine: false, timeAgo: "23 min", unreadCount: 1, isTyping: false),
//   ChatListItem(matchId: "anon-2", name: nil, avatarSystemIcon: nil,
//                lastMessage: "", isMine: false, timeAgo: "27 min", unreadCount: 2, isTyping: true),
//   ChatListItem(matchId: "anon-3", name: nil, avatarSystemIcon: nil,
//                lastMessage: "Ok, see you then.", isMine: false, timeAgo: "33 min", unreadCount: 0, isTyping: false),
//   ChatListItem(matchId: "anon-4", name: nil, avatarSystemIcon: nil,
//                lastMessage: "Hey! What's up, long time..", isMine: true, timeAgo: "50 min", unreadCount: 0, isTyping: false),
//]

let speedDatingChats: [SpeedDatingDetail] = [
  SpeedDatingDetail(
    sessionId: "session1", status: "active", startAt: "2026-01-01T00:00:00.000Z", expiresAt: "2026-01-02T00:00:00.000Z", remainingSeconds: 3600, canOpen: true, canSendMessage: true, myMessageCount: 4, otherMessageCount: 5, messageLimit: 20, unreadCount: 1, counterpart: SpeedDatingDetail.CounterPart(userId: "userId1", firstName: "Josh", initials: "J", blurredPhotoUrl: "", photoUrl: ""), moveToPermanent: SpeedDatingDetail.MoveToPermanent(myDecision: "pending", otherDecision: "pending", requestStatus: "none", canRequest: true, canRespond: true, canSubmitFinalDecision: false)
  ),
  SpeedDatingDetail(
    sessionId: "session1", status: "active", startAt: "2026-01-01T00:00:00.000Z", expiresAt: "2026-01-02T00:00:00.000Z", remainingSeconds: 3200, canOpen: true, canSendMessage: true, myMessageCount: 1, otherMessageCount: 0, messageLimit: 20, unreadCount: 0, counterpart: SpeedDatingDetail.CounterPart(userId: "userId1", firstName: "Kevin", initials: "K", blurredPhotoUrl: "", photoUrl: ""), moveToPermanent: SpeedDatingDetail.MoveToPermanent(myDecision: "pending", otherDecision: "pending", requestStatus: "none", canRequest: true, canRespond: true, canSubmitFinalDecision: false)
  ),
  SpeedDatingDetail(
    sessionId: "session1", status: "active", startAt: "2026-01-01T00:00:00.000Z", expiresAt: "2026-01-02T00:00:00.000Z", remainingSeconds: 3600, canOpen: true, canSendMessage: true, myMessageCount: 9, otherMessageCount: 12, messageLimit: 20, unreadCount: 1, counterpart: SpeedDatingDetail.CounterPart(userId: "userId1", firstName: "Jack", initials: "JA", blurredPhotoUrl: "", photoUrl: ""), moveToPermanent: SpeedDatingDetail.MoveToPermanent(myDecision: "pending", otherDecision: "pending", requestStatus: "none", canRequest: true, canRespond: true, canSubmitFinalDecision: false)
  ),
  SpeedDatingDetail(
    sessionId: "session1", status: "active", startAt: "2026-01-01T00:00:00.000Z", expiresAt: "2026-01-02T00:00:00.000Z", remainingSeconds: 2850, canOpen: true, canSendMessage: true, myMessageCount: 0, otherMessageCount: 0, messageLimit: 20, unreadCount: 1, counterpart: SpeedDatingDetail.CounterPart(userId: "userId1", firstName: "Nick", initials: "NI", blurredPhotoUrl: "", photoUrl: ""), moveToPermanent: SpeedDatingDetail.MoveToPermanent(myDecision: "pending", otherDecision: "pending", requestStatus: "none", canRequest: true, canRespond: true, canSubmitFinalDecision: false)
  )
  
]

let activeChats: [ActiveChatDetail] = [
    ActiveChatDetail(matchId: "matchId1", status: "active", createdAt: "2026-01-01T00:00:00.000Z", lastMessageAt: "2026-01-01T00:10:00.000Z", lastMessageContent: "Do you wanna go", messageCount: 24, canOpen: true, canSendMessage: true, unreadCount: 4, counterpart: ActiveChatDetail.CounterPart(userId: "userId1", displayName: "Jonhh", photoUrl: ""))
]

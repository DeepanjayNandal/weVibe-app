struct SpeedDatingDetail: Decodable {
    
    struct CounterPart: Decodable {
        let userId: String?
        let firstName: String?
        let initials: String?
        let blurredPhotoUrl: String?
        let photoUrl: String?
    }
    
    struct MoveToPermanent: Decodable {
        let myDecision: String?
        let otherDecision: String?
        let requestStatus: String?
        let canRequest: Bool?
        let canRespond: Bool?
        let canSubmitFinalDecision: Bool?
    }

    let sessionId: String?
    let status: String?
    let startAt: String?
    let expiresAt: String?
    let remainingSeconds: Int?
    let canOpen: Bool?
    let canSendMessage: Bool?
    let myMessageCount: Int?
    let otherMessageCount: Int?
    let messageLimit: Int?
    let unreadCount: Int?
    
    let counterpart: CounterPart?
    let moveToPermanent: MoveToPermanent?
    
    }


struct ActiveChatDetail: Decodable {
    struct CounterPart: Decodable{
        let userId: String?
        let displayName: String?
        let photoUrl: String?
    }
    let matchId: String?
    let status: String?
    let createdAt: String?
    let lastMessageAt: String?
    let lastMessageContent: String?
    let messageCount: Int?
    let canOpen: Bool?
    let canSendMessage: Bool?
    let unreadCount: Int?
    let counterpart: CounterPart?
    
}

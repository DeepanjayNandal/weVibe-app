import Foundation

// MARK: - UserPhoto

struct UserPhoto: Identifiable, Decodable {
    let id: String
    let url: String
}

struct PersonalityResponse: Decodable {
    let personalityType: String
    let personalityPrimary: String
    let personalitySecondary: String?
 
    enum CodingKeys: String, CodingKey {
        case personalityType        = "personality_type"
        case personalityPrimary     = "personality_primary"
        case personalitySecondary   = "personality_secondary"
    }
}
 

private struct ErrorResponse: Decodable {
    struct ErrorBody: Decodable { let code: String }
    let error: ErrorBody
}

private struct MeResponse: Decodable {
    struct DataBody: Decodable {
        struct UserBody: Decodable {
            let onboardingComplete: Bool?
            let isBanned: Bool?
        }
        let user: UserBody
    }
    let data: DataBody
}

struct SessionStatus {
    let onboardingComplete: Bool
    let isBanned: Bool
}
struct SessionCounterpartSummary {
    let userId: String
    let firstName: String
    let nickname: String?
    let initials: String
    let blurredPhotoUrl: String?
}

struct MatchListItem {
    let matchId: String
    let status: String?
    let lastMessageAt: String?
    let lastMessageContent: String?
    let unreadCount: Int
    let counterpartDisplayName: String?
    let counterpartUserId: String?
    let counterpartPhotoUrl: String?
}

struct ListMatchesResult {
    let success: Bool
    let matches: [MatchListItem]
}
struct SessionCounterpart {
    let userId: String
    let firstName: String
    let initials: String
    let blurredPhotoUrl: String?
}
 
struct SessionResult {
    let sessionId: String?
    let sessionExpiresAt: String?
    let status: String?
    let lastMessageContent: String?
    let lastMessageAt: String?
    let isLastMessageMine: Bool
    let unreadCount: Int
    let counterpart: SessionCounterpartSummary?
}
 
struct ListSessionsDetailResult {
    let sessions: [SessionResult]
}
 
struct ListSessionsResult {
    let success: Bool
    let data: ListSessionsDetailResult?
}
 
struct SessionMoveToPermanent {
    let myDecision: String        // "pending" | "yes" | "no"
    let otherDecision: String     // "pending" | "yes" | "no"
    let requestStatus: String     // "none" | "pending" | "accepted" | "rejected"
    let canRequest: Bool
    let canRespond: Bool
    let canSubmitFinalDecision: Bool
}
 
struct SessionDetail {
    let sessionId: String
    let status: String            // "active" | "ended" | "matched"
    let startedAt: String
    let expiresAt: String
    let remainingSeconds: Int
    let canOpen: Bool
    let canSendMessage: Bool
    let unreadCount: Int
    let myMessageCount: Int
    let otherMessageCount: Int
    let messageLimit: Int
    let counterpart: SessionCounterpart
    let moveToPermanent: SessionMoveToPermanent
}
 
struct SessionDetailResult {
    let success: Bool
    let session: SessionDetail?
}

struct SendMessageResult {
    let messageId: String
    let content: String
    let senderId: String
    let createdAt: String
}
struct MessageHistoryItem {
    let messageId: String
    let content: String
    let senderId: String
    let createdAt: String
}

struct PermanentMessageItem {
    let messageId: String
    let content: String
    let senderId: String
    let createdAt: String
}

struct SendPermanentMessageResult {
    let messageId: String
    let content: String
    let senderId: String
    let createdAt: String
}

enum APIError: LocalizedError {
    case noProfile                      // 404 — user has no profile yet
    case unauthorized                   // 401
    case banned                         // 403 USER_BANNED
    case validationError([String: String]) // 422 — field-level errors from backend
    case serverError(Int)               // any other non-2xx
    case network(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .noProfile:                return "No profile found."
        case .unauthorized:             return "Session expired. Please sign in again."
        case .banned:                   return "Your account has been suspended. Please contact support."
        case .validationError(let e):   return e.values.first
        case .serverError(let c):       return "Server error (\(c)). Please try again."
        case .network(let e):           return e.localizedDescription
        case .decoding(let e):          return "Response error: \(e.localizedDescription)"
        }
    }
}

struct APIClient {

    private let base: URL = {
        guard let url = URL(string: AppConfig.apiBaseURL) else {
            fatalError("Invalid API base URL: \(AppConfig.apiBaseURL)")
        }
        return url
    }()
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        return URLSession(configuration: cfg)
    }()

    // MARK: - Auth

    /// GET /auth/me — returns session status (onboardingComplete + isBanned).
    func checkProfile(token: String) async throws -> SessionStatus {
        let req = request(path: "/auth/me", method: "GET", token: token)
        let (data, response) = try await perform(req)
        let status = response.statusCode
        if status == 200 {
            let me = try JSONDecoder().decode(MeResponse.self, from: data)
            return SessionStatus(
                onboardingComplete: me.data.user.onboardingComplete ?? false,
                isBanned: me.data.user.isBanned ?? false
            )
        }
        if status == 401 { throw APIError.unauthorized }
        throw APIError.serverError(status)
    }

    /// POST /users/profile — submits onboarding data to create the user profile.
    func submitProfile(token: String, payload: UserProfilePayload) async throws {
        var req = request(path: "/users/profile", method: "POST", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if status == 422 {
            struct ValidationResponse: Decodable { let errors: [String: String] }
            if let resp = try? JSONDecoder().decode(ValidationResponse.self, from: data) {
                throw APIError.validationError(resp.errors)
            }
            throw APIError.serverError(422)
        }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
    }

    /// POST /auth/login — creates or finds the backend user record for SSO and email login.
    /// Pass `appleAuthCode` for Apple Sign-In so the backend can exchange it for an Apple
    /// refresh token and store it for later revocation on account deletion (App Store 5.1.1).
    func loginUser(idToken: String, provider: String, appleAuthCode: String? = nil) async throws {
        var req = URLRequest(url: base.appendingPathComponent("/auth/login"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: String] = ["provider": provider, "idToken": idToken]
        if let code = appleAuthCode, !code.isEmpty {
            body["appleAuthCode"] = code
            body["appleBundleId"] = Bundle.main.bundleIdentifier ?? ""
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if status == 403 { throw APIError.banned }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
    }

    /// POST /auth/register — creates the backend user record after Firebase registration.
    /// Silently ignores 409 (already registered — safe to retry).
    func registerUser(idToken: String, provider: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("/auth/register"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["provider": provider, "idToken": idToken]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await perform(req)
        let status = response.statusCode
        if status == 409 { return }
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
    }

    /// PATCH /users/fcm-token — stores the FCM push token on the backend for this user.
    func updateFCMToken(token: String, fcmToken: String) async throws {
        var req = request(path: "/users/fcm-token", method: "PATCH", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["fcmToken": fcmToken])
        let (_, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
    }

    // MARK: - Profile

    /// GET /users/profile — fetches the full user profile for the profile tab.
    func getProfile(token: String) async throws -> UserProfileResponse {
        let req = request(path: "/users/profile", method: "GET", token: token)
        let (data, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
        do {
            return try JSONDecoder().decode(UserProfileResponse.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// PATCH /users/profile — updates profile fields. Only sent fields are updated.
    func updateProfile(token: String, payload: ProfileUpdatePayload) async throws {
        var req = request(path: "/users/profile", method: "PATCH", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(payload)
        let (_, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
    }

    /// PATCH /users/profile/location — background location sync after significant movement.
    func updateLocation(token: String, latitude: Double, longitude: Double, city: String, state: String, zip: String) async throws {
        var req = request(path: "/users/profile/location", method: "PATCH", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude,
            "location_city": city,
            "location_state": state,
            "location_zip": zip
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
    }

    // MARK: - Photos

    struct PhotoUploadURLResult {
        let photoId: String
        let uploadURL: URL
    }

    /// POST /users/profile/photos/upload-url — returns a signed PUT URL for direct GCS upload.
    func requestPhotoUploadURL(token: String, mimeType: String, sizeBytes: Int) async throws -> PhotoUploadURLResult {
        var req = request(path: "/users/profile/photos/upload-url", method: "POST", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["mimeType": mimeType, "sizeBytes": sizeBytes]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
        struct Resp: Decodable { let photoId: String; let uploadURL: String }
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        guard let url = URL(string: resp.uploadURL) else { throw APIError.serverError(0) }
        return PhotoUploadURLResult(photoId: resp.photoId, uploadURL: url)
    }

    /// PUT <signedURL> — uploads raw JPEG bytes directly to GCS. No auth header (credentials are in the URL).
    func uploadPhotoData(_ data: Data, to signedURL: URL) async throws {
        var req = URLRequest(url: signedURL)
        req.httpMethod = "PUT"
        req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60
        req.httpBody = data
        let uploadSession = URLSession(configuration: .default)
        let (_, urlResponse) = try await uploadSession.data(for: req)
        guard let http = urlResponse as? HTTPURLResponse else {
            throw APIError.network(URLError(.badServerResponse))
        }
        if !(200..<300).contains(http.statusCode) { throw APIError.serverError(http.statusCode) }
    }

    /// POST /users/profile/photos/finalize — confirms the upload and writes the photo record to the DB.
    func finalizePhotoUpload(token: String, photoId: String, order: Int) async throws -> UserPhoto {
        var req = request(path: "/users/profile/photos/finalize", method: "POST", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["photoId": photoId, "order": order]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
        return try JSONDecoder().decode(UserPhoto.self, from: data)
    }

    /// DELETE /users/profile/photos/:photoId — removes photo from storage and DB.
    func deletePhoto(token: String, photoId: String) async throws {
        let req = request(path: "/users/profile/photos/\(photoId)", method: "DELETE", token: token)
        let (_, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if status == 204 || (200..<300).contains(status) { return }
        throw APIError.serverError(status)
    }

    /// PATCH /users/profile/photos/reorder — updates the display order of photos.
    func reorderPhotos(token: String, orders: [(photoId: String, order: Int)]) async throws {
        var req = request(path: "/users/profile/photos/reorder", method: "PATCH", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = orders.map { ["photoId": $0.photoId, "order": $0.order] as [String: Any] }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
    }
    
    // MARK: - Personality Test
    
    /// POST /users/profile/personality - update the personality test data of user
    func updatePersonalityData(token: String, answers: [Int]) async throws -> PersonalityResponse {
     
        guard answers.count == 6, answers.allSatisfy({ (0...3).contains($0) }) else {
            throw APIError.serverError(400)
        }
     
        var req = request(path: "/users/profile/personality", method: "POST", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
     
        let bodyObject: [String: Any] = ["answers": answers]
        req.httpBody = try JSONSerialization.data(withJSONObject: bodyObject)
     
        let (data, response) = try await perform(req)
        let status = response.statusCode
     
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
     
        do {
            let resp = try JSONDecoder().decode(PersonalityResponse.self, from: data)
            return resp
        } catch {
            throw APIError.decoding(error)
        }
    }

    // MARK: - Matchmaking

    struct JoinQueueResult {
        let state: String        // "waiting" or "matched"
        let sessionId: String?
    }

    /// POST /matching/queue/join — joins the speed dating queue.
    /// Returns immediately with state "matched" (sessionId present) or "waiting" (no match yet).
    func joinQueue(token: String) async throws -> JoinQueueResult {
        let req = request(path: "/matching/queue/join", method: "POST", token: token)
        let (data, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
        struct Resp: Decodable {
            struct DataBody: Decodable {
                let state: String
                let sessionId: String?
            }
            let data: DataBody
        }
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        return JoinQueueResult(state: resp.data.state, sessionId: resp.data.sessionId)
    }

    /// POST /matching/queue/leave — removes the user from the queue.
    /// Safe to call when not in queue (404 treated as success).
    func leaveQueue(token: String) async throws {
        let req = request(path: "/matching/queue/leave", method: "POST", token: token)
        let (_, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if status == 404 { return }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
    }
    
    
    /// GET /matching/sessions - get all the speed dating sessions
    /// Returns all the chat sessions that user are matching too
    func getAllSpeedDatingSessions(token: String) async throws -> ListSessionsResult {
           let req = request(path: "/matching/sessions", method: "GET", token: token)
           let (data, response) = try await perform(req)
           let status = response.statusCode
           if status == 401 { throw APIError.unauthorized }
           if !(200..<300).contains(status) { throw APIError.serverError(status) }
    
           struct Resp: Decodable {
               struct DataBody: Decodable {
                   struct Session: Decodable {
                       struct Counterpart: Decodable {
                           let userId: String?
                           let firstName: String?
                           let nickname: String?
                           let initials: String?
                           let blurredPhotoUrl: String?
                       }
                       let sessionId: String?
                       let sessionExpiresAt: String?
                       let status: String?
                       let lastMessageContent: String?
                       let lastMessageAt: String?
                       let isLastMessageMine: Bool?
                       let unreadCount: Int?
                       let counterpart: Counterpart?
                   }
                   let sessions: [Session]
               }
               let success: Bool
               let data: DataBody?
           }
    
           let resp = try JSONDecoder().decode(Resp.self, from: data)
    
           let sessions: [SessionResult] = (resp.data?.sessions ?? []).map { s in
               SessionResult(
                   sessionId:          s.sessionId,
                   sessionExpiresAt:   s.sessionExpiresAt,
                   status:             s.status,
                   lastMessageContent: s.lastMessageContent,
                   lastMessageAt:      s.lastMessageAt,
                   isLastMessageMine:  s.isLastMessageMine ?? false,
                   unreadCount:        s.unreadCount ?? 0,
                   counterpart: s.counterpart.map {
                       SessionCounterpartSummary(
                           userId:          $0.userId ?? "",
                           firstName:       $0.firstName ?? "",
                           nickname:        $0.nickname,
                           initials:        $0.initials ?? "??",
                           blurredPhotoUrl: $0.blurredPhotoUrl
                       )
                   }
               )
           }
    
           return ListSessionsResult(
               success: resp.success,
               data: ListSessionsDetailResult(sessions: sessions)
           )
       }
    
    /// GET /matching/sessions/sessionId - get the speed dating sessions detail
    /// Returns speed dating session detail
    
    func getSpeedDatingSession(token: String, sessionId: String) async throws -> SessionDetailResult {
          let req = request(path: "/matching/sessions/\(sessionId)", method: "GET", token: token)
   
          let (data, response) = try await perform(req)
          let status = response.statusCode
   
          if status == 401 { throw APIError.unauthorized }
          if status == 404 { throw APIError.noProfile }
          if !(200..<300).contains(status) { throw APIError.serverError(status) }
   
          struct Resp: Decodable {
              struct DataBody: Decodable {
                  let session: RawSession
              }
              struct RawSession: Decodable {
                  let sessionId: String
                  let status: String
                  let startedAt: String
                  let expiresAt: String
                  let remainingSeconds: Int
                  let canOpen: Bool
                  let canSendMessage: Bool
                  let unreadCount: Int
                  let myMessageCount: Int
                  let otherMessageCount: Int
                  let messageLimit: Int
                  let counterpart: RawCounterpart
                  let moveToPermanent: RawMoveToPermanent
              }
              struct RawCounterpart: Decodable {
                  let userId: String
                  let firstName: String
                  let initials: String
                  let blurredPhotoUrl: String?
              }
              struct RawMoveToPermanent: Decodable {
                  let myDecision: String
                  let otherDecision: String
                  let requestStatus: String
                  let canRequest: Bool
                  let canRespond: Bool
                  let canSubmitFinalDecision: Bool
              }
              let success: Bool
              let data: DataBody
          }
   
          do {
              let resp = try JSONDecoder().decode(Resp.self, from: data)
              let raw  = resp.data.session
   
              let session = SessionDetail(
                  sessionId:          raw.sessionId,
                  status:             raw.status,
                  startedAt:          raw.startedAt,
                  expiresAt:          raw.expiresAt,
                  remainingSeconds:   raw.remainingSeconds,
                  canOpen:            raw.canOpen,
                  canSendMessage:     raw.canSendMessage,
                  unreadCount:        raw.unreadCount,
                  myMessageCount:     raw.myMessageCount,
                  otherMessageCount:  raw.otherMessageCount,
                  messageLimit:       raw.messageLimit,
                  counterpart: SessionCounterpart(
                      userId:          raw.counterpart.userId,
                      firstName:       raw.counterpart.firstName,
                      initials:        raw.counterpart.initials,
                      blurredPhotoUrl: raw.counterpart.blurredPhotoUrl
                  ),
                  moveToPermanent: SessionMoveToPermanent(
                      myDecision:             raw.moveToPermanent.myDecision,
                      otherDecision:          raw.moveToPermanent.otherDecision,
                      requestStatus:          raw.moveToPermanent.requestStatus,
                      canRequest:             raw.moveToPermanent.canRequest,
                      canRespond:             raw.moveToPermanent.canRespond,
                      canSubmitFinalDecision: raw.moveToPermanent.canSubmitFinalDecision
                  )
              )
   
              return SessionDetailResult(success: resp.success, session: session)
   
          } catch {
              throw APIError.decoding(error)
          }
      }
    
    /// POST /matching/sessions/:sessionId/messages
    ///  send message in speed dating
    func sendSpeedDatingMessage(token: String, sessionId: String, content: String) async throws -> SendMessageResult {
        var req = request(path: "/matching/sessions/\(sessionId)/messages", method: "POST", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["content": content])
 
        let (data, response) = try await perform(req)
        let status = response.statusCode
 
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
 
        struct Resp: Decodable {
            struct DataBody: Decodable {
                struct Msg: Decodable {
                    let id: String
                    let content: String
                    let senderId: String
                    let createdAt: String
                }
                let message: Msg
            }
            let data: DataBody
        }
 
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        return SendMessageResult(
            messageId: resp.data.message.id,
            content:   resp.data.message.content,
            senderId:  resp.data.message.senderId,
            createdAt: resp.data.message.createdAt
        )
    }
    
    /// GET /matching/sessions/:sessionId/messages
    /// Get all messages in the session

    func getSpeedDatingMessages(token: String, sessionId: String) async throws -> [MessageHistoryItem] {
         let req = request(path: "/matching/sessions/\(sessionId)/messages", method: "GET", token: token)
         let (data, response) = try await perform(req)
         let status = response.statusCode
  
         if status == 401 { throw APIError.unauthorized }
         if !(200..<300).contains(status) { throw APIError.serverError(status) }
  
         struct Resp: Decodable {
             struct DataBody: Decodable {
                 struct Msg: Decodable {
                     let id: String
                     let content: String
                     let senderId: String
                     let createdAt: String
                 }
                 let messages: [Msg]
             }
             let data: DataBody
         }
  
         let resp = try JSONDecoder().decode(Resp.self, from: data)
         return resp.data.messages.map {
             MessageHistoryItem(messageId: $0.id, content: $0.content,
                                senderId: $0.senderId, createdAt: $0.createdAt)
         }
     }
    
    /// POST /api/v1/matching/sessions/:sessionId/final-decision
    /// Submit final decision when end the matching phase
    func submitFinalDecision(token: String, sessionId: String, decision: String) async throws {
            var req = request(path: "/matching/sessions/\(sessionId)/final-decision", method: "POST", token: token)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: ["decision": decision])
     
            let (data, response) = try await perform(req)
            let status = response.statusCode
     
            if status == 401 { throw APIError.unauthorized }
            if !(200..<300).contains(status) { throw APIError.serverError(status) }
        }
    
    // MARK: - Request Early Match (heart button during active session)
    // POST /matching/sessions/:sessionId/move-to-permanent/request
 
    func requestMoveToPermanent(token: String, sessionId: String) async throws {
        var req = request(path: "/matching/sessions/\(sessionId)/move-to-permanent/request",
                          method: "POST", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
 
        let (data, response) = try await perform(req)
        let status = response.statusCode
 
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
    }
 
    // MARK: - Respond to Early Match Request (partner responds yes/no)
    // POST /matching/sessions/:sessionId/move-to-permanent/respond
 
    func respondMoveToPermanent(token: String, sessionId: String, accept: Bool) async throws {
        var req = request(path: "/matching/sessions/\(sessionId)/move-to-permanent/respond",
                          method: "POST", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["accept": accept])
 
        let (data, response) = try await perform(req)
        let status = response.statusCode
 
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
    }
    
    // MARK: - Get Permanent Messages
    // GET /matching/matches/:matchId/messages
 
    func getPermanentMessages(token: String, matchId: String) async throws -> [PermanentMessageItem] {
        let req = request(path: "/matching/matches/\(matchId)/messages", method: "GET", token: token)
        let (data, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
 
        struct Resp: Decodable {
            struct DataBody: Decodable {
                struct Msg: Decodable {
                    let id: String
                    let matchId: String
                    let content: String
                    let senderId: String
                    let createdAt: String
                }
                let messages: [Msg]
            }
            let data: DataBody
        }
 
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        return resp.data.messages.map {
            PermanentMessageItem(
                messageId: $0.id,
                matchId:   $0.matchId,
                content:   $0.content,
                senderId:  $0.senderId,
                createdAt: $0.createdAt
            )
        }
    }
    
    // MARK: - Send Permanent Message
    // POST /matching/matches/:matchId/messages
    func sendPermanentMessage(token: String, matchId: String, content: String) async throws -> SendPermanentMessageResult {
        var req = request(path: "/matching/matches/\(matchId)/messages", method: "POST", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["content": content])
 
        let (data, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
 
        struct Resp: Decodable {
            struct DataBody: Decodable {
                struct Msg: Decodable {
                    let id: String
                    let content: String
                    let senderId: String
                    let createdAt: String
                }
                let message: Msg
            }
            let data: DataBody
        }
 
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        return SendPermanentMessageResult(
            messageId: resp.data.message.id,
            content:   resp.data.message.content,
            senderId:  resp.data.message.senderId,
            createdAt: resp.data.message.createdAt
        )
    }
    

    // MARK: - Match Profile

    /// GET /matching/matches/:matchId/profile — fetches the counterpart's full profile for a permanent match.
    func fetchMatchProfile(token: String, matchId: String) async throws -> MatchProfile {
        let req = request(path: "/matching/matches/\(matchId)/profile", method: "GET", token: token)
        let (data, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
        struct Resp: Decodable {
            struct DataBody: Decodable { let profile: MatchProfileResponse }
            let data: DataBody
        }
        do {
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            return resp.data.profile.toMatchProfile()
        } catch {
            throw APIError.decoding(error)
        }
    }

    // MARK: - Permanent Matches List

    /// GET /matching/matches — lists all permanent matches for the current user.
    func getAllMatches(token: String) async throws -> ListMatchesResult {
        let req = request(path: "/matching/matches", method: "GET", token: token)
        let (data, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
        struct Resp: Decodable {
            struct DataBody: Decodable {
                struct Match: Decodable {
                    struct Counterpart: Decodable {
                        let userId: String?
                        let displayName: String?
                        let photoUrl: String?
                    }
                    let matchId: String?
                    let status: String?
                    let lastMessageAt: String?
                    let lastMessageContent: String?
                    let unreadCount: Int?
                    let counterpart: Counterpart?
                }
                let matches: [Match]
            }
            let success: Bool
            let data: DataBody?
        }
        do {
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            let matches = (resp.data?.matches ?? []).compactMap { m -> MatchListItem? in
                guard let matchId = m.matchId else { return nil }
                return MatchListItem(
                    matchId: matchId,
                    status: m.status,
                    lastMessageAt: m.lastMessageAt,
                    lastMessageContent: m.lastMessageContent,
                    unreadCount: m.unreadCount ?? 0,
                    counterpartDisplayName: m.counterpart?.displayName,
                    counterpartUserId:      m.counterpart?.userId,
                    counterpartPhotoUrl: m.counterpart?.photoUrl
                )
            }
            return ListMatchesResult(success: resp.success, matches: matches)
        } catch {
            throw APIError.decoding(error)
        }
    }

    // MARK: - Permanent Chat Actions

    /// POST /matching/matches/:matchId/remove — removes the match for both users.
    func removeMatch(matchId: String, token: String) async throws {
        let req = request(path: "/matching/matches/\(matchId)/remove", method: "POST", token: token)
        let (_, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
    }

    /// POST /matching/matches/:matchId/block — blocks the counterpart and removes the match.
    /// reason is optional free text.
    func blockMatch(matchId: String, reason: String?, token: String) async throws {
        var req = request(path: "/matching/matches/\(matchId)/block", method: "POST", token: token)
        if let reason {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: ["reason": reason])
        }
        let (_, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
    }

    /// POST /matching/matches/:matchId/report — reports the counterpart.
    /// reason is required; details is optional.
    func reportMatch(matchId: String, reason: String, details: String?, token: String) async throws {
        var req = request(path: "/matching/matches/\(matchId)/report", method: "POST", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: String] = ["reason": reason]
        if let details {
            body["details"] = details
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
    }

    // MARK: - Permanent Chat Messages

    struct PermanentMessageItem {
        let messageId: String
        let matchId: String
        let content: String
        let senderId: String
        let createdAt: String
    }

    struct PermanentMessagesResult {
        let counterpartUserId: String
        let messages: [PermanentMessageItem]
    }

    /// GET /matching/matches/:matchId/messages — fetches full message history for a permanent match.
    func getMatchMessages(matchId: String, token: String) async throws -> PermanentMessagesResult {
        let req = request(path: "/matching/matches/\(matchId)/messages", method: "GET", token: token)
        let (data, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }

        struct Resp: Decodable {
            struct DataBody: Decodable {
                struct MatchItem: Decodable {
                    struct Counterpart: Decodable {
                        let userId: String?
                    }
                    let counterpart: Counterpart
                }
                struct Msg: Decodable {
                    let id: String
                    let matchId: String?
                    let senderId: String?
                    let content: String
                    let createdAt: String?
                }
                let match: MatchItem
                let messages: [Msg]
            }
            let data: DataBody
        }

        do {
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            let items = resp.data.messages.map {
                PermanentMessageItem(
                    messageId: $0.id,
                    matchId:   $0.matchId ?? matchId,
                    content:   $0.content ?? "", senderId:  $0.senderId ?? "",
                    createdAt: $0.createdAt!
                )
            }
            return PermanentMessagesResult(
                counterpartUserId: resp.data.match.counterpart.userId ?? "",
                messages: items
            )
        } catch {
            throw APIError.decoding(error)
        }
    }

    struct SendPermanentMessageResult {
        let messageId: String
        let content: String
        let senderId: String
        let createdAt: String?
    }

    /// POST /matching/matches/:matchId/messages — sends a message in a permanent match.
    func sendPermanentMessage(matchId: String, content: String, token: String) async throws -> SendPermanentMessageResult {
        var req = request(path: "/matching/matches/\(matchId)/messages", method: "POST", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["content": content])

        let (data, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }

        struct Resp: Decodable {
            struct DataBody: Decodable {
                struct Msg: Decodable {
                    let id: String
                    let content: String
                    let senderId: String?
                    let createdAt: String?
                }
                let message: Msg
            }
            let data: DataBody
        }

        do {
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            return SendPermanentMessageResult(
                messageId: resp.data.message.id,
                content:   resp.data.message.content,
                senderId:  resp.data.message.senderId ?? "",
                createdAt: resp.data.message.createdAt
            )
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// PATCH /matching/matches/:matchId/read — marks all messages in the match as read.
    func markMatchMessagesRead(matchId: String, token: String) async throws {
        let req = request(path: "/matching/matches/\(matchId)/read", method: "PATCH", token: token)
        let (_, response) = try await perform(req)
        let status = response.statusCode
        if status == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(status) { throw APIError.serverError(status) }
    }

    // MARK: - Helpers

    private func request(path: String, method: String, token: String) -> URLRequest {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return req
    }

    private func perform(_ req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.network(URLError(.badServerResponse))
            }
            return (data, httpResponse)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error)
        }
    }
}

// MARK: - Profile Payload

struct UserProfilePayload: Encodable {

    struct PromptEntry: Encodable {
        let question: String
        let answer: String
    }

    // Required
    let firstName: String?
    let lastName: String?
    let birthDate: String           // ISO: "1995-03-15"
    let gender: String
    let ethnicity: [String]?
    let heightUnit: String?         // "imperial" or "metric"
    let heightFt: Int?
    let heightIn: Int?
    let heightCm: Int?
    let locationCity: String
    let locationState: String
    let locationZip: String
    let latitude: Double
    let longitude: Double
    let meetPreference: String
    let relationshipGoals: [String]
    let minAgePreference: Int
    let maxAgePreference: Int
    let distancePreferenceMiles: Int
    // Optional
    let drinks: String?
    let smoking: String?
    let pets: String?
    let children: String?
    let workout: String?
    let sleepSchedule: String?
    let education: String?
    let careerField: String?
    let languages: [String]?
    let prompts: [PromptEntry]?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case birthDate = "birth_date"
        case gender
        case ethnicity
        case heightUnit = "height_unit"
        case heightFt = "height_ft"
        case heightIn = "height_in"
        case heightCm = "height_cm"
        case locationCity = "location_city"
        case locationState = "location_state"
        case locationZip = "location_zip"
        case latitude, longitude
        case meetPreference = "meet_preference"
        case relationshipGoals = "relationship_goals"
        case minAgePreference = "min_age_preference"
        case maxAgePreference = "max_age_preference"
        case distancePreferenceMiles = "distance_preference_miles"
        case drinks, smoking, pets, children, workout
        case sleepSchedule = "sleep_schedule"
        case education
        case careerField = "career_field"
        case languages
        case prompts
    }

    init(from data: OnboardingData, firstName: String, lastName: String) {
        self.firstName = firstName.isEmpty ? nil : firstName
        self.lastName = lastName.isEmpty ? nil : lastName

        // Combine separate dob fields into ISO date string
        let monthMap = ["Jan": "01", "Feb": "02", "Mar": "03", "Apr": "04", "May": "05", "Jun": "06",
                        "Jul": "07", "Aug": "08", "Sep": "09", "Oct": "10", "Nov": "11", "Dec": "12"]
        let monthNum = monthMap[data.dobMonth] ?? "01"
        let day = data.dobDay.count == 1 ? "0\(data.dobDay)" : data.dobDay
        birthDate = "\(data.dobYear)-\(monthNum)-\(day)"

        gender = data.sex
        ethnicity = data.ethnicities.isEmpty ? nil : data.ethnicities.sorted()

        // Map height unit: "FT" → "imperial", "CM" → "metric"
        let hasHeight = !data.heightFt.isEmpty || !data.heightCm.isEmpty
        if hasHeight {
            let isImperial = data.heightUnit == "FT"
            heightUnit = isImperial ? "imperial" : "metric"
            heightFt = isImperial ? Int(data.heightFt) : nil
            heightIn = isImperial ? (Int(data.heightIn) ?? 0) : nil
            heightCm = isImperial ? nil : Int(data.heightCm)
        } else {
            heightUnit = nil; heightFt = nil; heightIn = nil; heightCm = nil
        }

        locationCity = data.locationCity
        locationState = data.locationState
        locationZip = data.locationZip
        latitude = data.latitude
        longitude = data.longitude

        meetPreference = data.meetPreference
        relationshipGoals = Array(data.relationshipGoals)
        minAgePreference = Int(data.minAge)
        maxAgePreference = Int(data.maxAge)
        distancePreferenceMiles = Int(data.distance)

        drinks = data.drinks.isEmpty ? nil : data.drinks
        smoking = data.smoking.isEmpty ? nil : data.smoking
        pets = data.pets.isEmpty ? nil : data.pets
        children = data.children.isEmpty ? nil : data.children
        workout = data.workout.isEmpty ? nil : data.workout
        sleepSchedule = data.sleepSchedule.isEmpty ? nil : data.sleepSchedule
        let educationMap: [String: String] = [
            "High School": "high_school",
            "In College": "in_college",
            "Bachelor's Degree": "bachelors",
            "Master's Degree": "masters",
            "PhD / Doctorate": "phd",
            "Other": "other"
        ]
        education = data.education.isEmpty ? nil : (educationMap[data.education] ?? data.education)
        careerField = data.career.isEmpty ? nil : data.career
        languages = data.languages.isEmpty ? nil : data.languages.sorted()

        // Build prompts array from individual prompt fields
        var promptList: [PromptEntry] = []
        if !data.prompt1Question.isEmpty && !data.prompt1Answer.isEmpty {
            promptList.append(PromptEntry(question: data.prompt1Question, answer: data.prompt1Answer))
        }
        if !data.prompt2Question.isEmpty && !data.prompt2Answer.isEmpty {
            promptList.append(PromptEntry(question: data.prompt2Question, answer: data.prompt2Answer))
        }
        if !data.prompt3Question.isEmpty && !data.prompt3Answer.isEmpty {
            promptList.append(PromptEntry(question: data.prompt3Question, answer: data.prompt3Answer))
        }
        if !data.ownPrompt.isEmpty && !data.ownPromptAnswer.isEmpty {
            promptList.append(PromptEntry(question: data.ownPrompt, answer: data.ownPromptAnswer))
        }
        prompts = promptList.isEmpty ? nil : promptList
    }
}

// MARK: - Profile GET Response

struct UserProfileResponse: Decodable {
    struct PromptEntry: Decodable { let question: String; let answer: String }

    let firstName: String?
    let lastName: String?
    let bio: String?
    let jobTitle: String?
    let instagramHandle: String?
    let tiktokHandle: String?
    let spotifyPlaylistUrl: String?
    let pronouns: String?
    let orientation: String?
    let genderIdentity: String?
    let showGender: Bool?
    let showOrientation: Bool?
    let showIdentity: Bool?
    let careerField: String?
    let education: String?
    let school: String?
    let heightUnit: String?
    let heightFt: Int?
    let heightIn: Int?
    let heightCm: Int?
    let ethnicity: [String]?
    let languages: [String]?
    let birthCountry: String?
    let drinks: String?
    let smoking: String?
    let workout: String?
    let sleepSchedule: String?
    let pets: String?
    let cannabis: String?
    let petTypes: String?
    let petsName: String?
    let children: String?
    let isDrinksFlexible: Bool?
    let isSmokingFlexible: Bool?
    let isWorkoutFlexible: Bool?
    let isSleepFlexible: Bool?
    let isCannabisFlexible: Bool?
    let isKidsFlexible: Bool?
    let loveLanguage: String?
    let zodiacSign: String?
    let communicationStyle: String?
    let conflictStyle: String?
    let isPersonalityTestComplete: Bool?
    let showPersonalityTrait: Bool?
    let personalityType: String?
    let personalityPrimary: String?
    let personalitySecondary: String?
    let interests: [String]?
    let preferredDateActivities: [String]?
    let wouldNotDoActivities: [String]?
    let meetPreference: String?
    let relationshipGoals: [String]?
    let minAgePreference: Int?
    let maxAgePreference: Int?
    let distancePreferenceMiles: Int?
    let birthDate: String?
    let gender: String?
    let locationCity: String?
    let locationState: String?
    let prompts: [PromptEntry]?
    let photos: [UserPhoto]?
    

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case bio
        case jobTitle = "job_title"
        case instagramHandle = "instagram_handle"
        case tiktokHandle = "tiktok_handle"
        case spotifyPlaylistUrl = "spotify_playlist_url"
        case pronouns, orientation
        case genderIdentity = "gender_identity"
        case showGender = "show_sex"
        case showOrientation = "show_orientation"
        case showIdentity = "show_identity"
        case careerField = "career_field"
        case education, school
        case heightUnit = "height_unit"
        case heightFt = "height_ft"
        case heightIn = "height_in"
        case heightCm = "height_cm"
        case ethnicity, languages
        case birthCountry = "birth_country"
        case drinks, smoking, workout
        case sleepSchedule = "sleep_schedule"
        case pets, cannabis
        case petTypes = "pet_types"
        case petsName = "pets_name"
        case children
        case isDrinksFlexible = "is_drinks_flexible"
        case isSmokingFlexible = "is_smoking_flexible"
        case isWorkoutFlexible = "is_workout_flexible"
        case isSleepFlexible = "is_sleep_flexible"
        case isCannabisFlexible = "is_cannabis_flexible"
        case isKidsFlexible = "is_kids_flexible"
        case loveLanguage = "love_language"
        case zodiacSign = "zodiac_sign"
        case communicationStyle = "communication_style"
        case conflictStyle = "conflict_style"
        case personalityType = "personality_type"
        case personalityPrimary = "personality_primary"
        case personalitySecondary = "personality_secondary"
        case isPersonalityTestComplete = "is_personality_test_complete"
        case showPersonalityTrait = "show_personality_trait"
        case interests
        case preferredDateActivities = "preferred_date_activities"
        case wouldNotDoActivities = "would_not_do_activities"
        case meetPreference = "meet_preference"
        case relationshipGoals = "relationship_goals"
        case minAgePreference = "min_age_preference"
        case maxAgePreference = "max_age_preference"
        case distancePreferenceMiles = "distance_preference_miles"
        case prompts
        case photos = "photos"
        case birthDate = "birth_date"
        case gender
        case locationCity = "location_city"
        case locationState = "location_state"
    }
}

// MARK: - Match Profile Response

struct MatchProfileResponse: Decodable {
    struct PromptEntry: Decodable {
        let question: String
        let answer: String
    }

    let userId: String?
    let firstName: String?
    let lastName: String?
    let birthDate: String?
    let pronouns: String?
    let orientation: String?
    let genderIdentity: String?
    let showOrientation: Bool?
    let showPersonalityTrait: Bool?
    let locationCity: String?
    let locationState: String?
    let photos: [String]?
    let bio: String?
    let jobTitle: String?
    let school: String?
    let education: String?
    let careerField: String?
    let instagramHandle: String?
    let tiktokHandle: String?
    let spotifyPlaylistUrl: String?
    let interests: [String]?
    let preferredDateActivities: [String]?
    let loveLanguage: String?
    let zodiacSign: String?
    let personalityType: String?
    let personalityPrimary: String?
    let personalitySecondary: String?
    let drinks: String?
    let smoking: String?
    let workout: String?
    let pets: String?
    let sleepSchedule: String?
    let cannabis: String?
    let petTypes: String?
    let ethnicity: [String]?
    let languages: [String]?
    let prompts: [PromptEntry]?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case birthDate = "birth_date"
        case pronouns, orientation
        case genderIdentity = "gender_identity"
        case showOrientation = "show_orientation"
        case showPersonalityTrait = "show_personality_trait"
        case locationCity = "location_city"
        case locationState = "state"
        case photos, bio
        case jobTitle = "job_title"
        case school, education
        case careerField = "career_field"
        case instagramHandle = "instagram_handle"
        case tiktokHandle = "tiktok_handle"
        case spotifyPlaylistUrl = "spotify_playlist_url"
        case interests
        case preferredDateActivities = "preferred_date_activities"
        case loveLanguage = "love_language"
        case zodiacSign = "zodiac_sign"
        case personalityType = "personality_type"
        case personalityPrimary = "personality_primary"
        case personalitySecondary = "personality_secondary"
        case drinks = "lifestyle_drinks"
        case smoking = "lifestyle_smoking"
        case workout = "lifestyle_workout"
        case pets = "lifestyle_pets"
        case sleepSchedule = "lifestyle_sleep"
        case cannabis = "lifestyle_cannabis"
        case petTypes = "pet_types"
        case ethnicity, languages, prompts
    }

    func toMatchProfile() -> MatchProfile {
        MatchProfile(
            id: userId ?? "",
            firstName: firstName ?? "",
            lastName: lastName ?? "",
            age: Self.age(from: birthDate),
            jobTitle: jobTitle ?? "",
            bio: bio ?? "",
            pronouns: pronouns ?? "",
            instagramHandle: instagramHandle,
            tiktokHandle: tiktokHandle,
            locationCity: locationCity ?? "",
            locationState: locationState ?? "",
            orientation: orientation,
            identity: genderIdentity,
            isPersonalityTestCompelte: personalityType != nil,
            personalityType: personalityType,
            personalityPrimary: personalityPrimary,
            personalitySecondary: personalitySecondary,
            loveLanguage: loveLanguage,
            zodiacSign: zodiacSign,
            interests: interests ?? [],
            preferredDateActivities: preferredDateActivities ?? [],
            drinks: drinks ?? "",
            smoking: smoking ?? "",
            cannabis: cannabis ?? "",
            workout: workout ?? "",
            sleepSchedule: sleepSchedule ?? "",
            pets: pets ?? "",
            petTypes: petTypes ?? "",
            career: careerField ?? "",
            school: school ?? "",
            education: education ?? "",
            ethnicities: ethnicity ?? [],
            languages: languages ?? [],
            photoURLs: photos ?? [],
            prompts: (prompts ?? []).map {
                MatchProfile.PromptPair(question: $0.question, answer: $0.answer)
            },
            socialMediaLinks: [instagramHandle, tiktokHandle, spotifyPlaylistUrl]
                .compactMap { $0 }
                .filter { !$0.isEmpty },
            showLocation: true,
            showOrientation: showOrientation ?? true,
            showPersonalityTrait: showPersonalityTrait ?? true,
            showInterests: true,
            showLifestyle: true,
            showCareer: true,
            showPets: true
        )
    }

    private static func age(from dateString: String?) -> Int {
        guard let dateString else { return 0 }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        let date = iso.date(from: dateString) ?? dateOnly.date(from: dateString)
        guard let date else { return 0 }
        return Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
    }
}

// MARK: - Profile PATCH Payload

struct ProfileUpdatePayload: Encodable {
    struct PromptEntry: Encodable { let question: String; let answer: String }

    var firstName: String?
    var lastName: String?
    var bio: String?
    var jobTitle: String?
    var instagramHandle: String?
    var tiktokHandle: String?
    var spotifyPlaylistUrl: String?
    var pronouns: String?
    var orientation: String?
    var showGender: Bool?
    var showOrientation: Bool?
    var genderIdentity: String?
    var showIdentity: Bool?
    var careerField: String?
    var education: String?
    var school: String?
    var heightUnit: String?
    var heightFt: Int?
    var heightIn: Int?
    var heightCm: Int?
    var ethnicity: [String]?
    var languages: [String]?
    var birthCountry: String?
    var drinks: String?
    var smoking: String?
    var workout: String?
    var sleepSchedule: String?
    var pets: String?
    var cannabis: String?
    var petTypes: String?
    var petsName: String?
    var children: String?
    var isDrinksFlexible: Bool?
    var isSmokingFlexible: Bool?
    var isWorkoutFlexible: Bool?
    var isSleepFlexible: Bool?
    var isCannabisFlexible: Bool?
    var isKidsFlexible: Bool?
    var loveLanguage: String?
    var zodiacSign: String?
    var communicationStyle: String?
    var conflictStyle: String?
    var interests: [String]?
    var preferredDateActivities: [String]?
    var wouldNotDoActivities: [String]?
    var meetPreference: String?
    var relationshipGoals: [String]?
    var minAgePreference: Int?
    var maxAgePreference: Int?
    var distancePreferenceMiles: Int?
    var isPersonalityTestComplete: Bool?
    var showPersonalityTrait: Bool?
    var prompts: [PromptEntry]?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case bio
        case jobTitle = "job_title"
        case instagramHandle = "instagram_handle"
        case tiktokHandle = "tiktok_handle"
        case spotifyPlaylistUrl = "spotify_playlist_url"
        case pronouns, orientation
        case showGender = "show_sex"
        case showOrientation = "show_orientation"
        case genderIdentity = "gender_identity"
        case showIdentity = "show_identity"
        case careerField = "career_field"
        case education, school
        case heightUnit = "height_unit"
        case heightFt = "height_ft"
        case heightIn = "height_in"
        case heightCm = "height_cm"
        case ethnicity, languages
        case birthCountry = "birth_country"
        case drinks, smoking, workout
        case sleepSchedule = "sleep_schedule"
        case pets, cannabis
        case petTypes = "pet_types"
        case petsName = "pets_name"
        case children
        case isDrinksFlexible = "is_drinks_flexible"
        case isSmokingFlexible = "is_smoking_flexible"
        case isWorkoutFlexible = "is_workout_flexible"
        case isSleepFlexible = "is_sleep_flexible"
        case isCannabisFlexible = "is_cannabis_flexible"
        case isKidsFlexible = "is_kids_flexible"
        case loveLanguage = "love_language"
        case zodiacSign = "zodiac_sign"
        case communicationStyle = "communication_style"
        case conflictStyle = "conflict_style"
        case interests
        case preferredDateActivities = "preferred_date_activities"
        case wouldNotDoActivities = "would_not_do_activities"
        case meetPreference = "meet_preference"
        case relationshipGoals = "relationship_goals"
        case minAgePreference = "min_age_preference"
        case maxAgePreference = "max_age_preference"
        case distancePreferenceMiles = "distance_preference_miles"
        case isPersonalityTestComplete = "is_personality_test_complete"
        case showPersonalityTrait = "show_personality_trait"
        case prompts
    }

    init(from store: UserProfileStore) {
        firstName    = store.firstName.isEmpty    ? nil : store.firstName
        lastName     = store.lastName.isEmpty     ? nil : store.lastName
        bio          = store.bio.isEmpty          ? nil : store.bio
        jobTitle     = store.jobTitle.isEmpty     ? nil : store.jobTitle
        instagramHandle  = store.instagramHandle.isEmpty  ? nil : store.instagramHandle
        tiktokHandle     = store.tiktokHandle.isEmpty     ? nil : store.tiktokHandle
        spotifyPlaylistUrl = store.spotifyPlaylistURL.isEmpty ? nil : store.spotifyPlaylistURL
        pronouns     = store.pronouns.isEmpty     ? nil : store.pronouns
        orientation  = store.orientation.isEmpty  ? nil : store.orientation
        showGender      = store.showSex
        showOrientation = store.showOrientation
        genderIdentity  = store.identity.isEmpty  ? nil : store.identity
        showIdentity    = store.showIdentity
        careerField  = store.career.isEmpty    ? nil : store.career
        education    = store.education.isEmpty ? nil : (EducationLevel.from(displayName: store.education)?.rawValue ?? store.education)
        school       = store.school.isEmpty    ? nil : store.school

        let isImperial = store.heightUnit == "FT"
        if !store.heightFt.isEmpty || !store.heightCm.isEmpty {
            heightUnit = isImperial ? "imperial" : "metric"
            heightFt   = isImperial ? Int(store.heightFt) : nil
            heightIn   = isImperial ? (Int(store.heightIn) ?? 0) : nil
            heightCm   = isImperial ? nil : Int(store.heightCm)
        }

        ethnicity    = store.ethnicities.isEmpty ? nil : store.ethnicities
        languages    = store.languages.isEmpty   ? nil : store.languages
        birthCountry = store.birthCountry.isEmpty ? nil : store.birthCountry
        drinks       = store.drinks.isEmpty       ? nil : store.drinks
        smoking      = store.smoking.isEmpty      ? nil : store.smoking
        workout      = store.workout.isEmpty      ? nil : store.workout
        sleepSchedule = store.sleepSchedule.isEmpty ? nil : store.sleepSchedule
        pets         = store.pets.isEmpty         ? nil : store.pets
        cannabis     = store.cannabis.isEmpty     ? nil : store.cannabis
        petTypes     = store.petTypes.isEmpty     ? nil : store.petTypes
        petsName     = store.petsName.isEmpty     ? nil : store.petsName
        children     = store.children.isEmpty     ? nil : store.children
        isDrinksFlexible   = store.isDrinksFlexible
        isSmokingFlexible  = store.isSmokingFlexible
        isWorkoutFlexible  = store.isWorkoutFlexible
        isSleepFlexible    = store.isSleepFlexible
        isCannabisFlexible = store.isCannabisFlexible
        isKidsFlexible     = store.isKidsFlexible
        isPersonalityTestComplete = store.isPersonalityTestComplete
        loveLanguage = store.loveLanguage.isEmpty ? nil : store.loveLanguage
        zodiacSign   = store.zodiacSign.isEmpty   ? nil : store.zodiacSign
        // Empty string = neutral slider position — only send if non-empty
        communicationStyle = store.communicationStyle.isEmpty ? nil : store.communicationStyle
        conflictStyle      = store.conflictStyle.isEmpty      ? nil : store.conflictStyle
        interests              = store.interests.isEmpty              ? nil : store.interests
        preferredDateActivities = store.preferredDateActivities.isEmpty ? nil : store.preferredDateActivities
        wouldNotDoActivities    = store.wouldNotDoActivities.isEmpty    ? nil : store.wouldNotDoActivities
        meetPreference   = store.meetPreference.isEmpty   ? nil : store.meetPreference
        relationshipGoals = store.relationshipGoals.isEmpty ? nil : store.relationshipGoals
        minAgePreference        = Int(store.minAge)
        maxAgePreference        = Int(store.maxAge)
        distancePreferenceMiles = Int(store.distance)
        var promptList: [PromptEntry] = []
        if !store.prompt1Question.isEmpty && !store.prompt1Answer.isEmpty {
            promptList.append(.init(question: store.prompt1Question, answer: store.prompt1Answer))
        }
        if !store.prompt2Question.isEmpty && !store.prompt2Answer.isEmpty {
            promptList.append(.init(question: store.prompt2Question, answer: store.prompt2Answer))
        }
        if !store.prompt3Question.isEmpty && !store.prompt3Answer.isEmpty {
            promptList.append(.init(question: store.prompt3Question, answer: store.prompt3Answer))
        }
        if !store.customPromptQuestion.isEmpty && !store.customPromptAnswer.isEmpty {
            promptList.append(.init(question: store.customPromptQuestion, answer: store.customPromptAnswer))
        }
        prompts = promptList.isEmpty ? nil : promptList
    }

    /// Empty payload — set only the fields relevant to the calling edit sheet.
    init() {}
}

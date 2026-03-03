import Foundation

// 定義要傳送給後端的資料結構
struct RegisterRequest: Encodable {
    let provider: String
    let idToken: String
    let firstName: String
    let lastName: String
}

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case serverError(String)
    case decodingError
}

class APIService {
    static let shared = APIService()
    
    // iOS Simulator 使用 localhost。如果是實機測試，請改用電腦的區域 IP (例如 http://192.168.1.x:3000)
    private let baseURL = "http://localhost:3000/api/v1"
    
    func register(data: RegisterRequest) async throws {
        guard let url = URL(string: "\(baseURL)/auth/register") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(data)
            request.httpBody = jsonData
        } catch {
            throw APIError.decodingError
        }
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response object")
        }
        
        // 檢查 HTTP 狀態碼是否成功 (200-299)
        if !(200...299).contains(httpResponse.statusCode) {
            // 嘗試解析後端回傳的錯誤訊息
            if let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let errorObj = errorJson["error"] as? [String: Any],
               let code = errorObj["code"] as? String {
                throw APIError.serverError("Server Error: \(code)")
            } else {
                throw APIError.serverError("Server returned \(httpResponse.statusCode)")
            }
        }
    }
}
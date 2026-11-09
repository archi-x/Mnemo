import Foundation
import CryptoKit

/// 本机训练档案。没有账号体系，所有字段只写在本机 JSON 里。
struct Profile: Codable, Equatable {
    var id: String
    var nickname: String
    var avatar: String
    var pinHash: String?
    var createdAt: Date

    /// 可选头像（SF Symbol）
    static let avatars: [String] = ["brain.head.profile", "book.closed.fill", "sparkles", "moon.stars.fill"]

    var hasPin: Bool {
        guard let pinHash else { return false }
        return !pinHash.isEmpty
    }

    var displayName: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "练习者" : nickname
    }

    var joinedText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 M 月"
        return "自 \(f.string(from: createdAt)) 开始训练"
    }

    static func hash(_ pin: String) -> String {
        let digest = SHA256.hash(data: Data("mnemo.\(pin)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

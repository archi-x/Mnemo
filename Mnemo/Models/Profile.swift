import Foundation
import CryptoKit

/// 训练档案。可以是「本机档案」，也可以绑一个 Apple 账号（Sign in with Apple）。
/// 无论哪种，数据都只写在本机文件或用户自己的 iCloud 里，不上我们的服务器。
struct Profile: Codable, Equatable {
    var id: String
    var nickname: String
    var avatar: String
    var pinHash: String?
    var createdAt: Date
    /// Sign in with Apple 的用户标识；为空表示这是个本机档案
    var appleUserID: String? = nil
    /// Apple 返回的邮箱，可能是 @privaterelay.appleid.com 的转发地址
    var appleEmail: String? = nil

    /// 可选头像（SF Symbol）
    static let avatars: [String] = ["brain.head.profile", "book.closed.fill", "sparkles", "moon.stars.fill"]

    var isAppleAccount: Bool {
        guard let appleUserID else { return false }
        return !appleUserID.isEmpty
    }

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

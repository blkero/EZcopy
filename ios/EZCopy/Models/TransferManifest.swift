import Foundation

struct TransferManifest: Codable, Equatable {
    let app: String
    let schemaVersion: Int
    let sessionId: String
    let deviceName: String
    let createdAt: Date
    let files: [TransferFile]
}

struct TransferFile: Codable, Equatable, Identifiable {
    let id: String
    let originalName: String
    let relativePath: String
    let mediaType: MediaType
    let mimeType: String
    let size: Int64
    let createdAt: Date?
    let sourceMd5: String?
}

enum MediaType: String, Codable {
    case photo
    case video
}

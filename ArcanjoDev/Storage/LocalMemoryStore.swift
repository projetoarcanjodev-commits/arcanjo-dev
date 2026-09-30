import Foundation

public struct MemoryEvent: Codable, Sendable {
    public let timestamp: Date
    public let projectID: String
    public let category: String
    public let content: String
    public init(timestamp: Date = Date(), projectID: String = "default", category: String, content: String) {
        self.timestamp = timestamp; self.projectID = projectID; self.category = category; self.content = content
    }
}

/// Memória local, append-only em JSONL e separada por finalidade.
/// Os dados ficam no sandbox iOS do app; não há sincronização ou envio remoto.
public actor LocalMemoryStore {
    public enum Bucket: String, CaseIterable, Sendable {
        case conversations, projects, longTerm, decisions, toolResults, runs
    }

    private let root: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(root: URL? = nil, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        if let root { self.root = root }
        else {
            let support = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            self.root = support.appendingPathComponent("ArcanjoDev/Memory", isDirectory: true)
        }
        self.encoder = JSONEncoder(); self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder(); self.decoder.dateDecodingStrategy = .iso8601
        for bucket in Bucket.allCases {
            try fileManager.createDirectory(at: self.root.appendingPathComponent(bucket.rawValue, isDirectory: true), withIntermediateDirectories: true)
        }
    }

    public func append(_ event: MemoryEvent, to bucket: Bucket) throws {
        let folder = root.appendingPathComponent(bucket.rawValue, isDirectory: true)
        let file = folder.appendingPathComponent("events.jsonl")
        let data = try encoder.encode(event) + Data([0x0A])
        if fileManager.fileExists(atPath: file.path) {
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.seekToEnd(); try handle.write(contentsOf: data)
        } else {
            try data.write(to: file, options: .atomic)
        }
    }

    public func readAll(from bucket: Bucket) throws -> [MemoryEvent] {
        let file = root.appendingPathComponent(bucket.rawValue, isDirectory: true).appendingPathComponent("events.jsonl")
        guard fileManager.fileExists(atPath: file.path) else { return [] }
        let data = try Data(contentsOf: file)
        return try data.split(separator: 0x0A).map { try decoder.decode(MemoryEvent.self, from: Data($0)) }
    }

    public func clear(_ bucket: Bucket) throws {
        let file = root.appendingPathComponent(bucket.rawValue, isDirectory: true).appendingPathComponent("events.jsonl")
        if fileManager.fileExists(atPath: file.path) { try fileManager.removeItem(at: file) }
    }
}

//
//  CacheItem.swift
//  SymLinkdCache
//
//  Created by Antigravity on 16/07/2026.
//

import Foundation

public enum AppCategory: String, Codable, CaseIterable {
    case directMigration = "DIRECT"
    case nativeGuidance = "NATIVE CONFIG"
}

public enum CacheStatus: Equatable {
    case idle
    case scanning
    case migrating
    case success(freedBytes: Int64)
    case failed(String)
    
    public var label: String {
        switch self {
        case .idle: return "READY"
        case .scanning: return "SCANNING"
        case .migrating: return "MIGRATING"
        case .success: return "COMPLETED"
        case .failed: return "FAILED"
        }
    }
}

public struct CacheItem: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let bundleIdentifier: String?
    public let executableName: String?
    public let category: AppCategory
    public let sourcePath: URL
    public let targetSubpath: String
    public var sizeInBytes: Int64
    public var status: CacheStatus
    public var isRunning: Bool
    public var guidanceSteps: [String]
    public var documentationURL: String?
    
    public init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String? = nil,
        executableName: String? = nil,
        category: AppCategory,
        sourcePath: URL,
        targetSubpath: String,
        sizeInBytes: Int64 = 0,
        status: CacheStatus = .idle,
        isRunning: Bool = false,
        guidanceSteps: [String] = [],
        documentationURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.executableName = executableName
        self.category = category
        self.sourcePath = sourcePath
        self.targetSubpath = targetSubpath
        self.sizeInBytes = sizeInBytes
        self.status = status
        self.isRunning = isRunning
        self.guidanceSteps = guidanceSteps
        self.documentationURL = documentationURL
    }
    
    public var isSymlinked: Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: sourcePath.path, isDirectory: &isDir) else { return false }
        do {
            let values = try sourcePath.resourceValues(forKeys: [.isSymbolicLinkKey])
            return values.isSymbolicLink ?? false
        } catch {
            return false
        }
    }
    
    public var symlinkDestination: String? {
        guard isSymlinked else { return nil }
        return try? FileManager.default.destinationOfSymbolicLink(atPath: sourcePath.path)
    }
}

extension Int64 {
    public var formattedSize: String {
        if self == 0 { return "0.0 MB" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        return formatter.string(fromByteCount: self)
    }
}

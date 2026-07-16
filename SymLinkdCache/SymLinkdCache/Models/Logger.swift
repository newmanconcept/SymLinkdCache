//
//  Logger.swift
//  SymLinkdCache
//
//  Created by Antigravity on 16/07/2026.
//

import Foundation

public final class AppLogger: ObservableObject {
    public static let shared = AppLogger()
    
    @Published public private(set) var logs: [String] = []
    
    private let fileManager = FileManager.default
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        return df
    }()
    
    private var logFileURL: URL? {
        let libraryDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first
        let logsDir = libraryDir?.appendingPathComponent("Logs/SymLinkdCache", isDirectory: true)
        
        if let dir = logsDir {
            do {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Failed to create log directory: \(error)")
            }
        }
        return logsDir?.appendingPathComponent("operations.log")
    }
    
    private let queue = DispatchQueue(label: "com.onedaynot.SymLinkdCache.logger", qos: .utility)
    
    private init() {
        log("LOGGER INITIALIZED. SYSTEM STATUS: OK", type: .info)
    }
    
    public func log(_ message: String, type: LogType = .info) {
        let timeString = dateFormatter.string(from: Date())
        let prefix: String
        switch type {
        case .info:    prefix = "[INFO]"
        case .warning: prefix = "[WARN]"
        case .error:   prefix = "[ERR ]"
        case .success: prefix = "[OK  ]"
        }
        
        let logLine = "\(timeString) \(prefix) \(message)"
        print(logLine) // Standard Xcode console logging
        
        queue.async {
            // Write to file
            if let fileURL = self.logFileURL {
                do {
                    let data = (logLine + "\n").data(using: .utf8) ?? Data()
                    if self.fileManager.fileExists(atPath: fileURL.path) {
                        let fileHandle = try FileHandle(forWritingTo: fileURL)
                        try fileHandle.seekToEnd()
                        fileHandle.write(data)
                        try fileHandle.close()
                    } else {
                        try data.write(to: fileURL, options: .atomic)
                    }
                } catch {
                    print("Failed to write log to file: \(error)")
                }
            }
            
            // Dispatch back to main queue for UI
            DispatchQueue.main.async {
                self.logs.append(logLine)
                if self.logs.count > 300 {
                    self.logs.removeFirst()
                }
            }
        }
    }
    
    public func clear() {
        queue.async {
            if let fileURL = self.logFileURL {
                try? self.fileManager.removeItem(at: fileURL)
            }
            DispatchQueue.main.async {
                self.logs.removeAll()
                self.log("LOGS CLEARED.", type: .info)
            }
        }
    }
    
    public enum LogType: String {
        case info
        case warning
        case error
        case success
    }
}

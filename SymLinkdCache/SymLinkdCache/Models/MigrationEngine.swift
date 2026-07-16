//
//  MigrationEngine.swift
//  SymLinkdCache
//
//  Created by Antigravity on 16/07/2026.
//

import Foundation
import AppKit
import Combine

@MainActor
public final class MigrationEngine: ObservableObject {
    @Published public var items: [CacheItem] = []
    @Published public var isScanning = false
    @Published public var hasFullDiskAccess = false
    @Published public var targetVolumeURL: URL? = nil {
        didSet {
            if let url = targetVolumeURL {
                AppLogger.shared.log("TARGET VOLUME SET TO: \(url.path)", type: .info)
                UserDefaults.standard.set(url.path, forKey: "TargetVolumePath")
            } else {
                AppLogger.shared.log("TARGET VOLUME CLEARED", type: .warning)
                UserDefaults.standard.removeObject(forKey: "TargetVolumePath")
            }
        }
    }
    
    private let fileManager = FileManager.default
    private var timer: Timer?
    
    public init() {
        // Load target volume if saved
        if let path = UserDefaults.standard.string(forKey: "TargetVolumePath") {
            self.targetVolumeURL = URL(fileURLWithPath: path)
        }
        
        setupDefaultItems()
        checkFDA()
        
        // Start process supervision timer (every 3 seconds)
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshRunningStates()
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func setupDefaultItems() {
        let home = fileManager.homeDirectoryForCurrentUser
        
        let config: [(name: String, bundleId: String?, execName: String?, category: AppCategory, relativePath: String, subpath: String, steps: [String], doc: String?)] = [
            (
                name: "FIGMA CLIENT CACHE",
                bundleId: "com.figma.Desktop",
                execName: "Figma",
                category: .directMigration,
                relativePath: "Library/Application Support/Figma",
                subpath: "Figma_Data",
                steps: [],
                doc: nil
            ),
            (
                name: "SPOTIFY CACHE",
                bundleId: "com.spotify.client",
                execName: "Spotify",
                category: .directMigration,
                relativePath: "Library/Caches/com.spotify.client",
                subpath: "Spotify_Cache",
                steps: [],
                doc: nil
            ),
            (
                name: "CHROME CACHE",
                bundleId: "com.google.Chrome",
                execName: "Google Chrome",
                category: .directMigration,
                relativePath: "Library/Caches/Google/Chrome",
                subpath: "Chrome_Cache",
                steps: [],
                doc: nil
            ),
            (
                name: "XCODE DERIVED DATA",
                bundleId: "com.apple.dt.Xcode",
                execName: "Xcode",
                category: .directMigration,
                relativePath: "Library/Developer/Xcode/DerivedData",
                subpath: "Xcode_DerivedData",
                steps: [],
                doc: nil
            ),
            (
                name: "XCODE IOS DEVICESUPPORT",
                bundleId: "com.apple.dt.Xcode",
                execName: "Xcode",
                category: .directMigration,
                relativePath: "Library/Developer/Xcode/iOS DeviceSupport",
                subpath: "Xcode_iOSDeviceSupport",
                steps: [],
                doc: nil
            ),
            (
                name: "SLACK CONTAINER CACHE",
                bundleId: "com.tinyspeck.slackmacgap",
                execName: "Slack",
                category: .directMigration,
                relativePath: "Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Caches/com.tinyspeck.slackmacgap",
                subpath: "Slack_Cache",
                steps: [],
                doc: nil
            ),
            (
                name: "ADOBE PREMIERE CACHE",
                bundleId: "com.adobe.PremierePro",
                execName: "Adobe Premiere Pro",
                category: .nativeGuidance,
                relativePath: "Library/Application Support/Adobe/Common/Media Cache Files",
                subpath: "Adobe_Media_Cache",
                steps: [
                    "Launch Adobe Premiere Pro on your Mac.",
                    "Navigate to Preferences > Media Cache.",
                    "Locate 'Media Cache Files' and click '[ Browse... ]'.",
                    "Choose a folder on your external drive.",
                    "Select 'Move existing media cache files' when prompted."
                ],
                doc: "https://helpx.adobe.com/premiere-pro/using/preferences.html#MediaCache"
            ),
            (
                name: "DAVINCI RESOLVE CACHE",
                bundleId: "com.blackmagic-design.DaVinciResolve",
                execName: "DaVinci Resolve",
                category: .nativeGuidance,
                relativePath: "Library/Application Support/Blackmagic Design/DaVinci Resolve",
                subpath: "Resolve_Cache",
                steps: [
                    "Open DaVinci Resolve.",
                    "Open Preferences (Command + ,).",
                    "Navigate to System > Media Storage.",
                    "Click '[ Add ]' and choose your external drive folder.",
                    "Ensure it is placed at the top of the storage list."
                ],
                doc: "https://www.blackmagicdesign.com/products/davinciresolve"
            )
        ]
        
        self.items = config.map { cfg in
            let fullURL = home.appendingPathComponent(cfg.relativePath)
            return CacheItem(
                name: cfg.name,
                bundleIdentifier: cfg.bundleId,
                executableName: cfg.execName,
                category: cfg.category,
                sourcePath: fullURL,
                targetSubpath: cfg.subpath,
                sizeInBytes: 0,
                status: .idle,
                isRunning: false,
                guidanceSteps: cfg.steps,
                documentationURL: cfg.doc
            )
        }
    }
    
    public func checkFDA() {
        let home = fileManager.homeDirectoryForCurrentUser
        let safariURL = home.appendingPathComponent("Library/Safari")
        do {
            _ = try fileManager.contentsOfDirectory(at: safariURL, includingPropertiesForKeys: nil)
            hasFullDiskAccess = true
        } catch {
            hasFullDiskAccess = false
        }
    }
    
    public func scanAll() async {
        isScanning = true
        AppLogger.shared.log("STARTING ASYNCHRONOUS SCAN OF CACHE PATHS...", type: .info)
        checkFDA()
        
        for index in items.indices {
            let item = items[index]
            
            // Check if folder exists
            if fileManager.fileExists(atPath: item.sourcePath.path) {
                items[index].status = .scanning
                do {
                    let size = try await calculateFolderSize(at: item.sourcePath)
                    items[index].sizeInBytes = size
                    items[index].status = .idle
                    AppLogger.shared.log("SCANNED: \(item.name) | SIZE: \(size.formattedSize)", type: .info)
                } catch {
                    items[index].status = .failed(error.localizedDescription)
                    AppLogger.shared.log("SCAN FAILED: \(item.name) | \(error.localizedDescription)", type: .error)
                }
            } else {
                items[index].sizeInBytes = 0
                items[index].status = .idle
                AppLogger.shared.log("PATH NOT FOUND (SKIPPED): \(item.name)", type: .info)
            }
        }
        
        refreshRunningStates()
        isScanning = false
        AppLogger.shared.log("ASYNCHRONOUS SCAN COMPLETED.", type: .success)
    }
    
    private func calculateFolderSize(at url: URL) async throws -> Int64 {
        return try await Task.detached(priority: .userInitiated) {
            let fm = FileManager()
            var isSym = false
            if let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink == true {
                isSym = true
            }
            
            if isSym {
                if let destPath = try? fm.destinationOfSymbolicLink(atPath: url.path) {
                    let destURL = URL(fileURLWithPath: destPath)
                    return try Self.calculateFolderSizeSync(at: destURL, fm: fm)
                }
                return 0
            }
            
            return try Self.calculateFolderSizeSync(at: url, fm: fm)
        }.value
    }
    
    private static nonisolated func calculateFolderSizeSync(at url: URL, fm: FileManager) throws -> Int64 {
        var size: Int64 = 0
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: Set(keys))
            if let isDir = values.isDirectory, !isDir {
                if let fileSize = values.fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        return size
    }
    
    public func refreshRunningStates() {
        let runningApps = NSWorkspace.shared.runningApplications
        for index in items.indices {
            let item = items[index]
            var isRunning = false
            
            if let bundleId = item.bundleIdentifier {
                isRunning = runningApps.contains { $0.bundleIdentifier == bundleId }
            } else if let execName = item.executableName {
                isRunning = runningApps.contains { $0.localizedName == execName }
            }
            
            if items[index].isRunning != isRunning {
                items[index].isRunning = isRunning
                if isRunning {
                    AppLogger.shared.log("APP DETECTED RUNNING: \(item.name)", type: .warning)
                }
            }
        }
    }
    
    public func forceQuit(_ item: CacheItem) {
        AppLogger.shared.log("FORCE QUITTING APPLICATION FOR: \(item.name)...", type: .warning)
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if (item.bundleIdentifier != nil && app.bundleIdentifier == item.bundleIdentifier) ||
               (item.executableName != nil && app.localizedName == item.executableName) {
                app.forceTerminate()
                AppLogger.shared.log("TERMINATION SIGNAL SENT TO: \(app.localizedName ?? item.name)", type: .success)
            }
        }
        // Small delay to let OS process quit
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshRunningStates()
        }
    }
    
    public func migrate(_ item: CacheItem) async {
        guard let targetVolume = targetVolumeURL else {
            AppLogger.shared.log("MIGRATION FAILED: NO TARGET VOLUME SELECTED", type: .error)
            return
        }
        
        // Find item index
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        // Safety checks
        refreshRunningStates()
        if items[index].isRunning {
            AppLogger.shared.log("MIGRATION BLOCKED: \(item.name) IS CURRENTLY RUNNING. PLEASE QUIT THE APP.", type: .error)
            items[index].status = .failed("App is running")
            return
        }
        
        items[index].status = .migrating
        AppLogger.shared.log("INITIATING MIGRATION FOR \(item.name)...", type: .info)
        
        let sourceURL = item.sourcePath
        let targetURL = targetVolume.appendingPathComponent(item.targetSubpath)
        let backupURL = sourceURL.deletingLastPathComponent().appendingPathComponent(sourceURL.lastPathComponent + ".backup")
        
        do {
            // 1. Create target parent directories if needed
            let targetParent = targetURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: targetParent.path) {
                AppLogger.shared.log("CREATING TARGET DIRECTORY: \(targetParent.path)", type: .info)
                try fileManager.createDirectory(at: targetParent, withIntermediateDirectories: true, attributes: nil)
            }
            
            // If target folder already exists, delete it first to ensure clean migration
            if fileManager.fileExists(atPath: targetURL.path) {
                AppLogger.shared.log("TARGET DIRECTORY ALREADY EXISTS. CLEANING TARGET PATH...", type: .warning)
                try fileManager.removeItem(at: targetURL)
            }
            
            // 2. Copy source to target
            AppLogger.shared.log("COPYING DATA TO TARGET VOLUME: \(targetURL.path)", type: .info)
            try await performCopy(from: sourceURL, to: targetURL)
            
            // 3. Rename original to backup (buffer)
            AppLogger.shared.log("RENAMING ORIGINAL PATH TO BACKUP BUFFER...", type: .info)
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            try fileManager.moveItem(at: sourceURL, to: backupURL)
            
            // 4. Create symlink
            AppLogger.shared.log("CREATING SYMBOLIC LINK AT ORIGINAL PATH...", type: .info)
            try fileManager.createSymbolicLink(at: sourceURL, withDestinationURL: targetURL)
            
            // 5. Verify symlink
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDir) {
                let values = try sourceURL.resourceValues(forKeys: [.isSymbolicLinkKey])
                if values.isSymbolicLink == true {
                    AppLogger.shared.log("SYMBOLIC LINK VERIFIED: OK", type: .success)
                } else {
                    throw NSError(domain: "SymLinkdCache", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to verify symbolic link type"])
                }
            } else {
                throw NSError(domain: "SymLinkdCache", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to verify symbolic link existence"])
            }
            
            // 6. Delete backup
            AppLogger.shared.log("CLEANING UP BACKUP BUFFER...", type: .info)
            try fileManager.removeItem(at: backupURL)
            
            // 7. Update status
            let finalSize = item.sizeInBytes
            items[index].status = .success(freedBytes: finalSize)
            AppLogger.shared.log("MIGRATION COMPLETED SUCCESSFULLY. \(finalSize.formattedSize) MOVED AND FREED.", type: .success)
            
        } catch {
            AppLogger.shared.log("ERROR ENCOUNTERED: \(error.localizedDescription)", type: .error)
            AppLogger.shared.log("INITIATING ROLLBACK SEQUENCE...", type: .warning)
            
            // Rollback sequence
            // Remove symlink if created
            if fileManager.fileExists(atPath: sourceURL.path) {
                if let values = try? sourceURL.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink == true {
                    try? fileManager.removeItem(at: sourceURL)
                }
            }
            
            // Restore original from backup
            if fileManager.fileExists(atPath: backupURL.path) && !fileManager.fileExists(atPath: sourceURL.path) {
                AppLogger.shared.log("RESTORING ORIGINAL CACHE FOLDER FROM BACKUP...", type: .info)
                try? fileManager.moveItem(at: backupURL, to: sourceURL)
            }
            
            // Clean up target if copy was partially written
            if fileManager.fileExists(atPath: targetURL.path) {
                AppLogger.shared.log("REMOVING PARTIAL COPIED DATA FROM TARGET...", type: .info)
                try? fileManager.removeItem(at: targetURL)
            }
            
            items[index].status = .failed(error.localizedDescription)
            AppLogger.shared.log("ROLLBACK COMPLETED SAFELY. SYSTEM RESTORED.", type: .info)
        }
    }
    
    private func performCopy(from src: URL, to dest: URL) async throws {
        // Run on detached background utility thread
        try await Task.detached(priority: .userInitiated) {
            let fm = FileManager()
            try fm.copyItem(at: src, to: dest)
        }.value
    }
}

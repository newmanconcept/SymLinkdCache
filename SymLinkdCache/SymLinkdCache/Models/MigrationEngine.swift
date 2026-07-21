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
        self.items = [
            CacheItem(
                name: "XCODE DERIVED DATA",
                bundleIdentifier: "com.apple.dt.Xcode",
                executableName: "Xcode",
                category: .directMigration,
                sourcePath: home.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
                targetSubpath: "Xcode_DerivedData"
            ),
            CacheItem(
                name: "XCODE IOS DEVICESUPPORT",
                bundleIdentifier: "com.apple.dt.Xcode",
                executableName: "Xcode",
                category: .directMigration,
                sourcePath: home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"),
                targetSubpath: "Xcode_iOSDeviceSupport"
            )
        ]
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
        AppLogger.shared.log("STARTING DYNAMIC DISCOVERY OF ALL SYSTEM CACHES...", type: .info)
        checkFDA()
        
        let home = fileManager.homeDirectoryForCurrentUser
        
        // 1. Seed special folders
        var scanTargets: [CacheItem] = [
            CacheItem(
                name: "XCODE DERIVED DATA",
                bundleIdentifier: "com.apple.dt.Xcode",
                executableName: "Xcode",
                category: .directMigration,
                sourcePath: home.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
                targetSubpath: "Xcode_DerivedData"
            ),
            CacheItem(
                name: "XCODE IOS DEVICESUPPORT",
                bundleIdentifier: "com.apple.dt.Xcode",
                executableName: "Xcode",
                category: .directMigration,
                sourcePath: home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"),
                targetSubpath: "Xcode_iOSDeviceSupport"
            ),
            CacheItem(
                name: "ADOBE PREMIERE CACHE",
                bundleIdentifier: "com.adobe.PremierePro",
                executableName: "Adobe Premiere Pro",
                category: .nativeGuidance,
                sourcePath: home.appendingPathComponent("Library/Application Support/Adobe/Common/Media Cache Files"),
                targetSubpath: "Adobe_Media_Cache",
                guidanceSteps: [
                    "Launch Adobe Premiere Pro on your Mac.",
                    "Navigate to Preferences > Media Cache.",
                    "Locate 'Media Cache Files' and click '[ Browse... ]'.",
                    "Choose a folder on your external drive.",
                    "Select 'Move existing media cache files' when prompted."
                ],
                documentationURL: "https://helpx.adobe.com/premiere-pro/using/preferences.html#MediaCache"
            ),
            CacheItem(
                name: "DAVINCI RESOLVE CACHE",
                bundleIdentifier: "com.blackmagic-design.DaVinciResolve",
                executableName: "DaVinci Resolve",
                category: .nativeGuidance,
                sourcePath: home.appendingPathComponent("Library/Application Support/Blackmagic Design/DaVinci Resolve"),
                targetSubpath: "Resolve_Cache",
                guidanceSteps: [
                    "Open DaVinci Resolve.",
                    "Open Preferences (Command + ,).",
                    "Navigate to System > Media Storage.",
                    "Click '[ Add ]' and choose your external drive folder.",
                    "Ensure it is placed at the top of the storage list."
                ],
                documentationURL: "https://www.blackmagicdesign.com/products/davinciresolve"
            )
        ]
        
        // 2. Discover caches in Library/Caches
        let cachesURL = home.appendingPathComponent("Library/Caches")
        do {
            let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
            let directories = try fileManager.contentsOfDirectory(
                at: cachesURL,
                includingPropertiesForKeys: keys,
                options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
            )
            
            for url in directories {
                let resourceValues = try? url.resourceValues(forKeys: Set(keys))
                let isDir = resourceValues?.isDirectory ?? false
                let isSym = resourceValues?.isSymbolicLink ?? false
                
                guard isDir || isSym else { continue }
                
                let folderName = url.lastPathComponent
                if folderName.hasPrefix(".") || folderName == "CloudKit" || folderName == "Desktop" {
                    continue
                }
                
                if scanTargets.contains(where: { $0.sourcePath == url }) {
                    continue
                }
                
                let displayName = knownName(for: folderName) ?? (cleanAppName(from: folderName) + " CACHE")
                
                var bundleId: String? = nil
                var execName: String? = nil
                if folderName.contains("com.") {
                    bundleId = folderName
                    execName = cleanAppName(from: folderName)
                }
                
                scanTargets.append(CacheItem(
                    name: displayName.uppercased(),
                    bundleIdentifier: bundleId,
                    executableName: execName,
                    category: .directMigration,
                    sourcePath: url,
                    targetSubpath: "Caches/\(folderName)"
                ))
            }
        } catch {
            AppLogger.shared.log("FAILED LISTING LIBRARY/CACHES: \(error.localizedDescription)", type: .error)
        }
        
        // 3. Process sizes and filter out empty directories that aren't symlinked
        var activeItems: [CacheItem] = []
        
        for item in scanTargets {
            if fileManager.fileExists(atPath: item.sourcePath.path) {
                var updatedItem = item
                updatedItem.status = .scanning
                
                let runningApps = NSWorkspace.shared.runningApplications
                if let bundleId = item.bundleIdentifier {
                    updatedItem.isRunning = runningApps.contains { $0.bundleIdentifier == bundleId }
                } else if let execName = item.executableName {
                    updatedItem.isRunning = runningApps.contains { $0.localizedName == execName }
                }
                
                do {
                    let size = try await calculateFolderSize(at: item.sourcePath)
                    updatedItem.sizeInBytes = size
                    updatedItem.status = .idle
                    
                    if size > 0 || updatedItem.isSymlinked || updatedItem.category == .nativeGuidance {
                        activeItems.append(updatedItem)
                        AppLogger.shared.log("DISCOVERED: \(updatedItem.name) | SIZE: \(size.formattedSize) \(updatedItem.isSymlinked ? "[LINKED]" : "")", type: .info)
                    }
                } catch {
                    updatedItem.status = .failed(error.localizedDescription)
                    activeItems.append(updatedItem)
                    AppLogger.shared.log("DISCOVERY ERROR (\(item.name)): \(error.localizedDescription)", type: .error)
                }
            }
        }
        
        // Sort: active links first, then size descending
        activeItems.sort { (lhs, rhs) -> Bool in
            if lhs.isSymlinked != rhs.isSymlinked {
                return lhs.isSymlinked && !rhs.isSymlinked
            }
            return lhs.sizeInBytes > rhs.sizeInBytes
        }
        
        self.items = activeItems
        refreshRunningStates()
        isScanning = false
        AppLogger.shared.log("DISCOVERY COMPLETE. DETECTED \(activeItems.count) CACHES.", type: .success)
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
    
    private func cleanAppName(from folderName: String) -> String {
        let parts = folderName.components(separatedBy: ".")
        if parts.count >= 2 {
            for part in parts.reversed() {
                let cleanPart = part.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanPart != "client" && cleanPart != "caches" && cleanPart != "desktop" && cleanPart != "helper" && cleanPart != "mac" && cleanPart != "macos" && !cleanPart.isEmpty {
                    return part.capitalized
                }
            }
            return parts.last!.capitalized
        }
        return folderName.capitalized
    }
    
    private func knownName(for folderName: String) -> String? {
        let lower = folderName.lowercased()
        if lower.contains("com.spotify.client") { return "SPOTIFY CACHE" }
        if lower.contains("com.figma.desktop") { return "FIGMA CLIENT CACHE" }
        if lower.contains("google/chrome") || lower.contains("com.google.chrome") { return "CHROME CACHE" }
        if lower.contains("com.tinyspeck.slackmacgap") { return "SLACK CONTAINER CACHE" }
        if lower.contains("com.apple.dt.xcode") { return "XCODE CACHE" }
        return nil
    }
}

//
//  ControlDeckView.swift
//  SymLinkdCache
//
//  Created by Antigravity on 16/07/2026.
//

import SwiftUI

public struct ControlDeckView: View {
    public let item: CacheItem
    @ObservedObject public var engine: MigrationEngine
    @ObservedObject private var logger = AppLogger.shared
    
    public init(item: CacheItem, engine: MigrationEngine) {
        self.item = item
        self.engine = engine
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Upper Panel: Control Deck (changes dynamically)
            ZStack {
                if case .success(let freedBytes) = item.status {
                    successScreen(freedBytes: freedBytes)
                } else {
                    mainControlContent()
                }
            }
            .frame(maxHeight: .infinity)
            
            // Separator line
            Rectangle()
                .fill(Color.starkBorder)
                .frame(height: 1)
            
            // Lower Panel: Terminal Console
            terminalConsoleView()
                .frame(height: 180)
        }
        .background(Color.starkBg)
    }
    
    // MARK: - Success Screen (Inverted Black & White)
    private func successScreen(freedBytes: Int64) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("MIGRATION COMPLETE")
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundColor(.black)
                .tracking(2)
            
            VStack(spacing: 8) {
                Text("SUCCESS: +\(freedBytes.formattedSize)")
                    .font(.system(.largeTitle, design: .monospaced).bold())
                    .foregroundColor(.black)
                
                Text("FREED SYSTEM STORAGE")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Color(white: 0.2))
                    .tracking(1)
            }
            
            Text("[ DIRECTORY MOVED & SYMLINKED SUCCESSFULLY ]")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(
                    Rectangle()
                        .stroke(Color.black, lineWidth: 1)
                )
            
            Spacer()
            
            Button(action: {
                if let idx = engine.items.firstIndex(where: { $0.id == item.id }) {
                    engine.items[idx].status = .idle
                }
            }) {
                Text("[ OK / DISMISS ]")
            }
            .buttonStyle(StarkButtonStyle(isInverted: false))
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white) // Inverted background
    }
    
    // MARK: - Main Control Content
    private func mainControlContent() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Details
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundColor(.white)
                    
                    Text("CATEGORY: \(item.category.rawValue)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.starkSubtext)
                }
                .padding(.bottom, 10)
                
                if item.category == .directMigration {
                    directMigrationPanel()
                } else {
                    nativeGuidancePanel()
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Direct Migration Panel
    private func directMigrationPanel() -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // Path readouts
            VStack(alignment: .leading, spacing: 10) {
                pathBlock(title: "ORIGINAL CACHE PATH", path: item.sourcePath.path)
                
                if let targetRoot = engine.targetVolumeURL {
                    let destPath = targetRoot.appendingPathComponent(item.targetSubpath).path
                    pathBlock(title: "TARGET DESTINATION", path: destPath)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TARGET DESTINATION")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundColor(.starkSubtext)
                        Text("[ NO TARGET VOLUME SELECTED - CLICK 'SELECT TARGET VOLUME' IN LEFT PANE ]")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.starkWarning)
                    }
                }
            }
            
            // Safety Interlock
            HStack(spacing: 12) {
                if item.isRunning {
                    HStack(spacing: 8) {
                        StarkStatusDot(color: .starkAlert, flash: true)
                        Text("APP RUNNING")
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundColor(.starkAlert)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(
                        Rectangle()
                            .stroke(Color.starkAlert, lineWidth: 1)
                    )
                    
                    Button(action: {
                        engine.forceQuit(item)
                    }) {
                        Text("[ FORCE QUIT ]")
                    }
                    .buttonStyle(StarkButtonStyle())
                } else {
                    HStack(spacing: 8) {
                        StarkStatusDot(color: .starkSuccess, flash: false)
                        Text("APP STOPPED / SAFE")
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundColor(.starkSuccess)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(
                        Rectangle()
                            .stroke(Color.starkBorder, lineWidth: 1)
                    )
                }
            }
            .padding(.vertical, 4)
            
            // Action Button
            if item.status == .migrating {
                Text("[ MIGRATING... PLEASE WAIT ]")
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundColor(.starkSubtext)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        Rectangle()
                            .stroke(Color.starkBorder, lineWidth: 1)
                    )
            } else if case .failed(let errMsg) = item.status {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        StarkStatusDot(color: .starkAlert)
                        Text("MIGRATION FAILED: \(errMsg)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.starkAlert)
                    }
                    
                    Button(action: {
                        Task {
                            await engine.migrate(item)
                        }
                    }) {
                        Text("[ RETRY INITIATE MIGRATION ]")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StarkButtonStyle(isInverted: true))
                }
            } else {
                Button(action: {
                    Task {
                        await engine.migrate(item)
                    }
                }) {
                    Text(engine.targetVolumeURL == nil ? "[ VOLUME REQUIRED ]" : "[ INITIATE MIGRATION ]")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(StarkButtonStyle(isInverted: engine.targetVolumeURL != nil && !item.isRunning, isDisabled: engine.targetVolumeURL == nil || item.isRunning))
                .disabled(engine.targetVolumeURL == nil || item.isRunning)
            }
        }
    }
    
    // MARK: - Native Guidance Panel
    private func nativeGuidancePanel() -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // Status Readout
            HStack(spacing: 8) {
                StarkStatusDot(color: .starkWarning)
                Text("NATIVE CONFIGURATION REQUIRED")
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundColor(.starkWarning)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay(
                Rectangle()
                    .stroke(Color.starkWarning, lineWidth: 1)
            )
            
            // Steps list
            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<item.guidanceSteps.count, id: \.self) { idx in
                    HStack(alignment: .top, spacing: 10) {
                        Text(circledNumber(idx + 1))
                            .font(.system(.body, design: .default))
                            .foregroundColor(.starkText)
                        Text(item.guidanceSteps[idx])
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.starkZinc)
                    }
                }
            }
            .padding(.vertical, 10)
            
            // Actions
            HStack(spacing: 12) {
                Button(action: {
                    if let execName = item.executableName {
                        NSWorkspace.shared.launchApplication(execName)
                        AppLogger.shared.log("LAUNCH SIGNAL SENT TO: \(execName)", type: .info)
                    }
                }) {
                    Text("[ LAUNCH APPLICATION ]")
                }
                .buttonStyle(StarkButtonStyle(isInverted: true))
                
                if let docString = item.documentationURL, let docURL = URL(string: docString) {
                    Button(action: {
                        NSWorkspace.shared.open(docURL)
                        AppLogger.shared.log("OPENING DOCUMENTATION IN BROWSER...", type: .info)
                    }) {
                        Text("[ VIEW DOCUMENTATION ]")
                    }
                    .buttonStyle(StarkButtonStyle())
                }
            }
        }
    }
    
    private func pathBlock(title: String, path: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundColor(.starkSubtext)
            Text(path)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(2)
                .padding(8)
                .background(Color.starkPanel)
                .overlay(
                    Rectangle()
                        .stroke(Color.starkBorder, lineWidth: 1)
                )
        }
    }
    
    private func circledNumber(_ n: Int) -> String {
        let circles = ["⓪", "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩"]
        if n >= 0 && n < circles.count {
            return circles[n]
        }
        return "\(n)"
    }
    
    // MARK: - Terminal Console View
    private func terminalConsoleView() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Console Header
            HStack {
                Text("SYSTEM TERMINAL LOG")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    logger.clear()
                }) {
                    Text("[ CLEAR ]")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.starkSubtext)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.starkPanel)
            .overlay(
                Rectangle()
                    .stroke(Color.starkBorder, lineWidth: 1)
            )
            
            // Console Rows
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(0..<logger.logs.count, id: \.self) { idx in
                            let log = logger.logs[idx]
                            let color = logColor(for: log)
                            Text(log)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(color)
                                .id(idx)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.starkBg)
                .onChange(of: logger.logs.count) { _ in
                    if !logger.logs.isEmpty {
                        withAnimation {
                            proxy.scrollTo(logger.logs.count - 1, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    private func logColor(for line: String) -> Color {
        if line.contains("[ERR ]") {
            return .starkAlert
        } else if line.contains("[WARN]") {
            return .starkWarning
        } else if line.contains("[OK  ]") {
            return .starkSuccess
        } else {
            return .starkSubtext
        }
    }
}

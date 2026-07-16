//
//  FullDiskAccessView.swift
//  SymLinkdCache
//
//  Created by Antigravity on 16/07/2026.
//

import SwiftUI

public struct FullDiskAccessView: View {
    @ObservedObject public var engine: MigrationEngine
    
    public init(engine: MigrationEngine) {
        self.engine = engine
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    StarkStatusDot(color: .starkWarning, flash: true)
                    Text("PERMISSION REQUIRED")
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundColor(.starkWarning)
                        .tracking(1)
                }
                
                Text("FULL DISK ACCESS RESTRICTED")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 10)
            
            // Core Text Block
            VStack(alignment: .leading, spacing: 14) {
                Text("To safely move applications' caches and establish symbolic links, macOS requires this utility to run with Full Disk Access.")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.starkSubtext)
                    .lineSpacing(4)
                
                VStack(alignment: .leading, spacing: 10) {
                    instructionRow(num: "①", text: "Open macOS System Settings.")
                    instructionRow(num: "②", text: "Go to Privacy & Security > Full Disk Access.")
                    instructionRow(num: "③", text: "Find and toggle 'SymLinkdCache' to ON.")
                    instructionRow(num: "④", text: "If not listed, drag the app into the window or use the '+' button.")
                }
                .padding(.vertical, 8)
            }
            .padding(16)
            .background(Color.starkPanel)
            .overlay(
                Rectangle()
                    .stroke(Color.starkBorder, lineWidth: 1)
            )
            
            // Actions
            HStack(spacing: 16) {
                Button(action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                        AppLogger.shared.log("REQUESTED SYSTEM SETTINGS -> FULL DISK ACCESS", type: .info)
                    }
                }) {
                    Text("[ OPEN PRIVACY SETTINGS ]")
                }
                .buttonStyle(StarkButtonStyle(isInverted: true))
                
                Button(action: {
                    engine.checkFDA()
                    if engine.hasFullDiskAccess {
                        AppLogger.shared.log("FULL DISK ACCESS PERMISSION ACQUIRED.", type: .success)
                    } else {
                        AppLogger.shared.log("PERMISSION CHECK: RESTRICTED.", type: .warning)
                    }
                }) {
                    Text("[ CHECK STATUS ]")
                }
                .buttonStyle(StarkButtonStyle())
            }
        }
        .padding(32)
        .background(Color.starkBg)
        .overlay(
            Rectangle()
                .stroke(Color.starkBorder, lineWidth: 2)
                .padding(6)
        )
    }
    
    private func instructionRow(num: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(num)
                .font(.system(.body, design: .default))
                .foregroundColor(.white)
            Text(text)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.starkZinc)
        }
    }
}

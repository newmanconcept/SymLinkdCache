//
//  ContentView.swift
//  SymLinkdCache
//
//  Created by Az Newman on 16/07/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var engine = MigrationEngine()
    @State private var selectedItemId: UUID? = nil
    @State private var showFDAOverlay = false
    
    var body: some View {
        ZStack {
            // Main Two-Pane Split Layout
            HStack(spacing: 0) {
                // LEFT PANE: App Selector Matrix (320px width)
                leftPaneView()
                    .frame(width: 380)
                
                // 1px Solid Vertical Line Separator
                Rectangle()
                    .fill(Color.starkBorder)
                    .frame(width: 1)
                    .edgesIgnoringSafeArea(.all)
                
                // RIGHT PANE: Control Deck
                rightPaneView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.starkBg)
            
            // Full Disk Access Overlay Sheet
            if showFDAOverlay {
                Color.starkBg.opacity(0.9)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation { showFDAOverlay = false }
                        }) {
                            Text("[ CLOSE PANEL ]")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.starkSubtext)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 20)
                        .padding(.trailing, 20)
                    }
                    
                    Spacer()
                    FullDiskAccessView(engine: engine)
                    Spacer()
                }
                .transition(.scale)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            Task {
                await engine.scanAll()
                // If scanning finds FDA is missing, alert the user via console or UI
                if !engine.hasFullDiskAccess {
                    AppLogger.shared.log("FULL DISK ACCESS WARNING: PERMISSIONS ARE RESTRICTED.", type: .warning)
                }
            }
        }
        // Monitor FDA status to automatically hide overlay if granted
        .onChange(of: engine.hasFullDiskAccess) { hasAccess in
            if hasAccess && showFDAOverlay {
                withAnimation { showFDAOverlay = false }
            }
        }
    }
    
    // MARK: - Left Pane View
    private func leftPaneView() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // App Title Block
            VStack(alignment: .leading, spacing: 4) {
                Text("SYMLINKDCACHE")
                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(2)
                
                Text("EXTERNAL STORAGE CACHE RELOCATOR")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.starkSubtext)
                    .tracking(1)
            }
            .padding(.top, 24)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            
            // Volume Status Block
            VStack(alignment: .leading, spacing: 10) {
                Text("TARGET VOLUME")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundColor(.starkSubtext)
                
                if let url = engine.targetVolumeURL {
                    HStack(spacing: 8) {
                        Text(url.lastPathComponent.uppercased())
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button(action: selectTargetVolume) {
                            Text("[ CHANGE ]")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.starkSubtext)
                    }
                    .padding(8)
                    .background(Color.starkPanel)
                    .overlay(Rectangle().stroke(Color.starkBorder, lineWidth: 1))
                } else {
                    Button(action: selectTargetVolume) {
                        HStack {
                            Spacer()
                            Text("[ SELECT TARGET VOLUME ]")
                                .font(.system(.body, design: .monospaced).bold())
                            Spacer()
                        }
                    }
                    .buttonStyle(StarkButtonStyle(isInverted: true))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            // Sub-Toolbar Actions (Scan & FDA status)
            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        await engine.scanAll()
                    }
                }) {
                    Text(engine.isScanning ? "[ SCANNING... ]" : "[ RE-SCAN SYSTEM ]")
                }
                .buttonStyle(StarkButtonStyle(isDisabled: engine.isScanning))
                .disabled(engine.isScanning)
                
                Spacer()
                
                // FDA Indicator status button
                Button(action: {
                    engine.checkFDA()
                    withAnimation { showFDAOverlay = true }
                }) {
                    HStack(spacing: 6) {
                        StarkStatusDot(color: engine.hasFullDiskAccess ? .starkSuccess : .starkWarning, flash: !engine.hasFullDiskAccess)
                        Text(engine.hasFullDiskAccess ? "FDA: OK" : "FDA: RESTRICTED")
                            .font(.system(size: 10, design: .monospaced).bold())
                            .foregroundColor(engine.hasFullDiskAccess ? .starkSuccess : .starkWarning)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            // App Selector Grid Section
            ScrollView {
                VStack(spacing: 0) {
                    let validItems = engine.items
                    let maxSize = validItems.map { $0.sizeInBytes }.max() ?? 1
                    
                    if validItems.isEmpty {
                        Text("[ NO CACHES DETECTED ]")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.starkSubtext)
                            .padding(.top, 40)
                    } else {
                        ForEach(validItems) { item in
                            let fillRatio = maxSize > 0 ? Double(item.sizeInBytes) / Double(maxSize) : 0.0
                            let isSelected = selectedItemId == item.id
                            
                            AppSelectorRow(item: item, fillRatio: fillRatio, isSelected: isSelected)
                                .onTapGesture {
                                    selectedItemId = item.id
                                }
                        }
                    }
                }
            }
            .overlay(
                Rectangle()
                    .stroke(Color.starkBorder, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.starkBg)
    }
    
    // MARK: - Right Pane View
    private func rightPaneView() -> some View {
        Group {
            if let selectedId = selectedItemId,
               let item = engine.items.first(where: { $0.id == selectedId }) {
                ControlDeckView(item: item, engine: engine)
            } else {
                // Default Stark Control Deck State (Inspired by classic audio gear grids)
                VStack(spacing: 20) {
                    Spacer()
                    
                    // Audio Dial / Geometric Motif Placeholder
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(Color.starkBorder, lineWidth: 1)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 8]))
                                .foregroundColor(.starkBorder)
                                .frame(width: 100, height: 100)
                            
                            // Audio dial needle
                            Rectangle()
                                .fill(Color.starkSubtext)
                                .frame(width: 2, height: 36)
                                .offset(y: -18)
                                .rotationEffect(.degrees(45))
                        }
                        
                        Text("[ CONTROL DECK READY ]")
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundColor(.white)
                            .tracking(1)
                        
                        Text("SELECT AN APPLICATION MATRIX ELEMENT TO BEGIN")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.starkSubtext)
                    }
                    
                    Spacer()
                    
                    // Small inline console view even when nothing is selected
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle()
                            .fill(Color.starkBorder)
                            .frame(height: 1)
                        
                        HStack {
                            Text("CONSOLE RUNNING...")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.starkSubtext)
                            Spacer()
                            StarkStatusDot(color: .starkSuccess, flash: false)
                        }
                        .padding(12)
                        .background(Color.starkPanel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.starkBg)
            }
        }
    }
    
    // MARK: - Native File Picker Trigger
    private func selectTargetVolume() {
        let panel = NSOpenPanel()
        panel.title = "SELECT TARGET VOLUME FOR CACHES"
        panel.showsResizeIndicator = true
        panel.showsHiddenFiles = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                engine.targetVolumeURL = url
            }
        }
    }
}

#Preview {
    ContentView()
}

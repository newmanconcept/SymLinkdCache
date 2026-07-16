//
//  AppSelectorRow.swift
//  SymLinkdCache
//
//  Created by Antigravity on 16/07/2026.
//

import SwiftUI

public struct AppSelectorRow: View {
    public let item: CacheItem
    public let fillRatio: Double
    public let isSelected: Bool
    
    public init(item: CacheItem, fillRatio: Double, isSelected: Bool) {
        self.item = item
        self.fillRatio = fillRatio
        self.isSelected = isSelected
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Stark Indicator
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.starkText : Color.starkBorder, lineWidth: 1.5)
                    .frame(width: 14, height: 14)
                
                if item.isSymlinked {
                    Circle()
                        .fill(Color.starkSuccess)
                        .frame(width: 8, height: 8)
                } else if fillRatio > 0 {
                    let size = max(4.0, 10.0 * fillRatio)
                    Circle()
                        .fill(isSelected ? Color.starkText : Color.starkSubtext)
                        .frame(width: size, height: size)
                }
            }
            .frame(width: 16, height: 16)
            
            // Application Name
            Text(item.name)
                .font(.system(.body, design: .monospaced).bold())
                .foregroundColor(isSelected ? Color.starkText : Color.starkSubtext)
            
            // Dot Leader Line
            DottedLeader()
            
            // Size & Link status
            HStack(spacing: 8) {
                if item.isSymlinked {
                    Text("LINKED")
                        .font(.system(.caption, design: .monospaced).bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.starkSuccess)
                        .foregroundColor(Color.starkBg)
                } else {
                    Text(item.sizeInBytes.formattedSize)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(isSelected ? Color.starkText : Color.starkSubtext)
                }
                
                // If it is running, show a warning dot
                if item.isRunning {
                    StarkStatusDot(color: Color.starkWarning, flash: true)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            Group {
                if isSelected {
                    Color.starkPanel
                } else {
                    Color.clear
                }
            }
        )
        .overlay(
            Group {
                if isSelected {
                    Rectangle()
                        .stroke(Color.starkBorder, lineWidth: 1)
                } else {
                    EmptyView()
                }
            }
        )
        .contentShape(Rectangle())
    }
}

// MARK: - 파일 설명
// SidebarView: 아이콘 사이드바 컴포넌트
// - Xcode/Finder 스타일의 아이콘 전용 사이드바
// - 마우스 오버 시 툴팁 표시
// - 선택된 탭 하이라이트

import SwiftUI

struct SidebarView: View {
    // MARK: - Properties

    @Binding var selectedTab: SidebarTab
    @State private var hoveredTab: SidebarTab?

    // MARK: - Constants

    private let sidebarWidth: CGFloat = 48
    private let iconSize: CGFloat = 20
    private let buttonSize: CGFloat = 36

    // MARK: - Body

    var body: some View {
        VStack(spacing: 4) {
            ForEach(SidebarTab.allCases) { tab in
                sidebarButton(for: tab)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .frame(width: sidebarWidth)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Subviews

    @ViewBuilder
    private func sidebarButton(for tab: SidebarTab) -> some View {
        let isSelected = selectedTab == tab
        let isHovered = hoveredTab == tab
        let isStatistics = tab == .statistics

        Button {
            if !isStatistics {
                selectedTab = tab
            }
        } label: {
            Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(buttonForegroundStyle(isSelected: isSelected, isDisabled: isStatistics))
                .frame(width: buttonSize, height: buttonSize)
                .background(buttonBackground(isSelected: isSelected, isHovered: isHovered))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isStatistics)
        .onHover { hovering in
            hoveredTab = hovering ? tab : nil
        }
        .help(isStatistics ? "\(tab.rawValue) (준비 중)" : tab.rawValue)
    }

    /// 버튼 전경색 스타일
    private func buttonForegroundStyle(isSelected: Bool, isDisabled: Bool) -> some ShapeStyle {
        if isDisabled {
            return Color.secondary.opacity(0.4)
        }
        return isSelected ? Color.accentColor : Color.secondary
    }

    /// 버튼 배경
    @ViewBuilder
    private func buttonBackground(isSelected: Bool, isHovered: Bool) -> some View {
        if isSelected {
            Color.accentColor.opacity(0.15)
        } else if isHovered {
            Color.primary.opacity(0.05)
        } else {
            Color.clear
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 0) {
        SidebarView(selectedTab: .constant(.sessions))
        Divider()
        Text("Content Area")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(width: 600, height: 400)
}

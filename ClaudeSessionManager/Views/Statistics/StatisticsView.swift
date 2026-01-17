// MARK: - 파일 설명
// StatisticsView: 통계 탭 메인 뷰
// - 전체 토큰 사용량 요약
// - 프로젝트별 사용량 목록
// - 캐시 효율 표시

import SwiftUI

struct StatisticsView: View {
    @StateObject private var viewModel = StatisticsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 전체 요약 카드
                totalSummaryCard

                // 프로젝트별 사용량
                projectsSection
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Total Summary Card

    private var totalSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("토큰 사용량 요약")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: 24) {
                StatCard(
                    title: "총 토큰",
                    value: viewModel.totalStats.formattedTotal,
                    icon: "sum",
                    color: .blue
                )

                StatCard(
                    title: "입력",
                    value: viewModel.totalStats.formattedInput,
                    icon: "arrow.down.circle",
                    color: .green
                )

                StatCard(
                    title: "출력",
                    value: viewModel.totalStats.formattedOutput,
                    icon: "arrow.up.circle",
                    color: .orange
                )

                StatCard(
                    title: "캐시 효율",
                    value: viewModel.totalStats.formattedCacheHitRate,
                    icon: "memorychip",
                    color: .purple
                )
            }

            HStack(spacing: 16) {
                Label("\(viewModel.totalStats.totalSessions) 세션", systemImage: "list.bullet.rectangle")
                Label("\(viewModel.totalStats.totalProjects) 프로젝트", systemImage: "folder")
                Label("캐시 \(viewModel.totalStats.formattedCacheRead)", systemImage: "bolt.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        }
    }

    // MARK: - Projects Section

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("프로젝트별 사용량")
                .font(.headline)
                .foregroundStyle(.primary)

            if viewModel.projectUsages.isEmpty {
                emptyProjectsView
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.projectUsages) { project in
                        ProjectUsageRow(project: project)
                    }
                }
            }
        }
    }

    private var emptyProjectsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("아직 사용량 데이터가 없습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Claude Code 세션을 진행하면 통계가 표시됩니다.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.1))
        }
    }
}

// MARK: - Project Usage Row

private struct ProjectUsageRow: View {
    let project: ProjectUsage

    var body: some View {
        HStack(spacing: 12) {
            // 프로젝트 아이콘
            Image(systemName: "folder.fill")
                .font(.system(size: 16))
                .foregroundStyle(.blue)
                .frame(width: 24)

            // 프로젝트 이름
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(project.sessionCount) 세션")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // 토큰 사용량
            HStack(spacing: 16) {
                tokenLabel("↓", value: formatCount(project.totalInput), color: .green)
                tokenLabel("↑", value: formatCount(project.totalOutput), color: .orange)

                Text(project.formattedTotal)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
    }

    private func tokenLabel(_ symbol: String, value: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(symbol)
                .foregroundStyle(color)
            Text(value)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 11, design: .monospaced))
        .frame(width: 50, alignment: .trailing)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}

// MARK: - Preview

#Preview {
    StatisticsView()
        .frame(width: 600, height: 500)
}

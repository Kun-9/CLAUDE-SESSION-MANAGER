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
                    title: "입력",
                    value: viewModel.totalStats.formattedTotalInput,
                    icon: "arrow.down.circle",
                    color: .green,
                    description: "Claude에게 전송한 총 입력 토큰 수입니다. 시스템 프롬프트, 대화 히스토리, 파일 내용, 캐시 토큰이 포함됩니다.\n입력 = Input + CacheWrite + CacheRead"
                )

                StatCard(
                    title: "출력",
                    value: viewModel.totalStats.formattedOutput,
                    icon: "arrow.up.circle",
                    color: .orange,
                    description: "Claude가 생성한 응답의 토큰 수입니다. 코드, 설명, 도구 호출 등이 포함됩니다."
                )

                StatCard(
                    title: "실제 사용량",
                    value: viewModel.totalStats.formattedActualUsage,
                    icon: "sum",
                    color: .blue,
                    description: "비용 기준으로 계산한 실제 토큰 사용량입니다. Cache Write는 1.25배, Cache Read는 0.1배로 환산됩니다.\n실제 사용량 = Input×1 + CacheW×1.25 + CacheR×0.1 + Output"
                )

                StatCard(
                    title: "캐시 히트율",
                    value: viewModel.totalStats.formattedCacheSavingsRate,
                    icon: "memorychip",
                    color: .purple,
                    description: "캐시로 인한 비용 절감률입니다. Cache Write는 1.25배, Cache Read는 0.1배 비용으로 계산합니다.\n절감률 = (기본비용 - 실제비용) / 기본비용 × 100"
                )
            }

            HStack(spacing: 16) {
                Label("\(viewModel.totalStats.totalSessions) 세션", systemImage: "list.bullet.rectangle")
                Label("\(viewModel.totalStats.totalProjects) 프로젝트", systemImage: "folder")
                Label("캐시W \(viewModel.totalStats.formattedCacheCreation)", systemImage: "square.and.arrow.down")
                Label("캐시R \(viewModel.totalStats.formattedCacheRead)", systemImage: "bolt.circle")
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
    let description: String

    @State private var showingInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showingInfo.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingInfo, arrowEdge: .top) {
                    StatCardInfoPopover(description: description, color: color)
                }
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

// MARK: - Stat Card Info Popover

/// 공식 너비 측정용 PreferenceKey
private struct FormulaWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 200
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// StatCard info 버튼 클릭 시 표시되는 팝오버
/// 공식이 포함된 경우 하이라이팅 처리
private struct StatCardInfoPopover: View {
    let description: String
    let color: Color

    @State private var formulaWidth: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 공식 (한 줄로 표시, 너비 기준)
            if !formulaLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(formulaLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(color)
                            .fixedSize()
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(key: FormulaWidthKey.self, value: geo.size.width)
                                }
                            )
                    }
                }
            }

            // 설명 텍스트 (공식 너비에 맞춰 wrap)
            ForEach(descriptionLines, id: \.self) { line in
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: formulaWidth, alignment: .leading)
            }
        }
        .padding(14)
        .onPreferenceChange(FormulaWidthKey.self) { width in
            formulaWidth = max(width, 200)
        }
    }

    private var lines: [String] {
        description.components(separatedBy: "\n")
    }

    /// 공식이 아닌 설명 라인들
    private var descriptionLines: [String] {
        lines.filter { !isFormula($0) }
    }

    /// 공식 라인들
    private var formulaLines: [String] {
        lines.filter { isFormula($0) }
    }

    /// 공식인지 판단 (= 기호 포함)
    private func isFormula(_ text: String) -> Bool {
        text.contains(" = ")
    }
}

// MARK: - Project Usage Info Popover

/// 프로젝트별 사용량 info 팝오버
/// "총"은 .primary, "실제"는 .blue로 하이라이팅
private struct ProjectUsageInfoPopover: View {
    let project: ProjectUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 공식
            formulaRow(label: "Total", formula: "= Input + Output + CacheW + CacheR", color: .green)
            formulaRow(label: "Actual", formula: "= In×1 + CacheW×1.25 + CacheR×0.1 + Out", color: .blue)

            Divider()
                .padding(.vertical, 2)

            // 세부 값
            detailRow(label: "Input", value: project.totalInput)
            detailRow(label: "Output", value: project.totalOutput)
            detailRow(label: "CacheWrite", value: project.cacheCreation)
            detailRow(label: "CacheRead", value: project.cacheRead)

            Divider()
                .padding(.vertical, 2)

            // 합계
            HStack {
                Text("Total")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.green)
                Spacer()
                Text(formatCount(project.totalTokens))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.green)
            }

            HStack {
                Text("Actual")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.blue)
                Spacer()
                Text(formatCount(Int(project.actualTokenUsage)))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.blue)
            }
        }
        .padding(14)
        .frame(minWidth: 200)
    }

    private func formulaRow(label: String, formula: String, color: Color) -> some View {
        Text("\(label) \(formula)")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(color)
    }

    private func detailRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatCount(value))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func formatCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
}

// MARK: - Project Usage Row

private struct ProjectUsageRow: View {
    let project: ProjectUsage

    @State private var showingInfo = false

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

            // 토큰 사용량: 총 사용량, 실제 사용량
            HStack(spacing: 12) {
                tokenLabel("총", value: project.formattedTotal, color: .green)
                tokenLabel("실제", value: project.formattedActualUsage, color: .blue)

                // Info 버튼
                Button {
                    showingInfo.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
                    ProjectUsageInfoPopover(project: project)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
    }

    private func tokenLabel(_ label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(color)
        }
        .font(.system(size: 11, design: .monospaced))
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

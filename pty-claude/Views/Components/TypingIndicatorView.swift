// MARK: - 파일 설명
// TypingIndicatorView: 응답 생성 중임을 나타내는 점 애니메이션 인디케이터
// - 세 개의 점이 순차적으로 위아래로 애니메이션
// - Assistant 응답 대기 시 표시

import SwiftUI

/// 타이핑 중임을 나타내는 점 애니메이션 인디케이터
struct TypingIndicatorView: View {
    // MARK: - Properties

    @State private var isAnimating = false

    /// 점 색상 (기본: 녹색)
    var dotColor: Color = .green

    /// 점 크기
    var dotSize: CGFloat = 8

    /// 점 간격
    var spacing: CGFloat = 6

    // MARK: - Body

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .fill(dotColor)
                    .frame(width: dotSize, height: dotSize)
                    .offset(y: isAnimating ? -4 : 4)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        TypingIndicatorView()
        TypingIndicatorView(dotColor: .blue, dotSize: 10)
    }
    .padding()
}

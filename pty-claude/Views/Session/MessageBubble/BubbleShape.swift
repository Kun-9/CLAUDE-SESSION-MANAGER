// MARK: - 파일 설명
// BubbleShape: iMessage 스타일 말풍선 Shape
// - 둥근 모서리 + 꼬리 (왼쪽/오른쪽/없음)
// - SwiftUI Shape 프로토콜 구현

import SwiftUI

/// 말풍선 꼬리 방향
enum BubbleTailDirection {
    case left
    case right
    case none
}

/// iMessage 스타일 말풍선 Shape
struct BubbleShape: Shape {
    let tailDirection: BubbleTailDirection
    let cornerRadius: CGFloat

    init(tailDirection: BubbleTailDirection, cornerRadius: CGFloat = 16) {
        self.tailDirection = tailDirection
        self.cornerRadius = cornerRadius
    }

    func path(in rect: CGRect) -> Path {
        switch tailDirection {
        case .left:
            return leftTailPath(in: rect)
        case .right:
            return rightTailPath(in: rect)
        case .none:
            return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .path(in: rect)
        }
    }

    // MARK: - Private Path Builders

    /// 왼쪽 꼬리 말풍선 경로
    private func leftTailPath(in rect: CGRect) -> Path {
        let tailWidth: CGFloat = 8
        let tailHeight: CGFloat = 12
        let tailOffset: CGFloat = 14

        // 말풍선 본체 영역 (꼬리 공간 제외)
        let bubbleRect = CGRect(
            x: rect.minX + tailWidth,
            y: rect.minY,
            width: rect.width - tailWidth,
            height: rect.height
        )

        var path = Path()

        // 둥근 사각형 본체
        path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius), style: .continuous)

        // 꼬리 (왼쪽 하단)
        let tailTop = rect.maxY - tailOffset - tailHeight
        let tailBottom = rect.maxY - tailOffset

        path.move(to: CGPoint(x: bubbleRect.minX, y: tailTop))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: tailBottom - 4),
            control: CGPoint(x: bubbleRect.minX - tailWidth + 2, y: tailTop + tailHeight / 2)
        )
        path.addQuadCurve(
            to: CGPoint(x: bubbleRect.minX, y: tailBottom),
            control: CGPoint(x: bubbleRect.minX - 2, y: tailBottom)
        )
        path.closeSubpath()

        return path
    }

    /// 오른쪽 꼬리 말풍선 경로
    private func rightTailPath(in rect: CGRect) -> Path {
        let tailWidth: CGFloat = 8
        let tailHeight: CGFloat = 12
        let tailOffset: CGFloat = 14

        // 말풍선 본체 영역 (꼬리 공간 제외)
        let bubbleRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width - tailWidth,
            height: rect.height
        )

        var path = Path()

        // 둥근 사각형 본체
        path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius), style: .continuous)

        // 꼬리 (오른쪽 하단)
        let tailTop = rect.maxY - tailOffset - tailHeight
        let tailBottom = rect.maxY - tailOffset

        path.move(to: CGPoint(x: bubbleRect.maxX, y: tailTop))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: tailBottom - 4),
            control: CGPoint(x: bubbleRect.maxX + tailWidth - 2, y: tailTop + tailHeight / 2)
        )
        path.addQuadCurve(
            to: CGPoint(x: bubbleRect.maxX, y: tailBottom),
            control: CGPoint(x: bubbleRect.maxX + 2, y: tailBottom)
        )
        path.closeSubpath()

        return path
    }
}

// MARK: - Preview

#Preview("Bubble Shapes") {
    VStack(spacing: 20) {
        Text("Left Tail")
            .padding()
            .background(BubbleShape(tailDirection: .left).fill(Color.green.opacity(0.15)))
            .frame(width: 200, height: 60)

        Text("Right Tail")
            .padding()
            .background(BubbleShape(tailDirection: .right).fill(Color.blue.opacity(0.15)))
            .frame(width: 200, height: 60)

        Text("No Tail")
            .padding()
            .background(BubbleShape(tailDirection: .none).fill(Color.gray.opacity(0.15)))
            .frame(width: 200, height: 60)
    }
    .padding()
}

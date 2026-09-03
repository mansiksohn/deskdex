import SwiftUI
import DeskDexKit

/// `docs/design.md` "도감 (홈)": "실루엣은 카테고리 아이콘이 아니라 bbox
/// 형태를 채운 단색 실루엣으로 간다."
///
/// **알려진 갭**: 그 형태대로 하려면 `.none` 노드도 bbox를 들고 있어야 하는데,
/// `docs/design.md`의 이미지 참조 스키마는 `.none`에 필드를 두지 않는다
/// (`{ type: 'none' }`). 그래서 지금은 bbox 대신 카테고리별로 세로/가로
/// 비율만 살짝 다르게 준 사각 블롭이다 — 진짜 bbox 실루엣이 아니라 그
/// 방향으로 가는 자리표시자. bbox를 유지하려면 데이터 모델 쪽 결정이
/// 먼저 필요하다.
struct SilhouetteView: View {
    var category: NodeCategory

    private var aspectRatio: CGFloat {
        switch category {
        case .display, .book, .paper, .textile: return 0.75
        case .cablePower, .writing: return 1.6
        default: return 1.0
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.primary.opacity(0.16))
            .aspectRatio(aspectRatio, contentMode: .fit)
    }
}

#Preview {
    SilhouetteView(category: .drinkware)
        .padding()
}

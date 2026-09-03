import SwiftUI
import DeskDexKit

/// 카테고리는 명명 스와이프의 두 필수 필드 중 하나다 (`docs/design.md`
/// "필수 필드는 이름과 카테고리뿐"). 폼의 드롭다운이 아니라 가로 스크롤
/// 칩으로 둔 것은 같은 문서의 "폼 채우기로 만들지 않는다"를 따른 것 —
/// 탭 한 번으로 끝나야 목표 시간(조각당 2초)에 들어간다.
struct CategoryChipRow: View {
    @Binding var selection: NodeCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(NodeCategory.allCases) { category in
                    let isSelected = category == selection
                    Button {
                        selection = category
                    } label: {
                        Text(category.displayName)
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                Capsule()
                                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                            }
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

#Preview {
    CategoryChipRow(selection: .constant(.drinkware))
}

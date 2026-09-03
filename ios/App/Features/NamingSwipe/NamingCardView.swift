import SwiftUI
import DeskDexKit

/// "조각 하나를 크게. AI 추정 이름 미리 채움" (`docs/design.md` "명명 스와이프").
///
/// 실제 사진 로딩(장면 파일에서 bbox로 크롭)은 이 화면의 범위 밖이다 — 아직
/// 촬영·저장 파이프라인이 없다. `.derived`/`.specimen`도 지금은
/// `SilhouetteView`로 대체 표시한다.
struct NamingCardView: View {
    var node: Node
    @Binding var draftLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("#\(node.dexNo)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if node.needsInput {
                    Label("확인 필요", systemImage: "questionmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                Spacer()
                if node.kind == .cluster {
                    Text("군집 · \(node.memberCount)개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SilhouetteView(category: node.category)
                .frame(maxWidth: .infinity)

            TextField("이름", text: $draftLabel)
                .font(.title2.weight(.semibold))
                .textFieldStyle(.plain)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                }

            if !node.labelAI.isEmpty && draftLabel != node.labelAI {
                Text("AI 추정: \(node.labelAI)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        }
    }
}

#Preview {
    NamingCardView(node: SampleData.nodes[0], draftLabel: .constant(SampleData.nodes[0].labelAI))
        .padding()
}

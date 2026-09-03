import SwiftUI
import DeskDexKit

/// `docs/design.md` "2. 명명 스와이프" — "실사용 시간의 대부분이 여기 쓰인다.
/// UX 승부처." 그래서 상호작용을 최대한 줄였다: 카드를 오른쪽으로 밀거나
/// 버튼 두 개(맞음 / 나중에)면 끝난다. 별도 편집 화면은 없다 — 이름 칸을
/// 고친 채로 "맞음"을 누르면 그게 수정이다.
struct NamingSwipeView: View {
    @ObservedObject var viewModel: NamingSwipeViewModel
    @State private var dragOffset: CGSize = .zero

    private let confirmThreshold: CGFloat = 120

    var body: some View {
        VStack(spacing: 24) {
            header

            if let node = viewModel.current {
                NamingCardView(node: node, draftLabel: $viewModel.draftLabel)
                    .offset(dragOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width / 20)))
                    .gesture(dragGesture)
                    .id(node.id)

                CategoryChipRow(selection: $viewModel.draftCategory)

                actionButtons
            } else {
                emptyState
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 24)
    }

    private var header: some View {
        HStack {
            Text("명명 스와이프")
                .font(.headline)
            Spacer()
            Text("\(viewModel.remainingCount)개 남음")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring()) { viewModel.postpone() }
            } label: {
                Label("나중에", systemImage: "clock.arrow.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                confirm()
            } label: {
                Label("맞음", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("이번 명명 큐를 다 봤다")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                if value.translation.width > confirmThreshold {
                    confirm()
                } else {
                    withAnimation(.spring()) { dragOffset = .zero }
                }
            }
    }

    private func confirm() {
        viewModel.confirm()
        dragOffset = .zero
    }
}

#Preview {
    NamingSwipeView(
        viewModel: NamingSwipeViewModel(candidates: SampleData.nodes, onCommit: { _ in })
    )
}

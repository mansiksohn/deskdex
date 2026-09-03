import Foundation
import Combine
import DeskDexKit

/// `NamingQueue`(순수 로직, DeskDexKit)를 화면에 연결하는 얇은 층.
///
/// SwiftData를 직접 알지 못한다 — 결과 반영은 `onCommit` 클로저로 밖에서
/// 주입받는다. 그래서 미리보기·수동 QA에서는 `onCommit: { _ in }`로 그냥
/// 메모리에서만 돌려볼 수 있고, 실제 화면에서는 `ContentView`가 SwiftData
/// `ModelContext` 저장을 연결한다.
@MainActor
final class NamingSwipeViewModel: ObservableObject {
    @Published private(set) var queue: NamingQueue
    @Published var draftLabel: String = ""
    @Published var draftCategory: NodeCategory = .unknown

    private let onCommit: (Node) -> Void

    init(candidates: [Node], onCommit: @escaping (Node) -> Void) {
        queue = NamingQueue(candidates: candidates)
        self.onCommit = onCommit
        syncDraft()
    }

    var current: Node? { queue.current }
    var remainingCount: Int { queue.remainingCount }
    var isEmpty: Bool { queue.isEmpty }

    /// "맞으면 오른쪽 / 틀리면 수정". `draftLabel`이 AI 추정과 같으면 그냥
    /// 확정, 다르면 수정 후 확정 — 호출하는 쪽에서는 구분할 필요가 없다.
    func confirm() {
        guard let result = queue.confirm(label: draftLabel, category: draftCategory) else { return }
        onCommit(result)
        syncDraft()
    }

    /// "애매하면 나중에".
    func postpone() {
        guard let result = queue.postpone() else { return }
        onCommit(result)
        syncDraft()
    }

    private func syncDraft() {
        draftLabel = queue.current?.labelAI ?? ""
        draftCategory = queue.current?.category ?? .unknown
    }
}

import SwiftUI
import SwiftData
import DeskDexKit

/// 이 단계(`docs/design.md` 착수 순서 3)에는 도감 화면이 아직 없다 — 앱을
/// 열면 바로 명명 스와이프다. 4번(도감 화면)이 붙으면 여기는 탭/네비게이션
/// 루트로 바뀐다.
///
/// 저장소에 아무것도 없으면 `SampleData`로 채운다. 실제 장면 파싱
/// 파이프라인(백엔드)이 아직 없어 그것 없이는 큐가 항상 비어 있을 것이다.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: NamingSwipeViewModel?

    var body: some View {
        Group {
            if let viewModel {
                NamingSwipeView(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .task {
            guard viewModel == nil else { return }
            seedSampleDataIfEmpty()
            viewModel = makeViewModel()
        }
    }

    /// 큐는 세션 시작 시점의 스냅샷이다 — 스와이프 도중 배경에서 큐가
    /// 다시 섞이면 사용자 경험이 나빠지므로, `@Query`로 실시간 반영하지
    /// 않고 한 번만 읽는다.
    private func makeViewModel() -> NamingSwipeViewModel {
        let descriptor = FetchDescriptor<PersistentNode>(
            predicate: #Predicate<PersistentNode> { record in
                record.statusRaw == "active" && record.labelStatusRaw != "confirmed"
            }
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return NamingSwipeViewModel(candidates: records.map { $0.toDomain() }, onCommit: commit)
    }

    private func commit(_ node: Node) {
        let targetID = node.id
        let descriptor = FetchDescriptor<PersistentNode>(
            predicate: #Predicate<PersistentNode> { $0.id == targetID }
        )
        if let record = try? modelContext.fetch(descriptor).first {
            record.update(from: node)
        } else {
            modelContext.insert(PersistentNode(node: node))
        }
        try? modelContext.save()
    }

    private func seedSampleDataIfEmpty() {
        let existing = (try? modelContext.fetchCount(FetchDescriptor<PersistentNode>())) ?? 0
        guard existing == 0 else { return }
        modelContext.insert(PersistentScene(scene: SampleData.scene))
        for node in SampleData.nodes {
            modelContext.insert(PersistentNode(node: node))
        }
        try? modelContext.save()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [PersistentNode.self, PersistentScene.self], inMemory: true)
}

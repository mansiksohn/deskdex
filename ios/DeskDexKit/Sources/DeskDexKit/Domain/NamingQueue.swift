import Foundation

/// 명명 스와이프의 순수 로직. SwiftUI나 영속화에 대한 의존이 없어 유닛 테스트로
/// 검증할 수 있다 (`Tests/DeskDexKitTests/NamingQueueTests.swift`). 이 저장소를
/// 만든 환경에는 Swift 툴체인이 없어 이 파일 자체는 컴파일해보지 못했다 —
/// `ios/README.md`의 "검증 상태" 참조.
///
/// `docs/design.md` "2. 명명 스와이프"의 규칙을 그대로 코드로 옮겼다.
///   - `needs_input` 항목을 앞에 배치
///   - "맞으면 오른쪽 / 틀리면 수정 / 애매하면 나중에"는 두 액션으로 충분하다.
///     `confirm`이 확정(맞음)과 수정 후 확정을 함께 처리한다 — 호출자가 넘기는
///     텍스트가 `labelAI`와 같은지 다른지의 차이일 뿐, 별도 화면이 없다.
///     `postpone`이 "나중에"다.
///   - 폼이 아니므로 이름과 카테고리 외에는 아무것도 요구하지 않는다.
public struct NamingQueue {
    private var queue: [Node]

    /// 이번 세션에서 확정/보류한 개수. "n개 남음"류 UI 피드백용.
    public private(set) var confirmedInSession = 0
    public private(set) var postponedInSession = 0

    /// - Parameter candidates: 명명 대상 후보. `status == .active`이고
    ///   `labelStatus != .confirmed`인 노드만 넘긴다 — 필터링은 저장소 조회
    ///   쪽 책임이고, 이 이니셜라이저는 순서만 정한다.
    ///
    /// 정렬 순서: needs_input 항목 먼저, 그다음 나중에로 미룬 적 없는 항목,
    /// 마지막이 미룬 항목. 각 구간 안에서는 `dexNo`(발견 순서) 오름차순.
    /// 미룬 항목을 맨 뒤로 두는 것은 design.md가 명시하지 않은 이 구현의
    /// 결정이다 — "미룬 항목은 뒤로 밀리되 없어지지 않는다"(`docs/design.md`
    /// "`label_status`가 필요한 이유")를 앱을 다시 켰을 때도 지키기 위함.
    public init(candidates: [Node]) {
        queue = candidates.sorted { a, b in
            if a.needsInput != b.needsInput { return a.needsInput && !b.needsInput }
            let aDeferred = a.labelStatus == .deferred
            let bDeferred = b.labelStatus == .deferred
            if aDeferred != bDeferred { return bDeferred } // 미룬 쪽이 뒤로
            return a.dexNo < b.dexNo
        }
    }

    public var current: Node? { queue.first }
    public var remainingCount: Int { queue.count }
    public var isEmpty: Bool { queue.isEmpty }

    /// 현재 항목을 확정한다. `text`가 비어 있으면(사용자가 텍스트를 전부
    /// 지우고 넘긴 경우) `labelAI`로 대체한다 — 이름은 필수 필드라 빈 값으로
    /// 저장하지 않는다.
    @discardableResult
    public mutating func confirm(label text: String, category: NodeCategory) -> Node? {
        guard !queue.isEmpty else { return nil }
        var node = queue.removeFirst()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        node.label = trimmed.isEmpty ? node.labelAI : trimmed
        node.category = category
        node.labelStatus = .confirmed
        node.needsInput = false
        confirmedInSession += 1
        return node
    }

    /// "나중에". `label`은 계속 비워두고 큐 맨 뒤로 보낸다.
    ///
    /// 남은 항목이 이것 하나뿐이면 다시 맨 앞으로 온다 — 같은 카드가 다시
    /// 뜨는 것은 버그가 아니라 "지금 볼 게 이것뿐"이라는 뜻이다. 화면 쪽에서
    /// `remainingCount == 1 && current?.labelStatus == .deferred`로 감지해
    /// "일단 여기까지" 같은 종료 화면을 보여줄 수 있다.
    @discardableResult
    public mutating func postpone() -> Node? {
        guard !queue.isEmpty else { return nil }
        var node = queue.removeFirst()
        node.labelStatus = .deferred
        queue.append(node)
        postponedInSession += 1
        return node
    }
}

/// WHY.md v0 성공 판정 1번 — "장면 촬영 후 생성된 노드 중 이름이 붙은 비율".
/// `NamingQueue`와 분리한 이유: 큐는 확정된 노드를 넘겨받지 않으므로(애초에
/// 대상이 아니라서) 완주율의 분모(활성 노드 전체)를 계산할 수 없다.
public enum NamingCompletion {
    /// `nodes`는 저장소의 전체 노드(이미 확정된 것 포함)를 넘긴다.
    /// 대상이 없으면(장면을 아직 한 번도 안 찍었으면) nil.
    public static func rate(of nodes: [Node]) -> Double? {
        let active = nodes.filter { $0.status == .active }
        guard !active.isEmpty else { return nil }
        let confirmed = active.filter { $0.labelStatus == .confirmed }.count
        return Double(confirmed) / Double(active.count)
    }
}

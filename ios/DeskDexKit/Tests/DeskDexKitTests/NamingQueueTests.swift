import XCTest
@testable import DeskDexKit

/// `NamingQueue`는 이 저장소에서 유일하게 Xcode 없이 검증할 수 있는 부분이다
/// (SwiftUI/SwiftData 의존이 없는 순수 로직). `swift test`로 돌린다 —
/// `ios/README.md` "검증 상태" 참조.
final class NamingQueueTests: XCTestCase {
    private func node(
        dexNo: Int,
        labelAI: String = "물건",
        labelStatus: LabelStatus = .pending,
        needsInput: Bool = false
    ) -> Node {
        Node(dexNo: dexNo, kind: .object, labelAI: labelAI, labelStatus: labelStatus,
             category: .unknown, needsInput: needsInput)
    }

    // MARK: 정렬 — needs_input 먼저, 그다음 미룬 적 없는 것, 마지막이 미룬 것.
    // 각 구간 안에서는 dexNo 오름차순. docs/design.md "명명 스와이프".

    func testOrdering_needsInputFirst() {
        let a = node(dexNo: 1, needsInput: false)
        let b = node(dexNo: 2, needsInput: true)
        let queue = NamingQueue(candidates: [a, b])
        XCTAssertEqual(queue.current?.dexNo, 2)
    }

    func testOrdering_deferredGoesLast_evenIfNeedsInput() {
        let normal = node(dexNo: 1, needsInput: false)
        let deferredNeedsInput = node(dexNo: 2, labelStatus: .deferred, needsInput: true)
        let queue = NamingQueue(candidates: [normal, deferredNeedsInput])
        XCTAssertEqual(queue.current?.dexNo, 1, "미룬 항목은 needs_input이어도 뒤로 밀린다")
    }

    func testOrdering_tieBrokenByDexNo() {
        let a = node(dexNo: 5)
        let b = node(dexNo: 2)
        let c = node(dexNo: 9)
        let queue = NamingQueue(candidates: [a, b, c])
        XCTAssertEqual(queue.current?.dexNo, 2)
    }

    // MARK: confirm

    func testConfirm_setsLabelCategoryAndStatus_advancesQueue() {
        var queue = NamingQueue(candidates: [node(dexNo: 1, labelAI: "검은 키보드")])
        let confirmed = queue.confirm(label: "기계식 키보드", category: .input)

        XCTAssertEqual(confirmed?.label, "기계식 키보드")
        XCTAssertEqual(confirmed?.category, .input)
        XCTAssertEqual(confirmed?.labelStatus, .confirmed)
        XCTAssertEqual(confirmed?.needsInput, false, "확정되면 명명 큐 우선순위 플래그를 내린다")
        XCTAssertEqual(queue.confirmedInSession, 1)
        XCTAssertNil(queue.current, "큐에서 빠져야 한다")
    }

    func testConfirm_emptyText_fallsBackToLabelAI() {
        var queue = NamingQueue(candidates: [node(dexNo: 1, labelAI: "검은 키보드")])
        let confirmed = queue.confirm(label: "   ", category: .input)
        XCTAssertEqual(confirmed?.label, "검은 키보드", "이름은 필수 필드라 빈 값으로 저장하지 않는다")
    }

    func testConfirm_onEmptyQueue_returnsNilWithoutCrashing() {
        var queue = NamingQueue(candidates: [])
        XCTAssertNil(queue.confirm(label: "x", category: .unknown))
        XCTAssertEqual(queue.confirmedInSession, 0)
    }

    // MARK: postpone ("나중에")

    func testPostpone_movesToBack_keepsLabelEmpty() {
        var queue = NamingQueue(candidates: [node(dexNo: 1), node(dexNo: 2)])
        let postponed = queue.postpone()

        XCTAssertEqual(postponed?.dexNo, 1)
        XCTAssertEqual(postponed?.labelStatus, .deferred)
        XCTAssertNil(postponed?.label)
        XCTAssertEqual(queue.current?.dexNo, 2, "다음 항목으로 넘어가야 한다")
        XCTAssertEqual(queue.remainingCount, 2, "미룬 항목은 없어지지 않는다")
        XCTAssertEqual(queue.postponedInSession, 1)
    }

    func testPostpone_onlyItemLeft_comesBackAsCurrent() {
        var queue = NamingQueue(candidates: [node(dexNo: 1)])
        queue.postpone()
        XCTAssertEqual(queue.current?.dexNo, 1, "볼 게 이것뿐이면 같은 카드가 다시 온다")
        XCTAssertEqual(queue.remainingCount, 1)
    }

    // MARK: 완주율 — WHY.md v0 성공 판정 1번

    func testCompletionRate_countsConfirmedAmongActive() {
        let nodes = [
            node(dexNo: 1, labelStatus: .confirmed),
            node(dexNo: 2, labelStatus: .pending),
            node(dexNo: 3, labelStatus: .deferred),
            node(dexNo: 4, labelStatus: .confirmed),
        ]
        XCTAssertEqual(NamingCompletion.rate(of: nodes), 0.5)
    }

    func testCompletionRate_excludesGoneNodesFromBothSides() {
        var gone = node(dexNo: 1, labelStatus: .confirmed)
        gone.status = .gone
        let active = node(dexNo: 2, labelStatus: .pending)
        // gone인 확정 노드가 분자·분모 어느 쪽에도 들어가면 안 된다.
        XCTAssertEqual(NamingCompletion.rate(of: [gone, active]), 0.0)
    }

    func testCompletionRate_noActiveNodes_isNil() {
        XCTAssertNil(NamingCompletion.rate(of: []))
    }
}

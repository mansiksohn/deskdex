import Foundation

/// 물건과 군집은 같은 타입. `kind`로 구분한다 (`docs/design.md` "노드").
/// 군집을 별도 타입으로 빼면 lazy split 때 마이그레이션이 생긴다는 것이 그 문서의 근거고,
/// 이 앱에서도 그대로 따른다.
public enum NodeKind: String, Codable, Equatable, Hashable, Sendable {
    case object
    case cluster
}

/// 의자에 앉은 사람 기준 손이 닿는 정도. `docs/scene-schema.md` §7.
/// `position_confidence`가 낮으면 저장하지 않으므로 옵셔널로 다룬다 (Node.zone).
public enum NodeZone: String, Codable, Equatable, Hashable, Sendable {
    case hot
    case warm
    case cold
}

/// 물건이 무엇에 얹혀 있는가. `docs/scene-schema.md` "support" 섹션.
///
/// VLM 출력의 `off_desk`는 후처리에서 버려지고 Node로 승격되지 않으므로
/// (같은 문서 §5 "상판 필터") 여기 목록에는 없다.
public enum NodeSupport: String, Codable, Equatable, Hashable, Sendable {
    case desk
    case raised
    case vertical
    case unknown
}

/// `docs/design.md` "퇴장은 파이프라인이 판정하지 않는다": 자동으로 `gone`을
/// 붙이지 않는다. 사용자가 확인 큐에서 누를 때만 전이한다.
public enum NodeStatus: String, Codable, Equatable, Hashable, Sendable {
    case active
    case gone
}

/// 명명 스와이프에서의 진행 상태. `docs/design.md`의 "`label_status`가 필요한
/// 이유" 참조 — `label == nil`만으로는 "아직 안 봄"과 "나중에로 미룸"을
/// 구분할 수 없어서 별도로 둔다.
///
/// WHY.md의 v0 성공 판정 1번(명명 완주율)이 이 필드로 계산된다:
/// `confirmed 개수 / active 노드 총수`. `NamingQueue.completionRate`가 그 계산이다.
public enum LabelStatus: String, Codable, Equatable, Hashable, Sendable {
    case pending
    case confirmed
    case deferred
}

/// 카드에 무엇을 보여줄지. 파일로 저장하지 않고 장면 + bbox 참조로 둔다
/// (`docs/design.md` "이미지 참조") — bbox를 고치면 재크롭이 공짜이고, 과거
/// 장면을 나중에 소급 재처리할 수 있다.
///
/// `derived`의 `crop_quality`가 임계값 미만이면 여기 오지 않고 `.none`으로
/// 남는다 — "알아볼 수 없는 얼룩을 보여주느니 실루엣이 낫다."
public enum NodeImage: Codable, Equatable, Sendable {
    case none
    case derived(sceneID: UUID, bbox: BoundingBox)
    case specimen(fileID: UUID)
}

/// `docs/design.md` "노드"의 Swift 표현. 필드는 그 문서의 스키마와 1:1 대응.
///
/// 이 타입은 순수 값 타입이다 — SwiftData나 다른 영속화 프레임워크에 대한
/// 의존이 없다. 저장 방식은 `Persistence/PersistentNode.swift`가 맡고,
/// 그쪽이 이 타입으로/이 타입에서 변환한다. 명명 스와이프 로직(`NamingQueue`)이
/// 이 타입 위에서만 동작하므로 영속화 방식이 바뀌어도 로직은 그대로다.
public struct Node: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID

    /// 최초 발견순 정수. 절대 재정렬하지 않는다. 유령 노드(§검색, v0 미구현
    /// 범위)는 매칭 성공 시점에 부여하는 것으로 보되, 아직 코드가 없다.
    public var dexNo: Int

    public var kind: NodeKind
    public var parentID: UUID?

    /// 사용자 확정 이름. `labelStatus == .confirmed`일 때만 채워진다.
    public var label: String?

    /// AI 추정 이름. 사용자가 고쳐도 지우지 않는다 — 모델 교체 시 정확도
    /// 비교 근거가 된다 (`docs/design.md`).
    public var labelAI: String

    public var labelStatus: LabelStatus
    public var category: NodeCategory
    public var zone: NodeZone?
    public var support: NodeSupport

    /// false면 개별 분리 시도 안 함 (케이블 뭉치처럼 나눠봐야 의미 없는 것).
    public var splittable: Bool

    /// 군집일 때 추정 개수. object는 항상 1.
    public var memberCount: Int

    /// 군집의 활동 한 단어 (예: 커피, 필기). object에서는 nil.
    /// v0는 활동을 정식 노드로 승격하지 않는다 (`docs/design.md` "활동 / 엣지").
    public var activity: String?

    public var status: NodeStatus

    /// 연속 미검출 횟수. N회(설계 초안 3회)에서 확인 큐에 올라간다.
    /// 이 카운터를 올리는 판정 자체는 앱이 아니라 장면 파싱 파이프라인의 몫이라
    /// 이 구조체는 값만 들고 있는다.
    public var missedCount: Int

    /// AI가 식별 실패. `docs/scene-schema.md` §3의 `label_confidence < 0.40`에서
    /// 파생. 명명 큐 우선순위 — `NamingQueue`가 이 플래그로 앞에 배치한다.
    public var needsInput: Bool

    public var image: NodeImage

    /// 자유 메모, 마크다운.
    public var note: String

    public var discoveredAt: Date
    public var departedAt: Date?

    public init(
        id: UUID = UUID(),
        dexNo: Int,
        kind: NodeKind,
        parentID: UUID? = nil,
        label: String? = nil,
        labelAI: String,
        labelStatus: LabelStatus = .pending,
        category: NodeCategory,
        zone: NodeZone? = nil,
        support: NodeSupport = .unknown,
        splittable: Bool = true,
        memberCount: Int = 1,
        activity: String? = nil,
        status: NodeStatus = .active,
        missedCount: Int = 0,
        needsInput: Bool = false,
        image: NodeImage = .none,
        note: String = "",
        discoveredAt: Date = .now,
        departedAt: Date? = nil
    ) {
        self.id = id
        self.dexNo = dexNo
        self.kind = kind
        self.parentID = parentID
        self.label = label
        self.labelAI = labelAI
        self.labelStatus = labelStatus
        self.category = category
        self.zone = zone
        self.support = support
        self.splittable = splittable
        self.memberCount = memberCount
        self.activity = activity
        self.status = status
        self.missedCount = missedCount
        self.needsInput = needsInput
        self.image = image
        self.note = note
        self.discoveredAt = discoveredAt
        self.departedAt = departedAt
    }
}

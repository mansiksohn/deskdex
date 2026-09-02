import Foundation
#if canImport(SwiftData)
import SwiftData

/// `Node`(도메인 값 타입)의 SwiftData 저장 형태.
///
/// 열거형은 원시값(`String`) 컬럼으로, `NodeImage`처럼 연관값이 있는 열거형은
/// 컬럼을 펼쳐서(`imageKindRaw` + 종류별 필드) 저장한다. SwiftData가 연관값
/// 있는 열거형이나 값 타입 배열을 속성으로 직접 저장하는 것을 지원하는지는
/// 버전에 따라 달라 이 환경(Swift 툴체인 없음)에서는 확인할 수 없었다 —
/// 그래서 가장 보수적인 방식(스칼라만 저장)을 택했다. `docs/design.md`의
/// "이미지 참조"가 스키마 자체이고, 이 타입은 그 저장 형태일 뿐이다.
///
/// 도메인 로직(`NamingQueue` 등)은 이 타입을 직접 만지지 않는다 —
/// `toDomain()` / `update(from:)`으로만 오간다.
@Model
public final class PersistentNode {
    @Attribute(.unique) public var id: UUID

    public var dexNo: Int
    public var kindRaw: String
    public var parentID: UUID?
    public var label: String?
    public var labelAI: String
    public var labelStatusRaw: String
    public var categoryRaw: String
    public var zoneRaw: String?
    public var supportRaw: String
    public var splittable: Bool
    public var memberCount: Int
    public var activity: String?
    public var statusRaw: String
    public var missedCount: Int
    public var needsInput: Bool

    public var imageKindRaw: String // "none" | "derived" | "specimen"
    public var imageSceneID: UUID?
    public var imageBBoxX0: Double?
    public var imageBBoxY0: Double?
    public var imageBBoxX1: Double?
    public var imageBBoxY1: Double?
    public var imageFileID: UUID?

    public var note: String
    public var discoveredAt: Date
    public var departedAt: Date?

    public init(node: Node) {
        id = node.id
        dexNo = node.dexNo
        kindRaw = node.kind.rawValue
        parentID = node.parentID
        label = node.label
        labelAI = node.labelAI
        labelStatusRaw = node.labelStatus.rawValue
        categoryRaw = node.category.rawValue
        zoneRaw = node.zone?.rawValue
        supportRaw = node.support.rawValue
        splittable = node.splittable
        memberCount = node.memberCount
        activity = node.activity
        statusRaw = node.status.rawValue
        missedCount = node.missedCount
        needsInput = node.needsInput
        note = node.note
        discoveredAt = node.discoveredAt
        departedAt = node.departedAt

        let flat = PersistentNode.flatten(node.image)
        imageKindRaw = flat.kind
        imageSceneID = flat.sceneID
        imageBBoxX0 = flat.x0
        imageBBoxY0 = flat.y0
        imageBBoxX1 = flat.x1
        imageBBoxY1 = flat.y1
        imageFileID = flat.fileID
    }

    /// 순수 도메인 값으로 변환. 뷰모델과 `NamingQueue`는 이쪽만 다룬다.
    public func toDomain() -> Node {
        Node(
            id: id,
            dexNo: dexNo,
            kind: NodeKind(rawValue: kindRaw) ?? .object,
            parentID: parentID,
            label: label,
            labelAI: labelAI,
            labelStatus: LabelStatus(rawValue: labelStatusRaw) ?? .pending,
            category: NodeCategory(rawValue: categoryRaw) ?? .unknown,
            zone: zoneRaw.flatMap(NodeZone.init(rawValue:)),
            support: NodeSupport(rawValue: supportRaw) ?? .unknown,
            splittable: splittable,
            memberCount: memberCount,
            activity: activity,
            status: NodeStatus(rawValue: statusRaw) ?? .active,
            missedCount: missedCount,
            needsInput: needsInput,
            image: PersistentNode.unflatten(
                kind: imageKindRaw, sceneID: imageSceneID,
                x0: imageBBoxX0, y0: imageBBoxY0, x1: imageBBoxX1, y1: imageBBoxY1,
                fileID: imageFileID
            ),
            note: note,
            discoveredAt: discoveredAt,
            departedAt: departedAt
        )
    }

    /// 기존 레코드를 도메인 값으로 덮어쓴다. 명명 스와이프에서 확정/보류를
    /// 반영할 때 쓴다: `record.update(from: queue.confirm(...))`.
    public func update(from node: Node) {
        dexNo = node.dexNo
        kindRaw = node.kind.rawValue
        parentID = node.parentID
        label = node.label
        labelAI = node.labelAI
        labelStatusRaw = node.labelStatus.rawValue
        categoryRaw = node.category.rawValue
        zoneRaw = node.zone?.rawValue
        supportRaw = node.support.rawValue
        splittable = node.splittable
        memberCount = node.memberCount
        activity = node.activity
        statusRaw = node.status.rawValue
        missedCount = node.missedCount
        needsInput = node.needsInput
        note = node.note
        discoveredAt = node.discoveredAt
        departedAt = node.departedAt

        let flat = PersistentNode.flatten(node.image)
        imageKindRaw = flat.kind
        imageSceneID = flat.sceneID
        imageBBoxX0 = flat.x0
        imageBBoxY0 = flat.y0
        imageBBoxX1 = flat.x1
        imageBBoxY1 = flat.y1
        imageFileID = flat.fileID
    }

    // 인스턴스 메서드가 아니라 static인 이유: init 안에서 self가 완전히
    // 초기화되기 전에도 안전하게 호출하기 위해서다.
    private static func flatten(
        _ image: NodeImage
    ) -> (kind: String, sceneID: UUID?, x0: Double?, y0: Double?, x1: Double?, y1: Double?, fileID: UUID?) {
        switch image {
        case .none:
            return ("none", nil, nil, nil, nil, nil, nil)
        case let .derived(sceneID, bbox):
            return ("derived", sceneID, bbox.x0, bbox.y0, bbox.x1, bbox.y1, nil)
        case let .specimen(fileID):
            return ("specimen", nil, nil, nil, nil, nil, fileID)
        }
    }

    private static func unflatten(
        kind: String, sceneID: UUID?,
        x0: Double?, y0: Double?, x1: Double?, y1: Double?,
        fileID: UUID?
    ) -> NodeImage {
        switch kind {
        case "derived":
            if let sceneID, let x0, let y0, let x1, let y1 {
                return .derived(sceneID: sceneID, bbox: BoundingBox(x0: x0, y0: y0, x1: x1, y1: y1))
            }
            return .none // 손상된 레코드 방어. 정상 경로에서는 오지 않는다
        case "specimen":
            if let fileID { return .specimen(fileID: fileID) }
            return .none
        default:
            return .none
        }
    }
}
#endif

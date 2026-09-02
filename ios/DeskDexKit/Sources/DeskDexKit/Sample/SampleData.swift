import Foundation

/// 미리보기·수동 QA용 고정 데이터. 실제 장면 파싱 파이프라인(백엔드,
/// `docs/scene-schema.md`)이 아직 없어 이걸로 명명 스와이프 화면을 돌려본다.
///
/// 물건은 지어낸 것이 아니라 이 프로젝트를 시작하며 실제로 받은 사무실 책상
/// 사진(§ 관측 기록, `docs/scene-schema.md` §11)에서 가져왔다 — 티팟, 펜꽂이,
/// 파티션 엽서처럼 이 스키마를 실제로 고치게 만든 물건들이라 카테고리·
/// support 조합이 인위적이지 않다.
public enum SampleData {
    public static let scene = Scene(
        place: "office",
        imageFileID: UUID(),
        surfaceBBox: BoundingBox(x0: 0.02, y0: 0.15, x1: 0.98, y1: 0.95),
        captureQuality: CaptureQuality(
            angle: .oblique,
            surfaceRatio: 0.62,
            positionConfidence: 0.7,
            issues: []
        ),
        screenMasks: [
            ScreenMask(bbox: BoundingBox(x0: 0.35, y0: 0.1, x1: 0.7, y1: 0.55), kind: "monitor", confidence: 0.95),
        ]
    )

    public static let nodes: [Node] = [
        // needsInput 예시 — 색만 보고는 정체를 모르는 것.
        Node(
            dexNo: 1,
            kind: .object,
            labelAI: "흰색 원통형 물체",
            category: .unknown,
            zone: .warm,
            support: .desk,
            needsInput: true,
            image: .derived(sceneID: scene.id, bbox: BoundingBox(x0: 0.05, y0: 0.55, x1: 0.12, y1: 0.7))
        ),
        Node(
            dexNo: 2,
            kind: .object,
            labelAI: "민트색 티팟",
            category: .drinkware,
            zone: .hot,
            support: .desk,
            image: .derived(sceneID: scene.id, bbox: BoundingBox(x0: 0.28, y0: 0.6, x1: 0.4, y1: 0.78))
        ),
        Node(
            dexNo: 3,
            kind: .cluster,
            labelAI: "검은 펜꽂이",
            category: .writing,
            zone: .hot,
            support: .desk,
            memberCount: 12,
            activity: "필기",
            image: .derived(sceneID: scene.id, bbox: BoundingBox(x0: 0.02, y0: 0.35, x1: 0.14, y1: 0.6))
        ),
        Node(
            dexNo: 4,
            kind: .object,
            labelAI: "파티션에 기댄 SF 명예의 전당",
            category: .book,
            zone: .cold,
            support: .vertical,
            image: .derived(sceneID: scene.id, bbox: BoundingBox(x0: 0.02, y0: 0.02, x1: 0.14, y1: 0.15))
        ),
        Node(
            dexNo: 5,
            kind: .object,
            label: "회색 접이식 노트북 거치대",
            labelAI: "검은 노트북 거치대",
            labelStatus: .confirmed,
            category: .storage,
            zone: .hot,
            support: .raised,
            image: .derived(sceneID: scene.id, bbox: BoundingBox(x0: 0.62, y0: 0.5, x1: 0.85, y1: 0.7))
        ),
        // 이미지가 없는 예시 — crop_quality 미달로 실루엣만 있는 상태.
        Node(
            dexNo: 6,
            kind: .object,
            labelAI: "멀티탭",
            category: .cablePower,
            support: .raised,
            needsInput: true,
            image: .none
        ),
    ]
}

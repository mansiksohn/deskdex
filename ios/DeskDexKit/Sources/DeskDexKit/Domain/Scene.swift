import Foundation

/// `docs/scene-schema.md` §2 `capture_quality`의 `angle`.
public enum CaptureAngle: String, Codable, Equatable, Hashable, Sendable {
    case topDown = "top_down"
    case oblique
    case low
}

/// `docs/scene-schema.md` §2 `capture_quality.issues`.
public enum CaptureIssue: String, Codable, Equatable, Hashable, Sendable {
    case blur
    case tooDark = "too_dark"
    case backlit
    case surfaceCropped = "surface_cropped"
    case heavyOcclusion = "heavy_occlusion"
}

public struct CaptureQuality: Codable, Equatable, Sendable {
    public var angle: CaptureAngle
    public var surfaceRatio: Double
    public var positionConfidence: Double
    public var issues: [CaptureIssue]

    public init(angle: CaptureAngle, surfaceRatio: Double, positionConfidence: Double, issues: [CaptureIssue] = []) {
        self.angle = angle
        self.surfaceRatio = surfaceRatio
        self.positionConfidence = positionConfidence
        self.issues = issues
    }
}

/// 모니터 화면 영역. 파싱 제외 + 공유 시 블러 (`docs/design.md`).
public struct ScreenMask: Codable, Equatable, Sendable {
    public var bbox: BoundingBox
    public var kind: String
    public var confidence: Double

    public init(bbox: BoundingBox, kind: String, confidence: Double) {
        self.bbox = bbox
        self.kind = kind
        self.confidence = confidence
    }
}

/// `docs/design.md` "Scene"의 Swift 표현.
///
/// `place`가 매칭·진행률의 장소 필터 근거다 (`docs/design.md` "도감의 범위") —
/// 노드는 사용자 단위 하나의 도감이고, 장소는 여기에만 붙는다.
public struct Scene: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var capturedAt: Date

    /// 장소 태그. 자유 문자열 (예: "office", "cafe:합정").
    public var place: String

    public var imageFileID: UUID
    public var surfaceBBox: BoundingBox
    public var captureQuality: CaptureQuality
    public var screenMasks: [ScreenMask]

    public init(
        id: UUID = UUID(),
        capturedAt: Date = .now,
        place: String,
        imageFileID: UUID,
        surfaceBBox: BoundingBox,
        captureQuality: CaptureQuality,
        screenMasks: [ScreenMask] = []
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.place = place
        self.imageFileID = imageFileID
        self.surfaceBBox = surfaceBBox
        self.captureQuality = captureQuality
        self.screenMasks = screenMasks
    }
}

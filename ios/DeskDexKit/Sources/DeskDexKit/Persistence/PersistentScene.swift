import Foundation
#if canImport(SwiftData)
import SwiftData

/// `Scene`의 SwiftData 저장 형태. `PersistentNode`와 같은 이유로 배열
/// 필드(`screenMasks`, `captureQuality.issues`)는 JSON `Data`로 인코딩해서
/// 저장한다 — SwiftData의 값 타입 배열 지원 여부를 이 환경에서 확인할 수
/// 없었기 때문에(`ios/README.md` "검증 상태"), `Codable` + `JSONEncoder`라는
/// 어디서나 되는 방식으로 우회했다. v0는 이 필드들로 질의하지 않으므로
/// (화면에 그대로 그리기만 함) 이 우회의 비용이 없다.
@Model
public final class PersistentScene {
    @Attribute(.unique) public var id: UUID
    public var capturedAt: Date
    public var place: String
    public var imageFileID: UUID
    public var surfaceBBoxX0: Double
    public var surfaceBBoxY0: Double
    public var surfaceBBoxX1: Double
    public var surfaceBBoxY1: Double

    public var captureAngleRaw: String
    public var surfaceRatio: Double
    public var positionConfidence: Double
    public var captureIssuesJSON: Data // [CaptureIssue] 인코딩

    public var screenMasksJSON: Data // [ScreenMask] 인코딩

    public init(scene: Scene) {
        id = scene.id
        capturedAt = scene.capturedAt
        place = scene.place
        imageFileID = scene.imageFileID
        surfaceBBoxX0 = scene.surfaceBBox.x0
        surfaceBBoxY0 = scene.surfaceBBox.y0
        surfaceBBoxX1 = scene.surfaceBBox.x1
        surfaceBBoxY1 = scene.surfaceBBox.y1
        captureAngleRaw = scene.captureQuality.angle.rawValue
        surfaceRatio = scene.captureQuality.surfaceRatio
        positionConfidence = scene.captureQuality.positionConfidence
        captureIssuesJSON = (try? JSONEncoder().encode(scene.captureQuality.issues)) ?? Data()
        screenMasksJSON = (try? JSONEncoder().encode(scene.screenMasks)) ?? Data()
    }

    public func toDomain() -> Scene {
        let issues = (try? JSONDecoder().decode([CaptureIssue].self, from: captureIssuesJSON)) ?? []
        let masks = (try? JSONDecoder().decode([ScreenMask].self, from: screenMasksJSON)) ?? []
        return Scene(
            id: id,
            capturedAt: capturedAt,
            place: place,
            imageFileID: imageFileID,
            surfaceBBox: BoundingBox(x0: surfaceBBoxX0, y0: surfaceBBoxY0, x1: surfaceBBoxX1, y1: surfaceBBoxY1),
            captureQuality: CaptureQuality(
                angle: CaptureAngle(rawValue: captureAngleRaw) ?? .oblique,
                surfaceRatio: surfaceRatio,
                positionConfidence: positionConfidence,
                issues: issues
            ),
            screenMasks: masks
        )
    }
}
#endif

import Foundation

/// 정규화 bbox. `docs/design.md`의 좌표 규약: 0~1, 좌상단 원점, x0<x1, y0<y1.
///
/// 값의 유효성(범위, 뒤집힘)은 여기서 강제하지 않는다. 파싱 직후의 클램프와
/// 폐기는 서버 쪽 후처리(`docs/scene-schema.md` §5)의 책임이고, 이 타입은
/// 이미 정리된 값을 앱 안에서 들고 다니는 용도다.
public struct BoundingBox: Codable, Equatable, Hashable, Sendable {
    public var x0: Double
    public var y0: Double
    public var x1: Double
    public var y1: Double

    public init(x0: Double, y0: Double, x1: Double, y1: Double) {
        self.x0 = x0
        self.y0 = y0
        self.x1 = x1
        self.y1 = y1
    }

    public var width: Double { x1 - x0 }
    public var height: Double { y1 - y0 }
    public var area: Double { max(0, width) * max(0, height) }
}

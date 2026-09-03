import XCTest
@testable import DeskDexKit

/// `NodeImage`는 연관값 있는 열거형의 `Codable` 자동 합성(SE-0295)에 기댄다.
/// 컴파일러가 지원하는지 이 환경(Swift 툴체인 없음)에서는 확인 못 했으므로
/// 세 케이스 왕복 인코딩을 직접 돈다.
final class NodeCodableTests: XCTestCase {
    private func roundTrip(_ node: Node) throws -> Node {
        let data = try JSONEncoder().encode(node)
        return try JSONDecoder().decode(Node.self, from: data)
    }

    func testRoundTrip_imageNone() throws {
        let node = Node(dexNo: 1, kind: .object, labelAI: "물건", category: .unknown, image: .none)
        XCTAssertEqual(try roundTrip(node), node)
    }

    func testRoundTrip_imageDerived() throws {
        let node = Node(
            dexNo: 2, kind: .object, labelAI: "머그", category: .drinkware,
            image: .derived(sceneID: UUID(), bbox: BoundingBox(x0: 0.1, y0: 0.2, x1: 0.3, y1: 0.4))
        )
        XCTAssertEqual(try roundTrip(node), node)
    }

    func testRoundTrip_imageSpecimen() throws {
        let node = Node(
            dexNo: 3, kind: .object, labelAI: "키보드", category: .input,
            image: .specimen(fileID: UUID())
        )
        XCTAssertEqual(try roundTrip(node), node)
    }

    func testRoundTrip_clusterWithParentAndActivity() throws {
        let node = Node(
            dexNo: 4, kind: .cluster, labelAI: "커피 도구", category: .drinkware,
            support: .desk, memberCount: 3, activity: "커피"
        )
        XCTAssertEqual(try roundTrip(node), node)
    }

    /// 카테고리 rawValue가 `docs/scene-schema.md` §2의 VLM 출력 문자열과
    /// 그대로 맞아야 한다 — 파싱 경계에서 변환하지 않는다는 전제.
    func testCategoryRawValues_matchSceneSchema() {
        XCTAssertEqual(NodeCategory.cablePower.rawValue, "cable_power")
        XCTAssertEqual(NodeCategory.foodDrink.rawValue, "food_drink")
        XCTAssertEqual(NodeCategory.allCases.count, 20)
    }
}

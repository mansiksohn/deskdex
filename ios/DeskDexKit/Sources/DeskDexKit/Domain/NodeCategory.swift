import Foundation

/// 닫힌 카테고리 집합. **`docs/scene-schema.md` §2의 20종과 1:1로 일치해야 한다.**
/// 그쪽을 늘리면(예: unknown 비율이 15%를 넘어 항목을 추가하는 경우) 여기도 같이 늘린다.
///
/// `rawValue`는 VLM 출력 JSON의 문자열 그대로다 — 파싱 경계에서 변환하지 않는다.
public enum NodeCategory: String, Codable, CaseIterable, Equatable, Hashable, Sendable, Identifiable {
    case input
    case display
    case audio
    case cablePower = "cable_power"
    case writing
    case paper
    case book
    case drinkware
    case foodDrink = "food_drink"
    case storage
    case carry
    case lighting
    case plant
    case decor
    case device
    case tool
    case care
    case textile
    case trash
    case unknown

    public var id: String { rawValue }

    /// 명명 스와이프의 카테고리 칩에 쓰는 한국어 라벨.
    /// `docs/scene-schema.md` §2 표의 한글 범위 설명에서 대표 단어만 뽑았다.
    public var displayName: String {
        switch self {
        case .input: return "입력기기"
        case .display: return "디스플레이"
        case .audio: return "오디오"
        case .cablePower: return "케이블/전원"
        case .writing: return "필기"
        case .paper: return "종이"
        case .book: return "책"
        case .drinkware: return "잔/컵"
        case .foodDrink: return "음식/음료"
        case .storage: return "수납"
        case .carry: return "휴대품"
        case .lighting: return "조명"
        case .plant: return "식물"
        case .decor: return "장식"
        case .device: return "기기"
        case .tool: return "도구"
        case .care: return "케어"
        case .textile: return "패브릭"
        case .trash: return "버릴 것"
        case .unknown: return "미분류"
        }
    }
}

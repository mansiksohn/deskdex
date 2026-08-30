# scene-schema — 장면 파싱 계약 v1

`docs/design.md`의 "장면 파싱" 단계에서 VLM 1회 호출이 무엇을 받고 무엇을 뱉는지
고정한다. 초안이다. 실제 책상 사진 3~4장으로 검증한 뒤 v1로 확정한다
(하단 "검증 절차").

관련 문서: [WHY](WHY.md) · [design](design.md)

## 0. 이 문서가 고정하는 것

- VLM 출력 JSON 스키마 (구조화 출력에 그대로 넣는 형태)
- 출력 필드 → `Node` / `Scene` 필드 매핑
- 임계값 (`crop_quality`, `label_confidence` 등) 초안값
- 후처리 순서 (화면 영역 필터 → 정합성 검사 → 매칭 → `dex_no` 부여)
- 프롬프트 초안
- 합격 판정 기준

## 1. 좌표 규약

정규화 `0~1`, 좌상단 원점, `x`는 오른쪽, `y`는 아래 방향.
`x0 < x1`, `y0 < y1`을 후처리에서 검사한다.

VLM 출력에서는 bbox를 **객체** `{x0, y0, x1, y1}`로 받는다. 저장할 때
`design.md`의 배열 형태 `[x0,y0,x1,y1]`로 변환한다. 이유: 구조화 출력 스키마는
배열 길이를 강제할 수 없지만(`minItems`/`maxItems` 미지원) 객체는
`required` + `additionalProperties: false`로 4개 필드를 강제할 수 있다.
길이가 3인 bbox를 런타임에 만나는 것보다 낫다.

## 2. 출력 스키마

`output_config.format`에 넣는 JSON Schema. 구조화 출력 제약에 맞춰
숫자 범위(`minimum`/`maximum`)와 배열 길이 제약을 쓰지 않았다.
**범위 검사는 후처리에서 한다.**

`items`는 물건과 군집을 한 배열에 섞어 담고 `member_of`로 소속을 가리키는
평면 구조다. 중첩 구조를 쓰지 않는 이유는 구조화 출력이 재귀 스키마를
지원하지 않기 때문이고, 평면 쪽이 `Node` 테이블(물건과 군집이 같은 테이블)과도
그대로 대응한다.

```json
{
  "type": "object",
  "additionalProperties": false,
  "required": ["schema_version", "surface", "screen_regions", "capture_quality", "items", "unparsed_regions"],
  "properties": {
    "schema_version": { "const": "scene.v1" },

    "surface": {
      "type": "object",
      "additionalProperties": false,
      "required": ["bbox", "confidence"],
      "properties": {
        "bbox": { "$ref": "#/$defs/bbox" },
        "confidence": { "type": "number" }
      }
    },

    "screen_regions": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["bbox", "kind", "confidence"],
        "properties": {
          "bbox": { "$ref": "#/$defs/bbox" },
          "kind": { "enum": ["monitor", "laptop", "phone", "tablet", "tv", "other"] },
          "confidence": { "type": "number" }
        }
      }
    },

    "capture_quality": {
      "type": "object",
      "additionalProperties": false,
      "required": ["angle", "surface_ratio", "position_confidence", "issues"],
      "properties": {
        "angle": { "enum": ["top_down", "oblique", "low"] },
        "surface_ratio": { "type": "number" },
        "position_confidence": { "type": "number" },
        "issues": {
          "type": "array",
          "items": { "enum": ["blur", "too_dark", "backlit", "surface_cropped", "heavy_occlusion"] }
        }
      }
    },

    "items": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "id", "kind", "member_of", "label", "label_confidence", "category",
          "distinguishing_features", "bbox", "crop_quality", "occlusion",
          "zone", "support", "sediment", "member_count", "splittable", "activity"
        ],
        "properties": {
          "id":       { "type": "string" },
          "kind":     { "enum": ["object", "cluster"] },
          "member_of": { "anyOf": [{ "type": "string" }, { "type": "null" }] },

          "label":            { "type": "string" },
          "label_confidence": { "type": "number" },
          "category":         { "$ref": "#/$defs/category" },
          "distinguishing_features": { "type": "string" },

          "bbox":         { "$ref": "#/$defs/bbox" },
          "crop_quality": { "type": "number" },
          "occlusion":    { "type": "number" },
          "zone":         { "enum": ["hot", "warm", "cold"] },
          "support":      { "enum": ["desk", "raised", "vertical", "unknown"] },

          "sediment": {
            "type": "object",
            "additionalProperties": false,
            "required": ["candidate", "signals", "confidence"],
            "properties": {
              "candidate": { "type": "boolean" },
              "signals": {
                "type": "array",
                "items": {
                  "enum": ["dust", "under_stack", "behind_object", "desk_edge",
                           "unopened_package", "tangled_cable", "unreachable"]
                }
              },
              "confidence": { "type": "number" }
            }
          },

          "member_count": { "type": "integer" },
          "splittable":   { "type": "boolean" },
          "activity":     { "type": "string" }
        }
      }
    },

    "unparsed_regions": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["bbox", "reason", "estimated_count"],
        "properties": {
          "bbox": { "$ref": "#/$defs/bbox" },
          "reason": { "enum": ["too_cluttered", "too_small", "out_of_focus", "unidentifiable"] },
          "estimated_count": { "type": "integer" }
        }
      }
    }
  },

  "$defs": {
    "bbox": {
      "type": "object",
      "additionalProperties": false,
      "required": ["x0", "y0", "x1", "y1"],
      "properties": {
        "x0": { "type": "number" }, "y0": { "type": "number" },
        "x1": { "type": "number" }, "y1": { "type": "number" }
      }
    },
    "category": {
      "enum": [
        "input", "display", "audio", "cable_power", "writing", "paper",
        "book", "drinkware", "food_drink", "storage", "carry", "lighting",
        "plant", "decor", "device", "tool", "care", "textile", "trash", "unknown"
      ]
    }
  }
}
```

### 카테고리를 닫힌 집합으로 두는 이유

열어두면 호출마다 새 카테고리가 생겨 군집순 정렬과 필터가 무너진다.
20개는 책상 한 판을 덮기에 충분하다고 보고 시작하되, 검증에서 `unknown`
비율이 15%를 넘으면 항목을 늘린다.

용기와 내용물이 다른 카테고리일 때는 **내용물 기준**으로 정한다. 펜꽂이에 펜이
꽂혀 있으면 그 군집은 `writing`이지 `storage`가 아니다. 빈 펜꽂이만 있으면
`storage`다. 사용자가 찾는 것은 용기가 아니라 내용물이다.

| 값 | 범위 |
|---|---|
| `input` | 키보드, 마우스, 트랙패드, 매크로패드 |
| `display` | 모니터, 서브 디스플레이, 모니터암 |
| `audio` | 스피커, 헤드폰, 마이크, 오디오 인터페이스 |
| `cable_power` | 케이블, 충전기, 도크, 멀티탭 |
| `writing` | 펜, 연필, 붓, 지우개, 자 |
| `paper` | 노트, 서류, 포스트잇, 스티커 시트 |
| `book` | 책, 잡지, 만화책 |
| `drinkware` | 머그, 텀블러, 티팟, 잔, 코스터 |
| `food_drink` | 간식, 음료, 원두, 티백 |
| `storage` | 트레이, 서랍장, 정리함, 펜꽂이 |
| `carry` | 지갑, 키, 키링, 파우치, 사원증, 가방 |
| `lighting` | 스탠드, 조명, 무드등 |
| `plant` | 화분, 조화 |
| `decor` | 피규어, 오브제, 액자, 스티커 |
| `device` | 폰, 태블릿, 시계, 카메라, 외장 저장장치 |
| `tool` | 가위, 커터, 드라이버, 청소 도구 |
| `care` | 립밤, 핸드크림, 약, 안경, 마스크 |
| `textile` | 데스크매트, 손수건, 옷 |
| `trash` | 포장지, 빈 병, 버릴 것 |
| `unknown` | 물건인 건 확실하나 정체 불명 |

## 3. Node / Scene 매핑

| VLM 출력 | 저장 위치 | 비고 |
|---|---|---|
| `items[].label` | `Node.label_ai` | `Node.label`은 비워둔다. 사용자가 명명 스와이프에서 채운다 |
| `items[].category` | `Node.category` | |
| `items[].kind` | `Node.kind` | |
| `items[].member_of` | `Node.parent_id` | 로컬 id → 실제 노드 id로 치환 |
| `items[].bbox` | `Node.image.bbox` (`derived`일 때) | 배열로 변환 |
| `items[].zone` | `Node.zone` | `position_confidence`가 낮으면 저장하지 않음 |
| `items[].support` | `Node`에 보관 | 후처리 상판 필터가 유효 물건을 죽이지 않게 하는 용도 |
| `items[].member_count` | `Node.member_count` | `object`는 항상 1 |
| `items[].splittable` | `Node.splittable` | |
| `items[].activity` | 군집의 `activity` 문자열 필드 | v0에서 활동 노드는 만들지 않음 |
| `items[].label_confidence` | → `Node.needs_input` 파생 | 아래 임계값 표 |
| `items[].crop_quality` | → `Node.image.type` 결정 | 저장도 함께 (임계값 조정 시 소급 재판정용) |
| `items[].distinguishing_features` | 매칭 보조 신호로 보관 | §5 참조 |
| `items[].sediment` | 침전 후보 플래그 | v0는 수집만. 리포트는 범위 밖 |
| `surface.bbox` | `Scene.surface_bbox` | |
| `screen_regions[]` | `Scene.screen_masks` | |
| `capture_quality` | `Scene.capture_quality` | |
| `unparsed_regions[]` | `Scene`에 보관 | 진행률 분모에 넣지 않음. 재촬영 유도에 씀 |

`needs_input`을 VLM이 직접 뱉게 하지 않고 `label_confidence`에서 파생시키는 이유:
임계값을 코드에서 조정하면 과거 장면까지 소급 재판정이 된다. 모델이 스스로
"모르겠다"를 판정하게 두면 그 기준이 프롬프트에 박혀 조정이 안 된다.

## 4. 임계값 (초안)

전부 실측 전 추정값이다. 검증 후 이 표만 고치면 되도록 코드에서 상수로 뺀다.

| 조건 | 결과 |
|---|---|
| `label_confidence < 0.40` | `needs_input = true` (명명 큐 앞으로) |
| `crop_quality < 0.45` | `image.type = 'none'` — 실루엣으로 둔다 |
| `occlusion > 0.60` | `crop_quality`를 0.45 미만으로 강제 (가려진 건 크롭해도 못 알아본다) |
| `crop_quality < 0.60` | 그리드 내보내기에서 제외 |
| `capture_quality.position_confidence < 0.50` | `zone` 저장하지 않음 |
| `capture_quality.surface_ratio < 0.35` | 재촬영 유도 배너 |
| `surface.confidence < 0.50` | 파싱 결과 전체를 보류하고 재촬영 요청 |

`crop_quality` 임계값이 `design.md`의 "알아볼 수 없는 얼룩을 보여주느니 실루엣이
낫다"를 구현하는 지점이다. 검증 때 이 값을 눈으로 맞춘다 — 0.45 근처 크롭 20개를
늘어놓고 "이게 뭔지 알아볼 수 있나"로 판정.

## 5. 후처리 순서

**전처리 (호출 전)**: EXIF orientation을 적용해 픽셀을 실제 방향으로 회전시킨
뒤 태그를 지운다. 회전이 남아 있으면 좌표 규약과 `zone` 판정이 통째로 틀어진다.
받아본 실제 사진에 90도 돌아간 것이 섞여 있었다 — 흔한 경우로 보고 처리한다.

VLM 응답을 받은 뒤 노드를 만들기 전까지.

1. **스키마 검증** — 구조화 출력이 형태는 보장하지만 값은 보장하지 않는다.
   bbox가 `0~1` 범위인지, `x0 < x1`인지, confidence류가 `0~1`인지 검사.
   범위를 벗어나면 클램프하고, bbox가 뒤집혔으면 그 항목만 버린다.
2. **화면 영역 필터** — item bbox 면적의 **70% 이상**이 어떤 `screen_regions`
   항목과 겹치면 그 item을 버린다. 화면에 뜬 내용을 물건으로 오인한 것.
   `screen_regions` 자체는 `Scene.screen_masks`로 남아 공유 시 블러에 쓰인다.
3. **상판 필터** — bbox 중심이 `surface.bbox` 밖이고 **`support`가 `unknown`일 때만**
   버린다 (벽, 바닥, 창밖). `vertical`(파티션에 기댄 엽서, 모니터에 붙인 메모)과
   `raised`(모니터 받침대 위의 멀티탭, 선반 위 물건)는 상판 밖이어도 살린다.
   실제 사무실 책상 사진에서 파티션에 기대어 둔 물건이 여럿이었고, 단순
   상판 필터는 그것들을 전부 죽인다.
4. **관계 정합성** — `member_of`가 실재하는 id인지, 그 대상이 `kind='cluster'`인지,
   군집이 군집을 참조하지 않는지, 자기 자신을 가리키지 않는지. 위반 시
   `member_of`를 `null`로 떨어뜨리고 최상위 물건으로 둔다 (버리지 않는다).
5. **기존 노드 매칭** — §6.
6. **`dex_no` 부여** — 매칭 실패한 신규 항목에만. 부여 후 절대 재정렬하지 않는다.
7. **이미지 판정** — `crop_quality` → `image.type`.

2번과 3번의 순서가 중요하다. 화면 영역은 상판 위에 있으므로 상판 필터로는
안 걸러진다.

`surface`를 단수로 둔 것은 v0의 단순화다. 실제 사진에는 책상 상판 + 모니터
받침대 + 파티션처럼 표면이 여럿이었다. `support`가 그 대용이다. 다중 표면을
정식으로 모델링할지는 미결정.

### 왜 화면 마스킹이 별도 호출이 아닌가

`design.md`의 파이프라인은 `screen_masks 검출 → VLM 호출` 순서로 그려져 있지만,
그렇게 하면 모델을 하나 더 돌리게 되어 "VLM 1회" 원칙과 충돌한다. 같은 호출에서
`screen_regions`를 함께 받고 위 2번처럼 **사후 필터**하면 호출 1회를 유지하면서
오인식과 사생활 문제를 같이 처리한다. 블러는 어차피 공유 시점에 하므로 사후로
충분하다.

비용: 화면 속 물건을 모델이 한 번 뽑았다가 버리는 만큼의 출력 토큰. 무시할 수준.

## 6. 매칭과 실패 방향

v0 최대 리스크 지점이다. 책상은 하루 안에 배치가 바뀌므로 bbox 근접도는 약한
신호다. 신호를 셋 쓴다.

- `label` / `label_ai` 문자열 유사도
- `category` 일치
- `distinguishing_features` (빨간 스티커, 각인, 흠집 등 짧은 구절)
- bbox 근접도 — 보조 신호로만

**실패 방향을 병합 쪽으로 기울인다.** `dex_no`는 재정렬하지 않으므로 중복 노드는
사실상 되돌릴 수 없다(노드를 지워도 번호에 구멍이 남는다). 반면 잘못된 병합은
사용자가 명명 스와이프에서 "이건 다른 물건"으로 쪼개면 회복된다. 그래서 애매하면
기존 노드에 붙인다.

임계값은 미정 — 검증 때 같은 책상을 배치만 바꿔 두 번 찍어서 정한다.

## 7. 프롬프트 초안

시스템 프롬프트. 스키마는 `output_config.format`이 강제하므로 프롬프트에서
형식을 다시 설명하지 않는다. **판단 기준만 담는다.**

```text
당신은 책상 사진 한 장을 분석해 그 위에 놓인 물건 목록을 만든다.
사용자는 이 목록으로 자기 물건의 도감을 만든다. 목록에 없는 물건은
사용자에게 존재하지 않는 것이 된다.

## 무엇을 세는가

- 책상 상판 위에 놓인 것만. 벽, 바닥, 의자, 창밖, 사람은 제외한다.
- 모니터·노트북 화면에 표시된 내용은 물건이 아니다. 화면 영역은
  screen_regions에 따로 담고, 그 안의 아이콘이나 사진은 items에 넣지 않는다.
- 책상 자체, 데스크매트, 모니터암처럼 물건을 받치는 것도 물건으로 센다.
- 가려져서 일부만 보이는 것도 정체를 알겠으면 센다. occlusion을 높인다.
- 다른 물건에 붙박이로 딸린 부품은 따로 세지 않는다. 노트북의 키보드와
  트랙패드는 노트북 하나다. 반면 손으로 분리해서 따로 쓰는 것은 따로 센다
  (머그 뚜껑, 펜 뚜껑이 빠져 있으면 그건 별개 항목이 아니라 무시한다).
- 명백히 그 자리의 비품이거나 다른 사람 자리의 물건은 제외한다. 카페의
  냅킨 디스펜서, 옆자리 가방 같은 것. 판단이 서지 않으면 포함하고
  label_confidence를 낮춘다.

## support

물건이 무엇에 얹혀 있는가. desk는 상판 위에 직접, raised는 다른 물건이나
받침대 위에(모니터 받침대 위의 멀티탭), vertical은 세로 면에 기대거나 붙어
있는 것(파티션에 기댄 엽서, 모니터에 붙인 메모). 판단이 안 되면 unknown.

## 군집

물리적으로 붙어 있고 같은 활동에 쓰이는 물건 3개 이상은 하나의 cluster로
묶고, 그 안의 개별 물건은 items에 넣지 않는다. member_count에 눈으로 센
개수를 적고 activity에 활동을 한 단어로 적는다(예: 커피, 필기, 조립).

케이블 뭉치처럼 개수를 셀 수 없는 것은 cluster로 묶고 splittable을 false로
둔다. 나눠봐야 의미가 없는 것에는 splittable = false를 준다.

## 이름

- 한국어 명사구, 12자 이내. "검은색 기계식 키보드" 같은 형태.
- 브랜드나 모델명은 로고나 각인이 실제로 읽힐 때만 쓴다. 생김새로
  추측하지 않는다.
- 정체를 모르겠으면 지어내지 말고 category를 unknown으로 두고
  label에 보이는 대로 적는다("흰색 원통형 물체"). label_confidence를 낮춘다.
- label_confidence는 이름이 맞을 확률이다. 물건이 거기 있다는 확신과
  구분한다.

## distinguishing_features

같은 책상을 다음 주에 다시 찍었을 때 이 물건을 같은 물건으로 알아보게 해줄
표식을 짧게 적는다. 스티커, 각인, 흠집, 색 조합 같은 것. 없으면 빈 문자열.
위치는 적지 않는다 — 위치는 바뀐다.

## crop_quality

이 bbox만 잘라내서 카드에 보여줬을 때 사용자가 자기 물건을 알아볼 수 있는가.
초점, 크기, 잘림, 가림을 종합한다. 잘라놓으면 얼룩으로 보일 것 같으면 낮춘다.

## zone

의자에 앉은 사람 기준. hot은 손이 바로 닿는 곳, warm은 팔을 뻗어야 하는 곳,
cold는 일어나거나 다른 물건을 치워야 닿는 곳.

## 카테고리

용기와 내용물의 카테고리가 다르면 내용물을 따른다. 펜이 꽂힌 펜꽂이는
writing이다.

## sediment

오래 손대지 않은 것으로 보이는 정황을 담는다. 먼지, 다른 물건 밑에 깔림,
뜯지 않은 포장, 뒤엉킨 케이블, 접근 불가한 위치. 정황이 없으면 candidate를
false로 둔다. 추측으로 표시하지 않는다.

## 셀 수 없는 영역

너무 어수선하거나 작아서 개별 항목으로 나눌 수 없는 영역은 items에 억지로
넣지 말고 unparsed_regions에 담는다. 몇 개쯤 있어 보이는지 적는다.

정확도가 개수보다 중요하다. 확신이 없는 항목을 늘리는 것보다
label_confidence를 정직하게 낮추는 편이 낫다.
```

## 8. 호출 형태

```jsonc
POST https://api.anthropic.com/v1/messages
{
  "model": "claude-opus-5",
  "max_tokens": 16000,
  "output_config": {
    "format": { /* §2 스키마 */ }
  },
  "messages": [{
    "role": "user",
    "content": [
      { "type": "image",
        "source": { "type": "base64", "media_type": "image/jpeg", "data": "<b64>" } },
      { "type": "text", "text": "이 책상 사진을 분석하라." }
    ]
  }],
  "system": "<§7 프롬프트>"
}
```

메모:

- **모델**: `claude-opus-5`. 구조화 출력과 비전을 모두 지원한다. 파싱 정확도가
  곧 명명 완주율(성공 판정 1번)이므로 여기서 모델을 낮추지 않는다.
- **thinking**: Opus 5는 기본으로 적응형 사고가 켜져 있다. 별도 설정하지 않는다.
- **첫 호출 지연**: 새 스키마는 1회 컴파일 비용이 붙고 이후 24시간 캐시된다.
  스키마를 자주 바꾸면 매번 느려지므로 검증 중에는 감안한다.
- **`stop_reason`**: `max_tokens`면 JSON이 잘려 있을 수 있다. 항목이 많은
  책상에서 나올 수 있으므로 파싱 실패를 이 경우와 구분해 처리한다.
- **비용**: 사진 1장 + 프롬프트 + 출력 40항목 기준 장면당 대략 $0.1 안팎.
  주 1회 촬영이면 사용자당 무시할 수준이다.
- **Swift에는 공식 Anthropic SDK가 없다.** iOS 네이티브로 가더라도 이 호출은
  백엔드를 경유하는 게 맞다 — 앱에 API 키를 심을 수 없다. 누끼(Vision)는
  온디바이스, 장면 파싱은 서버로 갈린다.

## 9. 검증 절차

착수 순서 2번에 해당한다. **실제 책상 사진이 있어야 진행된다.**

필요한 사진과 현재 확보 상태는 §11.

측정:

| 지표 | 재는 법 | 합격선(초안) |
|---|---|---|
| 재현율 | 사람이 만든 정답 목록 중 잡힌 비율 | 0.80 |
| 허위 항목 | 실재하지 않는 항목 수 | 장면당 3개 이하 |
| 라벨 정확도 | 사용자가 고치지 않고 통과시킬 이름의 비율 | 0.60 |
| bbox 합격률 | 크롭했을 때 알아볼 수 있는 비율 | 0.70 |
| 화면 오인식 | 화면 속 내용이 물건으로 남은 수 | 0 |
| 안정성 | 같은 사진 2회 호출 시 항목 수 편차 | ±10% |
| 매칭 정확도 | 4번 사진에서 3번과 같은 물건을 같게 붙인 비율 | 0.85 |
| `unknown` 비율 | | 0.15 이하 |

라벨 정확도 합격선을 0.60으로 잡은 근거: 성공 판정 1번의 명명 완주율 목표가
50%다. AI 추정 이름이 절반도 못 맞히면 명명 스와이프가 "확인"이 아니라
"입력"이 되고, 목표한 한 조각 2초가 무너진다.

**어느 지표가 미달이면 프롬프트를 고치고, 프롬프트로 안 되면 스키마를 고친다.**
스키마를 먼저 고치면 무엇 때문에 좋아졌는지 알 수 없다.

## 10. 미결정

- 매칭 신뢰도 임계값 — 4번 사진으로 정한다
- `crop_quality` 임계값 0.45의 실제 위치 — 크롭 20개를 눈으로 보고 정한다
- 한 장면의 최대 항목 수 상한을 둘지 (지금은 없음. 어수선한 책상에서
  `max_tokens`에 닿는지 3번 사진으로 확인)
- 카테고리 18개로 충분한지
- 프롬프트 캐싱 적용 여부 — 시스템 프롬프트가 최소 캐시 프리픽스에 못 미칠
  수 있다. 촬영 빈도가 주 1회라 캐시 히트도 기대하기 어렵다. 보류
- **도감의 범위 — 책상 단위인가 사용자 단위인가.** `Scene`에 장소 식별자가
  없어서 지금은 모든 노드가 한 풀에 섞인다. 사무실 책상과 카페 테이블을 같이
  찍으면 매칭이 두 곳을 넘나든다. `design.md`에도 없는 갭이다. §11 참조
- `surface`를 배열로 바꿔 다중 표면을 정식 모델링할지
- 프레임 밖으로 잘린 물건의 처리. 카페 사진에서 노트와 컵이 절반씩 잘려 있었다.
  crop_quality가 낮아 실루엣이 되는데, 실루엣 모양 자체가 잘린 모양이 된다

## 11. 관측 기록 — 사진 3장 (2026-08-30)

실제 사진 3장을 눈으로 훑은 결과. **API 호출로 측정한 것이 아니다.** §9의
지표는 아직 하나도 재지 않았다.

### 받은 것

| # | 내용 | 각도 | 화면 | 역할 |
|---|---|---|---|---|
| A | 카페 테이블 — 책, 머그, 에어팟, 카드지갑, 노트, 폰 | oblique | 없음 | 평소 상태 |
| B | A와 같은 테이블, 노트북 추가 + 재배치 | oblique (90도 회전됨) | 노트북 켜짐 | 매칭 쌍(A와) |
| C | 사무실 책상 — 모니터, 티팟, 펜꽂이, 케이블, 다수 | 정면 저각 | 모니터 켜짐 | 최악 사례 |

### 드러난 것

각각 스키마나 파이프라인을 실제로 고치게 만든 관측이다.

1. **파티션에 기댄 물건** (C) — 엽서, 그림책, 포스터가 상판이 아니라 파티션에
   기대어 있다. 후처리의 상판 필터가 이것들을 전부 버린다. `support` 필드를
   넣고 필터 조건을 고쳤다.
2. **다른 물건 위에 얹힌 물건** (C) — 모니터 받침대 위의 멀티탭과 충전기.
   같은 필터 문제이자, 침전 판정(`under_stack`)과도 얽힌다.
3. **90도 회전된 사진** (B) — EXIF orientation이 적용되지 않은 채로 들어왔다.
   좌표 규약과 `zone`이 통째로 틀어진다. 전처리 단계를 추가했다.
4. **카테고리 누락** — 카드지갑(A, B)이 18종 어디에도 없었다. EDC 사용자에게
   지갑·키는 핵심 물건이다. `carry`를 추가했다. 그리고 `paper`가 책까지
   삼키고 있어서 `book`을 분리했다 — 1차 대상에 책 취미군이 있다.
5. **용기와 내용물** (C) — 펜 20자루가 꽂힌 펜꽂이는 `storage`인가 `writing`인가.
   내용물 기준으로 규칙을 못박았다.
6. **붙박이 부품** (B) — 노트북의 키보드와 트랙패드를 따로 셀 위험. 프롬프트에
   규칙을 넣었다.
7. **남의 물건과 가게 비품** (A, B) — 배경에 다른 사람의 가방이 있고, 티슈는
   가게 것이다. 소유 경계 규칙을 프롬프트에 넣었다.
8. **프레임 밖으로 잘린 물건** (A) — 노트와 플라스틱 컵이 절반씩 잘렸다.
   `crop_quality`로 실루엣이 되지만, 실루엣 모양이 "잘린 모양"이 된다.
   미결정으로 남겼다.

### 가장 큰 것 — 도감의 범위

A·B는 카페 테이블이고 C는 사무실 책상이다. **서로 다른 책상이다.**
`Scene`에 장소 식별자가 없어서 지금 설계로는 두 곳의 노드가 한 풀에 섞이고,
매칭이 카페 머그와 사무실 머그 사이에서 일어난다. `dex_no`가 하나의 연속된
수열이라는 전제도 "어느 책상의 도감인가"가 정해져야 성립한다.

`design.md`에도 없는 갭이다. 결정하기 전에는 매칭 임계값을 정할 수 없다.

### 아직 없는 것

- **top_down 기준선.** 셋 다 비스듬하거나 저각이다. 수직으로 내려찍은 사진이
  있어야 "각도 때문에 못 잡은 것"과 "모델이 못 잡은 것"을 분리할 수 있다.
- **C의 재촬영.** 매칭 쌍으로 쓸 수 있는 건 A↔B뿐인데, 그 둘은 90도 돌아가
  있어서 평소 재촬영의 난이도를 대표하지 못한다. 매주 찍을 진짜 대상은 C다.
- **정답 목록.** 재현율과 라벨 정확도는 사용자가 만든 정답 목록 없이는 못 잰다.
  물건의 진짜 이름은 소유자만 안다.

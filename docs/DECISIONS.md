# DeskDex (책상도감) — 결정 로그 (DECISIONS.md)

결정과 그 이유만 쌓는다(append-only). 현재 사실은 [CURRENT.md](CURRENT.md), 제품의 이유는 [WHY.md](WHY.md).

## 규칙

- 새 항목은 이 파일 **맨 아래**에 추가한다. 옛 항목의 본문은 고치지 않는다.
- 항목당 본문 10줄 이하. 검증 로그는 커밋 메시지에 쓰고 여기 쓰지 않는다.
- `결정:`·`이유:`는 필수, `버린 대안:`·`주의:`는 있으면 쓴다.
- 결정이 뒤집히면 옛 항목 제목 바로 아래 첫 줄에 `> ⚠️ 폐기됨 → [새 항목](#앵커)`를 추가한다.
- 위 규칙은 `tools/docs_lint.py`가 검사한다.

```markdown
### YYYY-MM-DD 제목
- 결정:
- 이유:
- 버린 대안: (있으면)
- 주의: (있으면)
```

## 기록

2026-11-23 이전 항목은 그때까지의 문서와 커밋에서 옮겨 적은 것이다. 세부 근거는 링크한 절에 있다.

### 2026-08-28 플랫폼은 iOS 네이티브 우선
- 결정: v0는 iOS 네이티브(SwiftUI + SwiftData)로 만든다. 누끼는 온디바이스 Vision, 장면 파싱만 백엔드를 거친다.
- 이유: 누끼 품질이 카드 톤을 좌우하는데, Vision(`VNGenerateForegroundInstanceMaskRequest`)이 온디바이스·무료·무제한이다. 장면 파싱은 앱에 API 키를 둘 수 없어 백엔드를 거친다([design.md](design.md) "개별 촬영 누끼").
- 버린 대안: 웹 먼저 — 나중으로 미뤘다.
- 주의: 주 작업 기기가 Windows라 컴파일·화면 확인이 맥이나 CI에 묶인다(AGENTS.md §4).

### 2026-09-02 퇴장(gone)은 자동 판정하지 않는다
- 결정: 파이프라인은 `status='gone'`을 부여하지 않는다. 연속 미검출은 카운터만 올리고, N회(초안 3회) 연속이면 "아직 있나요?" 확인 큐에 올린다. 퇴장은 사용자가 누른다.
- 이유: 같은 책상을 5분 간격으로 두 각도에서 찍었더니 물건 집합이 달랐다. 한 장면의 미검출은 부재의 증거가 아니다([scene-schema §12](scene-schema.md)).

### 2026-09-02 도감은 사용자 단위 하나, 장소는 Scene에만
- 결정: `dex_no`는 장소와 무관한 하나의 수열이다. 매칭은 같은 `place`의 노드를 먼저 보고, 못 찾으면 전체로 넓힌다.
- 이유: 지갑·노트북·책은 사무실과 카페를 오간다. 장소별 도감이면 같은 물건이 중복 등록되고 번호를 두 번 쓴다([design.md](design.md) "도감의 범위").
- 버린 대안: 장소별 도감 분리.

### 2026-09-02 장면 파싱 백엔드를 Claude에서 Gemini로
- 결정: 검증 러너 `tools/parse_scene.py`의 VLM 호출을 Gemini(`gemini-3.6-flash`, `google-genai`)로 바꾼다. 스키마는 `response_json_schema`로 거의 그대로 넘긴다.
- 이유: Claude API는 구독과 별도 결제가 필요해 실측을 바로 못 했다. Gemini로 먼저 실측했고 §9 지표 다섯 개를 모두 넘겼다.
- 버린 대안: Claude·Gemini 둘 다 고를 수 있게 하는 제공자 선택 옵션(옛 로컬 작업본에 있었다) — 지금은 한 백엔드로 계약을 굳히는 게 먼저다.
- 주의: 비용 추정(scene-schema §15)은 Claude 기준이라 참고용이다.

### 2026-11-23 글불 프로젝트의 작업 흐름을 도입하고 iOS 컴파일은 CI macOS로
- 결정: 글불처럼 `AGENTS.md`/`CLAUDE.md`, 덮어쓰는 `docs/CURRENT.md`, append-only 결정 로그, 세션 시작·커밋 hook, `tools/dod.sh`, 문서 lint를 둔다. 결정 로그 이름은 `DECISIONS.md`로 한다. Swift 컴파일·테스트는 GitHub Actions macOS 러너에서 돌린다.
- 이유: 석 달 쉬었다 돌아오니 현재 상태가 README·design.md·ios/README.md에 흩어져 있었다. 주 작업 기기가 Windows라 맥 없이 `swift test`와 앱 빌드를 확인할 길이 필요했다. 공개 저장소라 macOS 러너가 무료다.
- 버린 대안: 결정 로그를 글불처럼 `WHY.md`로 — 이 저장소의 `WHY.md`는 이미 제품의 이유 문서라 이름이 겹친다. Windows용 Swift 툴체인 — SwiftData·SwiftUI가 없어 도메인 로직밖에 확인하지 못한다.
- 주의: CI는 컴파일과 단위 테스트까지만 본다. 화면 동작 확인은 여전히 맥의 Xcode가 필요하다.

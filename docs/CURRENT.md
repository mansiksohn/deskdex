# DeskDex (책상도감) — 현재 상태 (CURRENT.md)

지금 무엇이 되어 있는지만 적는다. 덮어쓰는 문서이고 300줄을 넘기지 않는다(`tools/docs_lint.py`가 검사).
왜 이렇게 됐나는 [DECISIONS.md](DECISIONS.md), 제품의 이유는 [WHY.md](WHY.md), 설계는 [design.md](design.md).

## 1. 한 줄 요약

책상 사진 한 장 → VLM 파싱 → 노드 일괄 생성 → 명명 스와이프 → 도감 / 검색 / 그리드 내보내기.
플랫폼은 iOS 네이티브(SwiftUI + SwiftData, iOS 17+). 누끼는 온디바이스 Vision, 장면 파싱만
백엔드(Gemini) 경유. 지금은 v0 착수 단계다.

## 2. 착수 순서와 진행 상태

순서 자체는 [design.md](design.md) 하단.

| # | 작업 | 상태 |
|---|---|---|
| 1 | 누끼 손검증 — 물건 10개로 카드 톤 확인 | 미착수. 실물 사진 필요 |
| 2 | 장면 파싱 프롬프트 + 스키마 고정 | 실측 1차 합격(§3). 매칭 정확도·안정성 측정이 남음 |
| 3 | 데이터 모델 + 명명 스와이프 (`ios/`) | 코드 작성 완료. 컴파일 검증은 CI macOS 잡 도입으로 시작(§4) |
| 4 | 도감 화면 | 미착수 |
| 5 | 검색 | 미착수 |
| 6 | 그리드 내보내기 | 미착수 |

## 3. 장면 파싱 (`tools/`, 백엔드 실험)

- 백엔드는 Gemini `gemini-3.6-flash`(`google-genai` SDK). 키는 환경변수 `GEMINI_API_KEY` 또는 루트 `.env`.
- 스키마·프롬프트·합격선의 원본은 [scene-schema.md](scene-schema.md)이고 `parse_scene.py`가 직접 읽는다.
- 2026-09-02 사무실 책상 사진 2장(정면·top_down) 실측: §9 지표 다섯 개 전부 합격
  (재현율 100%, 라벨 정확도 93~100%, bbox 합격률 100%, 허위 0, unknown 0%). 결과는 `runs/2026-09-02/`,
  세부는 [scene-schema §16](scene-schema.md).
- 남은 것: 재촬영 간 노드 매칭 정확도, 같은 사진 반복 호출 안정성, 다른 책상(집·카페) 사진.

실행 절차는 [README](../README.md)의 "장면 파싱 검증 돌리기".

## 4. iOS (`ios/`)

| 위치 | 내용 | 검증 |
|---|---|---|
| `DeskDexKit/Sources/DeskDexKit/Domain/` | `Node`, `Scene`, `NamingQueue`, `BoundingBox`, `NodeCategory`. Foundation만 사용 | CI `swift test`(macOS) |
| `DeskDexKit/Tests/` | `NamingQueueTests`, `NodeCodableTests` | CI `swift test`(macOS) |
| `DeskDexKit/Sources/DeskDexKit/Persistence/` | SwiftData `@Model` | CI 컴파일만 |
| `App/` | SwiftUI 명명 스와이프 화면, 샘플 데이터 자동 시드 | CI 시뮬레이터 빌드(컴파일만). 화면 동작은 맥의 Xcode에서 [ios/README.md](../ios/README.md) 체크리스트로 |

- Xcode 프로젝트는 `ios/project.yml`(XcodeGen)로 만든다. `.xcodeproj`는 커밋하지 않는다.
- 알려진 갭: 실제 사진 로딩 없음(실루엣 자리표시자), 실루엣이 bbox 모양이 아님, 도감 화면 없음,
  유령 노드·퇴장 확인 큐 UI 없음(모델 필드 `NodeStatus`, `missedCount`만 있음). 세부는 [ios/README.md](../ios/README.md).

## 5. 개발 환경

- 주 작업 기기는 Windows(Swift 툴체인·Xcode 없음). 맥에서만 되는 일은 [AGENTS.md](../AGENTS.md) §4.
- Python 3.13, `google-genai`, `pillow`, `python-dotenv`.
- CI: GitHub Actions `.github/workflows/ci.yml` — `checks`(ubuntu: `tools/dod.sh`와 같은 검사),
  `ios`(macos: `swift test`, XcodeGen → 시뮬레이터 빌드). 공개 저장소라 macOS 러너도 무료.

## 6. 하지 않기로 한 것

재제안하지 않는다. 바꾸려면 DECISIONS.md에 새 결정을 남긴다.

- 3D 렌더링, 커머스 연동, 전수 입력 강요, 정확한 치수 측정 — [WHY.md](WHY.md) "하지 않을 것"
- 퇴장(`status='gone'`) 자동 판정 — [scene-schema §12](scene-schema.md)
- 장소별 도감 분리(도감은 사용자 단위 하나) — [design.md](design.md) "도감의 범위"

## 7. 파일 맵

| 경로 | 역할 |
|---|---|
| `AGENTS.md`, `CLAUDE.md` | 작업 규칙·함정, 문서 안내 |
| `docs/CURRENT.md` | 이 문서(현재 상태, 덮어쓰기) |
| `docs/DECISIONS.md` | 결정 로그(append-only) |
| `docs/WHY.md` | 제품의 이유, 하지 않을 것, v0 성공 판정 |
| `docs/design.md` | v0 범위, 데이터 모델, 파이프라인, 화면 |
| `docs/scene-schema.md` | 장면 파싱 VLM 계약 + 관측·실측 기록 |
| `tools/parse_scene.py` | 장면 파싱 러너(Gemini). raw.json / items.csv / summary.txt |
| `tools/score.py` | 손으로 채운 items.csv에서 §9 지표 채점 |
| `tools/visualize_crops.py` | bbox 오버레이, 물건별 크롭, crop 판정용 카드 뷰어 HTML |
| `tools/docs_lint.py` | 문서 lint(CURRENT 줄 수, DECISIONS 형식, 상대 링크) |
| `tools/dod.sh` | 완료 확인을 한 번에 |
| `tools/hooks/`, `.claude/settings.json` | Claude Code hook: 세션 시작 브리핑, 문서 없는 코드 커밋 차단 |
| `runs/` | 실측 결과(사진 제외) |
| `scratch/` | 실험 사진(gitignore) |
| `ios/DeskDexKit/` | Swift 패키지: 도메인 로직 + SwiftData 모델 + 테스트 |
| `ios/App/` | SwiftUI 앱 |
| `ios/project.yml` | XcodeGen 스펙 |

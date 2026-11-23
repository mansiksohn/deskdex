# DeskDex (책상도감) — 작업 규칙 (AGENTS.md)

모든 에이전트(Claude Code, Codex 등) 공통 규칙과 함정. 현재 사실은 `docs/CURRENT.md`, 문서 안내는 `CLAUDE.md`.

## 1. 절대 규칙

- **비밀:** API 키는 루트 `.env`에만 둔다(gitignore 대상). 커밋·로그·`runs/` 산출물에 키를 남기지 않는다.
- **사진:** 실험 사진은 `scratch/`(gitignore)에 둔다. 사진에는 자산 라벨·사람이 찍힌다([scene-schema §14](docs/scene-schema.md)). 원본 사진은 커밋하지 않는다. `runs/`의 JSON·CSV 결과만 커밋한다.
- **퇴장은 사용자가 누른다:** 파이프라인은 `status='gone'`을 자동으로 부여하지 않는다. 한 장면의 미검출은 부재의 증거가 아니다([scene-schema §12](docs/scene-schema.md)).
- **WHY의 "하지 않을 것"은 재제안하지 않는다**(3D 렌더링, 커머스 연동, 전수 입력 강요, 치수 측정). 바꾸려면 DECISIONS.md에 새 결정을 남긴다.

## 2. 검증

```
bash tools/dod.sh
```

Python 도구 문법 검사, 채점기가 지난 실측 결과로 도는지(`score.py`), 문서 lint(`tools/docs_lint.py`), `swift test`를 한 번에 돌린다. Swift 툴체인이 없는 환경(Windows)에서는 `swift test`를 건너뛴다고 표시한다. 그 부분은 GitHub Actions의 macOS 잡(`.github/workflows/ci.yml`)이 검증한다. 성공한 단계는 한 줄만, 실패한 단계만 출력 전체가 나온다. 작업을 끝내기 전에 반드시 통과시킨다.

iOS 코드를 고쳤으면 push 후 CI의 `ios` 잡(`swift test` + 앱 시뮬레이터 빌드)이 초록인지까지 확인한다. 눈으로 보는 확인(화면 동작)은 여전히 맥의 Xcode에서만 된다 — `ios/README.md` 체크리스트.

## 3. 작업 종료 규칙

사용자가 문서 갱신을 따로 요청하지 않아도 매 작업의 일부로 한다.

1. 바뀐 사실은 `docs/CURRENT.md`에 덮어써서 반영한다(300줄 이하, 넘치면 세부는 다른 문서 링크로).
2. 결정이 있었으면 `docs/DECISIONS.md` 맨 아래에 템플릿대로 한 항목을 추가한다(append-only). 검증 로그는 커밋 메시지에 쓴다.
3. 데이터 모델·화면 설계가 바뀌면 `docs/design.md`, 파싱 계약(스키마·프롬프트·합격선)이 바뀌면 `docs/scene-schema.md`를 고친다. 합격선을 바꾸면 `tools/score.py`의 `GATES`도 같이 고친다.
4. 코드와 문서를 한 커밋에 넣는다.

- **결정은 내려진 그 턴에 기록한다.** 사용자가 방향을 정하면("~로 단순화", "~는 빼자", "~로 확정") 코드 변경이 없어도 그 턴에 DECISIONS.md 항목을 쓴다. 미루면 다른 세션은 그 결정을 모른다.
- **기계로 확인할 수 있는 규칙은 테스트·lint로 옮긴다.** 아래 함정 중 막을 수 있는 것은 승격하고 여기서 지운다.
- **주석은 "지금 왜 이렇게 되어 있나"만 짧게.** 날짜·요청·시행착오 같은 변천사는 DECISIONS.md와 git이 맡는다.
- **자동 장치(`.claude/settings.json`):** 세션 시작 hook(`tools/hooks/session_brief.mjs`)이 뒤처짐과 main에 안 들어간 다른 브랜치·워크트리를 알려 준다. 커밋 hook(`tools/hooks/commit_docs_guard.mjs`)은 코드만 바뀌고 CURRENT·DECISIONS·design·scene-schema·AGENTS가 그대로인 커밋을 막는다(문서에 남길 게 없으면 커밋 메시지에 `[docs-skip]`).

## 4. 어디서 무엇을 하나 (Windows ↔ 맥)

| 작업 | Windows | 맥 |
|---|---|---|
| 문서, 장면 파싱 도구(`tools/*.py`), 실측 | 된다 | 된다 |
| `DeskDexKit` 도메인 로직 작성 | 된다(컴파일은 CI가) | 된다 |
| `swift test`, 앱 컴파일 | CI macOS 잡으로만 | 로컬에서 바로 |
| 시뮬레이터·실기에서 화면 확인, 온디바이스 Vision(누끼) | 안 된다 | 된다 |

## 5. 작업 재개 체크리스트 (오래 쉬었다가, 또는 다른 세션의 PR이 머지된 뒤)

1. `git status`가 깨끗한지 본 뒤 `git fetch origin && git merge --ff-only origin/main`.
2. Claude 세션을 새로 시작한다(`CLAUDE.md`·`AGENTS.md`·hook은 세션 시작 때만 읽힌다).
3. 세션 시작 브리핑의 경고(뒤처짐, 미병합 브랜치)를 먼저 처리한다. 합칠지 버릴지는 사용자에게 묻는다.
4. 기억이나 예전 대화와 `docs/CURRENT.md`가 다르면 CURRENT.md가 맞다.
5. `bash tools/dod.sh`로 기준선이 초록인지 확인하고 시작한다.

## 6. 함정 (Pitfalls)

- 스키마와 프롬프트의 원본은 `docs/scene-schema.md`의 첫 ```` ```json ```` 블록과 첫 ```` ```text ```` 블록이다. `parse_scene.py`가 그대로 읽으므로 코드에 사본을 만들지 않는다. 문서에서 그 두 블록보다 앞에 다른 json/text 블록을 넣으면 파서가 엉뚱한 것을 읽는다.
- 사진은 EXIF orientation을 픽셀에 적용한 뒤 써야 한다(`ImageOps.exif_transpose`). 안 하면 bbox 좌표와 zone이 통째로 틀어진다([scene-schema §5](docs/scene-schema.md)).
- 모니터 bbox는 자기 화면 영역과 겹친다 → 화면 영역 필터가 모니터 자체를 버린 적이 있다([scene-schema §16](docs/scene-schema.md)).
- Gemini `response_json_schema`는 `const`를 지원하지 않는다 → `to_gemini_schema`가 `enum` 하나짜리로 바꾼다. 스키마에 새 키워드를 쓰면 지원 목록(그 함수 docstring)부터 확인한다.
- Windows 콘솔에서 `score.py` 등의 한글 출력이 깨지면 `PYTHONIOENCODING=utf-8`을 준다(`dod.sh`는 이미 준다).
- SwiftData `@Model`과 SwiftUI는 Linux·Windows의 Swift로는 컴파일되지 않는다. 그래서 도메인 로직(`DeskDexKit/Sources/DeskDexKit/Domain/`)은 Foundation만 쓴다. 여기에 SwiftUI·SwiftData import를 넣지 않는다.
- `DeskDexKit`의 `Scene`(촬영 장면)은 SwiftUI의 `Scene`과 이름이 같다. `import SwiftUI`와 `import DeskDexKit`을 함께 쓰는 파일에서는 `SwiftUI.Scene` / `DeskDexKit.Scene`으로 적는다(안 그러면 'Scene' is ambiguous로 앱 빌드가 실패한다).

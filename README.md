# DeskDex (책상도감)

책상 위 물건을 기록하는 도구. 기록의 보상으로 도감과 공유 이미지를 준다.

지금 무엇이 되어 있고 무엇이 남았나: **[docs/CURRENT.md](docs/CURRENT.md)**.
작업 규칙은 [AGENTS.md](AGENTS.md).

- [docs/WHY.md](docs/WHY.md) — 왜 만드는가, 하지 않을 것, v0 성공 판정
- [docs/design.md](docs/design.md) — v0 범위, 데이터 모델, 파이프라인, 화면
- [docs/scene-schema.md](docs/scene-schema.md) — 장면 파싱 VLM 계약 (초안, 검증 전)
- [ios/README.md](ios/README.md) — iOS 앱 빌드 방법, 검증 상태, 알려진 갭

## v0 한 줄 요약

장면 촬영 한 장 → VLM 파싱 → 노드 일괄 생성 → 명명 스와이프 → 도감 / 검색 / 그리드 내보내기.

## 개발 환경

플랫폼은 iOS 네이티브(SwiftUI + SwiftData). 문서와 장면 파싱 도구(`tools/`)는
어느 OS에서나 되고, Swift 컴파일·테스트는 GitHub Actions의 macOS 잡이 맡는다.
화면 확인은 맥의 Xcode에서 — [ios/README.md](ios/README.md).

```sh
bash tools/dod.sh   # 작업 완료 확인(문서 lint, Python 도구, swift test)
```

## 장면 파싱 검증 돌리기

```sh
pip install google-genai pillow
export GEMINI_API_KEY=...   # 또는 루트 .env에 GEMINI_API_KEY=... (pip install python-dotenv)

python3 tools/parse_scene.py photos/*.jpg --out runs/0902
#   runs/0902/<이름>.raw.json   VLM 원본 응답
#   runs/0902/<이름>.items.csv  정답 대조용
#   runs/0902/summary.txt       항목 수, 버린 것, 토큰

# crop 판정을 돕는 시각화: bbox 오버레이 + 물건별 크롭 + 카드 뷰어 HTML
python3 tools/visualize_crops.py photos/<이름>.jpg runs/0902

# items.csv 의 hit / crop 열을 손으로 채운다
#   hit   o=맞음  n=실재하나 이름틀림  x=허위  miss=놓침(행을 직접 추가)
#   crop  o=크롭해서 알아볼 수 있다  x=없다

python3 tools/score.py runs/0902/*.items.csv
```

스키마와 프롬프트는 `docs/scene-schema.md`에서 직접 읽으므로, 고칠 때는 문서만
고치면 된다. 합격선은 같은 문서 §9에 있고 `tools/score.py`가 그 값으로 판정한다.

2026-09-02에 실제로 돌려봤다 (`docs/scene-schema.md` §16). 결과는
`runs/2026-09-02/`에 있다 — 원본 응답(`*.raw.json`), 채점 결과(`*.items.csv`),
요약(`summary.txt`).

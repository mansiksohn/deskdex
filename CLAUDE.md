# DeskDex (책상도감) — Claude Code

@AGENTS.md

## 문서 안내 — 필요한 것만 연다

| 알고 싶은 것 | 문서 | 읽는 법 |
|---|---|---|
| 지금 무엇이 되어 있고 무엇이 남았나(단계, 검증 상태, 파일 맵) | [docs/CURRENT.md](docs/CURRENT.md) | 작업 시작 시 |
| 왜 이 제품인가, 하지 않을 것, v0 성공 판정 | [docs/WHY.md](docs/WHY.md) | 제품 방향 질문일 때만 |
| v0 범위, 데이터 모델, 화면 설계 | [docs/design.md](docs/design.md) | 데이터 모델·화면 작업일 때 |
| 장면 파싱 VLM 계약(스키마·프롬프트·합격선·실측) | [docs/scene-schema.md](docs/scene-schema.md) | 파싱 작업일 때. 709줄이라 `grep -n '^## '`로 절을 찾아 범위만 읽는다 |
| 결정과 그 이유 | [docs/DECISIONS.md](docs/DECISIONS.md) | grep으로 찾는다. 덧붙일 때는 끝부분만 읽는다 |
| iOS 빌드 방법·Xcode 확인 체크리스트 | [ios/README.md](ios/README.md) | iOS 작업일 때 |

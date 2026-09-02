# DeskDex (책상도감)

책상 위 물건을 기록하는 도구. 기록의 보상으로 도감과 공유 이미지를 준다.

현재 단계: **데이터 모델 + 명명 스와이프 착수 (착수 순서 3번). 미검증 —
아래 "iOS 코드 검증 상태" 참조.**

- [docs/WHY.md](docs/WHY.md) — 왜 만드는가, 하지 않을 것, v0 성공 판정
- [docs/design.md](docs/design.md) — v0 범위, 데이터 모델, 파이프라인, 화면
- [docs/scene-schema.md](docs/scene-schema.md) — 장면 파싱 VLM 계약 (초안, 검증 전)
- [ios/README.md](ios/README.md) — iOS 앱 빌드 방법, 검증 상태, 알려진 갭

## v0 한 줄 요약

장면 촬영 한 장 → VLM 파싱 → 노드 일괄 생성 → 명명 스와이프 → 도감 / 검색 / 그리드 내보내기.

## 착수 순서

`docs/design.md` 하단 참조. 플랫폼은 **iOS 네이티브 우선**으로 결정했다
(누끼는 온디바이스 Vision, 장면 파싱만 백엔드 경유).

남은 선행 작업 둘 다 실물 사진이 필요하다.

1. 누끼 손검증 — 물건 10개로 카드 톤 확인. 미착수
2. 장면 파싱 검증 — 책상 사진으로 `docs/scene-schema.md`의 합격선 측정.
   백엔드는 **Gemini**로 전환 (Claude 구독은 API 크레딧을 별도로 안 줘서).
   사진 한 장(desk1)을 다른 방식으로 테스트해 지표 다섯 개는 이미 합격선을
   넘었다 — `tools/parse_scene.py`로 재현하는 것과 매칭 정확도·안정성
   측정이 남았다. `GEMINI_API_KEY`가 있으면 바로 돌릴 수 있다
3. **데이터 모델 + 명명 스와이프 — 코드 작성 완료, 컴파일 미검증.** `ios/`
   참조. 1·2번과 독립적으로 진행했다 (노드가 이미 있다고 가정하고 저장·
   명명만 다룬다. 장면 촬영 → 노드 생성 파이프라인은 아직 없다)

## iOS 코드 검증 상태

이 코드를 쓴 환경(Linux 컨테이너)에는 Swift 툴체인도 Xcode도 없다. 그래서:

- `ios/DeskDexKit/`의 도메인 로직(`Node`, `NamingQueue` 등)은 SwiftUI·
  SwiftData 의존 없이 짜서 **`swift test`로 Xcode 없이 검증 가능**하다.
  받으면 제일 먼저 이것부터 돌려본다.
- SwiftData 영속화·SwiftUI 화면은 Xcode에서 열어봐야 확인된다.

절차와 확인 체크리스트는 `ios/README.md`.

## 장면 파싱 검증 돌리기

```sh
pip install google-genai pillow
export GEMINI_API_KEY=...

python3 tools/parse_scene.py photos/*.jpg --out runs/0902
#   runs/0902/<이름>.raw.json   VLM 원본 응답
#   runs/0902/<이름>.items.csv  정답 대조용
#   runs/0902/summary.txt       항목 수, 버린 것, 토큰

# items.csv 의 hit / crop 열을 손으로 채운다
#   hit   o=맞음  n=실재하나 이름틀림  x=허위  miss=놓침(행을 직접 추가)
#   crop  o=크롭해서 알아볼 수 있다  x=없다

python3 tools/score.py runs/0902/*.items.csv
```

스키마와 프롬프트는 `docs/scene-schema.md`에서 직접 읽으므로, 고칠 때는 문서만
고치면 된다. 합격선은 같은 문서 §9에 있고 `tools/score.py`가 그 값으로 판정한다.

`tools/parse_scene.py`의 Gemini 호출부는 실제 `google-genai` 2.21.0을 설치해
API를 확인하고 썼지만, 이 환경에 `GEMINI_API_KEY`가 없어 **실제 네트워크
호출까지는 못 가봤다.** 스키마 변환·설정 객체 생성까지는 SDK 자체 검증을
통과했다. 처음 돌릴 때 에러가 나면 알려주시면 그걸 근거로 고친다.
`docs/scene-schema.md` §8에 세부 사항.

# DeskDex iOS — 데이터 모델 + 명명 스와이프

`docs/design.md` 착수 순서 3번. `docs/scene-schema.md`(장면 파싱, 백엔드)와는
독립적으로 진행했다 — 이 단계는 노드가 이미 있다고 가정하고 저장·명명만
다룬다. 장면 촬영 → 노드 생성 파이프라인은 아직 없다.

## 검증 상태 — 반드시 먼저 읽을 것

**이 코드는 컴파일된 적이 없다.** 작성한 환경(Linux 컨테이너)에 Swift
툴체인이 없고, `download.swift.org`가 프록시 정책으로 막혀 있어 설치도
못 했다 (`curl`이 403). Xcode·iOS 시뮬레이터도 당연히 없다.

그래서 구조를 이렇게 나눴다 — 검증 가능한 부분과 아닌 부분을 분리하기 위해서다.

| 위치 | 내용 | 검증 |
|---|---|---|
| `DeskDexKit/Sources/DeskDexKit/Domain/` | `Node`, `Scene`, `NamingQueue` 등. SwiftUI·SwiftData 의존 없는 순수 Swift/Foundation | **Xcode 없이 `swift test`로 검증 가능.** 아래 참조 |
| `DeskDexKit/Tests/` | 위 로직에 대한 XCTest | 코드는 다 썼다. 실행은 못 해봤다 |
| `DeskDexKit/Sources/DeskDexKit/Persistence/` | SwiftData `@Model` | iOS/macOS 전용. 미검증 |
| `App/` | SwiftUI 화면 | iOS 전용. 미검증. SwiftData·SwiftUI API 사용부(`#Predicate`, `.modelContainer(for:)`, `@ObservedObject`+SwiftData 조합)가 가장 위험도가 높다 |

**받으면 제일 먼저 할 일**:

```sh
cd ios/DeskDexKit
swift test
```

Xcode 없이, 맥이면 바로 된다 (`Package.swift`가 iOS 17 + macOS 14를 같이
선언해둬서 macOS 타깃으로 빌드된다). 이게 실패하면 나머지도 다 의심해야
한다 — 여기가 이 코드에서 유일하게 자동으로 확인되는 부분이다.

`App/`은 그다음, 아래 절차로 Xcode에 올려서 눈으로 확인한다.

## 빌드 — 수동 (권장, 확실한 경로)

XcodeGen 설치 여부와 무관하게 되는 방법.

1. Xcode에서 새 프로젝트 → iOS → App. 이름 `DeskDex`, 인터페이스 SwiftUI,
   최소 배포 대상 **iOS 17** (SwiftData가 17부터라 이 밑으로는 안 된다)
2. 생성된 프로젝트에 기본으로 딸려오는 `DeskDexApp.swift`, `ContentView.swift`,
   `Assets.xcassets`, `Info.plist`를 지운다
3. 이 저장소의 `ios/App/` 폴더 전체를 프로젝트로 끌어넣는다 (Copy items if
   needed 체크)
4. File → Add Package Dependencies → Add Local → `ios/DeskDexKit` 선택해서
   로컬 패키지로 추가하고, 앱 타깃에 `DeskDexKit` 라이브러리를 링크한다
5. 빌드 (⌘B). 시뮬레이터로 실행 (⌘R)

## 빌드 — XcodeGen (선택)

이미 xcodegen을 쓰고 있다면 더 빠르다. 이 `project.yml`은 작성했지만
**돌려보지 못했다** — 스키마가 정확한지는 XcodeGen이 직접 검증해줄 것이다.

```sh
brew install xcodegen   # 없다면
cd ios
xcodegen generate
open DeskDex.xcodeproj
```

## 실제로 확인해야 할 것 (Xcode가 열리면)

컴파일 자체가 첫 관문이다. 그다음 눈으로:

- [ ] 앱을 켜면 명명 스와이프가 바로 뜬다 (`SampleData`가 자동으로 시드된다)
- [ ] `#1 흰색 원통형 물체`처럼 "확인 필요" 배지 붙은 게 먼저 나온다
      (`needs_input` 우선순위)
- [ ] 카드를 오른쪽으로 밀면 다음 카드로 넘어간다
- [ ] "나중에"를 누르면 그 카드가 없어지지 않고 큐 뒤로 간다
- [ ] 이름 칸을 고친 채로 "맞음"을 누르면 고친 이름으로 저장된다
      (`labelAI`가 아니라)
- [ ] 앱을 껐다 켜도 확정한 것들은 그대로다 (SwiftData 영속화 확인)
- [ ] 큐를 다 비우면 "이번 명명 큐를 다 봤다" 화면이 뜬다

이 체크리스트가 실제로 통과하는지는 이 세션이 아니라 Xcode를 여는 쪽에서
확인해야 한다. `CLAUDE.md`류 규칙이 요구하는 "UI는 브라우저로 확인" 항목의
iOS 버전인데, 이 환경엔 그 버전의 브라우저(=Xcode 시뮬레이터)가 없다.

## 알려진 갭 (일부러 남긴 것)

- **실제 사진 로딩이 없다.** `NodeImage.derived`/`.specimen` 카드도 지금은
  `SilhouetteView` 자리표시자로 뜬다. 장면 파일 저장·크롭 파이프라인이
  아직 없어서다.
- **실루엣이 진짜 bbox 모양이 아니다.** `docs/design.md`는 "bbox 형태를 채운
  단색 실루엣"이라고 했는데, `Node.image`의 `.none` 케이스는 bbox를 들고
  있지 않는다 (`{ type: 'none' }`). `SilhouetteView.swift` 코드 주석 참조.
- **도감 화면이 없다.** 착수 순서 4번. 지금은 앱을 켜면 명명 스와이프가
  루트다.
- **유령 노드, 퇴장 확인 큐 UI가 없다.** 데이터 모델(`NodeStatus`,
  `missedCount`)은 있지만 그걸 다루는 화면은 아직 없다.

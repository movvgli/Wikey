<p align="center">
  <img src="Sources/Wikey/Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="128" alt="Wikey 앱 아이콘">
</p>

<h1 align="center">Wikey</h1>

<p align="center">
  반복하는 일을 단축키 하나로 끝내는 macOS 워크플로 앱
</p>

<p align="center">
  <a href="https://github.com/movvgli/Wikey/releases/latest"><strong>최신 버전 다운로드</strong></a>
  · <a href="README.en.md">English</a>
  · <a href="docs/INSTALL.md">설치 안내</a>
  · <a href="docs/PRIVACY.md">개인정보 보호</a>
</p>

![Wikey 홈 화면](docs/images/home.png)

Wikey는 앱 실행, 웹사이트 열기, 자주 쓰는 문구 붙여넣기와 창 배치를 원하는 순서로 연결해 실행합니다. 한 번 또는 두 단계 단축키를 지정하면 어느 앱을 사용 중이든 바로 워크플로를 시작할 수 있습니다.

모든 워크플로와 템플릿은 외부 서버로 전송하지 않고 사용자의 Mac에 저장됩니다.

## 빠르게 시작하기

1. [최신 릴리스](https://github.com/movvgli/Wikey/releases/latest)에서 `Wikey-버전.dmg`를 다운로드합니다.
2. Wikey를 **응용 프로그램** 폴더로 옮기고 실행합니다.
3. 첫 실행 안내에서 핵심 기능을 살펴보고, 사용할 기능에 필요한 권한만 켭니다.
4. **새 워크플로**를 만들고 동작과 단축키를 지정합니다.

배포 파일은 Developer ID로 서명되고 Apple 공증을 완료했습니다. macOS 15 이상에서 사용할 수 있습니다.

## 주요 기능

| 기능 | 설명 |
| --- | --- |
| 워크플로 | 여러 동작을 위에서 아래 순서로 연결해 한 번에 실행합니다. |
| 전역 단축키 | 한 번에 누르거나 최대 두 단계로 이어 누르는 단축키를 지원합니다. |
| 앱과 웹사이트 | 원하는 앱을 실행하고 URL을 기본 브라우저로 엽니다. |
| 템플릿 | 서식, 링크, 목록과 인라인 이미지가 포함된 문구를 복사하거나 자동으로 붙여넣습니다. |
| 창 레이아웃 | 여러 모니터에서 전체, 1/2, 1/3, 2/3와 사분면으로 앱 창을 배치합니다. |
| 빠른 실행 | 메뉴 막대에서 워크플로를 실행하고 Mac 로그인 시 자동으로 준비합니다. |
| 자동 업데이트 | 앱 안에서 새 버전을 확인하고 다운로드해 설치합니다. |

한 동작이 실패해도 Wikey는 가능한 나머지 동작을 계속 실행하고 결과를 알려줍니다.

## 권한과 개인정보

Wikey는 사용하는 기능에 필요한 macOS 권한만 요청합니다.

| 권한 | 사용하는 기능 |
| --- | --- |
| 손쉬운 사용 | 다른 앱의 창 이동·크기 변경, 자동 붙여넣기 |
| 입력 모니터링 | 두 단계 단축키의 두 번째 키 감지 |

단일 단축키, 앱 실행, 웹사이트 열기와 클립보드 복사는 위 권한 없이도 사용할 수 있습니다. 자세한 내용은 [개인정보 보호 안내](docs/PRIVACY.md)를 확인하세요.

## 업데이트

Wikey는 실행 중 하루에 한 번 새 버전을 확인합니다. **Wikey → 업데이트 확인…** 또는 **설정 → 업데이트**에서 직접 확인할 수 있으며 자동 다운로드 여부는 사용자가 선택합니다.

## 개발

필요 환경:

- macOS 15 이상
- Xcode와 Swift 6 도구 체인
- Xcode 프로젝트 재생성 시 [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```sh
./script/build_and_run.sh
swift test
xcodegen generate
```

배포 패키지 제작과 공증 절차는 [배포 안내](docs/DISTRIBUTION.md)에 정리되어 있습니다.

## 기여하기

버그 제보와 개선 제안을 환영합니다. [기여 안내](CONTRIBUTING.md)와 [행동 강령](CODE_OF_CONDUCT.md)을 읽어주세요. 보안 문제는 공개 이슈 대신 [보안 정책](SECURITY.md)의 방법으로 알려주세요.

## 라이선스

[MIT License](LICENSE)

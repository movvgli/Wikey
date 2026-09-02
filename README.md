# Wikey

단축키 하나로 자주 하는 일을 묶어 실행하는 macOS 앱입니다.

앱을 열고, 웹사이트를 띄우고, 자주 쓰는 문구를 붙여넣고, 여러 창을 원하는 위치에 배치할 수 있습니다. 모든 설정은 Mac 안에만 저장됩니다.

![Wikey 홈 화면](docs/images/home.png)

[English](README.en.md) · [설치 안내](docs/INSTALL.md) · [개인정보 보호](docs/PRIVACY.md)

## 할 수 있는 일

- 한 번에 누르는 전역 단축키
- 최대 두 단계로 이어 누르는 단축키
- 앱과 기본 브라우저로 웹사이트 열기
- 서식, 링크, 목록, 인라인 이미지가 포함된 템플릿 복사·붙여넣기
- 여러 앱을 실행하고 모니터별 전체, 1/2, 1/3, 2/3, 사분면으로 배치
- 로그인 시 자동 실행과 메뉴 막대 빠른 실행

워크플로에 여러 동작을 넣으면 위에서 아래 순서로 실행합니다. 한 동작이 실패해도 가능한 나머지 동작은 계속 실행합니다.

## 요구 사항

- macOS 15 이상
- 소스에서 빌드할 경우 Xcode와 Swift 6 도구 체인

## 설치

GitHub Releases의 DMG는 현재 Apple 공증 전 시험 배포본입니다. 다른 Mac에서는 개발자를 확인할 수 없다는 안내가 표시될 수 있습니다. 자세한 설치 방법과 권한 설명은 [설치 안내](docs/INSTALL.md)를 확인하세요.

소스에서 직접 실행하려면:

```sh
./script/build_and_run.sh
```

테스트:

```sh
swift test
```

Xcode 프로젝트를 다시 생성하려면 [XcodeGen](https://github.com/yonaskolb/XcodeGen)을 설치한 뒤 실행합니다.

```sh
xcodegen generate
```

## 권한

Wikey는 필요한 기능에만 macOS 권한을 요청합니다.

| 권한 | 사용하는 기능 |
| --- | --- |
| 손쉬운 사용 | 다른 앱 창 이동·크기 변경, 자동 붙여넣기 |
| 입력 모니터링 | 두 단계 단축키의 두 번째 키 감지 |

단일 단축키, 앱 실행, 웹사이트 열기와 클립보드 복사는 위 권한 없이도 사용할 수 있습니다.

## DMG 만들기

로컬 설치용 DMG:

```sh
./script/package_release.sh 1.0.0 1
```

결과물은 `dist/Wikey-1.0.0.dmg`와 SHA-256 체크섬입니다. Developer ID 인증서와 공증 프로필이 준비되면 같은 스크립트로 서명·공증할 수 있습니다.

```sh
WIKEY_CODESIGN_IDENTITY="Developer ID Application: 이름 (TEAMID)" \
WIKEY_NOTARY_PROFILE="wikey-notary" \
./script/package_release.sh 1.0.0 1
```

배포 전 준비 사항은 [배포 안내](docs/DISTRIBUTION.md)에 정리되어 있습니다.

## 기여하기

버그 제보와 개선 제안을 환영합니다. 작업을 시작하기 전에 [기여 안내](CONTRIBUTING.md)와 [행동 강령](CODE_OF_CONDUCT.md)을 읽어주세요. 보안 문제는 공개 이슈 대신 [보안 정책](SECURITY.md)의 방법으로 알려주세요.

## 라이선스

[MIT License](LICENSE)

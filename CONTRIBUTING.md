# Contributing to Wikey

작고 확인 가능한 변경을 선호합니다. 기능 제안은 구현 전에 이슈로 사용 사례와 기대 동작을 먼저 공유해주세요.

## 개발 환경

- macOS 15 이상
- Xcode
- Swift 6 도구 체인
- Xcode 프로젝트를 재생성할 경우 XcodeGen

## 시작하기

```sh
git clone https://github.com/movvgli/Wikey.git
cd Wikey
swift test
./script/build_and_run.sh
```

## 변경 원칙

- 앱 샌드박스를 우회하는 기능이나 셸·AppleScript 실행 기능은 현재 범위에 포함하지 않습니다.
- 외부 앱 제어 코드는 서비스 경계 안에 두고 SwiftUI 화면과 분리합니다.
- 새 동작에는 정상 경로와 실패 경로 테스트를 함께 추가합니다.
- 사용자의 기존 워크플로 및 템플릿 파일과의 호환성을 유지합니다.
- 권한이 없을 때 관련 기능만 실패하고 나머지 기능은 계속 동작해야 합니다.

## Pull Request

PR에는 다음을 포함해주세요.

- 바뀐 사용자 동작과 이유
- 직접 확인한 macOS 버전
- 실행한 테스트
- 화면 변경이 있다면 전후 이미지
- 권한, 저장 형식 또는 단축키 호환성에 미치는 영향

`swift test`가 통과해야 하며 생성된 앱, DMG, 개인 인증서와 로컬 설정 파일은 커밋하지 않습니다.

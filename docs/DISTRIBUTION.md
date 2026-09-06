# 배포 안내

## 정식 배포 경로

정식 배포는 **로컬에서 서명·공증한 DMG → GitHub Release → 서명된 업데이트 피드** 순서로 진행합니다. `v1.2.6` 같은 정식 태그를 푸시하는 것만으로 DMG가 만들어지거나 배포되지는 않습니다.

앱을 로컬에서 실행하거나 Developer ID로 서명한 것과 Apple 공증·공개 배포 완료는 서로 다른 상태입니다. 아래 명령의 `1.2.6 (1002006)`은 배포 절차 예시이며, 해당 버전이 이미 공증되거나 게시되었다는 뜻은 아닙니다. 실제 게시 상태는 [GitHub Releases](https://github.com/movvgli/Wikey/releases)에서 확인합니다.

## 1. 소스와 버전 확인

- `project.yml`의 `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`을 확인하고 Xcode 프로젝트와 생성된 Info.plist를 함께 갱신합니다.
- 빌드 번호는 `major × 1000000 + minor × 1000 + patch`를 사용합니다. 예: `1.2.6 → 1002006`.
- 테스트와 배포 대상 기능의 실제 실행을 확인합니다. 자동 테스트만으로 모든 외부 앱에서의 입력·첨부 동작을 보장하지 않습니다.
- 소스를 커밋하고 `main`에 푸시한 뒤 CI 결과를 확인합니다. 릴리스 태그는 실제 패키징한 소스 커밋을 가리켜야 합니다.

## 2. Developer ID 서명과 Apple 공증

공개 배포용 DMG에는 Apple Developer Program 팀의 `Developer ID Application` 인증서와 키체인에 저장된 공증 프로필이 필요합니다.

```sh
WIKEY_CODESIGN_IDENTITY="Developer ID Application: 이름 (TEAMID)" \
WIKEY_NOTARY_PROFILE="wikey-notary" \
./script/package_release.sh 1.2.6 1002006
```

이 스크립트는 다음 순서로 동작합니다.

1. 앱, 로그인 헬퍼, 내장 라이브러리와 Sparkle의 중첩 헬퍼를 Hardened Runtime·보안 타임스탬프로 서명합니다.
2. 앱 버전과 빌드 번호, 내장 업데이트 설정, 코드 서명을 확인합니다.
3. DMG를 만들고 검증한 뒤 서명합니다.
4. `notarytool`로 제출하고 결과를 기다립니다.
5. 승인된 티켓을 DMG에 스테이플하고 Gatekeeper 평가를 수행합니다.
6. 최종 DMG의 SHA-256 체크섬을 생성합니다.

검증은 업로드할 최종 파일을 대상으로 합니다. 서명이나 스테이플 작업이 끝난 뒤 파일을 변경하면 체크섬과 업데이트 서명을 다시 만들어야 합니다.

```sh
codesign --verify --deep --strict --verbose=2 dist/Wikey.app
hdiutil verify dist/Wikey-1.2.6.dmg
xcrun stapler validate dist/Wikey-1.2.6.dmg
spctl --assess --type open --context context:primary-signature --verbose=2 dist/Wikey-1.2.6.dmg
(cd dist && shasum -a 256 -c Wikey-1.2.6.dmg.sha256)
```

앱과 헬퍼의 서명 팀, `get-task-allow` 미포함, 지원 아키텍처, DMG 안에 들어간 앱의 버전도 확인합니다. DMG의 스테이플 성공과 앱 번들 자체의 스테이플 여부를 혼동하지 않습니다.

## 3. GitHub Release 게시

1. 검증한 소스 커밋에 정식 태그(예: `v1.2.6`)를 붙여 푸시합니다. 기존 릴리스 태그를 덮어쓰지 않습니다.
2. 해당 태그의 릴리스 초안을 만들고 `dist/Wikey-1.2.6.dmg`와 `dist/Wikey-1.2.6.dmg.sha256`를 첨부합니다.
3. 릴리스 노트에 변경 사항, 필요한 권한, 확인된 제한을 적습니다. Apple 공증 완료 문구는 실제 승인과 최종 파일 검증 후에만 넣습니다.
4. 첨부 파일과 대상 태그를 확인한 뒤 정식 릴리스를 공개합니다.
5. 공개 다운로드의 파일 크기와 SHA-256이 로컬의 최종 파일과 일치하는지 확인합니다.

`1.2.6` 변경 안내에는 앱 목록·앱별 단축키, 템플릿 삭제, 레이아웃 단축키, 워크플로 순차 실행과 실패 시 중단, 대기·중지 동작, 화면 간 일관성 개선을 포함합니다. 첨부 업로드나 모든 외부 앱에서의 동작을 일괄 보장하지 않습니다.

## 4. Sparkle 업데이트 피드 게시

정식 DMG가 공개되고 검증된 다음 아래 워크플로를 실행합니다.

```sh
gh workflow run publish-appcast.yml \
  --repo movvgli/Wikey \
  --ref main \
  -f version=1.2.6
```

[Publish signed update feed](../.github/workflows/publish-appcast.yml)는 공개 릴리스의 DMG를 내려받아 기존 Sparkle 키로 서명한 appcast를 만듭니다. 피드 생성 도구를 준비하기 위한 CI 빌드는 로컬에서 공증한 공개 DMG를 대체하지 않습니다. 또한 이 워크플로가 공증을 수행하는 것은 아닙니다.

워크플로는 `appcast.xml`을 릴리스에 첨부하고, `update-feed` 브랜치에 피드와 릴리스 노트를 게시합니다. 앱은 [공개 피드](https://raw.githubusercontent.com/movvgli/Wikey/update-feed/appcast.xml)를 읽고 EdDSA 서명을 검증한 뒤 DMG를 업데이트로 받아들입니다.

워크플로 성공 후에도 다음을 확인합니다.

- 최상단 항목의 버전·빌드 번호와 최소 macOS 버전
- 정식 릴리스를 가리키는 다운로드 URL, 실제 파일 크기와 EdDSA 서명
- 이전 버전의 다운로드 URL이 그대로 유지되는지
- 릴리스 노트 링크와 공개 다운로드가 열리는지
- 기존 설치본의 **업데이트 확인…**에서 새 버전을 찾는지

## 시험 빌드와 정식 피드 주의

인증서·공증 환경 변수를 생략한 `package_release.sh` 실행은 로컬용 ad-hoc DMG를 만듭니다. 이를 정식 배포 파일로 게시하지 않습니다.

[Preview release](../.github/workflows/release.yml)는 `preview-v*.*.*` 태그에만 반응하며, Apple 공증 없이 시험 릴리스를 만듭니다. 시험 릴리스는 최신 정식 버전으로 지정하지 않고 정식 `update-feed` 브랜치에도 게시하지 않습니다. 정식 업데이트 피드는 검증된 공개 릴리스에 대해 `publish-appcast.yml`로만 게시합니다.

## Sparkle 업데이트 서명

Sparkle의 `generate_keys`로 만든 개인 키는 로컬 키체인에 보관합니다. 공개 키만 `SUPublicEDKey`로 앱에 포함하며, 개인 키는 코드나 릴리스 파일에 넣지 않습니다.

피드 게시에는 저장소의 Actions secret `SPARKLE_ED_PRIVATE_KEY`를 사용합니다. 워크플로는 이 비밀값으로 appcast 서명을 만들며 로그나 공개 브랜치에는 개인 키를 기록하지 않습니다. 기존 앱의 `SUPublicEDKey`와 맞는 키를 유지합니다.

키를 잃으면 기존 설치본이 새 키로 서명한 업데이트를 신뢰할 수 없습니다. 키체인 외에 암호화된 별도 백업을 보관하세요. 인증서, `.p12` 파일, 앱 전용 암호와 공증 자격 증명은 저장소에 커밋하지 않습니다.

## 릴리스 체크리스트

- `swift test` 통과
- 배포 소스 커밋·태그·버전·빌드 번호 일치
- 앱, 헬퍼와 내장 라이브러리 서명 확인
- DMG `hdiutil verify` 통과
- appcast 버전, 다운로드 URL과 EdDSA 서명 확인
- GitHub Actions secret `SPARKLE_ED_PRIVATE_KEY` 설정 확인
- 정식 DMG의 Apple 공증 승인, `stapler validate`와 Gatekeeper 평가 통과
- 다운로드한 공개 DMG의 체크섬 일치
- 새 사용자 계정에서 설치와 권한 흐름 확인
- 서명된 피드 게시 완료 및 기존 앱의 업데이트 확인
- 릴리스 노트에 검증된 공증 여부와 기능 제한 명시

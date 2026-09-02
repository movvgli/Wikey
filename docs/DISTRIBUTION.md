# 배포 안내

## 현재 상태

태그를 푸시하면 GitHub Actions가 테스트를 실행하고 ad-hoc 서명된 DMG, SHA-256 체크섬과 Sparkle 업데이트 피드를 시험 릴리스로 게시합니다. 이 빌드는 Apple 공증본이 아니므로 macOS에서 개발자 확인 경고가 표시될 수 있습니다.

업데이트 피드는 `update-feed` 브랜치의 `appcast.xml`에 게시됩니다. 앱은 EdDSA 서명을 검증한 뒤에만 DMG를 업데이트로 받아들입니다.

## 로컬 시험 배포

```sh
./script/package_release.sh 1.0.0 1
shasum -a 256 -c dist/Wikey-1.0.0.dmg.sha256
```

## Developer ID 배포

공개 배포용 DMG에는 Apple Developer Program 팀의 `Developer ID Application` 인증서가 필요합니다.

1. 앱, 로그인 헬퍼와 내장 라이브러리를 Hardened Runtime으로 서명합니다.
2. DMG를 서명합니다.
3. `notarytool`로 공증을 제출합니다.
4. 승인된 티켓을 DMG에 스테이플합니다.
5. Gatekeeper 평가와 체크섬을 확인합니다.

현재 스크립트는 키체인에 인증서와 공증 프로필이 준비된 환경에서 이 과정을 수행합니다.

```sh
WIKEY_CODESIGN_IDENTITY="Developer ID Application: 이름 (TEAMID)" \
WIKEY_NOTARY_PROFILE="wikey-notary" \
./script/package_release.sh 1.0.0 1
```

인증서, `.p12` 파일, 앱 전용 암호와 공증 자격 증명은 저장소에 커밋하지 않습니다.

## Sparkle 업데이트 서명

Sparkle의 `generate_keys`로 만든 개인 키는 로컬 키체인에 보관합니다. 공개 키만 `SUPublicEDKey`로 앱에 포함하며, 개인 키는 코드나 릴리스 파일에 넣지 않습니다.

GitHub Actions 릴리스를 사용하려면 내보낸 개인 키를 저장소의 Actions secret `SPARKLE_ED_PRIVATE_KEY`로 등록해야 합니다. 워크플로는 이 비밀값으로 appcast 서명을 만들며 로그나 공개 브랜치에는 개인 키를 기록하지 않습니다.

키를 잃으면 기존 설치본이 새 키로 서명한 업데이트를 신뢰할 수 없습니다. 키체인 외에 암호화된 별도 백업을 보관하세요.

## 릴리스 체크리스트

- `swift test` 통과
- 버전과 빌드 번호 확인
- 앱, 헬퍼와 내장 라이브러리 서명 확인
- DMG `hdiutil verify` 통과
- appcast 버전, 다운로드 URL과 EdDSA 서명 확인
- GitHub Actions secret `SPARKLE_ED_PRIVATE_KEY` 설정 확인
- 공증을 사용하는 경우 `stapler validate` 통과
- 새 사용자 계정에서 설치와 권한 흐름 확인
- 릴리스 노트에 공증 여부 명시

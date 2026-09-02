# 배포 안내

## 현재 상태

태그를 푸시하면 GitHub Actions가 테스트를 실행하고 ad-hoc 서명된 DMG와 SHA-256 체크섬을 시험 릴리스로 게시합니다. 이 빌드는 Apple 공증본이 아니므로 macOS에서 개발자 확인 경고가 표시될 수 있습니다.

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

## 릴리스 체크리스트

- `swift test` 통과
- 버전과 빌드 번호 확인
- 앱, 헬퍼와 내장 라이브러리 서명 확인
- DMG `hdiutil verify` 통과
- 공증을 사용하는 경우 `stapler validate` 통과
- 새 사용자 계정에서 설치와 권한 흐름 확인
- 릴리스 노트에 공증 여부 명시

# 설치 안내

## GitHub Releases에서 설치

1. 최신 릴리스의 `Wikey-버전.dmg`를 내려받습니다.
2. DMG를 열고 Wikey를 Applications 폴더로 드래그합니다.
3. 응용 프로그램 폴더의 Wikey를 엽니다.

현재 공개 DMG는 Apple 공증 전 시험 배포본입니다. macOS가 개발자를 확인할 수 없다고 표시하면 Finder에서 Wikey를 Control-클릭한 뒤 **열기**를 선택하고, 다시 **열기**를 선택하세요. 이 선택은 신뢰할 수 있는 출처에서 받은 파일인지 확인한 경우에만 사용하세요.

## 권한 켜기

Wikey의 **설정 → 권한**에서 필요한 기능만 켭니다.

- **손쉬운 사용:** 앱 창 배치와 자동 붙여넣기
- **입력 모니터링:** 두 단계 단축키

시스템 설정에서 권한을 바꾼 뒤 Wikey로 돌아오면 상태가 자동 갱신됩니다. 계속 꺼짐으로 보이면 Wikey를 완전히 종료한 뒤 다시 실행하세요.

앱을 다시 빌드하거나 교체하면 macOS가 새 앱으로 인식해 권한을 다시 요청할 수 있습니다.

## 소스에서 실행

```sh
git clone https://github.com/movvgli/Wikey.git
cd Wikey
./script/build_and_run.sh
```

빌드된 앱은 `dist/Wikey.app`에 생성됩니다.

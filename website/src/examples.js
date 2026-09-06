// Fictional public data only; never import user settings or captures.
export const examples = {
  workflow: {
    tab: "워크플로", category: "여러 동작을 순서대로", title: "하루 시작",
    description: "자주 반복하는 준비 과정을 하나로 묶어요.",
    steps: [
      { title: "메모 앱 열기", detail: "작성할 앱을 먼저 준비", type: "앱 실행" },
      { title: "오늘의 할 일 붙여넣기", detail: "미리 저장한 문구 사용", type: "템플릿" },
      { title: "작업할 창 정리하기", detail: "저장한 위치와 크기로 배치", type: "레이아웃" },
    ],
    result: "단축키를 누르면 위에서 아래 순서로 실행",
  },
  apps: {
    tab: "앱", category: "하나의 앱을 바로", title: "자주 쓰는 앱",
    description: "목록에서 앱을 찾고 단축키를 지정해요.",
    apps: [{ name: "메모", shortcut: "⌃ ⌥ W" }, { name: "캘린더", shortcut: "⌃ ⌥ C" }, { name: "계산기", shortcut: "⌃ ⌥ N" }],
    result: "다른 앱을 사용 중에도 지정한 앱을 열기",
  },
  layout: {
    tab: "레이아웃", category: "창 배치를 한 번에", title: "나란히 작업하기",
    description: "앱마다 사용할 화면과 위치를 정해요.",
    result: "단축키 하나로 저장한 창 배치 불러오기",
  },
};

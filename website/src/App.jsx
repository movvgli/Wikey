import { useEffect, useState } from "react";
import { AppWindow, ArrowDown, ArrowRight, Check, Command, Files, GridFour, Moon, Sun } from "@phosphor-icons/react";
import { examples } from "./examples.js";

const RELEASE_URL = "https://github.com/movvgli/Wikey/releases/latest";
const GITHUB_URL = "https://github.com/movvgli/Wikey";

export function Demo({ initialSelected = "workflow" }) {
  const [selected, setSelected] = useState(initialSelected);
  const example = examples[selected];
  return (
    <figure className="demo">
      <div className="demo-chrome"><span className="window-dots" aria-hidden="true"><i /><i /><i /></span><span>Wikey</span><span className="demo-label">기능 미리보기</span></div>
      <div className="demo-body">
        <div className="demo-switcher" role="group" aria-label="미리 볼 기능 선택">
          {Object.entries(examples).map(([key, value]) => <button type="button" key={key} aria-pressed={key === selected} onClick={() => setSelected(key)}>{value.tab}</button>)}
        </div>
        <div className="demo-heading"><div><p className="eyebrow">{example.category}</p><h2>{example.title}</h2></div><kbd aria-label="예시 단축키 Control Option W">⌃ ⌥ W</kbd></div>
        <p className="demo-description">{example.description}</p>
        <div className="example-content" aria-live="polite" aria-atomic="true">
          {selected === "workflow" && <ol className="flow-steps">{example.steps.map((step, index) => <li key={step.title}><span className="step-index">{index + 1}</span><div><strong>{step.title}</strong><span>{step.detail}</span></div><span className="step-type">{step.type}</span></li>)}</ol>}
          {selected === "apps" && <div className="app-example"><div className="example-table-head"><span>앱 이름</span><span>단축키</span></div>{example.apps.map((app) => <div className="example-app-row" key={app.name}><span className="sample-app"><AppWindow size={21} /></span><strong>{app.name}</strong><kbd>{app.shortcut}</kbd></div>)}</div>}
          {selected === "layout" && <div className="layout-example"><div className="display-preview"><div><AppWindow size={24} /><span>브라우저</span><small>왼쪽 절반</small></div><div><Files size={24} /><span>메모</span><small>오른쪽 절반</small></div></div><p>저장해 둔 위치와 크기로 창을 정리합니다.</p></div>}
        </div>
        <div className="demo-result"><Check size={16} weight="bold" /><span>{example.result}</span></div>
      </div>
      <figcaption>설명을 위해 만든 가상 예시입니다. 실제 개인 설정이 아닙니다.</figcaption>
    </figure>
  );
}

export function App() {
  const [theme, setTheme] = useState(() => {
    try { return localStorage.getItem("wikey-site-theme") === "dark" ? "dark" : "light"; }
    catch { return "light"; }
  });
  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    try { localStorage.setItem("wikey-site-theme", theme); } catch { /* Storage is optional. */ }
  }, [theme]);
  return (
    <div className="site-shell" id="top">
      <a className="skip-link" href="#main">본문으로 바로가기</a>
      <header className="site-header">
        <a className="brand" href="#top" aria-label="Wikey 홈"><img src="./assets/wikey-icon.png" alt="" width="34" height="34" /><span>Wikey</span></a>
        <nav aria-label="주요 메뉴"><a href="#features">사용 방법</a><a href="#privacy">개인정보</a><a href="#install">설치</a><button className="theme-toggle" type="button" onClick={() => setTheme(theme === "light" ? "dark" : "light")} aria-label={`${theme === "light" ? "어두운" : "밝은"} 화면으로 전환`}>{theme === "light" ? <Moon size={19} /> : <Sun size={19} />}</button></nav>
      </header>
      <main id="main">
        <section className="hero" aria-labelledby="hero-title">
          <div className="hero-copy"><p className="eyebrow">Mac을 쓰는 나만의 순서</p><h1 id="hero-title">매번 하던 일,<br />한 번에 시작.</h1><p className="hero-description">앱을 열고, 자주 쓰는 문구를 붙이고,<br className="desktop-break" /> 창을 정리하는 일.<br />Wikey에 순서를 저장하고 단축키로 실행하세요.</p><a className="button button--primary" href={RELEASE_URL}>Mac용 Wikey 다운로드 <ArrowDown size={18} weight="bold" /></a><p className="metadata">최신 버전 1.2.7 · macOS 14 이상<br />Apple Silicon 및 Intel · Apple 공증 완료<br />무료 · Wikey 가입 없이 사용</p></div>
          <Demo />
        </section>
        <section className="feature-section" id="features" aria-labelledby="features-title">
          <div className="section-intro"><p className="eyebrow">하나부터 시작해도 괜찮아요</p><h2 id="features-title">앱 하나를 여는 것부터.<br />여러 동작을 이어서 하는 것까지.</h2><p>워크플로는 여러 동작을 원하는 순서로 묶어 둔 것입니다.<br />복잡한 코드를 쓰지 않아도 만들 수 있어요.</p></div>
          <div className="feature-list">
            <article><span className="feature-icon"><AppWindow size={24} /></span><div><h3>자주 여는 앱에 단축키 하나</h3><p><b>앱</b> 탭에서 설치된 앱을 찾고, 그 자리에서 단축키를 지정하세요. 다른 앱을 쓰다가도 바로 열 수 있습니다.</p></div><span className="feature-number">01</span></article>
            <article><span className="feature-icon"><Command size={24} /></span><div><h3>반복하는 순서를 워크플로로</h3><p><b>워크플로</b>에서 앱 실행, 템플릿 붙여넣기, Enter 입력 등을 순서대로 추가하세요. 처리 시간이 필요한 곳에는 대기도 넣을 수 있어요.</p></div><span className="feature-number">02</span></article>
            <article><span className="feature-icon"><GridFour size={24} /></span><div><h3>내가 쓰기 편한 창 배치로</h3><p><b>레이아웃</b>에 앱별 위치와 크기를 저장하세요. 단축키로 불러오거나 워크플로의 한 동작으로 사용할 수 있습니다.</p></div><span className="feature-number">03</span></article>
          </div>
          <p className="feature-note">자주 쓰는 문구는 <b>템플릿</b>에 저장해 재사용하세요. 이미지·파일 붙여넣기도 동작으로 추가할 수 있습니다.</p>
        </section>
        <section className="privacy-section" id="privacy" aria-labelledby="privacy-title">
          <div><p className="eyebrow">개인 작업은 공개하지 않아요</p><h2 id="privacy-title">설정은 내 Mac에.</h2></div>
          <div className="privacy-copy"><p>워크플로, 템플릿, 단축키와 레이아웃은 기본적으로 내 Mac에 저장됩니다.</p><p>원하면 iCloud 동기화를 켜서 설정과 첨부 파일 사본을 개인 iCloud Drive 폴더에 저장할 수 있습니다. 동기화는 시험 기능이며 기본값은 꺼짐입니다.</p><p className="small-copy">자동 업데이트를 확인할 때는 GitHub에 연결합니다. 직접 연 웹사이트나 붙여넣은 외부 앱에서의 데이터 처리는 해당 서비스의 정책을 따릅니다.</p><a className="text-link" href={`${GITHUB_URL}/blob/main/docs/PRIVACY.md`}>개인정보 안내 읽기 <ArrowRight size={16} /></a></div>
        </section>
        <section className="install-section" id="install" aria-labelledby="install-title">
          <div className="install-heading"><div><p className="eyebrow">처음 쓰는 분을 위해</p><h2 id="install-title">설치하고, 작은 동작부터.</h2></div><a className="button button--primary" href={RELEASE_URL}>Wikey 다운로드 <ArrowDown size={18} /></a></div>
          <ol className="install-steps"><li><span>1</span><h3>다운로드하고 옮기기</h3><p>GitHub 릴리스에서 DMG 파일을 받고, 열어서 Wikey를 응용 프로그램 폴더로 옮겨주세요.</p></li><li><span>2</span><h3>필요한 권한만 켜기</h3><p>첫 실행 안내를 따라가세요. 단순 앱 실행은 추가 권한 없이 시작할 수 있어요.</p></li><li><span>3</span><h3>하나를 만들고 시험하기</h3><p>앱 단축키 하나부터 지정해 보세요. 붙여넣는 워크플로는 빈 테스트 문서에서 먼저 확인하세요.</p></li></ol>
          <div className="permission-note"><strong>어떤 권한이 필요한가요?</strong><p>자동 붙여넣기·Enter 입력·창 배치에는 <b>손쉬운 사용</b>이 필요합니다. 두 단계 단축키를 쓰면 <b>입력 모니터링</b>도 켜주세요. 외부 앱에 따라 붙여넣기·창 크기 변경 지원은 다를 수 있습니다.</p><a className="text-link" href={`${GITHUB_URL}/blob/main/docs/INSTALL.md`}>자세한 설치 안내 <ArrowRight size={16} /></a></div>
        </section>
      </main>
      <footer><a className="brand" href="#top"><span>Wikey</span></a><p>반복은 짧게, 하던 일에 더 가까이.</p><div><a href={GITHUB_URL}>GitHub</a><a href={`${GITHUB_URL}/releases`}>업데이트 내역</a><a href={`${GITHUB_URL}/blob/main/docs/PRIVACY.md`}>개인정보 보호</a></div></footer>
    </div>
  );
}

import { useEffect, useState } from "react";
import {
  AppWindow,
  ArrowDown,
  ArrowRight,
  Browser,
  ClipboardText,
  GridFour,
  Moon,
  Sun,
} from "@phosphor-icons/react";

const RELEASE_URL = "https://github.com/movvgli/Wikey/releases/latest";
const GITHUB_URL = "https://github.com/movvgli/Wikey";

const actions = [
  { icon: AppWindow, label: "앱 실행" },
  { icon: Browser, label: "웹사이트 열기" },
  { icon: ClipboardText, label: "템플릿 붙여넣기" },
  { icon: GridFour, label: "창 배치" },
];

function ProductWindow({ crop = false, className = "" }) {
  return (
    <div className={`product-window ${crop ? "product-window--crop" : ""} ${className}`}>
      <div className="product-image-wrap">
        <img
          src="/assets/wikey-workflows.png"
          alt="Wikey에서 단축키가 지정된 워크플로를 관리하는 화면"
        />
      </div>
    </div>
  );
}

function SectionNumber({ children }) {
  return <span className="section-number">{children}</span>;
}

export function App() {
  const [theme, setTheme] = useState(() => {
    if (typeof window === "undefined") return "light";
    return localStorage.getItem("wikey-site-theme") || "light";
  });

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    localStorage.setItem("wikey-site-theme", theme);
  }, [theme]);

  const toggleTheme = () => setTheme((current) => (current === "light" ? "dark" : "light"));

  return (
    <div className="site-shell" id="top">
      <header className="site-header">
        <a className="brand" href="#top" aria-label="Wikey 홈">
          <img src="/assets/wikey-icon.png" alt="" />
          <span>Wikey</span>
        </a>

        <nav aria-label="주요 메뉴">
          <a href="#features">기능</a>
          <a href="#install">설치</a>
          <a href={GITHUB_URL} target="_blank" rel="noreferrer">GitHub</a>
          <button className="theme-toggle" type="button" onClick={toggleTheme} aria-label={`${theme === "light" ? "어두운" : "밝은"} 화면으로 전환`}>
            <span className={theme === "light" ? "is-active" : ""}><Sun size={15} weight="bold" /></span>
            <span className={theme === "dark" ? "is-active" : ""}><Moon size={14} weight="fill" /></span>
          </button>
        </nav>
      </header>

      <main>
        <section className="hero" aria-labelledby="hero-title">
          <div className="hero-copy">
            <p className="eyebrow">macOS workflow automation</p>
            <h1 id="hero-title">반복하는 일을,<br />단축키 하나로.</h1>
            <p className="hero-description">
              앱 실행, 웹사이트 열기, 문구 붙여넣기와 창 배치까지.
              원하는 순서대로 연결하고 어디서든 바로 실행하세요.
            </p>
            <div className="hero-actions">
              <a className="button button--primary" href={RELEASE_URL}>
                Wikey 내려받기 <ArrowDown size={18} weight="bold" />
              </a>
            </div>
            <p className="metadata">macOS 15 이상 · Apple Silicon 및 Intel</p>
          </div>

          <ProductWindow className="hero-window" />
        </section>

        <section className="story-section" id="features">
          <div className="story-copy">
            <SectionNumber>1</SectionNumber>
            <h2>앱을 열고, 문구를 붙이고,<br />창까지 배치해요.</h2>
            <p>필요한 동작을 차례대로 추가하면 Wikey가 정해진 순서로 실행합니다.</p>
            <a className="text-link" href="#shortcuts">작동 방식 자세히 보기 <ArrowRight size={17} weight="bold" /></a>
          </div>

          <div className="action-showcase" aria-label="워크플로에 연결할 수 있는 동작">
            <div className="action-strip">
              {actions.map(({ icon: Icon, label }, index) => (
                <div className="action-item" key={label}>
                  <span className="action-icon"><Icon size={21} weight="duotone" /></span>
                  <span>{label}</span>
                  {index < actions.length - 1 && <ArrowRight className="action-arrow" size={16} weight="bold" aria-hidden="true" />}
                </div>
              ))}
            </div>
            <ProductWindow crop />
          </div>
        </section>

        <section className="shortcut-section" id="shortcuts">
          <div className="story-copy">
            <SectionNumber>2</SectionNumber>
            <h2>한 번 또는 두 단계 단축키로<br />어디서나.</h2>
            <p>다른 앱을 사용 중이어도 지정한 단축키를 누르면 워크플로가 바로 시작됩니다.</p>
          </div>
          <div className="shortcut-visual">
            <div className="shortcut-key" aria-label="옵션 2 단축키">
              <span>⌥</span><span>2</span>
            </div>
            <div className="shortcut-line" aria-hidden="true" />
            <ProductWindow />
          </div>
        </section>

        <section className="plain-section">
          <div className="story-copy">
            <SectionNumber>3</SectionNumber>
            <h2>내 작업은 내 Mac에만.</h2>
            <p>워크플로와 템플릿은 외부 서버로 보내지 않고 이 Mac에 저장합니다. 사용하는 기능에 필요한 권한만 선택해서 켤 수 있어요.</p>
          </div>
          <div className="privacy-panel">
            <img src="/assets/wikey-icon.png" alt="Wikey 앱 아이콘" />
            <div>
              <strong>가볍고, 빠르고, 안전하게</strong>
              <span>앱 실행과 클립보드 복사는 별도 권한 없이 사용할 수 있습니다.</span>
            </div>
          </div>
        </section>

        <section className="download-section" id="install">
          <img src="/assets/wikey-icon.png" alt="" />
          <div>
            <p className="eyebrow">Ready when you are</p>
            <h2>자주 하는 일을 더 짧게 시작하세요.</h2>
            <p>Apple 공증을 완료한 최신 버전을 GitHub에서 내려받을 수 있습니다.</p>
          </div>
          <a className="button button--primary" href={RELEASE_URL}>Wikey 내려받기 <ArrowDown size={18} weight="bold" /></a>
        </section>
      </main>

      <footer>
        <span>Wikey · macOS workflow automation</span>
        <div>
          <a href={GITHUB_URL} target="_blank" rel="noreferrer">소스</a>
          <a href={`${GITHUB_URL}/releases`} target="_blank" rel="noreferrer">릴리스</a>
          <a href={`${GITHUB_URL}/blob/main/docs/PRIVACY.md`} target="_blank" rel="noreferrer">개인정보 보호</a>
        </div>
      </footer>
    </div>
  );
}

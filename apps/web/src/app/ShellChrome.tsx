import { pathForTab } from "./tabRoute";
import type { WebAppTab } from "./useWebAppController";
import { type MouseEvent, type ReactNode } from "react";

const TAB_ORDER: WebAppTab[] = ["sequence", "taskPool", "schedule"];

const TAB_META: Record<WebAppTab, { label: string; title: string }> = {
  sequence: {
    label: "主序列",
    title: "主序列"
  },
  taskPool: {
    label: "任务池",
    title: "任务池"
  },
  schedule: {
    label: "时间视图",
    title: "时间视图"
  }
};

interface ShellChromeProps {
  currentTab: WebAppTab;
  reserveBottomDock?: boolean;
  onOpenSettings: () => void;
  onTabLinkClick: (event: MouseEvent<HTMLAnchorElement>, tab: WebAppTab) => void;
  children: ReactNode;
}

export default function ShellChrome({
  currentTab,
  reserveBottomDock = false,
  onOpenSettings,
  onTabLinkClick,
  children
}: ShellChromeProps) {
  const activeMeta = TAB_META[currentTab];

  return (
    <div className="shell-layout">
      <header className="shell-header">
        <h1 className="shell-title" id="shell-route-title">
          <span key={currentTab} className="shell-title-text">
            {activeMeta.title}
          </span>
        </h1>
        <div className="shell-header-actions">
          <button type="button" className="btn-text shell-settings-button" onClick={onOpenSettings}>
            设置
          </button>
        </div>
      </header>

      <nav className="tab-switcher" aria-label="主导航">
        <ul className="shell-nav-list" role="list">
          {TAB_ORDER.map((tab) => (
            <li key={tab}>
              <a
                className={`tab-switcher-link${currentTab === tab ? " active" : ""}`}
                href={pathForTab(tab)}
                aria-current={currentTab === tab ? "page" : undefined}
                onClick={(event) => onTabLinkClick(event, tab)}
              >
                <span className="tab-switcher-label">{TAB_META[tab].label}</span>
              </a>
            </li>
          ))}
        </ul>
      </nav>

      <section className="shell-panel" aria-labelledby="shell-route-title">
        <div className={`shell-scroll-viewport${reserveBottomDock ? " has-bottom-dock" : ""}`}>
          <div key={currentTab} className="route-scene">
            {children}
          </div>
        </div>
      </section>
    </div>
  );
}

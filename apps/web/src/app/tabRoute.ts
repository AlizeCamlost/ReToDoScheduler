import type { WebAppTab } from "./useWebAppController";

const DEFAULT_TAB: WebAppTab = "sequence";
const TAB_QUERY_KEY = "tab";

const TAB_PATHS: Record<WebAppTab, string> = {
  sequence: "/",
  taskPool: "/task-pool",
  schedule: "/schedule"
};

const PATH_TAB_ALIASES: Record<string, WebAppTab> = {
  "/": "sequence",
  "/sequence": "sequence",
  "/task-pool": "taskPool",
  "/schedule": "schedule"
};

const normalizePath = (pathname: string): string => {
  if (!pathname || pathname === "/") return "/";
  const trimmed = pathname.replace(/\/+$/, "");
  return trimmed.length > 0 ? trimmed : "/";
};

export const pathForTab = (tab: WebAppTab): string => TAB_PATHS[tab];

export const loadTabFromLocation = (): WebAppTab => {
  if (typeof window === "undefined") return DEFAULT_TAB;

  const pathnameTab = PATH_TAB_ALIASES[normalizePath(window.location.pathname)];
  if (pathnameTab) return pathnameTab;

  const params = new URLSearchParams(window.location.search);
  const legacyCandidate = params.get(TAB_QUERY_KEY);
  if (legacyCandidate === "taskPool") return "taskPool";
  if (legacyCandidate === "schedule") return "schedule";
  return DEFAULT_TAB;
};

export const writeTabToLocation = (tab: WebAppTab, historyMode: "push" | "replace" = "replace"): void => {
  if (typeof window === "undefined") return;

  const url = new URL(window.location.href);
  url.pathname = pathForTab(tab);
  url.searchParams.delete(TAB_QUERY_KEY);

  const nextUrl = `${url.pathname}${url.search}${url.hash}`;
  if (historyMode === "push") {
    window.history.pushState(null, "", nextUrl);
  } else {
    window.history.replaceState(null, "", nextUrl);
  }
};

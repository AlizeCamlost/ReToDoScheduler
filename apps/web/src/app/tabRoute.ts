import type { WebAppTab } from "./useWebAppController";

const DEFAULT_TAB: WebAppTab = "sequence";
const TAB_QUERY_KEY = "tab";
const TABS: WebAppTab[] = ["sequence", "taskPool", "schedule"];

const isWebAppTab = (value: string | null): value is WebAppTab =>
  value !== null && TABS.includes(value as WebAppTab);

export const loadTabFromLocation = (): WebAppTab => {
  if (typeof window === "undefined") return DEFAULT_TAB;

  const params = new URLSearchParams(window.location.search);
  const candidate = params.get(TAB_QUERY_KEY);
  return isWebAppTab(candidate) ? candidate : DEFAULT_TAB;
};

export const writeTabToLocation = (tab: WebAppTab, historyMode: "push" | "replace" = "replace"): void => {
  if (typeof window === "undefined") return;

  const url = new URL(window.location.href);
  if (tab === DEFAULT_TAB) {
    url.searchParams.delete(TAB_QUERY_KEY);
  } else {
    url.searchParams.set(TAB_QUERY_KEY, tab);
  }

  const nextUrl = `${url.pathname}${url.search}${url.hash}`;
  if (historyMode === "push") {
    window.history.pushState(null, "", nextUrl);
  } else {
    window.history.replaceState(null, "", nextUrl);
  }
};

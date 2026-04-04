export type ThemeMode = "system" | "light" | "dark";
export type ResolvedTheme = "light" | "dark";

const THEME_MODE_STORAGE_KEY = "norn.appearance.themeMode";

const getStorage = (): Storage | null => {
  if (typeof window === "undefined") return null;
  return window.localStorage;
};

export const loadThemeMode = (): ThemeMode => {
  const value = getStorage()?.getItem(THEME_MODE_STORAGE_KEY);
  return value === "light" || value === "dark" || value === "system" ? value : "system";
};

export const saveThemeMode = (mode: ThemeMode): ThemeMode => {
  getStorage()?.setItem(THEME_MODE_STORAGE_KEY, mode);
  return mode;
};

export const resolveThemeMode = (mode: ThemeMode, prefersDark: boolean): ResolvedTheme =>
  mode === "system" ? (prefersDark ? "dark" : "light") : mode;

export const applyResolvedTheme = (theme: ResolvedTheme): void => {
  if (typeof document === "undefined") return;
  document.documentElement.dataset.theme = theme;
  document.documentElement.style.colorScheme = theme;
};

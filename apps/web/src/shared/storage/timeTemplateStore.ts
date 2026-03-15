import { DEFAULT_TIME_TEMPLATE, type TimeTemplate } from "@retodo/core";

const TIME_TEMPLATE_KEY = "retodo.timeTemplate";

export const loadTimeTemplate = (): TimeTemplate => {
  if (typeof window === "undefined") return DEFAULT_TIME_TEMPLATE;

  const raw = window.localStorage.getItem(TIME_TEMPLATE_KEY);
  if (!raw) return DEFAULT_TIME_TEMPLATE;

  try {
    const parsed = JSON.parse(raw) as TimeTemplate;
    if (!parsed || !Array.isArray(parsed.weeklyRanges)) return DEFAULT_TIME_TEMPLATE;
    return {
      timezone: parsed.timezone || DEFAULT_TIME_TEMPLATE.timezone,
      weeklyRanges: parsed.weeklyRanges
    };
  } catch {
    return DEFAULT_TIME_TEMPLATE;
  }
};

export const saveTimeTemplate = (template: TimeTemplate): void => {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(TIME_TEMPLATE_KEY, JSON.stringify(template));
};

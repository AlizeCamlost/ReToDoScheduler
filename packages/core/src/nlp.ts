import { DEFAULT_MIN_CHUNK_MINUTES, DEFAULT_TASK_NUMERIC } from "./defaults";

export interface ParseResult {
  title: string;
  estimatedMinutes: number;
  minChunkMinutes: number;
  dueAt?: string | undefined;
  tags: string[];
}

const DURATION_PATTERNS = [
  /(\d+)\s*(?:分钟|mins?|minutes?)/i,
  /(\d+)\s*m\b/i
];

const MIN_CHUNK_PATTERNS = [
  /至少\s*(\d+)\s*分钟/,
  /最少\s*(\d+)\s*分钟/,
  /min\s*chunk\s*(\d+)/i
];

const normalizeDateByKeyword = (source: string): string | undefined => {
  const today = new Date();
  const base = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  if (source.includes("今天") || /today/i.test(source)) {
    return base.toISOString();
  }
  if (source.includes("明天") || /tomorrow/i.test(source)) {
    base.setDate(base.getDate() + 1);
    return base.toISOString();
  }
  if (source.includes("后天")) {
    base.setDate(base.getDate() + 2);
    return base.toISOString();
  }

  const explicit = source.match(/(\d{4})-(\d{1,2})-(\d{1,2})/);
  if (explicit) {
    const dt = new Date(Number(explicit[1]), Number(explicit[2]) - 1, Number(explicit[3]));
    return dt.toISOString();
  }
  return undefined;
};

const parseDuration = (source: string, fallback: number): number => {
  for (const pattern of DURATION_PATTERNS) {
    const matched = source.match(pattern);
    if (matched) {
      return Number(matched[1]);
    }
  }
  return fallback;
};

const parseMinChunk = (source: string): number => {
  for (const pattern of MIN_CHUNK_PATTERNS) {
    const matched = source.match(pattern);
    if (matched) {
      return Number(matched[1]);
    }
  }
  return DEFAULT_MIN_CHUNK_MINUTES;
};

const parseTags = (source: string): string[] => {
  const matched = source.match(/#[\w\u4e00-\u9fa5-]+/g) ?? [];
  return matched.map((tag) => tag.replace(/^#/, "").toLowerCase());
};

const sanitizeTitle = (source: string): string =>
  source
    .replace(/#[\w\u4e00-\u9fa5-]+/g, "")
    .replace(/\s+/g, " ")
    .trim();

export const parseQuickInput = (input: string): ParseResult => {
  const fallbackMinutes = DEFAULT_TASK_NUMERIC.estimatedMinutes;
  return {
    title: sanitizeTitle(input) || "Untitled Task",
    estimatedMinutes: parseDuration(input, fallbackMinutes),
    minChunkMinutes: parseMinChunk(input),
    dueAt: normalizeDateByKeyword(input),
    tags: parseTags(input)
  };
};

import { API_BASE_URL } from "../config/env";

export class ApiError extends Error {
  readonly status: number;

  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

const shouldUseDevProxy = (): boolean => {
  if (!import.meta.env.DEV || typeof window === "undefined") return false;

  const configuredBase = API_BASE_URL.trim();
  if (!configuredBase) return true;

  try {
    const url = new URL(configuredBase);
    return ["127.0.0.1", "localhost"].includes(url.hostname);
  } catch {
    return false;
  }
};

export const buildApiUrl = (path: string): string => {
  if (shouldUseDevProxy()) return path;

  const normalized = API_BASE_URL.trim().replace(/\/+$/, "");
  return normalized ? `${normalized}${path}` : path;
};

const extractErrorMessage = async (response: Response, fallback: string): Promise<string> => {
  try {
    const payload = (await response.json()) as { error?: unknown };
    return typeof payload.error === "string" && payload.error.trim() ? payload.error : fallback;
  } catch {
    return fallback;
  }
};

export const apiFetch = async (path: string, init: RequestInit = {}): Promise<Response> => {
  const response = await fetch(buildApiUrl(path), {
    credentials: "include",
    ...init
  });

  if (!response.ok) {
    throw new ApiError(await extractErrorMessage(response, `Request failed (${response.status})`), response.status);
  }

  return response;
};

export const apiJson = async <T>(path: string, init: RequestInit = {}): Promise<T> => {
  const response = await apiFetch(path, init);
  return (await response.json()) as T;
};

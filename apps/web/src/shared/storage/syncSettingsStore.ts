import { API_AUTH_TOKEN, API_BASE_URL } from "../config/env";
import { createAndPersistDeviceId, getOrCreateDeviceId, persistDeviceId } from "./deviceSession";

export interface WebSyncSettings {
  baseUrl: string;
  authToken: string;
  deviceId: string;
}

const BASE_URL_STORAGE_KEY = "norn.sync.base_url";
const AUTH_TOKEN_STORAGE_KEY = "norn.sync.auth_token";
const HIDE_COMPLETED_STORAGE_KEY = "norn.taskPool.hideCompletedTasks";

const getStorage = (): Storage | null => {
  if (typeof window === "undefined") return null;
  return window.localStorage;
};

const readString = (key: string, fallback: string): string => {
  const storage = getStorage();
  if (!storage) return fallback;

  const value = storage.getItem(key);
  return value === null ? fallback : value;
};

const writeString = (key: string, value: string): void => {
  const storage = getStorage();
  if (!storage) return;
  storage.setItem(key, value);
};

export const isSyncConfigured = (settings: WebSyncSettings): boolean =>
  settings.baseUrl.trim().length > 0 && settings.authToken.trim().length > 0;

export const loadSyncSettings = (): WebSyncSettings => ({
  baseUrl: readString(BASE_URL_STORAGE_KEY, API_BASE_URL),
  authToken: readString(AUTH_TOKEN_STORAGE_KEY, API_AUTH_TOKEN),
  deviceId: getOrCreateDeviceId()
});

export const saveSyncSettings = (settings: WebSyncSettings): WebSyncSettings => {
  const normalizedBaseUrl = settings.baseUrl.trim();
  const normalizedAuthToken = settings.authToken.trim();
  const normalizedDeviceId = settings.deviceId.trim()
    ? persistDeviceId(settings.deviceId)
    : createAndPersistDeviceId();

  writeString(BASE_URL_STORAGE_KEY, normalizedBaseUrl);
  writeString(AUTH_TOKEN_STORAGE_KEY, normalizedAuthToken);

  return {
    baseUrl: normalizedBaseUrl,
    authToken: normalizedAuthToken,
    deviceId: normalizedDeviceId
  };
};

export const loadHideCompletedTasks = (): boolean => {
  const storage = getStorage();
  if (!storage) return false;
  return storage.getItem(HIDE_COMPLETED_STORAGE_KEY) === "true";
};

export const saveHideCompletedTasks = (value: boolean): boolean => {
  const storage = getStorage();
  if (storage) {
    storage.setItem(HIDE_COMPLETED_STORAGE_KEY, value ? "true" : "false");
  }
  return value;
};

import { createId } from "../utils/createId";

const DEVICE_ID_STORAGE_KEY = "norn.sync.device_id";
const DEVICE_NAME_STORAGE_KEY = "norn.auth.device_name";

let sessionDeviceId: string | null = null;

const getStorage = (): Storage | null => {
  if (typeof window === "undefined") return null;
  return window.localStorage;
};

const readStoredDeviceId = (): string | null => {
  const storage = getStorage();
  if (!storage) return null;

  const stored = storage.getItem(DEVICE_ID_STORAGE_KEY);
  return stored && stored.trim() ? stored.trim() : null;
};

const writeStoredDeviceId = (deviceId: string): void => {
  const storage = getStorage();
  if (!storage) return;
  storage.setItem(DEVICE_ID_STORAGE_KEY, deviceId);
};

const readStoredDeviceName = (): string => {
  const storage = getStorage();
  if (!storage) return "";

  return storage.getItem(DEVICE_NAME_STORAGE_KEY)?.trim() ?? "";
};

const writeStoredDeviceName = (deviceName: string): void => {
  const storage = getStorage();
  if (!storage) return;
  storage.setItem(DEVICE_NAME_STORAGE_KEY, deviceName);
};

export const getOrCreateDeviceId = (): string => {
  if (sessionDeviceId) return sessionDeviceId;
  sessionDeviceId = readStoredDeviceId() ?? createId();
  writeStoredDeviceId(sessionDeviceId);
  return sessionDeviceId;
};

export const createAndPersistDeviceId = (): string => {
  sessionDeviceId = createId();
  writeStoredDeviceId(sessionDeviceId);
  return sessionDeviceId;
};

export const persistDeviceId = (deviceId: string): string => {
  const normalized = deviceId.trim();
  sessionDeviceId = normalized || createAndPersistDeviceId();
  writeStoredDeviceId(sessionDeviceId);
  return sessionDeviceId;
};

const detectPlatform = (): string => {
  if (typeof navigator === "undefined") return "This device";

  const ua = navigator.userAgent.toLowerCase();
  if (ua.includes("mac")) return "Mac";
  if (ua.includes("windows")) return "Windows";
  if (ua.includes("iphone")) return "iPhone";
  if (ua.includes("ipad")) return "iPad";
  if (ua.includes("android")) return "Android";
  return "This device";
};

const detectBrowser = (): string => {
  if (typeof navigator === "undefined") return "Browser";

  const ua = navigator.userAgent.toLowerCase();
  if (ua.includes("edg/")) return "Edge";
  if (ua.includes("chrome/")) return "Chrome";
  if (ua.includes("firefox/")) return "Firefox";
  if (ua.includes("safari/")) return "Safari";
  return "Browser";
};

export const suggestDeviceName = (): string => `${detectPlatform()} · ${detectBrowser()}`;

export const loadPreferredDeviceName = (): string => readStoredDeviceName();

export const savePreferredDeviceName = (deviceName: string): string => {
  const normalized = deviceName.trim() || suggestDeviceName();
  writeStoredDeviceName(normalized);
  return normalized;
};

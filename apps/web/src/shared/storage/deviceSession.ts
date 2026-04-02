import { createId } from "../utils/createId";

const DEVICE_ID_STORAGE_KEY = "norn.sync.device_id";

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

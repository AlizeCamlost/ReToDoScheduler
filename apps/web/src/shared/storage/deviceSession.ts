import { createId } from "../utils/createId";

let sessionDeviceId: string | null = null;

export const getOrCreateDeviceId = (): string => {
  if (sessionDeviceId) return sessionDeviceId;
  sessionDeviceId = createId();
  return sessionDeviceId;
};

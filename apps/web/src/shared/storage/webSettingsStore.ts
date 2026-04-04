const HIDE_COMPLETED_STORAGE_KEY = "norn.taskPool.hideCompletedTasks";

const getStorage = (): Storage | null => {
  if (typeof window === "undefined") return null;
  return window.localStorage;
};

export const loadHideCompletedTasks = (): boolean => {
  const storage = getStorage();
  if (!storage) return false;
  return storage.getItem(HIDE_COMPLETED_STORAGE_KEY) === "true";
};

export const saveHideCompletedTasks = (value: boolean): boolean => {
  getStorage()?.setItem(HIDE_COMPLETED_STORAGE_KEY, value ? "true" : "false");
  return value;
};

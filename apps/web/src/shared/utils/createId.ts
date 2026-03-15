export const createId = (): string =>
  (globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.round(Math.random() * 100000)}`).toString();

import { apiJson } from "../../../shared/network/apiClient";

export interface WebSessionSummary {
  id: string;
  deviceId: string;
  deviceName: string;
  userAgent: string;
  ipAddress: string;
  createdAt: string;
  lastSeenAt: string;
  expiresAt: string;
  current: boolean;
}

export interface WebSessionState {
  enabled: boolean;
  authenticated: boolean;
  session?: WebSessionSummary;
}

interface WebSessionsPayload {
  currentSessionId: string;
  sessions: WebSessionSummary[];
}

export interface LoginPayload {
  username: string;
  password: string;
  deviceName: string;
}

export const fetchWebSessionState = (): Promise<WebSessionState> => apiJson("/v1/auth/session");

export const loginWebOwner = (payload: LoginPayload): Promise<{ authenticated: true; session: WebSessionSummary }> =>
  apiJson("/v1/auth/login", {
    method: "POST",
    headers: {
      "content-type": "application/json"
    },
    body: JSON.stringify(payload)
  });

export const logoutWebOwner = (): Promise<{ ok: true }> =>
  apiJson("/v1/auth/logout", {
    method: "POST"
  });

export const fetchWebSessions = (): Promise<WebSessionsPayload> => apiJson("/v1/auth/sessions");

export const revokeWebSession = (
  sessionId: string
): Promise<{ ok: true; currentSessionRevoked: boolean }> =>
  apiJson("/v1/auth/sessions/revoke", {
    method: "POST",
    headers: {
      "content-type": "application/json"
    },
    body: JSON.stringify({ sessionId })
  });

export const revokeOtherWebSessions = (): Promise<{ ok: true }> =>
  apiJson("/v1/auth/sessions/revoke-others", {
    method: "POST"
  });

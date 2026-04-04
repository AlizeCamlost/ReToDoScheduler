import crypto from "node:crypto";
import type { FastifyReply, FastifyRequest } from "fastify";
import { pool } from "./db.js";

const SESSION_COOKIE_NAME = "retodo_web_session";
const SESSION_TTL_MS = 1000 * 60 * 60 * 24 * 90;
const DEFAULT_DEV_OWNER_USERNAME = "owner";
const DEFAULT_DEV_OWNER_PASSWORD = "retodo-dev-login";

interface WebSessionRow {
  id: string;
  device_id: string;
  device_name: string;
  user_agent: string | null;
  ip_address: string | null;
  created_at: string | Date;
  last_seen_at: string | Date;
  expires_at: string | Date;
}

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

const isProduction = process.env.NODE_ENV === "production";

const getOwnerUsername = (): string => {
  const configured = process.env.WEB_LOGIN_USERNAME?.trim();
  if (configured) return configured;
  if (!isProduction) return DEFAULT_DEV_OWNER_USERNAME;
  throw new Error("Missing WEB_LOGIN_USERNAME");
};

const getOwnerPassword = (): string => {
  const configured = process.env.WEB_LOGIN_PASSWORD;
  if (configured && configured.trim()) return configured;
  if (!isProduction) return DEFAULT_DEV_OWNER_PASSWORD;
  throw new Error("Missing WEB_LOGIN_PASSWORD");
};

const sha256 = (value: string): string => crypto.createHash("sha256").update(value).digest("hex");

const parseCookies = (header?: string): Record<string, string> => {
  if (!header) return {};

  return header.split(";").reduce<Record<string, string>>((cookies, chunk) => {
    const [rawName, ...rawValue] = chunk.trim().split("=");
    if (!rawName || rawValue.length === 0) return cookies;
    cookies[rawName] = decodeURIComponent(rawValue.join("="));
    return cookies;
  }, {});
};

const serializeCookie = (name: string, value: string, maxAgeSeconds: number): string => {
  const parts = [
    `${name}=${encodeURIComponent(value)}`,
    "Path=/",
    "HttpOnly",
    "SameSite=Lax",
    `Max-Age=${maxAgeSeconds}`
  ];

  if (isProduction) {
    parts.push("Secure");
  }

  return parts.join("; ");
};

const formatSession = (row: WebSessionRow, currentSessionId?: string): WebSessionSummary => ({
  id: row.id,
  deviceId: row.device_id,
  deviceName: row.device_name,
  userAgent: row.user_agent ?? "",
  ipAddress: row.ip_address ?? "",
  createdAt: new Date(row.created_at).toISOString(),
  lastSeenAt: new Date(row.last_seen_at).toISOString(),
  expiresAt: new Date(row.expires_at).toISOString(),
  current: currentSessionId === row.id
});

const secureCompare = (left: string, right: string): boolean => {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  if (leftBuffer.length !== rightBuffer.length) return false;
  return crypto.timingSafeEqual(leftBuffer, rightBuffer);
};

const normalizeDeviceName = (deviceName?: string): string => {
  const trimmed = deviceName?.trim();
  if (!trimmed) return "This device";
  return trimmed.slice(0, 80);
};

const getUserAgent = (request: FastifyRequest): string =>
  String(request.headers["user-agent"] ?? "").slice(0, 240);

const getIpAddress = (request: FastifyRequest): string =>
  String(request.ip ?? "").slice(0, 80);

export const getWebLoginEnabled = (): boolean => {
  try {
    getOwnerUsername();
    getOwnerPassword();
    return true;
  } catch {
    return false;
  }
};

export const verifyOwnerCredentials = (username: string, password: string): boolean =>
  secureCompare(username.trim(), getOwnerUsername()) && secureCompare(password, getOwnerPassword());

export const setWebSessionCookie = (reply: FastifyReply, token: string): void => {
  reply.header("set-cookie", serializeCookie(SESSION_COOKIE_NAME, token, Math.floor(SESSION_TTL_MS / 1000)));
};

export const clearWebSessionCookie = (reply: FastifyReply): void => {
  reply.header("set-cookie", serializeCookie(SESSION_COOKIE_NAME, "", 0));
};

export const createWebSession = async (
  request: FastifyRequest,
  deviceName?: string
): Promise<WebSessionSummary & { token: string }> => {
  const now = new Date();
  const expiresAt = new Date(now.getTime() + SESSION_TTL_MS);
  const sessionId = crypto.randomUUID();
  const token = crypto.randomBytes(32).toString("base64url");
  const session = {
    id: sessionId,
    tokenHash: sha256(token),
    deviceId: sessionId,
    deviceName: normalizeDeviceName(deviceName),
    userAgent: getUserAgent(request),
    ipAddress: getIpAddress(request),
    createdAt: now.toISOString(),
    lastSeenAt: now.toISOString(),
    expiresAt: expiresAt.toISOString()
  };

  await pool.query(
    `INSERT INTO web_sessions (
      id, token_hash, device_id, device_name, user_agent, ip_address,
      created_at, last_seen_at, expires_at
    ) VALUES (
      $1, $2, $3, $4, $5, $6,
      $7::timestamptz, $8::timestamptz, $9::timestamptz
    )`,
    [
      session.id,
      session.tokenHash,
      session.deviceId,
      session.deviceName,
      session.userAgent,
      session.ipAddress,
      session.createdAt,
      session.lastSeenAt,
      session.expiresAt
    ]
  );

  return {
    id: session.id,
    deviceId: session.deviceId,
    deviceName: session.deviceName,
    userAgent: session.userAgent,
    ipAddress: session.ipAddress,
    createdAt: session.createdAt,
    lastSeenAt: session.lastSeenAt,
    expiresAt: session.expiresAt,
    current: true,
    token
  };
};

export const getWebSessionFromRequest = async (
  request: FastifyRequest
): Promise<WebSessionSummary | null> => {
  const token = parseCookies(request.headers.cookie)[SESSION_COOKIE_NAME];
  if (!token) return null;

  const result = await pool.query<WebSessionRow>(
    `SELECT id, device_id, device_name, user_agent, ip_address, created_at, last_seen_at, expires_at
     FROM web_sessions
     WHERE token_hash = $1
       AND revoked_at IS NULL
       AND expires_at > now()
     LIMIT 1`,
    [sha256(token)]
  );

  const row = result.rows[0];
  if (!row) {
    return null;
  }

  await pool.query(
    `UPDATE web_sessions
     SET last_seen_at = now(), user_agent = $2, ip_address = $3
     WHERE id = $1`,
    [row.id, getUserAgent(request), getIpAddress(request)]
  );

  return formatSession(
    {
      ...row,
      last_seen_at: new Date().toISOString(),
      user_agent: getUserAgent(request),
      ip_address: getIpAddress(request)
    },
    row.id
  );
};

export const requireWebSession = async (
  request: FastifyRequest,
  reply: FastifyReply
): Promise<WebSessionSummary | null> => {
  const session = await getWebSessionFromRequest(request);
  if (session) return session;

  clearWebSessionCookie(reply);
  reply.code(401);
  await reply.send({ error: "Unauthorized" });
  return null;
};

export const listWebSessions = async (currentSessionId: string): Promise<WebSessionSummary[]> => {
  const result = await pool.query<WebSessionRow>(
    `SELECT id, device_id, device_name, user_agent, ip_address, created_at, last_seen_at, expires_at
     FROM web_sessions
     WHERE revoked_at IS NULL
       AND expires_at > now()
     ORDER BY last_seen_at DESC, created_at DESC`
  );

  return result.rows.map((row) => formatSession(row, currentSessionId));
};

export const revokeWebSession = async (sessionId: string): Promise<void> => {
  await pool.query(
    `UPDATE web_sessions
     SET revoked_at = now()
     WHERE id = $1`,
    [sessionId]
  );
};

export const revokeOtherWebSessions = async (currentSessionId: string): Promise<void> => {
  await pool.query(
    `UPDATE web_sessions
     SET revoked_at = now()
     WHERE id <> $1
       AND revoked_at IS NULL`,
    [currentSessionId]
  );
};

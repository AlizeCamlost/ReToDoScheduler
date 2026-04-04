import type { FastifyPluginAsync } from "fastify";
import {
  clearWebSessionCookie,
  createWebSession,
  getWebLoginEnabled,
  getWebSessionFromRequest,
  listWebSessions,
  requireWebSession,
  revokeOtherWebSessions,
  revokeWebSession,
  setWebSessionCookie,
  verifyOwnerCredentials
} from "../auth.js";

interface LoginBody {
  username?: string;
  password?: string;
  deviceName?: string;
}

interface RevokeBody {
  sessionId?: string;
}

const authRoutes: FastifyPluginAsync = async (app) => {
  app.get("/v1/auth/session", async (request, reply) => {
    const session = await getWebSessionFromRequest(request);
    if (!session) {
      clearWebSessionCookie(reply);
      return { enabled: getWebLoginEnabled(), authenticated: false };
    }

    return {
      enabled: true,
      authenticated: true,
      session
    };
  });

  app.post<{ Body: LoginBody }>("/v1/auth/login", async (request, reply) => {
    const body = request.body ?? {};
    if (!getWebLoginEnabled()) {
      reply.code(503);
      return { error: "Web login is not configured" };
    }

    if (typeof body.username !== "string" || typeof body.password !== "string") {
      reply.code(400);
      return { error: "Invalid login payload" };
    }

    if (!verifyOwnerCredentials(body.username, body.password)) {
      reply.code(401);
      return { error: "Invalid credentials" };
    }

    const session = await createWebSession(request, body.deviceName);
    setWebSessionCookie(reply, session.token);

    return {
      authenticated: true,
      session: {
        id: session.id,
        deviceId: session.deviceId,
        deviceName: session.deviceName,
        userAgent: session.userAgent,
        ipAddress: session.ipAddress,
        createdAt: session.createdAt,
        lastSeenAt: session.lastSeenAt,
        expiresAt: session.expiresAt,
        current: true
      }
    };
  });

  app.post("/v1/auth/logout", async (request, reply) => {
    const session = await getWebSessionFromRequest(request);
    if (session) {
      await revokeWebSession(session.id);
    }

    clearWebSessionCookie(reply);
    return { ok: true };
  });

  app.get("/v1/auth/sessions", async (request, reply) => {
    const session = await requireWebSession(request, reply);
    if (!session) return;

    return {
      currentSessionId: session.id,
      sessions: await listWebSessions(session.id)
    };
  });

  app.post<{ Body: RevokeBody }>("/v1/auth/sessions/revoke", async (request, reply) => {
    const currentSession = await requireWebSession(request, reply);
    if (!currentSession) return;

    const sessionId = request.body?.sessionId;
    if (typeof sessionId !== "string" || !sessionId.trim()) {
      reply.code(400);
      return { error: "Invalid sessionId" };
    }

    await revokeWebSession(sessionId);
    if (sessionId === currentSession.id) {
      clearWebSessionCookie(reply);
      return { ok: true, currentSessionRevoked: true };
    }

    return { ok: true, currentSessionRevoked: false };
  });

  app.post("/v1/auth/sessions/revoke-others", async (request, reply) => {
    const currentSession = await requireWebSession(request, reply);
    if (!currentSession) return;

    await revokeOtherWebSessions(currentSession.id);
    return { ok: true };
  });
};

export default authRoutes;

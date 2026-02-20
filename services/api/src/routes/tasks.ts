import type { FastifyPluginAsync } from "fastify";

const taskRoutes: FastifyPluginAsync = async (app) => {
  app.get("/v1/tasks", async () => {
    return {
      message: "Phase 1 placeholder. Server sync will be enabled in Phase 3.",
      items: []
    };
  });
};

export default taskRoutes;

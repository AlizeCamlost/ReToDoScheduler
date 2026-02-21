import Fastify from "fastify";
import cors from "@fastify/cors";
import healthRoute from "./routes/health.js";
import taskRoutes from "./routes/tasks.js";

const app = Fastify({ logger: true });

await app.register(cors, {
  origin: true
});
await app.register(healthRoute);
await app.register(taskRoutes);

const port = Number(process.env.PORT ?? 8787);

app
  .listen({ host: "0.0.0.0", port })
  .then(() => {
    app.log.info(`API server listening on :${port}`);
  })
  .catch((error: unknown) => {
    app.log.error(error);
    process.exit(1);
  });

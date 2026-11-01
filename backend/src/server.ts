
import "dotenv/config";
import app from "./app.js";

const PORT = Number(process.env.PORT) || 4000;
const HOST = process.env.HOST || "0.0.0.0";

const server = app.listen(PORT, HOST, () => {
  console.log(`OpenCampus API listening on ${HOST}:${PORT}`);
});

function shutdown(signal: string): void {
  console.log(`${signal} received. Shutting down OpenCampus API...`);

  server.close((error) => {
    if (error) {
      console.error("Server shutdown error:", error);
      process.exit(1);
    }

    console.log("OpenCampus API stopped safely.");
    process.exit(0);
  });

  setTimeout(() => {
    console.error("Forced shutdown after timeout.");
    process.exit(1);
  }, 10000).unref();
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));

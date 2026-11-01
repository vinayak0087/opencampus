
import express, {
  type Request,
  type Response,
  type NextFunction
} from "express";
import cors from "cors";
import helmet from "helmet";

import authRoutes from "./modules/auth/auth.routes.js";

const app = express();

app.disable("x-powered-by");

app.use(helmet());

app.use(
  cors({
    origin: process.env.CORS_ORIGIN
      ? process.env.CORS_ORIGIN.split(",").map((item) => item.trim())
      : false,
    credentials: true
  })
);

app.use(express.json({ limit: "1mb" }));

app.get("/health", (_req: Request, res: Response) => {
  res.status(200).json({
    success: true,
    message: "OpenCampus API is running",
    service: "opencampus-backend",
    timestamp: new Date().toISOString()
  });
});

// Authentication API
app.use("/api/auth", authRoutes);

// 404 handler
app.use((_req: Request, res: Response) => {
  res.status(404).json({
    success: false,
    message: "API route not found"
  });
});

// Global error handler
app.use(
  (
    error: Error,
    _req: Request,
    res: Response,
    _next: NextFunction
  ) => {
    console.error(error.message);

    res.status(500).json({
      success: false,
      message: "Internal server error"
    });
  }
);

export default app;

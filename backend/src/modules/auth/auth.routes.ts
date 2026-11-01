
import { Router } from "express";

import { loginSchema } from "./auth.schemas.js";
import {
  authenticateUser,
  AuthError
} from "./auth.service.js";

const router = Router();

router.post("/login", async (req, res): Promise<void> => {
  try {
    const validation = loginSchema.safeParse(req.body);

    if (!validation.success) {
      res.status(400).json({
        error: "Invalid login details",
        details: validation.error.issues.map((issue) => ({
          field: issue.path.join("."),
          message: issue.message
        }))
      });
      return;
    }

    const result = await authenticateUser(validation.data);

    res.status(200).json({
      message: "Login successful",
      user: result.user,
      memberships: result.memberships,
      nextStep: "Select an institution to continue"
    });
  } catch (error) {
    if (error instanceof AuthError) {
      res.status(error.statusCode).json({
        error: error.message
      });
      return;
    }

    console.error("Login error:", error);

    res.status(500).json({
      error: "An unexpected error occurred"
    });
  }
});

export default router;

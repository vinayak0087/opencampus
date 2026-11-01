
import type {
  Request,
  Response,
  NextFunction
} from "express";

import { prisma } from "../config/prisma.js";
import { verifyAccessToken } from "../modules/auth/jwt.js";

export interface AuthenticatedUser {
  userId: string;
  institutionId: string;
  membershipId: string;
  role: string;
}

declare global {
  namespace Express {
    interface Request {
      auth?: AuthenticatedUser;
    }
  }
}

export async function authenticateRequest(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authorization = req.headers.authorization;

    if (!authorization || !authorization.startsWith("Bearer ")) {
      res.status(401).json({
        error: "Authentication required"
      });
      return;
    }

    const token = authorization.slice(7).trim();

    if (!token) {
      res.status(401).json({
        error: "Invalid authentication token"
      });
      return;
    }

    const claims = await verifyAccessToken(token);

    const membership = await prisma.institutionMembership.findFirst({
      where: {
        id: claims.membershipId,
        userId: claims.userId,
        institutionId: claims.institutionId,
        role: claims.role,
        membershipStatus: "active",
        user: {
          accountStatus: "active"
        }
      },
      select: {
        id: true
      }
    });

    if (!membership) {
      res.status(401).json({
        error: "Account or institution access is inactive"
      });
      return;
    }

    req.auth = claims;

    next();
  } catch {
    res.status(401).json({
      error: "Invalid or expired authentication token"
    });
  }
}

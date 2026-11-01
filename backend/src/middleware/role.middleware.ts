
import type {
  Request,
  Response,
  NextFunction,
  RequestHandler
} from "express";

const ALLOWED_ROLES = [
  "institution_admin",
  "hod",
  "faculty",
  "class_representative",
  "student"
] as const;

export type InstitutionRole =
  (typeof ALLOWED_ROLES)[number];

export function requireRoles(
  ...allowedRoles: InstitutionRole[]
): RequestHandler {
  if (allowedRoles.length === 0) {
    throw new Error(
      "At least one authorized role must be specified"
    );
  }

  for (const role of allowedRoles) {
    if (!ALLOWED_ROLES.includes(role)) {
      throw new Error("Invalid authorization role");
    }
  }

  return (
    req: Request,
    res: Response,
    next: NextFunction
  ): void => {
    if (!req.auth) {
      res.status(401).json({
        error: "Authentication required"
      });
      return;
    }

    if (
      !allowedRoles.includes(
        req.auth.role as InstitutionRole
      )
    ) {
      res.status(403).json({
        error: "You do not have permission to access this resource"
      });
      return;
    }

    next();
  };
}

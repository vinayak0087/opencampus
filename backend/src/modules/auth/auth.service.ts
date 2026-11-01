import bcrypt from "bcryptjs";
import { prisma } from "../../config/prisma.js";
import type { LoginInput } from "./auth.schemas.js";

export class AuthError extends Error {
  constructor(
    message: string,
    public readonly statusCode: number
  ) {
    super(message);
    this.name = "AuthError";
  }
}

export async function authenticateUser(input: LoginInput) {
  const user = await prisma.user.findFirst({
    where: {
      email: {
        equals: input.email,
        mode: "insensitive"
      }
    },
    include: {
      memberships: {
        where: {
          membershipStatus: "active"
        },
        include: {
          institution: {
            select: {
              id: true,
              name: true,
              slug: true,
              timezone: true
            }
          }
        }
      }
    }
  });

  if (!user) {
    throw new AuthError("Invalid email or password", 401);
  }

  if (user.accountStatus !== "active") {
    throw new AuthError("Account is not active", 403);
  }

  const passwordMatches = await bcrypt.compare(
    input.password,
    user.passwordHash
  );

  if (!passwordMatches) {
    throw new AuthError("Invalid email or password", 401);
  }

  return {
    user: {
      id: user.id,
      email: user.email,
      fullName: user.fullName,
      isPlatformAdmin: user.isPlatformAdmin
    },
    memberships: user.memberships.map((membership) => ({
      id: membership.id,
      institutionId: membership.institutionId,
      institution: membership.institution,
      departmentId: membership.departmentId,
      role: membership.role
    }))
  };
}
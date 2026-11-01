import { z } from "zod";

const passwordSchema = z
  .string()
  .min(1, "Password is required")
  .refine(
    (password) => new TextEncoder().encode(password).length <= 72,
    "Password exceeds the supported length"
  );

export const loginSchema = z.object({
  email: z
    .string()
    .trim()
    .email("Enter a valid email address")
    .transform((email) => email.toLowerCase()),

  password: passwordSchema
}).strict();

export const selectInstitutionSchema membershipStatus: "active" i z.object({
  institutionId: z
    .string()
    .uuid("Invalid institution ID")
}).strict();

export type LoginInput = z.infer<typeof loginSchema>;
export type SelectInstitutionInput = z.infer<
  typeof selectInstitutionSchema
>;
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
          membershipStatus: "active",
          institution: {
            // Only active institutions should be available.
            // Institution status will be added in a later migration.
          }
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

  // Use a generic response to avoid revealing whether an email exists.
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
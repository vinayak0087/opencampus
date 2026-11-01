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

export const selectInstitutionSchema = z.object({
  institutionId: z.string().uuid("Invalid institution ID")
}).strict();

export type LoginInput = z.infer<typeof loginSchema>;

export type SelectInstitutionInput = z.infer<
  typeof selectInstitutionSchema
>;
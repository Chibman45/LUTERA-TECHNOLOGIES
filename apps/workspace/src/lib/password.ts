import { z } from "zod";
export const passwordRules = [
  {
    id: "length",
    label: "12–128 characters",
    test: (v: string) => v.length >= 12 && v.length <= 128,
  },
  {
    id: "upper",
    label: "An uppercase letter",
    test: (v: string) => /\p{Lu}/u.test(v),
  },
  {
    id: "lower",
    label: "A lowercase letter",
    test: (v: string) => /\p{Ll}/u.test(v),
  },
  { id: "number", label: "A number", test: (v: string) => /\p{Nd}/u.test(v) },
  {
    id: "symbol",
    label: "A symbol, such as ! @ #",
    test: (v: string) => /[^\p{L}\p{N}\s]/u.test(v),
  },
] as const;
export function passwordIssues(value: string) {
  return passwordRules
    .filter((rule) => !rule.test(value))
    .map((rule) => rule.label);
}
export const newPasswordSchema = z
  .string()
  .max(128)
  .superRefine((value, context) => {
    const missing = passwordIssues(value);
    if (missing.length)
      context.addIssue({
        code: "custom",
        message: `Password requires: ${missing.join(", ")}.`,
      });
  });

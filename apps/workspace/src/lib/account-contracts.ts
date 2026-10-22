import { z } from "zod";
export const profileSchema = z
  .object({
    version: z.number().int().min(0),
    full_name: z
      .string()
      .trim()
      .min(1, "Enter your full name")
      .max(120)
      .refine(
        (v) => !/[\x00-\x1f]/.test(v),
        "Remove control characters from your name",
      ),
    phone: z
      .string()
      .trim()
      .max(40)
      .refine(
        (v) =>
          v === "" ||
          (/^[+()0-9 .-]+$/.test(v) && v.replace(/\D/g, "").length >= 6),
        "Enter a valid contact phone number",
      ),
    photo: z.string().max(1400000).optional(),
    remove_photo: z.boolean().default(false),
  })
  .strict()
  .refine(
    (v) => !(v.photo && v.remove_photo),
    "Choose a photo or remove the current photo",
  );
export const emailChangeSchema = z
  .object({
    email: z.email().trim().toLowerCase().max(254),
    confirmation: z.email().trim().toLowerCase().max(254),
  })
  .strict()
  .refine((v) => v.email === v.confirmation, "Email addresses must match");
export type AccountInfo = {
  email: string;
  role: string;
  pending_email: string | null;
  profile: {
    full_name: string;
    phone: string;
    avatar_url: string | null;
    version: number;
  };
  factors: { id: string; name: string }[];
};

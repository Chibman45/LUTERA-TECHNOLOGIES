import EmailConfirmation from "@/components/EmailConfirmation";
import { emailActionType } from "@/lib/auth-email";
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const query = await searchParams;
  const type = emailActionType.safeParse(query.type);
  const token =
    typeof query.token_hash === "string" &&
    /^[A-Za-z0-9_-]{32,256}$/.test(query.token_hash)
      ? query.token_hash
      : "";
  return (
    <EmailConfirmation token={token} type={type.success ? type.data : null} />
  );
}

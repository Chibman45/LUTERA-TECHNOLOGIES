import { timingSafeEqual } from "node:crypto";
import { notFound } from "next/navigation";
import Workspace from "@/components/Workspace";
export default async function Page({
  params,
}: {
  params: Promise<{ entry: string }>;
}) {
  const { entry } = await params;
  const expected = process.env.WORKSPACE_ENTRY || "";
  if (
    !/^[A-Za-z0-9_-]{32,128}$/.test(expected) ||
    !/^[A-Za-z0-9_-]{32,128}$/.test(entry) ||
    entry.length !== expected.length ||
    !timingSafeEqual(Buffer.from(entry), Buffer.from(expected))
  )
    notFound();
  return <Workspace />;
}

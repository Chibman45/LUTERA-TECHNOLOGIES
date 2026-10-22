# Private business workspace — implemented and deployed

The public website review was completed first. On 22 October 2026 the owner
authorised starting the private workspace and selected
`chimaster010@gmail.com` as the first owner account.

The application now lives in `apps/workspace`, with its own Next.js build and
deployment configuration. The separate `lutera-workspace` Vercel project is
deployed and the Lutera Supabase migrations and access tests are complete.
See [the implementation and deployment runbook](private-workspace.md) for
completed features, test evidence and the owner login/MFA and website deploy-hook
setup still required before operational use.

A hidden URL supplements approved membership, server-side authentication,
authenticator MFA and database access policies. The public website remains a
static Vercel application. No private records or login credentials belong in
this public repository.

Production public builds can now read the explicitly published public-content
snapshot. Financial documents, staff records, access rules and activity records
have no anonymous API privileges. No admin navigation link is added to the
public site.

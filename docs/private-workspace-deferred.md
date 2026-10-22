# Private business workspace — implementation started

The public website review was completed first. On 22 October 2026 the owner
authorised starting the private workspace and selected
`chimaster010@gmail.com` as the first owner account.

The application now lives in `apps/workspace`, with its own Next.js build and
deployment configuration. The Lutera Supabase project has been provisioned for
its private records. See [the implementation and deployment runbook](private-workspace.md)
for completed features, test evidence and the account access still required
before launch.

A hidden URL supplements approved membership, server-side authentication,
authenticator MFA and database access policies. The public website remains a
static Vercel application. No private records or login credentials belong in
this public repository.

Production public builds can now read the explicitly published public-content
snapshot. Financial documents, staff records, access rules and activity records
have no anonymous API privileges. No admin navigation link is added to the
public site.

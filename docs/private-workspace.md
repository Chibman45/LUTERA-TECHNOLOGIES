# Private business workspace — 22 October 2026

## Approved direction and status

The public website phase is complete, including the owner-reported Google and
Bing setup. The owner authorised this separate business workspace and confirmed
`chimaster010@gmail.com` for the first owner account.

The workspace is built in `apps/workspace`. Its baseline schema is applied to
the existing **Lutera Technologies / lutera-website** Supabase project
`zwtjemhrubzgaueuyuxn` in eu-west-1. Only public company seeds and the approved
owner allowlist entry were added. No staff, customer, payment or financial
records were imported; no invitations or test emails were sent.

Both Vercel and Supabase connections are available. The baseline and record-guard
migrations are applied, migration versions are reconciled, and the full access
suite passes on the actual Supabase project with all fixtures rolled back.
The private **lutera-workspace** Vercel project is deployed from this repository,
with Root Directory `apps/workspace`, at `https://workspace.luteratech.com`.
The generated entry path is held in Production environment settings, not in Git.
The first production deployment (`dpl_3QpqfB8Lf8J21r5nuxzqbArdAYBm`) is READY.
Default Vercel deployment protection remains on `.vercel.app` addresses. The
company subdomain uses application authentication, MFA and database policies. The public project remains **lutera_website**, serving
`https://luteratech.com`; its published snapshot build and all 32 live checks pass.

The approved owner Auth user exists with a confirmed email and verified TOTP
factor. The public-site deploy hook and the real owner workflow smoke check
remain launch follow-ups. No interactive authenticated owner session or
workspace-triggered public publication is claimed as tested.

## Implemented features

- Approved accounts with owner, admin, editor, finance and designer roles.
- Password sign-in followed by authenticator-app enrollment/verification.
- Website draft editor for company/contact details, services, custom service
  pages, commitments and social links; content preview; explicit publishing;
  publication history and live revision checks.
- Quotations, pro forma invoices and payment receipts; editable drafts,
  customer details, line items, currency, discount, tax and notes.
- Transactional numbering per document type/year. Issuing locks the record and
  captures company/payment settings. Corrections use a reasoned void and a new
  document; issued records cannot be deleted.
- Receipts can link to an issued quotation/pro forma. The database serialises
  receipt issuance and rejects payments above its remaining balance. Issuing
  requires explicit payment confirmation and a method. This records payments
  checked by staff; it does not process or independently verify bank payments.
- Staff profiles, active/expiry status, normalised private photographs,
  two-sided name-card and ID-card templates, and an on-screen card preview.
- PDF, Word **`.docx`** and PNG exports. PDFs preserve searchable financial text
  and use print-size pages for cards. PNG exports contain the selected card
  side. Word cards contain both images. These are modern Word files, not
  renamed legacy `.doc` binaries.
- Company document identity, optional bank/tax details and standard notes.
  Bank and tax identifiers start blank; tax defaults to zero and currency to
  NGN. No legal/tax rate or payment account is invented.
- Role-limited activity history, encrypted owner backup downloads and an
  offline backup verification utility.
- Responsive layouts, keyboard/focus states, reduced-motion support,
  unsaved-change prompts and explicit error/empty states.

## Security boundary

The workspace uses a **separate Vercel project**, with an opaque entry path
stored in a server environment variable. Its root and generic admin paths
return 404. It is absent from public navigation and sitemaps and sends noindex,
no-store, no-referrer and framing restrictions. The entry path is a precaution;
it is not an authentication secret or a substitute for access checks.

The server verifies the Auth user, approved active membership, role and MFA.
Postgres independently requires AAL2, a currently verified TOTP factor and an
existing unexpired session created within the last 12 hours. Revoked membership,
deleted sessions and removed factors therefore fail database authorisation even
with a previously issued JWT. Tokens stay in HttpOnly, Secure production cookies;
the browser does not use a Supabase client or persist tokens in localStorage.
Mutations require the configured exact Origin and JSON bodies. Payloads are
validated and bounded; updates check record versions.

All exposed private tables have RLS and explicit grants. Financial/staff/member/
audit tables have **no anonymous privileges**. Only the explicitly published
website snapshot is anonymously readable. Privileged helpers are in the
unexposed `private` schema, fix their search_path and check identity/permissions.
Public RPC wrappers are security-invoker. The app never uses a service-role key.
Audit rows cannot be edited or deleted through the application API.

Staff pictures use a private bucket; the server accepts JPEG/PNG/WebP under
1 MB, limits pixel count, strips metadata and stores a normalised JPEG. Reading
them requires staff permission and MFA. Backups exclude Auth password hashes
and authenticator secrets. Backup encryption uses scrypt and AES-256-GCM; the
password is not stored or logged. No private application data is committed to
this public source repository.

## Deployment configuration and account setup

Steps 1–2 describe the configuration already provisioned. The exact Production
origin is now `https://workspace.luteratech.com`. The subsequent READY deployment
`dpl_7ewWufSfptQySC1tWR3bRmdQEhEJ` applies the explicit `WORKSPACE_ORIGIN`;
the initial deployment also passed checks using the tested
`VERCEL_PROJECT_PRODUCTION_URL` fallback. `PUBLIC_SITE_DEPLOY_HOOK` is pending an
owner-created hook; no secret has been requested in chat. Preview environments
do not receive the production configuration.

1. In the **0xluter-s-projects** Vercel team, import
   `luteratech/LUTERA-TECHNOLOGIES` into a **new project**. Set Root Directory to
   `apps/workspace`, Framework to Next.js, Install to `npm ci`, Build to
   `npm run build`, and Node to 24.x. Use the app's own `vercel.json`. Keep the
   existing `lutera_website` public project and domain assignment.
2. Configure these **server-only Production** variables; do not use
   `NEXT_PUBLIC_` prefixes:

   | Variable | Value |
   | --- | --- |
   | `SUPABASE_URL` | `https://zwtjemhrubzgaueuyuxn.supabase.co` |
   | `SUPABASE_PUBLISHABLE_KEY` | The project's enabled publishable key; it is also recorded in `content/workspace-source.json` |
   | `WORKSPACE_ORIGIN` | Exact HTTPS origin of the new private project, without a trailing slash |
   | `WORKSPACE_ENTRY` | Generate with `openssl rand -hex 24`; keep it in the company password manager |
   | `PUBLIC_SITE_DEPLOY_HOOK` | Secret deploy-hook URL for the existing public `lutera_website` project's main branch |

   Missing configuration fails closed. Leave Production credentials out of
   Preview deployments. Build once, confirm the assigned private origin, save
   its exact origin value and redeploy before using authentication.
3. In Supabase Authentication settings, disable public signup, keep TOTP enabled,
   require strong passwords (at least 12 characters), and retain provider rate
   limits. These provider settings require project-owner access and have not
   been changed through this connector. Do not enable paid phone MFA.
4. In [Supabase Auth users](https://supabase.com/dashboard/project/zwtjemhrubzgaueuyuxn/auth/users),
   **create** the owner user with the approved email and an owner-chosen strong
   password, completing the provider's email confirmation process. The app
   requires a confirmed email. Do not send the password to ChatGPT or put it in
   repository/Vercel variables. Branded invitation/recovery callbacks are now
   implemented at `/auth/confirm`; hosted Auth URL, SMTP and template settings
   still need to be applied. See [the email setup guide](../apps/workspace/email/README.md).
5. Visit the private project's generated entry path, sign in and enroll a TOTP
   authenticator. Store recovery arrangements with the company owner. A second
   owner can be approved for operational continuity. Do not use real customer
   or staff records before the deployment smoke checks below pass.
6. The migration was already applied through the Supabase connector. The provider-assigned migration versions have been reconciled with the local
   CLI-created baseline. Apply subsequent changes as new migrations. For an empty
   replacement project, apply the migration history normally.

## Website publishing

The public site remains static HTML, not a browser database app. Production
builds default to `LUTERA_CONTENT_SOURCE=published` and read only the public
snapshot with the publishable key. Development/preview builds use repository
content. The public builder validates content again, generates normal crawlable
pages, runs HTML/SEO checks and copies only approved public files to `_site`.
It never publishes `apps`, private data, SQL, `.env` files or source settings.

In the **existing public Vercel project**, create a main-branch deploy hook under
Settings → Git → Deploy Hooks. Store that secret URL as
`PUBLIC_SITE_DEPLOY_HOOK` in the private project's Production variables. Save a
workspace draft, review it, then publish. The database atomically creates the
public snapshot/revision and an outbox/history row; the server requests the
public build. Check `/site-revision.json` through the workspace to mark that
specific version live. Saving a draft alone does not change the public site.
Failed or unconfigured builds are reported rather than displayed as successful.

The current public company snapshot was seeded unchanged. `content/site.json`
is the repository/development fallback. `LUTERA_CONTENT_SOURCE=repository` is an
explicit operational override, for example during a provider outage; it must
not be used to silently discard workspace publications. Invalid/unavailable
published content causes a build failure and leaves the last deployment live.
Changing the public enquiry email also requires activating that inbox with
FormSubmit before relying on delivery to the new destination.

## Access and recovery operations

The owner approves an email and role in Access, then creates or invites the
matching Auth user in the Supabase dashboard. After the branded email settings
are applied, invitees choose their own password through `/auth/confirm`. Recovery
links restore an email-verified session, followed by the existing authenticator
and the My account password form. Approval alone sends no email and creates no
password. Lost-factor recovery still requires the project owner's administrative
controls. Email recovery never bypasses MFA. Revoke sessions during recovery.

An owner cannot change their own access rule; another owner must do so. Disable
a departing colleague in Access. Their next API request is denied immediately;
the UI revalidates on visibility changes and every minute. Signing out revokes
that Auth account's sessions on every device.

Document and staff searches query the full permitted archive with 50-row
pagination, rather than searching only the initial recent-record cache. Receipts
can find older linked quotations/pro formas by number. The activity view shows
the latest 200 events; owner backups include the complete supported history.
Approved users can change their own password after MFA under My account; a
successful change signs out their sessions on all devices. Provider account
changes also appear in the Supabase Auth audit logs.

## Backup and restore policy

Owner backups include a transaction-consistent business-record snapshot,
numbering counters, activity history and referenced staff photos. Encrypted
downloads are capped below Vercel's buffered response limit (4 MB); records
snapshots are capped at 20,000 documents. Larger archives require a full
database/storage backup. The server reports that limit explicitly.

Download to a company-controlled location, store the password separately and
keep copies outside the Supabase project. Never upload real backups into this
public repository or chat. Verify an exported file locally by passing its
password on stdin from a password manager:

```sh
password-manager-command | npx tsx scripts/verify-backup.ts FILE.lutera-backup
```

Run this from `apps/workspace`. Verification prints record counts only and does
not extract private data. The unit suite verifies decryption, rejection of
wrong passwords and rejection of altered ciphertext.

The project owner must choose an off-site retention destination and confirm the
Supabase plan's automated database backups/PITR policy. Automatic off-site
backups have **not** been configured or claimed. Storage objects need their own
backup; database backups alone do not contain photo file bytes.

A restore is an operator-controlled maintenance procedure, not a public RPC:
stop writes, verify/decrypt the backup offline, restore into an isolated project,
validate schemas/counts/totals, restore the original document IDs and counters
before issuing new numbers, and copy photo bytes to the private bucket. Restore
issued rows through database-owner tooling with application mutation triggers
temporarily disabled within the restore transaction, then re-enable them and
rerun the access suite. Auth secrets are excluded: recreate/verify Auth accounts,
rebind approved email memberships and re-enroll MFA rather than restoring old
sessions. Review access rules before enabling users. A full recovery drill is
a launch follow-up; no untested one-click restore is exposed.

## Verification evidence and remaining launch checks

Verified locally:

- Strict TypeScript check, production Next.js build and production npm audit
  (no reported production dependency vulnerabilities at the check time).
- Integer totals, tax rounding, financial validation, Origin protection and
  public-content contract tests.
- Real PDF/DOCX/PNG generation for all three document types and both staff-card
  templates; multi-page financial output and two-sided print dimensions.
- Encrypted backup round trip and authenticated failure cases.
- PostgreSQL migration/access suite using minimal Supabase Auth fixtures:
  AAL1 denial, owner/editor separation, revoked/expired sessions, immutable
  issued records/audit, numbering, totals, snapshots and overpayment rejection.
- Real unauthenticated Next.js endpoint/CSRF denials, then browser API fixtures
  for login → MFA → quotation → issue → download, staff cards and public-content
  draft → publish → live check. Phone/tablet/desktop widths pass; axe reports
  no WCAG A/AA violations on the checked screens. These are fixture flows, not
  proof of a live authenticated owner session.
- Public builds for production and preview; a changed two-service catalogue
  verifies add/remove/rename, custom pages, escaping, contact routing, social
  links and dynamic sitemaps. Live anonymous Supabase requests return 401 for
  private tables; the public snapshot returns one row.
- Supabase security advisor returned no lints after provisioning. Performance
  advisor reported only three unused indexes on the empty project
  ([explanation](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index)).
- All 32 existing public live checks pass after the updated production build;
  `/site-revision.json` matches the seeded public snapshot.
- Production browser check through retained Vercel protection: login renders
  without JavaScript errors, password input is masked, and anonymous document
  search returns 401. Root, `/admin` and a wrong entry return 404; anonymous
  session/state return 401 and cross-origin mutations return 403. Responses
  carry noindex/no-store and CSP headers. No owner credentials were entered.
- GitHub Private workspace checks run `39831731770` passed both application and
  database jobs for `2d5b85ee99210bbd178d2642dc15c3891cce7c63`.

The actual Supabase access suite has passed, fixtures have rolled back and the
latest security advisor reports a provider warning for disabled leaked-password
protection; that owner/provider setting has not been changed. The separate
Vercel app is deployed.
Before operational use: complete provider Auth settings and verified owner/MFA
setup, connect its deploy hook, and exercise a real owner login/save/export/
publish/sign-out cycle. Confirm an unauthorised account and a pre-MFA session
cannot read records. Choose backup retention and complete a recovery drill.
No actual payment or customer enquiry should be submitted during checks.

## Official-domain account emails — 22 October update

`workspace.luteratech.com` is attached to the private Vercel project with verified
DNS. Production `WORKSPACE_ORIGIN` has been updated; the new build applies it.
The `mail.luteratech.com` sending domain is verified in Resend, with all four
provider DNS records set in Cloudflare and click/open tracking disabled. The
public website and existing mailbox routing are preserved.

All 13 Supabase account email templates use Lutera Technology Ltd, the supplied
logo rendered as a PNG for email compatibility, the official company website
and monitored support contact. They include subjects, authentication actions
and security notifications. The callback waits for an explicit same-origin POST
before consuming a token; approval, confirmed email and MFA still gate access.
Invitation passwords are chosen privately. Recovery routes users through their
existing MFA to My account; a successful password change revokes all sessions.

The owner has reported saving the hosted Supabase Site URL/allowlist, SMTP
sender and templates. Public settings confirm signup disabled and email
confirmation enabled; the owner has a verified TOTP factor. The connected tool
exposes no Auth configuration operation and no Management API token is
provisioned. The owner subsequently confirmed a fresh account email shows the
company sender, logo and official workspace link correctly. Complete real-account
token acceptance and recovery remain an owner smoke check.
The complete, non-secret payload,
individual templates and a private owner-run configuration utility are in
[the email setup directory](../apps/workspace/email/README.md). A fresh owner
invitation/recovery inbox check remains required after those settings are saved.

## Self-service accounts and authentication limits — 22 October update

My account now includes a private full name, contact phone and profile photo;
confirmed email changes; password requirements and visibility controls; and
verified authenticator status with enrollment of up to three authenticator
apps. MFA remains mandatory, and removing the last factor is not exposed.
A phone number is contact information, not a verified SMS factor.

Profiles and normalized JPEG avatars are accessible only by their own approved,
MFA-verified account. Photos accept JPEG/PNG/WebP below 1 MB and 16 megapixels;
metadata is stripped and the output is bounded to 512 pixels. Concurrent profile
saves check versions and rejected uploads are removed. Account data does not
change the company's public contact information or staff-card records.
The manual business-records backup does not include these personal account
profiles/photos; include their table/bucket in full database/storage backups.

Email changes reserve the new address for the current immutable Auth user ID.
The existing address stays approved until Supabase confirms the change. The
claim function then moves that same membership to the verified address,
preserving its role and active status. Other members cannot claim or be granted
a reserved address. A failed provider request releases its reservation only if
GoTrue has not accepted the change. No account role comes from user metadata.

All password inputs, including login, invitation, account and encrypted-backup
fields, have accessible show/hide controls. New account passwords require
12–128 characters, uppercase/lowercase letters, a number and a symbol, with
live requirement checks and identical server-side validation. Existing passwords
can still be used to sign in; the new composition policy applies when setting
or changing a password. Backup passwords retain their separate 16-character
minimum. Successful account password changes revoke all account sessions and
show a sign-in confirmation. Error/success notices, pending-email states and
429 retry countdowns are explicit and announced to assistive technology.

Authentication requests use an atomic shared Postgres limiter, rather than
process memory. A Production-only sensitive `AUTH_RATE_SECRET` authenticates the
narrow limiter RPC. Only its SHA-256 digest is stored in the inaccessible private
configuration table. Rate buckets contain HMAC-derived keys, counts and expiry,
not raw emails or IP addresses. The RPC's definer helper is in the unexposed
private schema with fixed search_path; private tables have no client grants and
explicit deny policies. Expired buckets are cleaned up. A failed rate backend
fails closed with 503; exceeding a quota returns 429 and Retry-After.

Application limits (all attempts, including successes):

| Request | Per subject | Per IP |
| --- | --- | --- |
| Password login | 10 / 15 minutes per email | 30 / 15 minutes |
| Authenticator enrollment/verification | 10 / 5 minutes per account and action | 20 / 5 minutes per action |
| Email-token confirmation | 5 / 15 minutes per token | 20 / 15 minutes |
| Password/email changes | 5 / 15 minutes per account and action | 20 / 15 minutes per action |

All protected actions also share an IP cap of 60 / 15 minutes. Production trusts
Vercel's edge-supplied IP headers, not client-supplied Cloudflare/Forwarded
headers. Keep the workspace's current DNS-only routing unless a trusted proxy
integration is explicitly configured. These application limits supplement
Supabase's own provider limits; direct Auth API policy remains controlled by
Supabase. The provider's leaked-password protection warning remains an owner
setting and was not changed by this implementation.

`AUTH_RATE_SECRET` is already configured for the production workspace. For a
replacement installation, generate 32 random bytes as 64 hex characters, store
them as this server-only sensitive variable, and store their SHA-256 hex digest
in `private.work_rate_config` (id 1) using database-owner tooling. Do not place
that secret in Git, browser variables, logs or backups shared through chat.
Preview environments continue to have no production credential configuration.

Verification: 18 unit/export tests and a production build pass. Account browser
fixtures cover profile/photo/email updates, additional MFA, password validation,
visibility controls, a successful password-change notification, and login 429
countdowns at 390/768/1280 pixels with no reported axe WCAG A/AA violations.
The existing browser and email suites also pass. New database tests pass both
locally and on actual Supabase, with fixture users/records rolled back. A real
parallel REST check admitted exactly 3 of 8 attempts for a test bucket and denied
5; the test bucket was then removed. No real email or password was changed by
these tests. Final production HTTP checks follow deployment.

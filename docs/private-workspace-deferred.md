# Private business workspace — deferred

The owner asked for the public website review/agreed-direction implementation to be finished first. This rebrand does not implement or provision the private workspace.

The later scope to retain is a private management interface for company information, services, contact/social details; pro forma/quotation invoices and payment receipts; staff name cards and ID cards; and PDF, Word/document and image exports using the supplied brand assets.

A hidden URL is not an access control. That phase requires a separate authenticated application and server-side authorisation, appropriate MFA, roles, secure sessions, audit records, backups and controlled document storage. The current static Vercel frontend does not provide these protections or private record storage. No credentials, staff records or financial records should be committed to this public repository. Provider choice, access policies, numbering/tax/payment fields and supported export formats need a concrete implementation brief for that phase.

The public site now reads shared company/service content from `content/site.json` and legal copy from `content/legal.json`. These are a future integration foundation; they do not expose a write API or create an administrator account.

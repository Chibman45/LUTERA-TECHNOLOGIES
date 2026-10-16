# LUTERA TECHNOLOGIES

Business IT procurement, hardware, consulting and support website. Static pages deployed with GitHub Pages. No database, admin accounts, payment or checkout.

## Website

Expected Pages address after deployment: https://chibman45.github.io/LUTERA-TECHNOLOGIES/

Repository Settings → Pages → Build and deployment → Source: **GitHub Actions**. The deployment workflow builds, checks and packages only the public site. Private repositories need a GitHub plan that supports Pages; otherwise the owner must make the repository public.

## Email enquiries

Procurement and contact forms POST over HTTPS to FormSubmit, which sends submissions to **chimaster010@gmail.com**. No API keys or private credentials are stored in source. Both forms set distinct subject lines, capture the sender's email for Reply-To, include privacy acknowledgement with a client timestamp, retain spam prevention and redirect to the thank-you page after provider processing.

**One-time owner activation:** the first submission may trigger a FormSubmit activation email. The inbox owner must click its confirmation link. Check spam/junk. Until that is completed, email delivery is not verified. Always submit a test after activation and confirm receipt; opening the thank-you page alone does not verify inbox delivery. No test or acknowledgement email is sent to arbitrary visitor addresses.

FormSubmit handles the form submission and its spam checks. The website does not operate a customer database; provider retention is governed by its own terms and privacy policy. Direct email and WhatsApp remain available if the form service is unavailable. JavaScript reduces accidental double clicks but does not guarantee server-side idempotency. Without JavaScript the forms still submit using standard HTML.

## Development

```sh
python scripts/build.py
python scripts/check.py
node --check assets/app.js
```

Serve the repository under `/LUTERA-TECHNOLOGIES/` to match generated links. `SITE_BASE` and `SITE_ORIGIN` environment variables override the default GitHub Pages path and origin when rebuilding for another location.

Editable SVG brand variants and the lightweight hardware illustration live in `assets/`. Colors are editable tokens in `assets/style.css`. Motion respects reduced-motion preferences. No WebGL, advertising analytics or tracking scripts are loaded on the site. FormSubmit may show its own spam-prevention page.

## Validation

Internal links, asset paths, image alt text, unique HTML IDs, single h1 headings and JavaScript syntax are checked in CI. Browser tests cover desktop/mobile layout, navigation, required procurement quantities, past-date rejection, captured form payloads and form redirects. Inbox receipt still requires owner activation and confirmation.

Incorporation is pending. No registration, certification, reseller status, stock availability, fixed pricing or customer endorsements are asserted.

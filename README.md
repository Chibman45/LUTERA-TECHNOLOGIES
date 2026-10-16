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

The logo recreates the supplied name card’s silver/blue L, orbital swoosh, cyan pixels and LUTERA wordmark. `assets/lutera-logo.png` is the full-resolution artwork; `lutera-logo.webp` is the 42 KB web asset. The SVG favicon follows the same emblem. Colors remain editable in `assets/style.css`.

Fonts are self-hosted as WOFF2 (with OFL licenses), avoiding external font requests.

The desktop hero uses self-hosted Three.js 0.180.0 to model a laptop, server and network switch. It responds to pointer movement, animates connection packets and supports pause/resume. After the initial page renders, 3D starts automatically on desktop layouts wider than 1024 CSS pixels with a mouse or trackpad. There is no activation button or GPU/startup-time opt-in gate. Mobile and tablet devices retain the standard illustration, including identified tablets with connected pointing devices. The loop caps rendering to approximately 30 fps, limits pixel ratio, and suspends offscreen or in background tabs. Mobile, reduced-motion, data-saver and unavailable-WebGL paths retain the static illustration; mobile and reduced-motion visitors do not download the 3D library. Section reveals, card tilt, hero entrance, gradient motion and a procurement scan complete the motion treatment. No advertising analytics or tracking scripts are loaded. FormSubmit may show its own spam-prevention page.

## Validation

Internal links, asset paths, image alt text, unique HTML IDs, single h1 headings and JavaScript syntax are checked in CI. Browser tests cover desktop/mobile layout, navigation, required procurement quantities, past-date rejection, captured form payloads and form redirects. Inbox receipt still requires owner activation and confirmation.

Incorporation is pending. No registration, certification, reseller status, stock availability, fixed pricing or customer endorsements are asserted.

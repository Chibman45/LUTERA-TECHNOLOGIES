# LUTERA TECHNOLOGIES

Abuja-based IT and AI solutions, automation, software, data analytics, cloud integration, hardware procurement, consulting and support website. Static pages deployed with GitHub Pages. No database, admin accounts, payment or checkout.

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

The desktop hero uses self-hosted Three.js 0.180.0 to model a laptop, server and network switch. It responds to pointer movement, animates connection packets and supports pause/resume. After the initial page renders, 3D starts automatically on desktop and large-tablet layouts at least 1024 CSS pixels wide, including touch-only tablets. Tablets at least 768 pixels wide also qualify when a mouse/trackpad is available or trusted Tab-key navigation signals keyboard use. Browsers cannot directly report a keyboard being attached. Phones and smaller tablet layouts retain the standard illustration. There is no activation button or GPU/startup-time opt-in gate. The loop caps rendering to approximately 30 fps, limits pixel ratio, and suspends offscreen or in background tabs. Phone, reduced-motion, data-saver and unavailable-WebGL paths retain the static illustration; phone and reduced-motion visitors do not download the 3D library. Section reveals, card tilt, hero entrance, gradient motion and a procurement scan complete the motion treatment. No advertising analytics or tracking scripts are loaded. FormSubmit may show its own spam-prevention page.

## Validation

Internal links, asset paths, image alt text, unique HTML IDs, single h1 headings and JavaScript syntax are checked in CI. Browser tests cover desktop/mobile layout, navigation, required procurement quantities, past-date rejection, captured form payloads and form redirects. Inbox receipt still requires owner activation and confirmation.

Incorporation is pending. No registration, certification, reseller status, stock availability, fixed pricing or customer endorsements are asserted.

## Modern procurement experience

The homepage equipment explorer, business-need selectors and Solutions comparison feed one enquiry list. Customers can change quantities and use a three-step form to email the complete brief. Local equipment photography, asymmetric service layouts, orbital graphics, an interactive timeline and a floating quote and WhatsApp contact icon complete additions 1–10. See `docs/experience-upgrade.md` and `docs/photo-credits.md`.

The list uses functional session storage for equipment IDs/quantities and a predefined business-need ID only. Free-text answers and contact details stay in the live form; no database is used. If storage is blocked, the Continue to quote link can carry equipment selections in its URL. Notices were updated for this behavior.

Run the isolated browser checks with:

```sh
python -m pip install -r tests/requirements.txt
python -m playwright install chromium
python tests/browser_experience.py
python tests/browser_tablet_3d.py
```

The test starts its own static server and intercepts external form submissions, so it sends no email. Set `LUTERA_TEST_URL` to check another deployment. Set `LUTERA_SCREENSHOTS` to an existing output directory to retain screenshots. Desktop/eligible-tablet 3D, phone/small-tablet fallbacks and reduced-motion preferences remain supported. Touch swipes scroll the page without picking equipment; taps and keyboard controls remain available.

Company facts are maintained in `scripts/company.py`, including the owner-supplied Abuja address, administrative location and nature of business. The About and Contact pages, footer and Organization structured data share these details. Digital-service quote links preselect AI, software, data or cloud enquiries without requiring equipment quantities.

The Solutions page covers digital solutions, consulting, procurement/supply and installation/maintenance/support alongside the equipment catalogue and comparison. Subject-specific local imagery supports every solution; AI/software/data/cloud cards share their content and images with the homepage and Services page.

Cinematic navigation adds native perspective page transitions where supported and a short curtain fallback elsewhere. The homepage project story has a scroll-driven CSS 3D assembly, four directly linked chapters and a pause control. It preserves native scrolling, browser history, forms and enquiry selections, with static/reduced-motion and no-JavaScript alternatives. See `docs/motion-and-brand.md`; run `python tests/browser_cinematic.py` to verify it.

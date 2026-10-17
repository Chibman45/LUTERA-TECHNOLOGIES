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
python tests/browser_consent.py
```

The test starts its own static server and intercepts external form submissions, so it sends no email. Set `LUTERA_TEST_URL` to check another deployment. Set `LUTERA_SCREENSHOTS` to an existing output directory to retain screenshots. Desktop/eligible-tablet 3D, phone/small-tablet fallbacks and reduced-motion preferences remain supported. Touch swipes scroll the page without picking equipment; taps and keyboard controls remain available.

Company facts are maintained in `scripts/company.py`, including the owner-supplied Abuja address, administrative location and nature of business. The About and Contact pages, footer and Organization structured data share these details. Digital-service quote links preselect AI, software, data or cloud enquiries without requiring equipment quantities.

The Solutions page covers digital solutions, consulting, procurement/supply and installation/maintenance/support alongside the equipment catalogue and comparison. Subject-specific local imagery supports every solution; AI/software/data/cloud cards share their content and images with the homepage and Services page.

## Search visibility and audit

Every public page has unique titles and descriptions, canonical links, PNG social-preview metadata and JSON-LD for the organization, website, breadcrumbs and relevant services. The four digital service landing pages are linked from the shared solution cards. The sitemap includes 17 indexable URLs; confirmation and error pages use noindex. `scripts/check_seo.py` validates this public surface in CI.

Google and Bing ownership verification are not completed until the owner signs in and verifies the supplied tag. See `docs/search-engine-setup.md` for the exact URL-prefix property, sitemap and supported GitHub Actions variables. A successful Pages deployment also notifies IndexNow engines with the public sitemap URLs; a successful notification is not proof of indexing. The key in `indexnow.txt` is the protocol's public validation token, not an account credential.

Lighthouse 13.5.0 was used to audit the published homepage on mobile/desktop, Solutions on mobile and Contact on mobile. Measurements are lab runs, not field Core Web Vitals or ranking guarantees. A before/after visual diagnostic measured 155 versus 25 WebGL draw calls with the same 4,792 triangles, preserving the existing automatic 3D scene and picking behavior. Saved Lighthouse HTML/JSON reports are supplied separately with the audit results. Hosting controls the GitHub Pages 10-minute cache policy; the project does not pretend to configure hostname-root robots.txt from a nested path.

```sh
python scripts/check_seo.py
python scripts/submit_indexnow.py # validates only; sends nothing
```

The 3D renderer uses a cost-based frame/resolution budget on slow GPUs and avoids duplicate resize renders. Phones and touch-only layouts display text and cards directly instead of initializing scroll reveals. This preserves the existing 3D eligibility and restored page design.

## Cookie preferences

Every page includes a non-modal privacy notice with equally prominent Accept optional and Reject optional controls. Cookie settings in the footer reopens it. `assets/consent.js` stores only the choice, notice version and choice timestamp in `lutera_cookie_consent_session_v2` session storage for the current visit in a browser tab. Internal navigation and reloads keep the choice. New tabs, direct address entry and entry through an external link ask again, including when a browser restores or copies a previous tab session. Tabs choose independently. The old 180-day local preference is removed and ignored. Invalid records or cleared storage show the notice again; blocked storage preserves the current page's choice only. Essential enquiry-list storage and forms work after either choice.

No optional analytics, advertising cookies or tracking scripts are installed, even after acceptance. This notice does not control cookies used on separate FormSubmit, reCAPTCHA or WhatsApp websites. Adding optional tracking later requires gating initialization on a valid acceptance, stopping it on withdrawal and revising the notice/version and policy; acceptance alone currently enables nothing. The cookie and privacy pages document the actual storage and third-party behavior.

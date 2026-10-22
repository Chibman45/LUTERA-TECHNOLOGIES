# Lutera Technology Ltd

Public, database-free website for Lutera’s eight services: IT procurement, hardware supply, technology consulting, installation and support (including computer labs), AI and automation, software development, data analytics, and cloud integration.

Repository: **https://github.com/luteratech/LUTERA-TECHNOLOGIES**

Hosting: **Vercel only**. GitHub stores the source and runs checks; the GitHub Pages publishing workflow has been removed.

The original repository has been transferred from `Chibman45` to `luteratech`,
retaining its history. Import it into Vercel, choose **Other** as the framework
preset and leave the root directory at the repository root. `vercel.json`
already sets the build command and output directory. Vercel deploys `main` after
import and on subsequent pushes. See [Vercel setup](docs/vercel-deployment.md) for
details. The approved primary domain is **https://luteratech.com/**.

The owner has now connected the custom domains in Vercel/Cloudflare. `content/site.json` records the approved primary origin and redirect aliases. Vercel must connect the primary domain to Production and permanently redirect the aliases, retaining paths and query strings. The owner has authorised the private workspace, now implemented as a separate application in `apps/workspace`. Its deployment and verified owner login are being completed; see [the runbook](docs/private-workspace.md).

## Brand and content

The supplied Lab rows master SVGs are in `assets/logo/`. Header, footer, favicon and social previews use this identity. The website uses the supplied Paper/Navy/blue tokens, self-hosted Sora and occasional Playfair italic, light layouts and short hover/focus transitions. The homepage uses a photographic background with a gentle crossfade and pan, constant readable text, automatic image rotation and a plain pause/resume option in the footer. Motion pauses offscreen and in background tabs. Reduced-motion, data-saving and no-JavaScript sessions keep a still hero image. The old Three.js hero and library have been removed. Reduced motion disables transitions; content does not depend on animation.

Edit company facts, service summaries, image mappings and delivery/support commitments in `content/site.json`. The confirmed company name is **Lutera Technology Ltd**. Registration is completed; the RC number is omitted. Legal content is in `content/legal.json`; the Python templates provide page structure, service detail copy and enquiry components. Development uses these shared files. Production builds can read the explicitly published workspace snapshot; `content/workspace-source.json` contains only its public/publishable connection details. The private database has no anonymous record access. See the runbook for the draft/publish workflow.

Photographs illustrate services and equipment, rather than claiming to show Lutera projects, premises or staff. Sources are documented in `docs/photo-credits.md`. Supplied font licences are included. Logo geometry and outlined wordmarks are preserved. Responsive WebP photo assets are prepared with `scripts/prepare_images.py` (Pillow required only for this developer task). `scripts/prepare_hero_images.py` regenerates the responsive hero backgrounds from the credited image sources. `scripts/render_social.py` regenerates the committed social PNGs using Playwright/Chromium; it is a developer tool, not a runtime dependency.

Card photographs have 480/768/960px candidates and layout-specific `sizes`, so
desktop cards and high-DPI phones can avoid unnecessarily large downloads. The
build combines the three source stylesheets into one file with a content hash
in its name, and preloads the accent font only on the homepage that uses it.
The source CSS and brand tokens remain editable separately.

## Enquiries and privacy

The quote wizard, equipment list and comparison feed a native HTTPS FormSubmit POST to **chimaster010@gmail.com**. The contact form uses the same recipient. The public enquiry flow uses no database or private credentials. The separate workspace stores only its private operational records in Supabase. Direct email, phone and the bottom-right WhatsApp/quote control remain available. Forms also work without JavaScript; mobile navigation remains available without JavaScript.

Tests intercept submissions and verify payloads without sending mail. FormSubmit inbox activation and actual receipt are controlled by the inbox owner/provider. The thank-you page alone is not evidence of delivery. Replies are promised within two working days; resolution/delivery times are agreed separately. Warranty starts at site acceptance, with duration, coverage and exclusions in the written quotation.

Equipment IDs, quantities and a predefined business need use functional session storage. Free text and contact details are not persisted there. When storage is blocked, an equipment selection can be passed through the quote URL.

The non-modal cookie notice offers equally prominent accept/reject choices on every fresh visit. Internal navigation/reload retains the choice for the current tab. New tabs, direct entries and external returns ask again. Cookie settings in the footer allows changes. No optional analytics, advertising cookies or tracking scripts are installed, even after acceptance. Third-party websites have their own policies.

## Build and checks

```sh
python tests/build_vercel.py
python scripts/build_vercel.py
python scripts/submit_indexnow.py  # validate only, no network notification
node --check assets/app.js
node --check assets/experience.js
node --check assets/consent.js
node --check assets/motion.js
python -m pip install -r tests/requirements.txt
python -m playwright install chromium
python tests/browser_brand.py
python tests/browser_hero.py
python tests/browser_experience.py
python tests/browser_consent.py
python scripts/review_live.py  # read-only checks against the primary domain and aliases
```

Browser tests start their own local server against `_site` at `/`. Set `LUTERA_TEST_URL` to test a deployed site. The Vercel build uses root paths and the approved custom origin; `SITE_ORIGIN` is an explicit override for test artifacts or a later approved move. GitHub Actions validates the build and browser flows; it does not publish a website. Only public pages/assets from `_site` are deployed.

## Search visibility

All 19 pages retain their existing paths, unique metadata, canonical URLs and social cards. The sitemap contains 17 indexable URLs; error/confirmation pages are excluded and marked noindex. Organization, WebSite, Service and Breadcrumb structured data use the resolved Vercel production origin. Preview builds are noindex. Search ownership verification and post-launch sitemap submission use the deployed Vercel address; see `docs/search-engine-setup.md`.

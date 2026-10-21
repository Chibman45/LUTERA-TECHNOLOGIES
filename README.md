# Lutera Technology Ltd

Public, database-free website for Lutera’s eight services: IT procurement, hardware supply, technology consulting, installation and support (including computer labs), AI and automation, software development, data analytics, and cloud integration.

Live review site: **https://chibman45.github.io/LUTERA-TECHNOLOGIES/**

The owner has deferred connecting `luteratech.com` and `luteratech.com.ng` until review is complete. No DNS, registrar or custom-domain settings are changed by this rebrand. The future private business workspace is also deferred; this repository does not contain an admin login, invoice system or staff-card generator.

## Brand and content

The supplied Lab rows master SVGs are in `assets/logo/`. Header, footer, favicon and social previews use this identity. The website uses the supplied Paper/Navy/blue tokens, self-hosted Sora and occasional Playfair italic, light layouts and short hover/focus transitions. The homepage uses a photographic background with a gentle crossfade and pan, constant readable text, automatic image rotation and a plain pause/resume option in the footer. Motion pauses offscreen and in background tabs. Reduced-motion, data-saving and no-JavaScript sessions keep a still hero image. The old Three.js hero and library have been removed. Reduced motion disables transitions; content does not depend on animation.

Edit company facts, service summaries, image mappings and delivery/support commitments in `content/site.json`. The confirmed company name is **Lutera Technology Ltd**. Registration is completed; the RC number is omitted. Legal content is in `content/legal.json`; the Python templates provide page structure, service detail copy and enquiry components. These shared files provide a public content foundation for the future workspace without introducing it now.

Photographs illustrate services and equipment, rather than claiming to show Lutera projects, premises or staff. Sources are documented in `docs/photo-credits.md`. Supplied font licences are included. Logo geometry and outlined wordmarks are preserved. Responsive WebP photo assets are prepared with `scripts/prepare_images.py` (Pillow required only for this developer task). `scripts/prepare_hero_images.py` regenerates the responsive hero backgrounds from the credited image sources. `scripts/render_social.py` regenerates the committed social PNGs using Playwright/Chromium; it is a developer tool, not a runtime dependency.

## Enquiries and privacy

The quote wizard, equipment list and comparison feed a native HTTPS FormSubmit POST to **chimaster010@gmail.com**. The contact form uses the same recipient. No database or private credentials are used. Direct email, phone and the bottom-right WhatsApp/quote control remain available. Forms also work without JavaScript; mobile navigation remains available without JavaScript.

Tests intercept submissions and verify payloads without sending mail. FormSubmit inbox activation and actual receipt are controlled by the inbox owner/provider. The thank-you page alone is not evidence of delivery. Replies are promised within two working days; resolution/delivery times are agreed separately. Warranty starts at site acceptance, with duration, coverage and exclusions in the written quotation.

Equipment IDs, quantities and a predefined business need use functional session storage. Free text and contact details are not persisted there. When storage is blocked, an equipment selection can be passed through the quote URL.

The non-modal cookie notice offers equally prominent accept/reject choices on every fresh visit. Internal navigation/reload retains the choice for the current tab. New tabs, direct entries and external returns ask again. Cookie settings in the footer allows changes. No optional analytics, advertising cookies or tracking scripts are installed, even after acceptance. Third-party websites have their own policies.

## Build and checks

```sh
python scripts/build.py
python scripts/check.py
python scripts/check_seo.py
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
```

Browser tests start their own local server. Set `LUTERA_TEST_URL` to test another deployment. Pages default to `/LUTERA-TECHNOLOGIES/`; `SITE_BASE` and `SITE_ORIGIN` support a later coordinated domain cutover. GitHub Actions builds, validates and deploys only the public pages/assets. No content directory, development scripts or tests are packaged into the Pages artifact.

## Search visibility

All 19 pages retain their existing paths, unique metadata, canonical URLs and social cards. The sitemap contains 17 indexable URLs; error/confirmation pages are excluded and marked noindex. Organization, WebSite, Service and Breadcrumb structured data use the current company identity and GitHub Pages address. IndexNow notifications follow deployment; receipt is not evidence of indexing. Google Search Console/Bing ownership setup remains separate; see `docs/search-engine-setup.md`.

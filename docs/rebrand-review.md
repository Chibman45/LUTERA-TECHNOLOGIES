# Public rebrand implementation review

Updated 22 October 2026. Scope: the agreed public website review direction, with the owner’s latest clarifications applied. The company name is Lutera Technology Ltd; no RC number is displayed. Registration-pending notices are removed. Hosting is Vercel only; the owner has connected the custom domains. The private business workspace remains a separate, deferred phase.

## Implemented

- Supplied Lab rows SVG identity, new favicon, social PNGs, self-hosted fonts and Paper/Navy/blue design tokens. All 24 supplied SVG masters are unchanged byte for byte.
- Light homepage, shared header/footer, all service and utility pages; equal-width, equally styled cards for the eight services. Installation/support includes computer-lab planning, installation, imaging, testing, commissioning and handover.
- Solutions organised by workflow/digital work, IT planning/support and equipment needs. Representative service-specific photographs are clearly labelled; local responsive WebP variants reduce transfer size.
- Confirmed address and company details; inspection, local spares, named support and warranty-start wording. Two-working-day enquiry responses are distinguished from fault resolution/delivery commitments; warranty duration/coverage remain subject to written quotation.
- Restyled quote wizard, equipment enquiry list, comparison, contact form and floating contact control. Existing form IDs and transport fields, native HTTPS submission and chimaster010@gmail.com routing remain intact.
- Fresh-visit consent and footer settings, keyboard controls, reduced motion and no-JavaScript forms/navigation. The former renderer, Three.js bundle, cinematic/tilt effects and old brand artwork are removed.
- Existing 19 routes, 17 indexable sitemap entries, canonicals, social metadata and Organization/WebSite/Service/Breadcrumb schema retained. The current build uses `https://luteratech.com` for production metadata and form returns; preview builds remain noindex with preview-specific form returns. No Projects route or unsupported customer/certification claims introduced.
- GitHub Pages unpublished and its deployment workflow removed. Vercel builds the public-only `_site` artifact from shared sources. A read-only live review checks deployed metadata, native form destinations, real unknown-route status and permanent alias redirects with path/query preservation.

## Verification

Static checks validate paths, responsive image variants, headings, IDs, alt text, metadata, sitemap and IndexNow payload. JavaScript syntax checks cover all four shipped scripts. The live Lighthouse review identified and corrected heading-level skips on Services and the quote form; the static check now guards against those skips. The sticky header also avoids a synchronous layout read during startup.

Browser regression suites cover all 19 routes and image loads; eight service-to-quote links; equal service widths and 320–1440px containment; tablet/mobile navigation; keyboard use; reduced motion; absence of 3D downloads; enquiry persistence, quantity/date validation, comparison and wizard navigation; no-JavaScript submission/navigation; blocked storage; both native form payloads; and fresh-visit consent behaviour. Test submissions are intercepted, so automated checks send no real enquiries and do not verify inbox delivery.

Visual review covers desktop homepage, Services, Solutions, About, Contact and quote; tablet Services; mobile homepage, Contact and support. Lighthouse lab reports and screenshots are saved outside the deployed artifact. Lab scores are not field Core Web Vitals or search-ranking guarantees. Search Console/Bing ownership setup remains an owner action.

## Deferred

- Final release evidence and domain redirect status are tracked in `launch-review.md`. Google Search Console/Bing ownership and actual inbox delivery remain owner/provider checks.
- The separate authenticated private workspace and document/card generators. See `private-workspace-deferred.md`.
- Actual project/customer evidence and detailed warranty duration/coverage until supplied; representative images and written-quotation scope remain explicit.

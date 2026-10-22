# Public website launch review

22 October 2026. Final public-site phase of the agreed implementation plan.
Primary domain: **https://luteratech.com/**. GitHub Pages is unpublished; hosting
and push deployment use Vercel only.

## Implemented in this release

- Committed the approved production origin in shared content. Canonicals, social
  images/URLs, Organization/WebSite/Service/Breadcrumb schema, sitemap, robots
  and both form return URLs are generated for that origin. Preview builds retain
  production canonicals, noindex and preview-specific form return URLs.
- Added permanent host-specific redirects for `www.luteratech.com`,
  `luteratech.com.ng` and `www.luteratech.com.ng`, preserving paths and query
  strings. They require working DNS/HTTPS and the domains attached in Vercel.
- Added `scripts/review_live.py`: repeatable, read-only checks of all 19 pages,
  17 sitemap entries, metadata, enquiry transport/return destinations, public
  IndexNow token, genuine unknown-route 404 and alias routing. It never submits
  enquiries or reports email delivery as verified.
- Updated the hosting, search-ownership and review documentation for the current
  production phase. The private workspace remains deferred.

## Verification status

Code revision: `e342003b072633881febda5a9047ff72397e1eeb`.
[Vercel deployment](https://vercel.com/0xluter-s-projects/lutera_website/DBkcZyBzw5KpRfx5gtysgMQCPrDU)
reported completed; [both GitHub CI jobs](https://github.com/luteratech/LUTERA-TECHNOLOGIES/actions/runs/39791518319)
passed, including all four browser suites and production/preview packaging.

The final live HTTP/SEO review passes all 26 checks: 19 pages, sitemap, robots,
IndexNow token, an unknown-route 404 and three alias quote-path/query redirects.
The owner saved the Vercel domain assignments. `www.luteratech.com` responds with
301; both `.com.ng` aliases respond with 308. All three retain
`/request-quote/?need=infrastructure` and finish on the primary origin with 200.
Direct probes for source/configuration paths (`content/site.json`, `README.md`,
`scripts/build_vercel.py`, `vercel.json`) returned 404.

Live browser brand/navigation checks pass all 19 routes, images, eight service
links, 320–1440px layouts and keyboard/no-JavaScript behaviour. The separate live
consent suite passes. The complete live enquiry suite also passes: equipment-list
persistence, quantities, comparison, wizard validation/back navigation, native
quote/contact payloads, responsive layouts, floating controls, no-JavaScript
forms and storage-blocked fallbacks. Its first attempt hit a 30-second remote
navigation timeout during responsive checks; a fresh full run passed without
code changes. No test messages were sent to the business inbox.

IndexNow accepted the notification for all 17 final-domain URLs with HTTP **202**.
Key validation is pending. This is not confirmation of crawling, indexing or ranking.

Generated JSON and full Lighthouse HTML/JSON reports are stored outside the public
artifact in the session's `lutera-launch-review` folder.

### Lighthouse lab review

Lighthouse 13.5.0 and Chromium, normal fresh-visit consent and standard profiles.

| Page/profile | Performance | Accessibility | Best practices | SEO |
| --- | ---: | ---: | ---: | ---: |
| Home/mobile | 62 | 100 | 100 | 100 |
| Solutions/mobile | 63 | 100 | 100 | 100 |
| Quote/mobile | 62 | 100 | 100 | 100 |
| Home/desktop | 87 | 100 | 100 | 100 |

All three mobile reports warn that this machine's CPU is slower than Lighthouse
expects. Home/mobile measured LCP 2.8s and blocking time 2,490ms; home/desktop
measured LCP 0.9s, blocking time 220ms and zero layout shift. Treat the mobile
scores as measurements requiring reproduction on a stable external runner, not
as a field Core Web Vitals baseline. Consent was not hidden or delayed for the
audit. No code changes were made to recognise Lighthouse or inflate its scores.
Performance remains an improvement area pending that reproduction. The audits
also note about 25 KiB of potential image savings on the homepage.

Before this release the custom domain served pages with the Vercel hostname in
all 19 canonical/schema/social metadata sets, the sitemap, robots advertisement
and the two form return URLs. Alias quote-path probes also served directly
instead of permanently redirecting to the primary origin. The live checker
detects those incomplete-cutover cases.

During this initial review, the extra `/LUTERA-TECHNOLOGIES/...` migration-prefix
rules returned 404 for slash-terminated page paths. The subsequent
[performance/routing follow-up](performance-follow-up.md) identifies Vercel's
strict trailing-slash matching, fixes those rules and verifies all six live
legacy-prefix cases. Redirects cannot handle requests arriving at GitHub's
retired hostname.

## Remaining owner/provider items

- Complete Google Search Console and Bing Webmaster ownership verification and
  submit `https://luteratech.com/sitemap.xml`. No account verification value has
  been supplied. See `search-engine-setup.md` for DNS and HTML-tag options.
- Confirm an actual contact and quote enquiry reach the business inbox. Browser
  tests intercept provider requests and cannot verify email delivery.
- Supply real project photographs, permissions and results before a Projects
  section or client case studies; confirm written warranty coverage/duration
  before publishing those details. Existing representative imagery and written
  quotation scope remain explicit.
- Review the separate private-workspace implementation brief after public-site
  sign-off. Authentication/MFA, document fields/numbering and private storage
  must be resolved for that phase. No admin or document generator is deployed.

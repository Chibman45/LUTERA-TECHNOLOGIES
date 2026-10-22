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

Production/preview build checks pass locally. Live release evidence will be
recorded after the Vercel deployment is available. Generated JSON, Lighthouse
reports and screenshots are stored outside the public artifact.

Before this release the custom domain served pages with the Vercel hostname in
all 19 canonical/schema/social metadata sets, the sitemap, robots advertisement
and the two form return URLs. Alias quote-path probes also served directly
instead of permanently redirecting to the primary origin. The live checker
detects those incomplete-cutover cases.

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

# Performance and legacy routing follow-up

22 October 2026. Public website only; private-workspace implementation remains deferred.

## Changes

- Added 768px card/equipment photographs between the existing 480px and 960px
  WebPs. Sources, quality, visible crop and the representative-image wording
  are unchanged. `sizes` now follows the actual one/two/three-column layouts.
  The equipment explorer retains all variants when visitors change its tab.
- Combined the three stylesheets into one generated CSS file, retaining their
  original cascade order and relative font URLs. A hash of the combined content
  names the file, so later style changes cannot reuse a stale CSS URL.
- JavaScript query versions also come from the script contents, so caches
  revalidate an updated equipment explorer instead of keeping a manual version.
- Preloaded Playfair Italic on the homepage, removing the stylesheet-to-font
  discovery delay measured in the previous audit. Other pages do not preload
  an unused accent font.
- Corrected legacy redirect patterns to handle Vercel's trailing-slash
  normalization. Host aliases match slash and asset paths and use literal host
  names. No main-domain catch-all redirect or homepage fallback is introduced.
- Expanded the live review to 32 checks, including legacy root/nested/query,
  asset and unknown-route cases. Unknown routes retain a real 404.

## Evidence before deployment

Vercel's own `@vercel/routing-utils` 6.6.0 reproduces the previous strict-matching
failure for a slash-terminated quote path. Compiling the revised config passes
root, nested-page, query-string and asset cases, plus alias and primary-domain
loop checks. The tool is used outside the repository; deployment gains no Node
dependency or runtime function.

Production/preview packaging checks and the browser brand suite pass locally.
The browser suite verifies actual selected images in fresh contexts: 480px for
a 1440px desktop at DPR 1, and 768px for a 390px phone at DPR 1.75. It also checks
that the homepage requests one stylesheet and preloads the headline font.

Across the eight service photographs, the selected files total **107,248 bytes**
on that desktop profile and **214,346 bytes** on that phone profile, compared
with **303,892 bytes** for the old 960px selection: approximately 65% and 29%
less image data respectively. These are image-file totals, not reductions in
the entire page's transfer size. Gzip of the combined CSS measures 10,407 bytes
versus 11,689 bytes for three separately compressed stylesheets, with two fewer
stylesheet requests. Actual CDN compression and cache behaviour may differ.

All 32 live HTTP checks now pass, including the six legacy-prefix cases that
previously failed. The code deployment reported completed in Vercel.

The previous live review scores remain in `launch-review.md`. Cookie choices,
motion preferences and the normal application remain enabled during audits.

The manual **Production Lighthouse review** workflow checks the live domain
and redirects, then audits Home, Solutions and Quote on mobile and Home on
desktop using Lighthouse 13.5.0 on a separate GitHub-hosted runner. Scores,
measurement warnings, metrics and full HTML/JSON reports are saved as a
14-day Actions artifact. It uses no account secrets, sends no form submissions
and does not bypass normal consent or motion behaviour.

## Deployed verification and Lighthouse results

Functional source revision: `15ebc5904f4942d738db5e9d814c678308d9fab5`.
[Both CI jobs](https://github.com/luteratech/LUTERA-TECHNOLOGIES/actions/runs/39797265412)
pass, including all four browser suites. They also pass locally. The final live
HTTP review passes all 32 checks. Focused fresh browser contexts on production
confirm the actual 480px desktop and 768px phone selections, one stylesheet,
the headline-font preload and script URLs versioned by their contents. Every
new image was fetched and its WebP bytes verified successfully. A first attempt
at the full remote brand suite timed out waiting for images; local/CI full
suites and the focused live checks passed without application changes.

[Production audit run 39798289066](https://github.com/luteratech/LUTERA-TECHNOLOGIES/actions/runs/39798289066)
completed successfully against `https://luteratech.com`. Lighthouse 13.5.0,
Chrome 156, GitHub-hosted Ubuntu; standard simulated mobile throttling with
4x CPU slowdown and the standard desktop preset. All reports have **no runtime
measurement warnings**. A machine-readable summary is in
[`lighthouse-latest.json`](lighthouse-latest.json).

| Page/profile | Performance | Accessibility | Best practices | SEO | LCP | Blocking time | Layout shift |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Home/mobile | 93 | 100 | 100 | 100 | 1.8s | 260ms | 0 |
| Solutions/mobile | 100 | 100 | 100 | 100 | 1.2s | 0ms | 0 |
| Quote/mobile | 95 | 100 | 100 | 100 | 1.6s | 240ms | 0 |
| Home/desktop | 100 | 100 | 100 | 100 | 0.4s | 0ms | 0 |

These are single-run lab measurements, not field Core Web Vitals or guaranteed
rankings. Earlier measurements used a different, CPU-constrained machine and
Chrome version, so the full score difference cannot be attributed solely to
the code changes. The image byte reductions and stylesheet request reductions
are independently verified. Full HTML/JSON reports are retained in the Actions
artifact for 14 days and downloaded to the session's review folder.

## Remaining work requiring the owner

The owner confirms Google Search Console and Bing Webmaster verification are
not yet complete. Add `luteratech.com` as a Google Domain property, publish its
generated verification TXT record in Cloudflare, then verify and submit
`https://luteratech.com/sitemap.xml`. Import the verified property into Bing or
follow Bing's verification flow. Public HTML verification tags can be added if
provided; no account secrets are needed in the repository.

Actual inbox delivery, project evidence and warranty details remain as listed
in `launch-review.md`. Private administration, invoices, receipts and staff cards
remain deferred and are not deployed by this work.

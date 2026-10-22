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

The previous live review scores remain in `launch-review.md`. Fresh deployed
measurements will be recorded after release; no Lighthouse score improvement is
assumed from these byte savings. Cookie choices, motion preferences and the
normal application remain enabled during audits.

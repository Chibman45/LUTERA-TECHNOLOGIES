# Vercel-only deployment

Updated 22 October 2026. Vercel is the only supported website host. GitHub retains
the source and CI checks; the GitHub Pages publishing workflow is removed.
The owner imported the repository into Vercel and connected the custom domains.
The approved production address is `https://luteratech.com/`. Subsequent pushes
to the connected production branch deploy through Vercel's Git integration.

## Repository transfer

Current repository: https://github.com/luteratech/LUTERA-TECHNOLOGIES

Transferred from `Chibman45/LUTERA-TECHNOLOGIES`. GitHub confirms the same
repository ID, `1422065710`, and the existing commit history is retained.
The working checkout's `origin` remote now points at the organization repository.
Other existing checkouts can update their remote with:

```sh
git remote set-url origin https://github.com/luteratech/LUTERA-TECHNOLOGIES.git
```

The repository transfer retained its existing history. Do not re-enable GitHub
Pages or add a Pages publisher. Deployment is handled by Vercel’s Git integration.
If an old copy is still published, the repository owner can unpublish it under
**Settings → Pages → Unpublish site**. The connected app can disable the workflow
but the Pages deletion API requires both Pages and Administration write permissions.

## Import into Vercel

Authorize Vercel's GitHub integration to access the repository in
the **luteratech** organization, then import that repository into the intended
Vercel account/team. Select `main` as the production branch.

The committed `vercel.json` supplies these settings:

| Setting | Value |
| --- | --- |
| Framework preset | Other / no framework |
| Root directory | Repository root (`.`) |
| Install command | None |
| Build command | `python3 scripts/build_vercel.py` |
| Output directory | `_site` |
| Trailing slashes | Enabled |

The build uses Python's standard library. No Node package install, database or
private application credentials are required. Use Vercel's Git integration for
push deployments; no Vercel token needs to be stored in GitHub Actions.

The canonical origin comes from `SITE_ORIGIN` when explicitly set, otherwise
`hosting.production_origin` in `content/site.json` (`https://luteratech.com`).
For an unconfigured copy of this project, Vercel's system hostname variables
remain fallbacks. The build rejects an invalid origin rather than publishing
GitHub URLs on Vercel. `SITE_ORIGIN` is a public website origin, not a password.

Connect `luteratech.com` to the project's Production environment. Do not redirect
it to `luterawebsite.vercel.app`. Remove any obsolete `SITE_ORIGIN` value pointing
to a deployment hostname, or set it to `https://luteratech.com` and redeploy.
The host-specific permanent rules in `vercel.json` direct `www.luteratech.com`,
`luteratech.com.ng` and `www.luteratech.com.ng` to the primary domain, preserving
paths and query strings. All aliases must be attached to this Vercel project
with valid DNS/HTTPS; repository rules cannot provision domains or certificates.
Avoid conflicting domain-level redirects in Vercel or Cloudflare.

## What the Vercel build changes

- Links, assets and the hero-image manifest use `/` instead of the GitHub project prefix.
- Canonicals, structured data, social images, sitemap and production form returns
  use the resolved production origin.
- Preview builds retain production canonicals, mark every page `noindex`, publish
  an empty sitemap and omit its robots advertisement. Preview form returns point
  to the preview deployment when `VERCEL_URL` is available.
- Both forms keep their existing FormSubmit recipient, fields and native HTTPS POST.
- The privacy notice identifies Vercel as the hosting provider.
- Only public pages/assets are packaged. Source, content files, documentation,
  tests, environment files and private records are not served from `_site`.
- Legacy `/LUTERA-TECHNOLOGIES/...` migration rules cover both slash-terminated
  page paths and extension-bearing assets. Vercel normalizes trailing slashes
  before matching strict redirect patterns; both forms must be handled. The
  live review now probes root, nested, query, asset and missing-path cases.
  These rules cannot redirect requests arriving at GitHub's old hostname.
- Unknown routes use the static `404.html`; there is no catch-all homepage rewrite.

The builder stages its work in a temporary directory. Committed legacy HTML
snapshots are not the deployment output; Vercel serves only the freshly generated
`_site` directory.

## Verification

```sh
python tests/build_vercel.py
python scripts/build_vercel.py
python -m http.server 8000 --directory _site
```

Open http://localhost:8000/ for a local root-hosted preview. Test both forms with
intercepted requests so test messages are not sent to the business inbox. Check
the eight service links, enquiry list, quote steps, consent, hero, mobile menu,
unknown-route response and legacy redirects on the actual Vercel deployment
after any deployment or domain change. For a reproducible, read-only live check:

```sh
python scripts/review_live.py --output /tmp/lutera-live-review.json
```

This checks all 19 pages, final-domain SEO and native form destinations, sitemap,
robots, IndexNow token, a real unknown-route 404, permanent alias redirects
with a quote path/query, and six legacy-prefix cases. It performs no form submission. Browser suites separately
verify interactions with intercepted email requests. See `launch-review.md` for
the current release status and remaining owner checks.

Production/preview packaging and root-hosted browser checks run in GitHub Actions.
Browser tests default to the built `_site` directory at `/`. Suites also accept
`LUTERA_TEST_URL` for testing another served deployment.

The private admin workspace, invoice/receipt tools, staff-card generators and
document exports remain outside this public-site preparation.

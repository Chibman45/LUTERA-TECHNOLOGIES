# Organization transfer and Vercel deployment

Prepared 22 October 2026. The public static site has Vercel build configuration;
no Vercel production deployment or custom-domain change has been made.

## Repository transfer

Current repository: https://github.com/luteratech/LUTERA-TECHNOLOGIES

Transferred from `Chibman45/LUTERA-TECHNOLOGIES`. GitHub confirms the same
repository ID, `1422065710`, and the existing commit history is retained.
The working checkout's `origin` remote now points at the organization repository.
Other existing checkouts can update their remote with:

```sh
git remote set-url origin https://github.com/luteratech/LUTERA-TECHNOLOGIES.git
```

GitHub redirects transferred repository URLs, but GitHub Pages website addresses
are separate. The expected organization review address after a successful Pages
deployment is https://luteratech.github.io/LUTERA-TECHNOLOGIES/.
The build derives its Pages origin from `GITHUB_REPOSITORY_OWNER` in Actions,
so metadata, sitemap and form returns follow the new owner on the next build.
Keep the Pages workflow until the replacement hosting is verified.

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

Expose Vercel's system environment variables to the build. The canonical origin
comes from `SITE_ORIGIN` when explicitly set, otherwise
`https://` + `VERCEL_PROJECT_PRODUCTION_URL`. A production-only fallback uses
`VERCEL_URL`. The build rejects a missing/invalid origin rather than publishing
GitHub URLs on Vercel. `SITE_ORIGIN` is a public website origin, not a password.

Do not set `SITE_ORIGIN` to a purchased domain before connecting and verifying
that domain. Initially use Vercel's actual assigned production address. Later,
set `SITE_ORIGIN=https://luteratech.com` as part of the approved domain cutover,
and rebuild. Custom domains and the `.com.ng` redirect remain deferred.

## What the Vercel build changes

- Links, assets and the hero-image manifest use `/` instead of the GitHub project prefix.
- Canonicals, structured data, social images, sitemap and production form returns
  use the resolved production origin.
- Preview builds retain production canonicals, mark every page `noindex`, publish
  an empty sitemap and omit its robots advertisement. Preview form returns point
  to the preview deployment when `VERCEL_URL` is available.
- Both forms keep their existing FormSubmit recipient, fields and native HTTPS POST.
- The privacy notice identifies Vercel as the hosting provider in Vercel builds;
  GitHub Pages builds continue identifying GitHub Pages.
- Only public pages/assets are packaged. Source, content files, documentation,
  tests, environment files and private records are not served from `_site`.
- Legacy `/LUTERA-TECHNOLOGIES/...` paths on the Vercel hostname redirect to their
  root-hosted equivalents. This cannot redirect requests arriving at GitHub's old hostname.
- Unknown routes use the static `404.html`; there is no catch-all homepage rewrite.

The Vercel builder stages its work in a temporary directory. It never rewrites
the committed GitHub Pages pages or sitemap.

## Verification

```sh
python tests/build_vercel.py
SITE_ORIGIN=https://your-assigned-production-host.vercel.app python scripts/build_vercel.py
python -m http.server 8000 --directory _site
```

Open http://localhost:8000/ for a local root-hosted preview. Test both forms with
intercepted requests so test messages are not sent to the business inbox. Check
the eight service links, enquiry list, quote steps, consent, hero, mobile menu,
unknown-route response and legacy redirects on the actual Vercel deployment
before assigning custom domains or retiring GitHub Pages.

Production/preview packaging checks run in GitHub Actions, alongside browser
matrices for GitHub Pages and Vercel root hosting. To run the root-hosted browser
checks locally against the built artifact, set `LUTERA_TEST_DIR=_site` and
`LUTERA_TEST_BASE=/`. Suites also accept `LUTERA_TEST_URL` for testing another
served deployment.

The private admin workspace, invoice/receipt tools, staff-card generators and
document exports remain outside this public-site preparation.

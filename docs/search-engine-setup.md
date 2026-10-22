# Search engine ownership and indexing

The site is public and can be crawled without a login. Automated SEO checks do not prove that a search engine has indexed the site or that a particular ranking will follow. The owner confirmed that Google Search Console and Bing Webmaster Tools have not been set up yet.

## Google Search Console

1. Sign in at [Google Search Console](https://search.google.com/search-console/).
2. Add a **URL-prefix** property using the exact address `https://luteratech.github.io/LUTERA-TECHNOLOGIES/`. The shared `github.io` domain is not a domain that LUTERA can verify through DNS.
3. Choose **HTML tag** under ownership verification and copy the `content` value from Google's `google-site-verification` meta tag.
4. Send that meta tag to Codex, or add its content value as the GitHub repository Actions variable `GOOGLE_SITE_VERIFICATION`. The deployment workflow reads the variable; it is a public ownership token, not a password. Re-run the **Deploy LUTERA to GitHub Pages** workflow, check the tag in the homepage source, then click **Verify** in Search Console.
5. Open **Sitemaps** and submit `https://luteratech.github.io/LUTERA-TECHNOLOGIES/sitemap.xml`.
6. Use **URL Inspection** for the homepage and the four new service pages. If eligible, select **Request indexing**. Check the Pages and Performance reports as Google collects data.

Keep the ownership tag in place after verification. No Google account or verified Search Console property was created by this code update. The site does not need Analytics or advertising scripts to verify ownership.

## Bing Webmaster Tools

1. Sign in at [Bing Webmaster Tools](https://www.bing.com/webmasters/).
2. Add the same site URL. You can use its Google Search Console import when offered, or its HTML meta-tag verification method.
3. For the meta-tag method, send the `msvalidate.01` meta tag to Codex, or save its content as the GitHub Actions variable `BING_SITE_VERIFICATION`, redeploy, then complete verification in Bing.
4. Submit the same sitemap and review Bing's crawl/indexing reports.

## IndexNow notifications

After a successful Pages deployment, the workflow sends only the public URLs in `sitemap.xml` to the IndexNow endpoint. `indexnow.txt` hosts the protocol's validation token at an explicit keyLocation under this project's path. It does not grant access to a Google or Bing account and does not claim the rest of the shared GitHub Pages hostname. The dry-run check validates the payload without contacting an engine.

An HTTP 200 response means the notification was received; HTTP 202 means receipt with key validation pending. Neither response proves crawling, indexing or ranking. Temporary notification failures do not fail or roll back the website deployment. Check the workflow step's log for the actual receipt. Google Search Console setup remains a separate owner action.

## robots.txt on a GitHub project site

The project publishes `/LUTERA-TECHNOLOGIES/robots.txt`. Search engines obtain the authoritative file at the hostname root, `https://luteratech.github.io/robots.txt`. A missing robots file does **not** block crawling. A project-path robots file does not replace a root robots file; submit the sitemap directly in the verified tools above. This update does not create or alter a separate root-domain repository.

## What improves discovery over time

Keep your company name, Abuja address and contact information consistent in accurate business listings and relevant links to the site. Keep service pages useful and current. A verified Google Business Profile may be useful if your business meets its eligibility requirements. Search engines control indexing and ranking; no Lighthouse score guarantees placement.

Sources: [Google SEO Starter Guide](https://developers.google.com/search/docs/fundamentals/seo-starter-guide), [ownership verification](https://support.google.com/webmasters/answer/9008080), [sitemap guidance](https://developers.google.com/search/docs/crawling-indexing/sitemaps/build-sitemap), [robots.txt guidance](https://developers.google.com/search/docs/crawling-indexing/robots/intro), [IndexNow protocol](https://www.indexnow.org/documentation).

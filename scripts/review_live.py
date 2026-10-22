"""Read-only release checks against the deployed public website. Never submit forms."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import urljoin, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener
import argparse
import json
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SITE = json.loads((ROOT / 'content/site.json').read_text())


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def fetch(url):
    request = Request(url, headers={'User-Agent': 'Lutera public launch review/1.0'})
    try:
        response = build_opener(NoRedirect).open(request, timeout=20)
    except HTTPError as error:
        response = error
    with response:
        return response.status, response.headers, response.read().decode('utf-8')


class Head(HTMLParser):
    def __init__(self):
        super().__init__()
        self.canonicals, self.returns, self.schemas, self.forms = [], [], [], []
        self.meta, self.schema, self.in_schema = {}, '', False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'link' and attrs.get('rel') == 'canonical':
            self.canonicals.append(attrs.get('href'))
        if tag == 'meta':
            self.meta[attrs.get('name', attrs.get('property'))] = attrs.get('content', '')
        if tag == 'input' and attrs.get('name') == '_next':
            self.returns.append(attrs.get('value'))
        if tag == 'form':
            self.forms.append(attrs)
        if tag == 'script' and attrs.get('type') == 'application/ld+json':
            self.schema, self.in_schema = '', True

    def handle_data(self, data):
        if self.in_schema:
            self.schema += data

    def handle_endtag(self, tag):
        if tag == 'script' and self.in_schema:
            self.schemas.append(json.loads(self.schema))
            self.in_schema = False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--origin', default=SITE['hosting']['production_origin'])
    parser.add_argument('--skip-aliases', action='store_true', help='Review a direct production deployment before domain cutover.')
    parser.add_argument('--output', type=Path, help='Save JSON outside the public artifact.')
    args = parser.parse_args()
    origin = args.origin.rstrip('/')
    parsed = urlsplit(origin)
    if parsed.scheme != 'https' or not parsed.hostname or parsed.path or parsed.query or parsed.fragment or parsed.username:
        parser.error('Use an HTTPS origin with no path, query or credentials.')
    routes = ['/', '/about/', '/services/', '/solutions/', '/contact/', '/request-quote/',
              '/privacy/', '/terms/', '/cookies/', '/thank-you/', '/404.html']
    routes += ['/services/' + item['slug'] + '/' for item in SITE['services']]
    indexed = {origin + route for route in routes if route not in ('/thank-you/', '/404.html')}

    def page_check(route):
        failures = []
        url = origin + route
        try:
            status, headers, body = fetch(url)
            # A direct request for the static error document may return 200;
            # the unknown-route probe below must return a genuine 404.
            allowed_status = (200, 404) if route == '/404.html' else (200,)
            if status not in allowed_status:
                failures.append(f'HTTP {status}; expected {allowed_status}; location={headers.get("Location", "")}')
            page = Head(); page.feed(body)
            if page.canonicals != [url]:
                failures.append(f'canonical={page.canonicals}')
            if page.meta.get('og:url') != url:
                failures.append('social URL does not match the final domain')
            if page.meta.get('og:image') != origin + '/assets/social.png':
                failures.append('social image does not use the final domain')
            excluded = url not in indexed
            if ('noindex' in page.meta.get('robots', '')) != excluded:
                failures.append('incorrect page indexing policy')
            if not excluded and any(word in headers.get('X-Robots-Tag', '').lower() for word in ('noindex', 'none')):
                failures.append('hosting layer blocks indexing')
            graph = [node for schema in page.schemas for node in schema.get('@graph', [])]
            for kind in ('Organization', 'WebSite'):
                if not any(node.get('@type') == kind and node.get('url') == origin + '/' for node in graph):
                    failures.append(f'{kind} schema missing or using another origin')
            expected_forms = 1 if route in ('/contact/', '/request-quote/') else 0
            if len(page.forms) != expected_forms or page.returns != [origin + '/thank-you/'] * expected_forms:
                failures.append('incorrect form count or return URL')
            for form in page.forms:
                if form.get('method', '').upper() != 'POST' or form.get('action') != 'https://formsubmit.co/' + SITE['company']['email']:
                    failures.append('unexpected enquiry transport')
        except (OSError, ValueError) as error:
            failures.append(str(error))
        return {'url': url, 'passed': not failures, 'failures': failures}

    with ThreadPoolExecutor(max_workers=4) as pool:
        checks = list(pool.map(page_check, routes))
    for path in ('/sitemap.xml', '/robots.txt', '/indexnow.txt', '/launch-check-missing-route/'):
        failures = []
        try:
            status, _, body = fetch(origin + path)
            expected = 404 if 'missing-route' in path else 200
            if status != expected:
                failures.append(f'HTTP {status}; expected {expected}')
            if path == '/sitemap.xml':
                urls = [node.text for node in ET.fromstring(body).findall('.//{*}loc')]
                if len(urls) != len(indexed) or set(urls) != indexed:
                    failures.append('sitemap does not contain exactly the 17 final-domain indexable pages')
            elif path == '/robots.txt':
                if f'Sitemap: {origin}/sitemap.xml' not in body or 'Disallow: /' in body:
                    failures.append('incorrect robots policy or sitemap address')
            elif path == '/indexnow.txt' and body.strip() != (ROOT / 'indexnow.txt').read_text().strip():
                failures.append('public IndexNow token differs from repository')
        except (OSError, ValueError, ET.ParseError) as error:
            failures.append(str(error))
        checks.append({'url': origin + path, 'passed': not failures, 'failures': failures})
    if not args.skip_aliases:
        for alias in SITE['hosting']['redirect_origins']:
            probe = '/request-quote/?need=infrastructure'
            current, chain, failures = alias + probe, [], []
            try:
                for _ in range(5):
                    status, headers, _ = fetch(current)
                    chain.append({'url': current, 'status': status})
                    if current == origin + probe and status == 200:
                        break
                    if status not in (301, 308) or not headers.get('Location'):
                        failures.append('expected a permanent redirect to the primary domain, preserving path and query')
                        break
                    target = urljoin(current, headers['Location'])
                    if urlsplit(target).netloc not in {urlsplit(origin).netloc, urlsplit(alias).netloc} or urlsplit(target).scheme != 'https':
                        failures.append('redirect leaves the approved primary/alias hosts')
                        break
                    current = target
                else:
                    failures.append('redirect loop or too many hops')
            except (OSError, ValueError) as error:
                failures.append(str(error))
            checks.append({'url': alias + probe, 'passed': not failures, 'failures': failures, 'chain': chain})
    report = {'reviewed_at': datetime.now(timezone.utc).isoformat(), 'origin': origin,
              'passed': all(check['passed'] for check in checks), 'checks': checks,
              'scope': 'Read-only public HTTP/SEO checks. No forms submitted; no inbox delivery or search-account verification performed.'}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + '\n')
    for check in checks:
        print(('PASS ' if check['passed'] else 'FAIL ') + check['url'] + (': ' + '; '.join(check['failures']) if check['failures'] else ''))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())

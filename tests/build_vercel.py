"""Exercise production/preview packaging without deploying or sending email."""
from hashlib import sha256
from html.parser import HTMLParser
from pathlib import Path
import json
import os
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / '_site'


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.canonical = None
        self.robots = None
        self.returns = []
        self.forms = []

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if tag == 'link' and attrs.get('rel') == 'canonical':
            self.canonical = attrs['href']
        if tag == 'meta' and attrs.get('name') == 'robots':
            self.robots = attrs['content']
        if tag == 'input' and attrs.get('name') == '_next':
            self.returns.append(attrs['value'])
        if tag == 'form':
            self.forms.append(attrs)


source_files = [p for p in ROOT.rglob('*.html') if not {'_site','.git','node_modules','.next','apps'} & set(p.parts)]
source_files += [ROOT / 'sitemap.xml', ROOT / 'robots.txt']
before = {p: sha256(p.read_bytes()).hexdigest() for p in source_files}
environment = dict(os.environ)
environment['LUTERA_CONTENT_SOURCE'] = 'repository'
for key in ('SITE_BASE', 'SITE_ORIGIN', 'FORM_ORIGIN', 'SITE_NOINDEX',
            'VERCEL_ENV', 'VERCEL_URL', 'VERCEL_PROJECT_PRODUCTION_URL'):
    environment.pop(key, None)


def check(settings, canonical, callback, preview):
    subprocess.run([sys.executable, 'scripts/build_vercel.py'], cwd=ROOT,
                   env=dict(environment, **settings), check=True)
    pages = list(OUTPUT.rglob('*.html'))
    assert len(pages) == 19
    assert not any((OUTPUT / name).exists() for name in ('scripts', 'content', 'docs', 'tests', '.git', '.env', 'vercel.json', 'apps', 'supabase', 'node_modules'))
    form_count = 0
    for path in pages:
        html = path.read_text()
        assert '/LUTERA-TECHNOLOGIES/' not in html, path
        page = Page(); page.feed(html)
        relative = path.relative_to(OUTPUT).as_posix()
        route = '' if relative == 'index.html' else relative.removesuffix('index.html')
        assert page.canonical == canonical + '/' + route, (relative, page.canonical)
        excluded = preview or relative in ('404.html', 'thank-you/index.html')
        assert ('noindex' in page.robots) == excluded, path
        for form in page.forms:
            assert form['action'] == 'https://workspace.luteratech.com/api/enquiry'
            assert form['method'].upper() == 'POST'
        assert len(page.returns) == len(page.forms)
        assert all(url == callback + '/thank-you/' for url in page.returns)
        form_count += len(page.forms)
    assert form_count == 2
    assert 'Vercel serves this website' in (OUTPUT / 'privacy/index.html').read_text()
    assert '{{hosting_provider}}' not in (OUTPUT / 'privacy/index.html').read_text()
    urls = [node.text for node in ET.parse(OUTPUT / 'sitemap.xml').findall('.//{*}loc')]
    assert len(urls) == (0 if preview else 17)
    assert all(url.startswith(canonical + '/') for url in urls)
    assert ('Sitemap:' in (OUTPUT / 'robots.txt').read_text()) != preview
    assert before == {p: sha256(p.read_bytes()).hexdigest() for p in source_files}


check({'VERCEL_ENV': 'production', 'VERCEL_PROJECT_PRODUCTION_URL': 'luterawebsite.vercel.app',
       'VERCEL_URL': 'production-deployment.example'},
      'https://luteratech.com', 'https://luteratech.com', False)
check({'VERCEL_ENV': 'preview', 'VERCEL_PROJECT_PRODUCTION_URL': 'luterawebsite.vercel.app',
       'VERCEL_URL': 'lutera-preview.example'},
      'https://luteratech.com', 'https://lutera-preview.example', True)
check({'VERCEL_ENV': 'production', 'SITE_ORIGIN': 'https://lutera-build.example',
       'VERCEL_PROJECT_PRODUCTION_URL': 'unused-production.example',
       'VERCEL_URL': 'production-deployment.example', 'SITE_BASE': '/obsolete/'},
      'https://lutera-build.example', 'https://lutera-build.example', False)
check({'VERCEL_ENV': 'preview', 'SITE_ORIGIN': 'https://lutera-canonical.example',
       'VERCEL_PROJECT_PRODUCTION_URL': 'unused-production.example',
       'VERCEL_URL': 'lutera-preview.example'},
      'https://lutera-canonical.example', 'https://lutera-preview.example', True)
for settings in ({'SITE_ORIGIN': 'https://example.com/not-an-origin/'},
                 {'SITE_ORIGIN': 'https://user:password@example.com'}):
    result = subprocess.run([sys.executable, 'scripts/build_vercel.py'], cwd=ROOT,
                            env=dict(environment, **settings), capture_output=True)
    assert result.returncode != 0
assert before == {p: sha256(p.read_bytes()).hexdigest() for p in source_files}
configuration = json.loads((ROOT / 'vercel.json').read_text())
assert configuration['outputDirectory'] == '_site' and configuration['trailingSlash']
assert configuration['framework'] is None
print('PASS Vercel production/preview builds: 19 root-hosted pages, 17 production sitemap URLs, '
      'preview noindex, canonical/callback separation, unchanged email transport, public-only '
      'artifact, invalid-origin rejection, unchanged source files.')

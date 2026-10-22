"""Build the root-hosted Vercel artifact from shared sources."""
from pathlib import Path
from urllib.parse import urlsplit
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / '_site'
PUBLIC_FILES = ('index.html', '404.html', 'robots.txt', 'sitemap.xml', 'indexnow.txt')
PUBLIC_DIRS = ('assets', 'about', 'contact', 'cookies', 'privacy', 'request-quote',
               'services', 'solutions', 'terms', 'thank-you')


def origin(value):
    parsed = urlsplit(value)
    if (parsed.scheme != 'https' or not parsed.hostname or parsed.username or
            parsed.password or parsed.path not in ('', '/') or parsed.query or
            parsed.fragment or not re.fullmatch(r'[A-Za-z0-9.-]+(?::[0-9]+)?', parsed.netloc)):
        raise ValueError('Use an HTTPS origin without a path, query or credentials.')
    return value.rstrip('/')


def build():
    preview = os.environ.get('VERCEL_ENV') == 'preview'
    canonical = os.environ.get('SITE_ORIGIN')
    if not canonical:
        host = os.environ.get('VERCEL_PROJECT_PRODUCTION_URL')
        if not host and os.environ.get('VERCEL_ENV') == 'production':
            host = os.environ.get('VERCEL_URL')
        if not host:
            raise ValueError('Set SITE_ORIGIN or expose VERCEL_PROJECT_PRODUCTION_URL in Vercel.')
        canonical = 'https://' + host
    canonical = origin(canonical)
    callback = origin('https://' + os.environ['VERCEL_URL']) if preview and os.environ.get('VERCEL_URL') else canonical
    environment = dict(os.environ, SITE_BASE='/', SITE_ORIGIN=canonical,
                       FORM_ORIGIN=callback, SITE_NOINDEX='1' if preview else '0')
    with tempfile.TemporaryDirectory(prefix='lutera-vercel-') as temporary:
        stage = Path(temporary)
        for name in ('scripts', 'content', 'assets'):
            shutil.copytree(ROOT / name, stage / name,
                            ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
        shutil.copy2(ROOT / 'indexnow.txt', stage / 'indexnow.txt')
        for script in ('build.py', 'check.py', 'check_seo.py'):
            subprocess.run([sys.executable, str(stage / 'scripts' / script)],
                           cwd=stage, env=environment, check=True)
        # Publish only generated pages/assets, never source, settings or records.
        if OUTPUT.exists():
            shutil.rmtree(OUTPUT)
        OUTPUT.mkdir()
        for name in PUBLIC_FILES:
            shutil.copy2(stage / name, OUTPUT / name)
        for name in PUBLIC_DIRS:
            shutil.copytree(stage / name, OUTPUT / name)
    print(f'Vercel artifact: {OUTPUT.name}/; canonical: {canonical}/; preview: {preview}')


if __name__ == '__main__':
    build()

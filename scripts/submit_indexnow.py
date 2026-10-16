"""Notify IndexNow engines after deployment; only public sitemap URLs are sent.

The validation token is intentionally published at keyLocation. It is not an
account credential. The nested keyLocation confines notifications to this site.
"""
from pathlib import Path
from urllib.request import Request,urlopen
from urllib.parse import urlsplit
import xml.etree.ElementTree as ET
import json,re,sys
ROOT=Path(__file__).resolve().parents[1]
urls=[node.text for node in ET.parse(ROOT/'sitemap.xml').findall('.//{*}loc')]
home=urls[0];key=(ROOT/'indexnow.txt').read_text().strip()
assert home.startswith('https://') and home.endswith('/')
assert re.fullmatch('[A-Za-z0-9-]{8,128}',key)
assert urls and len(urls)<=10000 and len(urls)==len(set(urls))
assert all(url.startswith(home) and urlsplit(url).hostname==urlsplit(home).hostname for url in urls)
payload={'host':urlsplit(home).hostname,'key':key,'keyLocation':home+'indexnow.txt','urlList':urls}
if '--submit' not in sys.argv:
 print(f'PASS: IndexNow payload validated for {len(urls)} public URLs within {home}; no notification sent.')
 raise SystemExit(0)
# Check the deployed key before asking engines to validate it.
with urlopen(Request(payload['keyLocation'],headers={'User-Agent':'LUTERA sitemap notification'}),timeout=30) as response:
 assert response.read().decode().strip()==key,'The deployed validation token differs; retry after publication.'
request=Request('https://api.indexnow.org/indexnow',data=json.dumps(payload).encode(),headers={'Content-Type':'application/json; charset=utf-8','User-Agent':'LUTERA sitemap notification'},method='POST')
with urlopen(request,timeout=30) as response:
 receipt={'endpoint':'https://api.indexnow.org/indexnow','status':response.status,'url_count':len(urls),'scope':home,'meaning':'Notification received; key validation pending.' if response.status==202 else 'Notification received. This is not proof of indexing.'}
 assert response.status in [200,202],receipt
 print(json.dumps(receipt))

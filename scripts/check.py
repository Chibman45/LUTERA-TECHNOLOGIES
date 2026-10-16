from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit,unquote
ROOT=Path(__file__).resolve().parents[1]
errors=[]
class Check(HTMLParser):
 def __init__(self,file):super().__init__();self.file=file;self.ids=[];self.refs=[];self.h1=0
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if 'id' in a:self.ids.append(a['id'])
  if tag=='h1':self.h1+=1
  if tag=='img' and 'alt' not in a:errors.append(f'{self.file}: image missing alt')
  for key in ('href','src'):
   u=a.get(key,'')
   if not u or u.startswith(('#','https:','http:','mailto:','tel:')):continue
   path=unquote(urlsplit(u).path)
   if path.startswith('/LUTERA-TECHNOLOGIES/'):path=path[len('/LUTERA-TECHNOLOGIES/'):]
   target=ROOT/path
   if target.is_dir():target=target/'index.html'
   if not target.exists():errors.append(f'{self.file}: missing {u}')
for f in ROOT.rglob('*.html'):
 c=Check(f.relative_to(ROOT));c.feed(f.read_text())
 if c.h1!=1:errors.append(f'{f}: expected one h1')
 if len(c.ids)!=len(set(c.ids)):errors.append(f'{f}: duplicate IDs')
assert not errors,'\n'.join(errors)
print('PASS: internal links, assets, image alt text, unique IDs and page headings across all HTML pages')

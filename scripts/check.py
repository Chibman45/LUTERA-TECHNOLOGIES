from pathlib import Path
from html.parser import HTMLParser
import json
from urllib.parse import urlsplit,unquote
ROOT=Path(__file__).resolve().parents[1]
errors=[]
class Check(HTMLParser):
 def __init__(self,file):super().__init__();self.file=file;self.ids=[];self.refs=[];self.h1=0;self.heading_level=0;self.hero_manifest=False;self.script_text=''
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if tag=='script' and a.get('id')=='hero-scenes':self.hero_manifest=True;self.script_text=''
  if 'id' in a:self.ids.append(a['id'])
  if tag=='h1':self.h1+=1
  if tag in ['h1','h2','h3','h4','h5','h6']:
   level=int(tag[1])
   if level>self.heading_level+1:errors.append(f'{self.file}: heading skips from h{self.heading_level} to {tag}')
   self.heading_level=level
  if tag=='img' and 'alt' not in a:errors.append(f'{self.file}: image missing alt')
  for key in ('href','src','srcset'):
   u=a.get(key,'')
   if key=='srcset':
    for entry in u.split(','):
     asset=entry.strip().split(' ')[0].removeprefix('/LUTERA-TECHNOLOGIES/').lstrip('/')
     if asset and not (ROOT/asset).exists():errors.append(f'{self.file}: missing responsive image {asset}')
    continue
   if not u or u.startswith(('#','https:','http:','mailto:','tel:')):continue
   path=unquote(urlsplit(u).path)
   if path.startswith('/LUTERA-TECHNOLOGIES/'):path=path[len('/LUTERA-TECHNOLOGIES/'):]
   target=ROOT/path.lstrip('/')
   if target.is_dir():target=target/'index.html'
   if not target.exists():errors.append(f'{self.file}: missing {u}')
 def handle_data(self,data):
  if self.hero_manifest:self.script_text+=data
 def handle_endtag(self,tag):
  if tag=='script' and self.hero_manifest:
   for scene in json.loads(self.script_text):
    self.handle_starttag('img',{'src':scene['src'],'srcset':scene['srcset'],'alt':''}.items())
   self.hero_manifest=False
for f in ROOT.rglob('*.html'):
 if {'.git','_site','apps','node_modules','.next'} & set(f.parts):continue
 c=Check(f.relative_to(ROOT));c.feed(f.read_text())
 if c.h1!=1:errors.append(f'{f}: expected one h1')
 if len(c.ids)!=len(set(c.ids)):errors.append(f'{f}: duplicate IDs')
assert not errors,'\n'.join(errors)
print('PASS: internal links, assets, image alt text, unique IDs and page headings across all HTML pages')

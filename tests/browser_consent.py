"""Consent behavior on real pages, with no external submissions or tracking."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json, os, shutil, threading
from playwright.sync_api import sync_playwright

ROOT=Path(__file__).resolve().parents[1]
KEY='lutera_cookie_consent_v1'
class Handler(SimpleHTTPRequestHandler):
 def translate_path(self,path):return super().translate_path(path.removeprefix('/LUTERA-TECHNOLOGIES'))
 def log_message(self,*args):pass

server=None
base=os.environ.get('LUTERA_TEST_URL')
if not base:
 server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(ROOT)))
 threading.Thread(target=server.serve_forever,daemon=True).start()
 base=f'http://127.0.0.1:{server.server_port}/LUTERA-TECHNOLOGIES/'

with sync_playwright() as p:
 browser=p.chromium.launch(executable_path=shutil.which('chromium') or None,args=['--no-sandbox'])
 context=browser.new_context(viewport={'width':1440,'height':1000},reduced_motion='reduce')
 page=context.new_page();errors=[];requests=[]
 page.on('pageerror',lambda error:errors.append(str(error)))
 page.on('request',lambda request:requests.append(request.url))
 page.goto(base,wait_until='networkidle')
 panel=page.get_by_role('dialog',name='Cookies & your privacy')
 assert panel.is_visible()
 assert page.evaluate('(key)=>localStorage.getItem(key)',KEY) is None
 assert page.locator('body').evaluate('(e)=>getComputedStyle(e).overflow')!='hidden'
 assert not panel.evaluate('(e)=>e.contains(document.activeElement)'), 'Automatic notice must not steal focus'
 for width,height in [(320,568),(360,740),(390,844),(768,1024),(1024,768),(1440,1000),(568,320)]:
  page.set_viewport_size({'width':width,'height':height})
  rect=panel.bounding_box();contact=page.locator('.floating-contact-toggle').bounding_box()
  assert rect['x']>=0 and rect['x']+rect['width']<=width+1,(width,rect)
  assert rect['y']>=0 and rect['y']+rect['height']<=height,(width,rect)
  assert rect['x']+rect['width']<=contact['x'] or rect['y']+rect['height']<=contact['y'],(width,rect,contact)
  assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
  for label in ['Accept optional','Reject optional']:
   assert page.get_by_role('button',name=label).bounding_box()['height']>=44
  if os.environ.get('LUTERA_CONSENT_SCREENSHOTS') and width in [390,1440]:
   page.screenshot(path=f"{os.environ['LUTERA_CONSENT_SCREENSHOTS']}/consent-{width}.png")
 page.set_viewport_size({'width':1440,'height':1000})
 # Reject works by keyboard, persists across pages/reloads/new tabs, and is reversible.
 page.get_by_role('button',name='Reject optional').focus();page.keyboard.press('Enter')
 assert not panel.is_visible()
 assert 'rejected' in page.locator('#cookie-feedback').inner_text()
 saved=page.evaluate('(key)=>JSON.parse(localStorage.getItem(key))',KEY)
 assert saved['choice']=='rejected' and saved['version']==1
 assert saved['expiresAt']-saved['chosenAt']==180*24*60*60*1000
 assert set(saved)=={'version','choice','chosenAt','expiresAt'}
 assert context.cookies()==[], 'Consent stores only an essential local preference, not cookies'
 page.reload(wait_until='networkidle');assert not panel.is_visible()
 page.goto(base+'solutions/',wait_until='networkidle');assert not panel.is_visible()
 page.locator('[data-cookie-settings]').click()
 assert panel.is_visible() and 'rejected' in page.locator('#cookie-current').inner_text()
 assert page.get_by_role('button',name='Accept optional').evaluate('(e)=>e===document.activeElement')
 page.keyboard.press('Escape');assert not panel.is_visible()
 assert page.locator('[data-cookie-settings]').evaluate('(e)=>e===document.activeElement')
 page.locator('[data-cookie-settings]').click();page.get_by_role('button',name='Accept optional').click()
 assert page.evaluate('(key)=>JSON.parse(localStorage.getItem(key)).choice',KEY)=='accepted'
 assert not panel.is_visible()
 assert 'No optional cookies' in page.locator('#cookie-feedback').inner_text()
 second=context.new_page();second.goto(base+'contact/',wait_until='networkidle')
 assert not second.locator('#cookie-consent').is_visible()
 # Another tab's withdrawal updates the open settings panel without a reload.
 page.locator('[data-cookie-settings]').click()
 second.locator('[data-cookie-settings]').click();second.get_by_role('button',name='Reject optional').click()
 page.wait_for_function("document.querySelector('#cookie-consent').hidden")
 # Expired, malformed and future-version preferences cannot suppress the notice.
 for value in ['not-json',json.dumps({'version':999,'choice':'accepted'}),json.dumps({'version':1,'choice':'rejected','chosenAt':0,'expiresAt':1})]:
  page.evaluate('([key,value])=>localStorage.setItem(key,value)',[KEY,value])
  page.reload(wait_until='networkidle');assert panel.is_visible()
  page.keyboard.press('Escape');assert panel.is_visible(), 'No implicit first-visit acceptance'
 assert not errors,errors
 assert all(url.startswith(base) for url in requests),requests
 context.close()
 # Blocked browser storage must not break either choice, enquiry lists or navigation.
 for label in ['Accept optional','Reject optional']:
  limited=browser.new_context(reduced_motion='reduce')
  limited.add_init_script("Storage.prototype.getItem=function(){throw new Error('blocked')};Storage.prototype.setItem=function(){throw new Error('blocked')}")
  q=limited.new_page();q.on('pageerror',lambda error:errors.append(str(error)))
  q.goto(base+'solutions/',wait_until='networkidle')
  q.get_by_role('button',name=label).click()
  assert not q.locator('#cookie-consent').is_visible()
  assert 'current page only' in q.locator('#cookie-feedback').inner_text()
  q.locator('[data-add="laptop"]').first.click()
  q.locator('[data-open-enquiry]').first.click();assert q.locator('#enquiry-dialog').is_visible()
  q.keyboard.press('Escape');q.reload(wait_until='networkidle')
  assert q.locator('#cookie-consent').is_visible()
  limited.close()
 assert not errors,errors
 # No JavaScript leaves the policy readable and forms/navigation available.
 nojs=browser.new_context(java_script_enabled=False)
 q=nojs.new_page();q.goto(base+'cookies/')
 assert not q.locator('#cookie-consent').is_visible()
 assert not q.locator('[data-cookie-settings]').is_visible()
 assert '180 days' in q.locator('main').inner_text()
 nojs.close();browser.close()
if server:server.shutdown()
print('PASS first-visit notice, equal choices, responsive layout, keyboard access, 180-day preference, changing/withdrawing consent, cross-tab sync, expiry/invalid storage, blocked storage, no tracking requests and no-JS policy.')

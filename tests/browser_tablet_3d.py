"""Real WebGL checks for large, pointing-device and keyboard-only tablets."""
from pathlib import Path
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from playwright.sync_api import sync_playwright
import os,shutil,threading
ROOT=Path(__file__).resolve().parents[1]
class Handler(SimpleHTTPRequestHandler):
 def translate_path(self,path):return super().translate_path(path.removeprefix('/LUTERA-TECHNOLOGIES'))
 def log_message(self,*args):pass
server=None
base=os.environ.get('LUTERA_TEST_URL')
if not base:
 server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(ROOT)))
 threading.Thread(target=server.serve_forever,daemon=True).start()
 base=f'http://127.0.0.1:{server.server_port}/LUTERA-TECHNOLOGIES/'
ipad='Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'
with sync_playwright() as p:
 browser=p.chromium.launch(executable_path=shutil.which('chromium') or None,args=['--no-sandbox','--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
 profiles=[
  ('large_touch_tablet',dict(viewport={'width':1366,'height':1024},is_mobile=True,has_touch=True,user_agent=ipad),'auto'),
  ('tablet_at_1024',dict(viewport={'width':1024,'height':768},is_mobile=True,has_touch=True,user_agent=ipad),'auto'),
  ('tablet_with_trackpad',dict(viewport={'width':820,'height':1180},user_agent=ipad),'auto'),
  ('keyboard_only_tablet',dict(viewport={'width':820,'height':1180},is_mobile=True,has_touch=True,user_agent=ipad),'keyboard'),
  ('small_touch_tablet',dict(viewport={'width':820,'height':1180},is_mobile=True,has_touch=True,user_agent=ipad),'normal'),
  ('phone_landscape',dict(viewport={'width':1100,'height':600},is_mobile=True,has_touch=True,user_agent='Mozilla/5.0 (Linux; Android 15; Phone) AppleWebKit/537.36 Chrome/140.0 Mobile Safari/537.36'),'normal'),
  ('reduced_motion_tablet',dict(viewport={'width':1366,'height':1024},is_mobile=True,has_touch=True,user_agent=ipad,reduced_motion='reduce'),'normal')]
 for name,options,mode in profiles:
  context=browser.new_context(**options);page=context.new_page();requests=[];errors=[]
  page.on('request',lambda r:requests.append(r.url));page.on('pageerror',lambda e:errors.append(str(e)))
  page.goto(base,wait_until='networkidle')
  if mode=='keyboard':
   assert page.locator('.hardware-scene canvas').count()==0
   page.evaluate("dispatchEvent(new KeyboardEvent('keydown',{key:'Tab'}))")
   assert page.locator('.hardware-scene canvas').count()==0
   page.keyboard.press('Tab')
  if mode!='normal':
   page.wait_for_selector('.scene-loaded canvas',timeout=60000)
   page.get_by_role('button',name='Pause animation').click()
   assert page.get_by_role('button',name='Resume animation').get_attribute('aria-pressed')=='true'
   # A touch swipe must not dispatch an equipment selection.
   page.evaluate("window.equipmentPicks=0;document.addEventListener('equipment-select',()=>window.equipmentPicks++)")
   host=page.locator('[data-hardware-scene]')
   host.dispatch_event('pointerdown',{'pointerType':'touch','clientX':180,'clientY':300})
   host.dispatch_event('pointerup',{'pointerType':'touch','clientX':180,'clientY':380})
   assert page.evaluate('window.equipmentPicks')==0
   assert host.evaluate('(e)=>getComputedStyle(e).touchAction')=='pan-y'
   # The visible server remains pickable in the actual batched WebGL geometry.
   if name=='large_touch_tablet':
    rect=page.locator('[data-hotspot="server"]').bounding_box()
    pick={'pointerType':'mouse','clientX':rect['x']+rect['width']/2,'clientY':rect['y']+rect['height']/2}
    host.dispatch_event('pointerdown',pick);host.dispatch_event('pointerup',pick)
    assert page.locator('[data-hotspot-title]').inner_text()=='Servers & storage'
    assert page.evaluate('window.equipmentPicks')==1
    page.keyboard.press('Escape')
   # Device details remain usable with touch and keyboard.
   hotspot=page.locator('[data-hotspot="server"]');hotspot.focus();hotspot.press('Enter')
   assert page.locator('[data-hotspot-title]').inner_text()=='Servers & storage'
   page.keyboard.press('Escape')
   if name=='large_touch_tablet':
    page.emulate_media(reduced_motion='reduce')
    page.wait_for_function("!document.querySelector('.hardware-scene canvas')")
  else:
   assert page.locator('.hardware-scene canvas').count()==0
   assert not any('/scene.js' in u or 'three.' in u for u in requests),(name,requests)
   assert page.locator('.hardware-fallback').evaluate('(e)=>getComputedStyle(e).opacity==="1"')
  assert not errors,(name,errors)
  print('PASS',name,mode,flush=True)
  context.close()
 browser.close()
if server:server.shutdown()
print('PASS tablet eligibility, automatic real 3D, keyboard activation, pause, touch-scroll protection, equipment details and accessibility fallbacks.')

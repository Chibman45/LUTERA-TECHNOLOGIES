"""Verify photo motion, readable content, real controls and low-motion fallbacks."""
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
import json,os,shutil,threading
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
class Handler(SimpleHTTPRequestHandler):
 def translate_path(self,path):return super().translate_path(path.removeprefix('/LUTERA-TECHNOLOGIES'))
 def log_message(self,*args):pass
server=None;base=os.environ.get('LUTERA_TEST_URL')
if not base:
 server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(ROOT)))
 threading.Thread(target=server.serve_forever,daemon=True).start()
 base=f'http://127.0.0.1:{server.server_port}/LUTERA-TECHNOLOGIES/'
with sync_playwright() as p:
 b=p.chromium.launch(executable_path=shutil.which('chromium') or None,args=['--no-sandbox'])
 c=b.new_context(viewport={'width':1191,'height':800});q=c.new_page();errors=[]
 q.on('pageerror',lambda e:errors.append(str(e)))
 q.goto(base,wait_until='networkidle');q.get_by_role('button',name='Reject optional').click()
 hero=q.locator('[data-hero]');q.wait_for_function('document.querySelector("[data-hero]").dataset.motion==="running"')
 # A slow runner may finish loading after an automatic cycle has occurred.
 assert 1<=q.locator('.hero-media img').count()<=3
 initial_counter=q.locator('[data-hero-counter]').inner_text()
 first=q.locator('.hero-slide.is-active');a=first.evaluate('(e)=>getComputedStyle(e).transform');q.wait_for_timeout(400);assert a!=first.evaluate('(e)=>getComputedStyle(e).transform')
 # A real automatic cycle loads and decodes the next image before crossfading.
 q.wait_for_function('(previous)=>document.querySelector("[data-hero-counter]").textContent!==previous',arg=initial_counter,timeout=15000)
 assert q.locator('.hero-slide.is-active').evaluate('(e)=>e.complete&&e.naturalWidth>0')
 q.locator('[data-hero-pause]').click();assert q.locator('[data-hero-pause]').get_attribute('aria-pressed')=='true'
 assert q.locator('[data-hero-play-icon]').is_visible() and not q.locator('[data-hero-pause-icon]').is_visible()
 # Pausing a newly active image is asynchronous on the compositor. Wait for
 # the animation's pending operation, then check its actual timeline rather
 # than sampling a possibly stale transform from the previous paint.
 active=q.locator('.hero-slide.is-active')
 active.evaluate('async (e)=>{await Promise.all(e.getAnimations().map(a=>a.ready))}')
 pan_state='(e)=>{const pan=e.getAnimations().find(a=>a.animationName==="hero-photo-pan");return {state:pan.playState,time:pan.currentTime}}'
 frozen=active.evaluate(pan_state)
 paused_counter=q.locator('[data-hero-counter]').inner_text()
 assert frozen['state']=='paused',frozen
 q.wait_for_timeout(8500)
 assert q.locator('[data-hero-counter]').inner_text()==paused_counter
 assert frozen==active.evaluate(pan_state),(frozen,active.evaluate(pan_state))
 # Manual navigation remains available while paused, with no hidden text.
 for _ in range(3):
  current=q.locator('[data-hero-counter]').inner_text()
  q.locator('[data-hero-next]').click()
  q.wait_for_function('(previous)=>document.querySelector("[data-hero-counter]").textContent!==previous',arg=current)
  if q.locator('[data-hero-counter]').inner_text()=='3 / 3':break
 assert q.locator('[data-hero-counter]').inner_text()=='3 / 3'
 assert 'Cloud and connected infrastructure' in q.locator('[data-hero-status]').inner_text()
 q.locator('[data-hero-next]').click();q.wait_for_function('document.querySelector("[data-hero-counter]").textContent==="1 / 3"')
 q.locator('[data-hero-previous]').click();q.wait_for_function('document.querySelector("[data-hero-counter]").textContent==="3 / 3"')
 q.locator('[data-hero-pause]').click();assert hero.get_attribute('data-motion')=='running'
 assert q.locator('[data-hero-pause-icon]').is_visible() and not q.locator('[data-hero-play-icon]').is_visible()
 q.locator('.enquiry-nav').click();q.wait_for_function('document.querySelector("[data-hero]").dataset.motion==="paused"')
 q.keyboard.press('Escape');q.wait_for_function('document.querySelector("[data-hero]").dataset.motion==="running"')
 q.locator('#our-services').scroll_into_view_if_needed();q.evaluate('scrollBy(0,300)')
 q.wait_for_function('document.querySelector("[data-hero]").dataset.motion==="paused"')
 q.evaluate('scrollTo(0,0)');q.wait_for_function('document.querySelector("[data-hero]").dataset.motion==="running"')
 # Changing the operating-system preference immediately suspends motion.
 q.emulate_media(reduced_motion='reduce');q.wait_for_function('document.querySelector("[data-hero]").dataset.motion==="paused"')
 assert not q.locator('[data-hero-pause]').is_visible()
 for width,height in [(320,740),(390,844),(768,1024),(1024,768),(1191,668),(1440,1000)]:
  q.set_viewport_size({'width':width,'height':height});q.evaluate('scrollTo(0,0)')
  assert q.evaluate('document.documentElement.scrollWidth<=innerWidth'),width
  box=hero.bounding_box()
  for selector in ['h1','.hero-copy>p','.hero-panel h2','.hero-panel p','.hero-photo-note']:
   text=hero.locator(selector);rect=text.bounding_box()
   assert text.is_visible() and rect['x']>=0 and rect['x']+rect['width']<=width+1,(width,selector,rect)
   assert rect['y']>=box['y'] and rect['y']+rect['height']<=box['y']+box['height']+1,(width,selector)
   assert text.evaluate('(e)=>getComputedStyle(e).color')=='rgb(255, 255, 255)'
  for selector in ['[data-hero-next]','[data-hero-previous]']:
   rect=q.locator(selector).bounding_box();assert rect['width']>=44 and rect['height']>=44
 # Reduced-motion and data-saving sessions request just the first hero photo.
 for mode in ['reduce','save-data','no-js']:
  context=b.new_context(viewport={'width':390,'height':844},reduced_motion='reduce' if mode=='reduce' else 'no-preference',java_script_enabled=mode!='no-js')
  if mode=='save-data':context.add_init_script("Object.defineProperty(navigator,'connection',{value:{saveData:true,addEventListener(){}}})")
  r=context.new_page();requests=[];r.on('request',lambda req:requests.append(req.url));r.goto(base,wait_until='networkidle')
  assert r.locator('.hero-slide').count()==1
  assert r.locator('.hero-slide').evaluate('(e)=>e.complete&&e.naturalWidth>0')
  assert r.evaluate('document.getAnimations().filter(a=>a.playState==="running").length')==0
  assert not any('hero-support-' in url or 'hero-cloud-' in url for url in requests),(mode,requests)
  if mode=='no-js':assert not r.locator('.hero-controls').is_visible()
  else:assert r.locator('[data-hero]').get_attribute('data-motion')=='paused'
  context.close()
 # Failed downloads preserve the visible photo and keep controls usable.
 fail=b.new_context(reduced_motion='reduce');r=fail.new_page()
 r.route('**/hero-support-*.webp',lambda route:route.fulfill(status=404,body='Missing photo'))
 r.goto(base,wait_until='networkidle');r.get_by_role('button',name='Reject optional').click();r.locator('[data-hero-next]').click()
 r.wait_for_function('document.querySelector("[data-hero-status]").textContent.includes("could not load")')
 assert r.locator('[data-hero-counter]').inner_text()=='1 / 3'
 assert r.locator('.hero-slide.is-active').evaluate('(e)=>e.complete&&e.naturalWidth>0')
 assert r.locator('[data-hero-next]').is_enabled()
 fail.close();assert not errors,errors;b.close()
if server:server.shutdown()
print('PASS hero: real pan/crossfade/autoplay, pause/resume, manual selection/wrap, offscreen suspension, dynamic reduced motion, save-data/no-JS still images, failed-image fallback, readable text and 320–1440px layouts.')

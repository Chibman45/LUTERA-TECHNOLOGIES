"""Cinematic motion must preserve navigation, native scrolling and accessible fallbacks."""
from pathlib import Path
from functools import partial
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from playwright.sync_api import sync_playwright
import os,shutil,threading
ROOT=Path(__file__).resolve().parents[1]
class Handler(SimpleHTTPRequestHandler):
 def translate_path(self,path):return super().translate_path(path.removeprefix('/LUTERA-TECHNOLOGIES'))
 def log_message(self,*args):pass
server=None;base=os.environ.get('LUTERA_TEST_URL')
if not base:
 server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(ROOT)))
 threading.Thread(target=server.serve_forever,daemon=True).start();base=f'http://127.0.0.1:{server.server_port}/LUTERA-TECHNOLOGIES/'
with sync_playwright() as p:
 b=p.chromium.launch(executable_path=shutil.which('chromium') or None,args=['--no-sandbox','--disable-webgl'])
 c=b.new_context(viewport={'width':1440,'height':1000});q=c.new_page();errors=[];q.on('pageerror',lambda e:errors.append(str(e)))
 # Record native transitions before the document scripts and retain the probe after navigation.
 c.add_init_script("addEventListener('pagereveal',e=>{window.hadNativeTransition=!!e.viewTransition;if(e.viewTransition)e.viewTransition.ready.then(()=>window.nativeReady=true,()=>{})})")
 q.goto(base,wait_until='networkidle')
 story=q.locator('[data-cinema-story]');assert story.count()==1
 assert q.locator('.cinema-chapter').count()==4
 q.locator('#story-discover').scroll_into_view_if_needed();q.wait_for_function("document.querySelector('[data-cinema-story]').classList.contains('cinema-motion')")
 q.wait_for_timeout(100)
 initial=story.evaluate("e=>e.style.getPropertyValue('--scene-progress')")
 q.locator('a[data-story-link="2"]').click();q.wait_for_url('**/#story-connect')
 q.wait_for_function("document.querySelector('[data-cinema-story]').dataset.chapter==='2'")
 assert q.locator('[data-story-link="2"]').get_attribute('aria-current')=='step'
 q.wait_for_function("parseFloat(document.querySelector('[data-cinema-story]').style.getPropertyValue('--scene-progress'))>.45")
 assert story.evaluate("e=>e.style.getPropertyValue('--scene-progress')")!=initial
 # Pinning is confined to the story and its camera pose follows the scroll.
 rect=q.locator('.cinema-sticky').bounding_box();assert 100<=rect['y']<=170,rect
 q.locator('[data-cinema-pause]').click();assert q.locator('[data-cinema-pause]').get_attribute('aria-pressed')=='true'
 frozen=story.evaluate("e=>e.style.getPropertyValue('--scene-progress')")
 q.locator('#story-support').scroll_into_view_if_needed();q.wait_for_timeout(120)
 assert story.evaluate("e=>e.style.getPropertyValue('--scene-progress')")==frozen
 q.locator('[data-cinema-pause]').click();q.wait_for_function("parseFloat(document.querySelector('[data-cinema-story]').style.getPropertyValue('--scene-progress'))>.8")
 q.emulate_media(reduced_motion='reduce');q.wait_for_function("!document.querySelector('[data-cinema-story]').classList.contains('cinema-motion')")
 assert q.locator('[data-cinema-pause]').is_hidden()
 assert q.locator('.cinema-assembly').evaluate("e=>getComputedStyle(e).transform")=='none'
 assert q.locator('.cinema-sticky').evaluate("e=>getComputedStyle(e).position")=='relative'
 q.emulate_media(reduced_motion='no-preference')
 # A real click must navigate with the native transition when available.
 q.locator('header a[href$="solutions/"]').click();q.wait_for_url('**/solutions/');q.wait_for_load_state('networkidle')
 if q.evaluate("'onpageswap' in window&&'ViewTransition' in window"):
  assert q.evaluate('window.hadNativeTransition'), 'Expected a native cross-document transition'
  assert q.evaluate('window.nativeReady'), 'Native transition must capture successfully'
 q.go_back(wait_until='networkidle');assert q.locator('[data-cinema-story]').count()==1
 # Quote actions preserve selections through the new navigation layer.
 q.goto(base+'solutions/',wait_until='networkidle');q.locator('[data-add="laptop"]').first.click()
 q.locator('.floating-contact-toggle').click();q.locator('.floating-quote-link').click();q.wait_for_url('**/request-quote/**');q.wait_for_load_state('networkidle')
 assert 'Business laptops' in q.locator('[data-quote-list]').inner_text()
 assert q.locator('#rfq-form').get_attribute('action')=='https://formsubmit.co/chimaster010@gmail.com'
 # Exercise the curtain in a browser without native cross-document support.
 fallback=b.new_context(viewport={'width':1440,'height':1000});fallback.add_init_script("delete Window.prototype.onpageswap;delete window.onpageswap;window.ViewTransition=undefined;delete window.ViewTransition")
 fallback.add_init_script("addEventListener('DOMContentLoaded',()=>{const s=document.createElement('style');s.textContent='@view-transition{navigation:none}';document.head.append(s)})")
 r=fallback.new_page();r.goto(base+'services/',wait_until='networkidle')
 # Override the feature check on implementations exposing a nonconfigurable property.
 assert not r.evaluate("'onpageswap' in window&&'ViewTransition' in window")
 r.locator('header a[href$="about/"]').evaluate('(a)=>a.click()')
 assert r.locator('html').evaluate("e=>e.classList.contains('cinema-leaving')")
 r.wait_for_url('**/about/');r.wait_for_load_state('networkidle')
 assert r.locator('h1').is_visible();r.go_back(wait_until='networkidle')
 assert not r.locator('html').evaluate("e=>e.classList.contains('cinema-leaving')")
 fallback.close()
 for width in [390]:
  q.set_viewport_size({'width':width,'height':900});q.goto(base,wait_until='networkidle')
  assert not story.evaluate("e=>e.classList.contains('cinema-motion')")
  assert q.locator('[data-cinema-pause]').is_hidden()
  assert q.locator('.cinema-sticky').evaluate("e=>getComputedStyle(e).position")=='relative'
  assert q.evaluate('document.documentElement.scrollWidth<=innerWidth')
 touch=b.new_context(viewport={'width':820,'height':1180},is_mobile=True,has_touch=True)
 r=touch.new_page();r.goto(base,wait_until='networkidle')
 assert not r.locator('[data-cinema-story]').evaluate("e=>e.classList.contains('cinema-motion')")
 r.keyboard.press('Tab');r.wait_for_function("document.querySelector('[data-cinema-story]').classList.contains('cinema-motion')")
 assert r.locator('.cinema-sticky').evaluate("e=>getComputedStyle(e).position")=='sticky'
 assert r.evaluate('document.documentElement.scrollWidth<=innerWidth')
 touch.close()
 nojs=b.new_context(java_script_enabled=False,viewport={'width':390,'height':900});r=nojs.new_page();r.goto(base)
 assert r.locator('.cinema-chapter').count()==4
 assert r.locator('[data-cinema-pause]').is_hidden()
 r.locator('[data-story-link="3"]').click();r.wait_for_url('**/#story-support');assert r.locator('#story-support').is_visible()
 nojs.close();assert not errors,errors;b.close()
if server:server.shutdown()
print('PASS cinematic chapter scrolling, sticky 3D scene, pose changes, pause/resume, reduced motion, native navigation, back restoration, quote selections, fallback curtain, mobile/tablet simplification and no-JS content. No emails sent.')

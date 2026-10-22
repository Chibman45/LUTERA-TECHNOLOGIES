"""Read-only real route checks and explicitly mocked invitation UI. Never sends mail."""
import json
from pathlib import Path
import shutil
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]
v=dict(l.split('=',1) for l in (root/'.env.local').read_text().splitlines() if l and not l.startswith('#'))
origin=v['WORKSPACE_ORIGIN']; entry=v['WORKSPACE_ENTRY']; token='a'*64
out=root/'test-results';out.mkdir(exist_ok=True)
with sync_playwright() as p:
 b=p.chromium.launch(executable_path=shutil.which('chromium') or None,headless=True,args=['--no-sandbox'])
 c=b.new_context(viewport={'width':1280,'height':900});page=c.new_page();errors=[];posts=[]
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.on('request',lambda r:posts.append(r.url) if r.method=='POST' else None)
 r=page.goto(origin+'/auth/confirm');assert r.status==200
 page.get_by_role('heading',name='Check your email link.').wait_for()
 assert 'noindex' in r.headers.get('x-robots-tag','')
 assert 'no-store' in r.headers.get('cache-control','')
 assert c.request.post(origin+'/api/auth/email-confirm',data={},headers={'Origin':'https://evil.example'}).status==403
 assert c.request.post(origin+'/api/auth/email-confirm',data={'token_hash':'short','type':'invite'},headers={'Origin':origin}).status==400
 page.goto(origin+'/auth/confirm?token_hash='+token+'&type=invite&next=https://evil.example')
 page.get_by_role('heading',name='Welcome to Lutera.').wait_for()
 page.wait_for_function('!location.search')
 assert not posts,posts
 page.get_by_label('New password',exact=True).fill('Sample-password-12!')
 page.get_by_label('Confirm password',exact=True).fill('different-password')
 page.get_by_role('button',name='Accept invitation').click()
 page.get_by_role('alert').get_by_text('Passwords must match.').wait_for()
 assert not posts,posts
 page.get_by_label('Confirm password',exact=True).fill('Sample-password-12!')
 def invalid(route):route.fulfill(status=400,content_type='application/json',body=json.dumps({'error':'This link has expired or has already been used.'}))
 c.route('**/api/auth/email-confirm',invalid)
 page.get_by_role('button',name='Accept invitation').click()
 page.get_by_role('alert').get_by_text('This link has expired or has already been used.').wait_for()
 page.screenshot(path=str(out/'email-invite-desktop.png'),full_page=True)
 axe=(root/'node_modules/axe-core/axe.min.js').read_text();page.add_script_tag(content=axe)
 report=page.evaluate("async()=>await axe.run(document,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21aa']}})")
 assert not report['violations'],[(v['id'],v['help']) for v in report['violations']]
 c.unroute('**/api/auth/email-confirm',invalid)
 def valid(route):route.fulfill(status=200,content_type='application/json',body=json.dumps({'next':'workspace','redirect':'/'+entry}))
 c.route('**/api/auth/email-confirm',valid)
 page.get_by_role('button',name='Accept invitation').click()
 page.get_by_role('heading',name='Welcome back.').wait_for()
 assert page.url==origin+'/'+entry
 page.goto(origin+'/auth/confirm?token_hash='+token+'&type=recovery')
 page.get_by_role('heading',name='Recover your account.').wait_for()
 assert page.get_by_text('Email recovery does not remove your authenticator.',exact=False).is_visible()
 assert page.locator('input[type=password]').count()==0
 page.set_viewport_size({'width':390,'height':844})
 page.screenshot(path=str(out/'email-recovery-mobile.png'),full_page=True)
 assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
 assert not errors,errors
 b.close()
print('PASS: real callback headers/CSRF/input denials; no GET token consumption; fixture invite validation, expiry, success redirect, recovery MFA guidance, responsive layout and axe checks. No mail sent.')

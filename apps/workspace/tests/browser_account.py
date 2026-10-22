"""Private-account UI fixtures with real unauthenticated API guards. No real emails or records."""
import base64,json,shutil
from pathlib import Path
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]
v=dict(l.split('=',1) for l in (root/'.env.local').read_text().splitlines() if l and not l.startswith('#'))
origin=v['WORKSPACE_ORIGIN'];entry=v['WORKSPACE_ENTRY'];out=root/'test-results';out.mkdir(exist_ok=True)
png=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aVxkAAAAASUVORK5CYII=')
session={'email':'owner-fixture@example.invalid','role':'owner','verified':True,'factors':[{'id':'82e20845-050f-47ba-a61e-b7eb7f1d0489','name':'Work phone'}]}
info={'email':session['email'],'role':'owner','pending_email':None,'profile':{'full_name':'Fixture Owner','phone':'','avatar_url':None,'version':0},'factors':session['factors'].copy()}
state={'documents':[],'staff':[],'audit':[],'members':[],'content':None,'settings':None,'publications':[],'publishing_connected':False}
calls=[];login_attempts=0

def fixture(route):
 global session,login_attempts
 action=route.request.url.split('/api/')[1];body=route.request.post_data_json if route.request.method=='POST' else None;calls.append(action)
 def respond(value,status=200,headers=None):route.fulfill(status=status,content_type='application/json',headers=headers or {},body=json.dumps(value))
 if action=='session':return respond(session) if session else respond({'error':'Sign in to continue'},401)
 if action=='state':return respond(state)
 if action=='account':return respond(info)
 if action=='account/profile':
  assert body['full_name']=='Updated Fixture Owner';info['profile'].update({'full_name':body['full_name'],'phone':body['phone'],'version':info['profile']['version']+1,'avatar_url':'data:image/png;base64,'+base64.b64encode(png).decode() if body.get('photo') else info['profile']['avatar_url']});return respond({'success':True})
 if action=='account/email':info['pending_email']=body['email'];return respond({'message':'Confirmation requested. Check both inboxes.'})
 if action=='mfa/add':return respond({'id':'c392fa77-4e70-4aee-bf6a-f221c88e5ccc','qr':'data:image/png;base64,'+base64.b64encode(png).decode(),'secret':'SAMPLE-NOT-A-REAL-KEY'})
 if action=='mfa/confirm-add':info['factors'].append({'id':body['factorId'],'name':'Backup phone'});return respond({'success':True})
 if action=='auth/password':
  assert body['password']=='Private-Password-123!';session=None;return respond({'success':True})
 if action=='auth/signin':
  login_attempts+=1
  return respond({'error':'Too many attempts. Please wait before retrying.'},429,{'Retry-After':'2'}) if login_attempts==1 else respond({'error':'Sign-in failed. Check your email and password.'},401)
 return respond({'error':'Unexpected fixture operation'},400)

with sync_playwright() as p:
 b=p.chromium.launch(executable_path=shutil.which('chromium') or None,headless=True,args=['--no-sandbox'])
 c=b.new_context(viewport={'width':1280,'height':1000});page=c.new_page();errors=[]
 page.on('pageerror',lambda e:errors.append(str(e)))
 assert c.request.get(origin+'/api/account').status==401
 assert c.request.get(origin+'/api/account/avatar').status==401
 assert c.request.post(origin+'/api/account/profile',data={},headers={'Origin':origin}).status==401
 assert c.request.post(origin+'/api/account/email',data={},headers={'Origin':'https://evil.example'}).status==403
 c.route('**/api/**',fixture)
 page.goto(origin+'/'+entry)
 page.get_by_role('button',name='My account',exact=True).click()
 page.get_by_label('Full name',exact=True).wait_for()
 page.get_by_label('Full name',exact=True).fill('Updated Fixture Owner')
 page.get_by_label('Phone number',exact=True).fill('+234 902 6276 130')
 page.get_by_label('Upload profile photo',exact=True).set_input_files({'name':'sample.png','mimeType':'image/png','buffer':png})
 page.get_by_role('button',name='Save profile',exact=True).click()
 page.get_by_text('Your profile has been updated.',exact=True).wait_for()
 assert info['profile']['phone']=='+234 902 6276 130'
 page.get_by_label('New email address',exact=True).fill('updated-fixture@example.invalid')
 page.get_by_label('Confirm new email address',exact=True).fill('updated-fixture@example.invalid')
 page.get_by_role('button',name='Request email change',exact=True).click()
 page.get_by_text('Waiting for confirmation:',exact=False).wait_for()
 page.get_by_label('New authenticator name',exact=True).fill('Backup phone')
 page.get_by_role('button',name='Add an authenticator',exact=True).click()
 page.get_by_label('New authenticator code',exact=True).fill('123456')
 page.get_by_role('button',name='Verify new authenticator',exact=True).click()
 page.get_by_text('Your additional authenticator is enabled and verified.',exact=True).wait_for()
 assert len(info['factors'])==2
 page.get_by_label('New password',exact=True).fill('weakpasswordweak')
 page.get_by_label('Confirm new password',exact=True).fill('weakpasswordweak')
 page.get_by_role('button',name='Change password & sign out').click()
 page.get_by_role('alert').get_by_text('Password requires:',exact=False).wait_for()
 assert 'auth/password' not in calls
 page.get_by_label('New password',exact=True).fill('Private-Password-123!')
 page.get_by_label('Confirm new password',exact=True).fill('Private-Password-123!')
 page.get_by_role('button',name='Show new password',exact=True).click()
 assert page.get_by_label('New password',exact=True).get_attribute('type')=='text'
 page.get_by_role('button',name='Hide new password',exact=True).click()
 assert page.get_by_label('New password',exact=True).get_attribute('type')=='password'
 axe=(root/'node_modules/axe-core/axe.min.js').read_text()
 for width in [390,768,1280]:
  page.set_viewport_size({'width':width,'height':1000})
  assert page.evaluate('document.documentElement.scrollWidth<=innerWidth'),width
  page.add_script_tag(content=axe)
  report=page.evaluate("async()=>await axe.run(document,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21aa']}})")
  assert not report['violations'],[(x['id'],x['help']) for x in report['violations']]
  page.screenshot(path=str(out/f'account-{width}.png'),full_page=True)
 page.get_by_role('button',name='Change password & sign out').click()
 page.get_by_role('heading',name='Welcome back.').wait_for()
 page.get_by_text('Your password has been updated. Sign in with your new password.').wait_for()
 page.get_by_label('Work email').fill('owner-fixture@example.invalid')
 page.get_by_label('Password',exact=True).fill('fixture-existing-password')
 page.get_by_role('button',name='Show password',exact=True).click()
 assert page.get_by_label('Password',exact=True).get_attribute('type')=='text'
 page.get_by_role('button',name='Hide password',exact=True).click()
 page.get_by_role('button',name='Continue securely').click()
 page.get_by_role('button',name='Try again in',exact=False).wait_for()
 assert page.get_by_role('button',name='Try again in',exact=False).is_disabled()
 page.get_by_role('button',name='Continue securely').wait_for(timeout=10000)
 page.get_by_role('button',name='Continue securely').click()
 page.get_by_role('alert').get_by_text('Sign-in failed.',exact=False).wait_for()
 assert login_attempts==2
 assert not errors,errors
 b.close()
print('PASS: real account/CSRF guards; fixture profile/photo/email/MFA, password rules and eyes, password-change notification, 429 retry countdown; 390/768/1280 layouts and axe. No real emails or account changes.')

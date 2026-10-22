"""Apply reviewed Auth settings with an owner-supplied environment token. No mail is sent.

Run privately on the owner's machine. Never paste the token into chat or Git.
"""
import argparse
import json
import os
from pathlib import Path
import sys
import urllib.request
import urllib.error

PROJECT = 'zwtjemhrubzgaueuyuxn'
ROOT = Path(__file__).resolve().parent

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply',action='store_true',help='Apply to the existing Lutera Supabase project')
    parser.add_argument('--urls-only',action='store_true',help='Fix the URLs independently of custom SMTP/template setup')
    args=parser.parse_args()
    config=json.loads((ROOT/'auth-config.json').read_text())
    if args.urls_only:config={k:config[k] for k in ['site_url','uri_allow_list']}
    if not args.apply:
        print(json.dumps({'project':PROJECT,'site_url':config['site_url'],'redirect_allowlist':config['uri_allow_list'],'template_count':sum(k.startswith('mailer_templates_') for k in config),'mode':'dry run; no changes sent'},indent=2))
        return
    token=os.environ.get('SUPABASE_ACCESS_TOKEN')
    if not token:sys.exit('Set SUPABASE_ACCESS_TOKEN privately in your terminal, not in a file or chat.')
    request=urllib.request.Request(f'https://api.supabase.com/v1/projects/{PROJECT}/config/auth',method='PATCH',headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'},data=json.dumps(config).encode())
    try:
        with urllib.request.urlopen(request,timeout=30) as response:
            # Provider responses can contain SMTP configuration. Check only the
            # reviewed public fields; never print or persist the response.
            actual=json.load(response)
            if any(actual.get(k)!=v for k,v in config.items()):sys.exit('The response did not confirm all requested fields. Review Supabase Auth settings before sending emails.')
    except urllib.error.HTTPError as error:
        sys.exit(f'Auth settings update failed (HTTP {error.code}). Check project permissions and custom SMTP. No provider response or credentials were printed.')
    except (OSError,ValueError):
        sys.exit('No confirmed response. Inspect Supabase Auth settings before retrying. No emails were sent by this script.')
    print('Supabase confirmed the requested URL/settings update. No emails were sent. Complete an owner invitation/recovery check next.')

if __name__=='__main__':main()

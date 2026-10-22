"""Generate public company seeds only. Never store private business records here."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[3]
site=json.loads((root/'content/site.json').read_text())
c=site['company']
settings={'company':{'name':c['legal_name'],'address':f"{c['street_address']}, {c['city']}, {c['state']}, Nigeria",'email':c['email'],'phone':c['display_phone'],'website':'https://luteratech.com'},'bank_name':'','account_name':'','account_number':'','tax_id':'','document_notes':'','currency':'NGN'}
def literal(data):return "'"+json.dumps(data,ensure_ascii=False).replace("'","''")+"'::jsonb"
sql=(f"\ninsert into public.work_settings(id,payload) values(1,{literal(settings)});\n"
     f"insert into public.work_site_drafts(id,content) values(1,{literal(site)});\n"
     f"insert into public.work_public_site(id,revision,content) values(1,gen_random_uuid(),{literal(site)});\n"
     "insert into public.work_members(email,role) values('chimaster010@gmail.com','owner');\n")
Path(__file__).with_name('seed.sql').write_text(sql)

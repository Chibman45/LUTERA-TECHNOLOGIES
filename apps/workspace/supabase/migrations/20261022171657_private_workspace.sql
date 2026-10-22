-- Private workspace. No financial/staff data is ever exposed to anon.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;
alter default privileges in schema private revoke execute on functions from public;
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;

create table public.work_members (
  email text primary key check (email = lower(email) and length(email) <= 254),
  user_id uuid unique references auth.users(id) on delete set null,
  role text not null check (role in ('owner','admin','editor','finance','designer')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.work_settings (
  id integer primary key default 1 check (id=1),
  payload jsonb not null check (jsonb_typeof(payload)='object'),
  version integer not null default 1, updated_at timestamptz not null default now()
);
create table public.work_site_drafts (
  id integer primary key default 1 check (id=1),
  content jsonb not null check (jsonb_typeof(content)='object'),
  version integer not null default 1, updated_at timestamptz not null default now()
);
create table public.work_documents (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('quotation','proforma','receipt')),
  status text not null default 'draft' check (status in ('draft','issued','void')),
  number text unique, payload jsonb not null,
  total_minor bigint not null default 0,
  version integer not null default 1,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  issued_at timestamptz,
  source_id uuid references public.work_documents(id) on delete restrict
);
create index work_documents_created_idx on public.work_documents(created_at desc);
create index work_documents_source_idx on public.work_documents(source_id) where source_id is not null;
create table public.work_staff (
  id uuid primary key default gen_random_uuid(), payload jsonb not null,
  version integer not null default 1,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create unique index work_staff_number_idx on public.work_staff((payload->>'staff_number'));
create table public.work_audit (
  id bigint generated always as identity primary key,
  actor uuid not null default auth.uid(), action text not null, entity text not null, entity_id text not null,
  created_at timestamptz not null default now()
);
create index work_audit_created_idx on public.work_audit(created_at desc);
create table public.work_public_site (
  id integer primary key default 1 check (id=1), revision uuid not null unique,
  content jsonb not null, published_at timestamptz not null default now()
);
create table public.work_publications (
  id uuid primary key, draft_version integer not null,
  status text not null default 'queued' check (status in ('queued','building','live','failed')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table private.work_counters (
  kind text not null, year integer not null, next_value integer not null,
  primary key(kind,year)
);

-- The only definer helpers live outside the exposed API schema. Each fixes its
-- search_path and makes its own identity/permission checks.
create function private.work_allowed(area text) returns boolean
language sql stable security definer set search_path = '' as $$
 select coalesce(
   (auth.jwt()->>'aal'='aal2')
   and exists(select 1 from auth.sessions s where s.id::text=auth.jwt()->>'session_id' and s.user_id=auth.uid()
              and s.created_at > now()-interval '12 hours' and (s.not_after is null or s.not_after>now()))
   and exists(select 1 from auth.mfa_factors f where f.user_id=auth.uid() and f.status='verified' and f.factor_type='totp')
   and exists(select 1 from public.work_members m where m.user_id=auth.uid() and m.active and (
       area='session' or m.role='owner' or (m.role='admin' and area not in ('members','backup'))
       or (m.role='editor' and area='content') or (m.role='finance' and area='finance') or (m.role='designer' and area='staff')
   )),false);
$$;
grant execute on function private.work_allowed(text) to authenticated;

create function private.work_claim() returns void language plpgsql security definer set search_path = '' as $$
declare verified_email text;
begin
  select lower(u.email) into verified_email from auth.users u where u.id=auth.uid() and u.email_confirmed_at is not null;
  if verified_email is null then raise exception 'Approved verified account required'; end if;
  update public.work_members set user_id=auth.uid() where email=verified_email and active and (user_id is null or user_id=auth.uid());
  if not found then raise exception 'Approved verified account required'; end if;
end; $$;
grant execute on function private.work_claim() to authenticated;
create function public.work_claim_membership() returns void language sql security invoker set search_path='' as $$ select private.work_claim(); $$;
revoke all on function public.work_claim_membership() from public, anon;
grant execute on function public.work_claim_membership() to authenticated;

create function private.work_member(email_address text, member_role text, enabled boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not private.work_allowed('members') then raise exception 'Owner access required'; end if;
 if member_role not in ('owner','admin','editor','finance','designer') or email_address !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' or length(email_address)>254 then raise exception 'Invalid member'; end if;
 if exists(select 1 from public.work_members where email=lower(email_address) and user_id=auth.uid()) then raise exception 'Use another owner to change your own access'; end if;
 insert into public.work_members(email,role,active) values(lower(email_address),member_role,enabled)
 on conflict(email) do update set role=excluded.role,active=excluded.active;
 insert into public.work_audit(action,entity,entity_id) values('access_changed','member',lower(email_address));
end; $$;
grant execute on function private.work_member(text,text,boolean) to authenticated;
create function public.work_set_member(email_address text, member_role text, enabled boolean) returns void
language sql security invoker set search_path='' as $$ select private.work_member(email_address,member_role,enabled); $$;
revoke all on function public.work_set_member(text,text,boolean) from public,anon;
grant execute on function public.work_set_member(text,text,boolean) to authenticated;

create function private.work_touch() returns trigger language plpgsql set search_path='' as $$
begin new.version=old.version+1; new.updated_at=now(); return new; end; $$;
create trigger work_settings_touch before update on public.work_settings for each row execute function private.work_touch();
create trigger work_drafts_touch before update on public.work_site_drafts for each row execute function private.work_touch();
create trigger work_staff_touch before update on public.work_staff for each row execute function private.work_touch();

create function private.work_audit_change() returns trigger language plpgsql security definer set search_path='' as $$
declare record_id text;
begin
 record_id=case when TG_OP='DELETE' then old.id::text else new.id::text end;
 insert into public.work_audit(action,entity,entity_id) values(lower(TG_OP),TG_TABLE_NAME,record_id);
 if TG_OP='DELETE' then return old; else return new; end if;
end; $$;
create trigger work_documents_audit after insert or update or delete on public.work_documents for each row execute function private.work_audit_change();
create trigger work_staff_audit after insert or update or delete on public.work_staff for each row execute function private.work_audit_change();
create trigger work_settings_audit after update on public.work_settings for each row execute function private.work_audit_change();
create trigger work_drafts_audit after update on public.work_site_drafts for each row execute function private.work_audit_change();

create function private.work_document_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare subtotal numeric:=0; tax numeric; item jsonb; company jsonb; seq integer; yr integer; source public.work_documents; received bigint;
begin
 if not private.work_allowed('finance') then raise exception 'Finance permission and MFA required'; end if;
 if TG_OP='DELETE' then
   if old.status<>'draft' then raise exception 'Issued records cannot be deleted'; end if;
   return old;
 end if;
 if TG_OP='INSERT' then
   if new.status<>'draft' or new.number is not null or new.issued_at is not null then raise exception 'Create a draft first'; end if;
   new.created_at=now(); new.version=1;
 else
   new.version=old.version+1;
   new.created_at=old.created_at;
   if old.status='void' then raise exception 'Voided records are immutable'; end if;
   if old.status='issued' then
     if new.status<>'void' or new.payload - 'void_reason' <> old.payload or length(trim(new.payload->>'void_reason')) not between 5 and 500
       or new.kind<>old.kind or new.number is distinct from old.number or new.total_minor<>old.total_minor
       or new.source_id is distinct from old.source_id or new.issued_at is distinct from old.issued_at then raise exception 'Issued records can only be voided with a reason'; end if;
     if exists(select 1 from public.work_documents d where d.source_id=old.id and d.status='issued') then raise exception 'Void linked receipts first'; end if;
     new.updated_at=now(); return new;
   end if;
   if new.status not in ('draft','issued') or new.kind<>old.kind then raise exception 'Invalid document transition'; end if;
 end if;
 if jsonb_typeof(new.payload)<>'object' or not (new.payload ?& array['kind','customer','currency','date','valid_until','items','discount_minor','tax_bps','notes','payment_method','payment_reference','payment_confirmed','source_id']) or not ((new.payload->'customer') ?& array['name','address','email','phone']) or new.payload->>'kind' is distinct from new.kind or length(new.payload::text)>60000
    or jsonb_typeof(new.payload->'customer') is distinct from 'object' or jsonb_typeof(new.payload#>'{customer,name}') is distinct from 'string' or jsonb_typeof(new.payload->'currency') is distinct from 'string' or jsonb_typeof(new.payload->'date') is distinct from 'string' or jsonb_typeof(new.payload->'valid_until') is distinct from 'string' or jsonb_typeof(new.payload->'payment_confirmed') is distinct from 'boolean' or jsonb_typeof(new.payload->'source_id') is distinct from 'string' or new.payload->>'currency' not in ('NGN','USD','GBP','EUR') or length(trim(new.payload#>>'{customer,name}')) not between 1 and 160
    or jsonb_typeof(new.payload->'items') is distinct from 'array' or jsonb_array_length(new.payload->'items') not between 1 and 40 then raise exception 'Invalid document'; end if;
 for item in select * from jsonb_array_elements(new.payload->'items') loop
   if item @> '{"description":null}' or item @> '{"quantity":null}' or item @> '{"unit_minor":null}' or not (item ?& array['description','quantity','unit_minor']) or jsonb_typeof(item->'description')<>'string' or jsonb_typeof(item->'quantity')<>'number' or jsonb_typeof(item->'unit_minor')<>'number' or length(trim(item->>'description')) not between 1 and 400 or (item->>'quantity')::numeric not between 1 and 1000000
     or (item->>'quantity')::numeric<>trunc((item->>'quantity')::numeric)
     or (item->>'unit_minor')::numeric not between 1 and 100000000000
     or (item->>'unit_minor')::numeric<>trunc((item->>'unit_minor')::numeric) then raise exception 'Invalid line item'; end if;
   subtotal=subtotal+(item->>'quantity')::numeric*(item->>'unit_minor')::numeric;
 end loop;
 if jsonb_typeof(new.payload->'discount_minor') is distinct from 'number' or jsonb_typeof(new.payload->'tax_bps') is distinct from 'number' or subtotal>1000000000000 or (new.payload->>'discount_minor')::numeric not between 0 and subtotal-1
    or (new.payload->>'tax_bps')::numeric not between 0 and 10000
    or (new.payload->>'discount_minor')::numeric<>trunc((new.payload->>'discount_minor')::numeric)
    or (new.payload->>'tax_bps')::numeric<>trunc((new.payload->>'tax_bps')::numeric) then raise exception 'Invalid totals'; end if;
 tax=round((subtotal-(new.payload->>'discount_minor')::numeric)*(new.payload->>'tax_bps')::numeric/10000);
 new.total_minor=subtotal-(new.payload->>'discount_minor')::numeric+tax;
 if (new.payload->>'valid_until')<>'' and (new.payload->>'valid_until')::date<(new.payload->>'date')::date then raise exception 'Invalid dates'; end if;
 new.source_id=nullif(new.payload->>'source_id','')::uuid;
 if new.source_id=new.id or (new.kind<>'receipt' and new.source_id is not null) then raise exception 'Only receipts can link another document'; end if;
 if new.kind='receipt' and ((new.payload->>'tax_bps')::numeric<>0 or (new.payload->>'discount_minor')::numeric<>0) then raise exception 'Receipts record the amount received'; end if;
 if new.source_id is not null then
   select * into source from public.work_documents where id=new.source_id for update;
   if not found or source.kind='receipt' or source.status<>'issued' or source.payload->>'currency'<>new.payload->>'currency'
       or source.payload#>>'{customer,name}'<>new.payload#>>'{customer,name}' then raise exception 'Link an issued quote/pro forma for the same customer and currency'; end if;
 end if;
 new.number=null; new.issued_at=null; new.payload=new.payload-'company'-'void_reason';
 if new.status='issued' then
   if new.kind='receipt' and (coalesce((new.payload->>'payment_confirmed')::boolean,false)=false or length(trim(new.payload->>'payment_method'))=0) then raise exception 'Confirm the received payment and payment method'; end if;
   if new.source_id is not null then
     select coalesce(sum(total_minor),0) into received from public.work_documents where source_id=new.source_id and status='issued' and id<>new.id;
     if received+new.total_minor>source.total_minor then raise exception 'Receipt exceeds the unpaid amount'; end if;
   end if;
   select payload into company from public.work_settings where id=1;
   if company is null then raise exception 'Configure company document settings first'; end if;
   yr=extract(year from now());
   insert into private.work_counters(kind,year,next_value) values(new.kind,yr,1)
     on conflict(kind,year) do update set next_value=private.work_counters.next_value+1 returning next_value into seq;
   new.number='LUT-'||case new.kind when 'quotation' then 'QUO' when 'proforma' then 'PRO' else 'RCT' end||'-'||yr||'-'||lpad(seq::text,6,'0');
   new.issued_at=now(); new.payload=jsonb_set(new.payload,'{company}',company);
 end if;
 new.updated_at=now(); return new;
end; $$;
create trigger work_document_guard before insert or update or delete on public.work_documents for each row execute function private.work_document_guard();

-- Draft and publication are separate. Only the explicitly published snapshot is public.
create function private.work_publish(expected_version integer) returns uuid language plpgsql security definer set search_path='' as $$
declare draft public.work_site_drafts; revision uuid:=gen_random_uuid();
begin
 if not private.work_allowed('content') then raise exception 'Content permission and MFA required'; end if;
 select * into draft from public.work_site_drafts where id=1 for update;
 if not found or draft.version<>expected_version then raise exception 'Draft changed; reload before publishing'; end if;
 if jsonb_typeof(draft.content->'company')<>'object' or jsonb_typeof(draft.content->'services')<>'array'
    or jsonb_array_length(draft.content->'services') not between 1 and 30
    or draft.content->'hosting'->>'production_origin'<>'https://luteratech.com'
    or exists(select 1 from jsonb_object_keys(draft.content) k where k not in ('hosting','company','services','commitments','socials'))
    then raise exception 'Invalid public content'; end if;
 insert into public.work_public_site(id,revision,content) values(1,revision,draft.content)
   on conflict(id) do update set revision=excluded.revision,content=excluded.content,published_at=now();
 insert into public.work_publications(id,draft_version) values(revision,expected_version);
 insert into public.work_audit(action,entity,entity_id) values('publish_requested','website',revision::text);
 return revision;
end; $$;
grant execute on function private.work_publish(integer) to authenticated;
create function public.work_publish_site(expected_version integer) returns uuid language sql security invoker set search_path='' as $$ select private.work_publish(expected_version); $$;
revoke all on function public.work_publish_site(integer) from public,anon;
grant execute on function public.work_publish_site(integer) to authenticated;

create function private.work_log(export_action text, table_name text, record_id text) returns void language plpgsql security definer set search_path='' as $$
begin
 if table_name not in ('document','staff','backup') or export_action not in ('export_pdf','export_docx','export_png','export_backup')
    or not private.work_allowed(case table_name when 'document' then 'finance' when 'staff' then 'staff' else 'backup' end)
    then raise exception 'Export permission required'; end if;
 insert into public.work_audit(action,entity,entity_id) values(export_action,table_name,left(record_id,100));
end; $$;
grant execute on function private.work_log(text,text,text) to authenticated;
create function public.work_log_export(export_action text, table_name text, record_id text) returns void language sql security invoker set search_path='' as $$ select private.work_log(export_action,table_name,record_id); $$;
revoke all on function public.work_log_export(text,text,text) from public,anon;
grant execute on function public.work_log_export(text,text,text) to authenticated;

-- Explicit table grants; all mutating access additionally passes RLS.
revoke all on public.work_members,public.work_settings,public.work_site_drafts,public.work_documents,public.work_staff,public.work_audit,public.work_public_site,public.work_publications from anon,authenticated;
grant select on public.work_members,public.work_audit,public.work_public_site to authenticated;
grant select on public.work_public_site to anon;
grant select,update on public.work_settings,public.work_site_drafts to authenticated;
grant select on public.work_publications to authenticated;
grant update(status,updated_at) on public.work_publications to authenticated;
grant select,insert,update,delete on public.work_documents,public.work_staff to authenticated;

alter table public.work_members enable row level security;
alter table public.work_settings enable row level security;
alter table public.work_site_drafts enable row level security;
alter table public.work_documents enable row level security;
alter table public.work_staff enable row level security;
alter table public.work_audit enable row level security;
alter table public.work_public_site enable row level security;
alter table public.work_publications enable row level security;
create policy work_own_membership on public.work_members for select to authenticated using(user_id=(select auth.uid()) or (select private.work_allowed('members')));
-- Settings contain company/payment information only; staff/finance roles need it for exports.
create policy work_settings_read on public.work_settings for select to authenticated using((select private.work_allowed('settings')) or (select private.work_allowed('finance')) or (select private.work_allowed('staff')));
create policy work_settings_update on public.work_settings for update to authenticated using((select private.work_allowed('settings'))) with check((select private.work_allowed('settings')));
create policy work_drafts_read on public.work_site_drafts for select to authenticated using((select private.work_allowed('content')));
create policy work_drafts_update on public.work_site_drafts for update to authenticated using((select private.work_allowed('content'))) with check((select private.work_allowed('content')));
create policy work_finance on public.work_documents for all to authenticated using((select private.work_allowed('finance'))) with check((select private.work_allowed('finance')));
create policy work_staff_access on public.work_staff for all to authenticated using((select private.work_allowed('staff'))) with check((select private.work_allowed('staff')));
create policy work_audit_read on public.work_audit for select to authenticated using((select private.work_allowed('audit')));
create policy work_public_snapshot on public.work_public_site for select to anon,authenticated using(true);
create policy work_publication_read on public.work_publications for select to authenticated using((select private.work_allowed('content')));
create policy work_publication_update on public.work_publications for update to authenticated using((select private.work_allowed('content'))) with check((select private.work_allowed('content')));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('work-staff','work-staff',false,1048576,array['image/jpeg']) on conflict(id) do nothing;
create policy work_photos_read on storage.objects for select to authenticated using(bucket_id='work-staff' and (select private.work_allowed('staff')));
create policy work_photos_insert on storage.objects for insert to authenticated with check(bucket_id='work-staff' and (select private.work_allowed('staff')));
create policy work_photos_delete on storage.objects for delete to authenticated using(bucket_id='work-staff' and (select private.work_allowed('staff')));

create function public.work_has_access(area text) returns boolean language sql security invoker set search_path='' as $$ select private.work_allowed(area); $$;
revoke all on function public.work_has_access(text) from public,anon;
grant execute on function public.work_has_access(text) to authenticated;
create function private.work_backup() returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if not private.work_allowed('backup') then raise exception 'Owner access required'; end if;
 if (select count(*) from public.work_documents)>20000 then raise exception 'Use the full database backup procedure'; end if;
 insert into public.work_audit(action,entity,entity_id) values('export_backup','backup','snapshot');
 select jsonb_build_object(
  'settings',(select jsonb_agg(s) from public.work_settings s),
  'members',(select jsonb_agg(s) from public.work_members s),
  'documents',coalesce((select jsonb_agg(s) from public.work_documents s),'[]'::jsonb),
  'staff',coalesce((select jsonb_agg(s) from public.work_staff s),'[]'::jsonb),
  'drafts',(select jsonb_agg(s) from public.work_site_drafts s),
  'public_site',(select jsonb_agg(s) from public.work_public_site s),
  'publications',coalesce((select jsonb_agg(s) from public.work_publications s),'[]'::jsonb),
  'counters',coalesce((select jsonb_agg(s) from private.work_counters s),'[]'::jsonb),
  'audit',coalesce((select jsonb_agg(s) from public.work_audit s),'[]'::jsonb)
 ) into result;
 return result;
end; $$;
grant execute on function private.work_backup() to authenticated;
create function public.work_backup_snapshot() returns jsonb language sql security invoker set search_path='' as $$ select private.work_backup(); $$;
revoke all on function public.work_backup_snapshot() from public,anon;
grant execute on function public.work_backup_snapshot() to authenticated;

insert into public.work_settings(id,payload) values(1,'{"company": {"name": "Lutera Technology Ltd", "address": "No. 7, Mahatma Gandhi Street, Area 11, Garki, Abuja, FCT, Nigeria", "email": "chimaster010@gmail.com", "phone": "+234 902 6276 130", "website": "https://luteratech.com"}, "bank_name": "", "account_name": "", "account_number": "", "tax_id": "", "document_notes": "", "currency": "NGN"}'::jsonb);
insert into public.work_site_drafts(id,content) values(1,'{"hosting": {"production_origin": "https://luteratech.com", "redirect_origins": ["https://www.luteratech.com", "https://luteratech.com.ng", "https://www.luteratech.com.ng"]}, "company": {"name": "Lutera Technology Ltd", "legal_name": "Lutera Technology Ltd", "registration_completed": true, "registration_number": "", "email": "chimaster010@gmail.com", "phone": "+2349026276130", "display_phone": "+234 902 6276 130", "whatsapp": "https://wa.me/2349026276130", "street_address": "No. 7, Mahatma Gandhi Street, Area 11, Garki", "city": "Abuja", "state": "FCT", "country": "NG", "lga": "AMAC (Abuja Municipal Area Council)", "house_number": "No. 7", "nature_of_business": "Information Technology and Artificial Intelligence (AI) Solutions; Technology Consultancy and IT Consulting Services; AI Agent Development and Business Process Automation; Software Design, Development and Implementation; Data Analytics; Systems Integration; Cloud-Based Solutions; Procurement, Importation, Exportation, Wholesale and Retail Supply of Computer Hardware, Accessories and Peripherals; Computer Installation, Maintenance and Technical Support; and Related Technology Services.", "brand_name": "Lutera"}, "services": [{"key": "procurement", "slug": "it-procurement", "title": "IT procurement & sourcing", "icon": "procurement", "image": "laptop", "alt": "Business laptop illustrating an equipment specification", "description": "Equipment sourced against your requirements, from specification and pre-shipment inspection to agreed delivery."}, {"key": "hardware", "slug": "hardware", "title": "Computer hardware & equipment", "icon": "hardware", "image": "desktop", "alt": "Desktop computer, keyboard and mouse", "description": "Business laptops, desktops, servers, networking equipment and the accessories that complete your setup."}, {"key": "consulting", "slug": "consulting", "title": "Technology & IT consulting", "icon": "consulting", "image": "consulting", "alt": "A team discussing project requirements with laptops around a shared table", "description": "Clear advice on technology priorities, specifications and implementation, shaped around your organisation."}, {"key": "support", "slug": "technical-support", "title": "Installation & technical support", "icon": "support", "image": "support", "alt": "Technician installing a memory module in computer equipment", "description": "Computer labs, installation, commissioning and maintenance, with a named support contact after handover."}, {"key": "ai", "slug": "ai-automation", "title": "AI agents & automation", "icon": "automation", "image": "ai", "alt": "A team mapping the stages of a business workflow", "description": "AI agents and business process automation for workflows that are currently handled by hand."}, {"key": "software", "slug": "software-development", "title": "Software development", "icon": "software", "image": "software", "alt": "Software source code displayed on a development computer", "description": "Business software designed, developed and implemented to an agreed scope, with your users in mind."}, {"key": "data", "slug": "data-analytics", "title": "Data analytics", "icon": "data", "image": "data", "alt": "Analytics dashboard displaying business charts and metrics", "description": "Useful reporting and analysis built around your business questions, data sources and decisions."}, {"key": "cloud", "slug": "cloud-integration", "title": "Cloud & systems integration", "icon": "cloud", "image": "servers", "alt": "Connected racks of server equipment", "description": "Cloud-based systems and practical integrations that connect the applications your organisation uses."}], "commitments": [{"title": "A clear specification", "description": "We source against an agreed specification and carry out pre-shipment inspections."}, {"title": "Support after handover", "description": "Locally held spare parts and a named support contact for the equipment we supply."}, {"title": "Written warranty terms", "description": "Parts warranty starts from site acceptance. Duration and coverage are agreed in writing."}]}'::jsonb);
insert into public.work_public_site(id,revision,content) values(1,gen_random_uuid(),'{"hosting": {"production_origin": "https://luteratech.com", "redirect_origins": ["https://www.luteratech.com", "https://luteratech.com.ng", "https://www.luteratech.com.ng"]}, "company": {"name": "Lutera Technology Ltd", "legal_name": "Lutera Technology Ltd", "registration_completed": true, "registration_number": "", "email": "chimaster010@gmail.com", "phone": "+2349026276130", "display_phone": "+234 902 6276 130", "whatsapp": "https://wa.me/2349026276130", "street_address": "No. 7, Mahatma Gandhi Street, Area 11, Garki", "city": "Abuja", "state": "FCT", "country": "NG", "lga": "AMAC (Abuja Municipal Area Council)", "house_number": "No. 7", "nature_of_business": "Information Technology and Artificial Intelligence (AI) Solutions; Technology Consultancy and IT Consulting Services; AI Agent Development and Business Process Automation; Software Design, Development and Implementation; Data Analytics; Systems Integration; Cloud-Based Solutions; Procurement, Importation, Exportation, Wholesale and Retail Supply of Computer Hardware, Accessories and Peripherals; Computer Installation, Maintenance and Technical Support; and Related Technology Services.", "brand_name": "Lutera"}, "services": [{"key": "procurement", "slug": "it-procurement", "title": "IT procurement & sourcing", "icon": "procurement", "image": "laptop", "alt": "Business laptop illustrating an equipment specification", "description": "Equipment sourced against your requirements, from specification and pre-shipment inspection to agreed delivery."}, {"key": "hardware", "slug": "hardware", "title": "Computer hardware & equipment", "icon": "hardware", "image": "desktop", "alt": "Desktop computer, keyboard and mouse", "description": "Business laptops, desktops, servers, networking equipment and the accessories that complete your setup."}, {"key": "consulting", "slug": "consulting", "title": "Technology & IT consulting", "icon": "consulting", "image": "consulting", "alt": "A team discussing project requirements with laptops around a shared table", "description": "Clear advice on technology priorities, specifications and implementation, shaped around your organisation."}, {"key": "support", "slug": "technical-support", "title": "Installation & technical support", "icon": "support", "image": "support", "alt": "Technician installing a memory module in computer equipment", "description": "Computer labs, installation, commissioning and maintenance, with a named support contact after handover."}, {"key": "ai", "slug": "ai-automation", "title": "AI agents & automation", "icon": "automation", "image": "ai", "alt": "A team mapping the stages of a business workflow", "description": "AI agents and business process automation for workflows that are currently handled by hand."}, {"key": "software", "slug": "software-development", "title": "Software development", "icon": "software", "image": "software", "alt": "Software source code displayed on a development computer", "description": "Business software designed, developed and implemented to an agreed scope, with your users in mind."}, {"key": "data", "slug": "data-analytics", "title": "Data analytics", "icon": "data", "image": "data", "alt": "Analytics dashboard displaying business charts and metrics", "description": "Useful reporting and analysis built around your business questions, data sources and decisions."}, {"key": "cloud", "slug": "cloud-integration", "title": "Cloud & systems integration", "icon": "cloud", "image": "servers", "alt": "Connected racks of server equipment", "description": "Cloud-based systems and practical integrations that connect the applications your organisation uses."}], "commitments": [{"title": "A clear specification", "description": "We source against an agreed specification and carry out pre-shipment inspections."}, {"title": "Support after handover", "description": "Locally held spare parts and a named support contact for the equipment we supply."}, {"title": "Written warranty terms", "description": "Parts warranty starts from site acceptance. Duration and coverage are agreed in writing."}]}'::jsonb);
insert into public.work_members(email,role) values('chimaster010@gmail.com','owner');

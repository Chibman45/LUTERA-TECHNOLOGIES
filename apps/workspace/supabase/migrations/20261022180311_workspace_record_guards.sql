-- Preserve record identifiers and bind access to the still-approved verified email.
create or replace function private.work_allowed(area text) returns boolean
language sql stable security definer set search_path = '' as $$
 select coalesce(
   (auth.jwt()->>'aal'='aal2')
   and exists(select 1 from auth.sessions s where s.id::text=auth.jwt()->>'session_id' and s.user_id=auth.uid()
              and s.created_at > now()-interval '12 hours' and (s.not_after is null or s.not_after>now()))
   and exists(select 1 from auth.mfa_factors f where f.user_id=auth.uid() and f.status='verified' and f.factor_type='totp')
   and exists(select 1 from public.work_members m join auth.users u on u.id=m.user_id and lower(u.email)=m.email and u.email_confirmed_at is not null where m.user_id=auth.uid() and m.active and (
       area='session' or m.role='owner' or (m.role='admin' and area not in ('members','backup'))
       or (m.role='editor' and area='content') or (m.role='finance' and area='finance') or (m.role='designer' and area='staff')
   )),false);
$$;

create or replace function private.work_touch() returns trigger language plpgsql set search_path='' as $$
begin if new.id is distinct from old.id then raise exception 'Record identifiers are immutable';end if; new.version=old.version+1; new.updated_at=now(); return new; end; $$;

create or replace function private.work_document_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare subtotal numeric:=0; tax numeric; item jsonb; company jsonb; seq integer; yr integer; source public.work_documents; received bigint; record_date date;
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
   if new.id is distinct from old.id then raise exception 'Record identifiers are immutable';end if;
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
    or jsonb_typeof(new.payload->'customer') is distinct from 'object' or jsonb_typeof(new.payload#>'{customer,name}') is distinct from 'string' or jsonb_typeof(new.payload->'currency') is distinct from 'string' or jsonb_typeof(new.payload->'date') is distinct from 'string' or jsonb_typeof(new.payload->'valid_until') is distinct from 'string' or jsonb_typeof(new.payload->'payment_confirmed') is distinct from 'boolean' or jsonb_typeof(new.payload->'source_id') is distinct from 'string' or jsonb_typeof(new.payload->'payment_method') is distinct from 'string' or jsonb_typeof(new.payload->'payment_reference') is distinct from 'string' or jsonb_typeof(new.payload->'notes') is distinct from 'string' or new.payload->>'currency' not in ('NGN','USD','GBP','EUR') or length(trim(new.payload#>>'{customer,name}')) not between 1 and 160
    or jsonb_typeof(new.payload->'items') is distinct from 'array' or jsonb_array_length(new.payload->'items') not between 1 and 40 then raise exception 'Invalid document'; end if;
 record_date=(new.payload->>'date')::date;
 if to_char(record_date,'YYYY-MM-DD')<>new.payload->>'date' or (new.kind='receipt' and new.status='issued' and record_date>current_date) then raise exception 'Invalid dates';end if;
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
alter table public.work_staff add constraint work_staff_payload_shape check (coalesce(
 jsonb_typeof(payload)='object' and payload ?& array['name','title','staff_number','department','email','phone','issued_on','expires_on','active','photo_path']
 and jsonb_typeof(payload->'name')='string' and length(trim(payload->>'name')) between 1 and 140
 and jsonb_typeof(payload->'title')='string' and length(trim(payload->>'title')) between 1 and 120
 and jsonb_typeof(payload->'staff_number')='string' and length(trim(payload->>'staff_number')) between 1 and 40
 and jsonb_typeof(payload->'active')='boolean' and jsonb_typeof(payload->'photo_path')='string'
 and ((payload->>'photo_path')='' or (payload->>'photo_path') ~ '^[0-9a-f-]{36}\.jpg$')
 and (payload->>'issued_on')::date is not null
 and ((payload->>'expires_on')='' or (payload->>'expires_on')::date >= (payload->>'issued_on')::date)
,false));

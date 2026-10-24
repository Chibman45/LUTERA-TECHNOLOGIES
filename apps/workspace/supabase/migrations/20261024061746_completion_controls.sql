-- Additive completion controls. All writes use MFA-checked, audited RPCs.
alter table public.work_audit add column detail jsonb not null default '{}'::jsonb check(length(detail::text)<=3000);
alter table public.work_customers add column legal_name text not null default '' check(length(legal_name)<=200), add column tags text not null default '' check(length(tags)<=500);
alter table public.work_enquiries add column priority text not null default 'normal' check(priority in ('low','normal','high','urgent')), add column next_action text not null default '' check(length(next_action)<=500), add column evidence_id uuid references public.work_files(id);
alter table public.work_expenses add column project_id uuid references public.work_cases(id),add column cost_center text not null default '' check(length(cost_center)<=100),add column purchase_id uuid references public.work_commercial(id);
alter table public.work_supplier_payments add column reversed_at timestamptz,add column reversal_reason text not null default '' check(length(reversal_reason)<=500),add column reversal_evidence_id uuid references public.work_files(id),add column reversed_by uuid references auth.users(id);
alter table public.work_bank_lines add column supplier_payment_id uuid unique references public.work_supplier_payments(id),add column refund_id uuid unique references public.work_refunds(id),add constraint work_bank_one_match check(num_nonnulls(payment_id,supplier_payment_id,refund_id)<=1);
alter table public.work_messages add column paused boolean not null default false,add column related_id uuid;
create table private.work_message_statements(message_id uuid primary key references public.work_messages(id),snapshot jsonb not null check(length(snapshot::text)<=250000));
alter table private.work_message_statements enable row level security;revoke all on private.work_message_statements from public,anon,authenticated;
create table public.work_locations(id uuid primary key default gen_random_uuid(),name text not null unique check(length(trim(name)) between 1 and 120),archived boolean not null default false,version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.work_inspections(id uuid primary key default gen_random_uuid(),purchase_id uuid not null references public.work_commercial(id),line_id uuid references public.work_commercial_lines(id),stage text not null check(stage in ('pre-shipment','receiving','discrepancy')),result text not null check(result in ('pending','accepted','rejected')),quantity integer not null check(quantity between 1 and 1000000),notes text not null check(length(trim(notes)) between 5 and 3000),evidence_id uuid not null references public.work_files(id),created_by uuid not null default auth.uid() references auth.users(id),created_at timestamptz not null default now());
create table public.work_stock_holds(id uuid primary key default gen_random_uuid(),movement_id uuid not null references public.work_stock(id),quantity integer not null check(quantity between 1 and 1000000),reason text not null check(length(trim(reason)) between 5 and 500),evidence_id uuid references public.work_files(id),released_at timestamptz,release_reason text not null default '',created_by uuid not null default auth.uid() references auth.users(id),created_at timestamptz not null default now());
create table public.work_order_progress(id uuid primary key default gen_random_uuid(),order_id uuid not null unique references public.work_commercial(id),status text not null check(status in ('approved','in_progress','fulfilled','closed')),delivery_address text not null default '' check(length(delivery_address)<=600),receiver text not null default '' check(length(receiver)<=160),evidence_id uuid references public.work_files(id),reason text not null check(length(trim(reason)) between 5 and 500),version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.work_order_cancellations(id uuid primary key default gen_random_uuid(),line_id uuid not null references public.work_commercial_lines(id),quantity integer not null check(quantity between 1 and 1000000),reason text not null check(length(trim(reason)) between 5 and 500),evidence_id uuid not null references public.work_files(id),created_by uuid not null default auth.uid() references auth.users(id),created_at timestamptz not null default now());
create table public.work_maintenance_visits(id uuid primary key default gen_random_uuid(),case_id uuid not null references public.work_cases(id),asset_id uuid references public.work_assets(id),assigned_to uuid references auth.users(id),scheduled_on date not null,completed_on date,status text not null default 'scheduled' check(status in ('scheduled','completed','cancelled')),notes text not null default '' check(length(notes)<=3000),evidence_id uuid references public.work_files(id),version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),check(status<>'completed' or completed_on is not null and evidence_id is not null));
create table public.work_supplier_bank(id uuid primary key default gen_random_uuid(),supplier_id uuid not null references public.work_suppliers(id),bank_name text not null check(length(trim(bank_name)) between 1 and 160),account_name text not null check(length(trim(account_name)) between 1 and 200),account_number text not null check(length(trim(account_number)) between 4 and 80),currency text not null check(currency in ('NGN','USD','GBP','EUR')),status text not null default 'pending' check(status in ('pending','active','superseded','rejected')),evidence_id uuid not null references public.work_files(id),reason text not null check(length(trim(reason)) between 5 and 500),proposed_by uuid not null default auth.uid() references auth.users(id),approved_by uuid references auth.users(id),created_at timestamptz not null default now());
create unique index work_one_supplier_bank on public.work_supplier_bank(supplier_id,currency) where status='active';
create table public.work_cost_allocations(id uuid primary key default gen_random_uuid(),expense_id uuid not null references public.work_expenses(id),purchase_line_id uuid not null references public.work_commercial_lines(id),amount_minor bigint not null check(amount_minor>0),currency text not null check(currency in ('NGN','USD','GBP','EUR')),basis text not null check(length(trim(basis)) between 5 and 500),created_by uuid not null default auth.uid() references auth.users(id),created_at timestamptz not null default now());
create table public.work_operating_policy(id integer primary key default 1 check(id=1),financial_retention_days integer check(financial_retention_days between 1 and 36500),communication_retention_days integer check(communication_retention_days between 1 and 36500),staff_retention_days integer check(staff_retention_days between 1 and 36500),backup_retention_days integer check(backup_retention_days between 1 and 36500),recovery_point_hours integer check(recovery_point_hours between 1 and 168),recovery_time_hours integer check(recovery_time_hours between 1 and 168),require_approval boolean not null default true check(require_approval),notes text not null default '' check(length(notes)<=3000),version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
insert into public.work_operating_policy(id) values(1);
create table public.work_approval_rules(id uuid primary key default gen_random_uuid(),kind text not null check(kind in ('purchase','discount','credit','refund')),currency text not null check(currency in ('NGN','USD','GBP','EUR')),threshold_minor bigint check(threshold_minor between 0 and 1000000000000),approver_id uuid references auth.users(id),notes text not null default '' check(length(notes)<=1000),version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(kind,currency));
alter table public.work_approval_rules enable row level security;revoke all on public.work_approval_rules from public,anon,authenticated;grant select on public.work_approval_rules to authenticated;
create policy work_approval_rules_owner on public.work_approval_rules for select to authenticated using((select private.work_allowed('members')));
create trigger work_approval_rules_audit after insert or update on public.work_approval_rules for each row execute function private.work_audit_change();
create trigger work_approval_rules_touch before update on public.work_approval_rules for each row execute function private.work_touch();
create index work_approval_rules_approver_idx on public.work_approval_rules(approver_id);
create function private.work_approval_gate(k text,ccy text,amount bigint) returns void language plpgsql security definer set search_path='' as $$
declare rule public.work_approval_rules;
begin
 perform pg_advisory_xact_lock(hashtextextended(k||':'||ccy,41));
 select * into rule from public.work_approval_rules where kind=k and currency=ccy;
 if rule.threshold_minor is not null and amount>=rule.threshold_minor and not private.work_allowed('members') and auth.uid() is distinct from rule.approver_id then raise exception using errcode='42501',message='BUSINESS: This amount requires the configured approver or company owner.';end if;
end;$$;
revoke all on function private.work_approval_gate(text,text,bigint) from public,anon,authenticated;
create table private.work_ops_requests(request_key uuid primary key,actor uuid not null references auth.users(id),fingerprint text not null,result jsonb not null,created_at timestamptz not null default now());
alter table private.work_ops_requests enable row level security;revoke all on private.work_ops_requests from public,anon,authenticated;
alter table public.work_locations enable row level security;revoke all on public.work_locations from public,anon,authenticated;grant select on public.work_locations to authenticated;
create policy work_locations_read on public.work_locations for select to authenticated using((select private.work_ops_allowed('inventory')));
create trigger work_locations_audit after insert or update or delete on public.work_locations for each row execute function private.work_audit_change();
create trigger work_locations_touch before update on public.work_locations for each row execute function private.work_touch();
alter table public.work_inspections enable row level security;revoke all on public.work_inspections from public,anon,authenticated;grant select on public.work_inspections to authenticated;
create policy work_inspections_read on public.work_inspections for select to authenticated using(exists(select 1 from public.work_commercial c where c.id=purchase_id and private.work_ops_allowed('procurement',c.assigned_to)));
create trigger work_inspections_audit after insert or update or delete on public.work_inspections for each row execute function private.work_audit_change();
alter table public.work_stock_holds enable row level security;revoke all on public.work_stock_holds from public,anon,authenticated;grant select on public.work_stock_holds to authenticated;
create policy work_stock_holds_read on public.work_stock_holds for select to authenticated using((select private.work_ops_allowed('inventory')));
create trigger work_stock_holds_audit after insert or update or delete on public.work_stock_holds for each row execute function private.work_audit_change();
alter table public.work_order_progress enable row level security;revoke all on public.work_order_progress from public,anon,authenticated;grant select on public.work_order_progress to authenticated;
create policy work_order_progress_read on public.work_order_progress for select to authenticated using(exists(select 1 from public.work_commercial c where c.id=order_id and private.work_ops_allowed('sales',c.assigned_to)));
create trigger work_order_progress_audit after insert or update or delete on public.work_order_progress for each row execute function private.work_audit_change();
create trigger work_order_progress_touch before update on public.work_order_progress for each row execute function private.work_touch();
alter table public.work_order_cancellations enable row level security;revoke all on public.work_order_cancellations from public,anon,authenticated;grant select on public.work_order_cancellations to authenticated;
create policy work_order_cancellations_read on public.work_order_cancellations for select to authenticated using(exists(select 1 from public.work_commercial_lines l join public.work_commercial c on c.id=l.record_id where l.id=line_id and private.work_ops_allowed('sales',c.assigned_to)));
create trigger work_order_cancellations_audit after insert or update or delete on public.work_order_cancellations for each row execute function private.work_audit_change();
alter table public.work_maintenance_visits enable row level security;revoke all on public.work_maintenance_visits from public,anon,authenticated;grant select on public.work_maintenance_visits to authenticated;
create policy work_maintenance_visits_read on public.work_maintenance_visits for select to authenticated using(private.work_case_allowed(case_id));
create trigger work_maintenance_visits_audit after insert or update or delete on public.work_maintenance_visits for each row execute function private.work_audit_change();
create trigger work_maintenance_visits_touch before update on public.work_maintenance_visits for each row execute function private.work_touch();
alter table public.work_supplier_bank enable row level security;revoke all on public.work_supplier_bank from public,anon,authenticated;grant select on public.work_supplier_bank to authenticated;
create policy work_supplier_bank_read on public.work_supplier_bank for select to authenticated using((select private.work_ops_allowed('finance',null,'approve') or private.work_allowed('members')));
create trigger work_supplier_bank_audit after insert or update or delete on public.work_supplier_bank for each row execute function private.work_audit_change();
alter table public.work_cost_allocations enable row level security;revoke all on public.work_cost_allocations from public,anon,authenticated;grant select on public.work_cost_allocations to authenticated;
create policy work_cost_allocations_read on public.work_cost_allocations for select to authenticated using((select private.work_ops_allowed('finance')));
create trigger work_cost_allocations_audit after insert or update or delete on public.work_cost_allocations for each row execute function private.work_audit_change();
alter table public.work_operating_policy enable row level security;revoke all on public.work_operating_policy from public,anon,authenticated;grant select on public.work_operating_policy to authenticated;
create policy work_operating_policy_read on public.work_operating_policy for select to authenticated using((select private.work_allowed('members')));
create trigger work_operating_policy_audit after insert or update or delete on public.work_operating_policy for each row execute function private.work_audit_change();
create trigger work_operating_policy_touch before update on public.work_operating_policy for each row execute function private.work_touch();
create index work_enquiries_evidence_id_completion_idx on public.work_enquiries(evidence_id);
create index work_expenses_project_id_completion_idx on public.work_expenses(project_id);
create index work_expenses_purchase_id_completion_idx on public.work_expenses(purchase_id);
create index work_supplier_payments_reversal_evidence_id_completion_idx on public.work_supplier_payments(reversal_evidence_id);
create index work_supplier_payments_reversed_by_completion_idx on public.work_supplier_payments(reversed_by);
create index work_inspections_purchase_id_completion_idx on public.work_inspections(purchase_id);
create index work_inspections_line_id_completion_idx on public.work_inspections(line_id);
create index work_inspections_evidence_id_completion_idx on public.work_inspections(evidence_id);
create index work_inspections_created_by_completion_idx on public.work_inspections(created_by);
create index work_stock_holds_movement_id_completion_idx on public.work_stock_holds(movement_id);
create index work_stock_holds_evidence_id_completion_idx on public.work_stock_holds(evidence_id);
create index work_stock_holds_created_by_completion_idx on public.work_stock_holds(created_by);
create index work_order_progress_evidence_id_completion_idx on public.work_order_progress(evidence_id);
create index work_order_cancellations_line_id_completion_idx on public.work_order_cancellations(line_id);
create index work_order_cancellations_evidence_id_completion_idx on public.work_order_cancellations(evidence_id);
create index work_order_cancellations_created_by_completion_idx on public.work_order_cancellations(created_by);
create index work_maintenance_visits_case_id_completion_idx on public.work_maintenance_visits(case_id);
create index work_maintenance_visits_asset_id_completion_idx on public.work_maintenance_visits(asset_id);
create index work_maintenance_visits_assigned_to_completion_idx on public.work_maintenance_visits(assigned_to);
create index work_maintenance_visits_evidence_id_completion_idx on public.work_maintenance_visits(evidence_id);
create index work_supplier_bank_supplier_id_completion_idx on public.work_supplier_bank(supplier_id);
create index work_supplier_bank_evidence_id_completion_idx on public.work_supplier_bank(evidence_id);
create index work_supplier_bank_proposed_by_completion_idx on public.work_supplier_bank(proposed_by);
create index work_supplier_bank_approved_by_completion_idx on public.work_supplier_bank(approved_by);
create index work_cost_allocations_expense_id_completion_idx on public.work_cost_allocations(expense_id);
create index work_cost_allocations_purchase_line_id_completion_idx on public.work_cost_allocations(purchase_line_id);
create index work_cost_allocations_created_by_completion_idx on public.work_cost_allocations(created_by);
create index work_ops_requests_actor_idx on private.work_ops_requests(actor);
create or replace function private.work_master(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare d jsonb=c->'data'; k text=c->>'entity'; rid uuid=coalesce(nullif(c->>'id','')::uuid,gen_random_uuid()); v integer=coalesce((c->>'version')::integer,0); a uuid; result jsonb; oldrow record;
begin
 if length(c::text)>40000 then raise exception 'BUSINESS: Record is too large.';end if;
 if k='customers' then
  select assigned_to into a from public.work_customers where id=rid;
  perform private.work_require('sales',coalesce(a,auth.uid()));
  perform private.work_assignment(nullif(d->>'assigned_to','')::uuid);
  if v=0 then insert into public.work_customers(id,name,email,phone,address,delivery_address,sector,tax_id,assigned_to,legal_name,tags) values(rid,d->>'name',coalesce(d->>'email',''),coalesce(d->>'phone',''),coalesce(d->>'address',''),coalesce(d->>'delivery_address',''),coalesce(d->>'sector',''),coalesce(d->>'tax_id',''),coalesce(nullif(d->>'assigned_to','')::uuid,auth.uid()),coalesce(d->>'legal_name',''),coalesce(d->>'tags',''));
  else update public.work_customers set legal_name=coalesce(d->>'legal_name',''),tags=coalesce(d->>'tags',''),name=d->>'name',email=coalesce(d->>'email',''),phone=coalesce(d->>'phone',''),address=coalesce(d->>'address',''),delivery_address=coalesce(d->>'delivery_address',''),sector=coalesce(d->>'sector',''),tax_id=coalesce(d->>'tax_id',''),archived=coalesce((d->>'archived')::boolean,false),assigned_to=nullif(d->>'assigned_to','')::uuid where id=rid and version=v; if not found then raise exception 'BUSINESS: Record changed. Refresh before saving.';end if;end if;
  select to_jsonb(t) into result from public.work_customers t where id=rid;
 elsif k='contacts' then
  select assigned_to into a from public.work_customers where id=(d->>'customer_id')::uuid;perform private.work_require('sales',a);
  if v=0 then insert into public.work_contacts(id,customer_id,name,email,phone,job_title) values(rid,(d->>'customer_id')::uuid,d->>'name',coalesce(d->>'email',''),coalesce(d->>'phone',''),coalesce(d->>'job_title',''));
  else update public.work_contacts set name=d->>'name',email=coalesce(d->>'email',''),phone=coalesce(d->>'phone',''),job_title=coalesce(d->>'job_title','') where id=rid and version=v and customer_id=(d->>'customer_id')::uuid;if not found then raise exception 'BUSINESS: Record changed. Refresh before saving.';end if;end if;
  select to_jsonb(t) into result from public.work_contacts t where id=rid;
 elsif k='enquiries' then
  select assigned_to into a from public.work_enquiries where id=rid; perform private.work_require('sales',coalesce(a,auth.uid())); perform private.work_assignment(nullif(d->>'assigned_to','')::uuid);
  if nullif(d->>'customer_id','') is not null and not private.work_customer_allowed((d->>'customer_id')::uuid) then raise exception 'BUSINESS: Customer access required.';end if;
  if v=0 then insert into public.work_enquiries(id,reference,name,email,phone,subject,message,customer_id,assigned_to,follow_up,services,priority,next_action,evidence_id) values(rid,private.work_number('ENQ'),d->>'name',coalesce(d->>'email',''),coalesce(d->>'phone',''),d->>'subject',coalesce(d->>'message',''),nullif(d->>'customer_id','')::uuid,coalesce(nullif(d->>'assigned_to','')::uuid,auth.uid()),nullif(d->>'follow_up','')::date,array(select jsonb_array_elements_text(coalesce(d->'services','[]'))),coalesce(d->>'priority','normal'),coalesce(d->>'next_action',''),nullif(d->>'evidence_id','')::uuid);
  else update public.work_enquiries set priority=coalesce(d->>'priority','normal'),next_action=coalesce(d->>'next_action',''),evidence_id=nullif(d->>'evidence_id','')::uuid,name=d->>'name',email=coalesce(d->>'email',''),phone=coalesce(d->>'phone',''),subject=d->>'subject',message=coalesce(d->>'message',''),customer_id=nullif(d->>'customer_id','')::uuid,assigned_to=nullif(d->>'assigned_to','')::uuid,status=d->>'status',follow_up=nullif(d->>'follow_up','')::date,loss_reason=coalesce(d->>'loss_reason',''),services=array(select jsonb_array_elements_text(coalesce(d->'services','[]'))) where id=rid and version=v;if not found then raise exception 'BUSINESS: Record changed. Refresh before saving.';end if;end if;
  if d->>'status'='lost' and length(trim(coalesce(d->>'loss_reason','')))<5 then raise exception 'BUSINESS: Record a loss reason.';end if;
  if nullif(d->>'evidence_id','') is not null then perform private.work_evidence((d->>'evidence_id')::uuid,'sales');end if;
  select to_jsonb(t) into result from public.work_enquiries t where id=rid;
 elsif k='opportunities' then
  select assigned_to into a from public.work_opportunities where id=rid;perform private.work_require('sales',coalesce(a,auth.uid()));perform private.work_assignment(nullif(d->>'assigned_to','')::uuid);
  if not private.work_customer_allowed((d->>'customer_id')::uuid) then raise exception 'BUSINESS: Customer access required.';end if;
  if v=0 then insert into public.work_opportunities(id,customer_id,enquiry_id,title,stage,value_minor,currency,expected_close,assigned_to,notes) values(rid,(d->>'customer_id')::uuid,nullif(d->>'enquiry_id','')::uuid,d->>'title',coalesce(d->>'stage','qualified'),coalesce((d->>'value_minor')::bigint,0),coalesce(d->>'currency','NGN'),nullif(d->>'expected_close','')::date,coalesce(nullif(d->>'assigned_to','')::uuid,auth.uid()),coalesce(d->>'notes',''));
  else update public.work_opportunities set title=d->>'title',stage=d->>'stage',value_minor=(d->>'value_minor')::bigint,currency=d->>'currency',expected_close=nullif(d->>'expected_close','')::date,assigned_to=nullif(d->>'assigned_to','')::uuid,notes=coalesce(d->>'notes','') where id=rid and version=v and customer_id=(d->>'customer_id')::uuid;if not found then raise exception 'BUSINESS: Record changed. Refresh before saving.';end if;end if;
  select to_jsonb(t) into result from public.work_opportunities t where id=rid;
 elsif k='suppliers' then
  perform private.work_require('procurement');
  if v=0 then insert into public.work_suppliers(id,name,email,phone,address,categories,terms) values(rid,d->>'name',coalesce(d->>'email',''),coalesce(d->>'phone',''),coalesce(d->>'address',''),coalesce(d->>'categories',''),coalesce(d->>'terms',''));
  else update public.work_suppliers set name=d->>'name',email=coalesce(d->>'email',''),phone=coalesce(d->>'phone',''),address=coalesce(d->>'address',''),categories=coalesce(d->>'categories',''),terms=coalesce(d->>'terms',''),archived=coalesce((d->>'archived')::boolean,false) where id=rid and version=v;if not found then raise exception 'BUSINESS: Record changed. Refresh before saving.';end if;end if;
  select to_jsonb(t) into result from public.work_suppliers t where id=rid;
 elsif k='items' then
  if not private.work_ops_allowed('sales',null,'write') and not private.work_ops_allowed('inventory',null,'write') and not private.work_ops_allowed('procurement',null,'write') then raise exception using errcode='42501',message='BUSINESS: Catalogue permission required.';end if;
  if v=0 then insert into public.work_items(id,sku,name,description,kind,unit,unit_minor,currency,serialized) values(rid,d->>'sku',d->>'name',coalesce(d->>'description',''),d->>'kind',coalesce(d->>'unit','unit'),coalesce((d->>'unit_minor')::bigint,0),coalesce(d->>'currency','NGN'),coalesce((d->>'serialized')::boolean,false));
  else
   if exists(select 1 from public.work_stock where item_id=rid) and exists(select 1 from public.work_items where id=rid and (kind<>d->>'kind' or serialized<>coalesce((d->>'serialized')::boolean,false))) then raise exception 'BUSINESS: Stock item type and serial policy cannot change after movements.';end if;
   update public.work_items set sku=d->>'sku',name=d->>'name',description=coalesce(d->>'description',''),kind=d->>'kind',unit=coalesce(d->>'unit','unit'),unit_minor=(d->>'unit_minor')::bigint,currency=d->>'currency',serialized=coalesce((d->>'serialized')::boolean,false),archived=coalesce((d->>'archived')::boolean,false) where id=rid and version=v;if not found then raise exception 'BUSINESS: Record changed. Refresh before saving.';end if;
  end if;
  select to_jsonb(t) into result from public.work_items t where id=rid;
 elsif k='cases' then
  select assigned_to into a from public.work_cases where id=rid;perform private.work_require(case when d->>'kind'='project' then 'projects' else 'support' end,coalesce(a,auth.uid())); perform private.work_assignment(nullif(d->>'assigned_to','')::uuid);
  if not private.work_customer_allowed((d->>'customer_id')::uuid) then raise exception 'BUSINESS: Customer access required.';end if;
  if d->>'status'='completed' and d->>'kind'='project' then perform private.work_evidence(nullif(d->>'acceptance_id','')::uuid,'projects');if length(trim(coalesce(d->>'accepted_by','')))<2 then raise exception 'BUSINESS: Record the customer acceptance name.';end if;end if;
  if nullif(d->>'order_id','') is not null and not exists(select 1 from public.work_commercial where id=(d->>'order_id')::uuid and kind='order' and status='issued' and customer_id=(d->>'customer_id')::uuid) then raise exception 'BUSINESS: Link an issued order for the same customer.';end if;
  if v=0 then insert into public.work_cases(id,kind,reference,customer_id,order_id,title,description,category,priority,assigned_to,starts_on,due_on,response_due_at) values(rid,d->>'kind',private.work_number(case when d->>'kind'='project' then 'PRJ' when d->>'kind'='ticket' then 'TKT' else 'MNT' end),(d->>'customer_id')::uuid,nullif(d->>'order_id','')::uuid,d->>'title',coalesce(d->>'description',''),coalesce(d->>'category',''),coalesce(d->>'priority','normal'),coalesce(nullif(d->>'assigned_to','')::uuid,auth.uid()),nullif(d->>'starts_on','')::date,nullif(d->>'due_on','')::date,nullif(d->>'response_due_at','')::timestamptz);
  else update public.work_cases set title=d->>'title',description=coalesce(d->>'description',''),category=coalesce(d->>'category',''),priority=d->>'priority',assigned_to=nullif(d->>'assigned_to','')::uuid,status=d->>'status',starts_on=nullif(d->>'starts_on','')::date,due_on=nullif(d->>'due_on','')::date,response_due_at=nullif(d->>'response_due_at','')::timestamptz,responded_at=nullif(d->>'responded_at','')::timestamptz,acceptance_id=nullif(d->>'acceptance_id','')::uuid,accepted_by=coalesce(d->>'accepted_by','') where id=rid and version=v and kind=d->>'kind' and customer_id=(d->>'customer_id')::uuid;if not found then raise exception 'BUSINESS: Record changed. Refresh before saving.';end if;end if;
  select to_jsonb(t) into result from public.work_cases t where id=rid;
 elsif k='tasks' then
  select * into oldrow from public.work_cases where id=(d->>'case_id')::uuid;
  if not found then raise exception 'BUSINESS: Project or ticket not found.';end if;
  if v>0 and not private.work_ops_allowed(case when oldrow.kind='project' then 'projects' else 'support' end,oldrow.assigned_to,'write') then
   select to_jsonb(t) into result from public.work_tasks t where t.id=rid and t.case_id=oldrow.id and t.assigned_to=auth.uid() and t.version=v for update;
   if result is null or not private.work_ops_allowed(case when oldrow.kind='project' then 'projects' else 'support' end,auth.uid(),'write') then raise exception using errcode='42501',message='BUSINESS: Assigned task editing access required.';end if;
   if d->>'title' is distinct from result->>'title' or nullif(d->>'assigned_to','')::uuid is distinct from (result->>'assigned_to')::uuid or nullif(d->>'due_on','') is distinct from result->>'due_on' or coalesce((d->>'billable')::boolean,false) is distinct from (result->>'billable')::boolean or nullif(d->>'depends_on','') is distinct from result->>'depends_on' or coalesce((d->>'customer_visible')::boolean,false) is distinct from (result->>'customer_visible')::boolean then raise exception 'BUSINESS: Only the project lead can change task assignments, dates, billing or scope.';end if;
   update public.work_tasks set description=coalesce(d->>'description',''),status=d->>'status' where id=rid returning to_jsonb(work_tasks.*) into result;return result;
  end if;
  perform private.work_require(case when oldrow.kind='project' then 'projects' else 'support' end,oldrow.assigned_to);perform private.work_assignment(nullif(d->>'assigned_to','')::uuid);
  if v=0 then insert into public.work_tasks(id,case_id,title,description,assigned_to,due_on,billable,depends_on,customer_visible) values(rid,(d->>'case_id')::uuid,d->>'title',coalesce(d->>'description',''),nullif(d->>'assigned_to','')::uuid,nullif(d->>'due_on','')::date,coalesce((d->>'billable')::boolean,false),nullif(d->>'depends_on','')::uuid,coalesce((d->>'customer_visible')::boolean,false));
  else update public.work_tasks set title=d->>'title',description=coalesce(d->>'description',''),assigned_to=nullif(d->>'assigned_to','')::uuid,due_on=nullif(d->>'due_on','')::date,status=d->>'status',billable=coalesce((d->>'billable')::boolean,false),depends_on=nullif(d->>'depends_on','')::uuid,customer_visible=coalesce((d->>'customer_visible')::boolean,false) where id=rid and version=v and case_id=(d->>'case_id')::uuid;if not found then raise exception 'BUSINESS: Record changed. Refresh before saving.';end if;end if;
  select to_jsonb(t) into result from public.work_tasks t where id=rid;
 else raise exception 'BUSINESS: Unsupported record type.';
 end if;
 return result;
end;$$;
create or replace function private.work_expense(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare d jsonb=c->'data';r public.work_expenses;rid uuid=coalesce(nullif(c->>'id','')::uuid,gen_random_uuid());result jsonb;used bigint;amount bigint;rate bigint;targetccy text;cost bigint;
begin
 perform private.work_require('finance');
 if c->>'action'='save' then
  select * into r from public.work_expenses where id=rid for update;
  if r.id is not null and (r.status<>'draft' or r.version<>(c->>'version')::integer) then raise exception 'BUSINESS: Only an unchanged draft expense can be edited.';end if;
  perform private.work_evidence((d->>'evidence_id')::uuid,'finance');
  targetccy=null;
  if nullif(d->>'order_id','') is not null then select currency into targetccy from public.work_commercial where id=(d->>'order_id')::uuid and kind='order' and status='issued';if targetccy is null then raise exception 'BUSINESS: Link an issued sales order.';end if;end if;
  targetccy=coalesce(targetccy,d->>'currency');rate=1000000;
  if targetccy<>d->>'currency' then
   rate=(d->>'fx_rate_micros')::bigint;
   if rate is null or rate<=0 or nullif(d->>'fx_date','') is null or (d->>'fx_date')::date>current_date or length(trim(coalesce(d->>'fx_reference','')))<5 then raise exception 'BUSINESS: Supply the approved exchange rate, date and source for this order currency.';end if;
  end if;
  cost=round((d->>'amount_minor')::numeric*rate/1000000);

  if r.id is null then insert into public.work_expenses(id,supplier_id,order_id,title,category,amount_minor,currency,incurred_on,due_on,evidence_id,cost_minor,cost_currency,fx_rate_micros,fx_date,fx_reference,project_id,cost_center,purchase_id) values(rid,nullif(d->>'supplier_id','')::uuid,nullif(d->>'order_id','')::uuid,d->>'title',coalesce(d->>'category',''),(d->>'amount_minor')::bigint,d->>'currency',(d->>'incurred_on')::date,nullif(d->>'due_on','')::date,(d->>'evidence_id')::uuid,cost,targetccy,rate,nullif(d->>'fx_date','')::date,coalesce(d->>'fx_reference',''),nullif(d->>'project_id','')::uuid,coalesce(d->>'cost_center',''),nullif(d->>'purchase_id','')::uuid);
  else update public.work_expenses set project_id=nullif(d->>'project_id','')::uuid,cost_center=coalesce(d->>'cost_center',''),purchase_id=nullif(d->>'purchase_id','')::uuid,supplier_id=nullif(d->>'supplier_id','')::uuid,order_id=nullif(d->>'order_id','')::uuid,cost_minor=cost,cost_currency=targetccy,fx_rate_micros=rate,fx_date=nullif(d->>'fx_date','')::date,fx_reference=coalesce(d->>'fx_reference',''),title=d->>'title',category=coalesce(d->>'category',''),amount_minor=(d->>'amount_minor')::bigint,currency=d->>'currency',incurred_on=(d->>'incurred_on')::date,due_on=nullif(d->>'due_on','')::date,evidence_id=(d->>'evidence_id')::uuid where id=rid;end if;
 elsif c->>'action'='submit' then
  update public.work_expenses set status='submitted' where id=rid and version=(c->>'version')::integer and status='draft';if not found then raise exception 'BUSINESS: Expense changed or is not a draft.';end if;
 elsif c->>'action' in ('approve','reject') then
  perform private.work_require('finance',null,'approve');
  select * into r from public.work_expenses where id=rid for update;
  if r.id is null or r.status<>'submitted' or r.version<>(c->>'version')::integer then raise exception 'BUSINESS: Review the latest submitted expense.';end if;
  if r.created_by=auth.uid() and not private.work_allowed('members') then raise exception 'BUSINESS: Another authorized colleague must approve your expense.';end if;
  insert into public.work_decisions(expense_id,action,record_version,reason) values(rid,c->>'action',r.version,c->>'reason');
  update public.work_expenses set status=case when c->>'action'='approve' then 'approved' else 'rejected' end where id=rid;
 elsif c->>'action'='pay' then
  select * into r from public.work_expenses where id=(c->>'expense_id')::uuid for update;
  select to_jsonb(t) into result from public.work_supplier_payments t where request_key=(c->>'request_key')::uuid;if result is not null then return result;end if;
  if r.id is null or r.status<>'approved' then raise exception 'BUSINESS: Approve the bill or expense before recording its payment.';end if;
  amount=(c->>'amount_minor')::bigint;
  select coalesce(sum(amount_minor),0) into used from public.work_supplier_payments where expense_id=r.id and reversed_at is null;
  if amount is null or amount<=0 or used+amount>r.amount_minor then raise exception 'BUSINESS: Supplier payment exceeds the unpaid amount.';end if;
  perform private.work_evidence((c->>'evidence_id')::uuid,'finance');
  insert into public.work_supplier_payments(expense_id,amount_minor,paid_on,reference,evidence_id,request_key) values(r.id,amount,(c->>'paid_on')::date,coalesce(c->>'reference',''),(c->>'evidence_id')::uuid,(c->>'request_key')::uuid) returning to_jsonb(work_supplier_payments.*) into result;return result;
 else raise exception 'BUSINESS: Unsupported expense action.';end if;
 if c->>'action'='save' then
  if nullif(d->>'project_id','') is not null and not private.work_case_allowed((d->>'project_id')::uuid) then raise exception 'BUSINESS: Project access required.';end if;
  if nullif(d->>'purchase_id','') is not null and not exists(select 1 from public.work_commercial p where p.id=(d->>'purchase_id')::uuid and p.kind='purchase' and p.status='issued' and p.supplier_id is not distinct from nullif(d->>'supplier_id','')::uuid and p.currency=d->>'currency') then raise exception 'BUSINESS: Select the issued purchase order for this supplier and currency.';end if;
 end if;
 select to_jsonb(t) into result from public.work_expenses t where id=rid;return result;
end;$$;
create or replace function private.work_job(proof text,c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare msg public.work_messages;rowdata record;payload jsonb;rows jsonb='[]';jobid uuid;creator uuid;reference text;enquiry uuid;notify text;
begin
 if proof is null or length(proof)<>64 or not exists(select 1 from private.work_job_config where id=1 and proof_hash=encode(sha256(convert_to(proof,'UTF8')),'hex')) then raise exception using errcode='42501',message='Invalid job proof';end if;
 if length(c::text)>35000 then raise exception 'Invalid job payload';end if;
 if c->>'action'='ingest' then
  perform pg_advisory_xact_lock(hashtextextended(c->>'request_key',9));
  select id,work_enquiries.reference into enquiry,reference from public.work_enquiries where request_key=(c->>'request_key')::uuid;
  if enquiry is not null then return jsonb_build_object('reference',reference);end if;
  if c->>'email' !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Invalid enquiry email';end if;
  reference=private.work_number('ENQ');
  insert into public.work_enquiries(reference,name,email,phone,subject,message,source,request_key,services,privacy_ack_at) values(reference,c->>'name',c->>'email',coalesce(c->>'phone',''),c->>'subject',c->>'message',c->>'source',(c->>'request_key')::uuid,array(select jsonb_array_elements_text(coalesce(c->'services','[]'))),now()) returning id into enquiry;
  select content#>>'{company,email}' into notify from public.work_public_site where id=1;
  insert into public.work_messages(recipient,subject,body,request_key,purpose,created_by) values(notify,'New enquiry '||reference,'A new website enquiry is ready in the private workspace. Reference: '||reference,gen_random_uuid(),'enquiry-notification',null);
  return jsonb_build_object('reference',reference);
 elsif c->>'action'='prepare' then return jsonb_build_object('queued',private.work_prepare_reminders());
 elsif c->>'action'='health' then return jsonb_build_object('pending_messages',(select count(*) from public.work_messages where status in ('queued','sending')),'failed_messages',(select count(*) from public.work_messages where status='failed'),'unassigned_enquiries',(select count(*) from public.work_enquiries where assigned_to is null and status not in ('won','lost','closed')));
 elsif c->>'action'='claim' then
  update public.work_messages m set status='cancelled',last_error='Reminder no longer eligible' where m.status in ('queued','failed') and (
   m.purpose='enquiry-followup' and not exists(select 1 from public.work_enquiries e where e.id=m.related_id and e.status not in ('won','lost','closed') and e.follow_up<=current_date) or
   m.purpose='warranty-reminder' and not exists(select 1 from public.work_assets a where a.id=m.related_id and a.warranty_until between current_date and current_date+30) or
   m.purpose='visit-reminder' and not exists(select 1 from public.work_maintenance_visits v join public.work_cases k on k.id=v.case_id where v.id=m.related_id and v.status='scheduled' and k.status not in ('closed','completed') and v.scheduled_on between current_date and current_date+7) or
   m.purpose='maintenance-reminder' and not exists(select 1 from public.work_cases k where k.kind='maintenance' and k.status not in ('closed','completed') and m.subject='Maintenance renewal: '||k.reference and k.due_on between current_date and current_date+7) or
   m.purpose='support-escalation' and not exists(select 1 from public.work_cases k where m.subject='Response target exceeded: '||k.reference and k.status not in ('closed','completed') and k.responded_at is null and k.response_due_at<now() and not exists(select 1 from public.work_case_service cs where cs.case_id=k.id and cs.clock_paused_at is not null)));
  update public.work_messages set status='failed',last_error='Retry window expired. Review provider delivery status before preparing a new message.' where status in ('queued','sending') and (created_at<=now()-interval '23 hours' or attempts>=4 and leased_at<now()-interval '5 minutes');
  for msg in select * from public.work_messages where not paused and ((status in ('queued','failed') and next_attempt_at<=now()) or (status='sending' and leased_at<now()-interval '5 minutes')) and attempts<4 and created_at>now()-interval '23 hours' order by created_at for update skip locked limit 10 loop
   if exists(select 1 from private.work_suppressed where email=lower(msg.recipient)) then update public.work_messages set status='cancelled',last_error='Recipient suppressed' where id=msg.id;continue;end if;
   if msg.purpose='invoice-reminder' and not exists(select 1 from public.work_invoice_balances where id=msg.record_id and outstanding_minor>0 and due_date<current_date) then update public.work_messages set status='cancelled',last_error='Invoice settled or no longer overdue' where id=msg.id;continue;end if;
   if msg.created_by is not null then
    select user_id into creator from public.work_members m where user_id=msg.created_by and active and (role in ('owner','admin','finance') or exists(select 1 from public.work_grants g where g.email=m.email and g.area='sales' and g.write_access));
    if creator is null or not private.work_sender_allowed(msg.created_by,msg.customer_id,msg.record_id,msg.document_id) then update public.work_messages set status='cancelled',last_error='Sender access revoked' where id=msg.id;continue;end if;
   end if;
   if msg.document_id is not null and not exists(select 1 from public.work_documents d join public.work_quotes q on q.document_id=d.id where d.id=msg.document_id and d.status='issued' and q.outcome<>'superseded') then update public.work_messages set status='cancelled',last_error='Quotation withdrawn or superseded' where id=msg.id;continue;end if;
   if msg.record_id is not null and not exists(select 1 from public.work_commercial where id=msg.record_id and status='issued') then update public.work_messages set status='cancelled',last_error='Document withdrawn' where id=msg.id;continue;end if;
   if msg.customer_id is not null and not exists(select 1 from public.work_customers cu where cu.id=msg.customer_id and not cu.archived and (lower(cu.email)=lower(msg.recipient) or exists(select 1 from public.work_contacts co where co.customer_id=cu.id and lower(co.email)=lower(msg.recipient)))) then update public.work_messages set status='cancelled',last_error='Customer contact is no longer authorized' where id=msg.id;continue;end if;
   jobid=gen_random_uuid();
   update public.work_messages set status='sending',attempts=attempts+1,lease_id=jobid,leased_at=now(),updated_at=now() where id=msg.id;
   payload=to_jsonb(msg)||jsonb_build_object('lease_id',jobid,'statement_snapshot',(select snapshot from private.work_message_statements where message_id=msg.id));
   if msg.record_id is not null then
    payload=payload||jsonb_build_object('document',(select to_jsonb(r) from public.work_commercial r where id=msg.record_id),'lines',(select jsonb_agg(to_jsonb(l) order by position) from public.work_commercial_lines l where record_id=msg.record_id));
   end if;
   if msg.document_id is not null then payload=payload||jsonb_build_object('legacy',(select to_jsonb(d) from public.work_documents d where id=msg.document_id));end if;
   rows=rows||jsonb_build_array(payload);
  end loop;
  return rows;
 elsif c->>'action'='complete' then
  update public.work_messages set status=case when coalesce(c->>'provider_id','')<>'' then 'sent' else 'failed' end,provider_id=nullif(c->>'provider_id',''),last_error=left(coalesce(c->>'error',''),200),next_attempt_at=now()+make_interval(mins=>power(3,attempts)::integer),updated_at=now() where id=(c->>'id')::uuid and lease_id=(c->>'lease_id')::uuid and status='sending';
  if coalesce(c->>'provider_id','')<>'' then
   update public.work_messages set delivery_status=case when exists(select 1 from private.work_mail_events where provider_id=c->>'provider_id' and type='email.complained') then 'complained' when exists(select 1 from private.work_mail_events where provider_id=c->>'provider_id' and type='email.bounced') then 'bounced' when exists(select 1 from private.work_mail_events where provider_id=c->>'provider_id' and type='email.delivered') then 'delivered' else 'pending' end where id=(c->>'id')::uuid;
   insert into private.work_suppressed(email,reason) select lower(recipient),delivery_status from public.work_messages where id=(c->>'id')::uuid and delivery_status in ('bounced','complained') on conflict do nothing;
  end if;return jsonb_build_object('success',true);
 elsif c->>'action'='event' then
  if c->>'type' not in ('email.delivered','email.bounced','email.complained','email.failed') then return '{}';end if;
  insert into private.work_mail_events(id,provider_id,type) values(c->>'event_id',c->>'provider_id',c->>'type') on conflict do nothing;if not found then return '{}';end if;
  update public.work_messages set delivery_status=case c->>'type' when 'email.delivered' then 'delivered' when 'email.bounced' then 'bounced' when 'email.complained' then 'complained' else 'failed' end where provider_id=c->>'provider_id' and (delivery_status='pending' or c->>'type' in ('email.bounced','email.complained'));
  if c->>'type' in ('email.bounced','email.complained') then insert into private.work_suppressed(email,reason) select lower(recipient),c->>'type' from public.work_messages where provider_id=c->>'provider_id' on conflict do nothing;end if;
  return '{}';
 end if;
 raise exception 'Unsupported job action';
end;$$;
create or replace function private.work_operations_execute(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare a text=c->>'action';d jsonb=coalesce(c->'data','{}');rid uuid=coalesce(nullif(c->>'id','')::uuid,gen_random_uuid());v integer=coalesce((c->>'version')::integer,0);result jsonb;ord public.work_commercial;ln public.work_commercial_lines;sp public.work_supplier_payments;bank public.work_bank_lines;mov public.work_stock;k public.work_cases;visit public.work_maintenance_visits;msg public.work_messages;sb public.work_supplier_bank;n bigint;used bigint;qty integer;held bigint;bal bigint;res bigint;area text;reason text=trim(coalesce(d->>'reason',''));eid uuid=nullif(d->>'evidence_id','')::uuid;
begin
 if a='location' then
  perform private.work_require('inventory');
  if v=0 then insert into public.work_locations(id,name) values(rid,trim(d->>'name'));
  else update public.work_locations set name=trim(d->>'name'),archived=coalesce((d->>'archived')::boolean,false) where id=rid and version=v;if not found then raise exception 'BUSINESS: Record changed. Refresh before saving.';end if;end if;
  select to_jsonb(t) into result from public.work_locations t where id=rid;
 elsif a='inspection' then
  select * into ord from public.work_commercial where id=(d->>'purchase_id')::uuid for update;
  perform private.work_require('procurement',ord.assigned_to);
  if ord.id is null or ord.kind<>'purchase' or ord.status<>'issued' then raise exception 'BUSINESS: Select an issued purchase order.';end if;
  if nullif(d->>'line_id','') is not null and not exists(select 1 from public.work_commercial_lines where id=(d->>'line_id')::uuid and record_id=ord.id and quantity>=(d->>'quantity')::integer) then raise exception 'BUSINESS: Select a purchase line with sufficient quantity.';end if;
  perform private.work_evidence(eid,'procurement');
  insert into public.work_inspections(id,purchase_id,line_id,stage,result,quantity,notes,evidence_id) values(rid,ord.id,nullif(d->>'line_id','')::uuid,d->>'stage',d->>'result',(d->>'quantity')::integer,d->>'notes',eid) returning to_jsonb(work_inspections.*) into result;
 elsif a='stock-hold' then
  perform private.work_require('inventory',null,'approve');
  select * into mov from public.work_stock where id=(d->>'movement_id')::uuid;
  perform 1 from public.work_items where id=mov.item_id for update;
  if mov.id is null or mov.kind not in ('receive','return') or mov.quantity<1 then raise exception 'BUSINESS: Select an incoming stock movement.';end if;
  qty=(d->>'quantity')::integer;
  select coalesce(sum(h.quantity),0) into held from public.work_stock_holds h join public.work_stock st on st.id=h.movement_id where st.item_id=mov.item_id and st.location=mov.location and st.serial=mov.serial and h.released_at is null;
  select coalesce(sum(quantity),0) into bal from public.work_stock where item_id=mov.item_id and location=mov.location and serial=mov.serial;
  select coalesce(sum(quantity),0) into res from public.work_reservations where item_id=mov.item_id and location=mov.location and serial=mov.serial and released_at is null;
  if qty is null or qty<=0 or qty>mov.quantity or qty>bal-held-res then raise exception 'BUSINESS: Quarantine exceeds the unreserved stock currently held.';end if;
  if eid is not null then perform private.work_evidence(eid,'inventory');end if;
  insert into public.work_stock_holds(id,movement_id,quantity,reason,evidence_id) values(rid,mov.id,qty,reason,eid) returning to_jsonb(work_stock_holds.*) into result;
 elsif a='release-hold' then
  perform private.work_require('inventory',null,'approve');
  if length(reason)<5 then raise exception 'BUSINESS: Record the inspection and release reason.';end if;
  update public.work_stock_holds set released_at=now(),release_reason=reason where id=rid and released_at is null returning to_jsonb(work_stock_holds.*) into result;
  if result is null then raise exception 'BUSINESS: Hold not found or already released.';end if;
 elsif a='order-progress' then
  select * into ord from public.work_commercial where id=(d->>'order_id')::uuid for update;
  perform private.work_require('sales',ord.assigned_to,case when d->>'status' in ('fulfilled','closed') then 'approve' else 'write' end);
  if ord.id is null or ord.kind<>'order' or ord.status<>'issued' then raise exception 'BUSINESS: Select an issued sales order.';end if;
  if d->>'status' in ('fulfilled','closed') then
   perform private.work_evidence(eid,'sales');
   if length(trim(coalesce(d->>'receiver','')))<2 then raise exception 'BUSINESS: Record the customer receiver or acceptance name.';end if;
   if exists(select 1 from public.work_commercial_lines l join public.work_items i on i.id=l.item_id where l.record_id=ord.id and i.kind='stock' and l.quantity>(select coalesce(sum(-st.quantity),0) from public.work_stock st join public.work_commercial_lines dl on dl.id=st.source_line_id where dl.source_line_id=l.id and st.kind in ('dispatch','return'))+(select coalesce(sum(quantity),0) from public.work_order_cancellations where line_id=l.id)) then raise exception 'BUSINESS: Dispatch or approve cancellation of the remaining stock quantities first.';end if;
   if exists(select 1 from public.work_cases where order_id=ord.id and kind='project' and status not in ('completed','closed')) then raise exception 'BUSINESS: Complete the linked project acceptance first.';end if;
  end if;
  if length(reason)<5 then raise exception 'BUSINESS: Enter a progress or acceptance reason.';end if;
  if v=0 then insert into public.work_order_progress(id,order_id,status,delivery_address,receiver,evidence_id,reason) values(rid,ord.id,d->>'status',coalesce(d->>'delivery_address',''),coalesce(d->>'receiver',''),eid,reason);
  else update public.work_order_progress set status=d->>'status',delivery_address=coalesce(d->>'delivery_address',''),receiver=coalesce(d->>'receiver',''),evidence_id=eid,reason=reason where id=rid and order_id=ord.id and version=v;if not found then raise exception 'BUSINESS: Record changed. Refresh before saving.';end if;end if;
  select to_jsonb(t) into result from public.work_order_progress t where id=rid;
 elsif a='cancel-quantity' then
  select * into ln from public.work_commercial_lines where id=(d->>'line_id')::uuid;
  select * into ord from public.work_commercial where id=ln.record_id for update;
  perform private.work_require('sales',ord.assigned_to,'approve');
  if ord.kind is distinct from 'order' or ord.status<>'issued' then raise exception 'BUSINESS: Select an issued order line.';end if;
  qty=(d->>'quantity')::integer;
  select greatest(coalesce(sum(x.quantity) filter(where h.kind='invoice'),0),coalesce(sum(x.quantity) filter(where h.kind='delivery'),0)) into used from public.work_commercial_lines x join public.work_commercial h on h.id=x.record_id where x.source_line_id=ln.id and h.status='issued';
  select coalesce(sum(quantity),0)+used into used from public.work_order_cancellations where line_id=ln.id;
  if qty is null or qty<1 or qty+used>ln.quantity then raise exception 'BUSINESS: Cancellation exceeds unbilled and undelivered order quantity.';end if;
  if exists(select 1 from public.work_reservations where order_id=ord.id and item_id=ln.item_id and released_at is null) then raise exception 'BUSINESS: Release reservations before cancelling this quantity.';end if;
  perform private.work_evidence(eid,'sales');
  insert into public.work_order_cancellations(id,line_id,quantity,reason,evidence_id) values(rid,ln.id,qty,reason,eid) returning to_jsonb(work_order_cancellations.*) into result;
 elsif a='visit' then
  select * into k from public.work_cases where id=(d->>'case_id')::uuid for update;
  if k.id is null or k.kind<>'maintenance' or not private.work_case_allowed(k.id,true) then raise exception using errcode='42501',message='BUSINESS: Maintenance contract access required.';end if;
  perform private.work_assignment(nullif(d->>'assigned_to','')::uuid);
  if nullif(d->>'asset_id','') is not null and not exists(select 1 from public.work_assets where id=(d->>'asset_id')::uuid and customer_id=k.customer_id) then raise exception 'BUSINESS: Choose an asset belonging to the contract customer.';end if;
  if eid is not null then perform private.work_evidence(eid,'support');end if;
  if nullif(d->>'completed_on','')::date>current_date then raise exception 'BUSINESS: A completed visit cannot be dated in the future.';end if;
  if v=0 then insert into public.work_maintenance_visits(id,case_id,asset_id,assigned_to,scheduled_on,status,completed_on,notes,evidence_id) values(rid,k.id,nullif(d->>'asset_id','')::uuid,nullif(d->>'assigned_to','')::uuid,(d->>'scheduled_on')::date,d->>'status',nullif(d->>'completed_on','')::date,coalesce(d->>'notes',''),eid);
  else update public.work_maintenance_visits set asset_id=nullif(d->>'asset_id','')::uuid,assigned_to=nullif(d->>'assigned_to','')::uuid,scheduled_on=(d->>'scheduled_on')::date,status=d->>'status',completed_on=nullif(d->>'completed_on','')::date,notes=coalesce(d->>'notes',''),evidence_id=eid where id=rid and case_id=k.id and version=v;if not found then raise exception 'BUSINESS: Record changed. Refresh before saving.';end if;end if;
  select to_jsonb(t) into result from public.work_maintenance_visits t where id=rid;
 elsif a='supplier-bank' then
  perform private.work_require('finance',null,'approve');perform private.work_evidence(eid,'finance');
  insert into public.work_supplier_bank(id,supplier_id,bank_name,account_name,account_number,currency,evidence_id,reason) values(rid,(d->>'supplier_id')::uuid,d->>'bank_name',d->>'account_name',d->>'account_number',d->>'currency',eid,reason) returning jsonb_build_object('id',id,'status',status) into result;
 elsif a='approve-bank' then
  perform private.work_require('finance',null,'approve');
  select * into sb from public.work_supplier_bank where id=rid;
  perform 1 from public.work_suppliers where id=sb.supplier_id for update;
  select * into sb from public.work_supplier_bank where id=rid for update;
  if sb.id is null or sb.status<>'pending' or length(reason)<5 then raise exception 'BUSINESS: Review a pending bank change and record its verification reason.';end if;
  if sb.proposed_by=auth.uid() and not private.work_allowed('members') then raise exception 'BUSINESS: A different authorized colleague must approve bank changes.';end if;
  if sb.proposed_by=auth.uid() and not coalesce((d->>'owner_exception')::boolean,false) then raise exception 'BUSINESS: The owner must explicitly confirm and explain the same-person exception.';end if;
  update public.work_supplier_bank set status='superseded' where supplier_id=sb.supplier_id and currency=sb.currency and status='active';
  update public.work_supplier_bank set status='active',approved_by=auth.uid(),reason=reason where id=rid returning jsonb_build_object('id',id,'status',status) into result;
 elsif a='cost-allocation' then
  perform private.work_require('finance',null,'approve');
  perform 1 from public.work_expenses where id=(d->>'expense_id')::uuid and status='approved' for update;
  if not found then raise exception 'BUSINESS: Allocate an approved supplier expense.';end if;
  select * into ln from public.work_commercial_lines where id=(d->>'purchase_line_id')::uuid;
  select * into ord from public.work_commercial where id=ln.record_id;
  if ord.kind is distinct from 'purchase' or ord.status<>'issued' or not exists(select 1 from public.work_expenses e where e.id=(d->>'expense_id')::uuid and (e.currency=ord.currency or e.cost_currency=ord.currency) and (e.supplier_id is null or e.supplier_id=ord.supplier_id)) then raise exception 'BUSINESS: Select a purchase line in the same currency and supplier as the approved expense.';end if;
  n=(d->>'amount_minor')::bigint;
  select coalesce(sum(amount_minor),0) into used from public.work_cost_allocations where expense_id=(d->>'expense_id')::uuid;
  if n is null or n<=0 or n+used>(select case when currency=ord.currency then amount_minor else cost_minor end from public.work_expenses where id=(d->>'expense_id')::uuid) then raise exception 'BUSINESS: Allocations exceed the approved expense.';end if;
  insert into public.work_cost_allocations(id,expense_id,purchase_line_id,amount_minor,currency,basis) values(rid,(d->>'expense_id')::uuid,ln.id,n,ord.currency,d->>'basis') returning to_jsonb(work_cost_allocations.*) into result;
 elsif a='reverse-supplier-payment' then
  perform private.work_require('finance',null,'approve');
  select * into sp from public.work_supplier_payments where id=rid;
  perform 1 from public.work_expenses where id=sp.expense_id for update;
  select * into sp from public.work_supplier_payments where id=rid for update;
  if sp.id is null or sp.reversed_at is not null then raise exception 'BUSINESS: Select an unreversed supplier payment.';end if;
  if exists(select 1 from public.work_bank_lines where supplier_payment_id=sp.id) then raise exception 'BUSINESS: Unmatch the bank line before correcting this supplier payment.';end if;
  if length(reason)<5 then raise exception 'BUSINESS: Record the correction reason.';end if;
  perform private.work_evidence(eid,'finance');
  update public.work_supplier_payments set reversed_at=now(),reversal_reason=reason,reversal_evidence_id=eid,reversed_by=auth.uid() where id=rid returning to_jsonb(work_supplier_payments.*) into result;
 elsif a='match-outgoing' then
  perform private.work_require('finance');
  if (nullif(d->>'supplier_payment_id','') is null)=(nullif(d->>'refund_id','') is null) then raise exception 'BUSINESS: Select exactly one supplier payment or customer refund.';end if;
  if nullif(d->>'supplier_payment_id','') is not null then
   select * into sp from public.work_supplier_payments where id=(d->>'supplier_payment_id')::uuid for update;
   select e.currency,sp.amount_minor into area,n from public.work_expenses e where e.id=sp.expense_id and sp.reversed_at is null;
  else
   select p.currency,r.amount_minor into area,n from public.work_refunds r join public.work_payments p on p.id=r.payment_id where r.id=(d->>'refund_id')::uuid for update of r;
  end if;
  select * into bank from public.work_bank_lines where id=rid for update;
  if n is null or bank.id is null or num_nonnulls(bank.payment_id,bank.supplier_payment_id,bank.refund_id)>0 or bank.amount_minor<>-n or bank.currency<>area then raise exception 'BUSINESS: Match an equal negative bank amount and the same currency to an unmatched recorded outgoing payment.';end if;
  update public.work_bank_lines set supplier_payment_id=nullif(d->>'supplier_payment_id','')::uuid,refund_id=nullif(d->>'refund_id','')::uuid where id=rid returning to_jsonb(work_bank_lines.*) into result;
 elsif a='unmatch-bank' then
  perform private.work_require('finance',null,'approve');
  if length(reason)<5 then raise exception 'BUSINESS: Record a reconciliation correction reason.';end if;
  select * into bank from public.work_bank_lines where id=rid for update;
  if bank.id is null then raise exception 'BUSINESS: Bank line not found.';end if;
  if bank.payment_id is not null then update public.work_payments set reconciled=false where id=bank.payment_id;end if;
  update public.work_bank_lines set payment_id=null,supplier_payment_id=null,refund_id=null where id=rid;
  insert into public.work_audit(actor,action,entity,entity_id,detail) values(auth.uid(),'bank_unmatch','work_bank_lines',rid::text,jsonb_build_object('reason',reason));
  result=jsonb_build_object('success',true);
 elsif a in ('pause-message','resume-message','replay-message','cancel-message') then
  select * into msg from public.work_messages where id=rid for update;
  if msg.id is null or not private.work_ops_allowed('sales',msg.created_by,'write') then raise exception using errcode='42501',message='BUSINESS: Message access required.';end if;
  if length(reason)<5 then raise exception 'BUSINESS: Record the dispatch decision reason.';end if;
  if msg.status in ('sent','cancelled') or msg.provider_id is not null then raise exception 'BUSINESS: A sent, cancelled or provider-accepted message cannot be replayed.';end if;
  if msg.status='sending' and msg.leased_at>now()-interval '5 minutes' then raise exception 'BUSINESS: Wait for the current delivery lease to finish.';end if;
  if a='replay-message' and (msg.created_at<=now()-interval '23 hours' or msg.attempts>=4) then raise exception 'BUSINESS: The safe provider retry window has ended. Review delivery status before preparing a new message.';end if;
  update public.work_messages set paused=case when a='pause-message' then true when a in ('resume-message','replay-message') then false else paused end,status=case when a='cancel-message' then 'cancelled' when a='replay-message' then 'queued' else status end,next_attempt_at=case when a='replay-message' then now() else next_attempt_at end,last_error=reason where id=rid returning to_jsonb(work_messages.*) into result;
 elsif a='queue-statement' then
  perform private.work_require('finance');
  if (d->>'from')<>'' and (d->>'to')<>'' and (d->>'from')::date>(d->>'to')::date then raise exception 'BUSINESS: Choose a valid statement date range.';end if;
  if not exists(select 1 from public.work_customers cu where cu.id=(d->>'customer_id')::uuid and not cu.archived and (lower(cu.email)=lower(d->>'recipient') or exists(select 1 from public.work_contacts co where co.customer_id=cu.id and lower(co.email)=lower(d->>'recipient')))) then raise exception 'BUSINESS: Choose a recorded customer contact email.';end if;
  if exists(select 1 from private.work_suppressed where email=lower(d->>'recipient')) then raise exception 'BUSINESS: This recipient is suppressed following a delivery failure.';end if;
  result=private.work_statement((d->>'customer_id')::uuid,nullif(d->>'from','')::date,nullif(d->>'to','')::date,d->>'currency');
  if jsonb_array_length(result->'events')>1000 then raise exception 'BUSINESS: Narrow the date range to at most 1,000 statement entries.';end if;
  result=result||jsonb_build_object('company',(select payload from public.work_settings where id=1),'from',coalesce(d->>'from',''),'to',coalesce(d->>'to',''));
  insert into public.work_messages(id,customer_id,recipient,subject,body,request_key) values(rid,(d->>'customer_id')::uuid,lower(d->>'recipient'),'Your Lutera customer statement','Please find your customer statement attached. Contact Lutera if you have questions about any entry.',(c->>'request_key')::uuid);
  insert into private.work_message_statements(message_id,snapshot) values(rid,result);
  result=jsonb_build_object('id',rid,'status','queued');
 elsif a='acceptance-request' then
  perform private.work_require('sales',(select assigned_to from public.work_customers where id=(d->>'customer_id')::uuid));
  if not exists(select 1 from public.work_portal_shares sh left join public.work_commercial cr on cr.id=sh.record_id left join public.work_documents ld on ld.id=sh.document_id where sh.id=(d->>'share_id')::uuid and sh.customer_id=(d->>'customer_id')::uuid and sh.active and (cr.status='issued' or ld.status='issued') and not exists(select 1 from public.work_quotes q where q.document_id=ld.id and q.outcome='superseded')) then raise exception 'BUSINESS: Select an active document share for this customer.';end if;
  insert into public.work_acceptance_requests(id,customer_id,share_id,prompt) values(rid,(d->>'customer_id')::uuid,(d->>'share_id')::uuid,d->>'prompt') returning to_jsonb(work_acceptance_requests.*) into result;
 elsif a='withdraw-acceptance' then
  perform private.work_require('sales',(select c.assigned_to from public.work_customers c join public.work_acceptance_requests r on r.customer_id=c.id where r.id=rid));
  update public.work_acceptance_requests set status='withdrawn' where id=rid returning to_jsonb(work_acceptance_requests.*) into result;
  if result is null then raise exception 'BUSINESS: Request not found.';end if;
 elsif a in ('pause-clock','resume-clock') then
  select * into k from public.work_cases where id=rid for update;
  if k.id is null then raise exception 'BUSINESS: Case not found.';end if;
  area=case when k.kind='project' then 'projects' else 'support' end;
  perform private.work_require(area,k.assigned_to,'approve');perform private.work_evidence(eid,area);
  if length(reason)<5 or k.status in ('closed','completed') or k.responded_at is not null or k.response_due_at is null then raise exception 'BUSINESS: Select open work with an agreed outstanding first-response deadline and record the customer-approved reason.';end if;
  perform 1 from public.work_case_service where case_id=k.id for update;
  if not found then raise exception 'BUSINESS: Save the agreed service coverage first.';end if;
  if a='pause-clock' then
   if k.response_due_at<=now() then raise exception 'BUSINESS: A missed response target cannot be erased by pausing the clock.';end if;
   update public.work_case_service set clock_paused_at=now(),response_remaining_minutes=private.work_business_minutes(now(),k.response_due_at),clock_reason=reason,clock_evidence_id=eid,version=version+1 where case_id=k.id and clock_paused_at is null;
   if not found then raise exception 'BUSINESS: This response clock is already paused.';end if;
  else
   select response_remaining_minutes into n from public.work_case_service where case_id=k.id and clock_paused_at is not null;
   if n is null then raise exception 'BUSINESS: This response clock is not paused.';end if;
   update public.work_case_service set clock_paused_at=null,response_remaining_minutes=null,clock_reason=reason,clock_evidence_id=eid,version=version+1 where case_id=k.id;
   update public.work_cases set response_due_at=private.work_working_deadline(now(),n::integer) where id=k.id;
  end if;
  insert into public.work_case_events(case_id,previous_status,status,actor,note) values(k.id,k.status,k.status,auth.uid(),a||': '||reason);
  result=jsonb_build_object('success',true);
 elsif a='shipment' then
  select * into ln from public.work_commercial_lines where id=(d->>'purchase_line_id')::uuid;
  select * into ord from public.work_commercial where id=ln.record_id for update;
  perform private.work_require('procurement',ord.assigned_to);
  if ord.kind is distinct from 'purchase' or ord.status<>'issued' then raise exception 'BUSINESS: Select an issued purchase line.';end if;
  select coalesce(sum(quantity),0) into used from public.work_shipments where purchase_line_id=ln.id and id<>rid and status not in ('cancelled','returned');
  qty=(d->>'quantity')::integer;
  if qty is null or qty<1 or qty+used>ln.quantity then raise exception 'BUSINESS: Shipment quantity exceeds the remaining purchase quantity.';end if;
  if nullif(d->>'shipped_on','')::date>current_date then raise exception 'BUSINESS: A recorded shipment cannot be dated in the future.';end if;
  if d->>'status' in ('shipped','arrived') and nullif(d->>'shipped_on','') is null then raise exception 'BUSINESS: Record the actual shipment date.';end if;
  if eid is not null then perform private.work_evidence(eid,'procurement');end if;
  if v=0 then insert into public.work_shipments(id,purchase_line_id,quantity,status,carrier,tracking_reference,shipped_on,expected_on,notes,evidence_id) values(rid,ln.id,qty,d->>'status',coalesce(d->>'carrier',''),coalesce(d->>'tracking_reference',''),nullif(d->>'shipped_on','')::date,nullif(d->>'expected_on','')::date,coalesce(d->>'notes',''),eid);
  else update public.work_shipments set quantity=qty,status=d->>'status',carrier=coalesce(d->>'carrier',''),tracking_reference=coalesce(d->>'tracking_reference',''),shipped_on=nullif(d->>'shipped_on','')::date,expected_on=nullif(d->>'expected_on','')::date,notes=coalesce(d->>'notes',''),evidence_id=eid where id=rid and purchase_line_id=ln.id and version=v;if not found then raise exception 'BUSINESS: Record changed. Refresh before saving.';end if;end if;
  select to_jsonb(t) into result from public.work_shipments t where id=rid;
 elsif a='approval-rule' then
  if not private.work_allowed('members') then raise exception using errcode='42501',message='BUSINESS: Owner access required.';end if;
  perform private.work_assignment(nullif(d->>'approver_id','')::uuid);
  perform pg_advisory_xact_lock(hashtextextended((d->>'kind')||':'||(d->>'currency'),41));
  if v=0 then insert into public.work_approval_rules(id,kind,currency,threshold_minor,approver_id,notes) values(rid,d->>'kind',d->>'currency',nullif(d->>'threshold_minor','')::bigint,nullif(d->>'approver_id','')::uuid,coalesce(d->>'notes',''));
  else update public.work_approval_rules set threshold_minor=nullif(d->>'threshold_minor','')::bigint,approver_id=nullif(d->>'approver_id','')::uuid,notes=coalesce(d->>'notes','') where id=rid and version=v and kind=d->>'kind' and currency=d->>'currency';if not found then raise exception 'BUSINESS: Rule changed. Refresh before saving.';end if;end if;
  select to_jsonb(t) into result from public.work_approval_rules t where id=rid;
 elsif a='operating-policy' then
  if not private.work_allowed('members') then raise exception using errcode='42501',message='BUSINESS: Owner access required.';end if;
  update public.work_operating_policy set financial_retention_days=nullif(d->>'financial_retention_days','')::integer,communication_retention_days=nullif(d->>'communication_retention_days','')::integer,staff_retention_days=nullif(d->>'staff_retention_days','')::integer,backup_retention_days=nullif(d->>'backup_retention_days','')::integer,recovery_point_hours=nullif(d->>'recovery_point_hours','')::integer,recovery_time_hours=nullif(d->>'recovery_time_hours','')::integer,notes=coalesce(d->>'notes','') where id=1 and version=v returning to_jsonb(work_operating_policy.*) into result;
  if result is null then raise exception 'BUSINESS: Policy changed. Refresh before saving.';end if;
 else raise exception 'BUSINESS: Unsupported operations action.';end if;
 return result;
end;$$;
create function private.work_operations(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare key uuid=(c->>'request_key')::uuid;fingerprint text;cached private.work_ops_requests;result jsonb;
begin
 if not private.work_allowed('session') then raise exception using errcode='42501',message='BUSINESS: Sign in and complete MFA.';end if;
 if length(c::text)>30000 or key is null then raise exception 'BUSINESS: Invalid request.';end if;
 perform pg_advisory_xact_lock(hashtextextended(key::text,37));
 fingerprint=encode(sha256(convert_to((c-'request_key')::text,'UTF8')),'hex');
 select * into cached from private.work_ops_requests where request_key=key;
 if found then
  if cached.actor<>auth.uid() or cached.fingerprint<>fingerprint then raise exception 'BUSINESS: Request key already used for different data.';end if;
  if c->>'action' in ('operating-policy','approval-rule') then
   if not private.work_allowed('members') then raise exception using errcode='42501',message='BUSINESS: Owner access required.';end if;
  elsif c->>'action' in ('location','stock-hold','release-hold') then
   perform private.work_require('inventory',null,case when c->>'action'='location' then 'write' else 'approve' end);
  elsif c->>'action' in ('supplier-bank','approve-bank','cost-allocation','reverse-supplier-payment','unmatch-bank','queue-statement','match-outgoing') then
   perform private.work_require('finance',null,case when c->>'action' in ('queue-statement','match-outgoing') then 'write' else 'approve' end);
  elsif c->>'action' in ('pause-message','resume-message','replay-message','cancel-message') then
   perform private.work_require('sales',(select created_by from public.work_messages where id=(c->>'id')::uuid));
  elsif c->>'action' in ('pause-clock','resume-clock','visit') then
   if not private.work_case_allowed(coalesce(nullif(c->>'id','')::uuid,nullif(c#>>'{data,case_id}','')::uuid),true) then raise exception using errcode='42501',message='BUSINESS: Case access required.';end if;
  elsif c->>'action' in ('shipment','inspection') then
   perform private.work_require('procurement',coalesce((select assigned_to from public.work_commercial where id=nullif(c#>>'{data,purchase_id}','')::uuid),(select h.assigned_to from public.work_commercial h join public.work_commercial_lines l on l.record_id=h.id where l.id=nullif(c#>>'{data,purchase_line_id}','')::uuid)));
  else
   if not private.work_ops_allowed('sales',auth.uid(),'write') then raise exception using errcode='42501',message='BUSINESS: Sales access required.';end if;
  end if;
  return cached.result;
 end if;
 result=private.work_operations_execute(c);
 insert into public.work_audit(action,entity,entity_id,detail) values(c->>'action','business_operations',coalesce(nullif(c->>'id',''),result->>'id','policy'),jsonb_build_object('reason',left(coalesce(c#>>'{data,reason}',''),500)));
 insert into private.work_ops_requests(request_key,actor,fingerprint,result) values(key,auth.uid(),fingerprint,result);
 return result;
end;$$;
grant execute on function private.work_operations(jsonb) to authenticated;
create function public.work_operations(c jsonb) returns jsonb language sql security invoker set search_path='' as $$select private.work_operations(c)$$;
revoke all on function public.work_operations(jsonb) from public,anon;grant execute on function public.work_operations(jsonb) to authenticated;

revoke all on function private.work_operations_execute(jsonb) from public,anon,authenticated;
revoke all on function private.work_operations(jsonb) from public,anon;
create or replace function private.work_stock_action(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
<<stock_op>>
declare item public.work_items;header public.work_commercial;line public.work_commercial_lines;
 qty integer=(c->>'quantity')::integer;location text=trim(c->>'location');serial text=trim(coalesce(c->>'serial',''));balance bigint;reserved bigint;held bigint;used bigint;result jsonb;isreserve boolean=c->>'action'='reserve';kind text=c->>'kind';reservation public.work_reservations;original public.work_stock;
begin
 perform private.work_require('inventory');
 if c->>'action'='release' then
  update public.work_reservations set released_at=now() where id=(c->>'id')::uuid and released_at is null;return jsonb_build_object('success',true);
 end if;
 select * into item from public.work_items where id=(c->>'item_id')::uuid for update;
 if item.id is null or item.kind<>'stock' or item.archived then raise exception 'BUSINESS: Choose an active stock-managed item.';end if;
 if isreserve then select to_jsonb(t) into result from public.work_reservations t where request_key=(c->>'request_key')::uuid;
 else select to_jsonb(t) into result from public.work_stock t where request_key=(c->>'request_key')::uuid;end if;
 if result is not null then return result;end if;
 if qty is null or qty<=0 or qty>1000000 or length(location) not between 1 and 120 or item.serialized and (qty<>1 or length(serial)=0) or not item.serialized and serial<>'' then raise exception 'BUSINESS: Check quantity, location and serial number.';end if;
 select coalesce(sum(quantity),0) into balance from public.work_stock where item_id=item.id and work_stock.location=stock_op.location and work_stock.serial=stock_op.serial;
 select coalesce(sum(quantity),0) into reserved from public.work_reservations where item_id=item.id and work_reservations.location=stock_op.location and work_reservations.serial=stock_op.serial and released_at is null;
 select coalesce(sum(h.quantity),0) into held from public.work_stock_holds h join public.work_stock st on st.id=h.movement_id where st.item_id=item.id and st.location=stock_op.location and st.serial=stock_op.serial and h.released_at is null;
 balance=balance-held;
 if exists(select 1 from public.work_locations where name=stock_op.location and archived) then raise exception 'BUSINESS: This stock location is archived.';end if;
 if isreserve then
  select * into header from public.work_commercial where id=(c->>'order_id')::uuid for update;
  if header.id is null or header.kind<>'order' or header.status<>'issued' then raise exception 'BUSINESS: Reserve against an issued customer order.';end if;
  select coalesce(sum(quantity),0) into used from public.work_reservations where item_id=item.id and order_id=header.id and released_at is null;
  if qty>balance-reserved or qty+used>(select coalesce(sum(quantity),0) from public.work_commercial_lines where record_id=header.id and item_id=item.id)
 -(select coalesce(sum(cn.quantity),0) from public.work_order_cancellations cn join public.work_commercial_lines ol on ol.id=cn.line_id where ol.record_id=header.id and ol.item_id=item.id)
 -(select coalesce(sum(-st.quantity),0) from public.work_stock st join public.work_commercial_lines dl on dl.id=st.source_line_id join public.work_commercial dh on dh.id=dl.record_id where dh.kind='delivery' and dh.source_id=header.id and st.item_id=item.id and st.kind in ('dispatch','return')) then raise exception 'BUSINESS: Reservation exceeds available stock or ordered quantity.';end if;
  insert into public.work_reservations(item_id,location,serial,order_id,quantity,request_key) values(item.id,location,serial,header.id,qty,(c->>'request_key')::uuid) returning to_jsonb(work_reservations.*) into result;
 else
  if kind not in ('receive','dispatch','return','adjustment') then raise exception 'BUSINESS: Invalid movement type.';end if;
  if kind='adjustment' then perform private.work_require('inventory',null,'approve');end if;
  if kind in ('receive','dispatch') then
   select * into line from public.work_commercial_lines where id=(c->>'source_line_id')::uuid;
   select * into header from public.work_commercial where id=line.record_id for update;
   if line.id is null or header.status<>'issued' or line.item_id is distinct from item.id or (kind='receive' and header.kind<>'purchase') or (kind='dispatch' and header.kind<>'delivery') then raise exception 'BUSINESS: Receiving needs a purchase line; dispatch needs an issued delivery line for this item.';end if;
   select coalesce(sum(case when stock_op.kind='receive' then quantity else -quantity end),0) into used from public.work_stock where source_line_id=line.id and (work_stock.kind=stock_op.kind or work_stock.kind='return');
   if used+qty>line.quantity then raise exception 'BUSINESS: Movement exceeds the remaining line quantity.';end if;
  end if;
  if kind='dispatch' then
   if nullif(c->>'reservation_id','') is not null then
    select * into reservation from public.work_reservations where id=(c->>'reservation_id')::uuid for update;
    if reservation.id is null or reservation.released_at is not null or reservation.item_id<>item.id or reservation.location<>location or reservation.serial<>serial or reservation.order_id is distinct from header.source_id or reservation.quantity<>qty then raise exception 'BUSINESS: Reservation must match this delivery, quantity and location.';end if;
    update public.work_reservations set released_at=now() where id=reservation.id;reserved=reserved-qty;
   end if;
   qty=-qty;
  elsif kind='return' then
   select * into original from public.work_stock where id=nullif(c->>'reverses_id','')::uuid;
   if original.id is null or original.kind not in ('receive','dispatch') or original.item_id<>item.id or original.location<>location or original.serial<>serial then raise exception 'BUSINESS: Link the original receipt or dispatch for this item, location and serial.';end if;
   select coalesce(sum(abs(quantity)),0) into used from public.work_stock where reverses_id=original.id;
   if used+qty>abs(original.quantity) then raise exception 'BUSINESS: Return exceeds the original movement quantity.';end if;
   line.id=original.source_line_id;if original.quantity>0 then qty=-qty;end if;
  elsif kind='adjustment' and c->>'direction'='out' then qty=-qty;end if;
  if qty<0 and balance+qty<reserved then raise exception 'BUSINESS: Movement would use reserved or unavailable stock.';end if;
  if item.serialized and qty>0 and (select coalesce(sum(quantity),0) from public.work_stock where item_id=item.id and work_stock.serial=stock_op.serial)>0 then raise exception 'BUSINESS: This serial number is already held in stock.';end if;
  insert into public.work_stock(item_id,location,serial,quantity,kind,order_id,source_line_id,reason,evidence_id,request_key,reverses_id)
  values(item.id,location,serial,qty,kind,case when kind='dispatch' then header.source_id else nullif(c->>'order_id','')::uuid end,line.id,c->>'reason',nullif(c->>'evidence_id','')::uuid,(c->>'request_key')::uuid,original.id) returning to_jsonb(work_stock.*) into result;
  if kind='receive' and exists(select 1 from public.work_inspections pi where pi.purchase_id=header.id and (pi.line_id is null or pi.line_id=line.id) and pi.result='rejected') then
   insert into public.work_stock_holds(movement_id,quantity,reason,evidence_id) values((result->>'id')::uuid,qty,'Automatically quarantined: rejected purchase inspection',nullif(c->>'evidence_id','')::uuid);
  end if;
 end if;
 return result;
end;$$;
create or replace function private.work_commercial_issue(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.work_commercial; s public.work_commercial; l record; subtotal numeric; tax numeric; used numeric; result jsonb; party jsonb; company jsonb; act text=coalesce(c->>'action','issue');reason text=c->>'reason';
begin
 select * into r from public.work_commercial where id=(c->>'id')::uuid for update;
 if r.id is null then raise exception 'BUSINESS: Record not found.';end if;
 perform private.work_require(private.work_commercial_area(r.kind),r.assigned_to,case when r.kind in ('purchase','credit') or (r.kind='order' and r.quote_id is null) or r.discount_minor>0 or act='cancel' then 'approve' else 'write' end);
 if length(trim(coalesce(reason,''))) not between 5 and 500 then raise exception 'BUSINESS: Enter an approval or issue reason.';end if;
 if r.status='issued' and act='issue' then return to_jsonb(r);end if;
 if r.version<>(c->>'version')::integer then raise exception 'BUSINESS: Record changed. Refresh before continuing.';end if;
 if act='cancel' then
  if r.kind in ('invoice','credit') then raise exception 'BUSINESS: Correct issued invoices using credit notes.';end if;
  if exists(select 1 from public.work_commercial where source_id=r.id and status='issued') or exists(select 1 from public.work_reservations where order_id=r.id and released_at is null) or exists(select 1 from public.work_stock where order_id=r.id) then raise exception 'BUSINESS: Resolve linked fulfilment and documents before cancellation.';end if;
  update public.work_commercial set status='cancelled' where id=r.id;
 else
  if r.status<>'draft' then raise exception 'BUSINESS: Only drafts can be issued.';end if;
  if (r.kind in ('purchase','credit') or r.discount_minor>0) and r.assigned_to=auth.uid() and not private.work_allowed('members') then raise exception 'BUSINESS: Another authorized colleague must approve your document.';end if;
  select sum(quantity::numeric*unit_minor) into subtotal from public.work_commercial_lines where record_id=r.id;
  if subtotal is null or subtotal<r.discount_minor or subtotal>1000000000000 or (subtotal=r.discount_minor and r.kind not in ('rfq','delivery')) then raise exception 'BUSINESS: Invalid totals or missing line items.';end if;
  tax=round((subtotal-r.discount_minor)*r.tax_bps/10000);
  if r.kind in ('purchase','credit') then perform private.work_approval_gate(r.kind,r.currency,(subtotal-r.discount_minor+tax)::bigint);end if;
  if r.discount_minor>0 then perform private.work_approval_gate('discount',r.currency,r.discount_minor);end if;
  if subtotal-r.discount_minor+tax>1000000000000 then raise exception 'BUSINESS: Document total is too large.';end if;
  if r.kind='order' and r.quote_id is not null then
   perform 1 from public.work_documents where id=r.quote_id for update;
   if exists(select 1 from public.work_commercial where quote_id=r.quote_id and kind='order' and status='issued' and id<>r.id) then raise exception 'BUSINESS: This quotation already has an issued sales order. Open that order instead of issuing a duplicate.';end if;
   if not exists(select 1 from public.work_quotes q join public.work_documents d on d.id=q.document_id where q.document_id=r.quote_id and q.customer_id=r.customer_id and q.outcome='accepted' and d.status='issued' and d.payload->>'currency'=r.currency and d.total_minor=subtotal-r.discount_minor+tax)
   then raise exception 'BUSINESS: Use an accepted quotation for this customer, currency and agreed total.';end if;
   if (select jsonb_agg(jsonb_build_object('description',description,'quantity',quantity,'unit_minor',unit_minor) order by position) from public.work_commercial_lines where record_id=r.id) is distinct from (select payload->'items' from public.work_documents where id=r.quote_id) or r.discount_minor<>(select (payload->>'discount_minor')::bigint from public.work_documents where id=r.quote_id) or r.tax_bps<>(select (payload->>'tax_bps')::integer from public.work_documents where id=r.quote_id) then raise exception 'BUSINESS: Order lines and adjustments must match the accepted quotation. Revise the quotation before changing the agreement.';end if;
  end if;
  if r.kind in ('invoice','credit','delivery') then
   select * into s from public.work_commercial where id=r.source_id for update;
   if s.id is null or s.status<>'issued' or s.customer_id<>r.customer_id or s.currency<>r.currency or (r.kind='credit' and s.kind<>'invoice') or (r.kind<>'credit' and s.kind<>'order') then raise exception 'BUSINESS: Link the correct issued source order or invoice.';end if;
   for l in select * from public.work_commercial_lines where record_id=r.id order by position loop
    if l.task_id is not null then
     perform 1 from public.work_tasks t join public.work_cases k on k.id=t.case_id where t.id=l.task_id and t.billable and t.status='done' and k.customer_id=r.customer_id and k.order_id=s.id for update of t;
     if not found or r.kind<>'invoice' or exists(select 1 from public.work_commercial_lines ml join public.work_commercial mh on mh.id=ml.record_id where ml.task_id=l.task_id and mh.status='issued' and mh.kind='invoice') then raise exception 'BUSINESS: Use an unbilled completed milestone for this order and customer.';end if;
    end if;
    if l.source_line_id is null or not exists(select 1 from public.work_commercial_lines sl where sl.id=l.source_line_id and sl.record_id=s.id and (r.kind='delivery' or sl.unit_minor=l.unit_minor) and sl.item_id is not distinct from l.item_id) then raise exception 'BUSINESS: Each line must reference an unchanged source line price.';end if;
    select coalesce(sum(x.quantity),0) into used from public.work_commercial_lines x join public.work_commercial h on h.id=x.record_id where x.source_line_id=l.source_line_id and h.kind=r.kind and h.status='issued';
    used=used+(select sum(x.quantity) from public.work_commercial_lines x where x.record_id=r.id and x.source_line_id=l.source_line_id);
    if r.kind='delivery' then used=used-(select coalesce(sum(st.quantity),0) from public.work_stock st join public.work_commercial_lines dl on dl.id=st.source_line_id where dl.source_line_id=l.source_line_id and st.kind='return' and st.quantity>0);end if;
    if r.kind in ('invoice','delivery') then used=used+(select coalesce(sum(quantity),0) from public.work_order_cancellations where line_id=l.source_line_id);end if;
    if used>(select quantity from public.work_commercial_lines where id=l.source_line_id) then raise exception 'BUSINESS: Quantity exceeds the remaining source quantity.';end if;
   end loop;
   select coalesce(sum(total_minor),0) into used from public.work_commercial where source_id=s.id and kind=r.kind and status='issued';
   if r.kind<>'delivery' and used+subtotal-r.discount_minor+tax>s.total_minor then raise exception 'BUSINESS: Amount exceeds the remaining source value.';end if;
   if r.kind='credit' then
    select coalesce(sum(amount_minor),0) into used from public.work_allocations where invoice_id=s.id and reversed_at is null;
    if used+(select coalesce(sum(total_minor),0) from public.work_commercial where source_id=s.id and kind='credit' and status='issued')+subtotal-r.discount_minor+tax>s.total_minor then raise exception 'BUSINESS: Reverse the affected payment allocation before issuing this credit.';end if;
   end if;
  end if;
  if r.kind in ('purchase','rfq') then select to_jsonb(t) into party from public.work_suppliers t where id=r.supplier_id and not archived;
  else select to_jsonb(t) into party from public.work_customers t where id=r.customer_id and not archived;end if;
  if party is null then raise exception 'BUSINESS: Select an active customer or supplier.';end if;
  select payload into company from public.work_settings where id=1;
  update public.work_commercial set status='issued',number=private.work_number(case r.kind when 'order' then 'ORD' when 'invoice' then 'INV' when 'credit' then 'CRN' when 'purchase' then 'PO' when 'rfq' then 'RFQ' else 'DLV' end),total_minor=subtotal-r.discount_minor+tax,issued_at=now(),snapshot=jsonb_build_object('party',party,'company',company,'template_version',1) where id=r.id;
 end if;
 insert into public.work_decisions(record_id,action,record_version,reason) values(r.id,act,r.version,reason);
 select to_jsonb(t) into result from public.work_commercial t where id=r.id;return result;
end;$$;

create or replace view public.work_stock_balances with(security_invoker=true) as
 select s.item_id,s.location,s.serial,sum(s.quantity)::bigint on_hand,
 coalesce((select sum(r.quantity) from public.work_reservations r where r.item_id=s.item_id and r.location=s.location and r.serial=s.serial and released_at is null),0)::bigint reserved,
 coalesce((select sum(h.quantity) from public.work_stock_holds h join public.work_stock st on st.id=h.movement_id where st.item_id=s.item_id and st.location=s.location and st.serial=s.serial and h.released_at is null),0)::bigint quarantined
 from public.work_stock s group by s.item_id,s.location,s.serial;
create or replace function private.work_backup_job(proof text,c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.work_backup_runs;result jsonb='{}';tbl text;rows jsonb;total bigint=0;manifest jsonb;
begin
 if length(coalesce(proof,''))<>64 or not exists(select 1 from private.work_job_config where id=1 and proof_hash=encode(sha256(convert_to(proof,'UTF8')),'hex')) then raise exception using errcode='42501',message='Invalid backup proof';end if;
 if c->>'action'='begin' then
  perform pg_advisory_xact_lock(87182345);
  if exists(select 1 from public.work_backup_runs where day=current_date and status in ('primary','complete')) or exists(select 1 from public.work_backup_runs where status='running' and created_at>now()-interval '10 minutes') then return null;end if;
  update public.work_backup_runs set status='failed',last_error='Backup lease expired',updated_at=now() where status='running';
  insert into public.work_backup_runs(path) values('daily/'||current_date||'-'||gen_random_uuid()||'.lutera') returning * into r;
  for tbl in select unnest(array['work_members','work_settings','work_site_drafts','work_documents','work_staff','work_audit','work_public_site','work_publications','work_profiles','work_grants','work_customers','work_contacts','work_enquiries','work_opportunities','work_suppliers','work_items','work_quotes','work_commercial','work_commercial_lines','work_files','work_payments','work_allocations','work_refunds','work_cases','work_tasks','work_notes','work_stock','work_reservations','work_assets','work_expenses','work_supplier_payments','work_decisions','work_messages','work_bank_lines','work_portal_members','work_portal_shares','work_portal_events','work_offers','work_automation','work_portal_case_shares','work_customer_merges','work_calendar','work_case_service','work_case_templates','work_case_events','work_case_changes','work_locations','work_inspections','work_stock_holds','work_order_progress','work_order_cancellations','work_maintenance_visits','work_supplier_bank','work_cost_allocations','work_operating_policy','work_acceptance_requests','work_portal_evidence','work_shipments','work_approval_rules']) loop
   execute format('select coalesce(jsonb_agg(to_jsonb(t)),''[]''::jsonb) from public.%I t',tbl) into rows;
   total=total+jsonb_array_length(rows);if total>50000 then raise exception 'Backup record limit exceeded';end if;
   result=result||jsonb_build_object(tbl,rows);
  end loop;
  result=result||jsonb_build_object('private.work_counters',coalesce((select jsonb_agg(to_jsonb(t)) from private.work_counters t),'[]'::jsonb),'private.work_requests',coalesce((select jsonb_agg(to_jsonb(t)) from private.work_requests t),'[]'::jsonb),'private.work_message_statements',coalesce((select jsonb_agg(to_jsonb(t)) from private.work_message_statements t),'[]'::jsonb),'private.work_ops_requests',coalesce((select jsonb_agg(to_jsonb(t)) from private.work_ops_requests t),'[]'::jsonb),'format','lutera-business-records-v2','created_at',now(),'auth_users_included',false);
  select coalesce(jsonb_agg(jsonb_build_object('bucket',bucket_id,'path',name)),'[]'::jsonb) into manifest from storage.objects where bucket_id in ('work-evidence','work-staff','work-avatars','work-portal-evidence');
  return jsonb_build_object('id',r.id,'path',r.path,'snapshot',result,'files',manifest);
 elsif c->>'action'='pending' then
  return coalesce((select jsonb_agg(to_jsonb(t)) from (select id,path,sha256 from public.work_backup_runs where status='primary' order by created_at limit 30)t),'[]'::jsonb);
 elsif c->>'action'='primary' then
  if c->>'sha256' !~ '^[a-f0-9]{64}$' then raise exception 'Invalid digest';end if;
  update public.work_backup_runs set status='primary',sha256=c->>'sha256',bytes=(c->>'bytes')::bigint,file_count=(c->>'file_count')::integer,last_error='',updated_at=now() where id=(c->>'id')::uuid and status='running' and exists(select 1 from storage.objects where bucket_id='work-backups' and name=work_backup_runs.path);
  if not found then raise exception 'Backup primary copy is missing';end if;
 elsif c->>'action'='offsite' then
  if length(coalesce(c->>'drive_id','')) not between 10 and 200 then raise exception 'Invalid Drive receipt';end if;
  if not exists(select 1 from public.work_backup_runs where id=(c->>'id')::uuid and sha256=c->>'sha256' and status in ('primary','complete')) then raise exception 'Backup digest or state mismatch';end if;
  update public.work_backup_runs set status='complete',drive_id=c->>'drive_id',last_error='',updated_at=now() where id=(c->>'id')::uuid and status='primary';
 elsif c->>'action'='failure' then
  update public.work_backup_runs set status=case when c->>'stage'='primary' then 'failed' else status end,last_error=case when c->>'stage'='primary' then 'Primary backup failed; inspect server integration health' else 'Google Drive copy failed; primary copy retained' end,updated_at=now() where id=(c->>'id')::uuid;
 else raise exception 'Unknown backup operation';end if;
 return jsonb_build_object('success',true);
end;$$;
create function public.work_reports_at(cutoff date) returns jsonb language sql stable security invoker set search_path='' as $$
 with eligible as (select * from public.work_commercial where status='issued' and document_date<=cutoff and issued_at<(cutoff+1)::timestamp at time zone 'Africa/Lagos'),
 balances as (select i.id,i.number,i.customer_id,i.currency,i.due_date,i.total_minor-
 coalesce((select sum(c.total_minor) from eligible c where c.source_id=i.id and c.kind='credit'),0)-
 coalesce((select sum(a.amount_minor) from public.work_allocations a where a.invoice_id=i.id and a.created_at<(cutoff+1)::timestamp at time zone 'Africa/Lagos' and (a.reversed_at is null or a.reversed_at>=(cutoff+1)::timestamp at time zone 'Africa/Lagos')),0) outstanding_minor from eligible i where i.kind='invoice'),
 bills as (select e.* from public.work_expenses e where e.incurred_on<=cutoff and exists(select 1 from public.work_decisions d where d.expense_id=e.id and d.action='approve' and d.created_at<(cutoff+1)::timestamp at time zone 'Africa/Lagos')),
 payables as (select e.id,e.title,s.name supplier,e.currency,e.due_on,e.amount_minor-coalesce((select sum(p.amount_minor) from public.work_supplier_payments p where p.expense_id=e.id and p.paid_on<=cutoff and (p.reversed_at is null or p.reversed_at>=(cutoff+1)::timestamp at time zone 'Africa/Lagos')),0) outstanding_minor from bills e left join public.work_suppliers s on s.id=e.supplier_id)
 select jsonb_build_object(
 'receivables',(select coalesce(jsonb_agg(x),'[]') from (select b.id,b.number,c.name customer,b.currency,b.due_date,b.outstanding_minor,case when b.due_date is null then 'No due date' when b.due_date>=cutoff then 'Current' when cutoff-b.due_date<=30 then '1–30 days' when cutoff-b.due_date<=60 then '31–60 days' when cutoff-b.due_date<=90 then '61–90 days' else 'Over 90 days' end ageing from balances b join public.work_customers c on c.id=b.customer_id where outstanding_minor>0 order by b.due_date nulls last limit 1000)x),
 'payables',(select coalesce(jsonb_agg(x),'[]') from (select *,case when due_on is null then 'No due date' when due_on>=cutoff then 'Current' when cutoff-due_on<=30 then '1–30 days' when cutoff-due_on<=60 then '31–60 days' when cutoff-due_on<=90 then '61–90 days' else 'Over 90 days' end ageing from payables where outstanding_minor>0 order by due_on nulls last limit 1000)x),
 'spending',(select coalesce(jsonb_agg(x),'[]') from (select category,currency,sum(amount_minor)::bigint amount_minor from bills group by category,currency)x),
 'cost_centers',(select coalesce(jsonb_agg(x),'[]') from (select coalesce(nullif(cost_center,''),'Unassigned') category,currency,sum(amount_minor)::bigint amount_minor from bills group by cost_center,currency)x),
 'projects',(select coalesce(jsonb_agg(x),'[]') from (select k.id,k.reference number,k.title,c.name customer,e.currency,sum(e.amount_minor)::bigint amount_minor from bills e join public.work_cases k on k.id=e.project_id join public.work_customers c on c.id=k.customer_id group by k.id,c.name,e.currency)x),
 'commitments',(select coalesce(jsonb_agg(x),'[]') from (select p.id,p.number,s.name supplier,p.currency,greatest(0,p.total_minor-coalesce((select sum(amount_minor) from bills where purchase_id=p.id),0))::bigint outstanding_minor,'Unbilled purchase commitment' ageing from eligible p join public.work_suppliers s on s.id=p.supplier_id where p.kind='purchase' order by p.issued_at desc limit 1000)x),
 'orders',(select coalesce(jsonb_agg(x),'[]') from (select o.id,o.number,o.title,o.currency,
 coalesce((select sum(i.total_minor) from eligible i where i.source_id=o.id and i.kind='invoice'),0)::bigint invoiced_minor,
 coalesce((select sum(cr.total_minor) from eligible cr join eligible i on i.id=cr.source_id where i.source_id=o.id and cr.kind='credit'),0)::bigint credited_minor,
 coalesce((select sum(e.cost_minor) from bills e where e.order_id=o.id and e.cost_currency=o.currency),0)::bigint recorded_cost_minor from eligible o where o.kind='order' order by o.created_at desc limit 1000)x));
$$;
revoke all on function public.work_reports_at(date) from public,anon;grant execute on function public.work_reports_at(date) to authenticated;
-- Retain the legacy current-report endpoint for older clients during rollout.
create or replace function public.work_business_reports() returns jsonb language sql stable security invoker set search_path='' as $$select public.work_reports_at(current_date)$$;



alter table public.work_automation add column enquiry_reminders boolean not null default false,add column warranty_reminders boolean not null default false,add column visit_reminders boolean not null default false,add column delivery_notices boolean not null default false;
alter table public.work_messages drop constraint work_messages_purpose_check;
alter table public.work_messages add constraint work_messages_purpose_check check(purpose in ('manual','enquiry-notification','invoice-reminder','maintenance-reminder','support-escalation','approval-request','enquiry-followup','warranty-reminder','visit-reminder','delivery-notice'));
create or replace function private.work_automation_settings(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if not private.work_allowed('members') then raise exception using errcode='42501',message='BUSINESS: Owner access required.';end if;
 update public.work_automation set enquiry_reminders=coalesce((c->>'enquiry_reminders')::boolean,enquiry_reminders),warranty_reminders=coalesce((c->>'warranty_reminders')::boolean,warranty_reminders),visit_reminders=coalesce((c->>'visit_reminders')::boolean,visit_reminders),delivery_notices=coalesce((c->>'delivery_notices')::boolean,delivery_notices),invoice_reminders=(c->>'invoice_reminders')::boolean,maintenance_reminders=(c->>'maintenance_reminders')::boolean,interval_days=(c->>'interval_days')::integer where id=1 and version=(c->>'version')::integer returning to_jsonb(work_automation.*) into result;
 if result is null then raise exception 'BUSINESS: Settings changed. Refresh before saving.';end if;return result;
end;$$;
alter function private.work_prepare_reminders() rename to work_prepare_initial_reminders;
create function private.work_prepare_reminders() returns integer language plpgsql security definer set search_path='' as $$
declare cfg public.work_automation;r record;n integer;notify text;key uuid;period bigint;
begin
 n=private.work_prepare_initial_reminders();select * into cfg from public.work_automation where id=1;
 select payload#>>'{company,email}' into notify from public.work_settings where id=1;
 period=extract(epoch from current_date)::bigint/(86400*cfg.interval_days);
 for r in
  select e.id,'enquiry-followup' purpose,'Follow-up due: '||e.reference subject,'Review enquiry '||e.reference||' and its recorded next action in the private workspace.' body,null::uuid customer_id,null::uuid record_id,notify recipient
  from public.work_enquiries e where cfg.enquiry_reminders and e.follow_up<=current_date and e.status not in ('won','lost','closed')
  union all
  select a.id,'warranty-reminder','Warranty review: '||a.serial,'Review the recorded warranty and service arrangements for asset '||a.serial||'. Recorded warranty end: '||a.warranty_until,null,null,notify from public.work_assets a where cfg.warranty_reminders and a.warranty_until between current_date and current_date+30
  union all
  select v.id,'visit-reminder','Maintenance visit due','Review the scheduled maintenance visit for '||v.scheduled_on||' in the private workspace.',null,null,notify from public.work_maintenance_visits v join public.work_cases k on k.id=v.case_id where cfg.visit_reminders and v.status='scheduled' and k.status not in ('closed','completed') and v.scheduled_on between current_date and current_date+7
  union all
  select h.id,'delivery-notice','Dispatch recorded: '||h.number,'Dispatch has been recorded against delivery note '||h.number||'. Please contact Lutera to confirm the delivery arrangements.',h.customer_id,h.id,c.email from public.work_commercial h join public.work_customers c on c.id=h.customer_id where cfg.delivery_notices and h.kind='delivery' and h.status='issued' and not c.archived and c.email<>'' and exists(select 1 from public.work_stock st join public.work_commercial_lines l on l.id=st.source_line_id where l.record_id=h.id and st.kind='dispatch') and not exists(select 1 from public.work_messages m where m.record_id=h.id and m.purpose='delivery-notice')
 loop
  if exists(select 1 from public.work_messages where subject=r.subject and purpose=r.purpose and created_at>now()-make_interval(days=>cfg.interval_days) and status<>'cancelled') then continue;end if;
  key=md5(r.id::text||':'||r.purpose||':'||period)::uuid;
  insert into public.work_messages(customer_id,record_id,recipient,subject,body,request_key,purpose,created_by,related_id) values(r.customer_id,r.record_id,r.recipient,r.subject,r.body,key,r.purpose,null,r.id) on conflict(request_key) do nothing;
  if found then n=n+1;end if;
 end loop;
 return n;
end;$$;
revoke all on function private.work_prepare_reminders() from public,anon,authenticated;

create table public.work_acceptance_requests(id uuid primary key default gen_random_uuid(),customer_id uuid not null references public.work_customers(id),share_id uuid not null references public.work_portal_shares(id),prompt text not null check(length(trim(prompt)) between 5 and 2000),status text not null default 'pending' check(status in ('pending','completed','withdrawn')),created_by uuid not null default auth.uid() references auth.users(id),created_at timestamptz not null default now());
create table public.work_portal_evidence(id uuid primary key,request_id uuid not null references public.work_acceptance_requests(id),path text not null unique,name text not null check(length(name) between 1 and 160),content_type text not null check(content_type in ('image/jpeg','application/pdf')),size integer not null check(size between 1 and 1048576),sha256 text not null check(sha256 ~ '^[a-f0-9]{64}$'),uploader_email text not null,status text not null default 'pending' check(status in ('pending','complete')),created_at timestamptz not null default now());
alter table public.work_acceptance_requests enable row level security;alter table public.work_portal_evidence enable row level security;
revoke all on public.work_acceptance_requests,public.work_portal_evidence from public,anon,authenticated;grant select on public.work_acceptance_requests,public.work_portal_evidence to authenticated;
create policy work_acceptance_requests_read on public.work_acceptance_requests for select to authenticated using(private.work_customer_allowed(customer_id));
create policy work_portal_evidence_read on public.work_portal_evidence for select to authenticated using(exists(select 1 from public.work_acceptance_requests r where r.id=request_id and private.work_customer_allowed(r.customer_id)));
create trigger work_acceptance_requests_audit after insert or update on public.work_acceptance_requests for each row execute function private.work_audit_change();
create index work_acceptance_requests_customer_idx on public.work_acceptance_requests(customer_id);create index work_acceptance_requests_share_idx on public.work_acceptance_requests(share_id);create index work_acceptance_requests_actor_idx on public.work_acceptance_requests(created_by);create index work_portal_evidence_request_idx on public.work_portal_evidence(request_id);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('work-portal-evidence','work-portal-evidence',false,1048576,array['image/jpeg','application/pdf']);
create function private.work_portal_object_allowed(p text,writing boolean default false) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.work_portal_evidence e join public.work_acceptance_requests r on r.id=e.request_id where e.path=p and (private.work_backup_proof() and (not writing or e.status='pending') or not writing and e.status='complete' and private.work_customer_allowed(r.customer_id)))
$$;
revoke all on function private.work_portal_object_allowed(text,boolean) from public;grant execute on function private.work_portal_object_allowed(text,boolean) to anon,authenticated;
create policy work_portal_evidence_object_read on storage.objects for select to anon,authenticated using(bucket_id='work-portal-evidence' and private.work_portal_object_allowed(name));
create policy work_portal_evidence_object_insert on storage.objects for insert to anon with check(bucket_id='work-portal-evidence' and private.work_portal_object_allowed(name,true));

alter function private.work_portal(text,jsonb) rename to work_portal_initial;
create function private.work_portal(proof text,c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare who text;req public.work_acceptance_requests;sh public.work_portal_shares;f public.work_portal_evidence;result jsonb;fid uuid;object_path text;
begin
 if proof is null or length(proof)<>64 or not exists(select 1 from private.work_job_config where id=1 and proof_hash=encode(sha256(convert_to(proof,'UTF8')),'hex')) then raise exception using errcode='42501',message='Invalid portal proof';end if;
 if length(c::text)>10000 then raise exception 'Invalid portal payload';end if;
 if c->>'action' not in ('state','reserve_evidence','complete_evidence') then return private.work_portal_initial(proof,c);end if;
 select email into who from private.work_portal_sessions where hash=c->>'session_hash' and expires_at>now();
 if who is null then raise exception using errcode='42501',message='Portal sign-in required';end if;
 if c->>'action'='state' then
  result=private.work_portal_initial(proof,c);
  return result||jsonb_build_object('acceptance_requests',(select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'prompt',r.prompt,'status',r.status,'document',coalesce(cr.number,ld.number))),'[]') from public.work_acceptance_requests r join public.work_portal_shares ps on ps.id=r.share_id and ps.active join public.work_portal_members pm on pm.customer_id=r.customer_id and pm.email=who and pm.active join public.work_customers cu on cu.id=r.customer_id and not cu.archived left join public.work_commercial cr on cr.id=ps.record_id left join public.work_documents ld on ld.id=ps.document_id where r.status<>'withdrawn' and (cr.status='issued' or ld.status='issued') and not exists(select 1 from public.work_quotes q where q.document_id=ld.id and q.outcome='superseded')));
 end if;
 select * into req from public.work_acceptance_requests where id=(c->>'request_id')::uuid for update;
 select * into sh from public.work_portal_shares where id=req.share_id and active;
 if req.id is null or req.status<>'pending' or sh.id is null or not exists(select 1 from public.work_portal_members pm join public.work_customers cu on cu.id=pm.customer_id and not cu.archived where pm.customer_id=req.customer_id and pm.email=who and pm.active) or not (exists(select 1 from public.work_commercial where id=sh.record_id and status='issued') or exists(select 1 from public.work_documents ld join public.work_quotes q on q.document_id=ld.id where ld.id=sh.document_id and ld.status='issued' and q.outcome<>'superseded')) then raise exception using errcode='42501',message='Evidence request unavailable';end if;
 if c->>'action'='reserve_evidence' then
  if exists(select 1 from public.work_portal_evidence where request_id=req.id and created_at>now()-interval '1 hour' group by request_id having count(*)>=5) then raise exception 'Evidence upload limit reached';end if;
  fid=(c->>'id')::uuid;object_path=req.id::text||'/'||fid||case when c->>'content_type'='application/pdf' then '.pdf' else '.jpg' end;
  insert into public.work_portal_evidence(id,request_id,path,name,content_type,size,sha256,uploader_email) values(fid,req.id,object_path,c->>'name',c->>'content_type',(c->>'size')::integer,c->>'sha256',who) returning * into f;
  return jsonb_build_object('id',f.id,'path',f.path);
 end if;
 select * into f from public.work_portal_evidence where id=(c->>'id')::uuid and request_id=req.id and uploader_email=who and status='pending' for update;
 if f.id is null or not exists(select 1 from storage.objects where bucket_id='work-portal-evidence' and name=f.path) then raise exception 'Evidence upload not complete';end if;
 update public.work_portal_evidence set status='complete' where id=f.id;update public.work_acceptance_requests set status='completed' where id=req.id;
 insert into public.work_portal_events(customer_id,email,action,record_id) values(req.customer_id,who,'acceptance_evidence_upload',req.id);
 return jsonb_build_object('success',true);
end;$$;
revoke all on function private.work_portal(text,jsonb) from public;grant execute on function private.work_portal(text,jsonb) to anon,authenticated;



alter table public.work_case_events add column note text not null default '' check(length(note)<=1000);
alter table public.work_case_service add column clock_paused_at timestamptz,add column response_remaining_minutes integer check(response_remaining_minutes>=0),add column clock_reason text not null default '' check(length(clock_reason)<=500),add column clock_evidence_id uuid references public.work_files(id);
create index work_case_service_clock_evidence_idx on public.work_case_service(clock_evidence_id);
create function private.work_business_minutes(started timestamptz,finished timestamptz) returns integer language plpgsql stable security definer set search_path='' as $$
declare cfg public.work_calendar;day date=(started at time zone 'Africa/Lagos')::date;last_day date=(finished at time zone 'Africa/Lagos')::date;lo timestamp;hi timestamp;total numeric=0;i integer;
begin
 select * into cfg from public.work_calendar where id=1;
 if finished<=started then return 0;end if;
 for i in 1..401 loop
  exit when day>last_day;
  if extract(dow from day)::integer=any(cfg.days) and not day=any(cfg.holidays) then
   lo=greatest(started at time zone 'Africa/Lagos',day+make_interval(mins=>cfg.start_minute));hi=least(finished at time zone 'Africa/Lagos',day+make_interval(mins=>cfg.end_minute));
   total=total+greatest(0,extract(epoch from hi-lo)/60);
  end if;
  day=day+1;
 end loop;
 if day<=last_day then raise exception 'BUSINESS: Service deadline exceeds the supported calendar horizon.';end if;
 return ceil(total)::integer;
end;$$;
revoke all on function private.work_business_minutes(timestamptz,timestamptz) from public,anon,authenticated;



create function public.work_business_dashboard_filtered(start_date date,end_date date,owner_id uuid,service text) returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object(
 'enquiries_open',(select count(*) from public.work_enquiries where (owner_id is null or assigned_to=owner_id) and (service='' or service=any(services) or case service when 'ai-automation' then 'ai' when 'cloud-integration' then 'cloud' when 'installation-labs' then 'support' else service end=any(services)) and status not in ('won','lost','closed')),
 'followups_due',(select count(*) from public.work_enquiries where (owner_id is null or assigned_to=owner_id) and (service='' or service=any(services) or case service when 'ai-automation' then 'ai' when 'cloud-integration' then 'cloud' when 'installation-labs' then 'support' else service end=any(services)) and follow_up<=current_date and status not in ('won','lost','closed')),
 'projects_active',(select count(*) from public.work_cases where (owner_id is null or assigned_to=owner_id) and (service='' or category=service) and kind='project' and status not in ('completed','closed')),
 'tickets_open',(select count(*) from public.work_cases where (owner_id is null or assigned_to=owner_id) and (service='' or category=service) and kind='ticket' and status not in ('completed','closed')),
 'tasks_due',(select count(*) from public.work_tasks where (owner_id is null or assigned_to=owner_id) and (service='' or exists(select 1 from public.work_cases k where k.id=case_id and k.category=service)) and due_on<=current_date and status<>'done'),
 'currency_totals',(select coalesce(jsonb_agg(t),'[]'::jsonb) from (
 select c currency,
 (select coalesce(sum(total_minor),0) from public.work_commercial where kind='invoice' and status='issued' and currency=c and (start_date is null or document_date>=start_date) and (end_date is null or document_date<=end_date)) invoiced_minor,
 (select coalesce(sum(amount_minor),0) from public.work_payments where status='confirmed' and currency=c and (start_date is null or paid_on>=start_date) and (end_date is null or paid_on<=end_date)) received_minor,
 (select coalesce(sum(r.amount_minor),0) from public.work_refunds r join public.work_payments p on p.id=r.payment_id where p.currency=c and (start_date is null or r.created_at::date>=start_date) and (end_date is null or r.created_at::date<=end_date)) refunded_minor,
 (select coalesce(sum(outstanding_minor),0) from public.work_invoice_balances where currency=c) outstanding_minor,
 (select coalesce(sum(outstanding_minor),0) from public.work_invoice_balances where currency=c and due_date<current_date) overdue_minor,
 (select coalesce(sum(amount_minor),0) from public.work_expenses where currency=c and status='approved' and (start_date is null or incurred_on>=start_date) and (end_date is null or incurred_on<=end_date)) expenses_minor
 from unnest(array['NGN','USD','GBP','EUR']) c) t));
$$;
revoke all on function public.work_business_dashboard_filtered(date,date,uuid,text) from public,anon;grant execute on function public.work_business_dashboard_filtered(date,date,uuid,text) to authenticated;
create function private.work_log_file_read(kind text,fid uuid) returns boolean language plpgsql security definer set search_path='' as $$
begin
 if not private.work_allowed('session') then raise exception using errcode='42501',message='BUSINESS: Sign in and complete MFA.';end if;
 if kind='staff-evidence' then
  if not exists(select 1 from public.work_files f where f.id=fid and private.work_ops_allowed(f.area,f.owner_id)) then raise exception using errcode='42501',message='BUSINESS: Evidence access required.';end if;
 elsif kind='customer-evidence' then
  if not exists(select 1 from public.work_portal_evidence f join public.work_acceptance_requests r on r.id=f.request_id where f.id=fid and f.status='complete' and private.work_customer_allowed(r.customer_id)) then raise exception using errcode='42501',message='BUSINESS: Customer evidence access required.';end if;
 else raise exception 'BUSINESS: Unsupported evidence kind.';end if;
 insert into public.work_audit(action,entity,entity_id) values('authorized_file_read',kind,fid::text);return true;
end;$$;
revoke all on function private.work_log_file_read(text,uuid) from public,anon;grant execute on function private.work_log_file_read(text,uuid) to authenticated;
create function public.work_log_file_read(kind text,fid uuid) returns boolean language sql security invoker set search_path='' as $$select private.work_log_file_read(kind,fid)$$;
revoke all on function public.work_log_file_read(text,uuid) from public,anon;grant execute on function public.work_log_file_read(text,uuid) to authenticated;

create table public.work_shipments(id uuid primary key default gen_random_uuid(),purchase_line_id uuid not null references public.work_commercial_lines(id),quantity integer not null check(quantity between 1 and 1000000),status text not null check(status in ('planned','shipped','arrived','delayed','returned','cancelled')),carrier text not null default '' check(length(carrier)<=160),tracking_reference text not null default '' check(length(tracking_reference)<=200),shipped_on date,expected_on date,notes text not null default '' check(length(notes)<=2000),evidence_id uuid references public.work_files(id),version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
alter table public.work_shipments enable row level security;revoke all on public.work_shipments from public,anon,authenticated;grant select on public.work_shipments to authenticated;
create policy work_shipments_read on public.work_shipments for select to authenticated using(exists(select 1 from public.work_commercial_lines l join public.work_commercial h on h.id=l.record_id where l.id=purchase_line_id and private.work_ops_allowed('procurement',h.assigned_to)));
create trigger work_shipments_audit after insert or update on public.work_shipments for each row execute function private.work_audit_change();
create trigger work_shipments_touch before update on public.work_shipments for each row execute function private.work_touch();
create index work_shipments_line_idx on public.work_shipments(purchase_line_id);create index work_shipments_evidence_idx on public.work_shipments(evidence_id);





create or replace function private.work_prepare_initial_reminders() returns integer language plpgsql security definer set search_path='' as $$
declare cfg public.work_automation;r record;key uuid;n integer=0;notify text;period integer;
begin
 select * into cfg from public.work_automation where id=1;
 period=extract(epoch from current_date)::bigint/(86400*cfg.interval_days);
 if cfg.invoice_reminders then
  for r in select b.*,c.email from public.work_invoice_balances b join public.work_customers c on c.id=b.customer_id where b.outstanding_minor>0 and b.due_date<current_date and not c.archived and c.email<>'' loop
   if exists(select 1 from public.work_messages where record_id=r.id and purpose='invoice-reminder' and created_at>now()-make_interval(days=>cfg.interval_days) and status<>'cancelled') then continue;end if;
   key=md5(r.id::text||':invoice-reminder:'||period)::uuid;
   insert into public.work_messages(customer_id,record_id,recipient,subject,body,request_key,purpose,created_by) values(r.customer_id,r.id,r.email,'Invoice reminder: '||r.number,'Our records show an outstanding balance of '||r.currency||' '||to_char(r.outstanding_minor::numeric/100,'FM999999999990.00')||' for invoice '||r.number||'. Please contact Lutera if you need a statement or have already sent payment.',key,'invoice-reminder',null) on conflict(request_key) do nothing;
   if found then n=n+1;end if;
  end loop;
 end if;
 if cfg.maintenance_reminders then
  select payload#>>'{company,email}' into notify from public.work_settings where id=1;
  for r in select * from public.work_cases where kind='maintenance' and status not in ('closed','completed') and due_on between current_date and current_date+7 loop
   if exists(select 1 from public.work_messages where subject='Maintenance renewal: '||r.reference and purpose='maintenance-reminder' and created_at>now()-make_interval(days=>cfg.interval_days) and status<>'cancelled') then continue;end if;
   key=md5(r.id::text||':maintenance-reminder:'||period)::uuid;
   insert into public.work_messages(recipient,subject,body,request_key,purpose,created_by) values(notify,'Maintenance renewal: '||r.reference,'Review maintenance contract '||r.reference||' in the private workspace. Target renewal date: '||r.due_on,key,'maintenance-reminder',null) on conflict(request_key) do nothing;
   if found then n=n+1;end if;
  end loop;
 end if;
 select payload#>>'{company,email}' into notify from public.work_settings where id=1;
 for r in select * from public.work_cases where kind='ticket' and status not in ('closed','completed') and response_due_at<now() and responded_at is null and not exists(select 1 from public.work_case_service cs where cs.case_id=work_cases.id and cs.clock_paused_at is not null) loop
  key=md5(r.id::text||':support-escalation:'||current_date)::uuid;
  insert into public.work_messages(recipient,subject,body,request_key,purpose,created_by) values(notify,'Response target exceeded: '||r.reference,'Review support ticket '||r.reference||' in the private workspace. Its recorded first-response deadline has passed.',key,'support-escalation',null) on conflict(request_key) do nothing;
  if found then n=n+1;end if;
 end loop;
 return n;
end;$$;

create or replace function private.work_statement(cid uuid,from_date date,to_date date,ccy text) returns jsonb language plpgsql security definer set search_path='' as $$
declare events jsonb;opening bigint;cust jsonb;
begin
 perform private.work_require('finance',null,'read');
 select to_jsonb(c) into cust from public.work_customers c where id=cid;
 if cust is null or ccy not in ('NGN','USD','GBP','EUR') then raise exception 'BUSINESS: Customer or currency not found.';end if;
 with entries as (
  select document_date posted_on,kind,number reference,case kind when 'invoice' then total_minor else 0 end debit_minor,case kind when 'credit' then total_minor else 0 end credit_minor from public.work_commercial where customer_id=cid and currency=ccy and kind in ('invoice','credit') and status='issued'
  union all select p.paid_on,'payment',coalesce(d.number,p.reference),0,p.amount_minor from public.work_payments p left join public.work_documents d on d.id=p.receipt_id where p.customer_id=cid and p.currency=ccy and p.status='confirmed'
  union all select (r.created_at at time zone 'Africa/Lagos')::date,'refund',r.id::text,r.amount_minor,0 from public.work_refunds r join public.work_payments p on p.id=r.payment_id where p.customer_id=cid and p.currency=ccy
 ) select coalesce(jsonb_agg(to_jsonb(entries) order by posted_on,reference) filter(where (from_date is null or posted_on>=from_date) and (to_date is null or posted_on<=to_date)),'[]'::jsonb),coalesce(sum(debit_minor-credit_minor) filter(where from_date is not null and posted_on<from_date),0) into events,opening from entries;
 return jsonb_build_object('customer',cust,'currency',ccy,'opening_minor',opening,'events',events);
end;$$;
create function private.work_bank_review(rid uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 perform private.work_require('finance',null,'approve');
 select to_jsonb(t) into result from public.work_supplier_bank t where id=rid;
 if result is null then raise exception 'BUSINESS: Supplier bank record not found.';end if;
 insert into public.work_audit(action,entity,entity_id) values('authorized_bank_review','work_supplier_bank',rid::text);
 return result;
end;$$;
revoke all on function private.work_bank_review(uuid) from public,anon;grant execute on function private.work_bank_review(uuid) to authenticated;
create function public.work_bank_review(rid uuid) returns jsonb language sql security invoker set search_path='' as $$select private.work_bank_review(rid)$$;
revoke all on function public.work_bank_review(uuid) from public,anon;grant execute on function public.work_bank_review(uuid) to authenticated;

create or replace function private.work_finance_action(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.work_payments;a public.work_allocations;amount bigint;used bigint;result jsonb;cid uuid;
begin
 perform private.work_require('finance',null,'approve');
 if c->>'action'='reverse_allocation' then
  select * into a from public.work_allocations where id=(c->>'id')::uuid;
  select * into p from public.work_payments where id=a.payment_id for update;
  perform 1 from public.work_commercial where id=a.invoice_id for update;
  if a.id is null or length(trim(coalesce(c->>'reason','')))<5 then raise exception 'BUSINESS: Select an allocation and enter a correction reason.';end if;
  update public.work_allocations set reversed_at=now(),reason=c->>'reason' where id=a.id and reversed_at is null;return jsonb_build_object('success',true);
 elsif c->>'action'='link_legacy' then
  cid=(c->>'customer_id')::uuid;
  if not exists(select 1 from public.work_customers where id=cid and not archived) then raise exception 'BUSINESS: Choose an active customer.';end if;
  update public.work_payments set customer_id=cid where id=(c->>'id')::uuid and customer_id is null and not exists(select 1 from public.work_allocations where payment_id=work_payments.id);
  if not found then raise exception 'BUSINESS: Payment already linked or not found.';end if;return jsonb_build_object('success',true);
 elsif c->>'action'='refund' then
  select * into p from public.work_payments where id=(c->>'payment_id')::uuid for update;
  select to_jsonb(t) into result from public.work_refunds t where request_key=(c->>'request_key')::uuid;if result is not null then return result;end if;
  amount=(c->>'amount_minor')::bigint;
  perform private.work_approval_gate('refund',p.currency,amount);
  select coalesce(sum(amount_minor),0) into used from public.work_allocations where payment_id=p.id and reversed_at is null;
  used=used+(select coalesce(sum(amount_minor),0) from public.work_refunds where payment_id=p.id);
  if p.id is null or p.status<>'confirmed' or amount is null or amount<=0 or amount>p.amount_minor-used then raise exception 'BUSINESS: Refund exceeds the unallocated payment balance.';end if;
  perform private.work_evidence((c->>'evidence_id')::uuid,'finance');
  insert into public.work_refunds(payment_id,amount_minor,evidence_id,reason,request_key) values(p.id,amount,(c->>'evidence_id')::uuid,c->>'reason',(c->>'request_key')::uuid) returning to_jsonb(work_refunds.*) into result;return result;
 end if;
 raise exception 'BUSINESS: Unsupported financial action.';
end;$$;

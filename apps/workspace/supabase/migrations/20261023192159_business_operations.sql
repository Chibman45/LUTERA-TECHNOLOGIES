-- Additive operations schema. Existing documents and their counters are preserved.
create table public.work_grants (
 email text not null references public.work_members(email) on update cascade on delete cascade,
 area text not null check(area in ('sales','finance','procurement','inventory','projects','support','reports')),
 scope text not null check(scope in ('assigned','all')), write_access boolean not null default false,
 approve_access boolean not null default false, primary key(email,area)
);
create function private.work_ops_allowed(area text, assigned uuid default null, action text default 'read') returns boolean
language sql stable security definer set search_path='' as $$
 select private.work_allowed('session') and exists (
 select 1 from public.work_members m where m.user_id=auth.uid() and m.active and
 (m.role='owner' or
 (action<>'approve' and ((m.role='admin') or (m.role='finance' and area in ('finance','sales','reports')))) or
 exists(select 1 from public.work_grants g where g.email=m.email and g.area=work_ops_allowed.area
 and (g.scope='all' or assigned=auth.uid())
 and (action='read' or action='write' and g.write_access or action='approve' and g.approve_access))))
$$;
grant execute on function private.work_ops_allowed(text,uuid,text) to authenticated;
create function public.work_business_access() returns jsonb language sql security invoker set search_path='' as $$
 select jsonb_object_agg(a,jsonb_build_object('read',private.work_ops_allowed(a,auth.uid()),'write',private.work_ops_allowed(a,auth.uid(),'write'),'approve',private.work_ops_allowed(a,auth.uid(),'approve')))
 from unnest(array['sales','finance','procurement','inventory','projects','support','reports']) a
$$;
revoke all on function public.work_business_access() from public,anon;
grant execute on function public.work_business_access() to authenticated;

create table public.work_customers (
 id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name)) between 1 and 160),
 email text not null default '' check(length(email)<=254),phone text not null default '' check(length(phone)<=40),
 address text not null default '' check(length(address)<=600), delivery_address text not null default '' check(length(delivery_address)<=600),
 sector text not null default '' check(length(sector)<=100), tax_id text not null default '' check(length(tax_id)<=80),
 assigned_to uuid references auth.users(id), archived boolean not null default false,
 version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create index work_customers_name_idx on public.work_customers(lower(name),id);
create table public.work_contacts (
 id uuid primary key default gen_random_uuid(),customer_id uuid not null references public.work_customers(id),
 name text not null check(length(trim(name)) between 1 and 160),email text not null default '' check(length(email)<=254),
 phone text not null default '' check(length(phone)<=40),job_title text not null default '' check(length(job_title)<=120),
 version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.work_enquiries (
 id uuid primary key default gen_random_uuid(),reference text not null unique,
 name text not null check(length(trim(name)) between 1 and 160),email text not null default '' check(length(email)<=254),phone text not null default '' check(length(phone)<=40),
 subject text not null check(length(trim(subject)) between 1 and 200),message text not null check(length(message)<=12000),
 source text not null default 'manual' check(source in ('manual','website-contact','website-quote','website-enquiry','import')),
 services text[] not null default '{}',status text not null default 'new' check(status in ('new','acknowledged','qualified','quoting','won','lost','closed')),
 customer_id uuid references public.work_customers(id),assigned_to uuid references auth.users(id),
 follow_up date,loss_reason text not null default '' check(length(loss_reason)<=500),
 request_key uuid unique,version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create index work_enquiries_follow_idx on public.work_enquiries(follow_up,status);
create table public.work_opportunities (
 id uuid primary key default gen_random_uuid(),customer_id uuid not null references public.work_customers(id),enquiry_id uuid references public.work_enquiries(id),
 title text not null check(length(trim(title)) between 1 and 200), stage text not null default 'qualified' check(stage in ('qualified','quoting','negotiation','won','lost')),
 value_minor bigint not null default 0 check(value_minor between 0 and 1000000000000),currency text not null default 'NGN' check(currency in ('NGN','USD','GBP','EUR')),
 expected_close date,assigned_to uuid references auth.users(id),notes text not null default '' check(length(notes)<=4000),
 version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.work_suppliers (
 id uuid primary key default gen_random_uuid(),name text not null check(length(trim(name)) between 1 and 160),email text not null default '' check(length(email)<=254),
 phone text not null default '' check(length(phone)<=40),address text not null default '' check(length(address)<=600),
 categories text not null default '' check(length(categories)<=400),terms text not null default '' check(length(terms)<=3000),
 archived boolean not null default false,version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.work_items (
 id uuid primary key default gen_random_uuid(),sku text not null unique check(length(trim(sku)) between 1 and 60),name text not null check(length(trim(name)) between 1 and 200),
 description text not null default '' check(length(description)<=2000),kind text not null check(kind in ('stock','to_order','service')),
 unit text not null default 'unit' check(length(unit) between 1 and 30),unit_minor bigint not null default 0 check(unit_minor between 0 and 100000000000),
 currency text not null default 'NGN' check(currency in ('NGN','USD','GBP','EUR')),serialized boolean not null default false,
 archived boolean not null default false,version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),check(not serialized or kind='stock')
);
create table public.work_quotes (
 document_id uuid primary key references public.work_documents(id), customer_id uuid not null references public.work_customers(id),
 opportunity_id uuid references public.work_opportunities(id),previous_id uuid references public.work_quotes(document_id),
 outcome text not null default 'pending' check(outcome in ('pending','accepted','declined','superseded')),
 accepted_by text not null default '' check(length(accepted_by)<=160),accepted_at timestamptz, evidence_id uuid,
 assigned_to uuid references auth.users(id),created_at timestamptz not null default now()
);
create table public.work_commercial (
 id uuid primary key default gen_random_uuid(),kind text not null check(kind in ('order','invoice','credit','purchase','rfq','delivery')),
 customer_id uuid references public.work_customers(id),supplier_id uuid references public.work_suppliers(id),
 source_id uuid references public.work_commercial(id),quote_id uuid references public.work_documents(id),
 assigned_to uuid references auth.users(id),status text not null default 'draft' check(status in ('draft','issued','cancelled')),
 number text unique,title text not null check(length(trim(title)) between 1 and 200),
 document_date date not null default current_date,due_date date,currency text not null default 'NGN' check(currency in ('NGN','USD','GBP','EUR')),
 discount_minor bigint not null default 0 check(discount_minor between 0 and 1000000000000),tax_bps integer not null default 0 check(tax_bps between 0 and 10000),
 total_minor bigint not null default 0 check(total_minor between 0 and 1000000000000),
 notes text not null default '' check(length(notes)<=4000), snapshot jsonb, issued_at timestamptz,
 request_key uuid not null unique,version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 check((kind in ('purchase','rfq') and supplier_id is not null and customer_id is null) or (kind not in ('purchase','rfq') and customer_id is not null and supplier_id is null)),
 check(due_date is null or due_date>=document_date)
);
create index work_commercial_customer_idx on public.work_commercial(customer_id,document_date,id);
create index work_commercial_source_idx on public.work_commercial(source_id,kind,status);
create table public.work_commercial_lines (
 id uuid primary key default gen_random_uuid(),record_id uuid not null references public.work_commercial(id) on delete cascade,
 position integer not null check(position between 0 and 39),item_id uuid references public.work_items(id),source_line_id uuid references public.work_commercial_lines(id),
 description text not null check(length(trim(description)) between 1 and 400),quantity integer not null check(quantity between 1 and 1000000),
 unit_minor bigint not null check(unit_minor between 0 and 100000000000),unique(record_id,position)
);
create table public.work_files (
 id uuid primary key,owner_id uuid not null references auth.users(id),area text not null check(area in ('sales','finance','procurement','inventory','projects','support')),
 name text not null check(length(name) between 1 and 160),path text not null unique,content_type text not null check(content_type in ('image/jpeg','application/pdf')),
 size integer not null check(size between 1 and 1048576),sha256 text not null check(sha256 ~ '^[a-f0-9]{64}$'),created_at timestamptz not null default now()
);
alter table public.work_quotes add constraint work_quotes_evidence_fk foreign key(evidence_id) references public.work_files(id);
create table public.work_payments (
 id uuid primary key default gen_random_uuid(),receipt_id uuid unique references public.work_documents(id),customer_id uuid references public.work_customers(id),
 amount_minor bigint not null check(amount_minor between 1 and 1000000000000),currency text not null check(currency in ('NGN','USD','GBP','EUR')),
 paid_on date not null check(paid_on<=current_date),method text not null check(length(trim(method)) between 1 and 100),reference text not null default '' check(length(reference)<=160),
 evidence_id uuid references public.work_files(id), legacy boolean not null default false,status text not null default 'confirmed' check(status in ('confirmed','reversed')),
 reconciled boolean not null default false,created_by uuid references auth.users(id),created_at timestamptz not null default now(),
 check(legacy or evidence_id is not null)
);
create table public.work_allocations (
 id uuid primary key default gen_random_uuid(),payment_id uuid not null references public.work_payments(id),invoice_id uuid not null references public.work_commercial(id),
 amount_minor bigint not null check(amount_minor>0),request_key uuid not null unique,created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),
 reversed_at timestamptz,reason text not null default '' check(length(reason)<=500)
);
create index work_allocations_invoice_idx on public.work_allocations(invoice_id) where reversed_at is null;
create index work_allocations_payment_idx on public.work_allocations(payment_id) where reversed_at is null;
create table public.work_refunds (
 id uuid primary key default gen_random_uuid(),payment_id uuid not null references public.work_payments(id),amount_minor bigint not null check(amount_minor>0),
 evidence_id uuid not null references public.work_files(id),reason text not null check(length(trim(reason)) between 5 and 500),
 request_key uuid not null unique,created_by uuid not null default auth.uid(),created_at timestamptz not null default now()
);
create table public.work_cases (
 id uuid primary key default gen_random_uuid(),kind text not null check(kind in ('project','ticket','maintenance')),
 reference text not null unique,customer_id uuid not null references public.work_customers(id),order_id uuid references public.work_commercial(id),
 title text not null check(length(trim(title)) between 1 and 200),description text not null default '' check(length(description)<=6000),
 category text not null default '' check(length(category)<=100),status text not null default 'open' check(status in ('open','active','waiting','completed','closed')),
 priority text not null default 'normal' check(priority in ('low','normal','high','urgent')),
 assigned_to uuid references auth.users(id),starts_on date,due_on date,response_due_at timestamptz,responded_at timestamptz,
 acceptance_id uuid references public.work_files(id),accepted_by text not null default '' check(length(accepted_by)<=160),
 version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),check(due_on is null or starts_on is null or due_on>=starts_on)
);
create table public.work_tasks (
 id uuid primary key default gen_random_uuid(),case_id uuid not null references public.work_cases(id),title text not null check(length(trim(title)) between 1 and 200),
 description text not null default '' check(length(description)<=3000),assigned_to uuid references auth.users(id),due_on date,
 status text not null default 'todo' check(status in ('todo','doing','blocked','done')),billable boolean not null default false,
 version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.work_notes (
 id uuid primary key default gen_random_uuid(),customer_id uuid references public.work_customers(id),case_id uuid references public.work_cases(id),enquiry_id uuid references public.work_enquiries(id),
 body text not null check(length(trim(body)) between 1 and 4000),created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),
 check(num_nonnulls(customer_id,case_id,enquiry_id)=1)
);
create table public.work_stock (
 id uuid primary key default gen_random_uuid(),item_id uuid not null references public.work_items(id),location text not null check(length(trim(location)) between 1 and 120),
 serial text not null default '' check(length(serial)<=120),quantity integer not null check(quantity<>0 and abs(quantity)<=1000000),
 kind text not null check(kind in ('receive','dispatch','return','adjustment')),order_id uuid references public.work_commercial(id),
 source_line_id uuid references public.work_commercial_lines(id),reason text not null check(length(trim(reason)) between 5 and 500),
 evidence_id uuid references public.work_files(id),request_key uuid not null unique,created_by uuid not null default auth.uid(),created_at timestamptz not null default now()
);
create index work_stock_item_idx on public.work_stock(item_id,location,serial);
create table public.work_reservations (
 id uuid primary key default gen_random_uuid(),item_id uuid not null references public.work_items(id),location text not null check(length(trim(location)) between 1 and 120),
 serial text not null default '' check(length(serial)<=120),order_id uuid not null references public.work_commercial(id),
 quantity integer not null check(quantity between 1 and 1000000),request_key uuid not null unique,released_at timestamptz,
 created_by uuid not null default auth.uid(),created_at timestamptz not null default now()
);
create table public.work_assets (
 id uuid primary key default gen_random_uuid(),customer_id uuid not null references public.work_customers(id),item_id uuid references public.work_items(id),
 delivery_id uuid references public.work_commercial(id),serial text not null check(length(trim(serial)) between 1 and 120),
 site text not null check(length(site)<=600),accepted_on date,warranty_until date,
 terms text not null default '' check(length(terms)<=3000),created_at timestamptz not null default now(),unique(customer_id,serial),check(warranty_until is null or accepted_on is not null and warranty_until>=accepted_on)
);
create table public.work_expenses (
 id uuid primary key default gen_random_uuid(),supplier_id uuid references public.work_suppliers(id),order_id uuid references public.work_commercial(id),
 title text not null check(length(trim(title)) between 1 and 200),category text not null check(length(category)<=100),
 amount_minor bigint not null check(amount_minor between 1 and 1000000000000),currency text not null check(currency in ('NGN','USD','GBP','EUR')),
 incurred_on date not null,due_on date,evidence_id uuid not null references public.work_files(id),
 status text not null default 'draft' check(status in ('draft','submitted','approved','rejected')),created_by uuid not null default auth.uid(),
 version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.work_supplier_payments (
 id uuid primary key default gen_random_uuid(),expense_id uuid not null references public.work_expenses(id),amount_minor bigint not null check(amount_minor>0),
 paid_on date not null check(paid_on<=current_date),reference text not null check(length(reference)<=160),evidence_id uuid not null references public.work_files(id),
 request_key uuid not null unique,created_by uuid not null default auth.uid(),created_at timestamptz not null default now()
);
create table public.work_decisions (
 id uuid primary key default gen_random_uuid(),record_id uuid references public.work_commercial(id),expense_id uuid references public.work_expenses(id),
 action text not null check(action in ('issue','cancel','approve','reject')),record_version integer not null,
 reason text not null check(length(trim(reason)) between 5 and 500),actor uuid not null default auth.uid(),created_at timestamptz not null default now(),
 check(num_nonnulls(record_id,expense_id)=1)
);
create table public.work_messages (
 id uuid primary key default gen_random_uuid(),recipient text not null check(length(recipient)<=254),subject text not null check(length(subject)<=200),
 body text not null check(length(body)<=6000),record_id uuid references public.work_commercial(id),document_id uuid references public.work_documents(id),customer_id uuid references public.work_customers(id),
 status text not null default 'queued' check(status in ('queued','sending','sent','failed','cancelled')),attempts integer not null default 0,
 provider_id text, last_error text not null default '',request_key uuid not null unique,created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.work_bank_lines (
 id uuid primary key default gen_random_uuid(),fingerprint text not null unique,posted_on date not null,amount_minor bigint not null check(amount_minor<>0),
 currency text not null check(currency in ('NGN','USD','GBP','EUR')),reference text not null check(length(reference)<=200),
 payment_id uuid references public.work_payments(id),created_by uuid not null default auth.uid(),created_at timestamptz not null default now()
);

-- All write APIs are bounded transactions. Tables grant SELECT only; each definer
-- helper rechecks live membership, MFA, capability and assignment on every action.

create function private.work_customer_allowed(cid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.work_customers c where c.id=cid and
 (private.work_ops_allowed('sales',c.assigned_to) or private.work_ops_allowed('finance',null) or
 exists(select 1 from public.work_cases k where k.customer_id=c.id and private.work_ops_allowed(case when k.kind='project' then 'projects' else 'support' end,k.assigned_to))))
$$;
grant execute on function private.work_customer_allowed(uuid) to authenticated;
create function private.work_commercial_area(kind text) returns text language sql immutable set search_path='' as $$
 select case when kind in ('invoice','credit') then 'finance' when kind in ('purchase','rfq') then 'procurement' when kind='delivery' then 'inventory' else 'sales' end
$$;
grant execute on function private.work_commercial_area(text) to authenticated;
alter table public.work_grants enable row level security;
revoke all on public.work_grants from public,anon,authenticated;
grant select on public.work_grants to authenticated;
create policy work_grants_read on public.work_grants for select to authenticated using (private.work_allowed('members') or exists(select 1 from public.work_members m where m.user_id=auth.uid() and m.email=work_grants.email and private.work_allowed('session')));
alter table public.work_customers enable row level security;
revoke all on public.work_customers from public,anon,authenticated;
grant select on public.work_customers to authenticated;
create policy work_customers_read on public.work_customers for select to authenticated using (private.work_customer_allowed(id));
create trigger work_customers_audit after insert or update or delete on public.work_customers for each row execute function private.work_audit_change();
alter table public.work_contacts enable row level security;
revoke all on public.work_contacts from public,anon,authenticated;
grant select on public.work_contacts to authenticated;
create policy work_contacts_read on public.work_contacts for select to authenticated using (private.work_customer_allowed(customer_id));
create trigger work_contacts_audit after insert or update or delete on public.work_contacts for each row execute function private.work_audit_change();
alter table public.work_enquiries enable row level security;
revoke all on public.work_enquiries from public,anon,authenticated;
grant select on public.work_enquiries to authenticated;
create policy work_enquiries_read on public.work_enquiries for select to authenticated using (private.work_ops_allowed('sales',assigned_to));
create trigger work_enquiries_audit after insert or update or delete on public.work_enquiries for each row execute function private.work_audit_change();
alter table public.work_opportunities enable row level security;
revoke all on public.work_opportunities from public,anon,authenticated;
grant select on public.work_opportunities to authenticated;
create policy work_opportunities_read on public.work_opportunities for select to authenticated using (private.work_ops_allowed('sales',assigned_to));
create trigger work_opportunities_audit after insert or update or delete on public.work_opportunities for each row execute function private.work_audit_change();
alter table public.work_suppliers enable row level security;
revoke all on public.work_suppliers from public,anon,authenticated;
grant select on public.work_suppliers to authenticated;
create policy work_suppliers_read on public.work_suppliers for select to authenticated using (private.work_ops_allowed('procurement') or private.work_ops_allowed('finance'));
create trigger work_suppliers_audit after insert or update or delete on public.work_suppliers for each row execute function private.work_audit_change();
alter table public.work_items enable row level security;
revoke all on public.work_items from public,anon,authenticated;
grant select on public.work_items to authenticated;
create policy work_items_read on public.work_items for select to authenticated using (private.work_ops_allowed('sales') or private.work_ops_allowed('inventory') or private.work_ops_allowed('procurement'));
create trigger work_items_audit after insert or update or delete on public.work_items for each row execute function private.work_audit_change();
alter table public.work_quotes enable row level security;
revoke all on public.work_quotes from public,anon,authenticated;
grant select on public.work_quotes to authenticated;
create policy work_quotes_read on public.work_quotes for select to authenticated using (private.work_ops_allowed('sales',assigned_to) or private.work_ops_allowed('finance'));
create trigger work_quotes_audit after insert or update or delete on public.work_quotes for each row execute function private.work_audit_change();
alter table public.work_commercial enable row level security;
revoke all on public.work_commercial from public,anon,authenticated;
grant select on public.work_commercial to authenticated;
create policy work_commercial_read on public.work_commercial for select to authenticated using (private.work_ops_allowed(private.work_commercial_area(kind),assigned_to));
create trigger work_commercial_audit after insert or update or delete on public.work_commercial for each row execute function private.work_audit_change();
alter table public.work_commercial_lines enable row level security;
revoke all on public.work_commercial_lines from public,anon,authenticated;
grant select on public.work_commercial_lines to authenticated;
create policy work_commercial_lines_read on public.work_commercial_lines for select to authenticated using (exists(select 1 from public.work_commercial r where r.id=record_id));
create trigger work_commercial_lines_audit after insert or update or delete on public.work_commercial_lines for each row execute function private.work_audit_change();
alter table public.work_files enable row level security;
revoke all on public.work_files from public,anon,authenticated;
grant select on public.work_files to authenticated;
create policy work_files_read on public.work_files for select to authenticated using (private.work_ops_allowed(area,owner_id));
create trigger work_files_audit after insert or update or delete on public.work_files for each row execute function private.work_audit_change();
alter table public.work_payments enable row level security;
revoke all on public.work_payments from public,anon,authenticated;
grant select on public.work_payments to authenticated;
create policy work_payments_read on public.work_payments for select to authenticated using (private.work_ops_allowed('finance'));
create trigger work_payments_audit after insert or update or delete on public.work_payments for each row execute function private.work_audit_change();
alter table public.work_allocations enable row level security;
revoke all on public.work_allocations from public,anon,authenticated;
grant select on public.work_allocations to authenticated;
create policy work_allocations_read on public.work_allocations for select to authenticated using (private.work_ops_allowed('finance'));
create trigger work_allocations_audit after insert or update or delete on public.work_allocations for each row execute function private.work_audit_change();
alter table public.work_refunds enable row level security;
revoke all on public.work_refunds from public,anon,authenticated;
grant select on public.work_refunds to authenticated;
create policy work_refunds_read on public.work_refunds for select to authenticated using (private.work_ops_allowed('finance'));
create trigger work_refunds_audit after insert or update or delete on public.work_refunds for each row execute function private.work_audit_change();
alter table public.work_cases enable row level security;
revoke all on public.work_cases from public,anon,authenticated;
grant select on public.work_cases to authenticated;
create policy work_cases_read on public.work_cases for select to authenticated using (private.work_ops_allowed(case when kind='project' then 'projects' else 'support' end,assigned_to));
create trigger work_cases_audit after insert or update or delete on public.work_cases for each row execute function private.work_audit_change();
alter table public.work_tasks enable row level security;
revoke all on public.work_tasks from public,anon,authenticated;
grant select on public.work_tasks to authenticated;
create policy work_tasks_read on public.work_tasks for select to authenticated using (exists(select 1 from public.work_cases c where c.id=case_id));
create trigger work_tasks_audit after insert or update or delete on public.work_tasks for each row execute function private.work_audit_change();
alter table public.work_notes enable row level security;
revoke all on public.work_notes from public,anon,authenticated;
grant select on public.work_notes to authenticated;
create policy work_notes_read on public.work_notes for select to authenticated using (customer_id is not null and private.work_customer_allowed(customer_id) or exists(select 1 from public.work_cases c where c.id=case_id) or exists(select 1 from public.work_enquiries e where e.id=enquiry_id));
create trigger work_notes_audit after insert or update or delete on public.work_notes for each row execute function private.work_audit_change();
alter table public.work_stock enable row level security;
revoke all on public.work_stock from public,anon,authenticated;
grant select on public.work_stock to authenticated;
create policy work_stock_read on public.work_stock for select to authenticated using (private.work_ops_allowed('inventory'));
create trigger work_stock_audit after insert or update or delete on public.work_stock for each row execute function private.work_audit_change();
alter table public.work_reservations enable row level security;
revoke all on public.work_reservations from public,anon,authenticated;
grant select on public.work_reservations to authenticated;
create policy work_reservations_read on public.work_reservations for select to authenticated using (private.work_ops_allowed('inventory'));
create trigger work_reservations_audit after insert or update or delete on public.work_reservations for each row execute function private.work_audit_change();
alter table public.work_assets enable row level security;
revoke all on public.work_assets from public,anon,authenticated;
grant select on public.work_assets to authenticated;
create policy work_assets_read on public.work_assets for select to authenticated using (private.work_customer_allowed(customer_id) or private.work_ops_allowed('inventory'));
create trigger work_assets_audit after insert or update or delete on public.work_assets for each row execute function private.work_audit_change();
alter table public.work_expenses enable row level security;
revoke all on public.work_expenses from public,anon,authenticated;
grant select on public.work_expenses to authenticated;
create policy work_expenses_read on public.work_expenses for select to authenticated using (private.work_ops_allowed('finance'));
create trigger work_expenses_audit after insert or update or delete on public.work_expenses for each row execute function private.work_audit_change();
alter table public.work_supplier_payments enable row level security;
revoke all on public.work_supplier_payments from public,anon,authenticated;
grant select on public.work_supplier_payments to authenticated;
create policy work_supplier_payments_read on public.work_supplier_payments for select to authenticated using (private.work_ops_allowed('finance'));
create trigger work_supplier_payments_audit after insert or update or delete on public.work_supplier_payments for each row execute function private.work_audit_change();
alter table public.work_decisions enable row level security;
revoke all on public.work_decisions from public,anon,authenticated;
grant select on public.work_decisions to authenticated;
create policy work_decisions_read on public.work_decisions for select to authenticated using (private.work_ops_allowed('finance') or private.work_ops_allowed('procurement'));
create trigger work_decisions_audit after insert or update or delete on public.work_decisions for each row execute function private.work_audit_change();
alter table public.work_messages enable row level security;
revoke all on public.work_messages from public,anon,authenticated;
grant select on public.work_messages to authenticated;
create policy work_messages_read on public.work_messages for select to authenticated using (private.work_ops_allowed('sales') or private.work_ops_allowed('finance'));
create trigger work_messages_audit after insert or update or delete on public.work_messages for each row execute function private.work_audit_change();
alter table public.work_bank_lines enable row level security;
revoke all on public.work_bank_lines from public,anon,authenticated;
grant select on public.work_bank_lines to authenticated;
create policy work_bank_lines_read on public.work_bank_lines for select to authenticated using (private.work_ops_allowed('finance'));
create trigger work_bank_lines_audit after insert or update or delete on public.work_bank_lines for each row execute function private.work_audit_change();
create trigger work_customers_touch before update on public.work_customers for each row execute function private.work_touch();
create trigger work_contacts_touch before update on public.work_contacts for each row execute function private.work_touch();
create trigger work_enquiries_touch before update on public.work_enquiries for each row execute function private.work_touch();
create trigger work_opportunities_touch before update on public.work_opportunities for each row execute function private.work_touch();
create trigger work_suppliers_touch before update on public.work_suppliers for each row execute function private.work_touch();
create trigger work_items_touch before update on public.work_items for each row execute function private.work_touch();
create trigger work_cases_touch before update on public.work_cases for each row execute function private.work_touch();
create trigger work_tasks_touch before update on public.work_tasks for each row execute function private.work_touch();
create trigger work_expenses_touch before update on public.work_expenses for each row execute function private.work_touch();
create trigger work_commercial_touch before update on public.work_commercial for each row execute function private.work_touch();

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('work-evidence','work-evidence',false,1048576,array['image/jpeg','application/pdf']);
create policy work_evidence_insert on storage.objects for insert to authenticated with check(
 bucket_id='work-evidence' and exists(select 1 from public.work_files f where f.path=storage.objects.name and f.owner_id=auth.uid() and private.work_ops_allowed(f.area,f.owner_id,'write')));
create policy work_evidence_read on storage.objects for select to authenticated using(
 bucket_id='work-evidence' and exists(select 1 from public.work_files f where f.path=storage.objects.name and private.work_ops_allowed(f.area,f.owner_id)));
-- No update/delete storage grant: uploaded evidence is immutable. Orphan cleanup
-- is an operator maintenance task; referenced financial evidence is retained.

create function private.work_number(kind text) returns text language plpgsql security definer set search_path='' as $$
declare n integer; yr integer=extract(year from now() at time zone 'Africa/Lagos');
begin
 insert into private.work_counters(kind,year,next_value) values(kind,yr,1)
 on conflict on constraint work_counters_pkey do update set next_value=private.work_counters.next_value+1 returning next_value into n;
 return 'LUT-'||upper(kind)||'-'||yr||'-'||lpad(n::text,6,'0');
end;$$;

create function private.work_require(area text,assigned uuid default null,action text default 'write') returns void language plpgsql stable security definer set search_path='' as $$
begin if not private.work_ops_allowed(area,assigned,action) then raise exception using errcode='42501',message='BUSINESS: This action is not permitted for your account or assignment.';end if;end;$$;
create function private.work_evidence(fid uuid,area text) returns void language plpgsql stable security definer set search_path='' as $$
begin
 if fid is null or not exists(select 1 from public.work_files f join storage.objects o on o.bucket_id='work-evidence' and o.name=f.path where f.id=fid and f.area=work_evidence.area and private.work_ops_allowed(f.area,f.owner_id))
 then raise exception 'BUSINESS: Upload payment or acceptance evidence before continuing.';end if;
end;$$;
create function private.work_assignment(uid uuid) returns void language plpgsql stable security definer set search_path='' as $$
begin if uid is not null and not exists(select 1 from public.work_members where user_id=uid and active) then raise exception 'BUSINESS: Choose an active approved colleague.';end if;end;$$;

create function private.work_master(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare d jsonb=c->'data'; k text=c->>'entity'; rid uuid=coalesce(nullif(c->>'id','')::uuid,gen_random_uuid()); v integer=coalesce((c->>'version')::integer,0); a uuid; result jsonb; oldrow record;
begin
 if length(c::text)>40000 then raise exception 'BUSINESS: Record is too large.';end if;
 if k='customers' then
  select assigned_to into a from public.work_customers where id=rid;
  perform private.work_require('sales',coalesce(a,auth.uid()));
  perform private.work_assignment(nullif(d->>'assigned_to','')::uuid);
  if v=0 then insert into public.work_customers(id,name,email,phone,address,delivery_address,sector,tax_id,assigned_to) values(rid,d->>'name',coalesce(d->>'email',''),coalesce(d->>'phone',''),coalesce(d->>'address',''),coalesce(d->>'delivery_address',''),coalesce(d->>'sector',''),coalesce(d->>'tax_id',''),coalesce(nullif(d->>'assigned_to','')::uuid,auth.uid()));
  else update public.work_customers set name=d->>'name',email=coalesce(d->>'email',''),phone=coalesce(d->>'phone',''),address=coalesce(d->>'address',''),delivery_address=coalesce(d->>'delivery_address',''),sector=coalesce(d->>'sector',''),tax_id=coalesce(d->>'tax_id',''),archived=coalesce((d->>'archived')::boolean,false),assigned_to=nullif(d->>'assigned_to','')::uuid where id=rid and version=v; if not found then raise exception 'BUSINESS: Record changed. Refresh before saving.';end if;end if;
  select to_jsonb(t) into result from public.work_customers t where id=rid;
 elsif k='contacts' then
  select assigned_to into a from public.work_customers where id=(d->>'customer_id')::uuid;perform private.work_require('sales',a);
  if v=0 then insert into public.work_contacts(id,customer_id,name,email,phone,job_title) values(rid,(d->>'customer_id')::uuid,d->>'name',coalesce(d->>'email',''),coalesce(d->>'phone',''),coalesce(d->>'job_title',''));
  else update public.work_contacts set name=d->>'name',email=coalesce(d->>'email',''),phone=coalesce(d->>'phone',''),job_title=coalesce(d->>'job_title','') where id=rid and version=v and customer_id=(d->>'customer_id')::uuid;if not found then raise exception 'BUSINESS: Record changed. Refresh before saving.';end if;end if;
  select to_jsonb(t) into result from public.work_contacts t where id=rid;
 elsif k='enquiries' then
  select assigned_to into a from public.work_enquiries where id=rid; perform private.work_require('sales',coalesce(a,auth.uid())); perform private.work_assignment(nullif(d->>'assigned_to','')::uuid);
  if nullif(d->>'customer_id','') is not null and not private.work_customer_allowed((d->>'customer_id')::uuid) then raise exception 'BUSINESS: Customer access required.';end if;
  if v=0 then insert into public.work_enquiries(id,reference,name,email,phone,subject,message,customer_id,assigned_to,follow_up,services) values(rid,private.work_number('ENQ'),d->>'name',coalesce(d->>'email',''),coalesce(d->>'phone',''),d->>'subject',coalesce(d->>'message',''),nullif(d->>'customer_id','')::uuid,coalesce(nullif(d->>'assigned_to','')::uuid,auth.uid()),nullif(d->>'follow_up','')::date,array(select jsonb_array_elements_text(coalesce(d->'services','[]'))));
  else update public.work_enquiries set name=d->>'name',email=coalesce(d->>'email',''),phone=coalesce(d->>'phone',''),subject=d->>'subject',message=coalesce(d->>'message',''),customer_id=nullif(d->>'customer_id','')::uuid,assigned_to=nullif(d->>'assigned_to','')::uuid,status=d->>'status',follow_up=nullif(d->>'follow_up','')::date,loss_reason=coalesce(d->>'loss_reason',''),services=array(select jsonb_array_elements_text(coalesce(d->'services','[]'))) where id=rid and version=v;if not found then raise exception 'BUSINESS: Record changed. Refresh before saving.';end if;end if;
  if d->>'status'='lost' and length(trim(coalesce(d->>'loss_reason','')))<5 then raise exception 'BUSINESS: Record a loss reason.';end if;
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
create or replace function private.work_audit_change() returns trigger language plpgsql security definer set search_path='' as $$
declare j jsonb;begin
 if auth.uid() is null then if TG_OP='DELETE' then return old;else return new;end if;end if;
 j=case when TG_OP='DELETE' then to_jsonb(old) else to_jsonb(new) end;
 insert into public.work_audit(action,entity,entity_id) values(lower(TG_OP),TG_TABLE_NAME,coalesce(j->>'id',j->>'case_id',j->>'document_id',j->>'email','record'));
 if TG_OP='DELETE' then return old;else return new;end if;
end;$$;

create function private.work_commercial_save(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare d jsonb=c->'data'; rid uuid=coalesce(nullif(c->>'id','')::uuid,gen_random_uuid()); r public.work_commercial; l jsonb; i integer=0; area text; result jsonb;
begin
 area=private.work_commercial_area(d->>'kind');
 select * into r from public.work_commercial where id=rid for update;
 perform private.work_require(area,coalesce(r.assigned_to,auth.uid()));
 if r.id is not null and r.status<>'draft' then raise exception 'BUSINESS: Issued records are locked. Use a credit or approved correction.';end if;
 if r.id is not null and (r.version<>coalesce((c->>'version')::integer,0) or r.kind<>d->>'kind') then raise exception 'BUSINESS: Record changed. Refresh before saving.';end if;
 if r.id is null and exists(select 1 from public.work_commercial where request_key=(c->>'request_key')::uuid) then select to_jsonb(t) into result from public.work_commercial t where request_key=(c->>'request_key')::uuid and private.work_ops_allowed(private.work_commercial_area(kind),assigned_to);return result;end if;
 if d->>'kind' not in ('purchase','rfq') and not private.work_customer_allowed((d->>'customer_id')::uuid) and not (d->>'kind'='delivery' and exists(select 1 from public.work_commercial where id=nullif(d->>'source_id','')::uuid and kind='order' and status='issued' and customer_id=(d->>'customer_id')::uuid)) then raise exception 'BUSINESS: Customer access required.';end if;
 if jsonb_typeof(d->'lines') is distinct from 'array' or jsonb_array_length(d->'lines') not between 1 and 40 then raise exception 'BUSINESS: Add between one and forty lines.';end if;
 if r.id is null then
 insert into public.work_commercial(id,kind,customer_id,supplier_id,source_id,quote_id,assigned_to,title,document_date,due_date,currency,discount_minor,tax_bps,notes,request_key)
 values(rid,d->>'kind',nullif(d->>'customer_id','')::uuid,nullif(d->>'supplier_id','')::uuid,nullif(d->>'source_id','')::uuid,nullif(d->>'quote_id','')::uuid,auth.uid(),d->>'title',(d->>'document_date')::date,nullif(d->>'due_date','')::date,d->>'currency',coalesce((d->>'discount_minor')::bigint,0),coalesce((d->>'tax_bps')::integer,0),coalesce(d->>'notes',''),(c->>'request_key')::uuid);
 else
 update public.work_commercial set customer_id=nullif(d->>'customer_id','')::uuid,supplier_id=nullif(d->>'supplier_id','')::uuid,source_id=nullif(d->>'source_id','')::uuid,quote_id=nullif(d->>'quote_id','')::uuid,title=d->>'title',document_date=(d->>'document_date')::date,due_date=nullif(d->>'due_date','')::date,currency=d->>'currency',discount_minor=coalesce((d->>'discount_minor')::bigint,0),tax_bps=coalesce((d->>'tax_bps')::integer,0),notes=coalesce(d->>'notes','') where id=rid;
 delete from public.work_commercial_lines where record_id=rid;
 end if;
 for l in select * from jsonb_array_elements(d->'lines') loop
 insert into public.work_commercial_lines(record_id,position,item_id,source_line_id,description,quantity,unit_minor,task_id) values(rid,i,nullif(l->>'item_id','')::uuid,nullif(l->>'source_line_id','')::uuid,l->>'description',(l->>'quantity')::integer,(l->>'unit_minor')::bigint,nullif(l->>'task_id','')::uuid);i=i+1;
 end loop;
 select to_jsonb(t) into result from public.work_commercial t where id=rid;
 return result;
end;$$;
create function private.work_commercial_issue(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
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
  if r.kind in ('purchase','credit') and r.assigned_to=auth.uid() and not private.work_allowed('members') then raise exception 'BUSINESS: Another authorized colleague must approve your document.';end if;
  select sum(quantity::numeric*unit_minor) into subtotal from public.work_commercial_lines where record_id=r.id;
  if subtotal is null or subtotal<r.discount_minor or subtotal>1000000000000 or (subtotal=r.discount_minor and r.kind not in ('rfq','delivery')) then raise exception 'BUSINESS: Invalid totals or missing line items.';end if;
  tax=round((subtotal-r.discount_minor)*r.tax_bps/10000);
  if subtotal-r.discount_minor+tax>1000000000000 then raise exception 'BUSINESS: Document total is too large.';end if;
  if r.kind='order' and r.quote_id is not null then
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

-- Mandatory evidence applies to all newly issued legacy receipts too, including
-- direct table writes. Old issued receipts are preserved and marked legacy.
alter table public.work_payments add column request_key uuid unique;
insert into public.work_payments(receipt_id,amount_minor,currency,paid_on,method,reference,legacy,status)
 select id,total_minor,payload->>'currency',(payload->>'date')::date,payload->>'payment_method',payload->>'payment_reference',true,case status when 'void' then 'reversed' else 'confirmed' end from public.work_documents where kind='receipt' and status in ('issued','void');
create function private.work_receipt_evidence() returns trigger language plpgsql security definer set search_path='' as $$
declare cid uuid;
begin
 if new.kind='receipt' and new.status='issued' and old.status='draft' then
  perform private.work_evidence(nullif(new.payload->>'evidence_id','')::uuid,'finance');
  cid=nullif(new.payload->>'customer_id','')::uuid;
  if cid is not null and not exists(select 1 from public.work_customers where id=cid and name=new.payload#>>'{customer,name}' and private.work_customer_allowed(id)) then raise exception 'BUSINESS: Payment customer does not match the receipt.';end if;
 end if;
 if old.kind in ('quotation','proforma') and new.status='void' and exists(select 1 from public.work_commercial where quote_id=old.id and status='issued') then raise exception 'BUSINESS: Resolve the accepted order before voiding this quotation.';end if;
 if old.kind='receipt' and old.status='issued' and new.status='void' and exists(select 1 from public.work_payments p join public.work_allocations a on a.payment_id=p.id where p.receipt_id=old.id and a.reversed_at is null) then raise exception 'BUSINESS: Reverse payment allocations before voiding the receipt.';end if;
 if old.kind='receipt' and old.status='issued' and new.status='void' and exists(select 1 from public.work_payments p join public.work_refunds r on r.payment_id=p.id where p.receipt_id=old.id) then raise exception 'BUSINESS: Refunded payments cannot be voided.';end if;
 return new;
end;$$;
create trigger work_receipt_evidence before update on public.work_documents for each row execute function private.work_receipt_evidence();
create function private.work_receipt_register() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.kind='receipt' and new.status='issued' and old.status='draft' then
 insert into public.work_payments(receipt_id,customer_id,amount_minor,currency,paid_on,method,reference,evidence_id,created_by,request_key)
 values(new.id,nullif(new.payload->>'customer_id','')::uuid,new.total_minor,new.payload->>'currency',(new.payload->>'date')::date,new.payload->>'payment_method',new.payload->>'payment_reference',(new.payload->>'evidence_id')::uuid,auth.uid(),nullif(new.payload->>'request_key','')::uuid);
 elsif new.kind='receipt' and new.status='void' and old.status='issued' then update public.work_payments set status='reversed' where receipt_id=new.id;end if;
 return new;
end;$$;
create trigger work_receipt_register after update on public.work_documents for each row execute function private.work_receipt_register();

create function private.work_payment(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare d jsonb=c->'data'; cust public.work_customers; doc uuid; payload jsonb;result jsonb;
begin
 perform private.work_require('finance');
 select to_jsonb(t) into result from public.work_payments t where request_key=(c->>'request_key')::uuid;
 if result is not null then return result;end if;
 perform pg_advisory_xact_lock(hashtextextended(c->>'request_key',2));
 select to_jsonb(t) into result from public.work_payments t where request_key=(c->>'request_key')::uuid;if result is not null then return result;end if;
 select * into cust from public.work_customers where id=(d->>'customer_id')::uuid and not archived;
 if cust.id is null then raise exception 'BUSINESS: Choose an active customer.';end if;
 perform private.work_evidence((d->>'evidence_id')::uuid,'finance');
 if coalesce((d->>'confirmed')::boolean,false)=false then raise exception 'BUSINESS: Confirm you checked the payment before recording it.';end if;
 payload=jsonb_build_object('kind','receipt','customer',jsonb_build_object('name',cust.name,'address',cust.address,'email',cust.email,'phone',cust.phone),'date',d->>'paid_on','valid_until','','currency',d->>'currency','items',jsonb_build_array(jsonb_build_object('description',coalesce(d->>'description','Payment received'),'quantity',1,'unit_minor',(d->>'amount_minor')::bigint)),'discount_minor',0,'tax_bps',0,'notes','','payment_method',d->>'method','payment_reference',coalesce(d->>'reference',''),'payment_confirmed',true,'source_id','','evidence_id',d->>'evidence_id','customer_id',cust.id,'request_key',c->>'request_key');
 insert into public.work_documents(kind,payload) values('receipt',payload) returning id into doc;
 update public.work_documents set status='issued' where id=doc;
 select to_jsonb(t) into result from public.work_payments t where receipt_id=doc;return result;
end;$$;
create function private.work_allocate(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.work_payments;i public.work_commercial;used bigint;available bigint;amount bigint=(c->>'amount_minor')::bigint;result jsonb;
begin
 perform private.work_require('finance');
 select * into p from public.work_payments where id=(c->>'payment_id')::uuid for update;
 select * into i from public.work_commercial where id=(c->>'invoice_id')::uuid for update;
 select to_jsonb(t) into result from public.work_allocations t where request_key=(c->>'request_key')::uuid;if result is not null then return result;end if;
 if p.id is null or i.id is null or p.status<>'confirmed' or i.kind<>'invoice' or i.status<>'issued' or p.customer_id is distinct from i.customer_id or p.currency<>i.currency then raise exception 'BUSINESS: Select a confirmed payment and issued invoice for the same customer and currency.';end if;
 select p.amount_minor-coalesce(sum(amount_minor),0) into available from public.work_allocations where payment_id=p.id and reversed_at is null;
 available=available-(select coalesce(sum(amount_minor),0) from public.work_refunds where payment_id=p.id);
 select coalesce(sum(amount_minor),0) into used from public.work_allocations where invoice_id=i.id and reversed_at is null;
 used=used+(select coalesce(sum(total_minor),0) from public.work_commercial where source_id=i.id and kind='credit' and status='issued');
 if amount is null or amount<=0 or amount>available or amount>i.total_minor-used then raise exception 'BUSINESS: Allocation exceeds the available payment or invoice balance.';end if;
 insert into public.work_allocations(payment_id,invoice_id,amount_minor,request_key) values(p.id,i.id,amount,(c->>'request_key')::uuid) returning to_jsonb(work_allocations.*) into result;return result;
end;$$;
create function private.work_finance_action(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
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
  select coalesce(sum(amount_minor),0) into used from public.work_allocations where payment_id=p.id and reversed_at is null;
  used=used+(select coalesce(sum(amount_minor),0) from public.work_refunds where payment_id=p.id);
  if p.id is null or p.status<>'confirmed' or amount is null or amount<=0 or amount>p.amount_minor-used then raise exception 'BUSINESS: Refund exceeds the unallocated payment balance.';end if;
  perform private.work_evidence((c->>'evidence_id')::uuid,'finance');
  insert into public.work_refunds(payment_id,amount_minor,evidence_id,reason,request_key) values(p.id,amount,(c->>'evidence_id')::uuid,c->>'reason',(c->>'request_key')::uuid) returning to_jsonb(work_refunds.*) into result;return result;
 end if;
 raise exception 'BUSINESS: Unsupported financial action.';
end;$$;
create function private.work_stock_action(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
<<stock_op>>
declare item public.work_items;header public.work_commercial;line public.work_commercial_lines;
 qty integer=(c->>'quantity')::integer;location text=trim(c->>'location');serial text=trim(coalesce(c->>'serial',''));balance bigint;reserved bigint;used bigint;result jsonb;isreserve boolean=c->>'action'='reserve';kind text=c->>'kind';reservation public.work_reservations;original public.work_stock;
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
 if isreserve then
  select * into header from public.work_commercial where id=(c->>'order_id')::uuid for update;
  if header.id is null or header.kind<>'order' or header.status<>'issued' then raise exception 'BUSINESS: Reserve against an issued customer order.';end if;
  select coalesce(sum(quantity),0) into used from public.work_reservations where item_id=item.id and order_id=header.id and released_at is null;
  if qty>balance-reserved or qty+used>(select coalesce(sum(quantity),0) from public.work_commercial_lines where record_id=header.id and item_id=item.id) then raise exception 'BUSINESS: Reservation exceeds available stock or ordered quantity.';end if;
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
 end if;
 return result;
end;$$;
create function private.work_expense(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
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

  if r.id is null then insert into public.work_expenses(id,supplier_id,order_id,title,category,amount_minor,currency,incurred_on,due_on,evidence_id,cost_minor,cost_currency,fx_rate_micros,fx_date,fx_reference) values(rid,nullif(d->>'supplier_id','')::uuid,nullif(d->>'order_id','')::uuid,d->>'title',coalesce(d->>'category',''),(d->>'amount_minor')::bigint,d->>'currency',(d->>'incurred_on')::date,nullif(d->>'due_on','')::date,(d->>'evidence_id')::uuid,cost,targetccy,rate,nullif(d->>'fx_date','')::date,coalesce(d->>'fx_reference',''));
  else update public.work_expenses set supplier_id=nullif(d->>'supplier_id','')::uuid,order_id=nullif(d->>'order_id','')::uuid,cost_minor=cost,cost_currency=targetccy,fx_rate_micros=rate,fx_date=nullif(d->>'fx_date','')::date,fx_reference=coalesce(d->>'fx_reference',''),title=d->>'title',category=coalesce(d->>'category',''),amount_minor=(d->>'amount_minor')::bigint,currency=d->>'currency',incurred_on=(d->>'incurred_on')::date,due_on=nullif(d->>'due_on','')::date,evidence_id=(d->>'evidence_id')::uuid where id=rid;end if;
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
  select coalesce(sum(amount_minor),0) into used from public.work_supplier_payments where expense_id=r.id;
  if amount is null or amount<=0 or used+amount>r.amount_minor then raise exception 'BUSINESS: Supplier payment exceeds the unpaid amount.';end if;
  perform private.work_evidence((c->>'evidence_id')::uuid,'finance');
  insert into public.work_supplier_payments(expense_id,amount_minor,paid_on,reference,evidence_id,request_key) values(r.id,amount,(c->>'paid_on')::date,coalesce(c->>'reference',''),(c->>'evidence_id')::uuid,(c->>'request_key')::uuid) returning to_jsonb(work_supplier_payments.*) into result;return result;
 else raise exception 'BUSINESS: Unsupported expense action.';end if;
 select to_jsonb(t) into result from public.work_expenses t where id=rid;return result;
end;$$;

create function private.work_misc(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;cust public.work_customers;q public.work_documents; oldquote public.work_quotes;k public.work_cases;a uuid;cid uuid;
begin
 if c->>'action'='note' then
  if nullif(c->>'customer_id','') is not null then
   perform private.work_require('sales',(select assigned_to from public.work_customers where id=(c->>'customer_id')::uuid));
   if not private.work_customer_allowed((c->>'customer_id')::uuid) then raise exception using errcode='42501',message='BUSINESS: Customer access required.';end if;
  elsif nullif(c->>'case_id','') is not null then
   select * into k from public.work_cases where id=(c->>'case_id')::uuid;perform private.work_require(case when k.kind='project' then 'projects' else 'support' end,k.assigned_to);
  elsif nullif(c->>'enquiry_id','') is not null then
   select assigned_to into a from public.work_enquiries where id=(c->>'enquiry_id')::uuid;perform private.work_require('sales',a);
  else raise exception 'BUSINESS: Link a customer, project, ticket or enquiry.';end if;
  insert into public.work_notes(customer_id,case_id,enquiry_id,body) values(nullif(c->>'customer_id','')::uuid,nullif(c->>'case_id','')::uuid,nullif(c->>'enquiry_id','')::uuid,c->>'body') returning to_jsonb(work_notes.*) into result;
 elsif c->>'action'='quote_link' then
  perform private.work_require('sales',auth.uid());
  select * into q from public.work_documents where id=(c->>'document_id')::uuid;
  if q.id is null or q.kind='receipt' then raise exception 'BUSINESS: Select a quotation or pro forma.';end if;
  cid=(c->>'customer_id')::uuid;if not private.work_customer_allowed(cid) then raise exception 'BUSINESS: Customer access required.';end if;
  if exists(select 1 from public.work_quotes where document_id=q.id) then raise exception 'BUSINESS: This document is already linked.';end if;
  if q.payload#>>'{customer,name}'<>(select name from public.work_customers where id=cid) then raise exception 'BUSINESS: The document customer must match the directory customer.';end if;
  insert into public.work_quotes(document_id,customer_id,opportunity_id,assigned_to) values(q.id,cid,nullif(c->>'opportunity_id','')::uuid,auth.uid()) returning to_jsonb(work_quotes.*) into result;
 elsif c->>'action'='quote_accept' then
  select * into oldquote from public.work_quotes where document_id=(c->>'document_id')::uuid for update;perform private.work_require('sales',oldquote.assigned_to);
  select * into q from public.work_documents where id=oldquote.document_id for update;
  if q.status<>'issued' or oldquote.outcome<>'pending' or (nullif(q.payload->>'valid_until','')::date<current_date) then raise exception 'BUSINESS: Only a current issued quotation can be accepted.';end if;
  perform private.work_evidence((c->>'evidence_id')::uuid,'sales');
  if length(trim(coalesce(c->>'accepted_by','')))<2 then raise exception 'BUSINESS: Record who accepted this quotation.';end if;
  update public.work_quotes set outcome='accepted',accepted_by=c->>'accepted_by',accepted_at=now(),evidence_id=(c->>'evidence_id')::uuid where document_id=q.id returning to_jsonb(work_quotes.*) into result;
 elsif c->>'action'='quote_revise' then
  if not private.work_quote_permission((c->>'document_id')::uuid,true) then raise exception using errcode='42501',message='BUSINESS: Quotation access required.';end if;
  select * into oldquote from public.work_quotes where document_id=(c->>'document_id')::uuid for update;
  select * into q from public.work_documents where id=oldquote.document_id for update;
  if q.id is null or q.status<>'issued' or oldquote.outcome='accepted' then raise exception 'BUSINESS: Only an unaccepted issued quotation can be revised.';end if;
  insert into public.work_documents(kind,payload) values(q.kind,q.payload-'company'-'void_reason') returning id into a;
  insert into public.work_quotes(document_id,customer_id,opportunity_id,previous_id,assigned_to) values(a,oldquote.customer_id,oldquote.opportunity_id,q.id,oldquote.assigned_to);
  update public.work_quotes set outcome='superseded' where document_id=q.id;result=jsonb_build_object('document_id',a);
 elsif c->>'action'='asset' then
  perform private.work_require('inventory');
  if not exists(select 1 from public.work_commercial where id=(c->>'delivery_id')::uuid and kind='delivery' and status='issued' and customer_id=(c->>'customer_id')::uuid) then raise exception 'BUSINESS: Link the customer delivery.';end if;
  if not exists(select 1 from public.work_stock s join public.work_commercial_lines l on l.id=s.source_line_id where l.record_id=(c->>'delivery_id')::uuid and s.kind='dispatch' and s.item_id=(c->>'item_id')::uuid and s.serial=c->>'serial') then raise exception 'BUSINESS: Register only equipment dispatched on this delivery.';end if;
  insert into public.work_assets(customer_id,item_id,delivery_id,serial,site,accepted_on,warranty_until,terms) values((c->>'customer_id')::uuid,(c->>'item_id')::uuid,(c->>'delivery_id')::uuid,c->>'serial',coalesce(c->>'site',''),nullif(c->>'accepted_on','')::date,nullif(c->>'warranty_until','')::date,coalesce(c->>'terms','')) returning to_jsonb(work_assets.*) into result;
 elsif c->>'action'='grant' then
  if not private.work_allowed('members') then raise exception using errcode='42501',message='BUSINESS: Owner access required.';end if;
  if exists(select 1 from public.work_members where email=lower(c->>'email') and user_id=auth.uid()) then raise exception 'BUSINESS: Another owner must change your own grants.';end if;
  if c->>'area' not in ('sales','projects','support') and c->>'scope'<>'all' then raise exception 'BUSINESS: Use all-record scope for this shared business module.';end if;
  insert into public.work_grants(email,area,scope,write_access,approve_access) values(lower(c->>'email'),c->>'area',c->>'scope',(c->>'write_access')::boolean,(c->>'approve_access')::boolean) on conflict(email,area) do update set scope=excluded.scope,write_access=excluded.write_access,approve_access=excluded.approve_access;
  insert into public.work_audit(action,entity,entity_id) values('grant','work_grants',lower(c->>'email')||':'||(c->>'area'));result=jsonb_build_object('success',true);
 elsif c->>'action'='file' then
  perform private.work_require(c->>'area',auth.uid());
  if c->>'path'<>auth.uid()::text||'/'||(c->>'id')||(case when c->>'content_type'='application/pdf' then '.pdf' else '.jpg' end) then raise exception 'BUSINESS: Invalid evidence path.';end if;
  insert into public.work_files(id,owner_id,area,name,path,content_type,size,sha256) values((c->>'id')::uuid,auth.uid(),c->>'area',c->>'name',c->>'path',coalesce(c->>'content_type','image/jpeg'),(c->>'size')::integer,c->>'sha256') returning to_jsonb(work_files.*) into result;
 else raise exception 'BUSINESS: Unsupported operation.';end if;
 return result;
end;$$;
create function private.work_business(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not private.work_allowed('session') then raise exception using errcode='42501',message='BUSINESS: Sign in and complete MFA.';end if;
 if length(c::text)>70000 then raise exception 'BUSINESS: Request is too large.';end if;
 case c->>'command'
 when 'save' then return private.work_master(c);
 when 'commercial_save' then return private.work_commercial_save(c);
 when 'commercial_issue' then return private.work_commercial_issue(c);
 when 'payment' then return private.work_payment(c);
 when 'allocate' then return private.work_allocate(c);
 when 'finance_action' then return private.work_finance_action(c);
 when 'stock' then return private.work_stock_action(c);
 when 'expense' then return private.work_expense(c);
 when 'misc' then return private.work_misc(c);
 when 'quote_create' then return private.work_quote_create(c);
 when 'quote_mutate' then return private.work_quote_mutate(c);
 when 'bank' then return private.work_bank(c);
 when 'queue' then return private.work_queue(c);
 when 'portal_admin' then return private.work_portal_admin(c);
 when 'offer' then return private.work_offer(c);
 when 'automation' then return private.work_automation_settings(c);
 when 'customers_bulk' then return private.work_customers_bulk(c);
 when 'delivery_work' then return private.work_delivery_work(c);
 else raise exception 'BUSINESS: Unsupported command.';end case;
end;$$;
grant execute on function private.work_business(jsonb) to authenticated;
create function public.work_business(c jsonb) returns jsonb language sql security invoker set search_path='' as $$select private.work_business(c)$$;
revoke all on function public.work_business(jsonb) from public,anon;grant execute on function public.work_business(jsonb) to authenticated;
-- No other private helpers are callable by clients.

create function private.work_people() returns jsonb language sql stable security definer set search_path='' as $$
 select case when private.work_allowed('session') then coalesce(jsonb_agg(jsonb_build_object('id',m.user_id,'name',coalesce(nullif(p.full_name,''),m.email))),'[]'::jsonb) else '[]'::jsonb end
 from public.work_members m left join public.work_profiles p on p.user_id=m.user_id where m.active and m.user_id is not null
$$;
grant execute on function private.work_people() to authenticated;
create view public.work_invoice_balances with(security_invoker=true) as
 select r.id,r.number,r.customer_id,r.document_date,r.due_date,r.currency,r.total_minor,
 coalesce((select sum(amount_minor) from public.work_allocations where invoice_id=r.id and reversed_at is null),0)::bigint paid_minor,
 coalesce((select sum(total_minor) from public.work_commercial where kind='credit' and source_id=r.id and status='issued'),0)::bigint credited_minor,
 (r.total_minor-coalesce((select sum(amount_minor) from public.work_allocations where invoice_id=r.id and reversed_at is null),0)-coalesce((select sum(total_minor) from public.work_commercial where kind='credit' and source_id=r.id and status='issued'),0))::bigint outstanding_minor
 from public.work_commercial r where r.kind='invoice' and r.status='issued';
revoke all on public.work_invoice_balances from public,anon;grant select on public.work_invoice_balances to authenticated;
create view public.work_stock_balances with(security_invoker=true) as
 select s.item_id,s.location,s.serial,sum(s.quantity)::bigint on_hand,
 coalesce((select sum(r.quantity) from public.work_reservations r where r.item_id=s.item_id and r.location=s.location and r.serial=s.serial and released_at is null),0)::bigint reserved
 from public.work_stock s group by s.item_id,s.location,s.serial;
revoke all on public.work_stock_balances from public,anon;grant select on public.work_stock_balances to authenticated;
create function public.work_business_people() returns jsonb language sql security invoker set search_path='' as $$select private.work_people()$$;

revoke all on function public.work_business_people() from public,anon;grant execute on function public.work_business_people() to authenticated;
create function public.work_business_dashboard(start_date date default null,end_date date default null) returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object(
 'enquiries_open',(select count(*) from public.work_enquiries where status not in ('won','lost','closed')),
 'followups_due',(select count(*) from public.work_enquiries where follow_up<=current_date and status not in ('won','lost','closed')),
 'projects_active',(select count(*) from public.work_cases where kind='project' and status not in ('completed','closed')),
 'tickets_open',(select count(*) from public.work_cases where kind='ticket' and status not in ('completed','closed')),
 'tasks_due',(select count(*) from public.work_tasks where due_on<=current_date and status<>'done'),
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
revoke all on function public.work_business_dashboard(date,date) from public,anon;grant execute on function public.work_business_dashboard(date,date) to authenticated;
create function private.work_quote_create(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare customer public.work_customers;doc uuid=coalesce(nullif(c->>'id','')::uuid,gen_random_uuid());p jsonb;
begin
 perform private.work_require('sales',auth.uid());
 select * into customer from public.work_customers where id=(c->>'customer_id')::uuid and not archived;
 if customer.id is null then raise exception 'BUSINESS: Choose an active customer.';end if;
 if exists(select 1 from public.work_quotes where document_id=doc and customer_id=customer.id) then return jsonb_build_object('document_id',doc);end if;
 p=jsonb_build_object('kind','quotation','customer',jsonb_build_object('name',customer.name,'email',customer.email,'phone',customer.phone,'address',customer.address),'date',to_char(now() at time zone 'Africa/Lagos','YYYY-MM-DD'),'valid_until','','currency','NGN','items',jsonb_build_array(jsonb_build_object('description','Describe the agreed equipment or service','quantity',1,'unit_minor',100)),'discount_minor',0,'tax_bps',0,'notes','','payment_method','','payment_reference','','payment_confirmed',false,'source_id','');
 insert into public.work_documents(id,kind,payload) values(doc,'quotation',p);
 insert into public.work_quotes(document_id,customer_id,assigned_to) values(doc,customer.id,auth.uid());
 return jsonb_build_object('document_id',doc);
end;$$;
create unique index work_bank_match_unique on public.work_bank_lines(payment_id) where payment_id is not null;
create function private.work_bank(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare line jsonb;bank public.work_bank_lines;p public.work_payments;n integer=0; fingerprint text;
begin
 perform private.work_require('finance');
 if c->>'action'='import' then
 if jsonb_typeof(c->'rows') is distinct from 'array' or jsonb_array_length(c->'rows') not between 1 and 500 then raise exception 'BUSINESS: Import between one and 500 rows.';end if;
 for line in select * from jsonb_array_elements(c->'rows') loop
 fingerprint=encode(sha256(convert_to(jsonb_build_array(coalesce(c->>'account','primary'),line->>'posted_on',(line->>'amount_minor')::bigint,line->>'currency',line->>'reference')::text,'UTF8')),'hex');
 insert into public.work_bank_lines(fingerprint,posted_on,amount_minor,currency,reference) values(fingerprint,(line->>'posted_on')::date,(line->>'amount_minor')::bigint,line->>'currency',line->>'reference') on conflict do nothing;
 if found then n=n+1;end if;
 end loop;
 return jsonb_build_object('inserted',n);
 elsif c->>'action'='match' then
  select * into p from public.work_payments where id=(c->>'payment_id')::uuid for update;
  select * into bank from public.work_bank_lines where id=(c->>'id')::uuid for update;
  if p.id is null or bank.id is null or p.status<>'confirmed' or bank.payment_id is not null or p.reconciled or bank.amount_minor<>p.amount_minor or bank.currency<>p.currency then raise exception 'BUSINESS: Match one unreconciled payment to an equal positive bank amount and currency.';end if;
  update public.work_bank_lines set payment_id=p.id where id=bank.id;update public.work_payments set reconciled=true where id=p.id;return jsonb_build_object('success',true);
 end if;
 raise exception 'BUSINESS: Unsupported bank action.';
end;$$;
create function private.work_statement(cid uuid,from_date date,to_date date,ccy text) returns jsonb language plpgsql security definer set search_path='' as $$
declare events jsonb;opening bigint;cust jsonb;
begin
 perform private.work_require('finance',null,'read');
 select to_jsonb(c) into cust from public.work_customers c where id=cid;
 if cust is null or ccy not in ('NGN','USD','GBP','EUR') then raise exception 'BUSINESS: Customer or currency not found.';end if;
 with entries as (
  select document_date posted_on,kind,number reference,case kind when 'invoice' then total_minor else 0 end debit_minor,case kind when 'credit' then total_minor else 0 end credit_minor from public.work_commercial where customer_id=cid and currency=ccy and kind in ('invoice','credit') and status='issued'
  union all select p.paid_on,'payment',coalesce(d.number,p.reference),0,p.amount_minor from public.work_payments p left join public.work_documents d on d.id=p.receipt_id where p.customer_id=cid and p.currency=ccy and p.status='confirmed'
  union all select r.created_at::date,'refund',r.id::text,r.amount_minor,0 from public.work_refunds r join public.work_payments p on p.id=r.payment_id where p.customer_id=cid and p.currency=ccy
 ) select coalesce(jsonb_agg(to_jsonb(entries) order by posted_on,reference) filter(where (from_date is null or posted_on>=from_date) and (to_date is null or posted_on<=to_date)),'[]'::jsonb),coalesce(sum(debit_minor-credit_minor) filter(where from_date is not null and posted_on<from_date),0) into events,opening from entries;
 return jsonb_build_object('customer',cust,'currency',ccy,'opening_minor',opening,'events',events);
end;$$;
grant execute on function private.work_statement(uuid,date,date,text) to authenticated;
create function public.work_customer_statement(cid uuid,from_date date,to_date date,ccy text) returns jsonb language sql security invoker set search_path='' as $$select private.work_statement(cid,from_date,to_date,ccy)$$;
revoke all on function public.work_customer_statement(uuid,date,date,text) from public,anon;grant execute on function public.work_customer_statement(uuid,date,date,text) to authenticated;
create table private.work_requests (
 user_id uuid not null,key uuid not null,request_hash text not null,result jsonb not null,area text not null,assigned_to uuid,action text not null,
 created_at timestamptz not null default now(),primary key(user_id,key)
);
alter table private.work_requests enable row level security;
revoke all on private.work_requests from public,anon,authenticated;
create policy work_requests_deny on private.work_requests for all to anon,authenticated using(false) with check(false);
-- Preserve the command implementation and wrap it with request idempotency.
alter function private.work_business(jsonb) rename to work_business_execute;
revoke all on function private.work_business_execute(jsonb) from authenticated;
create function private.work_business(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare k uuid=nullif(c->>'request_key','')::uuid;cached private.work_requests;result jsonb;a text;assigned uuid;act text='write';h text=encode(sha256(convert_to(c::text,'UTF8')),'hex');
begin
 if not private.work_allowed('session') then raise exception using errcode='42501',message='BUSINESS: Sign in and complete MFA.';end if;
 if k is null then return private.work_business_execute(c);end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||k::text,8));
 select * into cached from private.work_requests where user_id=auth.uid() and key=k;
 if cached.key is not null then
  perform private.work_require(cached.area,cached.assigned_to,cached.action);
  if cached.request_hash<>h then raise exception 'BUSINESS: This request was already used for different details. Refresh before continuing.';end if;
  return cached.result;
 end if;
 result=private.work_business_execute(c);
 a=case c->>'command' when 'save' then case c->>'entity' when 'suppliers' then 'procurement' when 'items' then 'inventory' when 'cases' then case when c#>>'{data,kind}'='project' then 'projects' else 'support' end when 'tasks' then coalesce((select case when kind='project' then 'projects' else 'support' end from public.work_cases where id=nullif(c#>>'{data,case_id}','')::uuid),'projects') else 'sales' end when 'commercial_save' then private.work_commercial_area(c#>>'{data,kind}') when 'commercial_issue' then (select private.work_commercial_area(kind) from public.work_commercial where id=(c->>'id')::uuid) when 'delivery_work' then coalesce((select case when kind='project' then 'projects' else 'support' end from public.work_cases where id=nullif(c->>'case_id','')::uuid),'projects') when 'customers_bulk' then 'sales' when 'stock' then 'inventory' when 'offer' then 'procurement' when 'queue' then 'sales' when 'portal_admin' then 'sales' when 'quote_create' then 'sales' when 'quote_mutate' then 'sales' when 'misc' then case c->>'action' when 'asset' then 'inventory' when 'file' then c->>'area' else 'sales' end else 'finance' end;
 assigned=coalesce(nullif(result->>'assigned_to','')::uuid,auth.uid());
 if c->>'command'='finance_action' or c->>'command'='expense' and c->>'action' in ('approve','reject') then act='approve';end if;
 insert into private.work_requests(user_id,key,request_hash,result,area,assigned_to,action) values(auth.uid(),k,h,result,a,assigned,act);
 return result;
end;$$;
grant execute on function private.work_business(jsonb) to authenticated;
-- Recreate the invoker wrapper after renaming the underlying implementation.
create or replace function public.work_business(c jsonb) returns jsonb language sql security invoker set search_path='' as $$select private.work_business(c)$$;
create table private.work_job_config(id integer primary key check(id=1),proof_hash text not null check(proof_hash ~ '^[a-f0-9]{64}$'));
alter table private.work_job_config enable row level security;
revoke all on private.work_job_config from public,anon,authenticated;
create policy work_job_config_deny on private.work_job_config for all to anon,authenticated using(false) with check(false);
alter table public.work_messages add column lease_id uuid;
alter table public.work_messages add column leased_at timestamptz;
alter table public.work_messages add column next_attempt_at timestamptz not null default now();
alter table public.work_messages add column delivery_status text not null default 'pending' check(delivery_status in ('pending','delivered','bounced','complained','failed'));
alter table public.work_messages add column purpose text not null default 'manual' check(purpose in ('manual','enquiry-notification','invoice-reminder','maintenance-reminder','support-escalation','approval-request'));
alter table public.work_messages alter column created_by drop not null;
create table private.work_mail_events(id text primary key,created_at timestamptz not null default now());
alter table private.work_mail_events enable row level security;revoke all on private.work_mail_events from public,anon,authenticated;
create policy work_mail_events_deny on private.work_mail_events for all to anon,authenticated using(false) with check(false);
create table private.work_suppressed(email text primary key,reason text not null,created_at timestamptz not null default now());
alter table private.work_suppressed enable row level security;revoke all on private.work_suppressed from public,anon,authenticated;
create policy work_suppressed_deny on private.work_suppressed for all to anon,authenticated using(false) with check(false);
create function private.work_queue(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.work_commercial;d public.work_documents;cust public.work_customers;result jsonb;
begin
 perform private.work_require('sales',auth.uid());
 select * into cust from public.work_customers where id=(c->>'customer_id')::uuid and not archived;
 if cust.id is null or not private.work_customer_allowed(cust.id) then raise exception 'BUSINESS: Customer access required.';end if;
 if lower(c->>'recipient')<>lower(cust.email) and not exists(select 1 from public.work_contacts where customer_id=cust.id and lower(email)=lower(c->>'recipient')) then raise exception 'BUSINESS: Choose a recorded customer contact email.';end if;
 if c->>'recipient' !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'BUSINESS: Supply a valid recipient.';end if;
 if nullif(c->>'record_id','') is not null then
  select * into r from public.work_commercial where id=(c->>'record_id')::uuid;
  if r.id is null or r.status<>'issued' or r.customer_id<>cust.id or not private.work_ops_allowed(private.work_commercial_area(r.kind),r.assigned_to) then raise exception 'BUSINESS: Share only an issued document for this customer.';end if;
 end if;
 if exists(select 1 from private.work_suppressed where email=lower(c->>'recipient')) then raise exception 'BUSINESS: This recipient is suppressed following a delivery failure or complaint. Contact the owner.';end if;
 if nullif(c->>'document_id','') is not null then
  select * into d from public.work_documents where id=(c->>'document_id')::uuid;
  if r.id is not null or d.id is null or d.status<>'issued' or d.kind not in ('quotation','proforma') or not private.work_quote_permission(d.id) or not exists(select 1 from public.work_quotes where document_id=d.id and customer_id=cust.id and outcome<>'superseded') then raise exception 'BUSINESS: Attach one linked issued quotation or pro forma for this customer.';end if;
 end if;
 insert into public.work_messages(customer_id,record_id,document_id,recipient,subject,body,request_key) values(cust.id,r.id,d.id,c->>'recipient',c->>'subject',c->>'body',(c->>'request_key')::uuid) on conflict(request_key) do nothing;
 select to_jsonb(t) into result from public.work_messages t where request_key=(c->>'request_key')::uuid;return result;
end;$$;
create function private.work_sender_allowed(uid uuid,cid uuid,rid uuid,did uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.work_members m where user_id=uid and active and
 (m.role in ('owner','admin','finance') or exists(select 1 from public.work_grants g where g.email=m.email and g.area='sales' and g.write_access and (g.scope='all' or exists(select 1 from public.work_customers where id=cid and assigned_to=uid) or exists(select 1 from public.work_quotes where document_id=did and assigned_to=uid)))) and
 (rid is null or exists(select 1 from public.work_commercial r where r.id=rid and (m.role in ('owner','admin') or m.role='finance' and private.work_commercial_area(r.kind) in ('sales','finance') or exists(select 1 from public.work_grants g where g.email=m.email and g.area=private.work_commercial_area(r.kind) and (g.scope='all' or r.assigned_to=uid))))) and
 (did is null or exists(select 1 from public.work_quotes q where q.document_id=did and (m.role in ('owner','admin','finance') or exists(select 1 from public.work_grants g where g.email=m.email and g.area='sales' and (g.scope='all' or q.assigned_to=uid)))))
 )
$$;
create function private.work_job(proof text,c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
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
  update public.work_messages set status='failed',last_error='Retry window expired. Review provider delivery status before preparing a new message.' where status in ('queued','sending') and (created_at<=now()-interval '23 hours' or attempts>=4 and leased_at<now()-interval '5 minutes');
  for msg in select * from public.work_messages where ((status in ('queued','failed') and next_attempt_at<=now()) or (status='sending' and leased_at<now()-interval '5 minutes')) and attempts<4 and created_at>now()-interval '23 hours' order by created_at for update skip locked limit 10 loop
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
   payload=to_jsonb(msg)||jsonb_build_object('lease_id',jobid);
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
grant execute on function private.work_job(text,jsonb) to anon,authenticated;
create function public.work_business_job(proof text,c jsonb) returns jsonb language sql security invoker set search_path='' as $$select private.work_job(proof,c)$$;
revoke all on function public.work_business_job(text,jsonb) from public;grant execute on function public.work_business_job(text,jsonb) to anon,authenticated;
create table public.work_portal_members (
 id uuid primary key default gen_random_uuid(),email text not null check(email=lower(email) and length(email)<=254),customer_id uuid not null references public.work_customers(id),
 active boolean not null default true,created_at timestamptz not null default now(),unique(email,customer_id)
);
create table public.work_portal_shares (
 id uuid primary key default gen_random_uuid(),customer_id uuid not null references public.work_customers(id),record_id uuid references public.work_commercial(id),document_id uuid references public.work_documents(id),
 active boolean not null default true,created_at timestamptz not null default now(),check(num_nonnulls(record_id,document_id)=1),unique(record_id),unique(document_id)
);
create table public.work_portal_events (
 id uuid primary key default gen_random_uuid(),customer_id uuid not null references public.work_customers(id),email text not null,action text not null,record_id uuid not null,created_at timestamptz not null default now()
);
alter table public.work_portal_members enable row level security;alter table public.work_portal_shares enable row level security;alter table public.work_portal_events enable row level security;
revoke all on public.work_portal_members,public.work_portal_shares,public.work_portal_events from public,anon,authenticated;
grant select on public.work_portal_members,public.work_portal_shares,public.work_portal_events to authenticated;
create policy work_portal_members_read on public.work_portal_members for select to authenticated using(private.work_allowed('members'));
create policy work_portal_shares_read on public.work_portal_shares for select to authenticated using(private.work_customer_allowed(customer_id));
create policy work_portal_events_read on public.work_portal_events for select to authenticated using(private.work_customer_allowed(customer_id));
create trigger work_portal_members_audit after insert or update on public.work_portal_members for each row execute function private.work_audit_change();
create trigger work_portal_shares_audit after insert or update on public.work_portal_shares for each row execute function private.work_audit_change();
create table private.work_portal_logins(hash text primary key,email text not null,expires_at timestamptz not null,used_at timestamptz);
create table private.work_portal_sessions(hash text primary key,email text not null,expires_at timestamptz not null,created_at timestamptz not null default now());
create table private.work_portal_mail(id uuid primary key default gen_random_uuid(),email text not null,cipher text not null,status text not null default 'queued',lease_id uuid,leased_at timestamptz,created_at timestamptz not null default now());
alter table private.work_portal_logins enable row level security;alter table private.work_portal_sessions enable row level security;alter table private.work_portal_mail enable row level security;
revoke all on private.work_portal_logins,private.work_portal_sessions,private.work_portal_mail from public,anon,authenticated;
create policy work_portal_logins_deny on private.work_portal_logins for all to anon,authenticated using(false) with check(false);
create policy work_portal_sessions_deny on private.work_portal_sessions for all to anon,authenticated using(false) with check(false);
create policy work_portal_mail_deny on private.work_portal_mail for all to anon,authenticated using(false) with check(false);
create function private.work_portal_admin(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.work_commercial;d public.work_documents;cid uuid=(c->>'customer_id')::uuid;
begin
 if c->>'action'='member' then
  if not private.work_allowed('members') then raise exception using errcode='42501',message='BUSINESS: Owner access required.';end if;
  if c->>'email' !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'BUSINESS: Enter a valid email.';end if;
  insert into public.work_portal_members(email,customer_id,active) values(lower(c->>'email'),cid,(c->>'active')::boolean) on conflict(email,customer_id) do update set active=excluded.active;
 elsif c->>'action'='share_case' then
  if not exists(select 1 from public.work_cases where id=(c->>'case_id')::uuid and customer_id=cid and private.work_ops_allowed(case when kind='project' then 'projects' else 'support' end,assigned_to,'write')) then raise exception using errcode='42501',message='BUSINESS: Project or support access required.';end if;
  insert into public.work_portal_case_shares(case_id,customer_id,active) values((c->>'case_id')::uuid,cid,(c->>'active')::boolean) on conflict(case_id) do update set active=excluded.active;
 elsif c->>'action'='share' then
  perform private.work_require('sales',null);
  if not private.work_customer_allowed(cid) then raise exception 'BUSINESS: Customer access required.';end if;
  if nullif(c->>'record_id','') is not null then
   select * into r from public.work_commercial where id=(c->>'record_id')::uuid;
   if r.id is null or r.status<>'issued' or r.customer_id<>cid or not private.work_ops_allowed(private.work_commercial_area(r.kind),r.assigned_to) then raise exception 'BUSINESS: Share only an issued document for this customer.';end if;
   insert into public.work_portal_shares(customer_id,record_id,active) values(cid,r.id,(c->>'active')::boolean) on conflict(record_id) do update set active=excluded.active;
  else
   select * into d from public.work_documents where id=(c->>'document_id')::uuid;
   if d.id is null or d.status<>'issued' or not private.work_quote_permission(d.id) or not exists(select 1 from public.work_quotes where document_id=d.id and customer_id=cid and outcome<>'superseded') then raise exception 'BUSINESS: Share only a linked issued quotation or pro forma.';end if;
   insert into public.work_portal_shares(customer_id,document_id,active) values(cid,d.id,(c->>'active')::boolean) on conflict(document_id) do update set active=excluded.active;
  end if;
 else raise exception 'BUSINESS: Unsupported portal action.';end if;
 return jsonb_build_object('success',true);
end;$$;
create function private.work_portal(proof text,c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
<<portal_op>>
declare email text;login private.work_portal_logins;r public.work_commercial;d public.work_documents;cid uuid;shares jsonb;result jsonb;msg private.work_portal_mail;jobid uuid;
begin
 if proof is null or length(proof)<>64 or not exists(select 1 from private.work_job_config where id=1 and proof_hash=encode(sha256(convert_to(proof,'UTF8')),'hex')) then raise exception using errcode='42501',message='Invalid portal proof';end if;
 if length(c::text)>20000 then raise exception 'Invalid portal request';end if;
 if c->>'action'='request' then
  email=lower(c->>'email');
  if exists(select 1 from public.work_portal_members m join public.work_customers cu on cu.id=m.customer_id where m.email=portal_op.email and m.active and not cu.archived) then
   insert into private.work_portal_logins(hash,email,expires_at) values(c->>'token_hash',email,now()+interval '15 minutes');
   insert into private.work_portal_mail(email,cipher) values(email,c->>'cipher');
  end if;
  delete from private.work_portal_logins where expires_at<now();delete from private.work_portal_sessions where expires_at<now();
  return jsonb_build_object('success',true);
 elsif c->>'action'='exchange' then
  select * into login from private.work_portal_logins where hash=c->>'token_hash' for update;
  if login.hash is null or login.used_at is not null or login.expires_at<now() or not exists(select 1 from public.work_portal_members where work_portal_members.email=login.email and active) then raise exception 'Portal link is invalid or expired';end if;
  update private.work_portal_logins set used_at=now() where hash=login.hash;
  insert into private.work_portal_sessions(hash,email,expires_at) values(c->>'session_hash',login.email,now()+interval '8 hours');return jsonb_build_object('success',true);
 elsif c->>'action'='claim_mail' then
  select * into msg from private.work_portal_mail where (status='queued' or status='sending' and leased_at<now()-interval '2 minutes') and created_at>now()-interval '10 minutes' order by created_at for update skip locked limit 1;
  if msg.id is null then return null;end if;
  update private.work_portal_mail set status='sending',lease_id=gen_random_uuid(),leased_at=now() where id=msg.id returning * into msg;return to_jsonb(msg);
 elsif c->>'action'='complete_mail' then
  update private.work_portal_mail set status=case when coalesce((c->>'sent')::boolean,false) then 'sent' else 'queued' end,cipher=case when coalesce((c->>'sent')::boolean,false) then '' else cipher end where id=(c->>'id')::uuid and lease_id=(c->>'lease_id')::uuid;return '{}';
 end if;
 select s.email into email from private.work_portal_sessions s where hash=c->>'session_hash' and expires_at>now();
 if email is null then raise exception using errcode='42501',message='Portal sign-in required';end if;
 if c->>'action'='signout' then delete from private.work_portal_sessions where hash=c->>'session_hash';return '{}';end if;
 if c->>'action'='state' then
  select coalesce(jsonb_agg(jsonb_build_object('id',cu.id,'name',cu.name)),'[]') into result from public.work_customers cu join public.work_portal_members m on m.customer_id=cu.id where m.email=portal_op.email and m.active and not cu.archived;
  select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'record_id',s.record_id,'document_id',s.document_id,'number',coalesce(cr.number,ld.number),'kind',coalesce(cr.kind,ld.kind),'currency',coalesce(cr.currency,ld.payload->>'currency'),'total_minor',coalesce(cr.total_minor,ld.total_minor))),'[]') into shares from public.work_portal_shares s join public.work_portal_members m on m.customer_id=s.customer_id and m.email=portal_op.email and m.active join public.work_customers cu on cu.id=s.customer_id and not cu.archived left join public.work_commercial cr on cr.id=s.record_id left join public.work_documents ld on ld.id=s.document_id where s.active and (cr.status='issued' or ld.status='issued') and not exists(select 1 from public.work_quotes q where q.document_id=ld.id and q.outcome='superseded');
  return jsonb_build_object('email',email,'customers',result,'documents',shares,'work',(
   select coalesce(jsonb_agg(jsonb_build_object('reference',k.reference,'title',k.title,'kind',k.kind,'status',k.status,'due_on',k.due_on,'milestones',(select coalesce(jsonb_agg(jsonb_build_object('title',t.title,'status',t.status,'due_on',t.due_on)),'[]') from public.work_tasks t where t.case_id=k.id and t.customer_visible))),'[]') from public.work_cases k join public.work_portal_case_shares sh on sh.case_id=k.id and sh.active join public.work_portal_members m on m.customer_id=k.customer_id and m.email=portal_op.email and m.active join public.work_customers visible_c on visible_c.id=k.customer_id and not visible_c.archived
  ));
 end if;
 if c->>'action'='ticket' then
  cid=(c->>'customer_id')::uuid;
  if not exists(select 1 from public.work_portal_members m join public.work_customers cu on cu.id=m.customer_id where m.email=portal_op.email and m.active and m.customer_id=cid and not cu.archived) then raise exception using errcode='42501',message='Customer access denied';end if;
  insert into public.work_cases(kind,reference,customer_id,title,description,category) values('ticket',private.work_number('TKT'),cid,c->>'title',c->>'description','customer-portal') returning id into jobid;
  insert into public.work_portal_case_shares(case_id,customer_id) values(jobid,cid);
  insert into public.work_portal_events(customer_id,email,action,record_id) values(cid,email,'ticket_create',jobid);
  return jsonb_build_object('reference',(select reference from public.work_cases where id=jobid));
 end if;
 select s.customer_id into cid from public.work_portal_shares s join public.work_portal_members m on m.customer_id=s.customer_id and m.email=portal_op.email and m.active join public.work_customers cu on cu.id=s.customer_id and not cu.archived where s.id=(c->>'share_id')::uuid and s.active;
 if cid is null then raise exception using errcode='42501',message='Document access denied';end if;
 select r0.* into r from public.work_commercial r0 join public.work_portal_shares s on s.record_id=r0.id where s.id=(c->>'share_id')::uuid and r0.status='issued';
 select d0.* into d from public.work_documents d0 join public.work_portal_shares s on s.document_id=d0.id where s.id=(c->>'share_id')::uuid and d0.status='issued';
 if r.id is null and d.id is null then raise exception using errcode='42501',message='Document withdrawn';end if;
 if d.id is not null and exists(select 1 from public.work_quotes where document_id=d.id and outcome='superseded') then raise exception 'Quotation superseded';end if;
 if c->>'action'='document' then
  insert into public.work_portal_events(customer_id,email,action,record_id) values(cid,email,'document_view',coalesce(r.id,d.id));
  if r.id is not null then return jsonb_build_object('record',jsonb_build_object('id',r.id,'kind',r.kind,'status',r.status,'number',r.number,'document_date',r.document_date,'due_date',r.due_date,'currency',r.currency,'total_minor',r.total_minor,'discount_minor',r.discount_minor,'tax_bps',r.tax_bps,'notes',r.notes,'snapshot',r.snapshot),'lines',(select jsonb_agg(jsonb_build_object('description',description,'quantity',quantity,'unit_minor',unit_minor) order by position) from public.work_commercial_lines where record_id=r.id));end if;
  return jsonb_build_object('legacy',jsonb_build_object('id',d.id,'kind',d.kind,'status',d.status,'number',d.number,'payload',d.payload,'total_minor',d.total_minor));
 elsif c->>'action' in ('accept','decline') then
  select * into d from public.work_documents where id=d.id for update;
  if d.id is null or d.status<>'issued' or d.kind<>'quotation' or nullif(d.payload->>'valid_until','')::date<current_date then raise exception 'Quotation cannot be accepted';end if;
  update public.work_quotes set outcome=case when c->>'action'='accept' then 'accepted' else 'declined' end,accepted_by=email,accepted_at=now() where document_id=d.id and customer_id=cid and outcome='pending';
  if not found then raise exception 'Quotation has already been decided';end if;
  insert into public.work_portal_events(customer_id,email,action,record_id) values(cid,email,'quote_'||(c->>'action'),d.id);return jsonb_build_object('success',true);
 end if;
 raise exception 'Unsupported portal action';
end;$$;
grant execute on function private.work_portal(text,jsonb) to anon,authenticated;
create function public.work_customer_portal(proof text,c jsonb) returns jsonb language sql security invoker set search_path='' as $$select private.work_portal(proof,c)$$;
revoke all on function public.work_customer_portal(text,jsonb) from public;grant execute on function public.work_customer_portal(text,jsonb) to anon,authenticated;
create function private.work_quote_permission(did uuid,writing boolean default false) returns boolean language sql stable security definer set search_path='' as $$
 select private.work_allowed('finance') or exists(select 1 from public.work_quotes q where q.document_id=did and private.work_ops_allowed('sales',q.assigned_to,case when writing then 'write' else 'read' end))
$$;
grant execute on function private.work_quote_permission(uuid,boolean) to authenticated;
create policy work_sales_quote_read on public.work_documents for select to authenticated using(kind in ('quotation','proforma') and private.work_quote_permission(id));
-- Sales writes use narrow business RPCs. Do not grant a blanket table INSERT or
-- UPDATE policy for them: the RPC links the customer and checks the assignment.
create function private.work_quote_mutate(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare d public.work_documents;result jsonb;
begin
 select * into d from public.work_documents where id=(c->>'id')::uuid for update;
 if d.id is null or d.kind not in ('quotation','proforma') or not private.work_quote_permission(d.id,true) then raise exception using errcode='42501',message='BUSINESS: Quotation access required.';end if;
 if d.version<>(c->>'version')::integer then raise exception 'BUSINESS: Draft changed. Refresh before editing.';end if;
 if c->>'action'='save' then update public.work_documents set payload=c->'payload' where id=d.id and status='draft';
 elsif c->>'action'='issue' then update public.work_documents set status='issued' where id=d.id;
 elsif c->>'action'='void' then update public.work_documents set status='void',payload=payload||jsonb_build_object('void_reason',c->>'reason') where id=d.id;
 else raise exception 'BUSINESS: Unsupported quotation action.';end if;
 select to_jsonb(t) into result from public.work_documents t where id=d.id;return result;
end;$$;
create function private.work_quote_settings() returns jsonb language sql stable security definer set search_path='' as $$
 select case when private.work_ops_allowed('sales',auth.uid()) or private.work_allowed('finance') then payload else null end from public.work_settings where id=1
$$;
grant execute on function private.work_quote_settings() to authenticated;
create function public.work_quote_settings() returns jsonb language sql security invoker set search_path='' as $$select private.work_quote_settings()$$;
revoke all on function public.work_quote_settings() from public,anon;grant execute on function public.work_quote_settings() to authenticated;

create or replace function private.work_document_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare subtotal numeric:=0; tax numeric; item jsonb; company jsonb; seq integer; yr integer; source public.work_documents; received bigint; record_date date;
begin
 if not private.work_allowed('finance') and not private.work_ops_allowed('finance',null,'write') and not (case when TG_OP='DELETE' then old.kind else new.kind end in ('quotation','proforma') and ((TG_OP='INSERT' and private.work_ops_allowed('sales',auth.uid(),'write')) or private.work_quote_permission(case when TG_OP='DELETE' then old.id else new.id end,true))) then raise exception 'Finance permission or assigned quotation access and MFA required';end if;
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
create table public.work_offers (
 id uuid primary key default gen_random_uuid(),rfq_id uuid not null references public.work_commercial(id),supplier_id uuid not null references public.work_suppliers(id),
 amount_minor bigint not null check(amount_minor between 1 and 1000000000000),currency text not null check(currency in ('NGN','USD','GBP','EUR')),
 lead_days integer not null check(lead_days between 0 and 1000),shipping_minor bigint not null default 0 check(shipping_minor>=0),terms text not null check(length(terms)<=3000),
 evidence_id uuid not null references public.work_files(id),selected boolean not null default false,selection_reason text not null default '',created_at timestamptz not null default now()
);
alter table public.work_offers enable row level security;revoke all on public.work_offers from public,anon,authenticated;grant select on public.work_offers to authenticated;
create policy work_offers_read on public.work_offers for select to authenticated using(private.work_ops_allowed('procurement'));
create trigger work_offers_audit after insert or update on public.work_offers for each row execute function private.work_audit_change();
create function private.work_offer(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;offer public.work_offers;
begin
 perform private.work_require('procurement');
 if c->>'action'='save' then
  perform 1 from public.work_commercial where id=(c->>'rfq_id')::uuid and kind='rfq' and status='issued' for update;
  if not found then raise exception 'BUSINESS: Link an issued supplier request.';end if;
  perform private.work_evidence((c->>'evidence_id')::uuid,'procurement');
  insert into public.work_offers(rfq_id,supplier_id,amount_minor,currency,lead_days,shipping_minor,terms,evidence_id) values((c->>'rfq_id')::uuid,(c->>'supplier_id')::uuid,(c->>'amount_minor')::bigint,c->>'currency',(c->>'lead_days')::integer,coalesce((c->>'shipping_minor')::bigint,0),coalesce(c->>'terms',''),(c->>'evidence_id')::uuid) returning to_jsonb(work_offers.*) into result;
 elsif c->>'action'='select' then
  perform private.work_require('procurement',null,'approve');
  select * into offer from public.work_offers where id=(c->>'id')::uuid;
  perform 1 from public.work_commercial where id=offer.rfq_id for update;
  if offer.id is null or length(trim(coalesce(c->>'reason','')))<5 then raise exception 'BUSINESS: Select an offer and explain the decision.';end if;
  update public.work_offers set selected=false where rfq_id=offer.rfq_id;
  update public.work_offers set selected=true,selection_reason=c->>'reason' where id=offer.id returning to_jsonb(work_offers.*) into result;
 else raise exception 'BUSINESS: Unsupported supplier offer action.';end if;
 return result;
end;$$;
-- Full history and private file manifests extend the existing encrypted backup.
alter function private.work_backup() rename to work_backup_base;
revoke all on function private.work_backup_base() from authenticated;
create function private.work_backup() returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;tbl text;rows jsonb;total bigint=0;
begin
 if not private.work_allowed('backup') then raise exception 'Owner access required';end if;
 result=private.work_backup_base();
 for tbl in select unnest(array['work_grants','work_customers','work_contacts','work_enquiries','work_opportunities','work_suppliers','work_items','work_quotes','work_commercial','work_commercial_lines','work_files','work_payments','work_allocations','work_refunds','work_cases','work_tasks','work_notes','work_stock','work_reservations','work_assets','work_expenses','work_supplier_payments','work_decisions','work_messages','work_bank_lines','work_portal_members','work_portal_shares','work_portal_events','work_offers','work_profiles','work_automation','work_portal_case_shares','work_customer_merges','work_calendar','work_case_service','work_case_templates','work_case_events','work_case_changes']) loop
  execute format('select coalesce(jsonb_agg(to_jsonb(t)),''[]''::jsonb) from public.%I t',tbl) into rows;
  total=total+jsonb_array_length(rows);if total>50000 then raise exception 'Use the full database and storage backup procedure';end if;
  result=result||jsonb_build_object(tbl,rows);
 end loop;
 return result;
end;$$;
grant execute on function private.work_backup() to authenticated;
create or replace function public.work_backup_snapshot() returns jsonb language sql security invoker set search_path='' as $$select private.work_backup()$$;
create function private.work_backup_file_access() returns boolean language sql stable security definer set search_path='' as $$
 select private.work_allowed('backup') and exists(select 1 from private.work_job_config where id=1 and proof_hash=encode(sha256(convert_to(coalesce(nullif(current_setting('request.headers',true),'')::jsonb->>'x-lutera-backup-proof',''),'UTF8')),'hex'))
$$;
grant execute on function private.work_backup_file_access() to authenticated;
create policy work_avatars_owner_backup on storage.objects for select to authenticated using(bucket_id='work-avatars' and private.work_backup_file_access());
alter table public.work_tasks add column depends_on uuid references public.work_tasks(id);
alter table public.work_tasks add column customer_visible boolean not null default false;
alter table public.work_commercial_lines add column task_id uuid references public.work_tasks(id);
create function private.work_task_rules() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.depends_on is not null then
  if new.depends_on=new.id or not exists(select 1 from public.work_tasks where id=new.depends_on and case_id=new.case_id) then raise exception 'BUSINESS: Dependencies must be another task in the same project.';end if;
  if exists(with recursive chain as (select id,depends_on,array[id] path from public.work_tasks where id=new.depends_on union all select t.id,t.depends_on,ch.path||t.id from public.work_tasks t join chain ch on t.id=ch.depends_on where not t.id=any(ch.path)) select 1 from chain where id=new.id) then raise exception 'BUSINESS: Task dependencies cannot form a cycle.';end if;
  if new.status='done' and exists(select 1 from public.work_tasks where id=new.depends_on and status<>'done') then raise exception 'BUSINESS: Complete the prerequisite task first.';end if;
 end if;
 return new;
end;$$;
create trigger work_tasks_rules before insert or update on public.work_tasks for each row execute function private.work_task_rules();
create table public.work_automation (
 id integer primary key default 1 check(id=1),invoice_reminders boolean not null default false,maintenance_reminders boolean not null default false,
 interval_days integer not null default 7 check(interval_days between 1 and 90),version integer not null default 1,updated_at timestamptz not null default now()
);
alter table public.work_automation enable row level security;revoke all on public.work_automation from public,anon,authenticated;grant select on public.work_automation to authenticated;
create policy work_automation_owner on public.work_automation for select to authenticated using(private.work_allowed('members'));
insert into public.work_automation(id) values(1);
create trigger work_automation_audit after update on public.work_automation for each row execute function private.work_audit_change();
create trigger work_automation_touch before update on public.work_automation for each row execute function private.work_touch();
create function private.work_automation_settings(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if not private.work_allowed('members') then raise exception using errcode='42501',message='BUSINESS: Owner access required.';end if;
 update public.work_automation set invoice_reminders=(c->>'invoice_reminders')::boolean,maintenance_reminders=(c->>'maintenance_reminders')::boolean,interval_days=(c->>'interval_days')::integer where id=1 and version=(c->>'version')::integer returning to_jsonb(work_automation.*) into result;
 if result is null then raise exception 'BUSINESS: Settings changed. Refresh before saving.';end if;return result;
end;$$;
create function private.work_prepare_reminders() returns integer language plpgsql security definer set search_path='' as $$
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
 for r in select * from public.work_cases where kind='ticket' and status not in ('closed','completed') and response_due_at<now() and responded_at is null loop
  key=md5(r.id::text||':support-escalation:'||current_date)::uuid;
  insert into public.work_messages(recipient,subject,body,request_key,purpose,created_by) values(notify,'Response target exceeded: '||r.reference,'Review support ticket '||r.reference||' in the private workspace. Its recorded first-response deadline has passed.',key,'support-escalation',null) on conflict(request_key) do nothing;
  if found then n=n+1;end if;
 end loop;
 return n;
end;$$;
alter table private.work_mail_events add column provider_id text;
alter table private.work_mail_events add column type text;
create table public.work_portal_case_shares(id uuid primary key default gen_random_uuid(),case_id uuid not null unique references public.work_cases(id),customer_id uuid not null references public.work_customers(id),active boolean not null default true,created_at timestamptz not null default now());
alter table public.work_portal_case_shares enable row level security;revoke all on public.work_portal_case_shares from public,anon,authenticated;grant select on public.work_portal_case_shares to authenticated;
create policy work_portal_case_shares_read on public.work_portal_case_shares for select to authenticated using(private.work_customer_allowed(customer_id));
create trigger work_portal_case_shares_audit after insert or update on public.work_portal_case_shares for each row execute function private.work_audit_change();
create table public.work_customer_merges(id uuid primary key default gen_random_uuid(),source_id uuid not null unique references public.work_customers(id),target_id uuid not null references public.work_customers(id),reason text not null check(length(trim(reason)) between 5 and 500),created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),check(source_id<>target_id));
alter table public.work_customer_merges enable row level security;revoke all on public.work_customer_merges from public,anon,authenticated;grant select on public.work_customer_merges to authenticated;
create policy work_customer_merges_read on public.work_customer_merges for select to authenticated using(private.work_ops_allowed('sales'));
create trigger work_customer_merges_audit after insert on public.work_customer_merges for each row execute function private.work_audit_change();
create function private.work_customers_bulk(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare row jsonb;rid uuid;target uuid;source uuid;tbl text;n integer=0;
begin
 perform private.work_require('sales',auth.uid());
 if c->>'action'='import' then
  if jsonb_typeof(c->'rows') is distinct from 'array' or jsonb_array_length(c->'rows') not between 1 and 500 then raise exception 'BUSINESS: Import between one and 500 customers.';end if;
  if exists(select 1 from jsonb_array_elements(private.work_customer_import_preview(c->'rows')) r where (r->>'duplicate')::boolean) then raise exception 'BUSINESS: Review duplicate customer records before importing.';end if;
  for row in select * from jsonb_array_elements(c->'rows') loop
   perform private.work_master(jsonb_build_object('entity','customers','version',0,'data',row));n=n+1;
  end loop;
  return jsonb_build_object('inserted',n);
 elsif c->>'action'='merge' then
  perform private.work_require('sales',null,'approve');
  source=(c->>'source_id')::uuid;target=(c->>'target_id')::uuid;
  if source=target then raise exception 'BUSINESS: Choose two different customers.';end if;
  perform 1 from public.work_customers where id in(source,target) order by id for update;
  if (select count(*) from public.work_customers where id in(source,target) and not archived)<>2 then raise exception 'BUSINESS: Select two active customer records.';end if;
  if coalesce((c->>'reviewed')::boolean,false)=false then raise exception 'BUSINESS: Review both records and linked customer access before merging.';end if;
  -- Portal access must be reviewed again after a merge; never silently expand
  -- one customer's access to another organization's documents.
  update public.work_portal_members set active=false where customer_id in(source,target);
  insert into public.work_portal_members(email,customer_id,active) select email,target,false from public.work_portal_members where customer_id=source on conflict(email,customer_id) do nothing;
  foreach tbl in array array['work_contacts','work_enquiries','work_opportunities','work_quotes','work_commercial','work_payments','work_cases','work_notes','work_assets','work_portal_shares','work_portal_events','work_portal_case_shares'] loop
   execute format('update public.%I set customer_id=$1 where customer_id=$2',tbl) using target,source;
  end loop;
  update public.work_customers set archived=true where id=source;
  insert into public.work_customer_merges(source_id,target_id,reason) values(source,target,c->>'reason');
  return jsonb_build_object('target_id',target,'portal_access_requires_review',true);
 end if;
 raise exception 'BUSINESS: Unsupported customer bulk action.';
end;$$;
create function private.work_fulfilment(c jsonb) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare r public.work_commercial;result jsonb;
begin
 perform private.work_require('inventory',null,'read');
 if c->>'action'='lookup' then
  select coalesce(jsonb_agg(x),'[]') into result from (select id,number,title,kind,status from public.work_commercial where status='issued' and kind in ('order','purchase','delivery') and (coalesce(c->>'kind','')='' or kind=c->>'kind') and (coalesce(c->>'query','')='' or position(lower(c->>'query') in lower(number||' '||title))>0) order by created_at desc limit 50 offset coalesce((c->>'page')::integer,0)*50) x;return result;
 elsif c->>'action'='source' then
  select * into r from public.work_commercial where id=(c->>'id')::uuid and kind='order' and status='issued';
  if r.id is null then raise exception 'BUSINESS: Choose an issued customer order.';end if;
  return jsonb_build_object('record',jsonb_build_object('id',r.id,'kind',r.kind,'number',r.number,'customer_id',r.customer_id,'currency',r.currency,'discount_minor',0,'tax_bps',0),'lines',(select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'item_id',l.item_id,'description',l.description,'quantity',l.quantity,'unit_minor',0) order by position),'[]') from public.work_commercial_lines l where record_id=r.id));
 elsif c->>'action'='lines' then
  select * into r from public.work_commercial where id=(c->>'id')::uuid and kind in ('purchase','delivery') and status='issued';
  if r.id is null then raise exception 'BUSINESS: Choose an issued purchase or delivery document.';end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('id',id,'record_id',record_id,'item_id',item_id,'description',description,'quantity',quantity,'position',position) order by position),'[]') from public.work_commercial_lines where record_id=r.id);
 end if;
 raise exception 'BUSINESS: Unsupported fulfilment lookup.';
end;$$;
grant execute on function private.work_fulfilment(jsonb) to authenticated;
create function public.work_fulfilment(c jsonb) returns jsonb language sql security invoker set search_path='' as $$select private.work_fulfilment(c)$$;
revoke all on function public.work_fulfilment(jsonb) from public,anon;grant execute on function public.work_fulfilment(jsonb) to authenticated;
create function private.work_quote_list(q text,page integer,outcome text) returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(x),'[]') from (select qt.document_id id,qt.*,d.number,d.status document_status,d.total_minor,d.payload->>'currency' currency
 from public.work_quotes qt join public.work_documents d on d.id=qt.document_id
 where private.work_quote_permission(qt.document_id) and (coalesce(q,'')='' or position(lower(q) in lower(coalesce(d.number,'')||' '||coalesce(d.payload#>>'{customer,name}','')))>0) and (coalesce(outcome,'')='' or qt.outcome=work_quote_list.outcome)
 order by qt.created_at desc limit 51 offset greatest(0,least(page,100000))*50) x
$$;
grant execute on function private.work_quote_list(text,integer,text) to authenticated;
create function public.work_quote_list(q text,page integer,outcome text) returns jsonb language sql security invoker set search_path='' as $$select private.work_quote_list(q,page,outcome)$$;
revoke all on function public.work_quote_list(text,integer,text) from public,anon;grant execute on function public.work_quote_list(text,integer,text) to authenticated;
create policy work_receipt_ops_read on public.work_documents for select to authenticated using(kind='receipt' and private.work_ops_allowed('finance'));
alter table public.work_stock add column reverses_id uuid references public.work_stock(id);
alter table public.work_enquiries add column privacy_ack_at timestamptz;
create function private.work_customer_import_preview(rows jsonb) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform private.work_require('sales',auth.uid());
 if jsonb_typeof(rows) is distinct from 'array' or jsonb_array_length(rows) not between 1 and 500 then raise exception 'BUSINESS: Import between one and 500 customers.';end if;
 with candidates as (select value,ordinality,count(*) over(partition by lower(value->>'name')) repeats from jsonb_array_elements(rows) with ordinality)
 select coalesce(jsonb_agg(jsonb_build_object('row',ordinality+1,'name',value->>'name','email',value->>'email','duplicate',repeats>1 or exists(select 1 from public.work_customers cu where lower(cu.name)=lower(value->>'name') or coalesce(value->>'email','')<>'' and lower(cu.email)=lower(value->>'email'))) order by ordinality),'[]') into result from candidates;
 return result;
end;$$;
grant execute on function private.work_customer_import_preview(jsonb) to authenticated;
create function public.work_customer_import_preview(rows jsonb) returns jsonb language sql security invoker set search_path='' as $$select private.work_customer_import_preview(rows)$$;
revoke all on function public.work_customer_import_preview(jsonb) from public,anon;grant execute on function public.work_customer_import_preview(jsonb) to authenticated;
create function private.work_case_allowed(cid uuid,writing boolean default false) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.work_cases k where k.id=cid and (
 private.work_ops_allowed(case when k.kind='project' then 'projects' else 'support' end,k.assigned_to,case when writing then 'write' else 'read' end) or
 not writing and private.work_ops_allowed(case when k.kind='project' then 'projects' else 'support' end,auth.uid()) and exists(select 1 from public.work_tasks t where t.case_id=k.id and t.assigned_to=auth.uid())))
$$;
grant execute on function private.work_case_allowed(uuid,boolean) to authenticated;
drop policy work_cases_read on public.work_cases;
create policy work_cases_read on public.work_cases for select to authenticated using(private.work_case_allowed(id));

create or replace function private.work_customer_allowed(cid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.work_customers c where c.id=cid and
 (private.work_ops_allowed('sales',c.assigned_to) or private.work_ops_allowed('finance',null) or exists(select 1 from public.work_cases k where k.customer_id=c.id and private.work_case_allowed(k.id))))
$$;
alter table public.work_expenses add column cost_minor bigint not null default 0 check(cost_minor between 0 and 1000000000000);
alter table public.work_expenses add column cost_currency text not null default 'NGN' check(cost_currency in ('NGN','USD','GBP','EUR'));
alter table public.work_expenses add column fx_rate_micros bigint not null default 1000000 check(fx_rate_micros between 1 and 1000000000000);
alter table public.work_expenses add column fx_date date;
alter table public.work_expenses add column fx_reference text not null default '' check(length(fx_reference)<=200);
create function public.work_business_reports() returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object(
 'receivables',(select coalesce(jsonb_agg(x),'[]') from (select b.id,b.number,c.name customer,b.currency,b.due_date,b.outstanding_minor,
 case when b.due_date is null then 'No due date' when b.due_date>=current_date then 'Current' when current_date-b.due_date<=30 then '1–30 days' when current_date-b.due_date<=60 then '31–60 days' when current_date-b.due_date<=90 then '61–90 days' else 'Over 90 days' end ageing
 from public.work_invoice_balances b join public.work_customers c on c.id=b.customer_id where b.outstanding_minor>0 order by b.due_date nulls last limit 1000) x),
 'payables',(select coalesce(jsonb_agg(x),'[]') from (select e.id,e.title,s.name supplier,e.currency,e.due_on,e.amount_minor-coalesce((select sum(amount_minor) from public.work_supplier_payments p where p.expense_id=e.id),0) outstanding_minor
 from public.work_expenses e left join public.work_suppliers s on s.id=e.supplier_id where e.status='approved' and e.amount_minor>coalesce((select sum(amount_minor) from public.work_supplier_payments p where p.expense_id=e.id),0) order by due_on nulls last limit 1000) x),
 'spending',(select coalesce(jsonb_agg(x),'[]') from (select category,currency,sum(amount_minor)::bigint amount_minor from public.work_expenses where status='approved' group by category,currency) x),
 'orders',(select coalesce(jsonb_agg(x),'[]') from (select o.id,o.number,o.title,o.currency,
 coalesce((select sum(i.total_minor) from public.work_commercial i where i.source_id=o.id and i.kind='invoice' and i.status='issued'),0)::bigint invoiced_minor,
 coalesce((select sum(cr.total_minor) from public.work_commercial cr join public.work_commercial i on i.id=cr.source_id where i.source_id=o.id and cr.kind='credit' and cr.status='issued'),0)::bigint credited_minor,
 coalesce((select sum(e.cost_minor) from public.work_expenses e where e.order_id=o.id and e.status='approved' and e.cost_currency=o.currency),0)::bigint recorded_cost_minor
 from public.work_commercial o where o.kind='order' and o.status='issued' order by o.created_at desc limit 1000) x));
$$;
revoke all on function public.work_business_reports() from public,anon;grant execute on function public.work_business_reports() to authenticated;

-- Background backups use a separate, server-held proof. Staff MFA policies are
-- never bypassed by fabricated user claims. No auth credentials are exported.
create function private.work_backup_proof() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.work_job_config where id=1 and proof_hash=encode(sha256(convert_to(coalesce(nullif(current_setting('request.headers',true),'')::jsonb->>'x-lutera-backup-proof',''),'UTF8')),'hex'))
$$;
grant execute on function private.work_backup_proof() to anon,authenticated;
create table public.work_backup_runs (
 id uuid primary key default gen_random_uuid(), day date not null default current_date, path text not null unique,
 status text not null default 'running' check(status in ('running','primary','complete','failed')),
 sha256 text,bytes bigint,file_count integer,drive_id text,last_error text not null default '',
 created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
alter table public.work_backup_runs enable row level security;
revoke all on public.work_backup_runs from public,anon,authenticated;grant select on public.work_backup_runs to authenticated;
create policy work_backup_runs_owner on public.work_backup_runs for select to authenticated using(private.work_allowed('backup'));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('work-backups','work-backups',false,67108864,array['application/octet-stream']);
create policy work_backup_worker_read on storage.objects for select to anon using(bucket_id in ('work-evidence','work-staff','work-avatars','work-backups') and private.work_backup_proof());
create policy work_backup_worker_insert on storage.objects for insert to anon with check(bucket_id='work-backups' and private.work_backup_proof() and exists(select 1 from public.work_backup_runs where path=storage.objects.name and status='running'));
-- The write-policy lookup must not depend on SELECT access to the log table.
drop policy work_backup_worker_insert on storage.objects;
create function private.work_backup_write_path(p text) returns boolean language sql stable security definer set search_path='' as $$
 select private.work_backup_proof() and exists(select 1 from public.work_backup_runs where path=p and status='running')
$$;
grant execute on function private.work_backup_write_path(text) to anon;
create policy work_backup_worker_insert on storage.objects for insert to anon with check(bucket_id='work-backups' and private.work_backup_write_path(storage.objects.name));
create function private.work_backup_job(proof text,c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.work_backup_runs;result jsonb='{}';tbl text;rows jsonb;total bigint=0;manifest jsonb;
begin
 if length(coalesce(proof,''))<>64 or not exists(select 1 from private.work_job_config where id=1 and proof_hash=encode(sha256(convert_to(proof,'UTF8')),'hex')) then raise exception using errcode='42501',message='Invalid backup proof';end if;
 if c->>'action'='begin' then
  perform pg_advisory_xact_lock(87182345);
  if exists(select 1 from public.work_backup_runs where day=current_date and status in ('primary','complete')) or exists(select 1 from public.work_backup_runs where status='running' and created_at>now()-interval '10 minutes') then return null;end if;
  update public.work_backup_runs set status='failed',last_error='Backup lease expired',updated_at=now() where status='running';
  insert into public.work_backup_runs(path) values('daily/'||current_date||'-'||gen_random_uuid()||'.lutera') returning * into r;
  for tbl in select unnest(array['work_members','work_settings','work_site_drafts','work_documents','work_staff','work_audit','work_public_site','work_publications','work_profiles','work_grants','work_customers','work_contacts','work_enquiries','work_opportunities','work_suppliers','work_items','work_quotes','work_commercial','work_commercial_lines','work_files','work_payments','work_allocations','work_refunds','work_cases','work_tasks','work_notes','work_stock','work_reservations','work_assets','work_expenses','work_supplier_payments','work_decisions','work_messages','work_bank_lines','work_portal_members','work_portal_shares','work_portal_events','work_offers','work_automation','work_portal_case_shares','work_customer_merges','work_calendar','work_case_service','work_case_templates','work_case_events','work_case_changes']) loop
   execute format('select coalesce(jsonb_agg(to_jsonb(t)),''[]''::jsonb) from public.%I t',tbl) into rows;
   total=total+jsonb_array_length(rows);if total>50000 then raise exception 'Backup record limit exceeded';end if;
   result=result||jsonb_build_object(tbl,rows);
  end loop;
  result=result||jsonb_build_object('private.work_counters',coalesce((select jsonb_agg(to_jsonb(t)) from private.work_counters t),'[]'::jsonb),'private.work_requests',coalesce((select jsonb_agg(to_jsonb(t)) from private.work_requests t),'[]'::jsonb),'format','lutera-business-records-v2','created_at',now(),'auth_users_included',false);
  select coalesce(jsonb_agg(jsonb_build_object('bucket',bucket_id,'path',name)),'[]'::jsonb) into manifest from storage.objects where bucket_id in ('work-evidence','work-staff','work-avatars');
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
grant execute on function private.work_backup_job(text,jsonb) to anon;
create function public.work_backup_job(proof text,c jsonb) returns jsonb language sql security invoker set search_path='' as $$select private.work_backup_job(proof,c)$$;
revoke all on function public.work_backup_job(text,jsonb) from public,authenticated;grant execute on function public.work_backup_job(text,jsonb) to anon;

-- Delivery controls: category templates, explicit commitments, change approvals,
-- equipment links and status history. No service target is promised by default.
create table public.work_calendar(id integer primary key check(id=1),days integer[] not null default array[1,2,3,4,5],start_minute integer not null default 540,end_minute integer not null default 1020,holidays date[] not null default '{}',version integer not null default 1,check(start_minute between 0 and 1439 and end_minute between 1 and 1440 and end_minute>start_minute),check(cardinality(days) between 1 and 7 and days<@array[0,1,2,3,4,5,6]));
insert into public.work_calendar(id) values(1);
create table public.work_case_service(case_id uuid primary key references public.work_cases(id),asset_id uuid references public.work_assets(id),agreed_response_minutes integer check(agreed_response_minutes between 1 and 86400),coverage text not null default '' check(length(coverage)<=4000),pause_reason text not null default '' check(length(pause_reason)<=1000),resolution text not null default '' check(length(resolution)<=4000),site_ready boolean not null default false,equipment_checked boolean not null default false,commissioning_complete boolean not null default false,handover_complete boolean not null default false,training_complete boolean not null default false,version integer not null default 1);
create table public.work_case_templates(case_id uuid primary key references public.work_cases(id),category text not null,created_at timestamptz not null default now());
create table public.work_case_events(id uuid primary key default gen_random_uuid(),case_id uuid not null references public.work_cases(id),previous_status text,status text not null,actor uuid references auth.users(id),created_at timestamptz not null default now());
create table public.work_case_changes(id uuid primary key default gen_random_uuid(),case_id uuid not null references public.work_cases(id),summary text not null check(length(trim(summary)) between 5 and 200),details text not null check(length(trim(details)) between 10 and 4000),amount_minor bigint not null default 0 check(amount_minor between -1000000000000 and 1000000000000),currency text not null check(currency in ('NGN','USD','EUR','GBP')),revised_due_on date,evidence_id uuid references public.work_files(id),quote_id uuid references public.work_documents(id),replacement_order_id uuid references public.work_commercial(id),task_id uuid references public.work_tasks(id),status text not null default 'submitted' check(status in ('submitted','approved','rejected','applied')),reason text not null default '' check(length(reason)<=500),created_by uuid not null default auth.uid(),decided_by uuid references auth.users(id),version integer not null default 1,request_key uuid not null unique,created_at timestamptz not null default now());
create index work_case_events_case_idx on public.work_case_events(case_id,created_at desc);
create index work_case_changes_case_idx on public.work_case_changes(case_id,created_at desc);
alter table public.work_calendar enable row level security;alter table public.work_case_service enable row level security;alter table public.work_case_templates enable row level security;alter table public.work_case_events enable row level security;alter table public.work_case_changes enable row level security;
revoke all on public.work_calendar,public.work_case_service,public.work_case_templates,public.work_case_events,public.work_case_changes from public,anon,authenticated;
grant select on public.work_calendar,public.work_case_service,public.work_case_templates,public.work_case_events,public.work_case_changes to authenticated;
create policy work_calendar_read on public.work_calendar for select to authenticated using(private.work_allowed('session'));
create policy work_case_service_read on public.work_case_service for select to authenticated using(private.work_case_allowed(case_id));
create policy work_case_templates_read on public.work_case_templates for select to authenticated using(private.work_case_allowed(case_id));
create policy work_case_events_read on public.work_case_events for select to authenticated using(private.work_case_allowed(case_id));
create policy work_case_changes_read on public.work_case_changes for select to authenticated using(private.work_case_allowed(case_id));
create trigger work_case_service_audit after insert or update on public.work_case_service for each row execute function private.work_audit_change();
create trigger work_case_changes_audit after insert or update on public.work_case_changes for each row execute function private.work_audit_change();
create trigger work_calendar_audit after update on public.work_calendar for each row execute function private.work_audit_change();
create function private.work_working_deadline(started timestamptz,minutes integer) returns timestamptz language plpgsql stable security definer set search_path='' as $$
declare cfg public.work_calendar;t timestamp=started at time zone 'Africa/Lagos';span integer;left_minutes integer=minutes;i integer;
begin
 select * into cfg from public.work_calendar where id=1;
 for i in 1..400 loop
  if extract(dow from t)::integer=any(cfg.days) and not t::date=any(cfg.holidays) then
   if t<t::date+make_interval(mins=>cfg.start_minute) then t=t::date+make_interval(mins=>cfg.start_minute);end if;
   span=floor(extract(epoch from (t::date+make_interval(mins=>cfg.end_minute)-t))/60);
   if span>0 then if left_minutes<=span then return (t+make_interval(mins=>left_minutes)) at time zone 'Africa/Lagos';end if;left_minutes=left_minutes-span;end if;
  end if;
  t=t::date+interval '1 day';
 end loop;
 raise exception 'BUSINESS: Response target exceeds the configured business calendar horizon.';
end;$$;
create function private.work_case_status_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare service public.work_case_service;
begin
 select * into service from public.work_case_service where case_id=new.id;
 if new.status='waiting' and old.status<>'waiting' and length(trim(coalesce(service.pause_reason,'')))<5 then raise exception 'BUSINESS: Record why this work is waiting before pausing it. Deadlines keep running unless explicitly revised.';end if;
 if new.kind='ticket' and new.status in ('completed','closed') and length(trim(coalesce(service.resolution,'')))<5 then raise exception 'BUSINESS: Record the ticket resolution before closing it.';end if;
 if new.kind='project' and new.category='installation-labs' and new.status='completed' and not coalesce(service.site_ready and service.equipment_checked and service.commissioning_complete and service.handover_complete and service.training_complete,false) then raise exception 'BUSINESS: Finish the installation acceptance checklist before completing this project.';end if;
 return new;
end;$$;
create trigger work_case_status_guard before update on public.work_cases for each row execute function private.work_case_status_guard();
create function private.work_case_history() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if TG_OP='INSERT' then insert into public.work_case_events(case_id,status,actor) values(new.id,new.status,auth.uid());
 elsif new.status<>old.status then insert into public.work_case_events(case_id,previous_status,status,actor) values(new.id,old.status,new.status,auth.uid());end if;return new;
end;$$;
create trigger work_case_history after insert or update on public.work_cases for each row execute function private.work_case_history();
create function private.work_delivery_work(c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare k public.work_cases;r public.work_case_changes;v jsonb=c->'data';line text;tasks text[];a text;result jsonb;svc public.work_case_service;mins integer;
begin
 if c->>'action'='calendar' then
  if not private.work_allowed('members') then raise exception using errcode='42501',message='BUSINESS: Owner access required.';end if;
  update public.work_calendar set days=array(select jsonb_array_elements_text(v->'days')::integer),start_minute=(v->>'start_minute')::integer,end_minute=(v->>'end_minute')::integer,holidays=array(select jsonb_array_elements_text(v->'holidays')::date),version=version+1 where id=1 and version=(c->>'version')::integer returning to_jsonb(work_calendar.*) into result;
  if result is null then raise exception 'BUSINESS: Calendar changed. Refresh before saving.';end if;return result;
 end if;
 select * into k from public.work_cases where id=(c->>'case_id')::uuid for update;
 if k.id is null then raise exception 'BUSINESS: Work record not found.';end if;
 a=case when k.kind='project' then 'projects' else 'support' end;perform private.work_require(a,k.assigned_to);
 if c->>'action'='template' then
  if exists(select 1 from public.work_case_templates where case_id=k.id) then raise exception 'BUSINESS: This project already has a delivery template. Edit its existing tasks.';end if;
  tasks=case k.category when 'installation-labs' then array['Confirm site readiness and agreed scope','Inspect equipment and record serial numbers','Install and commission the lab','Prepare handover and recovery instructions','Provide agreed user training','Obtain named customer acceptance'] when 'ai-automation' then array['Agree business process and success criteria','Review data access and security','Build and test agent workflows','Review human approval and failure paths','Validate with customer and hand over'] when 'software' then array['Confirm requirements and acceptance criteria','Agree architecture and data access','Build and review the implementation','Test functionality and security','Deploy, hand over and obtain acceptance'] when 'data' then array['Agree questions and data sources','Check permission and data quality','Prepare analysis and validate results','Review findings with customer','Hand over documentation and support'] when 'cloud-integration' then array['Review existing systems and access','Agree integration and recovery design','Configure and test in isolation','Validate migration and rollback','Hand over monitoring and documentation'] else array['Confirm requirements and agreed scope','Plan resources and responsibilities','Deliver and document agreed work','Validate the outcome with customer','Record handover and support arrangements'] end;
  insert into public.work_case_templates(case_id,category) values(k.id,k.category);
  foreach line in array tasks loop insert into public.work_tasks(case_id,title,assigned_to) values(k.id,line,k.assigned_to);end loop;
  return jsonb_build_object('created',cardinality(tasks));
 elsif c->>'action'='service' then
  select * into svc from public.work_case_service where case_id=k.id for update;
  if coalesce(svc.version,0)<>coalesce((c->>'version')::integer,0) then raise exception 'BUSINESS: Service details changed. Refresh before saving.';end if;
  if nullif(v->>'asset_id','') is not null and not exists(select 1 from public.work_assets where id=(v->>'asset_id')::uuid and customer_id=k.customer_id) then raise exception 'BUSINESS: Select equipment belonging to this customer.';end if;
  mins=nullif(v->>'agreed_response_minutes','')::integer;
  insert into public.work_case_service(case_id,asset_id,agreed_response_minutes,coverage,pause_reason,resolution,site_ready,equipment_checked,commissioning_complete,handover_complete,training_complete) values(k.id,nullif(v->>'asset_id','')::uuid,mins,coalesce(v->>'coverage',''),coalesce(v->>'pause_reason',''),coalesce(v->>'resolution',''),coalesce((v->>'site_ready')::boolean,false),coalesce((v->>'equipment_checked')::boolean,false),coalesce((v->>'commissioning_complete')::boolean,false),coalesce((v->>'handover_complete')::boolean,false),coalesce((v->>'training_complete')::boolean,false)) on conflict(case_id) do update set asset_id=excluded.asset_id,agreed_response_minutes=excluded.agreed_response_minutes,coverage=excluded.coverage,pause_reason=excluded.pause_reason,resolution=excluded.resolution,site_ready=excluded.site_ready,equipment_checked=excluded.equipment_checked,commissioning_complete=excluded.commissioning_complete,handover_complete=excluded.handover_complete,training_complete=excluded.training_complete,version=work_case_service.version+1;
  if mins is not null and mins is distinct from svc.agreed_response_minutes then update public.work_cases set response_due_at=private.work_working_deadline(k.created_at,mins) where id=k.id;end if;
  return jsonb_build_object('success',true);
 elsif c->>'action'='change' then
  if nullif(v->>'evidence_id','') is not null then perform private.work_evidence((v->>'evidence_id')::uuid,a);end if;
  insert into public.work_case_changes(case_id,summary,details,amount_minor,currency,revised_due_on,evidence_id,request_key) values(k.id,v->>'summary',v->>'details',coalesce((v->>'amount_minor')::bigint,0),v->>'currency',nullif(v->>'revised_due_on','')::date,nullif(v->>'evidence_id','')::uuid,(c->>'request_key')::uuid) returning to_jsonb(work_case_changes.*) into result;return result;
 elsif c->>'action'='decide' then
  perform private.work_require(a,k.assigned_to,'approve');
  select * into r from public.work_case_changes where id=(c->>'id')::uuid and case_id=k.id for update;
  if r.id is null or r.version<>(c->>'version')::integer or length(trim(coalesce(c->>'reason',''))) not between 5 and 500 then raise exception 'BUSINESS: Refresh the change and enter a decision reason.';end if;
  if r.created_by=auth.uid() and not private.work_allowed('members') then raise exception 'BUSINESS: Another authorized colleague must approve your change.';end if;
  if c->>'decision' not in ('approved','rejected','applied') or (c->>'decision' in ('approved','rejected') and r.status<>'submitted') or (c->>'decision'='applied' and r.status<>'approved') then raise exception 'BUSINESS: Change is not in the required approval state.';end if;
  if c->>'decision'='applied' then
   if not exists(select 1 from public.work_commercial where id=nullif(c->>'replacement_order_id','')::uuid and customer_id=k.customer_id and status='issued' and kind='order') and not exists(select 1 from public.work_tasks where id=nullif(c->>'task_id','')::uuid and case_id=k.id) then raise exception 'BUSINESS: Link the issued revised order or billing milestone before applying this change.';end if;
  end if;
  update public.work_case_changes set status=c->>'decision',reason=c->>'reason',decided_by=auth.uid(),replacement_order_id=nullif(c->>'replacement_order_id','')::uuid,task_id=nullif(c->>'task_id','')::uuid,version=version+1 where id=r.id returning to_jsonb(work_case_changes.*) into result;
  if c->>'decision'='applied' and r.revised_due_on is not null then update public.work_cases set due_on=r.revised_due_on where id=k.id;end if;return result;
 end if;
 raise exception 'BUSINESS: Unsupported delivery action.';
end;$$;

create function private.work_approval_notice() returns trigger language plpgsql security definer set search_path='' as $$
declare notify text;
begin
 if new.status='submitted' and old.status<>'submitted' then
  select payload#>>'{company,email}' into notify from public.work_settings where id=1;
  insert into public.work_messages(recipient,subject,body,request_key,purpose,created_by) values(notify,'Expense approval requested','A submitted expense is awaiting review in the private workspace. Reference: '||new.id,md5(new.id::text||':approval:'||new.version)::uuid,'approval-request',null);
 end if;return new;
end;$$;
create trigger work_approval_notice after update on public.work_expenses for each row execute function private.work_approval_notice();

create function private.work_sensitive_settings() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if not private.work_allowed('members') and jsonb_build_array(new.payload->'bank_name',new.payload->'account_name',new.payload->'account_number',new.payload->'tax_id',new.payload->'currency') is distinct from jsonb_build_array(old.payload->'bank_name',old.payload->'account_name',old.payload->'account_number',old.payload->'tax_id',old.payload->'currency') then raise exception 'BUSINESS: Only the owner can change bank, tax or default currency settings.';end if;return new;
end;$$;
create trigger work_sensitive_settings before update on public.work_settings for each row execute function private.work_sensitive_settings();

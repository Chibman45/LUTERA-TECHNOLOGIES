-- Private self-service profiles, confirmed email migration and shared auth limits.
create table public.work_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '' check(length(full_name)<=120),
 phone text not null default '' check(length(phone)<=40 and phone !~ '[[:cntrl:]]'),
 avatar_path text not null default '',
 version integer not null default 1,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(avatar_path='' or avatar_path ~ ('^'||user_id::text||'/[0-9a-f-]{36}\.jpg$'))
);
alter table public.work_profiles enable row level security;
revoke all on public.work_profiles from anon,authenticated;
grant select,insert,update on public.work_profiles to authenticated;
create policy work_profile_self on public.work_profiles for all to authenticated
 using(user_id=(select auth.uid()) and (select private.work_allowed('session')))
 with check(user_id=(select auth.uid()) and (select private.work_allowed('session')));
create function private.work_profile_touch() returns trigger language plpgsql set search_path='' as $$
begin if new.user_id is distinct from old.user_id then raise exception 'Profile owner is immutable';end if;new.version=old.version+1;new.updated_at=now();return new;end;$$;
revoke all on function private.work_profile_touch() from public,anon,authenticated;
create trigger work_profiles_touch before update on public.work_profiles for each row execute function private.work_profile_touch();

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('work-avatars','work-avatars',false,1048576,array['image/jpeg']);
create policy work_avatar_self on storage.objects for all to authenticated
 using(bucket_id='work-avatars' and split_part(name,'/',1)=(select auth.uid())::text and (select private.work_allowed('session')))
 with check(bucket_id='work-avatars' and split_part(name,'/',1)=(select auth.uid())::text and (select private.work_allowed('session')));

create table public.work_email_changes (
 user_id uuid primary key references auth.users(id) on delete cascade,
 old_email text not null, new_email text not null unique,
 created_at timestamptz not null default now()
);
alter table public.work_email_changes enable row level security;
revoke all on public.work_email_changes from anon,authenticated;
grant select on public.work_email_changes to authenticated;
create policy work_email_change_self on public.work_email_changes for select to authenticated
 using(user_id=(select auth.uid()) and (select private.work_allowed('session')));

create function private.work_prepare_email(new_address text) returns boolean
 language plpgsql security definer set search_path='' as $$
declare current_email text; pending public.work_email_changes;
begin
 if not private.work_allowed('session') then raise exception 'Verified account required';end if;
 new_address=lower(trim(new_address));
 if new_address !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' or length(new_address)>254 then raise exception 'Invalid email address';end if;
 perform pg_advisory_xact_lock(hashtextextended('lutera-email-'||auth.uid()::text,0));
 select email into current_email from public.work_members where user_id=auth.uid() and active for update;
 if current_email=new_address then raise exception 'Choose a different email address';end if;
 select * into pending from public.work_email_changes where user_id=auth.uid();
 if found then
  if pending.new_email=new_address then return false;end if;
  raise exception 'Finish the pending email change before requesting another';
 end if;
 if exists(select 1 from public.work_members where email=new_address)
 or exists(select 1 from auth.users where lower(email)=new_address and id<>auth.uid())
 or exists(select 1 from public.work_email_changes where new_email=new_address) then raise exception 'This email cannot be used';end if;
 insert into public.work_email_changes(user_id,old_email,new_email) values(auth.uid(),current_email,new_address);
 insert into public.work_audit(action,entity,entity_id) values('email_change_requested','account',auth.uid()::text);
 return true;
end;$$;
revoke all on function private.work_prepare_email(text) from public,anon;
grant execute on function private.work_prepare_email(text) to authenticated;
create function public.work_prepare_email_change(new_address text) returns boolean
 language sql security invoker set search_path='' as $$select private.work_prepare_email(new_address)$$;
revoke all on function public.work_prepare_email_change(text) from public,anon;
grant execute on function public.work_prepare_email_change(text) to authenticated;

create function private.work_abort_email(new_address text) returns void
 language plpgsql security definer set search_path='' as $$
begin
 if not private.work_allowed('session') then raise exception 'Verified account required';end if;
 -- Only undo a reservation that GoTrue has not accepted. A pending provider
 -- confirmation must keep its reservation until the address is confirmed.
 delete from public.work_email_changes c where c.user_id=auth.uid() and c.new_email=lower(new_address)
 and exists(select 1 from auth.users u where u.id=c.user_id and lower(u.email)=c.old_email
  and coalesce(lower(to_jsonb(u)->>'email_change'),'')<>c.new_email);
end;$$;
revoke all on function private.work_abort_email(text) from public,anon;
grant execute on function private.work_abort_email(text) to authenticated;
create function public.work_abort_email_change(new_address text) returns void
 language sql security invoker set search_path='' as $$select private.work_abort_email(new_address)$$;
revoke all on function public.work_abort_email_change(text) from public,anon;
grant execute on function public.work_abort_email_change(text) to authenticated;

create function private.work_reserved_email() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.work_email_changes where new_email=new.email and user_id is distinct from new.user_id) then
  raise exception 'This email is reserved for a confirmed account change';
 end if;
 return new;
end;$$;
revoke all on function private.work_reserved_email() from public,anon,authenticated;
create trigger work_member_reserved_email before insert or update on public.work_members for each row execute function private.work_reserved_email();

create or replace function private.work_claim() returns void language plpgsql security definer set search_path='' as $$
declare verified_email text; pending public.work_email_changes;
begin
 select lower(u.email) into verified_email from auth.users u where u.id=auth.uid() and u.email_confirmed_at is not null;
 if verified_email is null then raise exception 'Approved verified account required';end if;
 select * into pending from public.work_email_changes where user_id=auth.uid() for update;
 if found and pending.new_email=verified_email then
  update public.work_members set email=verified_email where user_id=auth.uid() and email=pending.old_email and active;
  if not found then raise exception 'Approved verified account required';end if;
  delete from public.work_email_changes where user_id=auth.uid();
  insert into public.work_audit(action,entity,entity_id) values('email_changed','account',auth.uid()::text);
 end if;
 if exists(select 1 from public.work_members where user_id=auth.uid() and email=verified_email and active) then return;end if;
 update public.work_members set user_id=auth.uid() where email=verified_email and active and (user_id is null or user_id=auth.uid());
 if not found then raise exception 'Approved verified account required';end if;
end;$$;

-- Schema USAGE permits resolving the narrow anon rate-check wrapper, not
-- access to private tables or any other helper (their EXECUTE grants stay restricted).
grant usage on schema private to anon;
-- No raw IPs, emails or credentials are stored in rate buckets. A server-only
-- secret authenticates calls; HMAC-derived keys make account/IP buckets opaque.
create table private.work_rate_config(id integer primary key check(id=1), secret_hash text not null check(secret_hash ~ '^[0-9a-f]{64}$'));
create table private.work_rate_buckets(key text primary key, attempts bigint not null, reset_at timestamptz not null);
create index work_rate_expiry_idx on private.work_rate_buckets(reset_at);
alter table private.work_rate_config enable row level security;
alter table private.work_rate_buckets enable row level security;
revoke all on private.work_rate_config,private.work_rate_buckets from public,anon,authenticated;
create function private.work_take_auth_rate(proof text,buckets jsonb) returns jsonb
 language plpgsql security definer set search_path='' as $$
declare spec jsonb; row private.work_rate_buckets; waiting integer:=0; cutoff timestamptz:=clock_timestamp(); lim integer; seconds integer;
begin
 if length(proof)<>64 or not exists(select 1 from private.work_rate_config where id=1 and secret_hash=encode(sha256(convert_to(proof,'UTF8')),'hex')) then raise exception 'Rate check unavailable' using errcode='42501';end if;
 if jsonb_typeof(buckets)<>'array' or jsonb_array_length(buckets) not between 1 and 4 then raise exception 'Invalid rate buckets';end if;
 delete from private.work_rate_buckets where reset_at<cutoff-interval '1 hour';
 for spec in select value from jsonb_array_elements(buckets) order by value->>'key' loop
  lim=(spec->>'limit')::integer; seconds=(spec->>'seconds')::integer;
  if coalesce(spec->>'key','') !~ '^[0-9a-f]{64}$' or lim is null or seconds is null or lim not between 1 and 1000 or seconds not between 1 and 3600 then raise exception 'Invalid rate bucket';end if;
  insert into private.work_rate_buckets(key,attempts,reset_at) values(spec->>'key',1,cutoff+make_interval(secs=>seconds))
  on conflict(key) do update set attempts=case when private.work_rate_buckets.reset_at<=cutoff then 1 else least(private.work_rate_buckets.attempts+1,1000000) end,
   reset_at=case when private.work_rate_buckets.reset_at<=cutoff then excluded.reset_at else private.work_rate_buckets.reset_at end
  returning * into row;
  if row.attempts>lim then waiting=greatest(waiting,ceil(extract(epoch from row.reset_at-cutoff))::integer);end if;
 end loop;
 return jsonb_build_object('allowed',waiting=0,'retry_after',greatest(waiting,0));
end;$$;
revoke all on function private.work_take_auth_rate(text,jsonb) from public;
grant execute on function private.work_take_auth_rate(text,jsonb) to anon,authenticated;
create function public.work_take_auth_rate(proof text,buckets jsonb) returns jsonb
 language sql security invoker set search_path='' as $$select private.work_take_auth_rate(proof,buckets)$$;
revoke all on function public.work_take_auth_rate(text,jsonb) from public;
grant execute on function public.work_take_auth_rate(text,jsonb) to anon,authenticated;

create function private.work_profile_audit() returns trigger language plpgsql security definer set search_path='' as $$
begin insert into public.work_audit(action,entity,entity_id) values('profile_updated','account',new.user_id::text);return new;end;$$;
revoke all on function private.work_profile_audit() from public,anon,authenticated;
create trigger work_profile_audit after insert or update on public.work_profiles for each row execute function private.work_profile_audit();

-- Serialize reservations against concurrent membership creation.
create or replace function private.work_prepare_email(new_address text) returns boolean
 language plpgsql security definer set search_path='' as $$
declare current_email text; pending public.work_email_changes;
begin
 if not private.work_allowed('session') then raise exception 'Verified account required';end if;
 new_address=lower(trim(new_address));
 if new_address !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' or length(new_address)>254 then raise exception 'Invalid email address';end if;
 perform pg_advisory_xact_lock(hashtextextended('lutera-email-'||auth.uid()::text,0));
 select email into current_email from public.work_members where user_id=auth.uid() and active for update;
 if current_email=new_address then raise exception 'Choose a different email address';end if;
 perform pg_advisory_xact_lock(hashtextextended('lutera-email-target-'||new_address,0));
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

create or replace function private.work_reserved_email() returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform pg_advisory_xact_lock(hashtextextended('lutera-email-target-'||new.email,0));
 if exists(select 1 from public.work_email_changes c join auth.users u on u.id=c.user_id where c.new_email=new.email and c.user_id is distinct from new.user_id) then
  raise exception 'This email is reserved for a confirmed account change';
 end if;
 return new;
end;$$;

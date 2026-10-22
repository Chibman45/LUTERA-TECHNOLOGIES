-- Disposable fixtures inside a transaction. No emails, real staff or payments.
begin;
create temp table work_test_ids(owner_id uuid, editor_id uuid, session_id uuid, editor_session uuid, factor_id uuid, editor_factor uuid);
insert into work_test_ids values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid());
grant select on work_test_ids to authenticated,anon;
insert into auth.users(id,email,email_confirmed_at) select owner_id,'owner-fixture@example.invalid',now() from work_test_ids union all select editor_id,'editor-fixture@example.invalid',now() from work_test_ids;
insert into auth.mfa_factors(id,user_id,factor_type,status,secret,created_at,updated_at) select factor_id,owner_id,'totp'::auth.factor_type,'verified'::auth.factor_status,'TEST-NOT-A-REAL-AUTHENTICATOR',now(),now() from work_test_ids union all select editor_factor,editor_id,'totp'::auth.factor_type,'verified'::auth.factor_status,'TEST-NOT-A-REAL-AUTHENTICATOR',now(),now() from work_test_ids;
insert into auth.sessions(id,user_id,factor_id,aal,created_at,updated_at) select session_id,owner_id,factor_id,'aal2'::auth.aal_level,now(),now() from work_test_ids union all select editor_session,editor_id,editor_factor,'aal2'::auth.aal_level,now(),now() from work_test_ids;
insert into public.work_members(email,user_id,role) select 'owner-fixture@example.invalid',owner_id,'owner' from work_test_ids union all select 'editor-fixture@example.invalid',editor_id,'editor' from work_test_ids;

-- Self-service profile policies apply equally to every approved role.
select set_config('request.jwt.claims',json_build_object('sub',editor_id,'aal','aal1','session_id',editor_session)::text,true) from work_test_ids;
set local role authenticated;
do $$declare denied boolean:=false;begin
 begin insert into public.work_profiles(user_id,full_name) values(auth.uid(),'TEST profile');exception when insufficient_privilege then denied=true;end;
 if not denied then raise exception 'AAL1 profile write allowed';end if;
end;$$;
reset role;
select set_config('request.jwt.claims',json_build_object('sub',editor_id,'aal','aal2','session_id',editor_session)::text,true) from work_test_ids;
set local role authenticated;
do $$declare denied boolean;begin
 insert into public.work_profiles(user_id,full_name,phone) values(auth.uid(),'Profile fixture','+234 123456789');
 update public.work_profiles set full_name='Updated profile' where user_id=auth.uid();
 if (select version from public.work_profiles where user_id=auth.uid())<>2 then raise exception 'Profile version did not advance';end if;
 denied=false;begin insert into public.work_profiles(user_id,full_name) values((select owner_id from work_test_ids),'Foreign profile');exception when insufficient_privilege then denied=true;end;
 if not denied then raise exception 'Cross-user profile insert allowed';end if;
 denied=false;begin update public.work_profiles set user_id=(select owner_id from work_test_ids) where user_id=auth.uid();exception when raise_exception then denied=true;end;
 if not denied then raise exception 'Profile owner was editable';end if;
 insert into storage.objects(bucket_id,name) values('work-avatars',auth.uid()::text||'/fixture.jpg');
 denied=false;begin insert into storage.objects(bucket_id,name) values('work-avatars',(select owner_id::text from work_test_ids)||'/fixture.jpg');exception when insufficient_privilege then denied=true;end;
 if not denied then raise exception 'Cross-user avatar write allowed';end if;
 if not public.work_prepare_email_change('new-editor-fixture@example.invalid') then raise exception 'Email reservation not created';end if;
 if public.work_prepare_email_change('new-editor-fixture@example.invalid') then raise exception 'Duplicate reservation was not idempotent';end if;
 perform public.work_claim_membership();
 if (select email from public.work_members where user_id=auth.uid())<>'editor-fixture@example.invalid' then raise exception 'Email changed before provider confirmation';end if;
 denied=false;begin perform public.work_prepare_email_change('second-fixture@example.invalid');exception when raise_exception then denied=true;end;
 if not denied then raise exception 'Pending email reservation was silently replaced';end if;
end;$$;
reset role;
select set_config('request.jwt.claims',json_build_object('sub',owner_id,'aal','aal2','session_id',session_id)::text,true) from work_test_ids;
set local role authenticated;
do $$declare denied boolean;begin
 if exists(select 1 from public.work_profiles) then raise exception 'Other user profile exposed';end if;
 if exists(select 1 from storage.objects where bucket_id='work-avatars') then raise exception 'Other user avatar exposed';end if;
 denied=false;begin perform public.work_set_member('new-editor-fixture@example.invalid','owner',true);exception when raise_exception then denied=true;end;
 if not denied then raise exception 'Reserved email granted to a different membership';end if;
end;$$;
reset role;
update auth.users set email='new-editor-fixture@example.invalid' where id=(select editor_id from work_test_ids);
select set_config('request.jwt.claims',json_build_object('sub',editor_id,'aal','aal1','session_id',editor_session)::text,true) from work_test_ids;
set local role authenticated;
select public.work_claim_membership();
reset role;
do $$begin
 if not exists(select 1 from public.work_members where user_id=(select editor_id from work_test_ids) and email='new-editor-fixture@example.invalid' and role='editor' and active) then raise exception 'Confirmed email did not preserve role';end if;
 if exists(select 1 from public.work_email_changes where user_id=(select editor_id from work_test_ids)) then raise exception 'Confirmed reservation not cleared';end if;
end;$$;
-- Authentication limiter fixture secret exists only in this rolled-back transaction.
insert into private.work_rate_config(id,secret_hash) values(1,encode(sha256(convert_to(repeat('1',64),'UTF8')),'hex')) on conflict(id) do update set secret_hash=excluded.secret_hash;
set local role anon;
do $$declare denied boolean; a jsonb; b jsonb:=jsonb_build_array(jsonb_build_object('key',repeat('a',64),'limit',2,'seconds',60));begin
 denied=false;begin perform public.work_take_auth_rate(repeat('0',64),b);exception when insufficient_privilege then denied=true;end;
 if not denied then raise exception 'Invalid limiter proof accepted';end if;
 a=public.work_take_auth_rate(repeat('1',64),b);if not (a->>'allowed')::boolean then raise exception 'First attempt rejected';end if;
 a=public.work_take_auth_rate(repeat('1',64),b);if not (a->>'allowed')::boolean then raise exception 'Second attempt rejected';end if;
 a=public.work_take_auth_rate(repeat('1',64),b);if (a->>'allowed')::boolean or (a->>'retry_after')::integer not between 1 and 60 then raise exception 'Limiter did not block with retry';end if;
 denied=false;begin perform * from private.work_rate_config;exception when insufficient_privilege then denied=true;end;
 if not denied then raise exception 'Rate secret hash exposed';end if;
 denied=false;begin perform * from public.work_profiles;exception when insufficient_privilege then denied=true;end;
 if not denied then raise exception 'Anonymous profile access';end if;
end;$$;
reset role;
update private.work_rate_buckets set reset_at=now()-interval '1 second' where key=repeat('a',64);
set local role anon;
do $$begin if not (public.work_take_auth_rate(repeat('1',64),jsonb_build_array(jsonb_build_object('key',repeat('a',64),'limit',2,'seconds',60)))->>'allowed')::boolean then raise exception 'Expired rate bucket did not reset';end if;end;$$;
reset role;
select 'PASS: own profile/avatar RLS, AAL1/anonymous denial, confirmed email role preservation, email reservation, limiter proof/quota/retry/expiry. Fixtures rolled back.' as result;
rollback;

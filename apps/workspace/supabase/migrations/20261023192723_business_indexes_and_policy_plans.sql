-- Cover foreign-key lookups and archive pagination without duplicating existing
-- index prefixes. This release runs before operational data entry begins.
do $$
declare r record;cols text;idx text;
begin
 for r in select c.conrelid,c.conname,c.conkey,t.relname from pg_constraint c join pg_class t on t.oid=c.conrelid join pg_namespace n on n.oid=t.relnamespace where c.contype='f' and n.nspname='public' and t.relname like 'work\_%' escape '\' and not exists(select 1 from pg_index i where i.indrelid=c.conrelid and i.indisvalid and i.indpred is null and array(select k from unnest(i.indkey) with ordinality as x(k,ord) where ord<=cardinality(c.conkey) order by ord)=c.conkey) loop
  select string_agg(quote_ident(a.attname),',' order by x.ord) into cols from unnest(r.conkey) with ordinality x(attnum,ord) join pg_attribute a on a.attrelid=r.conrelid and a.attnum=x.attnum;
  idx=left(r.relname,28)||'_fk_'||substr(md5(r.conname),1,12);
  execute format('create index %I on %s (%s)',idx,r.conrelid::regclass,cols);
 end loop;
 for r in select c.oid,c.relname,a.attnum from pg_class c join pg_namespace n on n.oid=c.relnamespace join pg_attribute a on a.attrelid=c.oid and a.attname='created_at' and not a.attisdropped where n.nspname='public' and c.relkind='r' and c.relname like 'work\_%' escape '\' and not exists(select 1 from pg_index i where i.indrelid=c.oid and i.indisvalid and i.indpred is null and i.indkey[0]=a.attnum) loop
  execute format('create index %I on %s (created_at desc)',left(r.relname,45)||'_archive_idx',r.oid::regclass);
 end loop;
end;$$;
drop policy work_grants_read on public.work_grants;
create policy work_grants_read on public.work_grants for select to authenticated using((select private.work_allowed('members')) or exists(select 1 from public.work_members m where m.user_id=(select auth.uid()) and m.email=work_grants.email and (select private.work_allowed('session'))));
drop policy work_finance on public.work_documents;
drop policy work_sales_quote_read on public.work_documents;
drop policy work_receipt_ops_read on public.work_documents;
create policy work_documents_read on public.work_documents for select to authenticated using((select private.work_allowed('finance')) or kind='receipt' and (select private.work_ops_allowed('finance')) or kind in ('quotation','proforma') and private.work_quote_permission(id));
create policy work_finance_insert on public.work_documents for insert to authenticated with check((select private.work_allowed('finance')));
create policy work_finance_update on public.work_documents for update to authenticated using((select private.work_allowed('finance'))) with check((select private.work_allowed('finance')));
create policy work_finance_delete on public.work_documents for delete to authenticated using((select private.work_allowed('finance')));

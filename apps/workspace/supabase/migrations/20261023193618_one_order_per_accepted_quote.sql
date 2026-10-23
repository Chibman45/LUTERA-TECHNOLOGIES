-- Serialize quote conversion and prevent duplicate committed orders, even when
-- two staff members issue different drafts at the same time.
create unique index work_order_quote_once_idx on public.work_commercial(quote_id) where kind='order' and status='issued' and quote_id is not null;
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
  if r.kind in ('purchase','credit') and r.assigned_to=auth.uid() and not private.work_allowed('members') then raise exception 'BUSINESS: Another authorized colleague must approve your document.';end if;
  select sum(quantity::numeric*unit_minor) into subtotal from public.work_commercial_lines where record_id=r.id;
  if subtotal is null or subtotal<r.discount_minor or subtotal>1000000000000 or (subtotal=r.discount_minor and r.kind not in ('rfq','delivery')) then raise exception 'BUSINESS: Invalid totals or missing line items.';end if;
  tax=round((subtotal-r.discount_minor)*r.tax_bps/10000);
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

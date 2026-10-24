-- These private caches are used only inside reviewed privileged functions.
-- No direct authenticated/anonymous access is allowed, including after a future grant.
create policy work_ops_requests_deny on private.work_ops_requests
  for all to anon, authenticated using (false) with check (false);
create policy work_message_statements_deny on private.work_message_statements
  for all to anon, authenticated using (false) with check (false);

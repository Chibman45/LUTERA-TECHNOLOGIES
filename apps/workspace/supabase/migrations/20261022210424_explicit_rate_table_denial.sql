-- Explicit denial documents that only the scoped definer RPC can access these.
create policy work_rate_config_deny on private.work_rate_config for all to anon,authenticated using(false) with check(false);
create policy work_rate_buckets_deny on private.work_rate_buckets for all to anon,authenticated using(false) with check(false);

-- Run as the migration owner after applying chat.sql to the disposable project.
-- Enable Supabase Cron (pg_cron) first. Then schedule once; inspect existing jobs
-- before rerunning this file. A one-minute retry tolerates missing daily partitions.
select cron.schedule('homecircle-chat-outbox','* * * * *',
  'select public.dispatch_chat_outbox(100)');
-- Monitor: select count(*),min(created_at) from public.chat_events where published_at is null;
-- Review retention before pruning old published invalidations. Keep message tombstones
-- and conversion/idempotency identities so old retries cannot create duplicates.

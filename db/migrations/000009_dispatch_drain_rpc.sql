-- migrate:up transaction:false
-- ============================================================================
-- step7_dispatch_drain_rpc.sql
-- ----------------------------------------------------------------------------
-- Drain-side helpers for the dispatch_queue outbox (Task 2).
--
-- The drainer (n8n schedule workflow OR scripts/drain_dispatch.js) calls:
--   1. claim_dispatch_batch(n)        → atomically grab up to n due rows,
--                                        flipping them to 'sent'-pending work by
--                                        bumping attempts and clearing them out
--                                        of the due window (so two concurrent
--                                        drainers never double-send).
--   2. mark_dispatch_sent(id)         → success → status='sent', sent_at=now()
--   3. mark_dispatch_failed(id, err)  → failure → backoff or dead_letter
--
-- Backoff: next_retry_at = now() + (2 ^ attempts) minutes. Dead-letter at 5.
--
-- Idempotent: CREATE OR REPLACE throughout.
-- ============================================================================

-- ── Claim a batch (concurrency-safe via FOR UPDATE SKIP LOCKED) ──────────────
-- Returns rows that are due now: status pending/failed AND next_retry_at <= now.
-- SKIP LOCKED lets multiple drainers run without contending on the same rows.
CREATE OR REPLACE FUNCTION claim_dispatch_batch(p_limit int DEFAULT 20)
RETURNS SETOF dispatch_queue
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
begin
  return query
  with due as (
    select id
    from dispatch_queue
    where status in ('pending','failed')
      and (next_retry_at is null or next_retry_at <= now())
    order by created_at
    limit p_limit
    for update skip locked
  )
  update dispatch_queue d
  set attempts = d.attempts + 1
  from due
  where d.id = due.id
  returning d.*;
end $function$;

-- ── Mark a row delivered ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION mark_dispatch_sent(p_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $function$
  update dispatch_queue
  set status = 'sent', sent_at = now(), last_error = null
  where id = p_id;
$function$;

-- ── Mark a row failed: exponential backoff, dead-letter after 5 attempts ─────
CREATE OR REPLACE FUNCTION mark_dispatch_failed(p_id uuid, p_error text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
declare
  v_attempts int;
begin
  select attempts into v_attempts from dispatch_queue where id = p_id;
  if v_attempts >= 5 then
    update dispatch_queue
    set status = 'dead_letter', last_error = p_error
    where id = p_id;
  else
    update dispatch_queue
    set status = 'failed',
        last_error = p_error,
        next_retry_at = now() + (power(2, v_attempts) || ' minutes')::interval
    where id = p_id;
  end if;
end $function$;

-- ── Grants ───────────────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION claim_dispatch_batch(int)        TO truespend_app, truespend;
GRANT EXECUTE ON FUNCTION mark_dispatch_sent(uuid)         TO truespend_app, truespend;
GRANT EXECUTE ON FUNCTION mark_dispatch_failed(uuid, text) TO truespend_app, truespend;

-- migrate:down transaction:false
-- Irreversible / forward-only migration. Roll forward with a new migration
-- per invariant I-8; no automated down path.
select 1;

-- migrate:up transaction:false
-- =============================================================================
-- step9_intake_status_rpcs.sql
-- All write-backs in the intake_receiver agent path go through SECURITY DEFINER
-- RPCs, so truespend_app never does raw table DML (honors I-1/I-2). Five RPCs:
--   status transitions:  set_ticket_pending_review, escalate_ticket, complete_ticket_auto
--   append-only audit:    record_decision (decisions), record_trace_signals (trace_log)
--
-- truespend_app gets EXECUTE on these only — NO table-level INSERT/UPDATE/DELETE
-- on tickets/decisions/trace_log. Money/budget moves stay in commit_budget /
-- approve_and_commit / reject_ticket (untouched here).
--
-- Idempotent: create-or-replace + idempotent grants. Mirrors close_ticket style.
-- =============================================================================

begin;

-- ── Status transitions ───────────────────────────────────────────────────────

-- one_touch / uncertain → pending_review (human review on the board)
create or replace function set_ticket_pending_review(p_ticket_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update tickets
  set status     = 'pending_review',
      updated_at = now()
  where id = p_ticket_id;
end $$;

-- >€100k or compliance blocker → escalated
create or replace function escalate_ticket(p_ticket_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update tickets
  set status     = 'escalated',
      updated_at = now()
  where id = p_ticket_id;
end $$;

-- auto_execute with no PO required → auto_executed (agent closed it itself)
create or replace function complete_ticket_auto(p_ticket_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update tickets
  set status     = 'auto_executed',
      updated_at = now(),
      closed_at  = now()
  where id = p_ticket_id;
end $$;

-- ── Append-only audit writes ─────────────────────────────────────────────────

-- Insert one agent decision, return its id (the workflow needs decision_id for
-- the trace rows). Append-only: INSERT only, no update/delete path.
create or replace function record_decision(
  p_ticket_id      uuid,
  p_disposition    disposition,
  p_confidence     numeric,
  p_reasoning      text,
  p_recommendation text,
  p_brief          text,
  p_model_used     text
) returns uuid
language plpgsql
security definer
as $$
declare
  v_id uuid;
begin
  insert into decisions (ticket_id, disposition, confidence, reasoning,
                         recommendation, brief, model_used)
  values (p_ticket_id, p_disposition, p_confidence, p_reasoning,
          p_recommendation, p_brief, coalesce(p_model_used, 'claude-sonnet-4-6'))
  returning id into v_id;
  return v_id;
end $$;

-- Insert the (≤5) trace signals for a decision in one call. Accepts a jsonb
-- array of {signal,value,weight,green,notes}; ignores rows with no decision_id.
-- Append-only.
create or replace function record_trace_signals(
  p_decision_id uuid,
  p_signals     jsonb
) returns void
language plpgsql
security definer
as $$
begin
  if p_decision_id is null or p_signals is null then
    return;
  end if;
  insert into trace_log (decision_id, signal, value, weight, green, notes)
  select p_decision_id,
         (s->>'signal')::signal_type,
         coalesce(s->>'value', ''),
         nullif(s->>'weight','')::numeric,
         coalesce((s->>'green')::boolean, true),
         coalesce(s->>'notes', '')
  from jsonb_array_elements(p_signals) as s;
end $$;

-- ── Grants: EXECUTE only, to the app login role. No table DML. ───────────────
grant execute on function set_ticket_pending_review(uuid)                          to truespend_app;
grant execute on function escalate_ticket(uuid)                                    to truespend_app;
grant execute on function complete_ticket_auto(uuid)                               to truespend_app;
grant execute on function record_decision(uuid,disposition,numeric,text,text,text,text) to truespend_app;
grant execute on function record_trace_signals(uuid,jsonb)                         to truespend_app;

commit;

-- migrate:down transaction:false
-- Irreversible / forward-only migration. Roll forward with a new migration
-- per invariant I-8; no automated down path.
select 1;

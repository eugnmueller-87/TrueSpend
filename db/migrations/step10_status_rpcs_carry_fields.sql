-- =============================================================================
-- step10_status_rpcs_carry_fields.sql
-- Widen the 3 intake status-transition RPCs (from step9) so they also set the
-- denormalized ticket fields the old raw-PATCH nodes wrote (recommendation,
-- brief, confidence; + po_number on close). Preserves exact prior behavior while
-- keeping all writes on the SECURITY DEFINER RPC path (I-1/I-2).
--
-- New migration (not an edit of step9, per I-8). create-or-replace + re-grant.
-- record_decision / record_trace_signals (step9) are unchanged.
-- =============================================================================

begin;

-- Drop the narrow step9 signatures first. Otherwise the new ones (which add
-- defaulted params) would OVERLOAD them and make a 1-arg call ambiguous.
drop function if exists set_ticket_pending_review(uuid);
drop function if exists escalate_ticket(uuid);
drop function if exists complete_ticket_auto(uuid);

create or replace function set_ticket_pending_review(
  p_ticket_id      uuid,
  p_recommendation text default null,
  p_brief          text default null,
  p_confidence     numeric default null
) returns void
language plpgsql
security definer
as $$
begin
  update tickets
  set status         = 'pending_review',
      recommendation = coalesce(p_recommendation, recommendation),
      brief          = coalesce(p_brief, brief),
      confidence     = coalesce(p_confidence, confidence),
      updated_at     = now()
  where id = p_ticket_id;
end $$;

create or replace function escalate_ticket(
  p_ticket_id      uuid,
  p_recommendation text default null,
  p_brief          text default null,
  p_confidence     numeric default null
) returns void
language plpgsql
security definer
as $$
begin
  update tickets
  set status         = 'escalated',
      recommendation = coalesce(p_recommendation, recommendation),
      brief          = coalesce(p_brief, brief),
      confidence     = coalesce(p_confidence, confidence),
      updated_at     = now()
  where id = p_ticket_id;
end $$;

create or replace function complete_ticket_auto(
  p_ticket_id      uuid,
  p_recommendation text default null,
  p_brief          text default null,
  p_confidence     numeric default null,
  p_po_number      text default null
) returns void
language plpgsql
security definer
as $$
begin
  update tickets
  set status         = 'auto_executed',
      recommendation = coalesce(p_recommendation, recommendation),
      brief          = coalesce(p_brief, brief),
      confidence     = coalesce(p_confidence, confidence),
      po_number      = coalesce(p_po_number, po_number),
      updated_at     = now(),
      closed_at      = now()
  where id = p_ticket_id;
end $$;

-- Re-grant EXECUTE on the new signatures (the step9 narrow ones still exist but
-- are now shadowed by these; harmless — both grant only to truespend_app).
grant execute on function set_ticket_pending_review(uuid,text,text,numeric) to truespend_app;
grant execute on function escalate_ticket(uuid,text,text,numeric)            to truespend_app;
grant execute on function complete_ticket_auto(uuid,text,text,numeric,text)  to truespend_app;

commit;

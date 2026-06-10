-- migrate:up transaction:false
-- =============================================================================
-- step11_supplier_email_threading.sql
-- Phase 1 (prompt-injection remediation) — schema support for DETERMINISTIC
-- ticket binding in the Supplier Reply Handler.
--
-- The reply handler must derive related_ticket_id from email thread structure,
-- never from Claude's output. To do that it needs to:
--   1. stamp every OUTBOUND supplier email with its RFC Message-ID + the
--      ticket_id it concerns;
--   2. on an INBOUND reply, read the In-Reply-To / References header and look up
--      the matching outbound row -> its ticket_id.
--
-- supplier_emails today has no message_id / in_reply_to / ticket_id columns
-- (see db/schema.sql supplier_emails). This migration adds them + an index.
--
-- truespend_app already has full CRUD on supplier_emails (step2d), so no new
-- grant is required — only the columns. No money/status path is touched (I-1/I-2
-- unaffected: ticket STATUS still changes only via SECURITY DEFINER RPCs; this
-- only adds linkage metadata on an audit table).
--
-- Idempotent: ADD COLUMN IF NOT EXISTS + CREATE INDEX IF NOT EXISTS.
-- I-8: applied to prod + recorded in schema_migrations as a SEPARATE gated step.
-- =============================================================================

begin;

alter table supplier_emails
  add column if not exists message_id   text,   -- RFC 5322 Message-ID of THIS email
  add column if not exists in_reply_to  text,   -- Message-ID this email replies to
  add column if not exists ticket_id    uuid;   -- the ticket this email concerns

-- FK is intentionally NOT enforced here: historical rows have null ticket_id and
-- some emails legitimately concern no ticket. Add the FK in a later migration if
-- desired once backfilled.

-- Look up an outbound email by its Message-ID fast (inbound reply -> parent row).
create index if not exists idx_supplier_emails_message_id
  on supplier_emails (message_id)
  where message_id is not null;

-- Look up a supplier's emails for a ticket.
create index if not exists idx_supplier_emails_ticket_id
  on supplier_emails (ticket_id)
  where ticket_id is not null;

-- =============================================================================
-- queue_supplier_reply_review — SECURITY DEFINER RPC
-- The reply handler calls this to put a supplier reply in front of a human on
-- the Operations Board with the agent's DRAFT attached. It NEVER closes or
-- approves anything — it only creates (or annotates) a pending_review ticket.
-- This is the human gate that replaces the old model-driven auto-send/close.
--
-- If p_ticket_id is supplied (deterministically derived), the draft is attached
-- to that ticket and it is moved to pending_review. Otherwise a fresh
-- pending_review ticket is created. Status writes happen here (definer), never
-- via a client PATCH (I-1/I-2).
-- =============================================================================
create or replace function queue_supplier_reply_review(
  p_ticket_id     uuid,
  p_supplier_id   uuid,
  p_from_email    text,
  p_subject       text,
  p_draft_subject text,
  p_draft_body    text,
  p_reasoning     text,
  p_urgency       text
) returns uuid
language plpgsql
security definer
as $$
declare
  v_id        uuid;
  v_notes     text;
  v_ref       text;
begin
  v_notes := 'Supplier reply needs review (urgency: ' || coalesce(p_urgency,'low') || ').'
    || E'\n\nFrom: ' || coalesce(p_from_email,'?')
    || E'\nInbound subject: ' || coalesce(p_subject,'?')
    || E'\n\nAgent reasoning: ' || coalesce(p_reasoning,'')
    || E'\n\n--- DRAFT REPLY (review before sending) ---'
    || E'\nSubject: ' || coalesce(p_draft_subject,'')
    || E'\n' || coalesce(p_draft_body,'');

  if p_ticket_id is not null then
    update tickets
    set status      = 'pending_review',
        review_type = coalesce(review_type, 'compliance_flag'),
        review_notes = v_notes,
        updated_at  = now()
    where id = p_ticket_id
    returning id into v_id;
    if v_id is not null then
      return v_id;
    end if;
    -- fall through to create if the id did not match a row
  end if;

  v_ref := 'TS-' || extract(year from current_date)::text || '-REPLY-'
           || substr(replace(uuid_generate_v4()::text,'-',''), 1, 6);

  insert into tickets (reference, source, status, title, description,
                       supplier_id, review_type, review_notes)
  values (v_ref, 'monitoring', 'pending_review',
          'Supplier reply: ' || left(coalesce(p_subject,'(no subject)'), 120),
          'Inbound supplier reply routed for human review.',
          p_supplier_id, 'compliance_flag', v_notes)
  returning id into v_id;

  return v_id;
end $$;

grant execute on function
  queue_supplier_reply_review(uuid, uuid, text, text, text, text, text, text)
to truespend_app;

commit;

-- migrate:down transaction:false
-- Irreversible / forward-only migration. Roll forward with a new migration
-- per invariant I-8; no automated down path.
select 1;

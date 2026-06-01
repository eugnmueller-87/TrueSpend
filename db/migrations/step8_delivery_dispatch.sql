-- ============================================================================
-- step8_delivery_dispatch.sql
-- ----------------------------------------------------------------------------
-- Extend the dispatch_queue outbox (Task 2) to the delivery path.
--
-- Same stability gap as approve/reject: confirm_delivery writes po.status in
-- the DB, but the downstream automation (3-way invoice match, late-delivery
-- ticket, supplier health) was fired by a browser fire-and-forget n8n webhook.
-- If n8n is down, delivery is recorded but the automation silently never runs.
--
-- Fix: confirm_delivery enqueues a durable 'delivered' event in the same
-- transaction. The drainer (scripts/drain_dispatch.js / dispatch_drain.json)
-- delivers it with retry + dead-letter, identical to approved/rejected.
--
-- Idempotent. CREATE OR REPLACE; CHECK constraint swap is safe to re-run.
-- ============================================================================

-- ── 1. Widen the event_type CHECK to allow 'delivered' ───────────────────────
ALTER TABLE dispatch_queue DROP CONSTRAINT IF EXISTS dispatch_queue_event_type_chk;
ALTER TABLE dispatch_queue ADD  CONSTRAINT dispatch_queue_event_type_chk
  CHECK (event_type IN ('approved','rejected','closed','delivered'));

-- ── 2. confirm_delivery — re-create with durable enqueue appended ────────────
CREATE OR REPLACE FUNCTION public.confirm_delivery(p_po_id uuid, p_confirmed_by text)
 RETURNS purchase_orders
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare v_po purchase_orders; v_late boolean;
begin
  select * into v_po from purchase_orders where id = p_po_id for update;
  if not found then raise exception 'PO not found: %', p_po_id; end if;
  v_late := v_po.expected_delivery is not null and current_date > v_po.expected_delivery;
  update purchase_orders set status = 'delivered', delivered_at = now(),
    notes = coalesce(notes,'') || case when v_late
      then ' [LATE: delivered ' || (current_date - v_po.expected_delivery)::text || ' days after SLA]'
      else '' end,
    updated_at = now()
  where id = p_po_id returning * into v_po;
  if v_late then
    update suppliers set health = case when health = 'green' then 'watch'::supplier_health else health end,
      updated_at = now()
    where id = v_po.supplier_id;
  end if;

  -- ── Durable dispatch (NEW — Task 2 extension) ──────────────────────────────
  -- Best-effort: never fail a recorded delivery because queueing hiccupped.
  begin
    perform enqueue_dispatch(
      v_po.ticket_id,
      'delivered',
      jsonb_build_object(
        'po_id',        v_po.id,
        'po_number',    v_po.po_number,
        'ticket_id',    v_po.ticket_id,
        'supplier_id',  v_po.supplier_id,
        'branch_id',    v_po.branch_id,
        'is_late',      v_late,
        'confirmed_by', p_confirmed_by,
        'delivered_at', now()
      )
    );
  exception
    when others then
      raise warning 'enqueue_dispatch(delivered) failed for po %: %', v_po.id, sqlerrm;
  end;

  return v_po;
end $function$;

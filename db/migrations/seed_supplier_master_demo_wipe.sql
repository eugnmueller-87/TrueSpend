-- =============================================================================
-- seed_supplier_master_demo_wipe.sql
-- Remove ALL demo seed data in one pass, for the real-data swap.
-- Order respects FKs: invoices → POs → contracts → budget rows → suppliers.
-- Suppliers that were ENRICHED (pre-existing rows tagged source='demo') are NOT
-- deleted — only un-tagged — because they are real master rows. The GAP vendors
-- (inserted by this seed) ARE deleted. Gap vendors are identified by the d5… id.
-- =============================================================================
begin;

delete from invoices         where source='demo';
delete from purchase_orders  where source='demo';
delete from contracts        where source='demo';
delete from budget_positions where source='demo';

-- gap vendors (inserted rows) — delete outright
delete from suppliers where source='demo' and id::text like 'd5000000-%';

-- enriched pre-existing suppliers — keep the row, drop only the demo tag
update suppliers set source = null where source='demo';

commit;

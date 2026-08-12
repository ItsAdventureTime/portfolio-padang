-- Deterministic synthetic demo dataset. Never run this against production.
TRUNCATE users RESTART IDENTITY CASCADE;

SELECT setval('seq_pr_number', 1, false);
SELECT setval('seq_po_number', 1, false);
SELECT setval('seq_fr_number', 1, false);

INSERT INTO users (id, email, full_name, role) VALUES
 ('00000000-0000-0000-0000-000000000001', 'admin.demo@padang.invalid', 'Demo Administrator', 'administrator'),
 ('00000000-0000-0000-0000-000000000002', 'gm.demo@padang.invalid', 'Maria Santos', 'general_manager'),
 ('00000000-0000-0000-0000-000000000003', 'dcs.demo@padang.invalid', 'Ramon Cruz', 'disbursing_check_signing_officer'),
 ('00000000-0000-0000-0000-000000000004', 'pm.demo@padang.invalid', 'John Dela Cruz', 'project_manager'),
 ('00000000-0000-0000-0000-000000000005', 'procurement.demo@padang.invalid', 'Ana Reyes', 'procurement_officer'),
 ('00000000-0000-0000-0000-000000000006', 'fabrication.demo@padang.invalid', 'Leo Garcia', 'fabrication_supervisor'),
 ('00000000-0000-0000-0000-000000000007', 'finance.demo@padang.invalid', 'Nina Flores', 'finance_staff'),
 ('00000000-0000-0000-0000-000000000008', 'billing.demo@padang.invalid', 'Carla Mendoza', 'billing_clerk'),
 ('00000000-0000-0000-0000-000000000009', 'inventory.demo@padang.invalid', 'Paolo Lim', 'inventory_clerk'),
 ('00000000-0000-0000-0000-000000000010', 'viewer.demo@padang.invalid', 'Demo Viewer', 'viewer');

INSERT INTO clients (id, client_code, name, contact_name, email, phone, address, tin, ewt_enabled, ewt_rate, created_by, updated_by) VALUES
 ('10000000-0000-0000-0000-000000000001', 'ABC-HOLD', 'ABC Holdings Inc.', 'Victor Tan', 'victor@example.invalid', '+63 917 000 1001', 'Angeles City, Pampanga', '123-456-789-000', true, 2.0000, '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001'),
 ('10000000-0000-0000-0000-000000000002', 'PAD-PROP', 'Padang Properties', 'Liza Padilla', 'liza@example.invalid', '+63 917 000 1002', 'San Fernando, Pampanga', '123-456-789-001', false, 0, '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001'),
 ('10000000-0000-0000-0000-000000000003', 'SF-CEO', 'City Engineering Office', 'Engr. Roberto Valdez', 'engineering@example.invalid', '+63 917 000 1003', 'San Fernando, Pampanga', '123-456-789-002', true, 2.0000, '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001');

INSERT INTO projects (id, project_code, project_name, client_id, client_name, contract_type, project_type, contract_amount, start_date, target_end_date, status, project_manager_id, location, description, created_by, updated_by) VALUES
 ('20000000-0000-0000-0000-000000000001', 'ABC-2026', 'ABC Building Construction', '10000000-0000-0000-0000-000000000001', 'ABC Holdings Inc.', 'lump_sum', 'private', 12450000, '2026-01-15', '2026-12-20', 'active', '00000000-0000-0000-0000-000000000004', 'Angeles City', 'Four-storey commercial building and site works.', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001'),
 ('20000000-0000-0000-0000-000000000002', 'SF-WH-2026', 'San Fernando Warehouse', '10000000-0000-0000-0000-000000000002', 'Padang Properties', 'unit_price', 'private', 8200000, '2026-03-01', '2026-11-30', 'active', '00000000-0000-0000-0000-000000000004', 'San Fernando', 'Warehouse structural and MEP package.', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001'),
 ('20000000-0000-0000-0000-000000000003', 'MEX-ROAD-2026', 'Mexico Road Improvement', '10000000-0000-0000-0000-000000000003', 'City Engineering Office', 'lump_sum', 'government', 5780000, '2026-05-10', '2027-02-28', 'planning', '00000000-0000-0000-0000-000000000004', 'Mexico, Pampanga', 'Road drainage and pavement improvement package.', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001');

INSERT INTO project_budget_items (id, project_id, item_code, description, unit, quantity, unit_rate, sort_order, created_by, updated_by) VALUES
 ('21000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'CIV-001', 'Concrete works', 'lot', 1, 4200000, 1, '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001'),
 ('21000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 'STE-001', 'Structural steel package', 'lot', 1, 3100000, 2, '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001'),
 ('21000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', 'MEP-001', 'MEP installation', 'lot', 1, 2150000, 1, '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001');

INSERT INTO project_progress_entries (id, project_id, budget_item_id, entry_date, completion_pct, notes, entered_by) VALUES
 ('22000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '21000000-0000-0000-0000-000000000001', '2026-08-01', 78, 'Concrete structure nearing completion.', '00000000-0000-0000-0000-000000000004'),
 ('22000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', '21000000-0000-0000-0000-000000000002', '2026-08-01', 58, 'Steel delivery and erection in progress.', '00000000-0000-0000-0000-000000000004'),
 ('22000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', '21000000-0000-0000-0000-000000000003', '2026-08-01', 41, 'First fix underway.', '00000000-0000-0000-0000-000000000004');

INSERT INTO project_variation_orders (id, project_id, vo_number, vo_type, description, amount, status, created_by, updated_by) VALUES
 ('23000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'VO-ABC-2026-01', 'addition', 'Additional fire protection riser', 680000, 'gm_approval', '00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000004');

INSERT INTO suppliers (id, supplier_code, name, contact_name, phone, email, address, tin, created_by, updated_by) VALUES
 ('30000000-0000-0000-0000-000000000001', 'SUP-STEEL', 'Pampanga Steel Supply', 'Jose Aquino', '+63 917 000 2001', 'sales@example.invalid', 'San Simon, Pampanga', '234-567-890-000', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001'),
 ('30000000-0000-0000-0000-000000000002', 'SUP-MEP', 'Central Luzon MEP Traders', 'Grace Uy', '+63 917 000 2002', 'orders@example.invalid', 'Angeles City, Pampanga', '234-567-890-001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001');

INSERT INTO inventory_items (id, item_code, description, unit, category, reorder_point, current_qty, avg_unit_cost, created_by, updated_by) VALUES
 ('31000000-0000-0000-0000-000000000001', 'STL-REBAR-16', 'Deformed rebar 16mm', 'length', 'Steel', 500, 1240, 486.50, '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001'),
 ('31000000-0000-0000-0000-000000000002', 'CEM-40', 'Portland cement 40kg', 'bag', 'Concrete', 200, 860, 242.75, '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001'),
 ('31000000-0000-0000-0000-000000000003', 'ELEC-THHN-14', 'THHN wire 14mm', 'roll', 'Electrical', 50, 74, 3250, '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001');

INSERT INTO fabrication_jobs (id, job_number, project_id, client_id, client_name, description, fabrication_type, status, estimated_materials, estimated_labor, estimated_overhead, actual_materials, actual_labor, proposed_price, target_delivery_date, created_by, updated_by) VALUES
 ('40000000-0000-0000-0000-000000000001', 'FAB-2026-010', '20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'ABC Holdings Inc.', 'Canopy steel framing', 'Structural steel', 'in_production', 850000, 240000, 95000, 620000, 170000, 1485000, '2026-09-15', '00000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000006'),
 ('40000000-0000-0000-0000-000000000002', 'FAB-2026-011', NULL, '10000000-0000-0000-0000-000000000002', 'Padang Properties', 'Warehouse rolling doors', 'Metal works', 'estimate', 230000, 95000, 35000, 0, 0, 485000, '2026-10-01', '00000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000006'),
 ('40000000-0000-0000-0000-000000000003', 'FAB-2026-012', NULL, '10000000-0000-0000-0000-000000000003', 'City Engineering Office', 'Guardrail sections', 'Road hardware', 'delivered', 410000, 120000, 50000, 395000, 118000, 720000, '2026-07-30', '00000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000006');

INSERT INTO purchase_requests (id, pr_number, project_id, status, purpose, requested_by, created_by, updated_by) VALUES
 ('50000000-0000-0000-0000-000000000001', 'PR-2026-0001', '20000000-0000-0000-0000-000000000001', 'submitted', 'Steel reinforcement replenishment', '00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000004');
INSERT INTO purchase_request_items (id, pr_id, description, quantity, unit, estimated_unit_cost, inventory_item_id, created_by, updated_by) VALUES
 ('51000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'Deformed rebar 16mm', 800, 'length', 490, '31000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000004');

INSERT INTO purchase_orders (id, po_number, pr_id, supplier_id, delivery_terms, payment_terms, total_amount, status, created_by, updated_by) VALUES
 ('52000000-0000-0000-0000-000000000001', 'PO-2026-0001', '50000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'Delivery to ABC site', '30 days from delivery', 392000, 'gm_approval', '00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000005');
INSERT INTO purchase_order_items (id, po_id, description, quantity, unit, unit_cost, inventory_item_id, created_by, updated_by) VALUES
 ('53000000-0000-0000-0000-000000000001', '52000000-0000-0000-0000-000000000001', 'Deformed rebar 16mm', 800, 'length', 490, '31000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000005');

INSERT INTO fund_requests (id, fr_number, fr_type, po_id, project_id, amount, purpose, status, requested_by, created_by, updated_by) VALUES
 ('54000000-0000-0000-0000-000000000001', 'FR-2026-0001', 'procurement', '52000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 392000, 'Payment for steel reinforcement PO', 'gm_approval', '00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000005'),
 ('54000000-0000-0000-0000-000000000002', 'FR-2026-0002', 'operational', NULL, NULL, 74200, 'Weekly site operating expenses', 'dcs_payment', '00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000002'),
 ('54000000-0000-0000-0000-000000000003', 'FR-2026-0003', 'procurement', NULL, '20000000-0000-0000-0000-000000000002', 128000, 'MEP consumables', 'completed', '00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000005');

INSERT INTO inventory_transactions (id, item_id, transaction_type, quantity, unit_cost, reference_type, reference_id, project_id, created_by) VALUES
 ('55000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', 'stock_in', 1240, 486.50, 'po', '52000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000009'),
 ('55000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000002', 'stock_out', -140, 242.75, 'project', '20000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000009');

INSERT INTO progress_billings (id, billing_number, project_id, billing_date, billing_period_start, billing_period_end, gross_amount, retention_rate, retention_amount, vat_rate, vat_amount, ewt_rate, ewt_amount, net_amount, status, submitted_by, submitted_at, due_date, notes, created_by, updated_by) VALUES
 ('60000000-0000-0000-0000-000000000001', 'PB-ABC-2026-02', '20000000-0000-0000-0000-000000000001', '2026-07-31', '2026-07-01', '2026-07-31', 892000, 10, 89200, 12, 107040, 2, 17840, 892000, 'partial_collected', '00000000-0000-0000-0000-000000000008', '2026-08-01 09:00+08', '2026-08-30', 'Second progress billing; partial payment received.', '00000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000008'),
 ('60000000-0000-0000-0000-000000000002', 'PB-SF-2026-01', '20000000-0000-0000-0000-000000000002', '2026-08-05', '2026-07-01', '2026-07-31', 410000, 10, 41000, 12, 49200, 0, 0, 418200, 'gm_approval', '00000000-0000-0000-0000-000000000008', '2026-08-05 10:00+08', '2026-09-04', 'First progress billing awaiting GM approval.', '00000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000008');
INSERT INTO progress_billing_items (id, billing_id, budget_item_id, description, contract_amount, prev_billed_pct, current_pct, prev_billed_amt, current_amount, created_by, updated_by) VALUES
 ('61000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', '21000000-0000-0000-0000-000000000001', 'Concrete works', 4200000, 45, 21, 1890000, 882000, '00000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000008'),
 ('61000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000001', '21000000-0000-0000-0000-000000000002', 'Structural steel package', 3100000, 30, 32, 930000, 992000, '00000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000008');
INSERT INTO retention_transactions (id, progress_billing_id, transaction_type, amount, reason, recorded_by) VALUES
 ('62000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', 'accrual', 89200, 'PB-ABC-2026-02 retention', '00000000-0000-0000-0000-000000000008');
INSERT INTO collections (id, billing_id, collection_date, amount_collected, payment_mode, or_number, ar_reference, bir_2307_reference, bank_reference, recorded_by) VALUES
 ('63000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', '2026-08-10', 450000, 'bank_transfer', 'OR-2026-0018', 'AR-ABC-2026-08', '2307-ABC-2026-08', 'BDO-TRX-88321', '00000000-0000-0000-0000-000000000007');

INSERT INTO qbo_export_batches (id, export_type, file_name, file_checksum, exported_by, record_count, status) VALUES
 ('70000000-0000-0000-0000-000000000001', 'invoices', 'demo-invoices-2026-07.csv', 'demo-checksum-invoices-2026-07', '00000000-0000-0000-0000-000000000007', 2, 'completed');

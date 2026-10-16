-- Demo data for a migrated OrdreFlow PostgreSQL database.
-- Fixed IDs and ON CONFLICT keep this safe to rerun without overwriting edits.
-- Dates for new time entries are relative to the day this file is first run.
BEGIN;

INSERT INTO users (id, manager_id, name, email, role, status, created_at) VALUES
    ('11111111-1111-4111-8111-111111111111', NULL, 'Alex Admin', 'alex.admin@example.com', 'Admin', 'Active', CURRENT_TIMESTAMP - INTERVAL '30 days'),
    ('6da7cc94-0ea4-4d98-84a8-10d8b5ce2520', NULL, 'Morgan Manager', 'morgan.manager@example.com', 'Manager', 'Active', CURRENT_TIMESTAMP - INTERVAL '28 days'),
    ('22222222-2222-2222-2222-222222222222', NULL, 'Sam Manager', 'sam.manager@example.com', 'Manager', 'Active', CURRENT_TIMESTAMP - INTERVAL '28 days')
ON CONFLICT (id) DO NOTHING;

INSERT INTO users (id, manager_id, name, email, role, status, created_at) VALUES
    ('5e530cd5-924a-445d-84ef-69bfb21ee241', '6da7cc94-0ea4-4d98-84a8-10d8b5ce2520', 'Casey Employee', 'casey.employee@example.com', 'Employee', 'Active', CURRENT_TIMESTAMP - INTERVAL '20 days'),
    ('33333333-3333-4333-8333-333333333333', '6da7cc94-0ea4-4d98-84a8-10d8b5ce2520', 'Jordan Employee', 'jordan.employee@example.com', 'Employee', 'Active', CURRENT_TIMESTAMP - INTERVAL '18 days'),
    ('44444444-4444-4444-8444-444444444444', '22222222-2222-2222-2222-222222222222', 'Taylor Employee', 'taylor.employee@example.com', 'Employee', 'Active', CURRENT_TIMESTAMP - INTERVAL '15 days'),
    ('55555555-5555-4555-8555-555555555555', '6da7cc94-0ea4-4d98-84a8-10d8b5ce2520', 'Robin Inactive', 'robin.inactive@example.com', 'Employee', 'Inactive', CURRENT_TIMESTAMP - INTERVAL '14 days')
ON CONFLICT (id) DO NOTHING;

INSERT INTO orders (id, manager_id, name, status, created_at, closed_at) VALUES
    ('a0000000-0000-4000-8000-000000000001', '6da7cc94-0ea4-4d98-84a8-10d8b5ce2520', 'Website redesign', 'Open', CURRENT_TIMESTAMP - INTERVAL '14 days', NULL),
    ('a0000000-0000-4000-8000-000000000002', '22222222-2222-2222-2222-222222222222', 'Mobile app launch', 'Open', CURRENT_TIMESTAMP - INTERVAL '10 days', NULL),
    ('a0000000-0000-4000-8000-000000000003', '6da7cc94-0ea4-4d98-84a8-10d8b5ce2520', 'Completed discovery', 'Closed', CURRENT_TIMESTAMP - INTERVAL '21 days', CURRENT_TIMESTAMP - INTERVAL '7 days')
ON CONFLICT (id) DO NOTHING;

INSERT INTO tasks (id, order_id, title, description) VALUES
    ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', 'Design landing page', 'Create responsive landing page mockups.'),
    ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000001', 'Implement checkout', 'Build and test the checkout flow.'),
    ('b0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000002', 'Set up notifications', 'Implement push notification preferences.'),
    ('b0000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000003', 'Discovery interviews', 'Document customer interviews and findings.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO time_entries (id, employee_id, task_id, date, hours, comment, status) VALUES
    ('c0000000-0000-4000-8000-000000000001', '5e530cd5-924a-445d-84ef-69bfb21ee241', 'b0000000-0000-4000-8000-000000000001', CURRENT_DATE, 2.50, 'First draft of the landing page', 'Draft'),
    ('c0000000-0000-4000-8000-000000000002', '5e530cd5-924a-445d-84ef-69bfb21ee241', 'b0000000-0000-4000-8000-000000000002', CURRENT_DATE, 3.00, 'Checkout implementation', 'Accepted'),
    ('c0000000-0000-4000-8000-000000000003', '5e530cd5-924a-445d-84ef-69bfb21ee241', 'b0000000-0000-4000-8000-000000000001', CURRENT_DATE, 1.00, 'Needs more detail on the design work', 'Returned'),
    ('c0000000-0000-4000-8000-000000000004', '5e530cd5-924a-445d-84ef-69bfb21ee241', 'b0000000-0000-4000-8000-000000000001', CURRENT_DATE - 7, 4.00, 'Final mockups', 'Finalized'),
    ('c0000000-0000-4000-8000-000000000005', '33333333-3333-4333-8333-333333333333', 'b0000000-0000-4000-8000-000000000002', CURRENT_DATE, 2.00, 'Checkout QA', 'Draft'),
    ('c0000000-0000-4000-8000-000000000006', '44444444-4444-4444-8444-444444444444', 'b0000000-0000-4000-8000-000000000003', CURRENT_DATE, 3.50, 'Notification settings', 'Draft')
ON CONFLICT (id) DO NOTHING;

INSERT INTO time_entry_reviews (id, time_entry_id, decision, reason, reviewed_at) VALUES
    ('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000002', 'Accepted', NULL, CURRENT_TIMESTAMP),
    ('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000003', 'Returned', 'Please describe the design work in more detail.', CURRENT_TIMESTAMP),
    ('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000004', 'Accepted', NULL, CURRENT_TIMESTAMP - INTERVAL '6 days'),
    ('d0000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-000000000004', 'Finalized', NULL, CURRENT_TIMESTAMP - INTERVAL '5 days')
ON CONFLICT (id) DO NOTHING;

COMMIT;

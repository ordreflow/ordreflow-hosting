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

-- md5-derived UUIDs are stable across runs and need no PostgreSQL extensions.
INSERT INTO users (id, manager_id, name, email, role, status, created_at)
SELECT md5('ordreflow:demo:manager:' || n)::uuid, NULL,
       'Demo Manager ' || lpad(n::text, 2, '0'),
       'demo.manager' || lpad(n::text, 2, '0') || '@example.com',
       'Manager', 'Active', CURRENT_TIMESTAMP - INTERVAL '100 days'
FROM generate_series(1, 2) AS managers(n)
ON CONFLICT DO NOTHING;

WITH managers(slot, id) AS (
    VALUES (1, '6da7cc94-0ea4-4d98-84a8-10d8b5ce2520'::uuid),
           (2, '22222222-2222-2222-2222-222222222222'::uuid),
           (3, md5('ordreflow:demo:manager:1')::uuid),
           (4, md5('ordreflow:demo:manager:2')::uuid)
)
INSERT INTO users (id, manager_id, name, email, role, status, created_at)
SELECT md5('ordreflow:demo:employee:' || n)::uuid, managers.id,
       'Demo Employee ' || lpad(n::text, 2, '0'),
       'demo.employee' || lpad(n::text, 2, '0') || '@example.com',
       'Employee', 'Active', CURRENT_TIMESTAMP - INTERVAL '90 days'
FROM generate_series(1, 21) AS employees(n)
JOIN managers ON managers.slot = ((n - 1) % 4) + 1
JOIN users manager ON manager.id = managers.id
ON CONFLICT DO NOTHING;

-- Roles already exist from the AddIdentity migration. Only assign a role to a
-- newly inserted login, so rerunning the seed does not undo account edits.
-- Passwords (Admin/Manager/Employee) are documented in README.md. These are
-- ASP.NET Core Identity V3 password hashes, not PostgreSQL crypt() hashes.
WITH demo_user_ids(id) AS (
    VALUES ('11111111-1111-4111-8111-111111111111'::uuid),
           ('6da7cc94-0ea4-4d98-84a8-10d8b5ce2520'::uuid),
           ('22222222-2222-2222-2222-222222222222'::uuid),
           ('5e530cd5-924a-445d-84ef-69bfb21ee241'::uuid),
           ('33333333-3333-4333-8333-333333333333'::uuid),
           ('44444444-4444-4444-8444-444444444444'::uuid),
           ('55555555-5555-4555-8555-555555555555'::uuid)
    UNION ALL
    SELECT md5('ordreflow:demo:manager:' || n)::uuid
    FROM generate_series(1, 2) AS managers(n)
    UNION ALL
    SELECT md5('ordreflow:demo:employee:' || n)::uuid
    FROM generate_series(1, 21) AS employees(n)
), inserted_accounts AS (
    INSERT INTO "AspNetUsers" (
        "Id", "UserId", "UserName", "NormalizedUserName", "Email", "NormalizedEmail",
        "EmailConfirmed", "PasswordHash", "SecurityStamp", "ConcurrencyStamp",
        "PhoneNumberConfirmed", "TwoFactorEnabled", "LockoutEnabled", "AccessFailedCount"
    )
    SELECT md5('ordreflow:demo:account:' || u.id::text)::uuid, u.id,
           u.email, upper(u.email), u.email, upper(u.email), true,
           CASE u.role
               WHEN 'Admin' THEN 'AQAAAAIAAYagAAAAEK0CtiJlkRzgmHN96R9BYniYk/HK+IUaxMtTYRA1e5J43QL6VNgFN9Y+ylRsSAUUSw=='
               WHEN 'Manager' THEN 'AQAAAAIAAYagAAAAEMQ/kQqf1BkecvA8230QEFPqfixlX8uLodhMVSiPuWBFAxprXmNpBS4r1VoCkZE8/w=='
               WHEN 'Employee' THEN 'AQAAAAIAAYagAAAAEBZeHJo/OwQR8GND+FB9pBvnIc/Ri4zS4VW34rx8f0lDnbeNAZrryAQcnJ/SIxsyvw=='
           END,
           md5('ordreflow:demo:security:' || u.id::text),
           md5('ordreflow:demo:concurrency:' || u.id::text),
           false, false, true, 0
    FROM demo_user_ids ids
    JOIN users u ON u.id = ids.id
    JOIN "AspNetRoles" role ON role."Name" = u.role
    ON CONFLICT DO NOTHING
    RETURNING "Id", "UserId"
)
INSERT INTO "AspNetUserRoles" ("UserId", "RoleId")
SELECT account."Id", role."Id"
FROM inserted_accounts account
JOIN users u ON u.id = account."UserId"
JOIN "AspNetRoles" role ON role."Name" = u.role
ON CONFLICT DO NOTHING;

INSERT INTO orders (id, manager_id, name, status, created_at, closed_at) VALUES
    ('a0000000-0000-4000-8000-000000000001', '6da7cc94-0ea4-4d98-84a8-10d8b5ce2520', 'Website redesign', 'Open', CURRENT_TIMESTAMP - INTERVAL '14 days', NULL),
    ('a0000000-0000-4000-8000-000000000002', '22222222-2222-2222-2222-222222222222', 'Mobile app launch', 'Open', CURRENT_TIMESTAMP - INTERVAL '10 days', NULL),
    ('a0000000-0000-4000-8000-000000000003', '6da7cc94-0ea4-4d98-84a8-10d8b5ce2520', 'Completed discovery', 'Closed', CURRENT_TIMESTAMP - INTERVAL '21 days', CURRENT_TIMESTAMP - INTERVAL '7 days')
ON CONFLICT (id) DO NOTHING;

WITH managers(slot, id) AS (
    VALUES (1, '6da7cc94-0ea4-4d98-84a8-10d8b5ce2520'::uuid),
           (2, '22222222-2222-2222-2222-222222222222'::uuid),
           (3, md5('ordreflow:demo:manager:1')::uuid),
           (4, md5('ordreflow:demo:manager:2')::uuid)
)
INSERT INTO orders (id, manager_id, name, status, created_at, closed_at)
SELECT md5('ordreflow:demo:order:' || n)::uuid, managers.id,
       (ARRAY[
           'Customer portal upgrade', 'Reporting dashboard', 'Data migration',
           'Accessibility improvements', 'Inventory sync', 'Billing integration',
           'Support center', 'Performance audit', 'Onboarding experience'
       ])[n],
       CASE WHEN n IN (5, 6) THEN 'Closed' ELSE 'Open' END,
       greatest(manager.created_at + INTERVAL '3 days',
                CURRENT_TIMESTAMP - ((55 + n * 3) * INTERVAL '1 day')),
       CASE WHEN n IN (5, 6) THEN CURRENT_TIMESTAMP - INTERVAL '5 days' ELSE NULL END
FROM generate_series(1, 9) AS projects(n)
JOIN managers ON managers.slot = ((n - 1) % 4) + 1
JOIN users manager ON manager.id = managers.id
ON CONFLICT DO NOTHING;

INSERT INTO tasks (id, order_id, title, description) VALUES
    ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', 'Design landing page', 'Create responsive landing page mockups.'),
    ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000001', 'Implement checkout', 'Build and test the checkout flow.'),
    ('b0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000002', 'Set up notifications', 'Implement push notification preferences.'),
    ('b0000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000003', 'Discovery interviews', 'Document customer interviews and findings.')
ON CONFLICT (id) DO NOTHING;

WITH demo_orders(slot, id) AS (
    VALUES (1, 'a0000000-0000-4000-8000-000000000001'::uuid),
           (2, 'a0000000-0000-4000-8000-000000000002'::uuid),
           (3, 'a0000000-0000-4000-8000-000000000003'::uuid)
    UNION ALL
    SELECT n + 3, md5('ordreflow:demo:order:' || n)::uuid
    FROM generate_series(1, 9) AS projects(n)
)
INSERT INTO tasks (id, order_id, title, description)
SELECT md5('ordreflow:demo:task:' || n)::uuid, orders.id,
       (ARRAY['Plan', 'Design', 'Implement', 'Review', 'Test'])[((n - 1) % 5) + 1]
           || ' ' || orders.name,
       'Demo work item for ' || orders.name || '.'
FROM generate_series(1, 46) AS items(n)
JOIN demo_orders ids ON ids.slot = ((n - 1) % 12) + 1
JOIN orders ON orders.id = ids.id
ON CONFLICT DO NOTHING;

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

-- Each active demo employee gets ten entries across up to seven weeks.
-- Select tasks on their manager's open orders so they can work with these
-- entries through the API. Dates stay after the employee and order were created.
-- Reviews are added only for newly inserted entries.
WITH demo_employee_ids(id) AS (
    VALUES ('5e530cd5-924a-445d-84ef-69bfb21ee241'::uuid),
           ('33333333-3333-4333-8333-333333333333'::uuid),
           ('44444444-4444-4444-8444-444444444444'::uuid)
    UNION ALL
    SELECT md5('ordreflow:demo:employee:' || n)::uuid
    FROM generate_series(1, 21) AS employees(n)
), work_items AS (
    SELECT tasks.id, orders.manager_id, orders.created_at,
           row_number() OVER (PARTITION BY orders.manager_id ORDER BY tasks.id) AS slot,
           count(*) OVER (PARTITION BY orders.manager_id) AS task_count
    FROM tasks
    JOIN orders ON orders.id = tasks.order_id
    WHERE orders.status = 'Open'
), inserted_entries AS (
    INSERT INTO time_entries (id, employee_id, task_id, date, hours, comment, status)
    SELECT md5('ordreflow:demo:time-entry:' || employee.id::text || ':' || period.n)::uuid,
           employee.id, work_items.id,
           greatest(CURRENT_DATE - ((period.n - 1) * 5 + ascii(left(employee.id::text, 1)) % 3),
                    employee.created_at::date + 2, work_items.created_at::date + 2),
           (1 + (period.n % 7) * 0.5)::numeric(5, 2),
           'Demo work on ' || tasks.title,
           CASE period.n % 4
               WHEN 1 THEN 'Draft'
               WHEN 2 THEN 'Accepted'
               WHEN 3 THEN 'Returned'
               ELSE 'Finalized'
           END
    FROM demo_employee_ids ids
    JOIN users employee ON employee.id = ids.id
                       AND employee.role = 'Employee' AND employee.status = 'Active'
    CROSS JOIN generate_series(1, 10) AS period(n)
    JOIN work_items ON work_items.manager_id = employee.manager_id
                   AND work_items.slot = ((period.n - 1) % work_items.task_count) + 1
    JOIN tasks ON tasks.id = work_items.id
    ON CONFLICT DO NOTHING
    RETURNING id, status, date
)
INSERT INTO time_entry_reviews (id, time_entry_id, decision, reason, reviewed_at)
SELECT md5('ordreflow:demo:review:' || entry.id::text || ':' || review.decision)::uuid,
       entry.id, review.decision, review.reason,
       entry.date::timestamptz + review.day_number * INTERVAL '1 day'
FROM inserted_entries entry
CROSS JOIN (VALUES
    ('Accepted', 1, NULL::text),
    ('Returned', 1, 'Please add more detail to this time entry.'),
    ('Finalized', 2, NULL::text)
) AS review(decision, day_number, reason)
WHERE entry.status = review.decision
   OR (entry.status = 'Finalized' AND review.decision = 'Accepted')
ON CONFLICT DO NOTHING;

COMMIT;

-- Demo data for the current employee/department time-registration model.
-- Fixed IDs and ON CONFLICT keep this safe to rerun without overwriting edits.
BEGIN;

DO $$
BEGIN
    IF to_regclass('employees') IS NULL OR to_regclass('time_entry_audits') IS NULL
       OR NOT EXISTS (SELECT 1 FROM information_schema.columns
                      WHERE table_schema = current_schema() AND table_name = 'tasks' AND column_name = 'kind')
       OR NOT EXISTS (SELECT 1 FROM information_schema.columns
                      WHERE table_schema = current_schema() AND table_name = 'tasks' AND column_name = 'assignment_only') THEN
        RAISE EXCEPTION 'Demo seed requires the current backend migration (including task kind and assignment_only)';
    END IF;
END $$;

-- Only newly created demo employees receive seed permissions. Rerunning the
-- seed must not grant access to unrelated employees or undo revoked access.
CREATE TEMP TABLE demo_employee_ids ON COMMIT DROP AS
SELECT demo.id FROM (
    VALUES ('11111111-1111-4111-8111-111111111111'::uuid),
           ('6da7cc94-0ea4-4d98-84a8-10d8b5ce2520'::uuid),
           ('22222222-2222-2222-2222-222222222222'::uuid),
           ('5e530cd5-924a-445d-84ef-69bfb21ee241'::uuid),
           ('33333333-3333-4333-8333-333333333333'::uuid),
           ('44444444-4444-4444-8444-444444444444'::uuid),
           ('55555555-5555-4555-8555-555555555555'::uuid)
    UNION ALL
    SELECT md5('ordreflow:demo:manager:' || n)::uuid FROM generate_series(1, 2) AS managers(n)
    UNION ALL
    SELECT md5('ordreflow:demo:employee:' || n)::uuid FROM generate_series(1, 21) AS employees(n)
) AS demo(id);

CREATE TEMP TABLE demo_new_employees ON COMMIT DROP AS
SELECT demo.id FROM demo_employee_ids demo
WHERE NOT EXISTS (SELECT 1 FROM employees WHERE employees.id = demo.id);

INSERT INTO employees (id, name, email, status, title, created_at) VALUES
    ('11111111-1111-4111-8111-111111111111', 'Alex Admin', 'alex.admin@example.com', 'Active', NULL, CURRENT_TIMESTAMP - INTERVAL '30 days'),
    ('6da7cc94-0ea4-4d98-84a8-10d8b5ce2520', 'Morgan Manager', 'morgan.manager@example.com', 'Active', NULL, CURRENT_TIMESTAMP - INTERVAL '28 days'),
    ('22222222-2222-2222-2222-222222222222', 'Sam Manager', 'sam.manager@example.com', 'Active', NULL, CURRENT_TIMESTAMP - INTERVAL '28 days'),
    ('5e530cd5-924a-445d-84ef-69bfb21ee241', 'Casey Employee', 'casey.employee@example.com', 'Active', NULL, CURRENT_TIMESTAMP - INTERVAL '20 days'),
    ('33333333-3333-4333-8333-333333333333', 'Jordan Employee', 'jordan.employee@example.com', 'Active', NULL, CURRENT_TIMESTAMP - INTERVAL '18 days'),
    ('44444444-4444-4444-8444-444444444444', 'Taylor Employee', 'taylor.employee@example.com', 'Active', NULL, CURRENT_TIMESTAMP - INTERVAL '15 days'),
    ('55555555-5555-4555-8555-555555555555', 'Robin Inactive', 'robin.inactive@example.com', 'Deactivated', NULL, CURRENT_TIMESTAMP - INTERVAL '14 days')
ON CONFLICT (id) DO NOTHING;

INSERT INTO employees (id, name, email, status, title, created_at)
SELECT md5('ordreflow:demo:manager:' || n)::uuid,
       'Demo Manager ' || lpad(n::text, 2, '0'),
       'demo.manager' || lpad(n::text, 2, '0') || '@example.com',
       'Active', NULL, CURRENT_TIMESTAMP - INTERVAL '100 days'
FROM generate_series(1, 2) AS managers(n)
ON CONFLICT (id) DO NOTHING;

INSERT INTO employees (id, name, email, status, title, created_at)
SELECT md5('ordreflow:demo:employee:' || n)::uuid,
       'Demo Employee ' || lpad(n::text, 2, '0'),
       'demo.employee' || lpad(n::text, 2, '0') || '@example.com',
       'Active', NULL, CURRENT_TIMESTAMP - INTERVAL '90 days'
FROM generate_series(1, 21) AS employees(n)
ON CONFLICT (id) DO NOTHING;

INSERT INTO employee_system_accesses (employee_id, permission)
SELECT id, 'Employee'
FROM demo_new_employees
ON CONFLICT DO NOTHING;

INSERT INTO employee_system_accesses (employee_id, permission)
SELECT demo.id, access.permission
FROM demo_new_employees demo
JOIN (VALUES
    ('11111111-1111-4111-8111-111111111111'::uuid, 'Administrator'),
    ('11111111-1111-4111-8111-111111111111'::uuid, 'Payroll'),
    ('6da7cc94-0ea4-4d98-84a8-10d8b5ce2520'::uuid, 'DepartmentManager'),
    ('6da7cc94-0ea4-4d98-84a8-10d8b5ce2520'::uuid, 'CatagoryReviewer'),
    ('22222222-2222-2222-2222-222222222222'::uuid, 'DepartmentManager'),
    ('22222222-2222-2222-2222-222222222222'::uuid, 'CatagoryReviewer')
) AS access(id, permission) ON access.id = demo.id
ON CONFLICT DO NOTHING;

INSERT INTO employee_system_accesses (employee_id, permission)
SELECT demo.id, permissions.permission
FROM generate_series(1, 2) AS managers(n)
JOIN demo_new_employees demo ON demo.id = md5('ordreflow:demo:manager:' || n)::uuid
CROSS JOIN (VALUES ('DepartmentManager'), ('CatagoryReviewer')) AS permissions(permission)
ON CONFLICT DO NOTHING;

INSERT INTO "AspNetUsers" (
    "Id", "EmployeeId", "UserName", "NormalizedUserName", "Email", "NormalizedEmail",
    "EmailConfirmed", "PasswordHash", "SecurityStamp", "ConcurrencyStamp",
    "PhoneNumberConfirmed", "TwoFactorEnabled", "LockoutEnabled", "AccessFailedCount"
)
SELECT md5('ordreflow:demo:account:' || employee.id::text)::uuid,
       employee.id, employee.email, upper(employee.email), employee.email, upper(employee.email),
       true,
       CASE
           WHEN employee.email = 'alex.admin@example.com' THEN 'AQAAAAIAAYagAAAAEK0CtiJlkRzgmHN96R9BYniYk/HK+IUaxMtTYRA1e5J43QL6VNgFN9Y+ylRsSAUUSw=='
           WHEN employee.email LIKE '%.manager%@example.com' OR employee.email IN ('morgan.manager@example.com', 'sam.manager@example.com')
               THEN 'AQAAAAIAAYagAAAAEMQ/kQqf1BkecvA8230QEFPqfixlX8uLodhMVSiPuWBFAxprXmNpBS4r1VoCkZE8/w=='
           ELSE 'AQAAAAIAAYagAAAAEBZeHJo/OwQR8GND+FB9pBvnIc/Ri4zS4VW34rx8f0lDnbeNAZrryAQcnJ/SIxsyvw=='
       END,
       md5('ordreflow:demo:security:' || employee.id::text),
       md5('ordreflow:demo:concurrency:' || employee.id::text),
       false, false, true, 0
FROM demo_employee_ids demo
JOIN employees employee ON employee.id = demo.id
ON CONFLICT DO NOTHING;

WITH managers(slot, id) AS (
    VALUES (1, '6da7cc94-0ea4-4d98-84a8-10d8b5ce2520'::uuid),
           (2, '22222222-2222-2222-2222-222222222222'::uuid),
           (3, md5('ordreflow:demo:manager:1')::uuid),
           (4, md5('ordreflow:demo:manager:2')::uuid)
)
INSERT INTO departments (id, name)
SELECT md5('ordreflow:demo:department:' || slot)::uuid,
       'Demo Department ' || slot
FROM managers
ON CONFLICT (id) DO NOTHING;

WITH managers(slot, id) AS (
    VALUES (1, '6da7cc94-0ea4-4d98-84a8-10d8b5ce2520'::uuid),
           (2, '22222222-2222-2222-2222-222222222222'::uuid),
           (3, md5('ordreflow:demo:manager:1')::uuid),
           (4, md5('ordreflow:demo:manager:2')::uuid)
)
INSERT INTO department_managers (department_id, manager_id)
SELECT md5('ordreflow:demo:department:' || slot)::uuid, id
FROM managers
ON CONFLICT DO NOTHING;

WITH membership(employee_id, slot) AS (
    VALUES ('6da7cc94-0ea4-4d98-84a8-10d8b5ce2520'::uuid, 1),
           ('22222222-2222-2222-2222-222222222222'::uuid, 2),
           ('5e530cd5-924a-445d-84ef-69bfb21ee241'::uuid, 1),
           ('33333333-3333-4333-8333-333333333333'::uuid, 1),
           ('44444444-4444-4444-8444-444444444444'::uuid, 2)
    UNION ALL
    SELECT md5('ordreflow:demo:manager:' || slot)::uuid, slot + 2
    FROM generate_series(1, 2) AS managers(slot)
    UNION ALL
    SELECT md5('ordreflow:demo:employee:' || n)::uuid, ((n - 1) % 4) + 1
    FROM generate_series(1, 21) AS employees(n)
)
INSERT INTO department_employees (department_id, employee_id)
SELECT md5('ordreflow:demo:department:' || slot)::uuid, employee_id
FROM membership
ON CONFLICT DO NOTHING;

WITH managers(slot, id) AS (
    VALUES (1, '6da7cc94-0ea4-4d98-84a8-10d8b5ce2520'::uuid),
           (2, '22222222-2222-2222-2222-222222222222'::uuid),
           (3, md5('ordreflow:demo:manager:1')::uuid),
           (4, md5('ordreflow:demo:manager:2')::uuid)
)
INSERT INTO catagories (
    id, created_by, department_id, name, description, status, internal_only, created_at, closed_at
)
SELECT md5('ordreflow:demo:category:' || slot)::uuid, managers.id,
       md5('ordreflow:demo:department:' || slot)::uuid,
       'General work', 'Shared demo work items', 'Active', false,
       greatest(manager.created_at + INTERVAL '1 day', CURRENT_TIMESTAMP - INTERVAL '80 days'), NULL
FROM managers
JOIN employees manager ON manager.id = managers.id
ON CONFLICT (id) DO NOTHING;

WITH managers(slot, id) AS (
    VALUES (1, '6da7cc94-0ea4-4d98-84a8-10d8b5ce2520'::uuid),
           (2, '22222222-2222-2222-2222-222222222222'::uuid),
           (3, md5('ordreflow:demo:manager:1')::uuid),
           (4, md5('ordreflow:demo:manager:2')::uuid)
)
INSERT INTO catagory_reviewers (employee_id, catagory_id)
SELECT id, md5('ordreflow:demo:category:' || slot)::uuid
FROM managers
ON CONFLICT DO NOTHING;

INSERT INTO tasks (id, catagory_id, name, description, kind, assignment_only, status, created_at, closed_at)
SELECT md5('ordreflow:demo:task:' || n)::uuid,
       category.id,
       (ARRAY[
           'Plan work', 'Prepare design', 'Implement feature', 'Review changes',
           'Test release', 'Update documentation'
       ])[((n - 1) % 6) + 1],
       'Demo work item ' || n,
       (ARRAY['Task', 'Project', 'Ticket'])[((n - 1) % 3) + 1],
       false, 'Active', greatest(category.created_at + INTERVAL '1 day', CURRENT_TIMESTAMP - INTERVAL '60 days'), NULL
FROM generate_series(1, 12) AS work_items(n)
JOIN catagories category ON category.id = md5('ordreflow:demo:category:' || ((n - 1) / 3 + 1))::uuid
ON CONFLICT (id) DO NOTHING;

WITH membership(employee_id, slot) AS (
    VALUES ('5e530cd5-924a-445d-84ef-69bfb21ee241'::uuid, 1),
           ('33333333-3333-4333-8333-333333333333'::uuid, 1),
           ('44444444-4444-4444-8444-444444444444'::uuid, 2)
    UNION ALL
    SELECT md5('ordreflow:demo:employee:' || n)::uuid, ((n - 1) % 4) + 1
    FROM generate_series(1, 21) AS employees(n)
), managers(slot, reviewer_id) AS (
    VALUES (1, '6da7cc94-0ea4-4d98-84a8-10d8b5ce2520'::uuid),
           (2, '22222222-2222-2222-2222-222222222222'::uuid),
           (3, md5('ordreflow:demo:manager:1')::uuid),
           (4, md5('ordreflow:demo:manager:2')::uuid)
), entry_rows AS (
    SELECT membership.employee_id, membership.slot, managers.reviewer_id
    FROM membership
    JOIN managers USING (slot)
), entries AS (
    INSERT INTO time_entries (id, revision, employee_id)
    SELECT md5('ordreflow:demo:time-entry:' || entry.employee_id::text || ':' || sample.number)::uuid,
           CASE WHEN sample.number = 1 THEN 1 ELSE 2 END, entry.employee_id
    FROM entry_rows entry
    CROSS JOIN generate_series(1, 3) AS sample(number)
    ON CONFLICT (id) DO NOTHING
    RETURNING id, employee_id
), initial_audits AS (
    INSERT INTO time_entry_audits (
        id, time_entry_id, actor_id, closed_by, task_id, work_date, duration, description, status, audit_time
    )
    SELECT md5('ordreflow:demo:audit:initial:' || time_entry.id::text)::uuid,
           time_entry.id, entry.employee_id, NULL,
           md5('ordreflow:demo:task:' || (((entry.slot - 1) * 3) + sample.number))::uuid,
           CURRENT_DATE - ((sample.number - 1) * 3),
           2.50, 'Demo time entry', 'ReadyForApproval', CURRENT_TIMESTAMP - INTERVAL '1 hour'
    FROM entry_rows entry
    CROSS JOIN generate_series(1, 3) AS sample(number)
    JOIN entries time_entry
      ON time_entry.employee_id = entry.employee_id
     AND time_entry.id = md5('ordreflow:demo:time-entry:' || entry.employee_id::text || ':' || sample.number)::uuid
    RETURNING time_entry_id
), decision_audits AS (
    INSERT INTO time_entry_audits (
        id, time_entry_id, actor_id, closed_by, task_id, work_date, duration, description, status, audit_time
    )
    SELECT md5('ordreflow:demo:audit:decision:' || time_entry.time_entry_id::text)::uuid,
           time_entry.time_entry_id, entry.reviewer_id, NULL,
           md5('ordreflow:demo:task:' || (((entry.slot - 1) * 3) + sample.number))::uuid,
           CURRENT_DATE - ((sample.number - 1) * 3),
           2.50, 'Demo time entry',
           CASE sample.number WHEN 2 THEN 'Rejected' ELSE 'Approved' END,
           CURRENT_TIMESTAMP - INTERVAL '30 minutes'
    FROM entry_rows entry
    CROSS JOIN generate_series(2, 3) AS sample(number)
    JOIN initial_audits time_entry
      ON time_entry.time_entry_id = md5('ordreflow:demo:time-entry:' || entry.employee_id::text || ':' || sample.number)::uuid
    RETURNING time_entry_id, actor_id, status, audit_time
)
INSERT INTO time_entry_reviews (id, time_entry_id, reviewer_id, description, status, reviewed_at_utc)
SELECT md5('ordreflow:demo:review:' || audit.time_entry_id::text)::uuid,
       audit.time_entry_id, audit.actor_id,
       CASE WHEN audit.status = 'Rejected' THEN 'Please add more detail to this entry.' END,
       audit.status, audit.audit_time
FROM decision_audits audit;

WITH membership(employee_id, slot) AS (
    VALUES ('5e530cd5-924a-445d-84ef-69bfb21ee241'::uuid, 1),
           ('33333333-3333-4333-8333-333333333333'::uuid, 1),
           ('44444444-4444-4444-8444-444444444444'::uuid, 2)
    UNION ALL
    SELECT md5('ordreflow:demo:employee:' || n)::uuid, ((n - 1) % 4) + 1
    FROM generate_series(1, 21) AS employees(n)
)
INSERT INTO task_assinments (task_id, assigned_to, expected_duration, expected_deadline)
SELECT md5('ordreflow:demo:task:' || (((membership.slot - 1) * 3) + sample.number))::uuid,
       membership.employee_id, 8, CURRENT_DATE + 30
FROM membership
CROSS JOIN generate_series(1, 3) AS sample(number)
ON CONFLICT DO NOTHING;

INSERT INTO registration_period_modes (id, admin_id, interval, day_in_month, created_date)
VALUES (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    '11111111-1111-4111-8111-111111111111',
    'Weekly',
    NULL,
    CURRENT_TIMESTAMP
)
ON CONFLICT (id) DO NOTHING;

COMMIT;

-- Demo data for the current employee/department time-registration model.
-- Fixed IDs and ON CONFLICT keep this safe to rerun without overwriting edits.
BEGIN;

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
FROM employees
WHERE id <> '11111111-1111-4111-8111-111111111111'
ON CONFLICT DO NOTHING;

INSERT INTO employee_system_accesses (employee_id, permission) VALUES
    ('11111111-1111-4111-8111-111111111111', 'Employee'),
    ('11111111-1111-4111-8111-111111111111', 'Administrator'),
    ('11111111-1111-4111-8111-111111111111', 'Payroll'),
    ('6da7cc94-0ea4-4d98-84a8-10d8b5ce2520', 'DepartmentManager'),
    ('6da7cc94-0ea4-4d98-84a8-10d8b5ce2520', 'CatagoryReviewer'),
    ('22222222-2222-2222-2222-222222222222', 'DepartmentManager'),
    ('22222222-2222-2222-2222-222222222222', 'CatagoryReviewer')
ON CONFLICT DO NOTHING;

INSERT INTO employee_system_accesses (employee_id, permission)
SELECT md5('ordreflow:demo:manager:' || n)::uuid, permission
FROM generate_series(1, 2) AS managers(n)
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
FROM employees employee
WHERE employee.email IN (
    'alex.admin@example.com', 'morgan.manager@example.com', 'sam.manager@example.com',
    'casey.employee@example.com', 'jordan.employee@example.com', 'taylor.employee@example.com',
    'robin.inactive@example.com'
)
   OR employee.email LIKE 'demo.manager%@example.com'
   OR employee.email LIKE 'demo.employee%@example.com'
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
SELECT md5('ordreflow:demo:category:' || slot)::uuid, id,
       md5('ordreflow:demo:department:' || slot)::uuid,
       'General work', 'Shared demo work items', 'Active', false,
       CURRENT_TIMESTAMP - INTERVAL '80 days', NULL
FROM managers
ON CONFLICT (id) DO NOTHING;

WITH managers(slot, id) AS (
    VALUES (1, '6da7cc94-0ea4-4d98-84a8-10d8b5ce2520'::uuid),
           (2, '22222222-2222-2222-2222-2222222

22222'::uuid),
           (3, md5('ordreflow:demo:manager:1')::uuid),
           (4, md5('ordreflow:demo:manager:2')::uuid)
)
INSERT INTO catagory_reviewers (employee_id, catagory_id)
SELECT id, md5('ordreflow:demo:category:' || slot)::uuid
FROM managers
ON CONFLICT DO NOTHING;

INSERT INTO tasks (id, catagory_id, name, description, kind, assignment_only, status, created_at, closed_at)
SELECT md5('ordreflow:demo:task:' || n)::uuid,
       md5('ordreflow:demo:category:' || (((n - 1) % 4) + 1))::uuid,
       (ARRAY[
           'Plan work', 'Prepare design', 'Implement feature', 'Review changes',
           'Test release', 'Update documentation'
       ])[((n - 1) % 6) + 1],
       'Demo work item ' || n,
       (ARRAY['Task', 'Project', 'Ticket'])[((n - 1) % 3) + 1],
       false, 'Active', CURRENT_TIMESTAMP - INTERVAL '60 days', NULL
FROM generate_series(1, 12) AS work_items(n)
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
           1, entry.employee_id
    FROM entry_rows entry
    CROSS JOIN generate_series(1, 3) AS sample(number)
    ON CONFLICT (id) DO NOTHING
    RETURNING id, employee_id
), entry_audits AS (
    INSERT INTO time_entry_audits (
        id, time_entry_id, actor_id, closed_by, task_id, work_date, duration, description, status, audit_time
    )
    SELECT md5('ordreflow:demo:audit:' || time_entry.id::text)::uuid,
           time_entry.id,
           CASE sample.number WHEN 3 THEN entry.reviewer_id ELSE entry.employee_id END,
           NULL,
           md5('ordreflow:demo:task:' || (((entry.slot - 1) * 3) + sample.number))::uuid,
           CURRENT_DATE - ((sample.number - 1) * 3),
           2.50, 'Demo time entry',
           CASE sample.number
               WHEN 1 THEN 'Draft'
               WHEN 2 THEN 'ReadyForApproval'
               WHEN 3 THEN CASE
                   WHEN right(entry.employee_id::text, 1) IN ('1', '3', '5', '7', '9', 'b', 'd', 'f')
                       THEN 'Rejected'
                   ELSE 'Approved'
               END
           END,
           CURRENT_TIMESTAMP - INTERVAL '1 hour'
    FROM entry_rows entry
    CROSS JOIN generate_series(1, 3) AS sample(number)
    JOIN entries time_entry
      ON time_entry.employee_id = entry.employee_id
     AND time_entry.id = md5('ordreflow:demo:time-entry:' || entry.employee_id::text || ':' || sample.number)::uuid
    ON CONFLICT (id) DO NOTHING
    RETURNING time_entry_id, actor_id, task_id, status, audit_time
)
INSERT INTO task_assinments (task_id, assigned_to, expected_duration, expected_deadline)
SELECT DISTINCT
       md5('ordreflow:demo:task:' || (((membership.slot - 1) * 3) + sample.number))::uuid,
       membership.employee_id, 8, CURRENT_DATE + 30
FROM membership
CROSS JOIN generate_series(1, 3) AS sample(number)
ON CONFLICT DO NOTHING;

WITH memberships(employee_id, slot) AS (
    VALUES ('5e530cd5-924a-445d-84ef-69bfb21ee241'::uuid, 1),
           ('33333333-3333-4333-8333-333333333333'::uuid, 1),
           ('44444444-4444-4444-8444-444444444444'::uuid, 2)
    UNION ALL
    SELECT md5('ordreflow:demo:employee:' || n)::uuid, ((n - 1) % 4) + 1
    FROM generate_series(1, 21) AS employees(n)
), reviewers(slot, reviewer_id) AS (
    VALUES (1, '6da7cc94-0ea4-4d98-84a8-10d8b5ce2520'::uuid),
           (2, '22222222-2222-2222-2222-222222222222'::uuid),
           (3, md5('ordreflow:demo:manager:1')::uuid),
           (4, md5('ordreflow:demo:manager:2')::uuid)
)
INSERT INTO time_entry_reviews (id, time_entry_id, reviewer_id, description, status, reviewed_at_utc)
SELECT md5('ordreflow:demo:review:' || time_entry.id::text)::uuid,
       time_entry.id, reviewers.reviewer_id,
       CASE audit.status WHEN 'Rejected' THEN 'Please add more detail to this entry.' ELSE NULL END,
       audit.status, audit.audit_time + INTERVAL '30 minutes'
FROM time_entry_audits audit
JOIN time_entries time_entry ON time_entry.id = audit.time_entry_id
JOIN memberships ON memberships.employee_id = time_entry.employee_id
JOIN reviewers USING (slot)
WHERE audit.status IN ('Approved', 'Rejected')
ON CONFLICT (id) DO NOTHING;

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

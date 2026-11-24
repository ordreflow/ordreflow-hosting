-- Demo data for the current Employee / Department / Catagory / TimeEntry model.
-- Requires the backend migration with the current task kind/assignment columns.
-- Stable IDs and ON CONFLICT preserve existing rows and make reruns idempotent.
BEGIN;

DO $$
BEGIN
    IF to_regclass('employees') IS NULL
       OR to_regclass('employee_system_accesses') IS NULL
       OR to_regclass('departments') IS NULL
       OR to_regclass('catagories') IS NULL
       OR to_regclass('time_entry_audits') IS NULL
       OR to_regclass('registration_period_modes') IS NULL THEN
        RAISE EXCEPTION 'The demo seed requires the backend M3 schema; apply its migration first';
    END IF;
END $$;

-- The manager/department relationship is seed-only: the domain represents it
-- with department_managers and department_employees, not an employee.manager_id.
CREATE TEMP TABLE demo_people (
    id uuid PRIMARY KEY,
    name text NOT NULL,
    email text NOT NULL,
    title text NOT NULL,
    status text NOT NULL,
    department_slot integer,
    created_at timestamptz NOT NULL
) ON COMMIT DROP;

INSERT INTO demo_people VALUES
    ('11111111-1111-4111-8111-111111111111', 'Alex Admin', 'alex.admin@example.com', 'Administrator', 'Active', NULL, CURRENT_TIMESTAMP - INTERVAL '100 days'),
    ('6da7cc94-0ea4-4d98-84a8-10d8b5ce2520', 'Morgan Manager', 'morgan.manager@example.com', 'Manager', 'Active', 1, CURRENT_TIMESTAMP - INTERVAL '90 days'),
    ('22222222-2222-2222-2222-222222222222', 'Sam Manager', 'sam.manager@example.com', 'Manager', 'Active', 2, CURRENT_TIMESTAMP - INTERVAL '90 days'),
    ('5e530cd5-924a-445d-84ef-69bfb21ee241', 'Casey Employee', 'casey.employee@example.com', 'Employee', 'Active', 1, CURRENT_TIMESTAMP - INTERVAL '80 days'),
    ('33333333-3333-4333-8333-333333333333', 'Jordan Employee', 'jordan.employee@example.com', 'Employee', 'Active', 1, CURRENT_TIMESTAMP - INTERVAL '80 days'),
    ('44444444-4444-4444-8444-444444444444', 'Taylor Employee', 'taylor.employee@example.com', 'Employee', 'Active', 2, CURRENT_TIMESTAMP - INTERVAL '80 days'),
    ('55555555-5555-4555-8555-555555555555', 'Robin Inactive', 'robin.inactive@example.com', 'Employee', 'Deactivated', 1, CURRENT_TIMESTAMP - INTERVAL '80 days');

INSERT INTO demo_people
SELECT md5('ordreflow:demo:manager:' || n)::uuid,
       'Demo Manager ' || lpad(n::text, 2, '0'),
       'demo.manager' || lpad(n::text, 2, '0') || '@example.com',
       'Manager', 'Active', n, CURRENT_TIMESTAMP - INTERVAL '100 days'
FROM generate_series(1, 2) AS managers(n);

INSERT INTO demo_people
SELECT md5('ordreflow:demo:employee:' || n)::uuid,
       'Demo Employee ' || lpad(n::text, 2, '0'),
       'demo.employee' || lpad(n::text, 2, '0') || '@example.com',
       'Employee', 'Active', CASE WHEN (n - 1) % 4 IN (0, 2) THEN 1 ELSE 2 END,
       CURRENT_TIMESTAMP - INTERVAL '90 days'
FROM generate_series(1, 21) AS employees(n);

-- Employee.Create grants baseline Employee access. Seed additional permissions
-- only for new employees so reruns do not restore a deliberately revoked grant.
WITH inserted AS (
    INSERT INTO employees (id, name, email, status, title, created_at)
    SELECT id, name, email, status, title, created_at FROM demo_people WHERE true
    ON CONFLICT (id) DO NOTHING
    RETURNING id
)
INSERT INTO employee_system_accesses (employee_id, permission)
SELECT id, 'Employee' FROM inserted
UNION ALL
SELECT inserted.id, 'Administrator' FROM inserted JOIN demo_people p USING (id) WHERE p.title = 'Administrator'
UNION ALL
SELECT inserted.id, 'Payroll' FROM inserted JOIN demo_people p USING (id) WHERE p.title = 'Administrator'
UNION ALL
SELECT inserted.id, 'DepartmentManager' FROM inserted JOIN demo_people p USING (id) WHERE p.title = 'Manager'
UNION ALL
SELECT inserted.id, 'CatagoryReviewer' FROM inserted JOIN demo_people p USING (id) WHERE p.title = 'Manager'
ON CONFLICT DO NOTHING;

-- IdentityUserContext uses AspNetUsers.EmployeeId and has no Identity roles.
-- Keep the original ASP.NET Core Identity V3 demo password hashes.
INSERT INTO "AspNetUsers" (
    "Id", "EmployeeId", "UserName", "NormalizedUserName", "Email", "NormalizedEmail",
    "EmailConfirmed", "PasswordHash", "SecurityStamp", "ConcurrencyStamp",
    "PhoneNumberConfirmed", "TwoFactorEnabled", "LockoutEnabled", "AccessFailedCount"
)
SELECT md5('ordreflow:demo:account:' || p.id::text)::uuid, p.id,
       p.email, upper(p.email), p.email, upper(p.email), true,
       CASE p.title
           WHEN 'Administrator' THEN 'AQAAAAIAAYagAAAAEK0CtiJlkRzgmHN96R9BYniYk/HK+IUaxMtTYRA1e5J43QL6VNgFN9Y+ylRsSAUUSw=='
           WHEN 'Manager' THEN 'AQAAAAIAAYagAAAAEMQ/kQqf1BkecvA8230QEFPqfixlX8uLodhMVSiPuWBFAxprXmNpBS4r1VoCkZE8/w=='
           ELSE 'AQAAAAIAAYagAAAAEBZeHJo/OwQR8GND+FB9pBvnIc/Ri4zS4VW34rx8f0lDnbeNAZrryAQcnJ/SIxsyvw=='
       END,
       md5('ordreflow:demo:security:' || p.id::text),
       md5('ordreflow:demo:concurrency:' || p.id::text),
       false, false, true, 0
FROM demo_people p
JOIN employees e ON e.id = p.id
WHERE true
ON CONFLICT DO NOTHING;

INSERT INTO departments (id, name) VALUES
    (md5('ordreflow:demo:department:1')::uuid, 'Product'),
    (md5('ordreflow:demo:department:2')::uuid, 'Operations')
ON CONFLICT (id) DO NOTHING;

INSERT INTO department_employees (department_id, employee_id)
SELECT md5('ordreflow:demo:department:' || p.department_slot)::uuid, p.id
FROM demo_people p
JOIN employees e ON e.id = p.id
WHERE p.department_slot IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO department_managers (department_id, manager_id)
SELECT md5('ordreflow:demo:department:' || p.department_slot)::uuid, p.id
FROM demo_people p
JOIN employees e ON e.id = p.id
WHERE p.title = 'Manager'
ON CONFLICT DO NOTHING;

-- Each manager reviews the categories in their department. Management by
-- itself does not grant reviewer permission or category review scope.
WITH category_seed(slot, department_slot, creator_id, name, internal_only, status) AS (
    VALUES
        (1, 1, '6da7cc94-0ea4-4d98-84a8-10d8b5ce2520'::uuid, 'Product development', true, 'Active'),
        (2, 1, md5('ordreflow:demo:manager:1')::uuid, 'Customer experience', false, 'Active'),
        (3, 2, md5('ordreflow:demo:manager:2')::uuid, 'Service delivery', true, 'Active'),
        (4, 2, '22222222-2222-2222-2222-222222222222'::uuid, 'Completed initiatives', false, 'Closed')
)
INSERT INTO catagories (id, created_by, department_id, name, description, status, internal_only, created_at, closed_at)
SELECT md5('ordreflow:demo:catagory:' || s.slot)::uuid, s.creator_id,
       md5('ordreflow:demo:department:' || s.department_slot)::uuid,
       s.name, 'Demo work in ' || s.name || '.', s.status, s.internal_only,
       greatest(creator.created_at + INTERVAL '1 day', CURRENT_TIMESTAMP - INTERVAL '80 days'),
       CASE WHEN s.status = 'Closed' THEN CURRENT_TIMESTAMP - INTERVAL '5 days' END
FROM category_seed s
JOIN employees creator ON creator.id = s.creator_id
WHERE true
ON CONFLICT (id) DO NOTHING;

INSERT INTO catagory_reviewers (employee_id, catagory_id)
SELECT p.id, c.id
FROM demo_people p
JOIN employees e ON e.id = p.id
JOIN catagories c ON c.department_id = md5('ordreflow:demo:department:' || p.department_slot)::uuid
                AND c.id IN (SELECT md5('ordreflow:demo:catagory:' || n)::uuid
                             FROM generate_series(1, 4) AS demo_categories(n))
WHERE p.title = 'Manager'
ON CONFLICT DO NOTHING;

WITH task_seed(slot, name) AS (
    VALUES (1, 'Design landing page'), (2, 'Implement checkout'), (3, 'Review product accessibility'),
           (4, 'Build customer portal'), (5, 'Test onboarding'), (6, 'Archive previous release'),
           (7, 'Set up notifications'), (8, 'Improve inventory sync'), (9, 'Document service procedures'),
           (10, 'Discovery interviews'), (11, 'Complete discovery report'), (12, 'Close old rollout')
)
INSERT INTO tasks (id, catagory_id, name, description, kind, assignment_only, status, created_at, closed_at)
SELECT md5('ordreflow:demo:task:' || s.slot)::uuid,
       c.id, s.name, 'Demo work item: ' || s.name || '.',
       CASE WHEN s.slot IN (4, 10) THEN 'Project'
            WHEN s.slot IN (7, 8) THEN 'Ticket' ELSE 'Task' END,
       s.slot IN (1, 7),
       CASE WHEN s.slot IN (6, 10, 11, 12) THEN 'Closed' ELSE 'Active' END,
       greatest(c.created_at + INTERVAL '1 day', CURRENT_TIMESTAMP - INTERVAL '70 days'),
       CASE WHEN s.slot IN (6, 10, 11, 12) THEN CURRENT_TIMESTAMP - INTERVAL '5 days' END
FROM task_seed s
JOIN catagories c ON c.id = md5('ordreflow:demo:catagory:' || ((s.slot - 1) / 3 + 1))::uuid
WHERE true
ON CONFLICT (id) DO NOTHING;

-- These two active tasks are assigned; the generated entries use other active
-- tasks so every seeded entry can pass the current assignment access check.
INSERT INTO task_assinments (task_id, assigned_to, expected_duration, expected_deadline) VALUES
    (md5('ordreflow:demo:task:1')::uuid, '5e530cd5-924a-445d-84ef-69bfb21ee241', 8.00, CURRENT_DATE + 14),
    (md5('ordreflow:demo:task:7')::uuid, '44444444-4444-4444-8444-444444444444', 12.00, CURRENT_DATE + 14)
ON CONFLICT DO NOTHING;

-- Monthly mode permits new registrations in the current month; older demo
-- entries remain historical and cannot be edited outside the open period.
INSERT INTO registration_period_modes (id, admin_id, interval, day_in_month, created_date)
SELECT md5('ordreflow:demo:registration-period')::uuid, p.id, 'Monthy', NULL,
       CURRENT_TIMESTAMP - INTERVAL '1 day'
FROM demo_people p
JOIN employees e ON e.id = p.id
WHERE p.title = 'Administrator'
ON CONFLICT (id) DO NOTHING;

-- First entry per employee is near today. Later entries cover several weeks;
-- work dates cannot precede either the employee or the task's creation.
CREATE TEMP TABLE demo_work_entries ON COMMIT DROP AS
WITH work_items AS (
    SELECT t.id AS task_id, c.department_id, t.created_at AS task_created_at,
           row_number() OVER (PARTITION BY c.department_id ORDER BY t.id) AS slot,
           count(*) OVER (PARTITION BY c.department_id) AS task_count
    FROM tasks t
    JOIN catagories c ON c.id = t.catagory_id
    WHERE t.status = 'Active' AND NOT t.assignment_only AND c.status = 'Active'
      AND t.id IN (SELECT md5('ordreflow:demo:task:' || n)::uuid
                   FROM generate_series(2, 5) AS product_tasks(n)
                   UNION ALL
                   SELECT md5('ordreflow:demo:task:' || n)::uuid
                   FROM generate_series(8, 9) AS operations_tasks(n))
), selected AS (
    SELECT md5('ordreflow:demo:time-entry:' || p.id::text || ':' || period.n)::uuid AS id,
           p.id AS employee_id, w.task_id,
           greatest(CASE WHEN period.n = 1 THEN CURRENT_DATE
                         ELSE CURRENT_DATE - ((period.n - 1) * 5 + ascii(left(p.id::text, 1)) % 3) END,
                    (e.created_at AT TIME ZONE 'UTC')::date + 2,
                    (w.task_created_at AT TIME ZONE 'UTC')::date + 2) AS work_date,
           (1 + (period.n % 7) * 0.5)::numeric(5, 2) AS duration,
           CASE period.n % 3 WHEN 2 THEN 'Approved' WHEN 0 THEN 'Rejected' END AS decision
    FROM demo_people p
    JOIN employees e ON e.id = p.id AND e.status = 'Active'
    CROSS JOIN generate_series(1, 10) AS period(n)
    JOIN work_items w ON w.department_id = md5('ordreflow:demo:department:' || p.department_slot)::uuid
                     AND w.slot = ((period.n - 1) % w.task_count) + 1
    WHERE p.title = 'Employee'
)
SELECT s.*, 'Demo work on ' || t.name || '.' AS description,
       least(CURRENT_TIMESTAMP - INTERVAL '10 minutes',
             (s.work_date::timestamp + INTERVAL '1 day 9 hours') AT TIME ZONE 'UTC') AS initial_at,
       CASE WHEN c.department_id = md5('ordreflow:demo:department:1')::uuid
            THEN '6da7cc94-0ea4-4d98-84a8-10d8b5ce2520'::uuid
            ELSE '22222222-2222-2222-2222-222222222222'::uuid END AS reviewer_id
FROM selected s
JOIN tasks t ON t.id = s.task_id
JOIN catagories c ON c.id = t.catagory_id;

-- A new time entry begins with a ReadyForApproval audit. Approvals/rejections
-- append an audit and a review with the same actor and UTC decision timestamp.
WITH inserted_entries AS (
    INSERT INTO time_entries (id, employee_id, revision)
    SELECT id, employee_id, CASE WHEN decision IS NULL THEN 1 ELSE 2 END
    FROM demo_work_entries
    WHERE true
    ON CONFLICT (id) DO NOTHING
    RETURNING id
), initial_audits AS (
    INSERT INTO time_entry_audits
        (id, time_entry_id, actor_id, closed_by, task_id, work_date, duration, description, status, audit_time)
    SELECT md5('ordreflow:demo:audit:initial:' || w.id::text)::uuid,
           w.id, w.employee_id, NULL, w.task_id, w.work_date, w.duration,
           w.description, 'ReadyForApproval', w.initial_at
    FROM demo_work_entries w JOIN inserted_entries i ON i.id = w.id
    RETURNING time_entry_id
), decision_audits AS (
    INSERT INTO time_entry_audits
        (id, time_entry_id, actor_id, closed_by, task_id, work_date, duration, description, status, audit_time)
    SELECT md5('ordreflow:demo:audit:decision:' || w.id::text)::uuid,
           w.id, w.reviewer_id, NULL, w.task_id, w.work_date, w.duration,
           w.description, w.decision, w.initial_at + INTERVAL '1 minute'
    FROM demo_work_entries w JOIN initial_audits i ON i.time_entry_id = w.id
    WHERE w.decision IS NOT NULL
    RETURNING time_entry_id
)
INSERT INTO time_entry_reviews (id, time_entry_id, reviewer_id, description, status, reviewed_at_utc)
SELECT md5('ordreflow:demo:review:' || w.id::text)::uuid,
       w.id, w.reviewer_id,
       CASE WHEN w.decision = 'Rejected' THEN 'Please describe this work in more detail.' END,
       w.decision, w.initial_at + INTERVAL '1 minute'
FROM demo_work_entries w JOIN decision_audits d ON d.time_entry_id = w.id;

COMMIT;

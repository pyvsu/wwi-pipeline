-- =====================================================
-- 03_dim_employee.sql : load dw.dim_employee (SCD1, full reload)
-- Source: oltp.people where is_employee
-- =====================================================

BEGIN TRANSACTION;

DELETE FROM dw.dim_employee;

INSERT INTO dw.dim_employee (
    employee_key, person_id, full_name, preferred_name, is_salesperson
)
SELECT
    ROW_NUMBER() OVER (ORDER BY person_id) AS employee_key,
    person_id,
    full_name,
    preferred_name,
    is_salesperson
FROM oltp.people
WHERE is_employee;

-- Unknown member
INSERT INTO dw.dim_employee (
    employee_key, person_id, full_name, preferred_name, is_salesperson
)
VALUES (-1, -1, 'Unknown', 'Unknown', FALSE);

COMMIT;

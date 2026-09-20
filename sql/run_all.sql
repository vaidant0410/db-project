-- =====================================================================
-- run_all.sql  -  Airline Reservation System : build everything + demo
--
-- Runs scripts 00-09 in order: drop, schema, data, views, functions,
-- procedures, triggers, package, queries, demo.
--
-- '@@' resolves each file relative to THIS script, so it works from
-- any working directory:
--     sqlplus ars/ars_pass@//localhost:1521/XEPDB1 @sql/run_all.sql
--     SQL> @run_all.sql            (when you are inside the sql folder)
--
-- Output is also written to run_all.log in the current directory.
-- The data set is rebuilt on every run, so flight dates are fresh
-- (the demo relies on flights leaving in the future).
-- =====================================================================
SET ECHO OFF
SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WRAPPED
SET LINESIZE 200
SET PAGESIZE 50
SET FEEDBACK ON
SET VERIFY OFF
SET DEFINE OFF
SET SQLBLANKLINES ON
SET TRIMSPOOL ON
WHENEVER SQLERROR CONTINUE

SPOOL run_all.log

PROMPT
PROMPT #####################################################################
PROMPT #  AIRLINE RESERVATION SYSTEM - full rebuild
PROMPT #####################################################################

@@00_drop.sql
@@01_schema.sql
@@02_data.sql
@@03_views.sql
@@04_functions.sql
@@05_procedures.sql
@@06_triggers.sql
@@07_package.sql

PROMPT
PROMPT #####################################################################
PROMPT #  Compilation check - anything listed here needs attention
PROMPT #####################################################################
COLUMN object_name FORMAT A32
COLUMN object_type FORMAT A15
COLUMN status      FORMAT A8
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status <> 'VALID'
 ORDER BY object_type, object_name;
PROMPT (no rows selected above means every object compiled cleanly)
CLEAR COLUMNS

@@08_queries.sql
@@09_demo.sql

PROMPT
PROMPT #####################################################################
PROMPT #  All scripts finished. Log: run_all.log
PROMPT #####################################################################

SPOOL OFF

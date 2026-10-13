-- =====================================================================
-- 00_drop.sql  -  Airline Reservation System : safe cleanup
--
-- Drops every object created by scripts 01-08 so the project can be
-- rebuilt from scratch. Objects that do not exist yet are skipped, so
-- the script is safe to run on an empty schema.
--
-- Errors that are deliberately ignored:
--   ORA-00942  table or view does not exist
--   ORA-02289  sequence does not exist (identity columns own their
--              sequences, but the code tolerates explicit ones too)
--   ORA-04043  procedure / function / package does not exist
--   ORA-04080  trigger does not exist
--   ORA-01418  index does not exist
-- Any other error is re-raised.
--
-- Usage:  SQL> @00_drop.sql
-- =====================================================================
SET ECHO OFF
SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WRAPPED
SET LINESIZE 200
SET PAGESIZE 50
SET FEEDBACK ON
SET VERIFY OFF
SET DEFINE OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT ==== 00_drop.sql : dropping existing Airline Reservation objects ====

DECLARE
  v_dropped PLS_INTEGER := 0;

  PROCEDURE drop_it (p_sql IN VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE p_sql;
    v_dropped := v_dropped + 1;
    DBMS_OUTPUT.PUT_LINE('  dropped : ' || p_sql);
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE IN (-942, -2289, -4043, -4080, -1418) THEN
        NULL;                       -- object was not there: nothing to do
      ELSE
        RAISE;
      END IF;
  END drop_it;
BEGIN
  -- views
  drop_it('DROP VIEW departures_board');
  drop_it('DROP VIEW airline_revenue');
  drop_it('DROP VIEW passenger_itinerary');
  drop_it('DROP VIEW available_seats');

  -- package (spec + body), then standalone routines
  drop_it('DROP PACKAGE flight_search_pkg');
  drop_it('DROP PACKAGE reservation_pkg');
  drop_it('DROP PROCEDURE show_passenger_bookings');
  drop_it('DROP PROCEDURE cancel_booking');
  drop_it('DROP PROCEDURE book_ticket');
  drop_it('DROP FUNCTION refund_percentage');
  drop_it('DROP FUNCTION seats_left');
  drop_it('DROP FUNCTION calculate_fare');

  -- triggers (they would vanish with their tables; explicit for clarity)
  drop_it('DROP TRIGGER trg_bookings_audit');
  drop_it('DROP TRIGGER trg_bookings_seat_status');
  drop_it('DROP TRIGGER trg_bookings_one_per_flight');
  drop_it('DROP TRIGGER trg_bookings_no_double_booking');
  drop_it('DROP TRIGGER trg_flights_validate_times');

  -- tables, children before parents; CASCADE CONSTRAINTS makes the
  -- order forgiving and PURGE skips the recycle bin
  drop_it('DROP TABLE flight_crew CASCADE CONSTRAINTS PURGE');
  drop_it('DROP TABLE crew CASCADE CONSTRAINTS PURGE');
  drop_it('DROP TABLE payments CASCADE CONSTRAINTS PURGE');
  drop_it('DROP TABLE booking_audit_log CASCADE CONSTRAINTS PURGE');
  drop_it('DROP TABLE bookings CASCADE CONSTRAINTS PURGE');
  drop_it('DROP TABLE seats CASCADE CONSTRAINTS PURGE');
  drop_it('DROP TABLE flights CASCADE CONSTRAINTS PURGE');
  drop_it('DROP TABLE aircraft CASCADE CONSTRAINTS PURGE');
  drop_it('DROP TABLE passengers CASCADE CONSTRAINTS PURGE');
  drop_it('DROP TABLE airports CASCADE CONSTRAINTS PURGE');
  drop_it('DROP TABLE airlines CASCADE CONSTRAINTS PURGE');

  DBMS_OUTPUT.PUT_LINE('Cleanup complete: ' || v_dropped || ' object(s) dropped.');
END;
/

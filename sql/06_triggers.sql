-- =====================================================================
-- 06_triggers.sql  -  Airline Reservation System : triggers
--
--   trg_flights_validate_times     BEFORE ROW on flights
--        departure must be earlier than arrival              (-20101)
--   trg_bookings_no_double_booking BEFORE ROW on bookings
--        rejects a CONFIRMED booking for a seat that is
--        already BOOKED; locks the seat row first            (-20102)
--   trg_bookings_one_per_flight    COMPOUND on bookings
--        a passenger may hold only one CONFIRMED seat
--        per flight                                          (-20103)
--   trg_bookings_seat_status       AFTER ROW on bookings
--        keeps seats.status in step with bookings
--        (BOOKED on confirm, AVAILABLE on cancel / delete /
--        seat change)
--   trg_bookings_audit             AFTER ROW on bookings
--        writes every INSERT / UPDATE / DELETE to
--        booking_audit_log
--
-- Avoiding ORA-04091 (mutating table)
--  A row-level trigger may not query or modify the table that fired it.
--   * The double-booking check needs the seat's state, which lives in
--     SEATS, not BOOKINGS - so a plain BEFORE ROW trigger is safe.
--   * "One seat per passenger per flight" must count rows in BOOKINGS.
--     The compound trigger records the affected rows in the row-level
--     section (no queries) and does the counting in AFTER STATEMENT,
--     when BOOKINGS is no longer mutating.
--   * The seat-status and audit triggers only write to OTHER tables.
--
-- Concurrency: the unique index uq_bookings_active_seat (01_schema.sql)
-- is the last line of defence if two sessions ever race for one seat.
--
-- Usage:  SQL> @06_triggers.sql
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
PROMPT ==== 06_triggers.sql : creating triggers ====

-- ---------------------------------------------------------------------
-- 1. departure < arrival
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_flights_validate_times
BEFORE INSERT OR UPDATE OF departure_time, arrival_time ON flights
FOR EACH ROW
BEGIN
  IF :NEW.arrival_time <= :NEW.departure_time THEN
    RAISE_APPLICATION_ERROR(-20101,
      'Flight ' || :NEW.flight_no || ': arrival (' ||
      TO_CHAR(:NEW.arrival_time, 'DD-Mon-YYYY HH24:MI') ||
      ') must be later than departure (' ||
      TO_CHAR(:NEW.departure_time, 'DD-Mon-YYYY HH24:MI') || ').');
  END IF;
END trg_flights_validate_times;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- 2. never book a seat that is already taken
--    Fires only when a row starts to hold a seat: a new CONFIRMED
--    booking, a cancelled booking being re-confirmed, or a confirmed
--    booking moving to another seat.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_bookings_no_double_booking
BEFORE INSERT OR UPDATE OF seat_id, status ON bookings
FOR EACH ROW
DECLARE
  v_seat_state seats.status%TYPE;
BEGIN
  IF NVL(:NEW.status, 'CONFIRMED') = 'CONFIRMED'
     AND (INSERTING OR :OLD.status <> 'CONFIRMED' OR :OLD.seat_id <> :NEW.seat_id) THEN
    BEGIN
      -- FOR UPDATE serialises concurrent bookings of the same seat: the
      -- second session waits here, then sees status = 'BOOKED'.
      SELECT status
        INTO v_seat_state
        FROM seats
       WHERE seat_id = :NEW.seat_id
         FOR UPDATE;

      IF v_seat_state = 'BOOKED' THEN
        RAISE_APPLICATION_ERROR(-20102,
          'Double booking prevented: seat ' || :NEW.seat_id || ' is already booked.');
      END IF;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;   -- unknown seat: the foreign key reports it (ORA-02291)
    END;
  END IF;
END trg_bookings_no_double_booking;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- 3. one CONFIRMED seat per passenger per flight  (COMPOUND TRIGGER)
--    AFTER EACH ROW  : only remembers (passenger, seat) - no queries
--    AFTER STATEMENT : BOOKINGS is no longer mutating, so it may be
--                      queried; raising here undoes the whole statement
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_bookings_one_per_flight
FOR INSERT OR UPDATE OF passenger_id, seat_id, status ON bookings
COMPOUND TRIGGER

  TYPE t_key IS RECORD (
    passenger_id bookings.passenger_id%TYPE,
    seat_id      bookings.seat_id%TYPE
  );
  TYPE t_key_tab IS TABLE OF t_key INDEX BY PLS_INTEGER;
  g_keys t_key_tab;

  AFTER EACH ROW IS
    v_key t_key;
  BEGIN
    IF :NEW.status = 'CONFIRMED' THEN
      v_key.passenger_id := :NEW.passenger_id;
      v_key.seat_id      := :NEW.seat_id;
      g_keys(g_keys.COUNT + 1) := v_key;
    END IF;
  END AFTER EACH ROW;

  AFTER STATEMENT IS
    v_flight_id seats.flight_id%TYPE;
    v_count     PLS_INTEGER;
  BEGIN
    FOR i IN 1 .. g_keys.COUNT LOOP
      SELECT flight_id INTO v_flight_id FROM seats WHERE seat_id = g_keys(i).seat_id;

      SELECT COUNT(*)
        INTO v_count
        FROM bookings b
        JOIN seats    s ON s.seat_id = b.seat_id
       WHERE b.passenger_id = g_keys(i).passenger_id
         AND b.status       = 'CONFIRMED'
         AND s.flight_id    = v_flight_id;

      IF v_count > 1 THEN
        RAISE_APPLICATION_ERROR(-20103,
          'Passenger ' || g_keys(i).passenger_id ||
          ' already holds a confirmed seat on flight ' || v_flight_id || '.');
      END IF;
    END LOOP;
  END AFTER STATEMENT;

END trg_bookings_one_per_flight;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- 4. keep seats.status in step with bookings
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_bookings_seat_status
AFTER INSERT OR UPDATE OF status, seat_id OR DELETE ON bookings
FOR EACH ROW
BEGIN
  -- the row no longer holds the seat it used to hold -> free it
  IF (UPDATING OR DELETING) AND :OLD.status = 'CONFIRMED'
     AND (DELETING OR :NEW.status <> 'CONFIRMED' OR :NEW.seat_id <> :OLD.seat_id) THEN
    UPDATE seats
       SET status = 'AVAILABLE'
     WHERE seat_id = :OLD.seat_id;
  END IF;

  -- the row now holds a seat it did not hold before -> mark it booked
  IF (INSERTING OR UPDATING) AND :NEW.status = 'CONFIRMED'
     AND (INSERTING OR :OLD.status <> 'CONFIRMED' OR :NEW.seat_id <> :OLD.seat_id) THEN
    UPDATE seats
       SET status = 'BOOKED'
     WHERE seat_id = :NEW.seat_id;
  END IF;
END trg_bookings_seat_status;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- 5. audit log of booking changes
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_bookings_audit
AFTER INSERT OR UPDATE OR DELETE ON bookings
FOR EACH ROW
DECLARE
  v_action booking_audit_log.action%TYPE;
BEGIN
  IF INSERTING THEN
    v_action := 'INSERT';
  ELSIF UPDATING THEN
    v_action := 'UPDATE';
  ELSE
    v_action := 'DELETE';
  END IF;

  INSERT INTO booking_audit_log
         (booking_id, action, old_status, new_status, old_seat_id, new_seat_id)
  VALUES (NVL(:NEW.booking_id, :OLD.booking_id), v_action,
          :OLD.status, :NEW.status, :OLD.seat_id, :NEW.seat_id);
END trg_bookings_audit;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- Check that everything compiled
-- ---------------------------------------------------------------------
PROMPT
PROMPT Triggers installed:
COLUMN trigger_name FORMAT A32
COLUMN table_name   FORMAT A10
COLUMN trigger_type FORMAT A20
COLUMN status       FORMAT A8
SELECT trigger_name, table_name, trigger_type, status
  FROM user_triggers
 ORDER BY table_name, trigger_name;
CLEAR COLUMNS

-- =====================================================================
-- 04_functions.sql  -  Airline Reservation System : stored functions
--
--   calculate_fare(flight_id, seat_class)  price quote for one seat
--   seats_left(flight_id)                  AVAILABLE seats on a flight
--   refund_percentage(hours_before)        cancellation refund policy
--                                          (helper for cancel_booking)
--
-- Custom error codes used across the project (RAISE_APPLICATION_ERROR)
--   -20001 flight does not exist
--   -20002 invalid seat class
--   -20003 seat not found on that flight
--   -20004 seat already booked                       (book_ticket)
--   -20005 passenger does not exist
--   -20006 flight is not open for booking
--   -20007 payment declined
--   -20008 booking does not exist
--   -20009 booking already cancelled
--   -20010 flight already departed, cannot cancel
--   -20101 arrival must be after departure           (trigger)
--   -20102 seat already booked                       (trigger)
--   -20103 passenger already holds a seat on the flight (trigger)
--
-- Fare rule (documented here so it can be explained in the viva)
--   fare = base_fare x class multiplier
--          ECONOMY 1.0 | BUSINESS 2.5 | FIRST 4.0
--   +15 % when 75 % or more of the flight's seats are already booked
--   +20 % when the flight departs within the next 48 hours
--
-- Refund rule (hours between cancellation and departure)
--   72 h or more : 90 %   |   24 h to 72 h : 50 %
--   under 24 h   : 10 %   |   already departed : 0 %
--
-- Usage:  SQL> @04_functions.sql
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
PROMPT ==== 04_functions.sql : creating functions ====

-- ---------------------------------------------------------------------
-- calculate_fare
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calculate_fare (
  p_flight_id  IN flights.flight_id%TYPE,
  p_seat_class IN seats.seat_class%TYPE
) RETURN NUMBER
IS
  c_high_load          CONSTANT NUMBER := 0.75;   -- share of seats booked
  c_high_load_uplift   CONSTANT NUMBER := 1.15;
  c_last_minute_hrs    CONSTANT NUMBER := 48;
  c_last_minute_uplift CONSTANT NUMBER := 1.20;

  v_base_fare  flights.base_fare%TYPE;
  v_departure  flights.departure_time%TYPE;
  v_multiplier NUMBER;
  v_total      NUMBER;
  v_booked     NUMBER;
  v_fare       NUMBER;
BEGIN
  BEGIN
    SELECT base_fare, departure_time
      INTO v_base_fare, v_departure
      FROM flights
     WHERE flight_id = p_flight_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20001, 'Flight ' || p_flight_id || ' does not exist.');
  END;

  v_multiplier := CASE UPPER(p_seat_class)
                    WHEN 'ECONOMY'  THEN 1
                    WHEN 'BUSINESS' THEN 2.5
                    WHEN 'FIRST'    THEN 4
                  END;                       -- NULL for anything else
  IF v_multiplier IS NULL THEN
    RAISE_APPLICATION_ERROR(-20002,
      'Invalid seat class ''' || p_seat_class || '''. Use ECONOMY, BUSINESS or FIRST.');
  END IF;

  SELECT COUNT(*),
         NVL(SUM(CASE WHEN status = 'BOOKED' THEN 1 END), 0)
    INTO v_total, v_booked
    FROM seats
   WHERE flight_id = p_flight_id;

  v_fare := v_base_fare * v_multiplier;

  IF v_total > 0 AND v_booked / v_total >= c_high_load THEN
    v_fare := v_fare * c_high_load_uplift;
  END IF;

  IF v_departure > SYSDATE AND (v_departure - SYSDATE) * 24 <= c_last_minute_hrs THEN
    v_fare := v_fare * c_last_minute_uplift;
  END IF;

  RETURN ROUND(v_fare, 2);
END calculate_fare;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- seats_left
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION seats_left (
  p_flight_id IN flights.flight_id%TYPE
) RETURN NUMBER
IS
  v_exists PLS_INTEGER;
  v_left   NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_exists FROM flights WHERE flight_id = p_flight_id;
  IF v_exists = 0 THEN
    RAISE_APPLICATION_ERROR(-20001, 'Flight ' || p_flight_id || ' does not exist.');
  END IF;

  SELECT COUNT(*)
    INTO v_left
    FROM seats
   WHERE flight_id = p_flight_id
     AND status = 'AVAILABLE';

  RETURN v_left;
END seats_left;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- refund_percentage : returns a fraction (0.90 = 90 %)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION refund_percentage (
  p_hours_before_departure IN NUMBER
) RETURN NUMBER
DETERMINISTIC
IS
BEGIN
  RETURN CASE
           WHEN p_hours_before_departure >= 72 THEN 0.90
           WHEN p_hours_before_departure >= 24 THEN 0.50
           WHEN p_hours_before_departure >   0 THEN 0.10
           ELSE 0
         END;
END refund_percentage;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- Quick self-test (needs no data: the database starts empty)
-- ---------------------------------------------------------------------
PROMPT
PROMPT Self-test: refund_percentage(hours before departure)
SELECT refund_percentage(100) AS at_100h,
       refund_percentage(30)  AS at_30h,
       refund_percentage(5)   AS at_5h,
       refund_percentage(-1)  AS after_departure
  FROM dual;

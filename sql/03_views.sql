-- =====================================================================
-- 03_views.sql  -  Airline Reservation System : views
--
--   available_seats      bookable seats on upcoming flights
--   passenger_itinerary  every booking with flight, seat and payment
--   airline_revenue      bookings, gross, refunds and net per airline
--
-- Views are created before the functions in 04_functions.sql, so they
-- show base_fare; use calculate_fare(flight_id, seat_class) for the
-- live price.
--
-- Usage:  SQL> @03_views.sql
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
PROMPT ==== 03_views.sql : creating views ====

-- ---------------------------------------------------------------------
-- available_seats : AVAILABLE seats on flights that can still be booked
-- (SCHEDULED or DELAYED and not yet departed).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW available_seats AS
SELECT f.flight_id,
       f.flight_no,
       al.airline_name,
       ao.iata_code   AS origin,
       ad.iata_code   AS destination,
       f.departure_time,
       s.seat_id,
       s.seat_no,
       s.seat_class,
       f.base_fare
  FROM seats s
  JOIN flights  f  ON f.flight_id   = s.flight_id
  JOIN airlines al ON al.airline_id = f.airline_id
  JOIN airports ao ON ao.airport_id = f.origin_airport_id
  JOIN airports ad ON ad.airport_id = f.dest_airport_id
 WHERE s.status = 'AVAILABLE'
   AND f.status IN ('SCHEDULED', 'DELAYED')
   AND f.departure_time > SYSDATE;

-- ---------------------------------------------------------------------
-- passenger_itinerary : one row per booking (confirmed and cancelled),
-- with the flight, route, seat and what was paid / refunded.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW passenger_itinerary AS
SELECT p.passenger_id,
       p.first_name || ' ' || p.last_name AS passenger_name,
       b.booking_id,
       b.status         AS booking_status,
       f.flight_no,
       al.airline_name,
       ao.city          AS from_city,
       ad.city          AS to_city,
       f.departure_time,
       f.arrival_time,
       s.seat_no,
       s.seat_class,
       pay.amount       AS amount_paid,
       pay.refund_amount,
       pay.status       AS payment_status
  FROM bookings b
  JOIN passengers p   ON p.passenger_id = b.passenger_id
  JOIN seats      s   ON s.seat_id      = b.seat_id
  JOIN flights    f   ON f.flight_id    = s.flight_id
  JOIN airlines   al  ON al.airline_id  = f.airline_id
  JOIN airports   ao  ON ao.airport_id  = f.origin_airport_id
  JOIN airports   ad  ON ad.airport_id  = f.dest_airport_id
  LEFT JOIN payments pay ON pay.booking_id = b.booking_id;

-- ---------------------------------------------------------------------
-- airline_revenue : LEFT JOINs keep airlines that have no flights or no
-- bookings (they show 0). payments.booking_id is UNIQUE, so a booking
-- never fans out into several payment rows and the sums are safe.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW airline_revenue AS
SELECT al.airline_id,
       al.airline_name,
       COUNT(b.booking_id)                                       AS total_bookings,
       NVL(SUM(CASE WHEN b.status = 'CONFIRMED' THEN 1 END), 0)  AS confirmed_bookings,
       NVL(SUM(pay.amount), 0)                                   AS gross_revenue,
       NVL(SUM(pay.refund_amount), 0)                            AS total_refunds,
       NVL(SUM(pay.amount), 0) - NVL(SUM(pay.refund_amount), 0)  AS net_revenue
  FROM airlines al
  LEFT JOIN flights  f   ON f.airline_id  = al.airline_id
  LEFT JOIN seats    s   ON s.flight_id   = f.flight_id
  LEFT JOIN bookings b   ON b.seat_id     = s.seat_id
  LEFT JOIN payments pay ON pay.booking_id = b.booking_id
 GROUP BY al.airline_id, al.airline_name;

PROMPT
PROMPT Views created:
COLUMN view_name FORMAT A25
SELECT view_name FROM user_views ORDER BY view_name;
COLUMN view_name CLEAR

PROMPT
PROMPT Preview - airline_revenue:
COLUMN airline_name       FORMAT A22
COLUMN total_bookings     FORMAT 999      HEADING 'BOOK|INGS'
COLUMN confirmed_bookings FORMAT 999      HEADING 'CONF|IRMED'
COLUMN gross_revenue      FORMAT 9,999,999.99
COLUMN total_refunds      FORMAT 9,999,999.99
COLUMN net_revenue        FORMAT 9,999,999.99
SELECT airline_name, total_bookings, confirmed_bookings,
       gross_revenue, total_refunds, net_revenue
  FROM airline_revenue
 ORDER BY net_revenue DESC, airline_name;
CLEAR COLUMNS

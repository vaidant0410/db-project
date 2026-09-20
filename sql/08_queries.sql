-- =====================================================================
-- 08_queries.sql  -  Airline Reservation System : 15 demo queries
--
--   Q1-Q2    INNER JOIN            Q10-Q11  correlated subquery / EXISTS
--   Q3-Q5    LEFT / RIGHT / FULL   Q12      NOT EXISTS
--   Q6-Q7    GROUP BY / HAVING     Q13      UNION
--   Q8-Q9    nested subqueries     Q14      INTERSECT
--                                  Q15      MINUS
--
-- Read-only: nothing here changes data.
-- Usage:  SQL> @08_queries.sql
-- =====================================================================
SET ECHO OFF
SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WRAPPED
SET LINESIZE 200
SET PAGESIZE 50
SET FEEDBACK ON
SET VERIFY OFF
SET DEFINE OFF
SET SQLBLANKLINES ON

CLEAR COLUMNS
COLUMN flight_no         FORMAT A9
COLUMN airline_name      FORMAT A20
COLUMN origin            FORMAT A6
COLUMN destination       FORMAT A11
COLUMN departs           FORMAT A17
COLUMN base_fare         FORMAT 99,990.00
COLUMN flight_status     FORMAT A13
COLUMN booking_id        FORMAT 9999   HEADING 'BOOKING'
COLUMN passenger_id      FORMAT 999    HEADING 'PAX|ID'
COLUMN passenger_name    FORMAT A22
COLUMN email             FORMAT A32
COLUMN seat_no           FORMAT A6
COLUMN seat_class        FORMAT A10
COLUMN amount            FORMAT 99,990.00
COLUMN payment_method    FORMAT A14
COLUMN booking_status    FORMAT A14
COLUMN flights_operated  FORMAT 999
COLUMN registration_no   FORMAT A12
COLUMN aircraft_model    FORMAT A26
COLUMN aircraft_status   FORMAT A16
COLUMN full_name         FORMAT A20
COLUMN crew_role         FORMAT A14
COLUMN rostered_flight   FORMAT A16
COLUMN payments_made     FORMAT 999
COLUMN gross_amount      FORMAT 999,990.00
COLUMN refunded_amount   FORMAT 999,990.00
COLUMN net_amount        FORMAT 999,990.00
COLUMN destination_city  FORMAT A20
COLUMN confirmed_bookings FORMAT 999   HEADING 'CONFIRMED|BOOKINGS'
COLUMN city              FORMAT A20
COLUMN airport_code      FORMAT A12

PROMPT
PROMPT ==== 08_queries.sql : 15 demo queries ====

-- ---------------------------------------------------------------------
PROMPT
PROMPT Q1  INNER JOIN (flights, airlines, airports twice)
PROMPT     Flight schedule: only flights that can still be booked, with airline and route.
-- ---------------------------------------------------------------------
SELECT f.flight_no,
       al.airline_name,
       ao.iata_code                                   AS origin,
       ad.iata_code                                   AS destination,
       TO_CHAR(f.departure_time, 'DD-Mon-YYYY HH24:MI') AS departs,
       f.base_fare,
       f.status                                       AS flight_status
  FROM flights f
  JOIN airlines al ON al.airline_id = f.airline_id
  JOIN airports ao ON ao.airport_id = f.origin_airport_id
  JOIN airports ad ON ad.airport_id = f.dest_airport_id
 WHERE f.status IN ('SCHEDULED', 'DELAYED')
 ORDER BY f.departure_time;

-- ---------------------------------------------------------------------
PROMPT
PROMPT Q2  INNER JOIN (bookings, passengers, seats, flights, payments)
PROMPT     Every confirmed booking with who booked, which seat, and what was paid.
-- ---------------------------------------------------------------------
SELECT b.booking_id,
       p.first_name || ' ' || p.last_name AS passenger_name,
       f.flight_no,
       s.seat_no,
       s.seat_class,
       pay.amount,
       pay.payment_method
  FROM bookings   b
  JOIN passengers p   ON p.passenger_id = b.passenger_id
  JOIN seats      s   ON s.seat_id      = b.seat_id
  JOIN flights    f   ON f.flight_id    = s.flight_id
  JOIN payments   pay ON pay.booking_id = b.booking_id
 WHERE b.status = 'CONFIRMED'
 ORDER BY b.booking_id;

-- ---------------------------------------------------------------------
PROMPT
PROMPT Q3  LEFT OUTER JOIN (airlines, flights)
PROMPT     Flights per airline. Lufthansa has no flights but is still listed, with 0.
-- ---------------------------------------------------------------------
SELECT al.airline_name,
       COUNT(f.flight_id) AS flights_operated
  FROM airlines al
  LEFT OUTER JOIN flights f ON f.airline_id = al.airline_id
 GROUP BY al.airline_name
 ORDER BY flights_operated DESC, al.airline_name;

-- ---------------------------------------------------------------------
PROMPT
PROMPT Q4  RIGHT OUTER JOIN (flights, aircraft)
PROMPT     Aircraft that are not assigned to any flight (the unmatched right-hand rows).
-- ---------------------------------------------------------------------
SELECT ac.registration_no,
       ac.aircraft_model,
       ac.status AS aircraft_status
  FROM flights f
 RIGHT OUTER JOIN aircraft ac ON ac.aircraft_id = f.aircraft_id
 WHERE f.flight_id IS NULL
 ORDER BY ac.registration_no;

-- ---------------------------------------------------------------------
PROMPT
PROMPT Q5  FULL OUTER JOIN (crew, flight_crew)
PROMPT     Crew roster: every crew member, with the flight they are rostered on,
PROMPT     or 'not rostered' when they have no assignment.
-- ---------------------------------------------------------------------
SELECT c.full_name,
       c.crew_role,
       NVL(TO_CHAR(fc.flight_id), 'not rostered') AS rostered_flight
  FROM crew c
  FULL OUTER JOIN flight_crew fc ON fc.crew_id = c.crew_id
 ORDER BY fc.flight_id, c.crew_id;

-- ---------------------------------------------------------------------
PROMPT
PROMPT Q6  GROUP BY with aggregates
PROMPT     Payments, gross, refunds and net amount per payment method.
-- ---------------------------------------------------------------------
SELECT payment_method,
       COUNT(*)                          AS payments_made,
       SUM(amount)                       AS gross_amount,
       SUM(refund_amount)                AS refunded_amount,
       SUM(amount) - SUM(refund_amount)  AS net_amount
  FROM payments
 GROUP BY payment_method
 ORDER BY net_amount DESC;

-- ---------------------------------------------------------------------
PROMPT
PROMPT Q7  GROUP BY ... HAVING
PROMPT     Destination cities with at least 2 confirmed bookings (HAVING filters the groups).
-- ---------------------------------------------------------------------
SELECT ad.city AS destination_city,
       COUNT(*) AS confirmed_bookings
  FROM bookings b
  JOIN seats    s  ON s.seat_id     = b.seat_id
  JOIN flights  f  ON f.flight_id   = s.flight_id
  JOIN airports ad ON ad.airport_id = f.dest_airport_id
 WHERE b.status = 'CONFIRMED'
 GROUP BY ad.city
HAVING COUNT(*) >= 2
 ORDER BY confirmed_bookings DESC, ad.city;

-- ---------------------------------------------------------------------
PROMPT
PROMPT Q8  Nested (non-correlated) subquery
PROMPT     Flights whose base fare is above the average base fare of all flights.
-- ---------------------------------------------------------------------
SELECT flight_no, base_fare
  FROM flights
 WHERE base_fare > (SELECT AVG(base_fare) FROM flights)
 ORDER BY base_fare DESC;

-- ---------------------------------------------------------------------
PROMPT
PROMPT Q9  Nested subquery with IN
PROMPT     Passengers holding a confirmed BUSINESS or FIRST class seat.
-- ---------------------------------------------------------------------
SELECT p.passenger_id,
       p.first_name || ' ' || p.last_name AS passenger_name,
       p.email
  FROM passengers p
 WHERE p.passenger_id IN (SELECT b.passenger_id
                            FROM bookings b
                            JOIN seats s ON s.seat_id = b.seat_id
                           WHERE b.status = 'CONFIRMED'
                             AND s.seat_class IN ('BUSINESS', 'FIRST'))
 ORDER BY p.passenger_id;

-- ---------------------------------------------------------------------
PROMPT
PROMPT Q10 Correlated subquery
PROMPT     Flights priced above the average of THEIR OWN airline (the subquery is re-evaluated
PROMPT     for each outer row because it refers to f.airline_id).
-- ---------------------------------------------------------------------
SELECT f.flight_no,
       al.airline_name,
       f.base_fare
  FROM flights f
  JOIN airlines al ON al.airline_id = f.airline_id
 WHERE f.base_fare > (SELECT AVG(f2.base_fare)
                        FROM flights f2
                       WHERE f2.airline_id = f.airline_id)
 ORDER BY al.airline_name, f.base_fare DESC;

-- ---------------------------------------------------------------------
PROMPT
PROMPT Q11 EXISTS
PROMPT     Passengers who have cancelled at least one booking.
-- ---------------------------------------------------------------------
SELECT p.passenger_id,
       p.first_name || ' ' || p.last_name AS passenger_name
  FROM passengers p
 WHERE EXISTS (SELECT 1
                 FROM bookings b
                WHERE b.passenger_id = p.passenger_id
                  AND b.status = 'CANCELLED')
 ORDER BY p.passenger_id;

-- ---------------------------------------------------------------------
PROMPT
PROMPT Q12 NOT EXISTS
PROMPT     Upcoming flights that have no crew rostered yet.
-- ---------------------------------------------------------------------
SELECT f.flight_no,
       ao.iata_code                                   AS origin,
       ad.iata_code                                   AS destination,
       TO_CHAR(f.departure_time, 'DD-Mon-YYYY HH24:MI') AS departs
  FROM flights f
  JOIN airports ao ON ao.airport_id = f.origin_airport_id
  JOIN airports ad ON ad.airport_id = f.dest_airport_id
 WHERE f.status IN ('SCHEDULED', 'DELAYED')
   AND NOT EXISTS (SELECT 1
                     FROM flight_crew fc
                    WHERE fc.flight_id = f.flight_id)
 ORDER BY f.departure_time;

-- ---------------------------------------------------------------------
PROMPT
PROMPT Q13 UNION
PROMPT     Every city that appears as an origin OR a destination (duplicates removed).
-- ---------------------------------------------------------------------
SELECT ao.city AS city
  FROM flights f
  JOIN airports ao ON ao.airport_id = f.origin_airport_id
UNION
SELECT ad.city
  FROM flights f
  JOIN airports ad ON ad.airport_id = f.dest_airport_id
 ORDER BY city;

-- ---------------------------------------------------------------------
PROMPT
PROMPT Q14 INTERSECT
PROMPT     Airports that are BOTH the origin of some flight AND the destination of another.
-- ---------------------------------------------------------------------
SELECT a.iata_code AS airport_code, a.city
  FROM airports a
  JOIN flights f ON f.origin_airport_id = a.airport_id
INTERSECT
SELECT a.iata_code, a.city
  FROM airports a
  JOIN flights f ON f.dest_airport_id = a.airport_id
 ORDER BY 1;

-- ---------------------------------------------------------------------
PROMPT
PROMPT Q15 MINUS
PROMPT     Airports that are a destination but never an origin (arrival-only airports).
-- ---------------------------------------------------------------------
SELECT a.iata_code AS airport_code, a.city
  FROM airports a
  JOIN flights f ON f.dest_airport_id = a.airport_id
MINUS
SELECT a.iata_code, a.city
  FROM airports a
  JOIN flights f ON f.origin_airport_id = a.airport_id
 ORDER BY 1;

CLEAR COLUMNS

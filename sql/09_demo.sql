-- =====================================================================
-- 09_demo.sql  -  Airline Reservation System : end-to-end demo
--
--   Step 0  starting state, pricing rules
--   Step 1  successful booking
--   Step 2  double booking blocked (triggers) + one seat per flight
--   Step 3  rollback on payment failure
--   Step 4  cancellation with tiered refunds
--   Step 5  constraint violations, ON DELETE SET NULL / CASCADE
--   Step 6  reports: passenger history, audit log, views, package
--
-- Everything runs inside ONE transaction. Nothing is committed: the
-- script ends with ROLLBACK TO SAVEPOINT, so the database is exactly as
-- it was before, and the demo can be run again and again.
-- Errors printed in steps 2-5 are EXPECTED - they are the demo.
-- The script pauses ("Press Enter to continue...") after every scenario and
-- clears the screen before each STEP, so it is meant to be run interactively.
--
-- Usage:  SQL> @09_demo.sql      (run after 00-07, e.g. via run_all.sql)
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
COLUMN seat_no          FORMAT A6
COLUMN seat_class       FORMAT A10
COLUMN seat_status      FORMAT A12
COLUMN seats_left       FORMAT 99      HEADING 'SEATS|LEFT'
COLUMN economy_fare     FORMAT 999,990.00
COLUMN business_fare    FORMAT 999,990.00
COLUMN base_x_2_5       FORMAT 999,990.00
COLUMN booking_id       FORMAT 9999    HEADING 'BOOKING'
COLUMN passenger_name   FORMAT A18
COLUMN flight_no        FORMAT A9
COLUMN booking_status   FORMAT A14
COLUMN payment_status   FORMAT A14
COLUMN amount_paid      FORMAT 999,990.00
COLUMN amount           FORMAT 999,990.00
COLUMN refund_amount    FORMAT 999,990.00
COLUMN total_bookings   FORMAT 999
COLUMN total_payments   FORMAT 999
COLUMN log_id           FORMAT 99999   HEADING 'LOG'
COLUMN action           FORMAT A7
COLUMN old_status       FORMAT A10
COLUMN new_status       FORMAT A10
COLUMN aircraft_id      FORMAT 999     HEADING 'AIRCRAFT'
COLUMN origin           FORMAT A6
COLUMN destination      FORMAT A11
COLUMN airline_name     FORMAT A20
COLUMN net_revenue      FORMAT 9,999,999.99
COLUMN g_booking        FORMAT 9999

PROMPT
PROMPT #####################################################################
PROMPT #  AIRLINE RESERVATION SYSTEM - END-TO-END DEMO
PROMPT #####################################################################

-- everything below can be undone with one ROLLBACK at the end
SAVEPOINT demo_start;

CLEAR SCREEN

-- =====================================================================
PROMPT
PROMPT =====================================================================
PROMPT STEP 0 - Starting state: flight 2 (6E-6105, Mumbai to Bengaluru)
PROMPT =====================================================================
PROMPT Seat map of flight 2. Seats 10A and 10B are booked; 10C was cancelled earlier.
SELECT seat_no, seat_class, status AS seat_status
  FROM seats
 WHERE flight_id = 2
 ORDER BY seat_id;

PROMPT
PROMPT Functions: seats_left() and calculate_fare() (base fare 4200, BUSINESS x 2.5).
SELECT seats_left(2)                    AS seats_left,
       calculate_fare(2, 'ECONOMY')     AS economy_fare,
       calculate_fare(2, 'BUSINESS')    AS business_fare
  FROM dual;

PROMPT
PROMPT Dynamic pricing. Flight 1 is 5/6 full, so BUSINESS costs 15 percent more than
PROMPT base x 2.5. Flight 13 leaves within 48 hours, so ECONOMY carries a 20 percent uplift.
SELECT calculate_fare(1, 'BUSINESS')            AS business_fare,
       ROUND(5800 * 2.5, 2)                     AS base_x_2_5,
       calculate_fare(13, 'ECONOMY')            AS economy_fare
  FROM dual;
PAUSE Press Enter to continue...

CLEAR SCREEN

-- =====================================================================
PROMPT
PROMPT =====================================================================
PROMPT STEP 1 - Successful booking
PROMPT Passenger 16 (Nikhil Bansal) books seat 1B, BUSINESS, on flight 2, paying by UPI.
PROMPT =====================================================================
VARIABLE g_booking NUMBER

BEGIN
  book_ticket(p_passenger_id => 16,
              p_flight_id    => 2,
              p_seat_no      => '1B',
              p_method       => 'UPI',
              p_booking_id   => :g_booking);
END;
/

PRINT g_booking

PROMPT
PROMPT The booking as the passenger sees it (view passenger_itinerary):
SELECT booking_id, passenger_name, flight_no, seat_no, seat_class,
       booking_status, amount_paid, payment_status
  FROM passenger_itinerary
 WHERE booking_id = :g_booking;

PROMPT
PROMPT The seat was flipped to BOOKED by trigger trg_bookings_seat_status, and one
PROMPT seat fewer is left:
SELECT seat_no, status AS seat_status, seats_left(2) AS seats_left
  FROM seats
 WHERE flight_id = 2 AND seat_no = '1B';

PROMPT
PROMPT The audit trigger recorded the INSERT:
SELECT log_id, booking_id, action, old_status, new_status
  FROM booking_audit_log
 WHERE booking_id = :g_booking
 ORDER BY log_id;
PAUSE Press Enter to continue...

CLEAR SCREEN

-- =====================================================================
PROMPT
PROMPT =====================================================================
PROMPT STEP 2 - Double booking is blocked
PROMPT =====================================================================
PROMPT 2a) A raw INSERT for the seat that was just sold. Expect ORA-20102 from trigger
PROMPT     trg_bookings_no_double_booking (the procedure is bypassed, the trigger still protects).
INSERT INTO bookings (passenger_id, seat_id, status)
VALUES (17, (SELECT seat_id FROM seats WHERE flight_id = 2 AND seat_no = '1B'), 'CONFIRMED');
PAUSE Press Enter to continue...

PROMPT
PROMPT 2b) The same attempt through book_ticket. Expect ORA-20004 (checked before any insert).
DECLARE
  v_id bookings.booking_id%TYPE;
BEGIN
  book_ticket(17, 2, '1B', 'CARD', v_id);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Rejected by book_ticket -> ' || SQLERRM);
END;
/
PAUSE Press Enter to continue...

PROMPT
PROMPT 2c) Passenger 16 already holds 1B on flight 2 and now asks for a second seat, 10D.
PROMPT     Expect ORA-20103 from the COMPOUND trigger trg_bookings_one_per_flight, which
PROMPT     counts bookings in its AFTER STATEMENT section to avoid ORA-04091.
DECLARE
  v_id bookings.booking_id%TYPE;
BEGIN
  book_ticket(16, 2, '10D', 'CARD', v_id);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Rejected by trigger -> ' || SQLERRM);
END;
/
PAUSE Press Enter to continue...

CLEAR SCREEN

-- =====================================================================
PROMPT
PROMPT =====================================================================
PROMPT STEP 3 - Rollback on payment failure
PROMPT =====================================================================
PROMPT Before: counts, and the state of seat 10D on flight 2.
SELECT (SELECT COUNT(*) FROM bookings)  AS total_bookings,
       (SELECT COUNT(*) FROM payments)  AS total_payments,
       (SELECT status FROM seats WHERE flight_id = 2 AND seat_no = '10D') AS seat_status
  FROM dual;

PROMPT
PROMPT 3a) Passenger 17 tenders INR 100 for a 4,200 seat. The booking row is inserted first,
PROMPT     the gateway declines (ORA-20007), and book_ticket rolls back to its SAVEPOINT.
DECLARE
  v_id bookings.booking_id%TYPE;
BEGIN
  book_ticket(p_passenger_id => 17, p_flight_id => 2, p_seat_no => '10D',
              p_method => 'CARD', p_booking_id => v_id, p_amount_paid => 100);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Payment failure -> ' || SQLERRM);
END;
/
PAUSE Press Enter to continue...

PROMPT
PROMPT 3b) An unknown payment method is rejected by the CHECK constraint on payments
PROMPT     (ORA-02290) after the booking row exists - and is rolled back the same way.
DECLARE
  v_id bookings.booking_id%TYPE;
BEGIN
  book_ticket(p_passenger_id => 17, p_flight_id => 2, p_seat_no => '10D',
              p_method => 'BITCOIN', p_booking_id => v_id);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Constraint failure -> ' || SQLERRM);
END;
/
PAUSE Press Enter to continue...

PROMPT
PROMPT After: nothing changed - no orphan booking, no payment, seat still AVAILABLE.
SELECT (SELECT COUNT(*) FROM bookings)  AS total_bookings,
       (SELECT COUNT(*) FROM payments)  AS total_payments,
       (SELECT status FROM seats WHERE flight_id = 2 AND seat_no = '10D') AS seat_status
  FROM dual;
PAUSE Press Enter to continue...

CLEAR SCREEN

-- =====================================================================
PROMPT
PROMPT =====================================================================
PROMPT STEP 4 - Cancellation and refunds
PROMPT Refund policy: 90 percent at 72h+ before departure, 50 percent at 24-72h,
PROMPT 10 percent under 24h, and nothing once the flight has departed.
PROMPT =====================================================================
PROMPT 4a) Cancel the booking from step 1. Flight 2 leaves in about 5 days: 90 percent.
DECLARE
  v_refund payments.refund_amount%TYPE;
BEGIN
  cancel_booking(:g_booking, v_refund);
  DBMS_OUTPUT.PUT_LINE('OUT parameter returned to the caller: INR ' || v_refund);
END;
/

PROMPT
PROMPT Booking cancelled, payment marked REFUNDED, seat back to AVAILABLE:
SELECT booking_id, passenger_name, seat_no, booking_status, amount_paid,
       refund_amount, payment_status
  FROM passenger_itinerary
 WHERE booking_id = :g_booking;

SELECT seat_no, status AS seat_status, seats_left(2) AS seats_left
  FROM seats
 WHERE flight_id = 2 AND seat_no = '1B';

PROMPT
PROMPT The audit log now shows the INSERT followed by the status change:
SELECT log_id, booking_id, action, old_status, new_status
  FROM booking_audit_log
 WHERE booking_id = :g_booking
 ORDER BY log_id;
PAUSE Press Enter to continue...

PROMPT
PROMPT 4b) Cancelling it a second time. Expect ORA-20009.
DECLARE
  v_refund payments.refund_amount%TYPE;
BEGIN
  cancel_booking(:g_booking, v_refund);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Rejected -> ' || SQLERRM);
END;
/
PAUSE Press Enter to continue...

PROMPT
PROMPT 4c) 50 percent tier: book and cancel a seat on flight 10 (leaves in about 2 days).
DECLARE
  v_id     bookings.booking_id%TYPE;
  v_refund payments.refund_amount%TYPE;
BEGIN
  book_ticket(16, 10, '10A', 'CARD', v_id);
  cancel_booking(v_id, v_refund);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Rejected -> ' || SQLERRM);
END;
/
PAUSE Press Enter to continue...

PROMPT
PROMPT 4d) 10 percent tier: seeded booking 13 is on flight 13, which leaves about 20 hours
PROMPT     after 02_data.sql was run. (If that was over a day ago the flight has already
PROMPT     departed and you will see ORA-20010 instead - re-run run_all.sql to refresh the dates.)
DECLARE
  v_refund payments.refund_amount%TYPE;
BEGIN
  cancel_booking(13, v_refund);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Rejected -> ' || SQLERRM);
END;
/
PAUSE Press Enter to continue...

PROMPT
PROMPT 4e) Booking 14 is on flight 14, which has already departed. Expect ORA-20010.
DECLARE
  v_refund payments.refund_amount%TYPE;
BEGIN
  cancel_booking(14, v_refund);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Rejected -> ' || SQLERRM);
END;
/
PAUSE Press Enter to continue...

PROMPT
PROMPT 4f) A booking that does not exist. Expect ORA-20008.
DECLARE
  v_refund payments.refund_amount%TYPE;
BEGIN
  cancel_booking(99999, v_refund);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Rejected -> ' || SQLERRM);
END;
/
PAUSE Press Enter to continue...

CLEAR SCREEN

-- =====================================================================
PROMPT
PROMPT =====================================================================
PROMPT STEP 5 - Constraint violations and referential actions
PROMPT Every error below is expected. Each failing statement is undone on its own.
PROMPT =====================================================================
PROMPT 5a) UNIQUE: a second passenger with an existing e-mail. Expect ORA-00001.
INSERT INTO passengers (first_name, last_name, email, phone, date_of_birth, gender)
VALUES ('Test', 'Duplicate', 'aarav.sharma@example.com', '9000000001', DATE '2000-01-01', 'M');
PAUSE Press Enter to continue...

PROMPT
PROMPT 5b) CHECK: a seat class that does not exist. Expect ORA-02290.
INSERT INTO seats (flight_id, seat_no, seat_class)
VALUES (2, '20A', 'LUXURY');
PAUSE Press Enter to continue...

PROMPT
PROMPT 5c) NOT NULL: a passenger without a first name. Expect ORA-01400.
INSERT INTO passengers (first_name, last_name, email, phone, date_of_birth, gender)
VALUES (NULL, 'Nameless', 'nameless@example.com', '9000000002', DATE '2000-01-01', 'F');
PAUSE Press Enter to continue...

PROMPT
PROMPT 5d) FOREIGN KEY: a booking for a passenger that does not exist. Expect ORA-02291.
INSERT INTO bookings (passenger_id, seat_id, status)
VALUES (9999, (SELECT seat_id FROM seats WHERE flight_id = 2 AND seat_no = '1A'), 'CONFIRMED');
PAUSE Press Enter to continue...

PROMPT
PROMPT 5e) TRIGGER: a flight that lands before it takes off. Expect ORA-20101.
INSERT INTO flights (flight_no, airline_id, origin_airport_id, dest_airport_id,
                     departure_time, arrival_time, base_fare)
VALUES ('AI-999', 1, 1, 2, SYSDATE + 10, SYSDATE + 9, 5000);
PAUSE Press Enter to continue...

PROMPT
PROMPT 5f) CHECK: a flight from an airport to itself. Expect ORA-02290 (ck_flights_route).
INSERT INTO flights (flight_no, airline_id, origin_airport_id, dest_airport_id,
                     departure_time, arrival_time, base_fare)
VALUES ('AI-998', 1, 1, 1, SYSDATE + 10, SYSDATE + 11, 5000);
PAUSE Press Enter to continue...

PROMPT
PROMPT 5g) NO ACTION: an airport that flights still use cannot be deleted. Expect ORA-02292.
DELETE FROM airports WHERE airport_id = 1;
PAUSE Press Enter to continue...

PROMPT
PROMPT 5h) NO ACTION on bookings.seat_id: flight 1 has bookings, so deleting it (which would
PROMPT     cascade to its seats) is refused. Expect ORA-02292 (fk_bookings_seat).
DELETE FROM flights WHERE flight_id = 1;
PAUSE Press Enter to continue...

PROMPT
PROMPT 5i) ON DELETE SET NULL: flight 12 is operated by aircraft 15. Deleting the aircraft
PROMPT     keeps the flight and clears its aircraft_id.
SELECT flight_no, aircraft_id FROM flights WHERE flight_id = 12;
DELETE FROM aircraft WHERE aircraft_id = 15;
SELECT flight_no, aircraft_id FROM flights WHERE flight_id = 12;
PAUSE Press Enter to continue...

PROMPT
PROMPT 5j) ON DELETE CASCADE: deleting passenger 15 removes their booking and its payment;
PROMPT     the triggers free seat 144 and write a DELETE row to the audit log.
SELECT (SELECT COUNT(*) FROM bookings WHERE passenger_id = 15) AS total_bookings,
       (SELECT COUNT(*) FROM payments WHERE booking_id = 15)   AS total_payments,
       (SELECT status FROM seats WHERE seat_id = 144)          AS seat_status
  FROM dual;

DELETE FROM passengers WHERE passenger_id = 15;

SELECT (SELECT COUNT(*) FROM bookings WHERE passenger_id = 15) AS total_bookings,
       (SELECT COUNT(*) FROM payments WHERE booking_id = 15)   AS total_payments,
       (SELECT status FROM seats WHERE seat_id = 144)          AS seat_status
  FROM dual;

SELECT log_id, booking_id, action, old_status, new_status
  FROM booking_audit_log
 WHERE action = 'DELETE';
PAUSE Press Enter to continue...

CLEAR SCREEN

-- =====================================================================
PROMPT
PROMPT =====================================================================
PROMPT STEP 6 - Reports
PROMPT =====================================================================
PROMPT 6a) show_passenger_bookings (explicit cursor + DBMS_OUTPUT) for passenger 16:
EXEC show_passenger_bookings(16)
PAUSE Press Enter to continue...

PROMPT
PROMPT 6b) The complete audit trail of this demo session:
SELECT log_id, booking_id, action, old_status, new_status
  FROM booking_audit_log
 WHERE log_id >= (SELECT MIN(log_id) FROM booking_audit_log WHERE booking_id = :g_booking)
 ORDER BY log_id;
PAUSE Press Enter to continue...

PROMPT
PROMPT 6c) View available_seats for flight 2 (what a customer could still book):
SELECT flight_no, origin, destination, seat_no, seat_class
  FROM available_seats
 WHERE flight_id = 2
 ORDER BY seat_id;
PAUSE Press Enter to continue...

PROMPT
PROMPT 6d) View airline_revenue (top 5 by net revenue) reflects the refunds just issued:
SELECT *
  FROM (SELECT airline_name, total_bookings, confirmed_bookings,
               gross_revenue, total_refunds, net_revenue
          FROM airline_revenue
         ORDER BY net_revenue DESC)
 WHERE ROWNUM <= 5;
PAUSE Press Enter to continue...

PROMPT
PROMPT 6e) The same API through the package reservation_pkg:
SELECT reservation_pkg.seats_left(2)               AS seats_left,
       reservation_pkg.calculate_fare(2, 'BUSINESS') AS business_fare
  FROM dual;
PAUSE Press Enter to continue...

CLEAR SCREEN

-- =====================================================================
PROMPT
PROMPT =====================================================================
PROMPT CLEAN-UP - roll back the whole demo so the data is exactly as it was
PROMPT =====================================================================
ROLLBACK TO SAVEPOINT demo_start;

SELECT (SELECT COUNT(*) FROM bookings)  AS total_bookings,
       (SELECT COUNT(*) FROM payments)  AS total_payments
  FROM dual;

PROMPT
PROMPT Demo finished. Expected after clean-up: 18 bookings and 18 payments.
CLEAR COLUMNS

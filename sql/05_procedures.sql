-- =====================================================================
-- 05_procedures.sql  -  Airline Reservation System : stored procedures
--
--   book_ticket             validate -> lock seat -> price -> insert
--                           booking + payment. Any failure rolls back to
--                           a SAVEPOINT taken on entry, so a half-made
--                           booking is never left behind.
--   cancel_booking          cancels a booking, frees the seat and pays
--                           a refund according to refund_percentage().
--   show_passenger_bookings prints a passenger's bookings with an
--                           explicit (parameterised) cursor loop and
--                           DBMS_OUTPUT.
--
-- Transaction control: the procedures never COMMIT. The caller decides
-- when the unit of work is complete (COMMIT) or abandoned (ROLLBACK).
-- On error they roll back only their own work (to their SAVEPOINT) and
-- re-raise the original error to the caller.
--
-- Seat status is flipped by trigger trg_bookings_seat_status
-- (06_triggers.sql). book_ticket / cancel_booking also issue an
-- idempotent UPDATE of the seat, so they stay correct even if the
-- triggers are disabled.
--
-- Error codes are listed in 04_functions.sql.
--
-- Usage:  SQL> @05_procedures.sql
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
PROMPT ==== 05_procedures.sql : creating procedures ====

-- ---------------------------------------------------------------------
-- book_ticket
--   p_seat_no     seat label on that flight, e.g. '10A' (case-insensitive)
--   p_method      CARD | UPI | NETBANKING | WALLET | CASH
--   p_booking_id  OUT - id of the new booking (NULL if it failed)
--   p_amount_paid amount tendered to the payment gateway. Leave NULL to
--                 pay exactly the quoted fare; any other amount is
--                 declined (-20007), which rolls the booking back.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE book_ticket (
  p_passenger_id IN  passengers.passenger_id%TYPE,
  p_flight_id    IN  flights.flight_id%TYPE,
  p_seat_no      IN  seats.seat_no%TYPE,
  p_method       IN  payments.payment_method%TYPE,
  p_booking_id   OUT bookings.booking_id%TYPE,
  p_amount_paid  IN  NUMBER DEFAULT NULL
) AS
  v_count        PLS_INTEGER;
  v_flight_state flights.status%TYPE;
  v_departure    flights.departure_time%TYPE;
  v_seat_id      seats.seat_id%TYPE;
  v_seat_class   seats.seat_class%TYPE;
  v_seat_state   seats.status%TYPE;
  v_fare         payments.amount%TYPE;
  v_tendered     NUMBER;
  v_booking_id   bookings.booking_id%TYPE;
BEGIN
  SAVEPOINT sp_book_ticket;
  p_booking_id := NULL;

  -- 1. passenger must exist
  SELECT COUNT(*) INTO v_count FROM passengers WHERE passenger_id = p_passenger_id;
  IF v_count = 0 THEN
    RAISE_APPLICATION_ERROR(-20005, 'Passenger ' || p_passenger_id || ' does not exist.');
  END IF;

  -- 2. flight must exist and still be open for booking
  BEGIN
    SELECT status, departure_time
      INTO v_flight_state, v_departure
      FROM flights
     WHERE flight_id = p_flight_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20001, 'Flight ' || p_flight_id || ' does not exist.');
  END;

  IF v_flight_state NOT IN ('SCHEDULED', 'DELAYED') OR v_departure <= SYSDATE THEN
    RAISE_APPLICATION_ERROR(-20006,
      'Flight ' || p_flight_id || ' is not open for booking (status ' || v_flight_state ||
      ', departs ' || TO_CHAR(v_departure, 'DD-Mon-YYYY HH24:MI') || ').');
  END IF;

  -- 3. lock the seat row so nobody else can grab it while we book
  BEGIN
    SELECT seat_id, seat_class, status
      INTO v_seat_id, v_seat_class, v_seat_state
      FROM seats
     WHERE flight_id = p_flight_id
       AND seat_no   = UPPER(p_seat_no)
       FOR UPDATE;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20003,
        'Seat ' || p_seat_no || ' does not exist on flight ' || p_flight_id || '.');
  END;

  IF v_seat_state <> 'AVAILABLE' THEN
    RAISE_APPLICATION_ERROR(-20004,
      'Seat ' || UPPER(p_seat_no) || ' on flight ' || p_flight_id || ' is already booked.');
  END IF;

  -- 4. price the seat (before this booking changes the load factor)
  v_fare := calculate_fare(p_flight_id, v_seat_class);

  -- 5. create the booking and mark the seat
  INSERT INTO bookings (passenger_id, seat_id, status)
  VALUES (p_passenger_id, v_seat_id, 'CONFIRMED')
  RETURNING booking_id INTO v_booking_id;

  UPDATE seats
     SET status = 'BOOKED'
   WHERE seat_id = v_seat_id
     AND status <> 'BOOKED';

  -- 6. charge the passenger. A declined payment is raised AFTER the
  --    booking rows exist on purpose: the handler below then has real
  --    work to undo, which is what the SAVEPOINT is for.
  v_tendered := NVL(p_amount_paid, v_fare);
  IF v_tendered <> v_fare THEN
    RAISE_APPLICATION_ERROR(-20007,
      'Payment declined: tendered INR ' || TO_CHAR(v_tendered, 'FM999,999,990.00') ||
      ' but the fare is INR ' || TO_CHAR(v_fare, 'FM999,999,990.00') || '.');
  END IF;

  INSERT INTO payments (booking_id, amount, payment_method, status, transaction_ref)
  VALUES (v_booking_id, v_tendered, p_method, 'SUCCESS',
          'TXN' || TO_CHAR(SYSDATE, 'YYMMDD') || LPAD(v_booking_id, 6, '0'));

  p_booking_id := v_booking_id;
  DBMS_OUTPUT.PUT_LINE('Booking ' || v_booking_id || ' confirmed: flight ' || p_flight_id ||
                       ', seat ' || UPPER(p_seat_no) || ' (' || v_seat_class || '), paid INR ' ||
                       TO_CHAR(v_tendered, 'FM999,999,990.00') || ' by ' || p_method || '.');
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK TO SAVEPOINT sp_book_ticket;   -- undo booking, payment, seat lock
    p_booking_id := NULL;
    RAISE;                                  -- caller sees the original error
END book_ticket;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- cancel_booking
--   p_refund_amount OUT - refund issued in INR (0 if nothing was paid)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE cancel_booking (
  p_booking_id    IN  bookings.booking_id%TYPE,
  p_refund_amount OUT payments.refund_amount%TYPE
) AS
  v_status      bookings.status%TYPE;
  v_seat_id     bookings.seat_id%TYPE;
  v_flight_no   flights.flight_no%TYPE;
  v_departure   flights.departure_time%TYPE;
  v_payment_id  payments.payment_id%TYPE;
  v_paid        payments.amount%TYPE;
  v_hours_left  NUMBER;
  v_pct         NUMBER;
BEGIN
  SAVEPOINT sp_cancel_booking;
  p_refund_amount := 0;

  -- 1. find and lock the booking (only the bookings row is locked)
  BEGIN
    SELECT b.status, b.seat_id, f.flight_no, f.departure_time
      INTO v_status, v_seat_id, v_flight_no, v_departure
      FROM bookings b
      JOIN seats   s ON s.seat_id   = b.seat_id
      JOIN flights f ON f.flight_id = s.flight_id
     WHERE b.booking_id = p_booking_id
       FOR UPDATE OF b.status;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20008, 'Booking ' || p_booking_id || ' does not exist.');
  END;

  -- 2. business rules
  IF v_status = 'CANCELLED' THEN
    RAISE_APPLICATION_ERROR(-20009, 'Booking ' || p_booking_id || ' is already cancelled.');
  END IF;

  v_hours_left := (v_departure - SYSDATE) * 24;
  IF v_hours_left <= 0 THEN
    RAISE_APPLICATION_ERROR(-20010,
      'Flight ' || v_flight_no || ' has already departed; booking ' || p_booking_id ||
      ' cannot be cancelled.');
  END IF;

  v_pct := refund_percentage(v_hours_left);

  -- 3. the payment made for this booking (if any)
  BEGIN
    SELECT payment_id, amount
      INTO v_payment_id, v_paid
      FROM payments
     WHERE booking_id = p_booking_id
       AND status     = 'SUCCESS'
       FOR UPDATE;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_payment_id := NULL;
  END;

  -- 4. cancel the booking and free the seat
  UPDATE bookings
     SET status       = 'CANCELLED',
         cancelled_at = SYSDATE
   WHERE booking_id = p_booking_id;

  UPDATE seats
     SET status = 'AVAILABLE'
   WHERE seat_id = v_seat_id
     AND status <> 'AVAILABLE';

  -- 5. refund
  IF v_payment_id IS NOT NULL THEN
    p_refund_amount := ROUND(v_paid * v_pct, 2);
    UPDATE payments
       SET status        = 'REFUNDED',
           refund_amount = p_refund_amount,
           refund_date   = SYSDATE
     WHERE payment_id = v_payment_id;
  END IF;

  DBMS_OUTPUT.PUT_LINE('Booking ' || p_booking_id || ' (flight ' || v_flight_no ||
                       ') cancelled ' || TO_CHAR(ROUND(v_hours_left, 1), 'FM99990.0') ||
                       ' h before departure. Refund: INR ' ||
                       TO_CHAR(p_refund_amount, 'FM999,999,990.00') ||
                       ' (' || TO_CHAR(v_pct * 100, 'FM990') || '%).');
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK TO SAVEPOINT sp_cancel_booking;
    p_refund_amount := 0;
    RAISE;
END cancel_booking;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- show_passenger_bookings : explicit cursor with a parameter
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE show_passenger_bookings (
  p_passenger_id IN passengers.passenger_id%TYPE
) AS
  CURSOR c_bookings (cp_passenger_id passengers.passenger_id%TYPE) IS
    SELECT b.booking_id,
           b.status         AS booking_status,
           f.flight_no,
           ao.iata_code     AS origin,
           ad.iata_code     AS destination,
           f.departure_time,
           s.seat_no,
           s.seat_class,
           pay.amount       AS amount_paid,
           pay.refund_amount
      FROM bookings b
      JOIN seats    s   ON s.seat_id     = b.seat_id
      JOIN flights  f   ON f.flight_id   = s.flight_id
      JOIN airports ao  ON ao.airport_id = f.origin_airport_id
      JOIN airports ad  ON ad.airport_id = f.dest_airport_id
      LEFT JOIN payments pay ON pay.booking_id = b.booking_id
     WHERE b.passenger_id = cp_passenger_id
     ORDER BY f.departure_time, b.booking_id;

  v_row    c_bookings%ROWTYPE;
  v_name   VARCHAR2(70);
  v_count  PLS_INTEGER := 0;
  v_net    NUMBER := 0;
BEGIN
  BEGIN
    SELECT first_name || ' ' || last_name
      INTO v_name
      FROM passengers
     WHERE passenger_id = p_passenger_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20005, 'Passenger ' || p_passenger_id || ' does not exist.');
  END;

  DBMS_OUTPUT.PUT_LINE('Bookings of ' || v_name || ' (passenger ' || p_passenger_id || ')');
  DBMS_OUTPUT.PUT_LINE(RPAD('-', 84, '-'));
  DBMS_OUTPUT.PUT_LINE(RPAD('BOOKING', 9) || RPAD('FLIGHT', 10) || RPAD('ROUTE', 9) ||
                       RPAD('DEPARTURE', 19) || RPAD('SEAT', 14) || RPAD('STATUS', 11) ||
                       LPAD('PAID (INR)', 12));
  DBMS_OUTPUT.PUT_LINE(RPAD('-', 84, '-'));

  OPEN c_bookings(p_passenger_id);
  LOOP
    FETCH c_bookings INTO v_row;
    EXIT WHEN c_bookings%NOTFOUND;

    v_count := v_count + 1;
    v_net   := v_net + NVL(v_row.amount_paid, 0) - NVL(v_row.refund_amount, 0);

    DBMS_OUTPUT.PUT_LINE(
      RPAD(v_row.booking_id, 9) ||
      RPAD(v_row.flight_no, 10) ||
      RPAD(v_row.origin || '-' || v_row.destination, 9) ||
      RPAD(TO_CHAR(v_row.departure_time, 'DD-Mon-YYYY HH24:MI'), 19) ||
      RPAD(v_row.seat_no || ' ' || INITCAP(v_row.seat_class), 14) ||
      RPAD(v_row.booking_status, 11) ||
      LPAD(TO_CHAR(NVL(v_row.amount_paid, 0), 'FM999,999,990.00'), 12));
  END LOOP;
  CLOSE c_bookings;

  IF v_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('No bookings found.');
  ELSE
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 84, '-'));
    DBMS_OUTPUT.PUT_LINE(v_count || ' booking(s). Net spend after refunds: INR ' ||
                         TO_CHAR(v_net, 'FM999,999,990.00'));
  END IF;
END show_passenger_bookings;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- Check that everything compiled (the database starts with no bookings,
-- so the procedures are exercised by the first real booking)
-- ---------------------------------------------------------------------
PROMPT
PROMPT Procedures installed:
COLUMN object_name FORMAT A28
COLUMN status      FORMAT A8
SELECT object_name, status FROM user_objects WHERE object_type = 'PROCEDURE' ORDER BY object_name;
CLEAR COLUMNS

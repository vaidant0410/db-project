-- =====================================================================
-- 07_package.sql  -  Airline Reservation System : reservation_pkg
--
-- Bundles the booking API into one package:
--   reservation_pkg.calculate_fare / seats_left / refund_percentage
--   reservation_pkg.book_ticket / cancel_booking / show_passenger_bookings
-- Signatures and behaviour match the standalone objects from 04 and 05,
-- so either style can be used:
--     EXEC book_ticket(...)                 -- standalone
--     EXEC reservation_pkg.book_ticket(...) -- packaged
--
-- Why the logic appears twice
--   Inside a package body, a call to book_ticket() resolves to the
--   package's own book_ticket, so the package cannot simply forward to
--   the standalone procedure of the same name. It therefore carries its
--   own copy of the code. In a real system you would keep only the
--   package and drop the standalone versions.
--
-- Package advantages worth mentioning in the viva
--   * one namespace and one public interface (the spec)
--   * private constants (fare / refund policy) hidden in the body
--   * the body can be recompiled without invalidating callers, as long
--     as the spec does not change
--
-- Custom error codes: see 04_functions.sql.
--
-- Usage:  SQL> @07_package.sql
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
PROMPT ==== 07_package.sql : creating package reservation_pkg ====

-- ---------------------------------------------------------------------
-- Specification (the public interface)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE reservation_pkg AS

  -- price of one seat: base fare x class multiplier, +15 % when the
  -- flight is 75 % full, +20 % within 48 hours of departure
  FUNCTION calculate_fare (
    p_flight_id  IN flights.flight_id%TYPE,
    p_seat_class IN seats.seat_class%TYPE
  ) RETURN NUMBER;

  -- number of AVAILABLE seats on a flight
  FUNCTION seats_left (
    p_flight_id IN flights.flight_id%TYPE
  ) RETURN NUMBER;

  -- refund fraction for a cancellation this many hours before departure
  FUNCTION refund_percentage (
    p_hours_before_departure IN NUMBER
  ) RETURN NUMBER;

  -- atomic booking: booking + payment + seat, or nothing
  PROCEDURE book_ticket (
    p_passenger_id IN  passengers.passenger_id%TYPE,
    p_flight_id    IN  flights.flight_id%TYPE,
    p_seat_no      IN  seats.seat_no%TYPE,
    p_method       IN  payments.payment_method%TYPE,
    p_booking_id   OUT bookings.booking_id%TYPE,
    p_amount_paid  IN  NUMBER DEFAULT NULL
  );

  -- cancel a booking, free the seat, refund per refund_percentage
  PROCEDURE cancel_booking (
    p_booking_id    IN  bookings.booking_id%TYPE,
    p_refund_amount OUT payments.refund_amount%TYPE
  );

  -- print a passenger's bookings (DBMS_OUTPUT)
  PROCEDURE show_passenger_bookings (
    p_passenger_id IN passengers.passenger_id%TYPE
  );

END reservation_pkg;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- Body (the implementation)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY reservation_pkg AS

  -- private policy constants
  c_high_load          CONSTANT NUMBER := 0.75;   -- share of seats booked
  c_high_load_uplift   CONSTANT NUMBER := 1.15;
  c_last_minute_hrs    CONSTANT NUMBER := 48;
  c_last_minute_uplift CONSTANT NUMBER := 1.20;

  -- -------------------------------------------------------------------
  FUNCTION calculate_fare (
    p_flight_id  IN flights.flight_id%TYPE,
    p_seat_class IN seats.seat_class%TYPE
  ) RETURN NUMBER IS
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
                    END;
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

  -- -------------------------------------------------------------------
  FUNCTION seats_left (
    p_flight_id IN flights.flight_id%TYPE
  ) RETURN NUMBER IS
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

  -- -------------------------------------------------------------------
  FUNCTION refund_percentage (
    p_hours_before_departure IN NUMBER
  ) RETURN NUMBER IS
  BEGIN
    RETURN CASE
             WHEN p_hours_before_departure >= 72 THEN 0.90
             WHEN p_hours_before_departure >= 24 THEN 0.50
             WHEN p_hours_before_departure >   0 THEN 0.10
             ELSE 0
           END;
  END refund_percentage;

  -- -------------------------------------------------------------------
  PROCEDURE book_ticket (
    p_passenger_id IN  passengers.passenger_id%TYPE,
    p_flight_id    IN  flights.flight_id%TYPE,
    p_seat_no      IN  seats.seat_no%TYPE,
    p_method       IN  payments.payment_method%TYPE,
    p_booking_id   OUT bookings.booking_id%TYPE,
    p_amount_paid  IN  NUMBER DEFAULT NULL
  ) IS
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
    SAVEPOINT sp_pkg_book_ticket;
    p_booking_id := NULL;

    SELECT COUNT(*) INTO v_count FROM passengers WHERE passenger_id = p_passenger_id;
    IF v_count = 0 THEN
      RAISE_APPLICATION_ERROR(-20005, 'Passenger ' || p_passenger_id || ' does not exist.');
    END IF;

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

    v_fare := calculate_fare(p_flight_id, v_seat_class);   -- the package's own function

    INSERT INTO bookings (passenger_id, seat_id, status)
    VALUES (p_passenger_id, v_seat_id, 'CONFIRMED')
    RETURNING booking_id INTO v_booking_id;

    UPDATE seats
       SET status = 'BOOKED'
     WHERE seat_id = v_seat_id
       AND status <> 'BOOKED';

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
      ROLLBACK TO SAVEPOINT sp_pkg_book_ticket;
      p_booking_id := NULL;
      RAISE;
  END book_ticket;

  -- -------------------------------------------------------------------
  PROCEDURE cancel_booking (
    p_booking_id    IN  bookings.booking_id%TYPE,
    p_refund_amount OUT payments.refund_amount%TYPE
  ) IS
    v_status      bookings.status%TYPE;
    v_seat_id     bookings.seat_id%TYPE;
    v_flight_no   flights.flight_no%TYPE;
    v_departure   flights.departure_time%TYPE;
    v_payment_id  payments.payment_id%TYPE;
    v_paid        payments.amount%TYPE;
    v_hours_left  NUMBER;
    v_pct         NUMBER;
  BEGIN
    SAVEPOINT sp_pkg_cancel_booking;
    p_refund_amount := 0;

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

    IF v_status = 'CANCELLED' THEN
      RAISE_APPLICATION_ERROR(-20009, 'Booking ' || p_booking_id || ' is already cancelled.');
    END IF;

    v_hours_left := (v_departure - SYSDATE) * 24;
    IF v_hours_left <= 0 THEN
      RAISE_APPLICATION_ERROR(-20010,
        'Flight ' || v_flight_no || ' has already departed; booking ' || p_booking_id ||
        ' cannot be cancelled.');
    END IF;

    v_pct := refund_percentage(v_hours_left);              -- the package's own function

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

    UPDATE bookings
       SET status       = 'CANCELLED',
           cancelled_at = SYSDATE
     WHERE booking_id = p_booking_id;

    UPDATE seats
       SET status = 'AVAILABLE'
     WHERE seat_id = v_seat_id
       AND status <> 'AVAILABLE';

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
      ROLLBACK TO SAVEPOINT sp_pkg_cancel_booking;
      p_refund_amount := 0;
      RAISE;
  END cancel_booking;

  -- -------------------------------------------------------------------
  PROCEDURE show_passenger_bookings (
    p_passenger_id IN passengers.passenger_id%TYPE
  ) IS
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

END reservation_pkg;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- Self-test (read-only)
-- ---------------------------------------------------------------------
PROMPT
PROMPT Self-test: packaged functions
COLUMN fare       FORMAT 999,990.00
COLUMN seats_left FORMAT 99  HEADING 'SEATS|LEFT'
SELECT reservation_pkg.seats_left(2)                       AS seats_left,
       reservation_pkg.calculate_fare(2, 'BUSINESS')       AS fare,
       reservation_pkg.refund_percentage(30)               AS refund_at_30h
  FROM dual;
CLEAR COLUMNS

PROMPT
PROMPT Self-test: reservation_pkg.show_passenger_bookings(2)
EXEC reservation_pkg.show_passenger_bookings(2)

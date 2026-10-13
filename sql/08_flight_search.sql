-- =====================================================================
-- 08_flight_search.sql  -  Airline Reservation System : search and book
--
-- flight_search_pkg lets a customer fly from any airport to any other
-- airport without the route having been scheduled by hand:
--
--   search_flights    the flights for a route, date and class. The first
--                     search for a route and day generates 4-7 flights
--                     (ensure_flights), so every search has options.
--   seat_map          every seat on a flight with its class, state, fare
--   quick_book        book with just name, e-mail and phone: the
--                     passenger is found or created, a seat is picked if
--                     none was chosen, then book_ticket does the booking
--   find_booking      a booking, looked up by booking id + e-mail
--   cancel_my_booking cancel a booking, checked by booking id + e-mail
--   quick_book_round_trip  two quick_book calls under one savepoint:
--                     both legs are booked, or neither
--   my_bookings       every booking made with an e-mail, checked by phone
--
-- How flights are generated (ensure_flights)
--   * distance  : great-circle distance between the two airports
--   * duration  : 30 min + distance at 800 km/h, rounded to 5 minutes
--   * airlines  : carriers of the route's countries (domestic route:
--                 the country's own airlines), plus GLOBAL carriers on
--                 international routes. Low-cost carriers (fare_factor
--                 under 0.90) do not fly routes longer than 5,000 km.
--   * base fare : (1,500 + 4.8 INR per km) x airline fare_factor,
--                 +/- up to 15 %, rounded to 10 INR
--   * seats     : 2 business rows + 10 economy rows (+ 1 first-class
--                 row from 4,000 km); 15-80 % of them already sold
--                 through other channels, so the seat map looks real
--   * DBMS_RANDOM is seeded with route + date, so the same search
--     always produces the same flights.
--   Generated flights are committed in an autonomous transaction: they
--   are timetable data and stay even if the caller rolls back.
--
-- New error codes
--   -20011 unknown airport code
--   -20012 origin and destination are the same airport
--   -20013 date outside the booking window (today to 365 days ahead)
--   -20014 no seats left in that class
--   -20015 no booking with that id for that e-mail
--   -20016 first and last name are required
--   -20017 invalid e-mail address
--   -20018 invalid phone number
--   -20019 return flight leaves before the outbound flight lands
--   -20020 no bookings for that e-mail and phone number
--
-- Usage:  SQL> @08_flight_search.sql
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
PROMPT ==== 08_flight_search.sql : creating flight_search_pkg ====

-- ---------------------------------------------------------------------
-- Package specification
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE flight_search_pkg AS

  -- great-circle distance between two airports, in km
  FUNCTION distance_km (
    p_from IN airports.iata_code%TYPE,
    p_to   IN airports.iata_code%TYPE
  ) RETURN NUMBER;

  -- make sure the route has flights on that day (generates them if not)
  PROCEDURE ensure_flights (
    p_origin IN airports.iata_code%TYPE,
    p_dest   IN airports.iata_code%TYPE,
    p_date   IN DATE
  );

  -- flights for a route and day, priced for one seat of p_class
  PROCEDURE search_flights (
    p_origin  IN  airports.iata_code%TYPE,
    p_dest    IN  airports.iata_code%TYPE,
    p_date    IN  DATE,
    p_class   IN  seats.seat_class%TYPE DEFAULT 'ECONOMY',
    p_results OUT SYS_REFCURSOR
  );

  -- every seat of a flight: seat_no, class, status, row, letter, fare
  PROCEDURE seat_map (
    p_flight_id IN  flights.flight_id%TYPE,
    p_results   OUT SYS_REFCURSOR
  );

  -- book with only name, e-mail and phone. p_seat_no NULL = pick the
  -- first free seat of p_seat_class. Never commits: the caller decides.
  PROCEDURE quick_book (
    p_first_name IN  passengers.first_name%TYPE,
    p_last_name  IN  passengers.last_name%TYPE,
    p_email      IN  passengers.email%TYPE,
    p_phone      IN  VARCHAR2,
    p_flight_id  IN  flights.flight_id%TYPE,
    p_seat_class IN  seats.seat_class%TYPE,
    p_seat_no    IN  seats.seat_no%TYPE,
    p_method     IN  payments.payment_method%TYPE,
    p_booking_id OUT bookings.booking_id%TYPE,
    p_seat_out   OUT seats.seat_no%TYPE,
    p_amount     OUT payments.amount%TYPE
  );

  -- one booking with its flight, seat and payment
  PROCEDURE find_booking (
    p_booking_id IN  bookings.booking_id%TYPE,
    p_email      IN  passengers.email%TYPE,
    p_result     OUT SYS_REFCURSOR
  );

  -- cancel_booking, after checking the e-mail matches the booking
  PROCEDURE cancel_my_booking (
    p_booking_id    IN  bookings.booking_id%TYPE,
    p_email         IN  passengers.email%TYPE,
    p_refund_amount OUT payments.refund_amount%TYPE
  );

  -- round trip: both legs are booked, or neither (one savepoint around
  -- two quick_book calls). The return must leave after the outbound lands.
  PROCEDURE quick_book_round_trip (
    p_first_name  IN  passengers.first_name%TYPE,
    p_last_name   IN  passengers.last_name%TYPE,
    p_email       IN  passengers.email%TYPE,
    p_phone       IN  VARCHAR2,
    p_out_flight  IN  flights.flight_id%TYPE,
    p_out_class   IN  seats.seat_class%TYPE,
    p_out_seat    IN  seats.seat_no%TYPE,
    p_ret_flight  IN  flights.flight_id%TYPE,
    p_ret_class   IN  seats.seat_class%TYPE,
    p_ret_seat    IN  seats.seat_no%TYPE,
    p_method      IN  payments.payment_method%TYPE,
    p_out_booking OUT bookings.booking_id%TYPE,
    p_out_seat_no OUT seats.seat_no%TYPE,
    p_out_amount  OUT payments.amount%TYPE,
    p_ret_booking OUT bookings.booking_id%TYPE,
    p_ret_seat_no OUT seats.seat_no%TYPE,
    p_ret_amount  OUT payments.amount%TYPE
  );

  -- every booking made with an e-mail (all travellers on it), past and
  -- future. The phone number must match one of them: -20020 otherwise.
  PROCEDURE my_bookings (
    p_email   IN  passengers.email%TYPE,
    p_phone   IN  VARCHAR2,
    p_results OUT SYS_REFCURSOR
  );

END flight_search_pkg;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- Package body
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY flight_search_pkg AS

  c_min_options   CONSTANT PLS_INTEGER := 4;    -- flights per route and day
  c_max_options   CONSTANT PLS_INTEGER := 7;
  c_window_days   CONSTANT PLS_INTEGER := 365;  -- how far ahead one can book
  c_cruise_kmh    CONSTANT NUMBER      := 800;
  c_taxi_minutes  CONSTANT NUMBER      := 30;
  c_fare_fixed    CONSTANT NUMBER      := 1500; -- INR
  c_fare_per_km   CONSTANT NUMBER      := 4.8;  -- INR
  c_first_from_km CONSTANT NUMBER      := 4000; -- long-haul flights get a first-class row
  c_lcc_max_km    CONSTANT NUMBER      := 5000; -- low-cost carriers stay below this
  c_lcc_factor    CONSTANT NUMBER      := 0.90; -- fare_factor below this = low-cost

  TYPE t_airlines IS TABLE OF airlines%ROWTYPE;

  -- airport by IATA code, or -20011
  FUNCTION airport_row (p_code IN VARCHAR2) RETURN airports%ROWTYPE IS
    v_row airports%ROWTYPE;
  BEGIN
    SELECT * INTO v_row FROM airports WHERE iata_code = UPPER(TRIM(p_code));
    RETURN v_row;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20011, 'Unknown airport ''' || p_code || '''.');
  END airport_row;

  -- haversine formula, earth radius 6,371 km
  FUNCTION haversine (p_lat1 NUMBER, p_lon1 NUMBER, p_lat2 NUMBER, p_lon2 NUMBER) RETURN NUMBER IS
    c_rad CONSTANT NUMBER := ACOS(-1) / 180;
    v_a   NUMBER;
  BEGIN
    v_a := POWER(SIN((p_lat2 - p_lat1) * c_rad / 2), 2)
         + COS(p_lat1 * c_rad) * COS(p_lat2 * c_rad)
         * POWER(SIN((p_lon2 - p_lon1) * c_rad / 2), 2);
    RETURN 2 * 6371 * ASIN(SQRT(v_a));
  END haversine;

  FUNCTION distance_km (
    p_from IN airports.iata_code%TYPE,
    p_to   IN airports.iata_code%TYPE
  ) RETURN NUMBER IS
    v_a airports%ROWTYPE := airport_row(p_from);
    v_b airports%ROWTYPE := airport_row(p_to);
  BEGIN
    RETURN ROUND(haversine(v_a.latitude, v_a.longitude, v_b.latitude, v_b.longitude));
  END distance_km;

  -- seat inventory for a new flight; some seats are already sold
  PROCEDURE add_seats (p_flight_id IN flights.flight_id%TYPE, p_km IN NUMBER) IS
    v_row  PLS_INTEGER := 0;
    v_sold NUMBER      := DBMS_RANDOM.VALUE(0.15, 0.80);

    PROCEDURE add_row (p_class IN VARCHAR2, p_letters IN VARCHAR2) IS
    BEGIN
      v_row := v_row + 1;
      FOR i IN 1 .. LENGTH(p_letters) LOOP
        INSERT INTO seats (flight_id, seat_no, seat_class, status)
        VALUES (p_flight_id, v_row || SUBSTR(p_letters, i, 1), p_class,
                CASE WHEN DBMS_RANDOM.VALUE < v_sold THEN 'BOOKED' ELSE 'AVAILABLE' END);
      END LOOP;
    END add_row;
  BEGIN
    IF p_km >= c_first_from_km THEN
      add_row('FIRST', 'AF');
    END IF;
    add_row('BUSINESS', 'ACDF');
    add_row('BUSINESS', 'ACDF');
    FOR r IN 1 .. 10 LOOP
      add_row('ECONOMY', 'ABCDEF');
    END LOOP;
  END add_seats;

  PROCEDURE ensure_flights (
    p_origin IN airports.iata_code%TYPE,
    p_dest   IN airports.iata_code%TYPE,
    p_date   IN DATE
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_o        airports%ROWTYPE;
    v_d        airports%ROWTYPE;
    v_day      DATE := TRUNC(p_date);
    v_have     PLS_INTEGER;
    v_target   PLS_INTEGER;
    v_km       NUMBER;
    v_minutes  NUMBER;
    v_home     t_airlines;   -- carriers of the route's own countries
    v_global   t_airlines;   -- carriers that fly anywhere
    v_al       airlines%ROWTYPE;
    v_dep      DATE;
    v_fare     flights.base_fare%TYPE;
    v_no       flights.flight_no%TYPE;
    v_taken    PLS_INTEGER;
    v_aircraft aircraft.aircraft_id%TYPE;
    v_id       flights.flight_id%TYPE;
    v_lock     airports.airport_id%TYPE;
    v_used     VARCHAR2(400) := ',';   -- airline codes already on this route today
  BEGIN
    v_o := airport_row(p_origin);
    v_d := airport_row(p_dest);

    IF v_o.airport_id = v_d.airport_id THEN
      RAISE_APPLICATION_ERROR(-20012, 'Origin and destination are the same airport.');
    END IF;
    IF p_date IS NULL OR v_day < TRUNC(SYSDATE) OR v_day > TRUNC(SYSDATE) + c_window_days THEN
      RAISE_APPLICATION_ERROR(-20013,
        'Flights can be searched from today up to ' || c_window_days || ' days ahead.');
    END IF;

    -- one session at a time generates flights out of an airport
    SELECT airport_id INTO v_lock FROM airports WHERE airport_id = v_o.airport_id FOR UPDATE;

    SELECT COUNT(*)
      INTO v_have
      FROM flights
     WHERE origin_airport_id = v_o.airport_id
       AND dest_airport_id   = v_d.airport_id
       AND departure_time   >= v_day
       AND departure_time    < v_day + 1;

    IF v_have >= c_min_options THEN
      COMMIT;                                   -- releases the lock
      RETURN;
    END IF;

    DBMS_RANDOM.SEED(v_o.iata_code || v_d.iata_code || TO_CHAR(v_day, 'YYYYMMDD'));

    v_km      := haversine(v_o.latitude, v_o.longitude, v_d.latitude, v_d.longitude);
    v_minutes := GREATEST(45, ROUND((c_taxi_minutes + v_km / c_cruise_kmh * 60) / 5) * 5);

    IF v_o.country = v_d.country THEN
      SELECT * BULK COLLECT INTO v_home
        FROM airlines
       WHERE country = v_o.country
         AND (v_km <= c_lcc_max_km OR fare_factor >= c_lcc_factor)
       ORDER BY airline_id;
      v_global := t_airlines();
    ELSE
      SELECT * BULK COLLECT INTO v_home
        FROM airlines
       WHERE network <> 'DOMESTIC' AND country IN (v_o.country, v_d.country)
         AND (v_km <= c_lcc_max_km OR fare_factor >= c_lcc_factor)
       ORDER BY airline_id;
      SELECT * BULK COLLECT INTO v_global
        FROM airlines
       WHERE network = 'GLOBAL' AND country NOT IN (v_o.country, v_d.country)
       ORDER BY airline_id;
    END IF;
    IF v_home.COUNT = 0 AND v_global.COUNT = 0 THEN
      SELECT * BULK COLLECT INTO v_global
        FROM airlines WHERE network = 'GLOBAL' ORDER BY airline_id;
    END IF;

    v_target := TRUNC(DBMS_RANDOM.VALUE(c_min_options, c_max_options + 1));

    FOR i IN 1 .. v_target - v_have LOOP
      -- 60 % home carriers, 40 % global carriers; up to 4 draws to find
      -- an airline that is not on the route yet, so the options vary
      FOR attempt IN 1 .. 4 LOOP
        IF v_home.COUNT > 0 AND (v_global.COUNT = 0 OR DBMS_RANDOM.VALUE < 0.6) THEN
          v_al := v_home(TRUNC(DBMS_RANDOM.VALUE(1, v_home.COUNT + 1)));
        ELSE
          v_al := v_global(TRUNC(DBMS_RANDOM.VALUE(1, v_global.COUNT + 1)));
        END IF;
        EXIT WHEN INSTR(v_used, ',' || v_al.iata_code || ',') = 0;
      END LOOP;
      v_used := v_used || v_al.iata_code || ',';

      -- departure between 05:00 and 23:30, on a 5-minute grid
      v_dep  := v_day + TRUNC(DBMS_RANDOM.VALUE(60, 283)) * 5 / 1440;
      v_fare := ROUND((c_fare_fixed + v_km * c_fare_per_km) * v_al.fare_factor
                      * DBMS_RANDOM.VALUE(0.85, 1.15), -1);

      -- flight number unique for that departure time
      LOOP
        v_no := v_al.iata_code || '-' || TRUNC(DBMS_RANDOM.VALUE(100, 10000));
        SELECT COUNT(*) INTO v_taken FROM flights WHERE flight_no = v_no AND departure_time = v_dep;
        EXIT WHEN v_taken = 0;
      END LOOP;

      BEGIN
        SELECT aircraft_id INTO v_aircraft
          FROM (SELECT aircraft_id FROM aircraft
                 WHERE airline_id = v_al.airline_id AND status = 'ACTIVE'
                 ORDER BY aircraft_id)
         WHERE ROWNUM = 1;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN v_aircraft := NULL;
      END;

      -- a slot that has already gone (searching for today) is skipped
      IF v_dep > SYSDATE + 2 / 24 THEN
        INSERT INTO flights (flight_no, airline_id, aircraft_id, origin_airport_id, dest_airport_id,
                             departure_time, arrival_time, base_fare, status)
        VALUES (v_no, v_al.airline_id, v_aircraft, v_o.airport_id, v_d.airport_id,
                v_dep, v_dep + (v_minutes + TRUNC(DBMS_RANDOM.VALUE(-2, 3)) * 5) / 1440,
                v_fare, CASE WHEN DBMS_RANDOM.VALUE < 0.08 THEN 'DELAYED' ELSE 'SCHEDULED' END)
        RETURNING flight_id INTO v_id;

        add_seats(v_id, v_km);
      END IF;
    END LOOP;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;            -- an autonomous transaction must end before it returns
      RAISE;
  END ensure_flights;

  PROCEDURE search_flights (
    p_origin  IN  airports.iata_code%TYPE,
    p_dest    IN  airports.iata_code%TYPE,
    p_date    IN  DATE,
    p_class   IN  seats.seat_class%TYPE DEFAULT 'ECONOMY',
    p_results OUT SYS_REFCURSOR
  ) IS
    v_class seats.seat_class%TYPE := UPPER(NVL(p_class, 'ECONOMY'));
  BEGIN
    IF v_class NOT IN ('ECONOMY', 'BUSINESS', 'FIRST') THEN
      RAISE_APPLICATION_ERROR(-20002,
        'Invalid seat class ''' || p_class || '''. Use ECONOMY, BUSINESS or FIRST.');
    END IF;

    ensure_flights(p_origin, p_dest, p_date);

    OPEN p_results FOR
      SELECT f.flight_id,
             f.flight_no,
             al.iata_code   AS airline_code,
             al.airline_name,
             o.iata_code    AS origin,
             o.city         AS origin_city,
             d.iata_code    AS destination,
             d.city         AS destination_city,
             f.departure_time,
             f.arrival_time,
             ROUND((f.arrival_time - f.departure_time) * 1440) AS duration_min,
             f.status,
             (SELECT COUNT(*) FROM seats s
               WHERE s.flight_id = f.flight_id AND s.seat_class = v_class
                 AND s.status = 'AVAILABLE')                   AS seats_left,
             calculate_fare(f.flight_id, v_class)              AS fare
        FROM flights f
        JOIN airlines al ON al.airline_id = f.airline_id
        JOIN airports o  ON o.airport_id  = f.origin_airport_id
        JOIN airports d  ON d.airport_id  = f.dest_airport_id
       WHERE o.iata_code = UPPER(TRIM(p_origin))
         AND d.iata_code = UPPER(TRIM(p_dest))
         AND f.departure_time >= TRUNC(p_date)
         AND f.departure_time <  TRUNC(p_date) + 1
         AND f.departure_time >  SYSDATE
         AND f.status IN ('SCHEDULED', 'DELAYED')
         AND EXISTS (SELECT 1 FROM seats s
                      WHERE s.flight_id = f.flight_id AND s.seat_class = v_class)
       ORDER BY f.departure_time;
  END search_flights;

  PROCEDURE seat_map (
    p_flight_id IN  flights.flight_id%TYPE,
    p_results   OUT SYS_REFCURSOR
  ) IS
    v_count PLS_INTEGER;
  BEGIN
    SELECT COUNT(*) INTO v_count FROM flights WHERE flight_id = p_flight_id;
    IF v_count = 0 THEN
      RAISE_APPLICATION_ERROR(-20001, 'Flight ' || p_flight_id || ' does not exist.');
    END IF;

    OPEN p_results FOR
      SELECT s.seat_no,
             s.seat_class,
             s.status,
             TO_NUMBER(REGEXP_SUBSTR(s.seat_no, '^[0-9]+')) AS seat_row,
             REGEXP_SUBSTR(s.seat_no, '[A-Z]$')             AS seat_letter,
             calculate_fare(s.flight_id, s.seat_class)      AS fare
        FROM seats s
       WHERE s.flight_id = p_flight_id
       ORDER BY seat_row, seat_letter;
  END seat_map;

  PROCEDURE quick_book (
    p_first_name IN  passengers.first_name%TYPE,
    p_last_name  IN  passengers.last_name%TYPE,
    p_email      IN  passengers.email%TYPE,
    p_phone      IN  VARCHAR2,
    p_flight_id  IN  flights.flight_id%TYPE,
    p_seat_class IN  seats.seat_class%TYPE,
    p_seat_no    IN  seats.seat_no%TYPE,
    p_method     IN  payments.payment_method%TYPE,
    p_booking_id OUT bookings.booking_id%TYPE,
    p_seat_out   OUT seats.seat_no%TYPE,
    p_amount     OUT payments.amount%TYPE
  ) IS
    v_first     passengers.first_name%TYPE := TRIM(p_first_name);
    v_last      passengers.last_name%TYPE  := TRIM(p_last_name);
    v_email     passengers.email%TYPE      := LOWER(TRIM(p_email));
    v_phone     VARCHAR2(40)               := REGEXP_REPLACE(p_phone, '[^0-9+]', '');
    v_class     seats.seat_class%TYPE      := UPPER(NVL(p_seat_class, 'ECONOMY'));
    v_seat      seats.seat_no%TYPE         := UPPER(TRIM(p_seat_no));
    v_passenger passengers.passenger_id%TYPE;
    v_count     PLS_INTEGER;
  BEGIN
    SAVEPOINT sp_quick_book;
    p_booking_id := NULL;
    p_seat_out   := NULL;
    p_amount     := NULL;

    -- 1. contact details
    IF v_first IS NULL OR v_last IS NULL THEN
      RAISE_APPLICATION_ERROR(-20016, 'First and last name are required.');
    END IF;
    IF v_email IS NULL OR NOT REGEXP_LIKE(v_email, '^[^@ ]+@[^@ ]+\.[^@ ]+$') THEN
      RAISE_APPLICATION_ERROR(-20017, 'Invalid e-mail address ''' || p_email || '''.');
    END IF;
    IF v_phone IS NULL OR NOT REGEXP_LIKE(v_phone, '^\+?[0-9]{7,15}$') THEN
      RAISE_APPLICATION_ERROR(-20018, 'Invalid phone number ''' || p_phone || '''.');
    END IF;

    SELECT COUNT(*) INTO v_count FROM flights WHERE flight_id = p_flight_id;
    IF v_count = 0 THEN
      RAISE_APPLICATION_ERROR(-20001, 'Flight ' || p_flight_id || ' does not exist.');
    END IF;

    -- 2. find the passenger (same e-mail + name) or create one
    BEGIN
      SELECT passenger_id INTO v_passenger
        FROM passengers
       WHERE LOWER(email)      = v_email
         AND LOWER(first_name) = LOWER(v_first)
         AND LOWER(last_name)  = LOWER(v_last);
      UPDATE passengers SET phone = v_phone WHERE passenger_id = v_passenger;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        INSERT INTO passengers (first_name, last_name, email, phone)
        VALUES (v_first, v_last, v_email, v_phone)
        RETURNING passenger_id INTO v_passenger;
    END;

    -- 3. no seat chosen: the first free one in the class, front to back
    IF v_seat IS NULL THEN
      IF v_class NOT IN ('ECONOMY', 'BUSINESS', 'FIRST') THEN
        RAISE_APPLICATION_ERROR(-20002,
          'Invalid seat class ''' || p_seat_class || '''. Use ECONOMY, BUSINESS or FIRST.');
      END IF;
      BEGIN
        SELECT seat_no INTO v_seat
          FROM (SELECT seat_no FROM seats
                 WHERE flight_id = p_flight_id AND seat_class = v_class AND status = 'AVAILABLE'
                 ORDER BY TO_NUMBER(REGEXP_SUBSTR(seat_no, '^[0-9]+')), seat_no)
         WHERE ROWNUM = 1;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          RAISE_APPLICATION_ERROR(-20014,
            'No ' || LOWER(v_class) || ' seats left on flight ' || p_flight_id || '.');
      END;
    END IF;

    -- 4. the booking itself: seat lock, fare, payment, all-or-nothing
    book_ticket(v_passenger, p_flight_id, v_seat, UPPER(p_method), p_booking_id);

    SELECT amount INTO p_amount FROM payments WHERE booking_id = p_booking_id;
    p_seat_out := v_seat;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO SAVEPOINT sp_quick_book;   -- also undoes a new passenger row
      p_booking_id := NULL;
      p_seat_out   := NULL;
      p_amount     := NULL;
      RAISE;
  END quick_book;

  -- -20015 unless the booking exists and belongs to that e-mail
  PROCEDURE check_owner (p_booking_id IN NUMBER, p_email IN VARCHAR2) IS
    v_count PLS_INTEGER;
  BEGIN
    SELECT COUNT(*)
      INTO v_count
      FROM bookings b
      JOIN passengers p ON p.passenger_id = b.passenger_id
     WHERE b.booking_id = p_booking_id
       AND LOWER(p.email) = LOWER(TRIM(p_email));
    IF v_count = 0 THEN
      RAISE_APPLICATION_ERROR(-20015,
        'No booking ' || p_booking_id || ' was found for that e-mail address.');
    END IF;
  END check_owner;

  PROCEDURE find_booking (
    p_booking_id IN  bookings.booking_id%TYPE,
    p_email      IN  passengers.email%TYPE,
    p_result     OUT SYS_REFCURSOR
  ) IS
  BEGIN
    check_owner(p_booking_id, p_email);

    OPEN p_result FOR
      SELECT b.booking_id,
             b.status         AS booking_status,
             b.booking_date,
             b.cancelled_at,
             p.first_name,
             p.last_name,
             p.email,
             f.flight_id,
             f.flight_no,
             al.airline_name,
             o.iata_code      AS origin,
             o.city           AS origin_city,
             d.iata_code      AS destination,
             d.city           AS destination_city,
             f.departure_time,
             f.arrival_time,
             f.status         AS flight_status,
             s.seat_no,
             s.seat_class,
             pay.amount,
             pay.payment_method,
             pay.status       AS payment_status,
             pay.refund_amount,
             pay.transaction_ref
        FROM bookings b
        JOIN passengers p     ON p.passenger_id = b.passenger_id
        JOIN seats s          ON s.seat_id      = b.seat_id
        JOIN flights f        ON f.flight_id    = s.flight_id
        JOIN airlines al      ON al.airline_id  = f.airline_id
        JOIN airports o       ON o.airport_id   = f.origin_airport_id
        JOIN airports d       ON d.airport_id   = f.dest_airport_id
        LEFT JOIN payments pay ON pay.booking_id = b.booking_id
       WHERE b.booking_id = p_booking_id;
  END find_booking;

  PROCEDURE cancel_my_booking (
    p_booking_id    IN  bookings.booking_id%TYPE,
    p_email         IN  passengers.email%TYPE,
    p_refund_amount OUT payments.refund_amount%TYPE
  ) IS
  BEGIN
    check_owner(p_booking_id, p_email);
    cancel_booking(p_booking_id, p_refund_amount);
  END cancel_my_booking;

  PROCEDURE quick_book_round_trip (
    p_first_name  IN  passengers.first_name%TYPE,
    p_last_name   IN  passengers.last_name%TYPE,
    p_email       IN  passengers.email%TYPE,
    p_phone       IN  VARCHAR2,
    p_out_flight  IN  flights.flight_id%TYPE,
    p_out_class   IN  seats.seat_class%TYPE,
    p_out_seat    IN  seats.seat_no%TYPE,
    p_ret_flight  IN  flights.flight_id%TYPE,
    p_ret_class   IN  seats.seat_class%TYPE,
    p_ret_seat    IN  seats.seat_no%TYPE,
    p_method      IN  payments.payment_method%TYPE,
    p_out_booking OUT bookings.booking_id%TYPE,
    p_out_seat_no OUT seats.seat_no%TYPE,
    p_out_amount  OUT payments.amount%TYPE,
    p_ret_booking OUT bookings.booking_id%TYPE,
    p_ret_seat_no OUT seats.seat_no%TYPE,
    p_ret_amount  OUT payments.amount%TYPE
  ) IS
    v_out_arrival flights.arrival_time%TYPE;
    v_ret_depart  flights.departure_time%TYPE;
  BEGIN
    SAVEPOINT sp_round_trip;

    BEGIN
      SELECT o.arrival_time, r.departure_time
        INTO v_out_arrival, v_ret_depart
        FROM flights o, flights r
       WHERE o.flight_id = p_out_flight
         AND r.flight_id = p_ret_flight;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20001, 'Flight ' || p_out_flight || ' or ' || p_ret_flight || ' does not exist.');
    END;
    IF v_ret_depart <= v_out_arrival THEN
      RAISE_APPLICATION_ERROR(-20019, 'The return flight must leave after the outbound flight lands.');
    END IF;

    quick_book(p_first_name, p_last_name, p_email, p_phone, p_out_flight, p_out_class, p_out_seat,
               p_method, p_out_booking, p_out_seat_no, p_out_amount);
    quick_book(p_first_name, p_last_name, p_email, p_phone, p_ret_flight, p_ret_class, p_ret_seat,
               p_method, p_ret_booking, p_ret_seat_no, p_ret_amount);
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO SAVEPOINT sp_round_trip;   -- the outbound leg goes too
      p_out_booking := NULL; p_out_seat_no := NULL; p_out_amount := NULL;
      p_ret_booking := NULL; p_ret_seat_no := NULL; p_ret_amount := NULL;
      RAISE;
  END quick_book_round_trip;

  PROCEDURE my_bookings (
    p_email   IN  passengers.email%TYPE,
    p_phone   IN  VARCHAR2,
    p_results OUT SYS_REFCURSOR
  ) IS
    -- compare the last (up to) 10 digits, so +91 98100 12345 = 9810012345
    v_digits VARCHAR2(40) := REGEXP_REPLACE(p_phone, '[^0-9]', '');
    v_tail   PLS_INTEGER  := LEAST(10, NVL(LENGTH(v_digits), 0));
    v_count  PLS_INTEGER;
  BEGIN
    IF v_tail < 7 THEN
      RAISE_APPLICATION_ERROR(-20018, 'Invalid phone number ''' || p_phone || '''.');
    END IF;

    SELECT COUNT(*)
      INTO v_count
      FROM passengers
     WHERE LOWER(email) = LOWER(TRIM(p_email))
       AND SUBSTR(REGEXP_REPLACE(phone, '[^0-9]', ''), -v_tail) = SUBSTR(v_digits, -v_tail);
    IF v_count = 0 THEN
      RAISE_APPLICATION_ERROR(-20020, 'No bookings found for that e-mail and phone number.');
    END IF;

    OPEN p_results FOR
      SELECT b.booking_id,
             b.status         AS booking_status,
             b.booking_date,
             p.first_name,
             p.last_name,
             f.flight_id,
             f.flight_no,
             al.iata_code     AS airline_code,
             al.airline_name,
             o.iata_code      AS origin,
             o.city           AS origin_city,
             d.iata_code      AS destination,
             d.city           AS destination_city,
             f.departure_time,
             f.arrival_time,
             f.status         AS flight_status,
             s.seat_no,
             s.seat_class,
             pay.amount,
             pay.payment_method
        FROM bookings b
        JOIN passengers p     ON p.passenger_id = b.passenger_id
        JOIN seats s          ON s.seat_id      = b.seat_id
        JOIN flights f        ON f.flight_id    = s.flight_id
        JOIN airlines al      ON al.airline_id  = f.airline_id
        JOIN airports o       ON o.airport_id   = f.origin_airport_id
        JOIN airports d       ON d.airport_id   = f.dest_airport_id
        LEFT JOIN payments pay ON pay.booking_id = b.booking_id
       WHERE LOWER(p.email) = LOWER(TRIM(p_email))
       ORDER BY f.departure_time;
  END my_bookings;

END flight_search_pkg;
/
SHOW ERRORS

-- ---------------------------------------------------------------------
-- departures_board : what the airport screens show, next 7 days
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW departures_board AS
SELECT f.flight_id,
       f.flight_no,
       al.airline_name,
       o.iata_code  AS origin,
       o.city       AS origin_city,
       d.iata_code  AS destination,
       d.city       AS destination_city,
       f.departure_time,
       f.status
  FROM flights f
  JOIN airlines al ON al.airline_id = f.airline_id
  JOIN airports o  ON o.airport_id  = f.origin_airport_id
  JOIN airports d  ON d.airport_id  = f.dest_airport_id
 WHERE f.departure_time > SYSDATE
   AND f.departure_time < SYSDATE + 7;

-- ---------------------------------------------------------------------
-- Self-test: generate a route that was never scheduled, then book on it
-- ---------------------------------------------------------------------
PROMPT
PROMPT Self-test: distance DEL -> LHR (km)
SELECT flight_search_pkg.distance_km('DEL', 'LHR') AS del_lhr_km FROM dual;

PROMPT
PROMPT Self-test: search DEL -> LHR in 10 days, economy (flights are generated)
VARIABLE rc REFCURSOR
BEGIN
  flight_search_pkg.search_flights('DEL', 'LHR', TRUNC(SYSDATE) + 10, 'ECONOMY', :rc);
END;
/
COLUMN flight_no    FORMAT A8
COLUMN airline_name FORMAT A26
COLUMN airline_code NOPRINT
COLUMN origin_city  NOPRINT
COLUMN destination_city NOPRINT
COLUMN fare         FORMAT 9,999,990
PRINT rc
CLEAR COLUMNS

PROMPT
PROMPT Self-test: quick_book on the first of those flights, then roll back
DECLARE
  v_flight  flights.flight_id%TYPE;
  v_booking bookings.booking_id%TYPE;
  v_seat    seats.seat_no%TYPE;
  v_amount  payments.amount%TYPE;
BEGIN
  SELECT MIN(f.flight_id) INTO v_flight
    FROM flights f
    JOIN airports o ON o.airport_id = f.origin_airport_id
    JOIN airports d ON d.airport_id = f.dest_airport_id
   WHERE o.iata_code = 'DEL' AND d.iata_code = 'LHR'
     AND f.departure_time >= TRUNC(SYSDATE) + 10 AND f.departure_time < TRUNC(SYSDATE) + 11;

  SAVEPOINT sp_selftest;
  flight_search_pkg.quick_book('Test', 'Traveller', 'test.traveller@example.com', '+44 20 7946 0000',
                               v_flight, 'ECONOMY', NULL, 'CARD', v_booking, v_seat, v_amount);
  DBMS_OUTPUT.PUT_LINE('quick_book -> booking ' || v_booking || ', seat ' || v_seat ||
                       ', paid INR ' || TO_CHAR(v_amount, 'FM999,999,990.00'));
  ROLLBACK TO SAVEPOINT sp_selftest;
END;
/

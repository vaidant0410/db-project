-- =====================================================================
-- 02_data.sql  -  Airline Reservation System : sample data
--
-- 10 airlines, 15 airports, 15 aircraft, 15 flights, 17 passengers,
-- 18 bookings + 18 payments, 20 crew members, 18 flight-crew links,
-- and 90 seats (6 per flight, generated set-based - see below).
--
-- Notes
--  * Flight dates are relative to SYSDATE so the demo always has
--    "upcoming" flights, whenever the script is run:
--      flight 13 leaves in about 20 hours   (refund tier: 10 %)
--      flight 10 leaves in about 2 days     (refund tier: 50 %)
--      flights 1-5,7,8,9,11 leave 4+ days ahead (refund tier: 90 %)
--      flight 14 left two days ago          (cannot be cancelled)
--  * Explicit ids stay below 1000; identity columns start at 1000.
--  * Seat ids are flight_id * 10 + n  (n = 1..6):
--      n=1 '1A' BUSINESS (FIRST on flights 8 and 9), n=2 '1B' BUSINESS,
--      n=3..6 '10A'..'10D' ECONOMY.
--    The seat map is deliberately scaled down to 6 seats per flight so
--    demo output stays readable; aircraft.total_seats holds the real
--    aircraft capacity.
--  * Bookings are loaded before triggers exist (06_triggers.sql), so
--    seats.status is synchronised with one UPDATE at the end.
--  * Seeded payment amounts are the fare quoted when the ticket was
--    bought (base fare x class multiplier); calculate_fare() may quote
--    a different price today because it also reacts to demand.
--
-- Usage:  SQL> @02_data.sql
-- =====================================================================
SET ECHO OFF
SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WRAPPED
SET LINESIZE 200
SET PAGESIZE 50
SET VERIFY OFF
SET DEFINE OFF
SET SQLBLANKLINES ON
SET FEEDBACK OFF

PROMPT
PROMPT ==== 02_data.sql : loading sample data ====

-- ---------------------------------------------------------------------
-- AIRLINES
-- ---------------------------------------------------------------------
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year) VALUES (1,  'AI', 'Air India',          'India',     1932);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year) VALUES (2,  '6E', 'IndiGo',             'India',     2006);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year) VALUES (3,  'SG', 'SpiceJet',           'India',     2005);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year) VALUES (4,  'QP', 'Akasa Air',          'India',     2021);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year) VALUES (5,  'IX', 'Air India Express',  'India',     2005);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year) VALUES (6,  '9I', 'Alliance Air',       'India',     1996);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year) VALUES (7,  'S5', 'Star Air',           'India',     2018);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year) VALUES (8,  'EK', 'Emirates',           'UAE',       1985);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year) VALUES (9,  'SQ', 'Singapore Airlines', 'Singapore', 1972);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year) VALUES (10, 'LH', 'Lufthansa',          'Germany',   1953);

-- ---------------------------------------------------------------------
-- AIRPORTS
-- ---------------------------------------------------------------------
INSERT INTO airports (airport_id, iata_code, airport_name, city, country) VALUES (1,  'DEL', 'Indira Gandhi International Airport',                 'New Delhi',        'India');
INSERT INTO airports (airport_id, iata_code, airport_name, city, country) VALUES (2,  'BOM', 'Chhatrapati Shivaji Maharaj International Airport',   'Mumbai',           'India');
INSERT INTO airports (airport_id, iata_code, airport_name, city, country) VALUES (3,  'BLR', 'Kempegowda International Airport',                    'Bengaluru',        'India');
INSERT INTO airports (airport_id, iata_code, airport_name, city, country) VALUES (4,  'MAA', 'Chennai International Airport',                       'Chennai',          'India');
INSERT INTO airports (airport_id, iata_code, airport_name, city, country) VALUES (5,  'CCU', 'Netaji Subhas Chandra Bose International Airport',    'Kolkata',          'India');
INSERT INTO airports (airport_id, iata_code, airport_name, city, country) VALUES (6,  'HYD', 'Rajiv Gandhi International Airport',                  'Hyderabad',        'India');
INSERT INTO airports (airport_id, iata_code, airport_name, city, country) VALUES (7,  'AMD', 'Sardar Vallabhbhai Patel International Airport',     'Ahmedabad',        'India');
INSERT INTO airports (airport_id, iata_code, airport_name, city, country) VALUES (8,  'PNQ', 'Pune International Airport',                          'Pune',             'India');
INSERT INTO airports (airport_id, iata_code, airport_name, city, country) VALUES (9,  'GOI', 'Goa International Airport',                          'Goa',              'India');
INSERT INTO airports (airport_id, iata_code, airport_name, city, country) VALUES (10, 'COK', 'Cochin International Airport',                        'Kochi',            'India');
INSERT INTO airports (airport_id, iata_code, airport_name, city, country) VALUES (11, 'JAI', 'Jaipur International Airport',                       'Jaipur',           'India');
INSERT INTO airports (airport_id, iata_code, airport_name, city, country) VALUES (12, 'LKO', 'Chaudhary Charan Singh International Airport',        'Lucknow',          'India');
INSERT INTO airports (airport_id, iata_code, airport_name, city, country) VALUES (13, 'TRV', 'Trivandrum International Airport',                    'Thiruvananthapuram', 'India');
INSERT INTO airports (airport_id, iata_code, airport_name, city, country) VALUES (14, 'DXB', 'Dubai International Airport',                        'Dubai',            'UAE');
INSERT INTO airports (airport_id, iata_code, airport_name, city, country) VALUES (15, 'SIN', 'Singapore Changi Airport',                          'Singapore',        'Singapore');

-- ---------------------------------------------------------------------
-- AIRCRAFT
-- ---------------------------------------------------------------------
INSERT INTO aircraft (aircraft_id, airline_id, registration_no, aircraft_model, total_seats, status) VALUES (1,  1,  'VT-TNA', 'Airbus A320neo',           162, 'ACTIVE');
INSERT INTO aircraft (aircraft_id, airline_id, registration_no, aircraft_model, total_seats, status) VALUES (2,  1,  'VT-ANB', 'Boeing 787-8 Dreamliner',  238, 'ACTIVE');
INSERT INTO aircraft (aircraft_id, airline_id, registration_no, aircraft_model, total_seats, status) VALUES (3,  2,  'VT-IZB', 'Airbus A320neo',           186, 'ACTIVE');
INSERT INTO aircraft (aircraft_id, airline_id, registration_no, aircraft_model, total_seats, status) VALUES (4,  2,  'VT-IUC', 'Airbus A321neo',           222, 'ACTIVE');
INSERT INTO aircraft (aircraft_id, airline_id, registration_no, aircraft_model, total_seats, status) VALUES (5,  3,  'VT-SZA', 'Boeing 737-800',           189, 'ACTIVE');
INSERT INTO aircraft (aircraft_id, airline_id, registration_no, aircraft_model, total_seats, status) VALUES (6,  3,  'VT-SQD', 'Bombardier Q400',          78,  'MAINTENANCE');
INSERT INTO aircraft (aircraft_id, airline_id, registration_no, aircraft_model, total_seats, status) VALUES (7,  4,  'VT-YAB', 'Boeing 737-8 MAX',          189, 'ACTIVE');
INSERT INTO aircraft (aircraft_id, airline_id, registration_no, aircraft_model, total_seats, status) VALUES (8,  5,  'VT-BXA', 'Boeing 737-8',              186, 'ACTIVE');
INSERT INTO aircraft (aircraft_id, airline_id, registration_no, aircraft_model, total_seats, status) VALUES (9,  5,  'VT-BXB', 'Boeing 737-800',           189, 'RETIRED');
INSERT INTO aircraft (aircraft_id, airline_id, registration_no, aircraft_model, total_seats, status) VALUES (10, 6,  'VT-AXA', 'ATR 72-600',              70,  'ACTIVE');
INSERT INTO aircraft (aircraft_id, airline_id, registration_no, aircraft_model, total_seats, status) VALUES (11, 7,  'VT-STA', 'Embraer E175',            76,  'ACTIVE');
INSERT INTO aircraft (aircraft_id, airline_id, registration_no, aircraft_model, total_seats, status) VALUES (12, 8,  'A6-EPA', 'Boeing 777-300ER',        354, 'ACTIVE');
INSERT INTO aircraft (aircraft_id, airline_id, registration_no, aircraft_model, total_seats, status) VALUES (13, 9,  '9V-SMB', 'Airbus A350-900',         253, 'ACTIVE');
INSERT INTO aircraft (aircraft_id, airline_id, registration_no, aircraft_model, total_seats, status) VALUES (14, 10, 'D-AIXA', 'Airbus A350-900',         293, 'ACTIVE');
INSERT INTO aircraft (aircraft_id, airline_id, registration_no, aircraft_model, total_seats, status) VALUES (15, 2,  'VT-IRA', 'ATR 72-600',              78,  'ACTIVE');

-- ---------------------------------------------------------------------
-- FLIGHTS  (INTERVAL literals keep the minutes exact)
-- ---------------------------------------------------------------------
INSERT INTO flights (flight_id, flight_no, airline_id, aircraft_id, origin_airport_id, dest_airport_id, departure_time, arrival_time, base_fare, status)
VALUES (1,  'AI-101',  1, 1,  1,  2,  TRUNC(SYSDATE) + INTERVAL '5 06:00' DAY TO MINUTE,  TRUNC(SYSDATE) + INTERVAL '5 08:15' DAY TO MINUTE,  5800,  'SCHEDULED');
INSERT INTO flights (flight_id, flight_no, airline_id, aircraft_id, origin_airport_id, dest_airport_id, departure_time, arrival_time, base_fare, status)
VALUES (2,  '6E-6105', 2, 3,  2,  3,  TRUNC(SYSDATE) + INTERVAL '5 09:30' DAY TO MINUTE,  TRUNC(SYSDATE) + INTERVAL '5 11:15' DAY TO MINUTE,  4200,  'SCHEDULED');
INSERT INTO flights (flight_id, flight_no, airline_id, aircraft_id, origin_airport_id, dest_airport_id, departure_time, arrival_time, base_fare, status)
VALUES (3,  'SG-8152', 3, 5,  1,  9,  TRUNC(SYSDATE) + INTERVAL '6 07:15' DAY TO MINUTE,  TRUNC(SYSDATE) + INTERVAL '6 10:00' DAY TO MINUTE,  6100,  'DELAYED');
INSERT INTO flights (flight_id, flight_no, airline_id, aircraft_id, origin_airport_id, dest_airport_id, departure_time, arrival_time, base_fare, status)
VALUES (4,  'QP-1101', 4, 7,  3,  6,  TRUNC(SYSDATE) + INTERVAL '4 18:40' DAY TO MINUTE,  TRUNC(SYSDATE) + INTERVAL '4 19:55' DAY TO MINUTE,  3100,  'SCHEDULED');
INSERT INTO flights (flight_id, flight_no, airline_id, aircraft_id, origin_airport_id, dest_airport_id, departure_time, arrival_time, base_fare, status)
VALUES (5,  'IX-1511', 5, 8,  10, 14, TRUNC(SYSDATE) + INTERVAL '7 03:20' DAY TO MINUTE,  TRUNC(SYSDATE) + INTERVAL '7 07:05' DAY TO MINUTE,  14500, 'SCHEDULED');
INSERT INTO flights (flight_id, flight_no, airline_id, aircraft_id, origin_airport_id, dest_airport_id, departure_time, arrival_time, base_fare, status)
VALUES (6,  '9I-601',  6, 10, 1,  11, TRUNC(SYSDATE) + INTERVAL '3 11:00' DAY TO MINUTE,  TRUNC(SYSDATE) + INTERVAL '3 12:05' DAY TO MINUTE,  2900,  'SCHEDULED');
INSERT INTO flights (flight_id, flight_no, airline_id, aircraft_id, origin_airport_id, dest_airport_id, departure_time, arrival_time, base_fare, status)
VALUES (7,  'S5-115',  7, 11, 6,  8,  TRUNC(SYSDATE) + INTERVAL '4 08:10' DAY TO MINUTE,  TRUNC(SYSDATE) + INTERVAL '4 09:25' DAY TO MINUTE,  3400,  'SCHEDULED');
INSERT INTO flights (flight_id, flight_no, airline_id, aircraft_id, origin_airport_id, dest_airport_id, departure_time, arrival_time, base_fare, status)
VALUES (8,  'EK-512',  8, 12, 1,  14, TRUNC(SYSDATE) + INTERVAL '8 04:05' DAY TO MINUTE,  TRUNC(SYSDATE) + INTERVAL '8 07:45' DAY TO MINUTE,  21000, 'SCHEDULED');
INSERT INTO flights (flight_id, flight_no, airline_id, aircraft_id, origin_airport_id, dest_airport_id, departure_time, arrival_time, base_fare, status)
VALUES (9,  'SQ-529',  9, 13, 4,  15, TRUNC(SYSDATE) + INTERVAL '9 22:10' DAY TO MINUTE,  TRUNC(SYSDATE) + INTERVAL '10 02:30' DAY TO MINUTE, 24000, 'SCHEDULED');
INSERT INTO flights (flight_id, flight_no, airline_id, aircraft_id, origin_airport_id, dest_airport_id, departure_time, arrival_time, base_fare, status)
VALUES (10, '6E-2041', 2, 4,  4,  5,  TRUNC(SYSDATE) + INTERVAL '2 13:45' DAY TO MINUTE,  TRUNC(SYSDATE) + INTERVAL '2 16:05' DAY TO MINUTE,  4600,  'SCHEDULED');
INSERT INTO flights (flight_id, flight_no, airline_id, aircraft_id, origin_airport_id, dest_airport_id, departure_time, arrival_time, base_fare, status)
VALUES (11, 'AI-665',  1, 2,  3,  1,  TRUNC(SYSDATE) + INTERVAL '6 15:20' DAY TO MINUTE,  TRUNC(SYSDATE) + INTERVAL '6 18:10' DAY TO MINUTE,  6900,  'SCHEDULED');
INSERT INTO flights (flight_id, flight_no, airline_id, aircraft_id, origin_airport_id, dest_airport_id, departure_time, arrival_time, base_fare, status)
VALUES (12, '6E-7211', 2, 15, 8,  9,  TRUNC(SYSDATE) + INTERVAL '3 17:30' DAY TO MINUTE,  TRUNC(SYSDATE) + INTERVAL '3 18:40' DAY TO MINUTE,  3300,  'SCHEDULED');
-- flight 13: leaves ~20 hours from now (last-minute fare, 10 % refund tier)
INSERT INTO flights (flight_id, flight_no, airline_id, aircraft_id, origin_airport_id, dest_airport_id, departure_time, arrival_time, base_fare, status)
VALUES (13, 'SG-8901', 3, 5,  2,  1,  TRUNC(SYSDATE, 'HH24') + INTERVAL '0 20:00' DAY TO MINUTE, TRUNC(SYSDATE, 'HH24') + INTERVAL '0 22:10' DAY TO MINUTE, 5200, 'SCHEDULED');
-- flight 14: already flown (cannot be cancelled or booked)
INSERT INTO flights (flight_id, flight_no, airline_id, aircraft_id, origin_airport_id, dest_airport_id, departure_time, arrival_time, base_fare, status)
VALUES (14, '6E-2211', 2, 4,  7,  2,  TRUNC(SYSDATE) + INTERVAL '-2 06:30' DAY TO MINUTE, TRUNC(SYSDATE) + INTERVAL '-2 07:40' DAY TO MINUTE, 3900,  'ARRIVED');
-- flight 15: cancelled by the airline (cannot be booked)
INSERT INTO flights (flight_id, flight_no, airline_id, aircraft_id, origin_airport_id, dest_airport_id, departure_time, arrival_time, base_fare, status)
VALUES (15, 'AI-887',  1, 1,  5,  1,  TRUNC(SYSDATE) + INTERVAL '4 09:00' DAY TO MINUTE,  TRUNC(SYSDATE) + INTERVAL '4 11:20' DAY TO MINUTE,  6300,  'CANCELLED');

-- ---------------------------------------------------------------------
-- PASSENGERS
-- ---------------------------------------------------------------------
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, date_of_birth, gender, passport_no) VALUES (1,  'Aarav',    'Sharma',     'aarav.sharma@example.com',     '9810012345', DATE '1994-03-14', 'M', 'K1234501');
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, date_of_birth, gender, passport_no) VALUES (2,  'Priya',    'Nair',       'priya.nair@example.com',       '9847023456', DATE '1990-07-22', 'F', 'L2345602');
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, date_of_birth, gender, passport_no) VALUES (3,  'Rohan',    'Mehta',      'rohan.mehta@example.com',      '9820034567', DATE '1988-11-05', 'M', 'M3456703');
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, date_of_birth, gender, passport_no) VALUES (4,  'Ananya',   'Iyer',       'ananya.iyer@example.com',      '9840045678', DATE '1996-01-30', 'F', 'N4567804');
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, date_of_birth, gender, passport_no) VALUES (5,  'Vikram',   'Singh',      'vikram.singh@example.com',     '9899056789', DATE '1985-09-18', 'M', 'P5678905');
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, date_of_birth, gender, passport_no) VALUES (6,  'Sneha',    'Reddy',      'sneha.reddy@example.com',      '9848067890', DATE '1992-05-09', 'F', 'R6789006');
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, date_of_birth, gender, passport_no) VALUES (7,  'Arjun',    'Kapoor',     'arjun.kapoor@example.com',     '9811078901', DATE '1998-12-01', 'M', 'S7890107');
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, date_of_birth, gender, passport_no) VALUES (8,  'Kavya',    'Menon',      'kavya.menon@example.com',      '9895089012', DATE '1993-08-27', 'F', 'T8901208');
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, date_of_birth, gender, passport_no) VALUES (9,  'Rahul',    'Verma',      'rahul.verma@example.com',      '9415090123', DATE '1987-04-16', 'M', 'U9012309');
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, date_of_birth, gender, passport_no) VALUES (10, 'Isha',     'Gupta',      'isha.gupta@example.com',       '9871101234', DATE '1995-10-11', 'F', 'V0123410');
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, date_of_birth, gender, passport_no) VALUES (11, 'Karan',    'Malhotra',   'karan.malhotra@example.com',   '9810112345', DATE '1991-02-25', 'M', 'W1234511');
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, date_of_birth, gender, passport_no) VALUES (12, 'Divya',    'Joshi',      'divya.joshi@example.com',      '9822123456', DATE '1989-06-13', 'F', 'X2345612');
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, date_of_birth, gender, passport_no) VALUES (13, 'Siddharth', 'Rao',        'siddharth.rao@example.com',    '9845134567', DATE '1997-03-08', 'M', 'Y3456713');
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, date_of_birth, gender, passport_no) VALUES (14, 'Meera',    'Pillai',     'meera.pillai@example.com',     '9447145678', DATE '1994-09-30', 'F', 'Z4567814');
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, date_of_birth, gender, passport_no) VALUES (15, 'Aditya',   'Chatterjee', 'aditya.chatterjee@example.com','9830156789', DATE '1986-12-19', 'M', 'A5678915');
-- passengers 16 and 17 have never booked (used by the outer-join / NOT EXISTS demos)
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, date_of_birth, gender, passport_no) VALUES (16, 'Nikhil',   'Bansal',     'nikhil.bansal@example.com',    '9899167890', DATE '1999-07-04', 'M', NULL);
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, date_of_birth, gender, passport_no) VALUES (17, 'Pooja',    'Deshmukh',   'pooja.deshmukh@example.com',   '9822178901', DATE '2001-01-21', 'F', NULL);

-- ---------------------------------------------------------------------
-- SEATS : 6 per flight, set-based (flight_id * 10 + n)
-- ---------------------------------------------------------------------
INSERT INTO seats (seat_id, flight_id, seat_no, seat_class, status)
SELECT f.flight_id * 10 + n.idx,
       f.flight_id,
       CASE n.idx WHEN 1 THEN '1A' WHEN 2 THEN '1B' WHEN 3 THEN '10A'
                  WHEN 4 THEN '10B' WHEN 5 THEN '10C' ELSE '10D' END,
       CASE WHEN n.idx = 1 AND f.flight_id IN (8, 9) THEN 'FIRST'
            WHEN n.idx <= 2 THEN 'BUSINESS'
            ELSE 'ECONOMY' END,
       'AVAILABLE'
  FROM flights f
 CROSS JOIN (SELECT LEVEL AS idx FROM dual CONNECT BY LEVEL <= 6) n;

-- ---------------------------------------------------------------------
-- BOOKINGS  (15 confirmed, 3 cancelled)
-- ---------------------------------------------------------------------
INSERT INTO bookings (booking_id, passenger_id, seat_id, booking_date, status, cancelled_at) VALUES (1,  1,  13,  SYSDATE - 9,  'CONFIRMED', NULL);
INSERT INTO bookings (booking_id, passenger_id, seat_id, booking_date, status, cancelled_at) VALUES (2,  2,  14,  SYSDATE - 8,  'CONFIRMED', NULL);
INSERT INTO bookings (booking_id, passenger_id, seat_id, booking_date, status, cancelled_at) VALUES (3,  3,  11,  SYSDATE - 8,  'CONFIRMED', NULL);
INSERT INTO bookings (booking_id, passenger_id, seat_id, booking_date, status, cancelled_at) VALUES (4,  4,  15,  SYSDATE - 6,  'CONFIRMED', NULL);
INSERT INTO bookings (booking_id, passenger_id, seat_id, booking_date, status, cancelled_at) VALUES (5,  5,  16,  SYSDATE - 5,  'CONFIRMED', NULL);
INSERT INTO bookings (booking_id, passenger_id, seat_id, booking_date, status, cancelled_at) VALUES (6,  6,  23,  SYSDATE - 4,  'CONFIRMED', NULL);
INSERT INTO bookings (booking_id, passenger_id, seat_id, booking_date, status, cancelled_at) VALUES (7,  7,  24,  SYSDATE - 3,  'CONFIRMED', NULL);
INSERT INTO bookings (booking_id, passenger_id, seat_id, booking_date, status, cancelled_at) VALUES (8,  8,  33,  SYSDATE - 3,  'CONFIRMED', NULL);
INSERT INTO bookings (booking_id, passenger_id, seat_id, booking_date, status, cancelled_at) VALUES (9,  9,  41,  SYSDATE - 2,  'CONFIRMED', NULL);
INSERT INTO bookings (booking_id, passenger_id, seat_id, booking_date, status, cancelled_at) VALUES (10, 10, 53,  SYSDATE - 2,  'CONFIRMED', NULL);
INSERT INTO bookings (booking_id, passenger_id, seat_id, booking_date, status, cancelled_at) VALUES (11, 11, 83,  SYSDATE - 1,  'CONFIRMED', NULL);
INSERT INTO bookings (booking_id, passenger_id, seat_id, booking_date, status, cancelled_at) VALUES (12, 12, 91,  SYSDATE - 1,  'CONFIRMED', NULL);
INSERT INTO bookings (booking_id, passenger_id, seat_id, booking_date, status, cancelled_at) VALUES (13, 13, 133, SYSDATE - 1,  'CONFIRMED', NULL);
INSERT INTO bookings (booking_id, passenger_id, seat_id, booking_date, status, cancelled_at) VALUES (14, 14, 143, SYSDATE - 6,  'CONFIRMED', NULL);
INSERT INTO bookings (booking_id, passenger_id, seat_id, booking_date, status, cancelled_at) VALUES (15, 15, 144, SYSDATE - 5,  'CONFIRMED', NULL);
INSERT INTO bookings (booking_id, passenger_id, seat_id, booking_date, status, cancelled_at) VALUES (16, 1,  25,  SYSDATE - 10, 'CANCELLED', SYSDATE - 4);
INSERT INTO bookings (booking_id, passenger_id, seat_id, booking_date, status, cancelled_at) VALUES (17, 2,  43,  SYSDATE - 8,  'CANCELLED', SYSDATE - 2);
INSERT INTO bookings (booking_id, passenger_id, seat_id, booking_date, status, cancelled_at) VALUES (18, 3,  36,  SYSDATE - 7,  'CANCELLED', SYSDATE - 1);

-- seats behind CONFIRMED bookings are BOOKED (triggers are not installed yet)
UPDATE seats
   SET status = 'BOOKED'
 WHERE seat_id IN (SELECT seat_id FROM bookings WHERE status = 'CONFIRMED');

-- ---------------------------------------------------------------------
-- PAYMENTS  (one per booking; the 3 cancelled bookings were refunded
--            at 90 %, 50 % and 10 % - the refund tiers of cancel_booking)
-- ---------------------------------------------------------------------
INSERT INTO payments (payment_id, booking_id, amount, payment_method, status, transaction_ref, payment_date, refund_amount, refund_date) VALUES (1,  1,  5800,  'CARD',       'SUCCESS',  'TXN00000001', SYSDATE - 9,  0,    NULL);
INSERT INTO payments (payment_id, booking_id, amount, payment_method, status, transaction_ref, payment_date, refund_amount, refund_date) VALUES (2,  2,  5800,  'UPI',        'SUCCESS',  'TXN00000002', SYSDATE - 8,  0,    NULL);
INSERT INTO payments (payment_id, booking_id, amount, payment_method, status, transaction_ref, payment_date, refund_amount, refund_date) VALUES (3,  3,  14500, 'CARD',       'SUCCESS',  'TXN00000003', SYSDATE - 8,  0,    NULL);
INSERT INTO payments (payment_id, booking_id, amount, payment_method, status, transaction_ref, payment_date, refund_amount, refund_date) VALUES (4,  4,  5800,  'NETBANKING', 'SUCCESS',  'TXN00000004', SYSDATE - 6,  0,    NULL);
INSERT INTO payments (payment_id, booking_id, amount, payment_method, status, transaction_ref, payment_date, refund_amount, refund_date) VALUES (5,  5,  5800,  'UPI',        'SUCCESS',  'TXN00000005', SYSDATE - 5,  0,    NULL);
INSERT INTO payments (payment_id, booking_id, amount, payment_method, status, transaction_ref, payment_date, refund_amount, refund_date) VALUES (6,  6,  4200,  'WALLET',     'SUCCESS',  'TXN00000006', SYSDATE - 4,  0,    NULL);
INSERT INTO payments (payment_id, booking_id, amount, payment_method, status, transaction_ref, payment_date, refund_amount, refund_date) VALUES (7,  7,  4200,  'CARD',       'SUCCESS',  'TXN00000007', SYSDATE - 3,  0,    NULL);
INSERT INTO payments (payment_id, booking_id, amount, payment_method, status, transaction_ref, payment_date, refund_amount, refund_date) VALUES (8,  8,  6100,  'UPI',        'SUCCESS',  'TXN00000008', SYSDATE - 3,  0,    NULL);
INSERT INTO payments (payment_id, booking_id, amount, payment_method, status, transaction_ref, payment_date, refund_amount, refund_date) VALUES (9,  9,  7750,  'CARD',       'SUCCESS',  'TXN00000009', SYSDATE - 2,  0,    NULL);
INSERT INTO payments (payment_id, booking_id, amount, payment_method, status, transaction_ref, payment_date, refund_amount, refund_date) VALUES (10, 10, 14500, 'NETBANKING', 'SUCCESS',  'TXN00000010', SYSDATE - 2,  0,    NULL);
INSERT INTO payments (payment_id, booking_id, amount, payment_method, status, transaction_ref, payment_date, refund_amount, refund_date) VALUES (11, 11, 21000, 'CARD',       'SUCCESS',  'TXN00000011', SYSDATE - 1,  0,    NULL);
INSERT INTO payments (payment_id, booking_id, amount, payment_method, status, transaction_ref, payment_date, refund_amount, refund_date) VALUES (12, 12, 96000, 'CARD',       'SUCCESS',  'TXN00000012', SYSDATE - 1,  0,    NULL);
INSERT INTO payments (payment_id, booking_id, amount, payment_method, status, transaction_ref, payment_date, refund_amount, refund_date) VALUES (13, 13, 5200,  'UPI',        'SUCCESS',  'TXN00000013', SYSDATE - 1,  0,    NULL);
INSERT INTO payments (payment_id, booking_id, amount, payment_method, status, transaction_ref, payment_date, refund_amount, refund_date) VALUES (14, 14, 3900,  'CASH',       'SUCCESS',  'TXN00000014', SYSDATE - 6,  0,    NULL);
INSERT INTO payments (payment_id, booking_id, amount, payment_method, status, transaction_ref, payment_date, refund_amount, refund_date) VALUES (15, 15, 3900,  'UPI',        'SUCCESS',  'TXN00000015', SYSDATE - 5,  0,    NULL);
INSERT INTO payments (payment_id, booking_id, amount, payment_method, status, transaction_ref, payment_date, refund_amount, refund_date) VALUES (16, 16, 4200,  'CARD',       'REFUNDED', 'TXN00000016', SYSDATE - 10, 3780, SYSDATE - 4);
INSERT INTO payments (payment_id, booking_id, amount, payment_method, status, transaction_ref, payment_date, refund_amount, refund_date) VALUES (17, 17, 3100,  'UPI',        'REFUNDED', 'TXN00000017', SYSDATE - 8,  1550, SYSDATE - 2);
INSERT INTO payments (payment_id, booking_id, amount, payment_method, status, transaction_ref, payment_date, refund_amount, refund_date) VALUES (18, 18, 6100,  'WALLET',     'REFUNDED', 'TXN00000018', SYSDATE - 7,  610,  SYSDATE - 1);

-- ---------------------------------------------------------------------
-- CREW  (crew 19 and 20 are not rostered on any flight yet)
-- ---------------------------------------------------------------------
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (1,  1, 'Rajiv Bhatia',     'CAPTAIN',       'IN-ATPL-1001', 18, '9810200001');
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (2,  1, 'Neha Arora',       'FIRST_OFFICER', 'IN-CPL-2001',  7,  '9810200002');
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (3,  1, 'Sunita Rao',       'PURSER',        'IN-CC-3001',   12, '9810200003');
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (4,  1, 'Tanvi Kulkarni',   'CABIN_CREW',    'IN-CC-3002',   3,  '9810200004');
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (5,  2, 'Harpreet Sandhu',  'CAPTAIN',       'IN-ATPL-1002', 15, '9820200005');
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (6,  2, 'Manish Tiwari',    'FIRST_OFFICER', 'IN-CPL-2002',  5,  '9820200006');
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (7,  2, 'Lakshmi Krishnan', 'PURSER',        'IN-CC-3003',   9,  '9820200007');
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (8,  2, 'Farhan Sheikh',    'CABIN_CREW',    'IN-CC-3004',   2,  '9820200008');
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (9,  3, 'Suresh Nambiar',   'CAPTAIN',       'IN-ATPL-1003', 20, '9830200009');
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (10, 3, 'Aditi Deshpande',  'FIRST_OFFICER', 'IN-CPL-2003',  6,  '9830200010');
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (11, 3, 'Pankaj Yadav',     'CABIN_CREW',    'IN-CC-3005',   4,  '9830200011');
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (12, 4, 'Ritu Saxena',      'CAPTAIN',       'IN-ATPL-1004', 14, '9840200012');
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (13, 4, 'Gaurav Chopra',    'FIRST_OFFICER', 'IN-CPL-2004',  4,  '9840200013');
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (14, 4, 'Shalini Mishra',   'PURSER',        'IN-CC-3006',   8,  '9840200014');
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (15, 5, 'Anil Varghese',    'CAPTAIN',       'IN-ATPL-1005', 22, '9850200015');
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (16, 5, 'Deepa Thomas',     'FIRST_OFFICER', 'IN-CPL-2005',  6,  '9850200016');
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (17, 5, 'Imran Qureshi',    'CABIN_CREW',    'IN-CC-3007',   5,  '9850200017');
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (18, 6, 'Vivek Choudhary',  'CAPTAIN',       'IN-ATPL-1006', 11, '9860200018');
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (19, 9, 'Mei Ling Tan',     'PURSER',        'SG-CC-4001',   10, NULL);
INSERT INTO crew (crew_id, airline_id, full_name, crew_role, license_no, experience_years, phone) VALUES (20, 8, 'Omar Al Farsi',    'CAPTAIN',       'AE-ATPL-5001', 19, NULL);

-- ---------------------------------------------------------------------
-- FLIGHT_CREW  (flights 1-6 are crewed; flights 7-15 are not yet)
-- ---------------------------------------------------------------------
INSERT INTO flight_crew (flight_id, crew_id) VALUES (1, 1);
INSERT INTO flight_crew (flight_id, crew_id) VALUES (1, 2);
INSERT INTO flight_crew (flight_id, crew_id) VALUES (1, 3);
INSERT INTO flight_crew (flight_id, crew_id) VALUES (1, 4);
INSERT INTO flight_crew (flight_id, crew_id) VALUES (2, 5);
INSERT INTO flight_crew (flight_id, crew_id) VALUES (2, 6);
INSERT INTO flight_crew (flight_id, crew_id) VALUES (2, 7);
INSERT INTO flight_crew (flight_id, crew_id) VALUES (2, 8);
INSERT INTO flight_crew (flight_id, crew_id) VALUES (3, 9);
INSERT INTO flight_crew (flight_id, crew_id) VALUES (3, 10);
INSERT INTO flight_crew (flight_id, crew_id) VALUES (3, 11);
INSERT INTO flight_crew (flight_id, crew_id) VALUES (4, 12);
INSERT INTO flight_crew (flight_id, crew_id) VALUES (4, 13);
INSERT INTO flight_crew (flight_id, crew_id) VALUES (4, 14);
INSERT INTO flight_crew (flight_id, crew_id) VALUES (5, 15);
INSERT INTO flight_crew (flight_id, crew_id) VALUES (5, 16);
INSERT INTO flight_crew (flight_id, crew_id) VALUES (5, 17);
INSERT INTO flight_crew (flight_id, crew_id) VALUES (6, 18);

-- ---------------------------------------------------------------------
-- Row-count summary, then commit
-- ---------------------------------------------------------------------
SET FEEDBACK ON
COLUMN table_name FORMAT A20
COLUMN row_count  FORMAT 999,999
SELECT 'airlines'    AS table_name, COUNT(*) AS row_count FROM airlines
UNION ALL SELECT 'airports',    COUNT(*) FROM airports
UNION ALL SELECT 'aircraft',    COUNT(*) FROM aircraft
UNION ALL SELECT 'flights',     COUNT(*) FROM flights
UNION ALL SELECT 'passengers',  COUNT(*) FROM passengers
UNION ALL SELECT 'seats',       COUNT(*) FROM seats
UNION ALL SELECT 'bookings',    COUNT(*) FROM bookings
UNION ALL SELECT 'payments',    COUNT(*) FROM payments
UNION ALL SELECT 'crew',        COUNT(*) FROM crew
UNION ALL SELECT 'flight_crew', COUNT(*) FROM flight_crew;
COLUMN table_name CLEAR
COLUMN row_count  CLEAR

COMMIT;

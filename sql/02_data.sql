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
-- AIRLINES  (network: DOMESTIC / REGIONAL / GLOBAL; fare_factor = price level)
-- ---------------------------------------------------------------------
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (1  , 'AI', 'Air India'                      , 'India'         , 1932, 'REGIONAL', 1.10);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (2  , '6E', 'IndiGo'                         , 'India'         , 2006, 'REGIONAL', 0.90);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (3  , 'SG', 'SpiceJet'                       , 'India'         , 2005, 'REGIONAL', 0.85);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (4  , 'QP', 'Akasa Air'                      , 'India'         , 2021, 'REGIONAL', 0.88);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (5  , 'IX', 'Air India Express'              , 'India'         , 2005, 'REGIONAL', 0.82);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (6  , '9I', 'Alliance Air'                   , 'India'         , 1996, 'DOMESTIC', 0.95);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (7  , 'S5', 'Star Air'                       , 'India'         , 2018, 'DOMESTIC', 0.92);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (8  , 'EK', 'Emirates'                       , 'UAE'           , 1985, 'GLOBAL'  , 1.25);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (9  , 'SQ', 'Singapore Airlines'             , 'Singapore'     , 1972, 'GLOBAL'  , 1.30);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (10 , 'LH', 'Lufthansa'                      , 'Germany'       , 1953, 'GLOBAL'  , 1.20);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (11 , 'QR', 'Qatar Airways'                  , 'Qatar'         , NULL, 'GLOBAL'  , 1.20);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (12 , 'EY', 'Etihad Airways'                 , 'UAE'           , NULL, 'GLOBAL'  , 1.15);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (13 , 'TK', 'Turkish Airlines'               , 'Turkey'        , NULL, 'GLOBAL'  , 1.05);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (14 , 'BA', 'British Airways'                , 'UK'            , NULL, 'GLOBAL'  , 1.25);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (15 , 'AF', 'Air France'                     , 'France'        , NULL, 'GLOBAL'  , 1.20);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (16 , 'KL', 'KLM Royal Dutch Airlines'       , 'Netherlands'   , NULL, 'GLOBAL'  , 1.15);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (17 , 'UA', 'United Airlines'                , 'USA'           , NULL, 'GLOBAL'  , 1.15);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (18 , 'AA', 'American Airlines'              , 'USA'           , NULL, 'REGIONAL', 1.10);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (19 , 'DL', 'Delta Air Lines'                , 'USA'           , NULL, 'REGIONAL', 1.15);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (20 , 'WN', 'Southwest Airlines'             , 'USA'           , NULL, 'DOMESTIC', 0.85);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (21 , 'B6', 'JetBlue'                        , 'USA'           , NULL, 'REGIONAL', 0.90);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (22 , 'AC', 'Air Canada'                     , 'Canada'        , NULL, 'REGIONAL', 1.10);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (23 , 'QF', 'Qantas'                         , 'Australia'     , NULL, 'REGIONAL', 1.20);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (24 , 'VA', 'Virgin Australia'               , 'Australia'     , NULL, 'DOMESTIC', 0.95);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (25 , 'NZ', 'Air New Zealand'                , 'New Zealand'   , NULL, 'REGIONAL', 1.10);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (26 , 'NH', 'All Nippon Airways'             , 'Japan'         , NULL, 'REGIONAL', 1.20);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (27 , 'JL', 'Japan Airlines'                 , 'Japan'         , NULL, 'REGIONAL', 1.20);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (28 , 'CX', 'Cathay Pacific'                 , 'Hong Kong'     , NULL, 'REGIONAL', 1.20);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (29 , 'KE', 'Korean Air'                     , 'South Korea'   , NULL, 'REGIONAL', 1.10);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (30 , 'CA', 'Air China'                      , 'China'         , NULL, 'REGIONAL', 1.00);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (31 , 'MU', 'China Eastern Airlines'         , 'China'         , NULL, 'REGIONAL', 0.95);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (32 , 'TG', 'Thai Airways'                   , 'Thailand'      , NULL, 'REGIONAL', 1.00);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (33 , 'MH', 'Malaysia Airlines'              , 'Malaysia'      , NULL, 'REGIONAL', 1.00);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (34 , 'AK', 'AirAsia'                        , 'Malaysia'      , NULL, 'REGIONAL', 0.75);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (35 , 'TR', 'Scoot'                          , 'Singapore'     , NULL, 'REGIONAL', 0.78);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (36 , 'GA', 'Garuda Indonesia'               , 'Indonesia'     , NULL, 'REGIONAL', 1.00);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (37 , 'VN', 'Vietnam Airlines'               , 'Vietnam'       , NULL, 'REGIONAL', 0.95);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (38 , 'PR', 'Philippine Airlines'            , 'Philippines'   , NULL, 'REGIONAL', 0.95);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (39 , 'UL', 'SriLankan Airlines'             , 'Sri Lanka'     , NULL, 'REGIONAL', 0.95);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (40 , 'RA', 'Nepal Airlines'                 , 'Nepal'         , NULL, 'REGIONAL', 0.90);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (41 , 'BG', 'Biman Bangladesh Airlines'      , 'Bangladesh'    , NULL, 'REGIONAL', 0.90);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (42 , 'PK', 'Pakistan International Airlines', 'Pakistan'      , NULL, 'REGIONAL', 0.90);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (43 , 'SV', 'Saudia'                         , 'Saudi Arabia'  , NULL, 'REGIONAL', 1.00);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (44 , 'WY', 'Oman Air'                       , 'Oman'          , NULL, 'REGIONAL', 1.05);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (45 , 'GF', 'Gulf Air'                       , 'Bahrain'       , NULL, 'REGIONAL', 1.00);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (46 , 'KU', 'Kuwait Airways'                 , 'Kuwait'        , NULL, 'REGIONAL', 1.00);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (47 , 'FZ', 'flydubai'                       , 'UAE'           , NULL, 'REGIONAL', 0.80);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (48 , 'G9', 'Air Arabia'                     , 'UAE'           , NULL, 'REGIONAL', 0.75);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (49 , 'LY', 'El Al'                          , 'Israel'        , NULL, 'REGIONAL', 1.10);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (50 , 'HY', 'Uzbekistan Airways'             , 'Uzbekistan'    , NULL, 'REGIONAL', 0.90);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (51 , 'SU', 'Aeroflot'                       , 'Russia'        , NULL, 'REGIONAL', 0.95);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (52 , 'VS', 'Virgin Atlantic'                , 'UK'            , NULL, 'REGIONAL', 1.20);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (53 , 'U2', 'easyJet'                        , 'UK'            , NULL, 'REGIONAL', 0.75);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (54 , 'FR', 'Ryanair'                        , 'Ireland'       , NULL, 'REGIONAL', 0.70);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (55 , 'EI', 'Aer Lingus'                     , 'Ireland'       , NULL, 'REGIONAL', 1.00);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (56 , 'IB', 'Iberia'                         , 'Spain'         , NULL, 'REGIONAL', 1.05);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (57 , 'AZ', 'ITA Airways'                    , 'Italy'         , NULL, 'REGIONAL', 1.05);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (58 , 'LX', 'Swiss International Air Lines'  , 'Switzerland'   , NULL, 'REGIONAL', 1.25);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (59 , 'OS', 'Austrian Airlines'              , 'Austria'       , NULL, 'REGIONAL', 1.10);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (60 , 'SN', 'Brussels Airlines'              , 'Belgium'       , NULL, 'REGIONAL', 1.05);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (61 , 'SK', 'Scandinavian Airlines'          , 'Sweden'        , NULL, 'REGIONAL', 1.10);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (62 , 'AY', 'Finnair'                        , 'Finland'       , NULL, 'REGIONAL', 1.10);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (63 , 'FI', 'Icelandair'                     , 'Iceland'       , NULL, 'REGIONAL', 1.05);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (64 , 'TP', 'TAP Air Portugal'               , 'Portugal'      , NULL, 'REGIONAL', 1.00);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (65 , 'A3', 'Aegean Airlines'                , 'Greece'        , NULL, 'REGIONAL', 0.95);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (66 , 'LO', 'LOT Polish Airlines'            , 'Poland'        , NULL, 'REGIONAL', 0.95);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (67 , 'OK', 'Czech Airlines'                 , 'Czech Republic', NULL, 'REGIONAL', 0.95);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (68 , 'MS', 'EgyptAir'                       , 'Egypt'         , NULL, 'REGIONAL', 0.95);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (69 , 'AT', 'Royal Air Maroc'                , 'Morocco'       , NULL, 'REGIONAL', 0.95);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (70 , 'ET', 'Ethiopian Airlines'             , 'Ethiopia'      , NULL, 'GLOBAL'  , 0.95);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (71 , 'KQ', 'Kenya Airways'                  , 'Kenya'         , NULL, 'REGIONAL', 1.00);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (72 , 'SA', 'South African Airways'          , 'South Africa'  , NULL, 'REGIONAL', 1.05);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (73 , 'P4', 'Air Peace'                      , 'Nigeria'       , NULL, 'REGIONAL', 0.90);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (74 , 'MK', 'Air Mauritius'                  , 'Mauritius'     , NULL, 'REGIONAL', 1.05);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (75 , 'HM', 'Air Seychelles'                 , 'Seychelles'    , NULL, 'REGIONAL', 1.05);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (76 , 'AM', 'Aeromexico'                     , 'Mexico'        , NULL, 'REGIONAL', 1.00);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (77 , 'LA', 'LATAM Airlines'                 , 'Chile'         , NULL, 'REGIONAL', 1.00);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (78 , 'G3', 'GOL Linhas Aereas'              , 'Brazil'        , NULL, 'DOMESTIC', 0.80);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (79 , 'AR', 'Aerolineas Argentinas'          , 'Argentina'     , NULL, 'REGIONAL', 0.95);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (80 , 'AV', 'Avianca'                        , 'Colombia'      , NULL, 'REGIONAL', 0.95);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (81 , 'FJ', 'Fiji Airways'                   , 'Fiji'          , NULL, 'REGIONAL', 1.05);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (82 , 'BR', 'EVA Air'                        , 'Taiwan'        , NULL, 'REGIONAL', 1.10);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (83 , 'Q2', 'Maldivian'                      , 'Maldives'      , NULL, 'REGIONAL', 0.95);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (84 , 'HU', 'Hainan Airlines'                , 'China'         , NULL, 'REGIONAL', 0.95);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (85 , 'VY', 'Vueling'                        , 'Spain'         , NULL, 'REGIONAL', 0.75);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (86 , 'NK', 'Spirit Airlines'                , 'USA'           , NULL, 'DOMESTIC', 0.70);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (87 , 'JQ', 'Jetstar'                        , 'Australia'     , NULL, 'REGIONAL', 0.75);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (88 , 'WS', 'WestJet'                        , 'Canada'        , NULL, 'REGIONAL', 0.90);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (89 , 'PC', 'Pegasus Airlines'               , 'Turkey'        , NULL, 'REGIONAL', 0.75);
INSERT INTO airlines (airline_id, iata_code, airline_name, country, founded_year, network, fare_factor) VALUES (90 , 'XY', 'flynas'                         , 'Saudi Arabia'  , NULL, 'REGIONAL', 0.78);

-- ---------------------------------------------------------------------
-- AIRPORTS  (1-15 are used by the sample flights below; the rest let
--            flight_search_pkg generate flights between any two of them)
-- ---------------------------------------------------------------------
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (1  , 'DEL', 'Indira Gandhi International Airport'              , 'New Delhi'         , 'India'         ,   28.5562,   77.1000);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (2  , 'BOM', 'Chhatrapati Shivaji Maharaj International Airport', 'Mumbai'            , 'India'         ,   19.0896,   72.8656);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (3  , 'BLR', 'Kempegowda International Airport'                 , 'Bengaluru'         , 'India'         ,   13.1986,   77.7066);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (4  , 'MAA', 'Chennai International Airport'                    , 'Chennai'           , 'India'         ,   12.9941,   80.1709);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (5  , 'CCU', 'Netaji Subhas Chandra Bose International Airport' , 'Kolkata'           , 'India'         ,   22.6547,   88.4467);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (6  , 'HYD', 'Rajiv Gandhi International Airport'               , 'Hyderabad'         , 'India'         ,   17.2403,   78.4294);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (7  , 'AMD', 'Sardar Vallabhbhai Patel International Airport'   , 'Ahmedabad'         , 'India'         ,   23.0772,   72.6347);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (8  , 'PNQ', 'Pune International Airport'                       , 'Pune'              , 'India'         ,   18.5821,   73.9197);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (9  , 'GOI', 'Goa International Airport'                        , 'Goa'               , 'India'         ,   15.3808,   73.8314);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (10 , 'COK', 'Cochin International Airport'                     , 'Kochi'             , 'India'         ,   10.1520,   76.4019);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (11 , 'JAI', 'Jaipur International Airport'                     , 'Jaipur'            , 'India'         ,   26.8242,   75.8122);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (12 , 'LKO', 'Chaudhary Charan Singh International Airport'     , 'Lucknow'           , 'India'         ,   26.7606,   80.8893);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (13 , 'TRV', 'Trivandrum International Airport'                 , 'Thiruvananthapuram', 'India'         ,    8.4821,   76.9201);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (14 , 'DXB', 'Dubai International Airport'                      , 'Dubai'             , 'UAE'           ,   25.2532,   55.3657);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (15 , 'SIN', 'Singapore Changi Airport'                         , 'Singapore'         , 'Singapore'     ,    1.3644,  103.9915);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (16 , 'GAU', 'Lokpriya Gopinath Bordoloi International Airport' , 'Guwahati'          , 'India'         ,   26.1061,   91.5859);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (17 , 'PAT', 'Jay Prakash Narayan International Airport'        , 'Patna'             , 'India'         ,   25.5913,   85.0880);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (18 , 'IXC', 'Chandigarh International Airport'                 , 'Chandigarh'        , 'India'         ,   30.6735,   76.7885);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (19 , 'SXR', 'Srinagar International Airport'                   , 'Srinagar'          , 'India'         ,   33.9871,   74.7742);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (20 , 'IXB', 'Bagdogra International Airport'                   , 'Siliguri'          , 'India'         ,   26.6812,   88.3286);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (21 , 'BBI', 'Biju Patnaik International Airport'               , 'Bhubaneswar'       , 'India'         ,   20.2444,   85.8178);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (22 , 'NAG', 'Dr. Babasaheb Ambedkar International Airport'     , 'Nagpur'            , 'India'         ,   21.0922,   79.0472);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (23 , 'IDR', 'Devi Ahilya Bai Holkar Airport'                   , 'Indore'            , 'India'         ,   22.7218,   75.8011);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (24 , 'VNS', 'Lal Bahadur Shastri International Airport'        , 'Varanasi'          , 'India'         ,   25.4524,   82.8593);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (25 , 'ATQ', 'Sri Guru Ram Dass Jee International Airport'      , 'Amritsar'          , 'India'         ,   31.7096,   74.7973);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (26 , 'IXZ', 'Veer Savarkar International Airport'              , 'Port Blair'        , 'India'         ,   11.6412,   92.7297);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (27 , 'VTZ', 'Visakhapatnam International Airport'              , 'Visakhapatnam'     , 'India'         ,   17.7212,   83.2245);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (28 , 'CJB', 'Coimbatore International Airport'                 , 'Coimbatore'        , 'India'         ,   11.0300,   77.0434);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (29 , 'IXE', 'Mangaluru International Airport'                  , 'Mangaluru'         , 'India'         ,   12.9613,   74.8901);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (30 , 'UDR', 'Maharana Pratap Airport'                          , 'Udaipur'           , 'India'         ,   24.6177,   73.8961);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (31 , 'IXL', 'Kushok Bakula Rimpochee Airport'                  , 'Leh'               , 'India'         ,   34.1359,   77.5465);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (32 , 'BHO', 'Raja Bhoj Airport'                                , 'Bhopal'            , 'India'         ,   23.2875,   77.3374);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (33 , 'RPR', 'Swami Vivekananda Airport'                        , 'Raipur'            , 'India'         ,   21.1804,   81.7388);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (34 , 'DED', 'Jolly Grant Airport'                              , 'Dehradun'          , 'India'         ,   30.1897,   78.1803);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (35 , 'IXR', 'Birsa Munda Airport'                              , 'Ranchi'            , 'India'         ,   23.3143,   85.3217);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (36 , 'IXM', 'Madurai Airport'                                  , 'Madurai'           , 'India'         ,    9.8345,   78.0934);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (37 , 'GOX', 'Manohar International Airport'                    , 'North Goa'         , 'India'         ,   15.7442,   73.8606);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (38 , 'STV', 'Surat International Airport'                      , 'Surat'             , 'India'         ,   21.1141,   72.7418);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (39 , 'VGA', 'Vijayawada International Airport'                 , 'Vijayawada'        , 'India'         ,   16.5304,   80.7968);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (40 , 'CCJ', 'Calicut International Airport'                    , 'Kozhikode'         , 'India'         ,   11.1368,   75.9553);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (41 , 'IMF', 'Imphal International Airport'                     , 'Imphal'            , 'India'         ,   24.7600,   93.8967);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (42 , 'TRZ', 'Tiruchirappalli International Airport'            , 'Tiruchirappalli'   , 'India'         ,   10.7654,   78.7097);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (43 , 'AUH', 'Zayed International Airport'                      , 'Abu Dhabi'         , 'UAE'           ,   24.4330,   54.6511);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (44 , 'DOH', 'Hamad International Airport'                      , 'Doha'              , 'Qatar'         ,   25.2731,   51.6081);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (45 , 'RUH', 'King Khalid International Airport'                , 'Riyadh'            , 'Saudi Arabia'  ,   24.9576,   46.6988);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (46 , 'JED', 'King Abdulaziz International Airport'             , 'Jeddah'            , 'Saudi Arabia'  ,   21.6796,   39.1565);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (47 , 'MCT', 'Muscat International Airport'                     , 'Muscat'            , 'Oman'          ,   23.5933,   58.2844);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (48 , 'BAH', 'Bahrain International Airport'                    , 'Manama'            , 'Bahrain'       ,   26.2708,   50.6336);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (49 , 'KWI', 'Kuwait International Airport'                     , 'Kuwait City'       , 'Kuwait'        ,   29.2266,   47.9689);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (50 , 'KUL', 'Kuala Lumpur International Airport'               , 'Kuala Lumpur'      , 'Malaysia'      ,    2.7456,  101.7099);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (51 , 'BKK', 'Suvarnabhumi Airport'                             , 'Bangkok'           , 'Thailand'      ,   13.6900,  100.7501);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (52 , 'HKT', 'Phuket International Airport'                     , 'Phuket'            , 'Thailand'      ,    8.1132,   98.3169);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (53 , 'HKG', 'Hong Kong International Airport'                  , 'Hong Kong'         , 'Hong Kong'     ,   22.3080,  113.9185);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (54 , 'PEK', 'Beijing Capital International Airport'            , 'Beijing'           , 'China'         ,   40.0799,  116.6031);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (55 , 'PVG', 'Shanghai Pudong International Airport'            , 'Shanghai'          , 'China'         ,   31.1443,  121.8083);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (56 , 'CAN', 'Guangzhou Baiyun International Airport'           , 'Guangzhou'         , 'China'         ,   23.3924,  113.2988);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (57 , 'NRT', 'Narita International Airport'                     , 'Tokyo'             , 'Japan'         ,   35.7720,  140.3929);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (58 , 'HND', 'Haneda Airport'                                   , 'Tokyo'             , 'Japan'         ,   35.5494,  139.7798);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (59 , 'KIX', 'Kansai International Airport'                     , 'Osaka'             , 'Japan'         ,   34.4347,  135.2440);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (60 , 'ICN', 'Incheon International Airport'                    , 'Seoul'             , 'South Korea'   ,   37.4602,  126.4407);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (61 , 'TPE', 'Taoyuan International Airport'                    , 'Taipei'            , 'Taiwan'        ,   25.0797,  121.2342);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (62 , 'MNL', 'Ninoy Aquino International Airport'               , 'Manila'            , 'Philippines'   ,   14.5086,  121.0194);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (63 , 'CGK', 'Soekarno-Hatta International Airport'             , 'Jakarta'           , 'Indonesia'     ,   -6.1256,  106.6559);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (64 , 'DPS', 'Ngurah Rai International Airport'                 , 'Bali'              , 'Indonesia'     ,   -8.7482,  115.1670);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (65 , 'SGN', 'Tan Son Nhat International Airport'               , 'Ho Chi Minh City'  , 'Vietnam'       ,   10.8188,  106.6519);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (66 , 'HAN', 'Noi Bai International Airport'                    , 'Hanoi'             , 'Vietnam'       ,   21.2212,  105.8072);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (67 , 'CMB', 'Bandaranaike International Airport'               , 'Colombo'           , 'Sri Lanka'     ,    7.1808,   79.8841);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (68 , 'MLE', 'Velana International Airport'                     , 'Male'              , 'Maldives'      ,    4.1918,   73.5291);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (69 , 'KTM', 'Tribhuvan International Airport'                  , 'Kathmandu'         , 'Nepal'         ,   27.6966,   85.3591);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (70 , 'DAC', 'Hazrat Shahjalal International Airport'           , 'Dhaka'             , 'Bangladesh'    ,   23.8433,   90.3978);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (71 , 'KHI', 'Jinnah International Airport'                     , 'Karachi'           , 'Pakistan'      ,   24.9065,   67.1608);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (72 , 'TAS', 'Islam Karimov Tashkent International Airport'     , 'Tashkent'          , 'Uzbekistan'    ,   41.2579,   69.2812);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (73 , 'IST', 'Istanbul Airport'                                 , 'Istanbul'          , 'Turkey'        ,   41.2753,   28.7519);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (74 , 'TLV', 'Ben Gurion Airport'                               , 'Tel Aviv'          , 'Israel'        ,   32.0114,   34.8867);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (75 , 'LHR', 'Heathrow Airport'                                 , 'London'            , 'UK'            ,   51.4700,   -0.4543);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (76 , 'LGW', 'Gatwick Airport'                                  , 'London'            , 'UK'            ,   51.1537,   -0.1821);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (77 , 'MAN', 'Manchester Airport'                               , 'Manchester'        , 'UK'            ,   53.3537,   -2.2750);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (78 , 'CDG', 'Charles de Gaulle Airport'                        , 'Paris'             , 'France'        ,   49.0097,    2.5479);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (79 , 'NCE', 'Nice Cote d''Azur Airport'                        , 'Nice'              , 'France'        ,   43.6584,    7.2159);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (80 , 'FRA', 'Frankfurt Airport'                                , 'Frankfurt'         , 'Germany'       ,   50.0379,    8.5622);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (81 , 'MUC', 'Munich Airport'                                   , 'Munich'            , 'Germany'       ,   48.3538,   11.7861);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (82 , 'BER', 'Berlin Brandenburg Airport'                       , 'Berlin'            , 'Germany'       ,   52.3667,   13.5033);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (83 , 'AMS', 'Amsterdam Airport Schiphol'                       , 'Amsterdam'         , 'Netherlands'   ,   52.3105,    4.7683);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (84 , 'MAD', 'Adolfo Suarez Madrid-Barajas Airport'             , 'Madrid'            , 'Spain'         ,   40.4983,   -3.5676);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (85 , 'BCN', 'Josep Tarradellas Barcelona-El Prat Airport'      , 'Barcelona'         , 'Spain'         ,   41.2974,    2.0833);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (86 , 'FCO', 'Leonardo da Vinci-Fiumicino Airport'              , 'Rome'              , 'Italy'         ,   41.8003,   12.2389);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (87 , 'MXP', 'Milan Malpensa Airport'                           , 'Milan'             , 'Italy'         ,   45.6306,    8.7281);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (88 , 'ZRH', 'Zurich Airport'                                   , 'Zurich'            , 'Switzerland'   ,   47.4582,    8.5555);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (89 , 'VIE', 'Vienna International Airport'                     , 'Vienna'            , 'Austria'       ,   48.1103,   16.5697);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (90 , 'CPH', 'Copenhagen Airport'                               , 'Copenhagen'        , 'Denmark'       ,   55.6180,   12.6508);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (91 , 'ARN', 'Stockholm Arlanda Airport'                        , 'Stockholm'         , 'Sweden'        ,   59.6498,   17.9238);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (92 , 'OSL', 'Oslo Gardermoen Airport'                          , 'Oslo'              , 'Norway'        ,   60.1976,   11.1004);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (93 , 'HEL', 'Helsinki Airport'                                 , 'Helsinki'          , 'Finland'       ,   60.3172,   24.9633);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (94 , 'DUB', 'Dublin Airport'                                   , 'Dublin'            , 'Ireland'       ,   53.4264,   -6.2499);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (95 , 'LIS', 'Humberto Delgado Airport'                         , 'Lisbon'            , 'Portugal'      ,   38.7742,   -9.1342);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (96 , 'ATH', 'Athens International Airport'                     , 'Athens'            , 'Greece'        ,   37.9364,   23.9445);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (97 , 'PRG', 'Vaclav Havel Airport Prague'                      , 'Prague'            , 'Czech Republic',   50.1008,   14.2600);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (98 , 'WAW', 'Warsaw Chopin Airport'                            , 'Warsaw'            , 'Poland'        ,   52.1657,   20.9671);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (99 , 'BRU', 'Brussels Airport'                                 , 'Brussels'          , 'Belgium'       ,   50.9010,    4.4844);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (100, 'KEF', 'Keflavik International Airport'                   , 'Reykjavik'         , 'Iceland'       ,   63.9850,  -22.6056);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (101, 'SVO', 'Sheremetyevo International Airport'               , 'Moscow'            , 'Russia'        ,   55.9726,   37.4146);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (102, 'CAI', 'Cairo International Airport'                      , 'Cairo'             , 'Egypt'         ,   30.1219,   31.4056);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (103, 'JNB', 'O. R. Tambo International Airport'                , 'Johannesburg'      , 'South Africa'  ,  -26.1392,   28.2460);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (104, 'CPT', 'Cape Town International Airport'                  , 'Cape Town'         , 'South Africa'  ,  -33.9715,   18.6021);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (105, 'NBO', 'Jomo Kenyatta International Airport'              , 'Nairobi'           , 'Kenya'         ,   -1.3192,   36.9278);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (106, 'ADD', 'Bole International Airport'                       , 'Addis Ababa'       , 'Ethiopia'      ,    8.9779,   38.7993);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (107, 'LOS', 'Murtala Muhammed International Airport'           , 'Lagos'             , 'Nigeria'       ,    6.5774,    3.3212);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (108, 'CMN', 'Mohammed V International Airport'                 , 'Casablanca'        , 'Morocco'       ,   33.3675,   -7.5898);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (109, 'RAK', 'Marrakesh Menara Airport'                         , 'Marrakesh'         , 'Morocco'       ,   31.6069,   -8.0363);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (110, 'MRU', 'Sir Seewoosagur Ramgoolam International Airport'  , 'Mauritius'         , 'Mauritius'     ,  -20.4302,   57.6836);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (111, 'SEZ', 'Seychelles International Airport'                 , 'Mahe'              , 'Seychelles'    ,   -4.6743,   55.5218);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (112, 'ZNZ', 'Abeid Amani Karume International Airport'         , 'Zanzibar'          , 'Tanzania'      ,   -6.2220,   39.2249);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (113, 'ACC', 'Kotoka International Airport'                     , 'Accra'             , 'Ghana'         ,    5.6052,   -0.1668);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (114, 'JFK', 'John F. Kennedy International Airport'            , 'New York'          , 'USA'           ,   40.6413,  -73.7781);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (115, 'EWR', 'Newark Liberty International Airport'             , 'Newark'            , 'USA'           ,   40.6895,  -74.1745);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (116, 'LAX', 'Los Angeles International Airport'                , 'Los Angeles'       , 'USA'           ,   33.9416, -118.4085);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (117, 'SFO', 'San Francisco International Airport'              , 'San Francisco'     , 'USA'           ,   37.6213, -122.3790);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (118, 'ORD', 'O''Hare International Airport'                    , 'Chicago'           , 'USA'           ,   41.9742,  -87.9073);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (119, 'ATL', 'Hartsfield-Jackson Atlanta International Airport' , 'Atlanta'           , 'USA'           ,   33.6407,  -84.4277);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (120, 'DFW', 'Dallas Fort Worth International Airport'          , 'Dallas'            , 'USA'           ,   32.8998,  -97.0403);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (121, 'MIA', 'Miami International Airport'                      , 'Miami'             , 'USA'           ,   25.7959,  -80.2870);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (122, 'SEA', 'Seattle-Tacoma International Airport'             , 'Seattle'           , 'USA'           ,   47.4502, -122.3088);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (123, 'BOS', 'Logan International Airport'                      , 'Boston'            , 'USA'           ,   42.3656,  -71.0096);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (124, 'IAD', 'Washington Dulles International Airport'          , 'Washington'        , 'USA'           ,   38.9531,  -77.4565);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (125, 'LAS', 'Harry Reid International Airport'                 , 'Las Vegas'         , 'USA'           ,   36.0840, -115.1537);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (126, 'HNL', 'Daniel K. Inouye International Airport'           , 'Honolulu'          , 'USA'           ,   21.3187, -157.9225);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (127, 'YYZ', 'Toronto Pearson International Airport'            , 'Toronto'           , 'Canada'        ,   43.6777,  -79.6248);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (128, 'YVR', 'Vancouver International Airport'                  , 'Vancouver'         , 'Canada'        ,   49.1967, -123.1815);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (129, 'YUL', 'Montreal-Trudeau International Airport'           , 'Montreal'          , 'Canada'        ,   45.4706,  -73.7408);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (130, 'MEX', 'Mexico City International Airport'                , 'Mexico City'       , 'Mexico'        ,   19.4361,  -99.0719);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (131, 'CUN', 'Cancun International Airport'                     , 'Cancun'            , 'Mexico'        ,   21.0365,  -86.8771);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (132, 'GRU', 'Sao Paulo-Guarulhos International Airport'        , 'Sao Paulo'         , 'Brazil'        ,  -23.4356,  -46.4731);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (133, 'GIG', 'Rio de Janeiro-Galeao International Airport'      , 'Rio de Janeiro'    , 'Brazil'        ,  -22.8090,  -43.2506);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (134, 'EZE', 'Ministro Pistarini International Airport'         , 'Buenos Aires'      , 'Argentina'     ,  -34.8222,  -58.5358);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (135, 'SCL', 'Arturo Merino Benitez International Airport'      , 'Santiago'          , 'Chile'         ,  -33.3930,  -70.7858);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (136, 'LIM', 'Jorge Chavez International Airport'               , 'Lima'              , 'Peru'          ,  -12.0219,  -77.1143);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (137, 'BOG', 'El Dorado International Airport'                  , 'Bogota'            , 'Colombia'      ,    4.7016,  -74.1469);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (138, 'SYD', 'Sydney Kingsford Smith Airport'                   , 'Sydney'            , 'Australia'     ,  -33.9399,  151.1753);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (139, 'MEL', 'Melbourne Airport'                                , 'Melbourne'         , 'Australia'     ,  -37.6690,  144.8410);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (140, 'BNE', 'Brisbane Airport'                                 , 'Brisbane'          , 'Australia'     ,  -27.3842,  153.1175);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (141, 'PER', 'Perth Airport'                                    , 'Perth'             , 'Australia'     ,  -31.9385,  115.9672);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (142, 'AKL', 'Auckland Airport'                                 , 'Auckland'          , 'New Zealand'   ,  -37.0082,  174.7850);
INSERT INTO airports (airport_id, iata_code, airport_name, city, country, latitude, longitude) VALUES (143, 'NAN', 'Nadi International Airport'                       , 'Nadi'              , 'Fiji'          ,  -17.7554,  177.4431);

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

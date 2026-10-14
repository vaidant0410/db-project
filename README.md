# Airline Reservation System — Oracle SQL / PL/SQL backend

A DBMS lab project: an airline reservation website whose backend is written in **Oracle SQL and PL/SQL**.
Every rule (pricing, flight generation, double-booking protection, refunds, auditing) lives in the database;
a small Node.js API (`api/`) turns web requests into procedure calls and serves the website (`web/`).

* Search between **any two of 143 airports** — flights are generated on demand by PL/SQL
* Pick a seat, book one-way or round trip, manage and cancel bookings, see them all in a profile
* **7 entity tables** + an audit log, **4 views**, **3 functions**, **3 procedures**, **2 packages**,
  **5 triggers** (one of them a compound trigger)

---

## Quick start

You need two programs. Nothing else — no Oracle installation, no database setup.

| Install | Where |
|---|---|
| **Docker Desktop** | <https://www.docker.com/products/docker-desktop/> — after installing, start it and wait until it says *Engine running* |
| **Node.js 18 or newer** | <https://nodejs.org> (the LTS version) |

**1. Get the code.** Either clone it:

```
git clone https://github.com/vaidant0410/db-project.git
cd db-project
```

or, without Git, download the ZIP (on GitHub: **Code → Download ZIP**), unzip it and open a terminal in the
unzipped folder.

**2. Start the database.** In the project folder:

```
docker compose up -d --wait
```

The first time, this downloads Oracle Database Free (about 2.8 GB) and builds the database from the scripts in
`sql/`, which takes a few minutes. It returns when the database is ready. Later starts take seconds.

**3. Start the website.** In the same terminal:

```
cd api
npm install
npm start
```

Wait for `ARS running on http://localhost:3000`.

**4. Open <http://localhost:3000>** in your browser. Search a route, pick a flight, book it.

The database starts **empty** apart from 90 airlines and 143 airports. Flights appear when a route is first
searched; passengers, bookings and payments when someone books — every row comes from using the website.

### Every day after that

| To … | Run (in the project folder) |
|---|---|
| stop the website | press **Ctrl+C** in the terminal running `npm start` |
| stop the database | `docker compose stop` |
| start everything again | `docker compose up -d --wait`, then `cd api` and `npm start` |
| wipe all bookings and flights, keep airlines and airports | `docker compose exec oracle bash /container-entrypoint-startdb.d/10_rebuild_ars.sh --reset` |
| remove the database completely | `docker compose down -v` |

Your data is kept when you stop and start again, and across reboots.

### Look inside the database

Use **Oracle SQL Developer** (desktop app, or the *Oracle SQL Developer* extension for VS Code) and create a
connection with:

| Field | Value |
|---|---|
| Username / password | `ars` / `ars_pass` |
| Host / port | `localhost` / `1522` |
| Service name | `FREEPDB1` |

Open a table and switch to its **Data** tab; press refresh after using the website to see the new rows.
Or use SQL\*Plus inside the container: `docker compose exec oracle sqlplus ars/ars_pass@//localhost:1521/FREEPDB1`.

### If something goes wrong

| Problem | Fix |
|---|---|
| `error during connect` / `cannot find ... dockerDesktopLinuxEngine` | Docker Desktop is not running — start it and wait for *Engine running* |
| `npm start` says `Could not connect to the database` | the database is not up yet — run `docker compose up -d --wait` first |
| `port is already allocated` (1522) or `EADDRINUSE` (3000) | something else uses the port — change `"1522:1521"` in `docker-compose.yml`, or start the website with another port: `PORT=3001 npm start` (PowerShell: `$env:PORT=3001; npm start`) |
| the page has no ascii art and a plain font | the computer is offline — the font and the art load from the internet; everything else still works |
| `docker compose up` waits a long time the first time | normal: the image download and the first build take a few minutes |
| times look off | the database runs on Indian time (`TZ: Asia/Kolkata` in `docker-compose.yml`); change it there |

---

## 1. Repository layout

```
sql/
  00_drop.sql        drop every project object (safe to run on an empty schema)
  01_schema.sql      tables, keys, constraints, indexes
  02_reference_data.sql  90 airlines and 143 airports; no flights, passengers or bookings
  03_views.sql       available_seats, passenger_itinerary, airline_revenue
  04_functions.sql   calculate_fare, seats_left, refund_percentage
  05_procedures.sql  book_ticket, cancel_booking, show_passenger_bookings
  06_triggers.sql    validation, double-booking guard, seat sync, audit log
  07_package.sql     reservation_pkg (bundles the booking API)
  08_flight_search.sql  flight_search_pkg (search any route, seat map, quick booking) + departures_board view
  run_all.sql        runs 00 → 08 in order
api/                 server.js: Express + node-oracledb, the HTTP API; also serves web/
web/                 index.html: one page with six tabs (home, book a flight, departures,
                     hot destinations, manage booking, profile); assets/ holds the shared styles and scripts.
                     The animated ascii art comes from ascii.rest (MIT licence).
docker-compose.yml   Oracle Database Free in a container; the schema is built on the first start
docker/startdb/      10_rebuild_ars.sh, the script that builds (or with --reset, rebuilds) the schema
docs/                ER diagrams (airline_erd_overview.png, airline_erd_detail.png, with .svg sources)
README.md            this file
```

---

## 2. Running without Docker (optional)

Only needed if you would rather install Oracle yourself, e.g. **Oracle Database 21c XE**.

1. Download Oracle Database 21c Express Edition from
   <https://www.oracle.com/database/technologies/xe-downloads.html> (an Oracle account is required).
   **Windows:** unzip it and run `setup.exe`; choose a password for `SYS` / `SYSTEM` and keep port **1521**.
   **Linux:** install the preinstall package and the `oracle-database-xe-21c` RPM, then run
   `sudo /etc/init.d/oracle-xe-21c configure`. SQL\*Plus is installed with the database.
2. Create the project user in the pluggable database **`XEPDB1`** (once):

   ```
   sqlplus system/YourPassword@//localhost:1521/XEPDB1
   ```

   ```sql
   CREATE USER ars IDENTIFIED BY ars_pass
     DEFAULT TABLESPACE users QUOTA UNLIMITED ON users;
   GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE,
         CREATE PROCEDURE, CREATE TRIGGER TO ars;
   EXIT
   ```

   If `CREATE USER` fails with **ORA-65096**, you are connected to the container root (`XE`) instead of `XEPDB1`.
3. Build the schema from the project folder (this also resets it to empty whenever you run it again):

   ```
   sqlplus ars/ars_pass@//localhost:1521/XEPDB1 @sql/run_all.sql
   ```

   `run_all.sql` runs `00` → `08` in order, lists any object that failed to compile, and writes `run_all.log`.
4. Start the website against this database. In `api/`:

   ```
   npm install
   DB_CONNECT=localhost:1521/XEPDB1 npm start
   ```

   (PowerShell: `$env:DB_CONNECT="localhost:1521/XEPDB1"; npm start`.) On Oracle 23ai Free the service is `FREEPDB1`.

---

## 3. The API

The API reads `DB_USER`, `DB_PASSWORD`, `DB_CONNECT` and `PORT` from the environment; the defaults
(`ars`, `ars_pass`, `localhost:1522/FREEPDB1`, `3000`) match the Docker database.

| Endpoint | Calls |
|---|---|
| `GET /api/airports` | `airports` table |
| `GET /api/search?from=DEL&to=LHR&date=2026-10-20&cls=ECONOMY` | `flight_search_pkg.search_flights` |
| `GET /api/flights/:id/seats` | `flight_search_pkg.seat_map` |
| `POST /api/bookings` `{firstName, lastName, email, phone, flightId, seatClass, seatNo?, method}` | `flight_search_pkg.quick_book`, then `COMMIT` |
| `GET /api/bookings/:id?email=` | `flight_search_pkg.find_booking` |
| `POST /api/bookings/round-trip` `{firstName, lastName, email, phone, method, legs: [2 x {flightId, seatClass, seatNo?}]}` | `flight_search_pkg.quick_book_round_trip`, then `COMMIT` |
| `POST /api/bookings/:id/cancel` `{email}` | `flight_search_pkg.cancel_my_booking`, then `COMMIT` |
| `POST /api/profile` `{email, phone}` | `flight_search_pkg.my_bookings` (all past and future bookings of that e-mail) |
| `GET /api/departures?from=DEL&limit=14` | `flight_search_pkg.ensure_departures` (schedules the airport's day if needed), then the `departures_board` view: that airport, today |
| `GET /api/fares/from/:origin?to=BOM,DXB` | `flight_search_pkg.fare_from`: lowest possible fare per destination (read-only, creates no flights) |

Errors raised by the packages (`ORA-20xxx`) come back as JSON `{error, code}` with a matching HTTP status
(404 not found, 409 conflict, 400 bad input, 422 not bookable, 402 payment declined).

---

## 4. Data model

```
airlines 1───< flights >───1 airports (origin)
                  │   └─────1 airports (destination)
                  1
                  │
                  └───< seats 1───< bookings >───1 passengers
                                       │
                                       1
                                       │
                                    payments             (one payment per booking)

bookings ──(trigger)──> booking_audit_log
```

| Table | Purpose | Notable rules |
|---|---|---|
| `airlines` | carriers | unique 2-character IATA code and name; `network` DOMESTIC / REGIONAL / GLOBAL; `fare_factor` 0.5–2 |
| `airports` | airports | unique 3-letter IATA code; latitude / longitude for distances |
| `flights` | scheduled flights | origin ≠ destination (CHECK), departure < arrival (trigger), unique (flight_no, departure) |
| `passengers` | customers | unique (e-mail, first name, last name), so one e-mail can book for a family; phone 7–15 digits with an optional `+`; date of birth, gender and passport optional |
| `seats` | seat inventory per flight | class ECONOMY / BUSINESS / FIRST, status AVAILABLE / BOOKED, unique (flight, seat_no) |
| `bookings` | a passenger holding a seat | status CONFIRMED / CANCELLED; the flight is reached through the seat (3NF) |
| `payments` | money in and out | one per booking, refund ≤ amount |
| `booking_audit_log` | history of every booking change | no foreign key, so it survives deletions |

**Referential actions**

| Action | Where |
|---|---|
| `ON DELETE CASCADE` | airline → flights · flight → seats · passenger → bookings · booking → payment |
| no action (restrict) | airports in use, and `bookings.seat_id` — a flight that still has bookings cannot be deleted |

Identity columns start at **1000**; the reference data uses explicit ids below 1000, so they never collide.

Every flight is generated by `flight_search_pkg` and has 70 seats: 1 first-class row (2 seats), 2 business rows
(8 seats) and 10 economy rows (60 seats). Flights of 4,000 km or more get a second first-class row (72 seats).

---

## 5. Business rules

**Fare** — `calculate_fare(flight_id, seat_class)`

```
fare = base_fare × class multiplier        ECONOMY 1.0 | BUSINESS 2.5 | FIRST 4.0
       × 1.15  when 75 % or more of the flight's seats are booked
       × 1.20  when the flight departs within 48 hours
```

**Refund** — `cancel_booking` (hours between cancellation and departure)

| Time before departure | Refund |
|---|---|
| 72 h or more | 90 % |
| 24 h to 72 h | 50 % |
| under 24 h | 10 % |
| already departed | cancellation refused |

**Booking** — `book_ticket(passenger, flight, seat_no, method, OUT booking_id [, amount_paid])`
validates the passenger, flight and seat, locks the seat row (`SELECT … FOR UPDATE`), prices it, inserts the
booking and the payment, and marks the seat. It takes a `SAVEPOINT` on entry; **any** failure rolls back to it
and re-raises the error, so a half-finished booking is never left behind. The procedures never `COMMIT` —
the caller controls the transaction.

**Flight search** — `flight_search_pkg.search_flights(origin, destination, date, class, OUT cursor)`.
The first search for a route and day generates 4–7 non-stop flights (`ensure_flights`):

```
distance  = great-circle distance between the airports (haversine)
duration  = 30 min + distance at 800 km/h, rounded to 5 minutes
airlines  = domestic route: the airlines of that country
            international route: REGIONAL / GLOBAL airlines of the two countries (60 %)
                                 + GLOBAL airlines from elsewhere (40 %)
            low-cost carriers (fare_factor < 0.90) only up to 5,000 km
base fare = (1,500 + 4.8 INR per km) x airline fare_factor x 0.85-1.15, rounded to 10 INR
seats     = 15-80 % already sold through other channels (first class half as much)
```

**Departures board** — `flight_search_pkg.ensure_departures(airport, day)` runs `ensure_flights` for the airport's
main routes: up to 5 domestic airports more than 150 km away and the 3 nearest international hubs. The website
calls it for the visitor's nearest airport when the departures tab opens, so the board shows that airport's day.

`DBMS_RANDOM` is seeded with route + date, so the same search always gives the same flights. Generated flights
are written in an autonomous transaction (they are timetable data and stay even if the caller rolls back), and a
row lock on the origin airport stops two sessions from generating the same route at once.

**Quick booking** — `flight_search_pkg.quick_book(first, last, email, phone, flight, class, seat_no, method, OUT …)`
needs nothing but a name, e-mail and phone: it finds or creates the passenger, picks the first free seat of the
class when no seat is given, and calls `book_ticket`. A booking is later found or cancelled with its number and
the e-mail (`find_booking`, `cancel_my_booking`).

**Round trip** — `flight_search_pkg.quick_book_round_trip` calls `quick_book` twice under one `SAVEPOINT`: if the
return leg fails (seat taken, sold out, …) the outbound booking is rolled back too, so a customer never ends up
with half a trip. The return flight must leave after the outbound flight lands (-20019).

**Profile** — `flight_search_pkg.my_bookings(email, phone, OUT cursor)` lists every booking made with an e-mail,
past and future, once the phone number matches one of its passengers (the last 10 digits are compared, so
`+91 98100 12345` and `9810012345` are the same number).

### Custom error codes

| Code | Meaning | Raised by |
|---|---|---|
| -20001 | flight does not exist | functions, procedures |
| -20002 | invalid seat class | `calculate_fare` |
| -20003 | seat not found on that flight | `book_ticket` |
| -20004 | seat already booked | `book_ticket` |
| -20005 | passenger does not exist | `book_ticket`, `show_passenger_bookings` |
| -20006 | flight not open for booking | `book_ticket` |
| -20007 | payment declined | `book_ticket` |
| -20008 | booking does not exist | `cancel_booking` |
| -20009 | booking already cancelled | `cancel_booking` |
| -20010 | flight already departed | `cancel_booking` |
| -20011 | unknown airport code | `flight_search_pkg` |
| -20012 | origin and destination are the same airport | `flight_search_pkg` |
| -20013 | date outside the booking window (today to 365 days) | `flight_search_pkg` |
| -20014 | no seats left in that class | `quick_book` |
| -20015 | no booking with that number for that e-mail | `find_booking`, `cancel_my_booking` |
| -20016 | first and last name are required | `quick_book` |
| -20017 | invalid e-mail address | `quick_book` |
| -20018 | invalid phone number | `quick_book`, `my_bookings` |
| -20019 | return flight leaves before the outbound flight lands | `quick_book_round_trip` |
| -20020 | no bookings for that e-mail and phone number | `my_bookings` |
| -20101 | arrival not after departure | trigger `trg_flights_validate_times` |
| -20102 | seat already booked | trigger `trg_bookings_no_double_booking` |
| -20103 | passenger already holds a seat on the flight | compound trigger `trg_bookings_one_per_flight` |

### Triggers and the mutating-table error (ORA-04091)

| Trigger | Type | Job |
|---|---|---|
| `trg_flights_validate_times` | BEFORE ROW | departure must be earlier than arrival |
| `trg_bookings_no_double_booking` | BEFORE ROW | locks the seat row and refuses a seat that is already BOOKED |
| `trg_bookings_one_per_flight` | **COMPOUND** | one CONFIRMED seat per passenger per flight |
| `trg_bookings_seat_status` | AFTER ROW | seat becomes BOOKED on confirm, AVAILABLE on cancel / delete / seat change |
| `trg_bookings_audit` | AFTER ROW | writes every INSERT / UPDATE / DELETE to `booking_audit_log` |

A row trigger may not read the table that fired it. The seat check reads `seats`, and the seat-status and
audit triggers only write to other tables, so plain row triggers are safe. The one rule that must **count rows
in `bookings`** is implemented as a compound trigger: the row-level section only remembers which rows changed,
and the counting happens in `AFTER STATEMENT`, when `bookings` is no longer mutating.
The partial unique index `uq_bookings_active_seat` is a last line of defence if two sessions ever race for the
same seat.

---

## 6. Troubleshooting (manual Oracle install)

| Symptom | Cause / fix |
|---|---|
| `SP2-0310: unable to open file "sql/run_all.sql"` | you are in a different folder; use the correct relative path or an absolute path |
| `ORA-12514` / `ORA-12541` | listener not running or wrong service name; use `localhost:1521/XEPDB1` and start the `OracleServiceXE` and listener services |
| `ORA-01017: invalid username/password` | wrong password, or the user was created in the container root instead of `XEPDB1` |
| `ORA-01031: insufficient privileges` on `CREATE …` | run the `GRANT` statement from section 2 |
| `ORA-01950: no privileges on tablespace 'USERS'` | the user needs `QUOTA UNLIMITED ON users` |
| `Warning: … created with compilation errors` | run `SHOW ERRORS` straight after the failing script; the scripts already do this |
| output wraps or columns look ragged | widen the terminal to at least 200 columns (`mode con cols=200` on Windows cmd) |
| `ORA-20006` / `ORA-20010` | the flight has already departed — search a later date |

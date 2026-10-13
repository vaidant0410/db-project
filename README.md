# Airline Reservation System — Oracle SQL / PL/SQL backend

A DBMS lab project: the complete database backend of an airline reservation system, written in pure
**Oracle SQL and PL/SQL** for **Oracle Database 21c Express Edition**, run from **SQL\*Plus**.
Every rule (pricing, double-booking protection, refunds, auditing) lives in the database, so a frontend
or API layer only has to call the procedures / package and read the views.

* **10 entity tables** — airlines, airports, aircraft, flights, passengers, seats, bookings, payments,
  crew, flight_crew (+ `booking_audit_log`)
* **3 views**, **3 functions**, **3 procedures**, **1 package**, **5 triggers** (one of them a compound trigger)

---

## 1. Repository layout

```
sql/
  00_drop.sql        drop every project object (safe to run on an empty schema)
  01_schema.sql      tables, keys, constraints, indexes
  02_data.sql        sample data (Indian airlines and airports), ends with COMMIT
  03_views.sql       available_seats, passenger_itinerary, airline_revenue
  04_functions.sql   calculate_fare, seats_left, refund_percentage
  05_procedures.sql  book_ticket, cancel_booking, show_passenger_bookings
  06_triggers.sql    validation, double-booking guard, seat sync, audit log
  07_package.sql     reservation_pkg (optional, bundles the booking API)
  run_all.sql        runs 00 → 07 in order
docker-compose.yml   Oracle Database Free in a container; the schema is rebuilt on every start
docker/startdb/      10_rebuild_ars.sh, the script that rebuilds the schema
docs/                ER diagrams (airline_erd_overview.png, airline_erd_detail.png, with .svg sources)
README.md            this file
```

---

## 2. Install Oracle Database 21c XE

1. Download **Oracle Database 21c Express Edition** for your OS from
   <https://www.oracle.com/database/technologies/xe-downloads.html> (an Oracle account is required).
2. **Windows:** unzip the download and run `setup.exe`. When asked, choose a password — it is used for the
   `SYS`, `SYSTEM` and `PDBADMIN` accounts. Keep the default port **1521**.
   **Linux:** install the preinstall package and the `oracle-database-xe-21c` RPM, then run
   `sudo /etc/init.d/oracle-xe-21c configure`.
3. The installer creates the database service and the listener and starts them. On Windows, check that the
   services **OracleServiceXE** and **OracleOraDB21Home1TNSListener** are *Running* (`services.msc`).
4. SQL\*Plus is installed together with the database. On Windows it is in
   `C:\app\<your-user>\product\21c\dbhomeXE\bin\` — add that folder to your `PATH`, or run it by full path.

XE contains one container database (`XE`) and one pluggable database, **`XEPDB1`**. Work in `XEPDB1`.

---

## 3. Connect with SQL\*Plus and create the project user

Connect to the pluggable database as `SYSTEM` (replace the password with the one from installation):

```
sqlplus system/YourPassword@//localhost:1521/XEPDB1
```

Create a dedicated user for the project (do this once):

```sql
CREATE USER ars IDENTIFIED BY ars_pass
  DEFAULT TABLESPACE users QUOTA UNLIMITED ON users;

GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE,
      CREATE PROCEDURE, CREATE TRIGGER TO ars;

EXIT
```

> If `CREATE USER` fails with **ORA-65096: invalid common user or role name**, you are connected to the
> container root (`XE`) instead of `XEPDB1` — check the service name in the connect string.

Now connect as the project user:

```
sqlplus ars/ars_pass@//localhost:1521/XEPDB1
```

---

## 4. Run the project

### Everything in one go

From the repository root (or from anywhere — `run_all.sql` locates its sibling scripts itself):

```
sqlplus ars/ars_pass@//localhost:1521/XEPDB1 @sql/run_all.sql
```

or, from inside an SQL\*Plus session:

```
SQL> @sql/run_all.sql
```

`run_all.sql` drops old objects, rebuilds the schema, loads the data, creates views / functions /
procedures / triggers / package, and lists any object that failed to compile. Output is also written to
`run_all.log` in your current directory.

### One script at a time

```
SQL> @sql/00_drop.sql
SQL> @sql/01_schema.sql
SQL> @sql/02_data.sql
...
SQL> @sql/07_package.sql
```

Scripts `03`–`07` need the earlier ones to have been run.

### Start over

`@sql/run_all.sql` (or just `@sql/00_drop.sql` followed by `01`…`07`) resets the database to the sample state.
Flight dates in the sample data are relative to the moment `02_data.sql` runs, so reload it when the sample
flights have departed and you need bookable ones again.

### Or: run it in Docker (recommended for development)

With [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed, one command starts an Oracle
Database Free container and builds the schema from `sql/00`–`07` (the schema is rebuilt on **every** start, so the
flight dates are always fresh):

```
docker compose up -d --wait
```

Connect with `ars` / `ars_pass` at `localhost:1522`, service name `FREEPDB1`
(`sqlplus ars/ars_pass@//localhost:1522/FREEPDB1`). Port 1522 is used so it does not clash with a local Oracle XE
on 1521. To reset the data without restarting:

```
docker compose exec oracle bash /container-entrypoint-startdb.d/10_rebuild_ars.sh
```

These are the connection details a frontend / API layer should use during development.

---

## 5. Data model

```
airlines 1───< aircraft 1───< flights >───1 airports (origin)
    │  └──────────────────────────^  └──────1 airports (destination)
    │
    ├───< crew >───< flight_crew >───  flights          (many-to-many)
    │
    └───< flights 1───< seats 1───< bookings >───1 passengers
                                       │
                                       1
                                       │
                                    payments             (one payment per booking)

bookings ──(trigger)──> booking_audit_log
```

| Table | Purpose | Notable rules |
|---|---|---|
| `airlines` | carriers | unique 2-character IATA code and name |
| `airports` | airports | unique 3-letter IATA code |
| `aircraft` | fleet | unique registration, status ACTIVE / MAINTENANCE / RETIRED |
| `flights` | scheduled flights | origin ≠ destination (CHECK), departure < arrival (trigger), unique (flight_no, departure) |
| `passengers` | customers | unique e-mail, 10-digit phone (CHECK), optional unique passport |
| `seats` | seat inventory per flight | class ECONOMY / BUSINESS / FIRST, status AVAILABLE / BOOKED, unique (flight, seat_no) |
| `bookings` | a passenger holding a seat | status CONFIRMED / CANCELLED; the flight is reached through the seat (3NF) |
| `payments` | money in and out | one per booking, refund ≤ amount |
| `crew`, `flight_crew` | staff and their assignments | junction table with composite primary key |
| `booking_audit_log` | history of every booking change | no foreign key, so it survives deletions |

**Referential actions**

| Action | Where |
|---|---|
| `ON DELETE CASCADE` | airline → aircraft, flights, crew · flight → seats, flight_crew · passenger → bookings · booking → payment · crew → flight_crew |
| `ON DELETE SET NULL` | `flights.aircraft_id` (an aircraft can be retired while its flight history stays) |
| no action (restrict) | airports in use, and `bookings.seat_id` — a flight that still has bookings cannot be deleted |

Identity columns start at **1000**; the sample data uses explicit ids below 1000, so they never collide.

The seat map is deliberately small — **6 seats per flight** (2 premium, 4 economy) — to keep sample output
readable. `aircraft.total_seats` holds the real capacity of the aircraft type.

---

## 6. Business rules

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

## 7. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `SP2-0310: unable to open file "sql/run_all.sql"` | you are in a different folder; use the correct relative path or an absolute path |
| `ORA-12514` / `ORA-12541` | listener not running or wrong service name; use `localhost:1521/XEPDB1` and start the `OracleServiceXE` and listener services |
| `ORA-01017: invalid username/password` | wrong password, or the user was created in the container root instead of `XEPDB1` |
| `ORA-01031: insufficient privileges` on `CREATE …` | run the `GRANT` statement from section 3 |
| `ORA-01950: no privileges on tablespace 'USERS'` | the user needs `QUOTA UNLIMITED ON users` |
| `Warning: … created with compilation errors` | run `SHOW ERRORS` straight after the failing script; the scripts already do this |
| output wraps or columns look ragged | widen the terminal to at least 200 columns (`mode con cols=200` on Windows cmd) |
| `ORA-20006` / `ORA-20010` on sample flights | the sample data is old and its flights have departed — run `run_all.sql` again |

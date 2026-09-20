# Demo script — Airline Reservation System

A **10–15 minute** presentation, given alone. Everything runs live in one notebook, `demo/airline_demo.sqlnb`, inside VS Code: you press a run button, the database answers, and you say one plain sentence about what just happened. There is nothing to type.

Each box in the notebook starts with a plain-English explanation. The technical term sits underneath in italics, so the box makes sense to anyone and the real names are still there for the examiner.

---

## Before you start (10 minutes before)

1. **Start Docker Desktop** and wait until it says *Engine running*.
2. In the project folder, start the database (about a minute the first time, a few seconds after that):
   ```
   docker compose up -d --wait
   ```
3. Open the folder `D:\proj-backend` in VS Code, then open **`demo/airline_demo.sqlnb`**.
4. Click **No connection attached** at the bottom right of the window and pick **ARS Docker**
   (user `ars`, password `ars_pass`, host `localhost`, port `1522`, service name `FREEPDB1`).
5. Press the first box, *Is everything ready?* It must say **READY**. If it does not, reset the data:
   ```
   docker compose exec oracle bash /container-entrypoint-startdb.d/10_rebuild_ars.sh
   ```
6. Make the text big (**Ctrl and +** a few times) so the back of the room can read it. Close other windows and switch off notifications.
7. Record one clean run as a backup (**Win+G** on Windows), in case something fails on the day.

The sample data stays READY for about 17 hours after it is loaded, because the flight dates are relative to the load time. Do step 5 on the morning of the presentation. Restarting the container reloads the data too.

---

## The plan

**Open with (30 seconds):** *"This is an airline ticket system. All the rules live inside the database, so a seat can never be booked twice and a booking is never left half-done. I'll show it working, and then how it is built."*

Press each box in this order and say the sentence next to it. The notebook is in the same order.

### 1. Watch it work (about 7 minutes)

| Box | Say | What appears |
|---|---|---|
| **Book a ticket** | "One command books the seat and takes the payment. The database also writes its own diary entry." | ticket CONFIRMED; seat BOOKED, one fewer left; audit row `INSERT` |
| **Nobody can steal a seat** | "Someone else wants the same seat, the normal way and through the back door. Both are refused." | `ORA-20004` (front door), `ORA-20102` (back door) |
| **One seat per person** | "A second seat on the same flight is refused." | `ORA-20103` |
| **If something goes wrong, nothing is left half-done** | "The payment fails halfway, and the booking is undone too. Same numbers before and after." | counts 18 and 18 both times; `ORA-20007`, `ORA-02290` |
| **Cancel and get money back** | "Ninety percent back, the seat is free again, and the diary is updated." | refund **9,450.00 (90%)**; CANCELLED / REFUNDED; seat AVAILABLE; audit `INSERT` then `UPDATE` |
| **Cancel later, get less back** | "The closer to take-off, the less you get." | **2,760.00 (50%)** and **520.00 (10%)** |
| **Cancelling things that cannot be cancelled** | "Twice, after take-off, or a ticket that does not exist: refused, with a reason." | `ORA-20009`, `ORA-20010`, `ORA-20008` |
| **Bad data bounces off** | "Six bad things typed in. Every one is refused." | `ORA-00001`, `ORA-02290`, `ORA-01400`, `ORA-02291`, `ORA-20101`, `ORA-02290` |
| **Deleting things safely** | "Three delete rules: protect it, keep it, or delete the related things too." | `ORA-02292` twice; `aircraft_id` becomes empty; booking and payment gone, seat free, audit `DELETE` |

Whenever the output says **The database said NO**, that is the point: the rules are working. Say so once, early, so nobody mistakes it for a failure.

### 2. Ask it questions (about 2 minutes)

Fifteen questions are in the notebook. Show three or four and mention the rest exist:

- **Question 3** (LEFT OUTER JOIN): Lufthansa has no flights and still appears, with 0.
- **Question 7** (GROUP BY ... HAVING): the cities with at least two confirmed bookings.
- **Question 10** (correlated subquery): flights priced above the average of *their own* airline.
- **Question 15** (MINUS): the airports where planes only arrive.

### 3. How it is built (about 2 minutes, optional)

Scroll through the headings only: **tables** (the pages of the notebook), **rules** (guards on the doors), **windows** (views), **calculators** (functions), **recipes** (procedures), **toolbox** (package), **automatic helpers** (triggers). Run the fare box: flight 2 business is 10,500; flight 1, nearly full, is 16,675.

### The end (30 seconds)

Press the last box: **18 bookings and 18 payments**, exactly as before. *"Nothing we did was kept. Constraints protect the structure, triggers protect the rules, and procedures make every booking all-or-nothing. Thank you. Questions?"*

---

## If something goes wrong

| What you see | What to do |
|---|---|
| The first box does not say READY | Run the reset command from step 5 above, then press the box again. |
| A box prints **OOPS**, or a red error | Reset the data and run the box again. Say nothing dramatic: "let me reset that". |
| A "Could not cancel booking 13" line | The sample data has gone stale. Reset it. |
| VS Code cannot connect | Check that Docker Desktop says *Engine running* and `docker compose ps` says *healthy*. The port is **1522**, the service name is **FREEPDB1**. |
| Nothing works at all | Play the recording you made in step 7. |

---

## Questions she might ask

Short answers you can give. They are grouped by topic.

### Design and constraints

1. **Why identity columns instead of sequences plus a trigger?**
   Less code and no trigger to maintain; the database guarantees unique ids. `GENERATED BY DEFAULT ON NULL`
   lets our sample data supply explicit ids while new rows get generated ones (starting at 1000, so no clash).
2. **What is the difference between PRIMARY KEY and UNIQUE?**
   A table has one primary key (unique + NOT NULL). It may have many UNIQUE constraints and they allow NULLs
   (e.g. `passport_no`).
3. **Explain ON DELETE CASCADE vs SET NULL vs the default. Where do you use each and why?**
   CASCADE: airline → aircraft/flights, flight → seats, passenger → bookings, booking → payment. SET NULL:
   `flights.aircraft_id`. Default (restrict): airports, and `bookings.seat_id` — a flight with bookings must
   not vanish, so deleting it fails with ORA-02292.
4. **Which normal form is the design in? Why does `bookings` not have a `flight_id`?**
   3NF. `flight_id` is determined by `seat_id`; storing it in bookings would duplicate data and allow a
   booking whose seat and flight disagree.
5. **Why is `flight_crew` a separate table?**
   Flights and crew are many-to-many. The junction table's composite primary key `(flight_id, crew_id)`
   prevents assigning the same person to the same flight twice.
6. **What is the `uq_bookings_active_seat` index?**
   A function-based unique index on `CASE WHEN status='CONFIRMED' THEN seat_id END`. Cancelled rows become NULL
   and are not indexed, so a seat can have many cancelled bookings but only one confirmed one.
7. **What is a view? Can you INSERT into `airline_revenue`?**
   A stored query, no data of its own. No — a view with GROUP BY / aggregates is not updatable.
8. **What is the difference between DROP, TRUNCATE and DELETE? What does PURGE do?**
   DROP removes the table; TRUNCATE removes all rows fast without rollback; DELETE removes chosen rows and can be
   rolled back. PURGE skips the recycle bin so the space is freed immediately.
9. **Why CHECK constraints instead of lookup tables for status / class?**
   Fixed, tiny value sets that never change — a CHECK is simpler. If the business added classes often, a lookup
   table with a foreign key would be better.

### Functions, procedures and the package

1. **Function vs procedure?**
   A function returns a value and can be used inside SQL; a procedure performs an action and may return values
   through OUT parameters. `calculate_fare` is a function because we want `SELECT calculate_fare(...)`;
   `book_ticket` changes data, so it is a procedure.
2. **What does SAVEPOINT do, and how is `ROLLBACK TO SAVEPOINT` different from `ROLLBACK`?**
   A savepoint marks a point in the transaction. `ROLLBACK TO` undoes only the work after it; the transaction
   stays open. Plain `ROLLBACK` undoes everything since the last COMMIT.
3. **Why do the procedures not COMMIT?**
   The caller may be running several steps as one unit of work. The procedure guarantees it leaves nothing
   half-done (via the savepoint), and the caller decides when to make it permanent.
4. **What does `RAISE_APPLICATION_ERROR` do? Why -20001 to -20999?**
   It raises a user-defined error with your own code and message. Oracle reserves that range for applications;
   other numbers belong to Oracle's own errors.
5. **Why `WHEN OTHERS THEN ROLLBACK TO SAVEPOINT …; RAISE;` — why re-raise?**
   Rolling back cleans up. Re-raising tells the caller what went wrong; swallowing the exception would make a
   failed booking look successful.
6. **What does `SELECT … FOR UPDATE` do here?**
   It locks the seat row until COMMIT/ROLLBACK. A second session trying to book the same seat waits, then
   re-reads the row, sees `BOOKED`, and is refused — no double booking, no lost update.
7. **Explicit vs implicit cursor? What are the cursor attributes?**
   An implicit cursor is created by Oracle for every SQL statement (`SQL%ROWCOUNT`). An explicit cursor is
   declared by you for multi-row queries and controlled with OPEN / FETCH / CLOSE. Attributes: `%FOUND`,
   `%NOTFOUND`, `%ROWCOUNT`, `%ISOPEN`.
8. **What is `%TYPE` / `%ROWTYPE`?**
   `%TYPE` copies one column's data type; `%ROWTYPE` copies a whole row (or cursor row) structure. The code
   adapts if a column type changes.
9. **What is a package — specification vs body — and why use one?**
   The specification declares the public interface; the body holds the implementation and private items.
   Benefits: one namespace, hidden internals, and the body can be recompiled without invalidating callers.
10. **What does `DETERMINISTIC` mean on `refund_percentage`?**
    The same input always gives the same output, so Oracle may cache results.

### Triggers, queries and transactions

1. **Row-level vs statement-level trigger? BEFORE vs AFTER? What are `:NEW` and `:OLD`?**
   Row-level fires once per affected row (`FOR EACH ROW`), statement-level once per statement. BEFORE can validate
   or change `:NEW` values before the write; AFTER sees the final state. `:OLD`/`:NEW` hold the row before and
   after the change (`:OLD` is NULL on INSERT, `:NEW` is NULL on DELETE).
2. **What is ORA-04091 and how did you avoid it?**
   A row trigger tried to query or change the table that fired it, which is mid-change ("mutating"). We only
   read/write *other* tables in row triggers, and the rule that must count `bookings` is a compound trigger that
   counts in the `AFTER STATEMENT` section.
3. **What is a compound trigger? Name its timing points.**
   One trigger with several sections sharing variables: `BEFORE STATEMENT`, `BEFORE EACH ROW`,
   `AFTER EACH ROW`, `AFTER STATEMENT`. State kept in the declaration section lives for the statement.
4. **Why check double booking in a BEFORE trigger with FOR UPDATE — and also keep a unique index?**
   BEFORE fires early enough to give a clear custom error; `FOR UPDATE` serialises two sessions racing for a
   seat. The unique index is the final guarantee if anything bypasses the check.
5. **Why is the departure-before-arrival rule a trigger and not a CHECK constraint?**
   A CHECK *could* do it, because both columns are in the same row, and is the better choice in production
   (declarative, cheaper). We used a trigger to demonstrate custom messages with `RAISE_APPLICATION_ERROR`.
   Rules that need other tables or the current time — like our seat rule — cannot be CHECK constraints.
6. **Why does `booking_audit_log` have no foreign key?**
   The log must outlive the booking. With a foreign key, deleting a booking (e.g. cascade from a passenger)
   would fail or delete its history.
7. **INNER vs LEFT vs RIGHT vs FULL OUTER join?**
   INNER keeps matching rows only. LEFT keeps every left row, RIGHT every right row, FULL both, filling
   NULLs where there is no match.
8. **WHERE vs HAVING?**
   WHERE filters rows before grouping; HAVING filters groups after aggregation (e.g. `COUNT(*) >= 2`).
9. **Correlated vs non-correlated subquery? EXISTS vs IN?**
   A correlated subquery refers to the outer row and is evaluated per row (Q10). Non-correlated runs once (Q8).
   EXISTS stops at the first match and handles NULLs safely; NOT EXISTS is the safe anti-join (`NOT IN`
   misbehaves with NULLs).
10. **UNION vs UNION ALL? What is MINUS?**
    UNION removes duplicates, UNION ALL keeps them (faster). MINUS returns rows of the first query that are not
    in the second — Oracle's name for `EXCEPT`.
11. **Show ACID in your project.**
    *Atomicity* — the "If something goes wrong, nothing is left half-done" box. *Consistency* — the "Nobody can steal a seat", "One seat per person" and "Bad data bounces off" boxes.
    *Isolation* — `FOR UPDATE` row lock. *Durability* — committed data survives (`02_data.sql` ends with COMMIT).
12. **Two users book the same seat at the same moment — what happens?**
    Both call `book_ticket`; the first locks the seat row. The second waits at `FOR UPDATE`, then finds the seat
    `BOOKED` and gets ORA-20004. If both somehow reached the insert, the unique index would raise ORA-00001.

---

## Checklist

- [ ] Docker Desktop is running and `docker compose ps` shows *healthy*.
- [ ] The first notebook box says **READY**.
- [ ] The text is big, notifications are off, other windows are closed.
- [ ] The backup recording is saved.
- [ ] You can explain **why** each constraint and trigger exists, not just what it does.
- [ ] Repository pushed: `git status` is clean and `git log` shows the scripts.

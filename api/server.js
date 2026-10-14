// ARS API: a thin HTTP layer over the Oracle packages.
// Every rule (pricing, seat locks, refunds) stays in PL/SQL; this file
// only turns HTTP requests into procedure calls and commits or rolls back.
//
//   npm start            then open http://localhost:3000
//
// Connection settings come from the environment (defaults match docker-compose.yml):
//   DB_USER=ars  DB_PASSWORD=ars_pass  DB_CONNECT=localhost:1522/FREEPDB1  PORT=3000

const path = require('path');
const express = require('express');
const oracledb = require('oracledb');

const PORT = Number(process.env.PORT) || 3000;
const DB = {
  user: process.env.DB_USER || 'ars',
  password: process.env.DB_PASSWORD || 'ars_pass',
  connectString: process.env.DB_CONNECT || 'localhost:1522/FREEPDB1',
};

oracledb.outFormat = oracledb.OUT_FORMAT_OBJECT;

let pool;
async function db(fn) {
  const conn = await pool.getConnection();
  try {
    return await fn(conn);
  } finally {
    await conn.close();
  }
}

// Oracle DATEs are airport-local times with no time zone. The driver reads
// them as this machine's local time, so write them back out the same way,
// as plain 'YYYY-MM-DDTHH:MM:SS', and nothing gets shifted.
const p2 = n => String(n).padStart(2, '0');
const localStamp = d => `${d.getFullYear()}-${p2(d.getMonth() + 1)}-${p2(d.getDate())}` +
  `T${p2(d.getHours())}:${p2(d.getMinutes())}:${p2(d.getSeconds())}`;

// UPPER_SNAKE column names -> camelCase keys
const camel = row => Object.fromEntries(Object.entries(row).map(([k, v]) =>
  [k.toLowerCase().replace(/_([a-z])/g, (_, c) => c.toUpperCase()), v instanceof Date ? localStamp(v) : v]));

async function readCursor(rs) {
  const rows = await rs.getRows();
  await rs.close();
  return rows.map(camel);
}

// ORA-20xxx from the packages -> HTTP status + the package's own message
const STATUS = {
  20001: 404, 20003: 404, 20008: 404, 20011: 404, 20015: 404,
  20004: 409, 20009: 409, 20014: 409, 20102: 409, 20103: 409,
  20002: 400, 20012: 400, 20013: 400, 20016: 400, 20017: 400, 20018: 400, 20019: 400,
  20020: 404,
  20006: 422, 20010: 422, 20007: 402,
};
function sendError(res, err) {
  const code = Math.abs(err.errorNum || 0);
  if (STATUS[code]) {
    const msg = String(err.message).split('\n')[0].replace(/^ORA-\d+:\s*/, '');
    return res.status(STATUS[code]).json({ error: msg, code: -code });
  }
  console.error(err);
  res.status(500).json({ error: 'Something went wrong on our side. Try again.' });
}
const route = fn => (req, res) => fn(req, res).catch(err => sendError(res, err));

const app = express();
app.use(express.json());

// airports for the from / to pickers (coordinates let the page find the nearest one)
app.get('/api/airports', route(async (req, res) => {
  const rows = await db(c => c.execute(
    `SELECT iata_code AS code, airport_name AS name, city, country, latitude, longitude
       FROM airports ORDER BY city, iata_code`));
  res.json(rows.rows.map(camel));
}));

// flights for a route and day (generated on first search)
app.get('/api/search', route(async (req, res) => {
  const { from, to, date, cls = 'ECONOMY' } = req.query;
  const flights = await db(async c => {
    const r = await c.execute(
      `BEGIN flight_search_pkg.search_flights(:o, :d, TO_DATE(:dt, 'YYYY-MM-DD'), :cls, :rc); END;`,
      { o: from, d: to, dt: date, cls, rc: { dir: oracledb.BIND_OUT, type: oracledb.CURSOR } });
    return readCursor(r.outBinds.rc);
  });
  res.json(flights);
}));

// seat map of one flight
app.get('/api/flights/:id/seats', route(async (req, res) => {
  const seats = await db(async c => {
    const r = await c.execute(
      `BEGIN flight_search_pkg.seat_map(:id, :rc); END;`,
      { id: Number(req.params.id), rc: { dir: oracledb.BIND_OUT, type: oracledb.CURSOR } });
    return readCursor(r.outBinds.rc);
  });
  res.json(seats);
}));

// book: name, e-mail, phone, flight, class, optional seat, payment method
app.post('/api/bookings', route(async (req, res) => {
  const b = req.body || {};
  const out = await db(async c => {
    try {
      const r = await c.execute(
        `BEGIN flight_search_pkg.quick_book(:fn, :ln, :em, :ph, :fl, :cls, :seat, :pm, :bid, :sout, :amt); END;`,
        {
          fn: b.firstName, ln: b.lastName, em: b.email, ph: b.phone,
          fl: Number(b.flightId), cls: b.seatClass || 'ECONOMY', seat: b.seatNo || null,
          pm: b.method || 'CARD',
          bid: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
          sout: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 4 },
          amt: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
        });
      await c.commit();
      return r.outBinds;
    } catch (err) {
      await c.rollback();
      throw err;
    }
  });
  res.status(201).json({ bookingId: out.bid, seatNo: out.sout, amount: out.amt });
}));

// round trip: { firstName, lastName, email, phone, method, legs: [{ flightId, seatClass, seatNo? } x 2] }
app.post('/api/bookings/round-trip', route(async (req, res) => {
  const b = req.body || {};
  const [out = {}, ret = {}] = b.legs || [];
  const NUM = { dir: oracledb.BIND_OUT, type: oracledb.NUMBER };
  const SEAT = { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 4 };
  const r = await db(async c => {
    try {
      const x = await c.execute(
        `BEGIN flight_search_pkg.quick_book_round_trip(:fn, :ln, :em, :ph,
           :of, :oc, :os, :rf, :rc, :rs, :pm, :ob, :osn, :oa, :rb, :rsn, :ra); END;`,
        {
          fn: b.firstName, ln: b.lastName, em: b.email, ph: b.phone,
          of: Number(out.flightId), oc: out.seatClass || 'ECONOMY', os: out.seatNo || null,
          rf: Number(ret.flightId), rc: ret.seatClass || 'ECONOMY', rs: ret.seatNo || null,
          pm: b.method || 'CARD',
          ob: NUM, osn: SEAT, oa: NUM, rb: NUM, rsn: SEAT, ra: NUM,
        });
      await c.commit();
      return x.outBinds;
    } catch (err) {
      await c.rollback();
      throw err;
    }
  });
  res.status(201).json([
    { bookingId: r.ob, seatNo: r.osn, amount: r.oa },
    { bookingId: r.rb, seatNo: r.rsn, amount: r.ra },
  ]);
}));

// profile: every booking made with an e-mail, checked by phone (POST keeps them out of URLs)
app.post('/api/profile', route(async (req, res) => {
  const { email = '', phone = '' } = req.body || {};
  const rows = await db(async c => {
    const r = await c.execute(
      `BEGIN flight_search_pkg.my_bookings(:em, :ph, :rc); END;`,
      { em: email, ph: phone, rc: { dir: oracledb.BIND_OUT, type: oracledb.CURSOR } });
    return readCursor(r.outBinds.rc);
  });
  res.json(rows);
}));

// look a booking up by its number + e-mail
app.get('/api/bookings/:id', route(async (req, res) => {
  const rows = await db(async c => {
    const r = await c.execute(
      `BEGIN flight_search_pkg.find_booking(:id, :em, :rc); END;`,
      { id: Number(req.params.id), em: req.query.email || '',
        rc: { dir: oracledb.BIND_OUT, type: oracledb.CURSOR } });
    return readCursor(r.outBinds.rc);
  });
  res.json(rows[0]);
}));

// cancel, refund by the time left before departure
app.post('/api/bookings/:id/cancel', route(async (req, res) => {
  const refund = await db(async c => {
    try {
      const r = await c.execute(
        `BEGIN flight_search_pkg.cancel_my_booking(:id, :em, :refund); END;`,
        { id: Number(req.params.id), em: (req.body || {}).email || '',
          refund: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER } });
      await c.commit();
      return r.outBinds.refund;
    } catch (err) {
      await c.rollback();
      throw err;
    }
  });
  res.json({ refund });
}));

// next departures for the board
app.get('/api/departures', route(async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 14, 50);
  const rows = await db(c => c.execute(
    `SELECT flight_no, airline_name, origin, origin_city, destination, destination_city,
            departure_time, status
       FROM departures_board
      ORDER BY departure_time
      FETCH FIRST :n ROWS ONLY`, { n: limit }));
  res.json(rows.rows.map(camel));
}));

// lowest possible fare per destination, for the destination cards.
// Read-only (flight_search_pkg.fare_from): browsing never creates flights.
app.get('/api/fares/from/:origin', route(async (req, res) => {
  const to = String(req.query.to || '').split(',').filter(Boolean).slice(0, 12);
  const result = {};
  await db(async c => {
    for (const dest of to) {
      try {
        const r = await c.execute(`SELECT flight_search_pkg.fare_from(:o, :d) AS fare FROM dual`, { o: req.params.origin, d: dest });
        result[dest] = r.rows[0].FARE;
      } catch {
        result[dest] = null;
      }
    }
  });
  res.json({ fares: result });
}));

app.use('/api', (req, res) => res.status(404).json({ error: 'No such endpoint.' }));
app.use(express.static(path.join(__dirname, '..', 'web')));

(async () => {
  pool = await oracledb.createPool({ ...DB, poolMin: 1, poolMax: 8 });
  app.listen(PORT, () => console.log(`ARS running on http://localhost:${PORT}  (db ${DB.connectString})`));
})().catch(err => {
  console.error('Could not connect to the database:', err.message);
  console.error('Is it running?  docker compose up -d --wait');
  process.exit(1);
});

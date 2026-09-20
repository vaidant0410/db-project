#!/bin/bash
# Rebuilds the ARS schema (sql/00 .. sql/07) inside the FREEPDB1 pluggable database.
#
# The container runs this on every start (it is mounted into /container-entrypoint-startdb.d).
# Run it by hand to reset the data between demos:
#   docker compose exec oracle bash /container-entrypoint-startdb.d/10_rebuild_ars.sh
#
# A fresh rebuild keeps the flight dates in 02_data.sql relative to "now", which the demo needs.

APP_USER="${APP_USER:-ars}"
APP_PASS="${APP_USER_PASSWORD:-ars_pass}"
CONNECT="$APP_USER/$APP_PASS@//localhost:1521/FREEPDB1"
READY=/tmp/ars_ready
WORK=$(mktemp -d)

rm -f "$READY"

# Git on Windows may check the scripts out with CRLF line endings (core.autocrlf); work on LF copies.
cp /opt/ars-sql/0[0-7]_*.sql "$WORK"/
sed -i 's/\r$//' "$WORK"/*.sql

{
  echo "SET ECHO OFF FEEDBACK OFF VERIFY OFF DEFINE OFF SQLBLANKLINES ON LINESIZE 200 PAGESIZE 50 TRIMSPOOL ON"
  echo "SET SERVEROUTPUT ON SIZE UNLIMITED"
  echo "WHENEVER SQLERROR CONTINUE"
  echo "SPOOL /tmp/ars_build.log"
  for f in "$WORK"/0[0-7]_*.sql; do echo "@$f"; done
  echo "SPOOL OFF"
  echo "EXIT"
} > "$WORK/build.sql"

sqlplus -L -S "$CONNECT" @"$WORK/build.sql" > /tmp/ars_build.out 2>&1

ERRORS=$(grep -cE 'ORA-|SP2-|PLS-|compilation errors' /tmp/ars_build.log)
INVALID=$(sqlplus -L -S "$CONNECT" <<'SQL' | tr -d '[:space:]'
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
SELECT COUNT(*) FROM user_objects WHERE status <> 'VALID';
EXIT
SQL
)

if [ "$ERRORS" = "0" ] && [ "$INVALID" = "0" ]; then
  touch "$READY"
  echo "ARS schema ready (no errors, no invalid objects)."
else
  echo "ARS rebuild FAILED: $ERRORS error line(s), ${INVALID:-?} invalid object(s). See /tmp/ars_build.log in the container."
fi

rm -rf "$WORK"

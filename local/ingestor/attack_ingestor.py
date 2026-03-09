#!/usr/bin/env python3
import json
import os
import pathlib
import time

import psycopg2


LOG_PATH = pathlib.Path("/data/cowrie/log/cowrie/cowrie.json")
DB_CONFIG = {
    "host": "postgres",
    "dbname": os.environ["POSTGRES_DB"],
    "user": os.environ["POSTGRES_USER"],
    "password": os.environ["POSTGRES_PASSWORD"],
}


def connect():
    while True:
        try:
            conn = psycopg2.connect(**DB_CONFIG)
            conn.autocommit = False
            return conn
        except psycopg2.OperationalError:
            time.sleep(5)


def ensure_schema(cur, conn):
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS cowrie_events (
            id BIGSERIAL PRIMARY KEY,
            eventid TEXT NOT NULL,
            src_ip TEXT,
            username TEXT,
            password TEXT,
            payload JSONB NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
        """
    )
    conn.commit()


def wait_for_log():
    while not LOG_PATH.exists():
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        time.sleep(2)


def main():
    wait_for_log()
    conn = connect()
    cur = conn.cursor()
    ensure_schema(cur, conn)

    with LOG_PATH.open("r", encoding="utf-8") as logfile:
        logfile.seek(0, 2)
        while True:
            line = logfile.readline()
            if not line:
                time.sleep(1)
                continue

            try:
                payload = json.loads(line)
            except json.JSONDecodeError:
                continue

            cur.execute(
                """
                INSERT INTO cowrie_events (eventid, src_ip, username, password, payload)
                VALUES (%s, %s, %s, %s, %s::jsonb)
                """,
                (
                    payload.get("eventid", "unknown"),
                    payload.get("src_ip"),
                    payload.get("username"),
                    payload.get("password"),
                    json.dumps(payload),
                ),
            )
            conn.commit()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Recreate this project's Metabase state on a fresh instance, idempotently.

Reads the checked-in exports in ``metabase/exports/`` (dashboards 3-6 and
cards 28-43 of the live instance, exported 2026-09-13) and replays them
against ``MB_URL``:

  1. Creates the admin account (``MB_ADMIN_EMAIL`` / ``MB_ADMIN_PASSWORD``)
     via ``/api/setup`` if this instance was never set up, otherwise logs in.
     If the account exists but the password does not match, exits loudly --
     password recovery stays a manual step.
  2. Creates the two ClickHouse connections by name if missing:
     ``ClickHouse (marts, staging, intermediate)`` (dbname ``marts``) and
     ``ClickHouse (raw)`` (dbname ``raw``). One connection cannot span both
     ClickHouse databases -- the driver scopes a connection to one dbname.
  3. Recreates the 16 project cards matched by name, remapping the live
     ``source-table`` / ``field`` / ``database`` IDs to the recreated ones
     via (schema, table, column) name lookups -- never hard-coding IDs.
  4. Recreates the 4 dashboards matched by name, including the non-query
     dashcards verbatim (dashboard 5's "Association only" text card,
     dashboard 6's three link cards with URLs remapped to the recreated
     dashboard IDs).
  5. Points the ``custom-homepage-dashboard`` setting at the recreated Home
     dashboard.

Re-running against an already-configured instance is a no-op: everything is
matched by name (check-then-create), sample content is never touched.

Python stdlib only (repo rule: no new Python dependencies).
"""

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

MB_URL = os.environ.get("MB_URL", "http://metabase:3000").rstrip("/")
ADMIN_EMAIL = os.environ.get("MB_ADMIN_EMAIL", "analytics@analytics.local")
ADMIN_PASSWORD = os.environ.get("MB_ADMIN_PASSWORD", "analytics")
CH_HOST = os.environ.get("CLICKHOUSE_HOST", "clickhouse")
CH_PORT = int(os.environ.get("CLICKHOUSE_PORT", "8123"))
CH_USER = os.environ.get("CLICKHOUSE_USER", "analytics")
CH_PASSWORD = os.environ.get("CLICKHOUSE_PASSWORD", "analytics")

EXPORT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "exports")

MARTS_DB_NAME = "ClickHouse (marts, staging, intermediate)"
RAW_DB_NAME = "ClickHouse (raw)"

# Old dashboard IDs (live, 2026-09-13) in export-file order -> dashboard name,
# used to remap dashboard 6's link-card URLs to the recreated IDs.
EXPORT_DASHBOARDS = [
    ("dashboard_3.json", "Executive Overview"),
    ("dashboard_4.json", "Problem Analysis"),
    ("dashboard_5.json", "Root Cause & Drill-Down"),
    ("dashboard_6.json", "Home"),
]
HOME_DASHBOARD_NAME = "Home"


class APIError(Exception):
    pass


class AuthError(APIError):
    pass


def api(method, path, token=None, data=None, timeout=60):
    body = json.dumps(data).encode() if data is not None else None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["X-Metabase-Session"] = token
    req = urllib.request.Request(MB_URL + path, data=body,
                                 headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            payload = resp.read()
            if not payload:
                return None
            if resp.headers.get_content_type() == "application/json":
                return json.loads(payload)
            return payload
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")[:1000]
        raise APIError(f"{method} {path} -> HTTP {exc.code}: {detail}")


def wait_for_health(timeout_s=300):
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(MB_URL + "/api/health",
                                        timeout=10) as resp:
                if json.loads(resp.read()).get("status") == "ok":
                    print("Metabase is healthy", flush=True)
                    return
        except Exception:
            pass
        time.sleep(5)
    raise APIError("timed out waiting for Metabase /api/health")


def login_or_setup():
    """Return a session token.

    Try logging in first (works whether or not the instance was already set
    up). If the credentials are rejected, fall back to /api/setup for a fresh
    instance. If both fail, the password must be wrong on an existing
    account -- fail loudly instead of resetting anything.
    """
    try:
        session = api("POST", "/api/session",
                      data={"username": ADMIN_EMAIL,
                            "password": ADMIN_PASSWORD})
        print(f"Logged in as {ADMIN_EMAIL}", flush=True)
        return session["id"]
    except APIError as login_err:
        print(f"Login failed ({login_err}); trying first-time setup ...",
              flush=True)
    try:
        props = api("GET", "/api/session/properties")
    except APIError as exc:
        raise AuthError(
            f"Login as {ADMIN_EMAIL} failed and the instance properties "
            f"could not be read: {exc}. If the admin account exists with a "
            "different password, reset it manually (see issue #30); this "
            "script will not touch credentials.") from exc
    setup_token = props.get("setup-token")
    if not setup_token:
        raise AuthError(
            f"Login as {ADMIN_EMAIL} failed and this instance is already "
            f"set up (no setup-token). The password does not match -- "
            f"reset it manually (see issue #30); this script will not "
            f"touch credentials.")
    try:
        result = api("POST", "/api/setup", data={
            "token": setup_token,
            "user": {"first_name": "Analytics", "last_name": "Admin",
                     "email": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
            "prefs": {"site_name": "E-commerce Logistics Analytics",
                      "allow_tracking": False},
        })
        print(f"Created admin account {ADMIN_EMAIL}", flush=True)
        return result["id"]
    except APIError as exc:
        raise AuthError(
            f"Login as {ADMIN_EMAIL} failed and first-time setup failed: "
            f"{exc}. If the admin account exists with a different "
            f"password, reset it manually (see issue #30).") from exc


def ensure_database(token, name, dbname):
    dbs = api("GET", "/api/database", token=token)["data"]
    for db in dbs:
        if db["name"] == name and not db.get("archived", False):
            print(f"Database {name!r} already exists (id {db['id']})",
                  flush=True)
            return db["id"]
    db = api("POST", "/api/database", token=token, data={
        "name": name,
        "engine": "clickhouse",
        "details": {"host": CH_HOST, "port": CH_PORT, "dbname": dbname,
                    "user": CH_USER, "password": CH_PASSWORD,
                    "ssl": False},
    })
    print(f"Created database {name!r} (id {db['id']}, dbname {dbname})",
          flush=True)
    return db["id"]


def wait_for_sync(token, db_id, name, required_tables, timeout_s=600):
    """Wait until the DB sync exposes the tables cards query by name."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        meta = api("GET", f"/api/database/{db_id}/metadata", token=token,
                   timeout=120)
        names = {(t.get("schema"), t.get("name")) for t in meta["tables"]}
        if required_tables <= names:
            print(f"Database {name!r} sync complete "
                  f"({len(meta['tables'])} tables)", flush=True)
            return meta
        time.sleep(10)
    missing = required_tables - names
    raise APIError(f"timed out waiting for {name!r} sync; "
                   f"still missing tables: {sorted(missing)}")


def load_exports():
    old_tables = json.load(open(os.path.join(EXPORT_DIR, "tables.json")))
    dashboards = []
    for filename, name in EXPORT_DASHBOARDS:
        with open(os.path.join(EXPORT_DIR, filename)) as fh:
            dashboards.append(json.load(fh))
    cards = {}
    for entry in os.listdir(EXPORT_DIR):
        if entry.startswith("card_") and entry.endswith(".json"):
            with open(os.path.join(EXPORT_DIR, entry)) as fh:
                card = json.load(fh)
            cards[card["name"]] = card
    return old_tables, dashboards, cards


def build_id_maps(old_tables, new_meta):
    """Map old table/field IDs to new ones by (schema, table, column) name."""
    # Old: field id -> (schema, table, column); table id -> (schema, table).
    old_field_names = {}
    old_table_names = {}
    for table_id, table in old_tables.items():
        key = (table["schema"], table["name"])
        old_table_names[int(table_id)] = key
        for field_id, field_name in table["fields"].items():
            old_field_names[int(field_id)] = (key[0], key[1], field_name)
    # New: same lookups from live metadata.
    new_table_ids = {}
    new_field_ids = {}
    for table in new_meta["tables"]:
        key = (table.get("schema"), table.get("name"))
        new_table_ids[key] = table["id"]
        for field in table.get("fields", []):
            new_field_ids[(key[0], key[1], field["name"])] = field["id"]
    table_map = {}
    for old_id, key in old_table_names.items():
        if key not in new_table_ids:
            raise APIError(f"table {key} from exports not found after sync")
        table_map[old_id] = new_table_ids[key]
    field_map = {}
    for old_id, key in old_field_names.items():
        if key not in new_field_ids:
            raise APIError(f"column {key} from exports not found after sync")
        field_map[old_id] = new_field_ids[key]
    return table_map, field_map


def remap_query(node, db_map, table_map, field_map):
    """Recursively rewrite old database/table/field IDs in a dataset_query."""
    if isinstance(node, dict):
        out = {}
        for key, value in node.items():
            if key == "database" and isinstance(value, int):
                out[key] = db_map.get(value, value)
            elif key == "source-table" and isinstance(value, int):
                out[key] = table_map.get(value, value)
            else:
                out[key] = remap_query(value, db_map, table_map, field_map)
        return out
    if isinstance(node, list):
        if (len(node) >= 2 and node[0] == "field"
                and isinstance(node[1], int)):
            return (["field", field_map.get(node[1], node[1])]
                    + [remap_query(v, db_map, table_map, field_map)
                       for v in node[2:]])
        return [remap_query(v, db_map, table_map, field_map) for v in node]
    return node


def find_card_id(token, name):
    query = urllib.parse.urlencode({"q": name})
    results = api("GET", f"/api/search?{query}", token=token)
    for item in results.get("data", []):
        if (item.get("model") == "card" and item.get("name") == name
                and not item.get("archived", False)):
            return item["id"]
    return None


def ensure_card(token, export, db_map, table_map, field_map):
    name = export["name"]
    existing = find_card_id(token, name)
    if existing is not None:
        print(f"Card {name!r} already exists (id {existing})", flush=True)
        return existing
    card = api("POST", "/api/card", token=token, data={
        "name": name,
        "dataset_query": remap_query(export["dataset_query"], db_map,
                                     table_map, field_map),
        "display": export["display"],
        "description": export.get("description"),
        "visualization_settings": export.get("visualization_settings", {}),
    })
    print(f"Created card {name!r} (id {card['id']})", flush=True)
    return card["id"]


def link_target_name(viz):
    link = (viz or {}).get("link") or {}
    entity = link.get("entity") or {}
    if entity.get("model") == "dashboard":
        return entity.get("name")
    return None


def dashcard_identity(dashcard, dashboard_ids_by_name):
    """Hashable identity used to detect already-replayed dashcards."""
    viz = dashcard.get("visualization_settings") or {}
    if dashcard.get("card_id") is not None:
        return ("card", dashcard["card_id"])
    if "text" in viz:
        return ("text", viz.get("text"))
    target = link_target_name(viz)
    if target is not None:
        return ("link", dashboard_ids_by_name.get(target, target))
    return ("unknown", json.dumps(viz, sort_keys=True))


def remap_dashcard_viz(viz, dashboard_ids_by_name, old_dashboards_by_id):
    viz = json.loads(json.dumps(viz))  # deep copy
    target = link_target_name(viz)
    if target is None:
        return viz
    new_id = dashboard_ids_by_name.get(target)
    if new_id is None:
        raise APIError(f"link card target {target!r} was not recreated; "
                       f"known dashboards: {sorted(dashboard_ids_by_name)}")
    viz["link"]["entity"]["id"] = new_id
    viz["link"]["url"] = f"/dashboard/{new_id}"
    return viz


def ensure_dashboard(token, export, card_ids_by_name, dashboard_ids_by_name,
                     old_dashboards_by_id):
    name = export["name"]
    existing = None
    for dash in api("GET", "/api/dashboard", token=token):
        if dash["name"] == name and not dash.get("archived", False):
            existing = dash
            break
    if existing is None:
        created = api("POST", "/api/dashboard", token=token, data={
            "name": name, "description": export.get("description")})
        dashboard_id = created["id"]
        print(f"Created dashboard {name!r} (id {dashboard_id})", flush=True)
    else:
        dashboard_id = existing["id"]
        print(f"Dashboard {name!r} already exists (id {dashboard_id})",
              flush=True)
    dashboard_ids_by_name[name] = dashboard_id

    full = api("GET", f"/api/dashboard/{dashboard_id}", token=token)
    have = {dashcard_identity(dc, dashboard_ids_by_name)
            for dc in full.get("dashcards", [])}
    current = [
        {"id": dc["id"], "card_id": dc.get("card_id"), "row": dc["row"],
         "col": dc["col"], "size_x": dc["size_x"], "size_y": dc["size_y"],
         "series": dc.get("series", []),
         "visualization_settings": dc.get("visualization_settings", {}),
         "parameter_mappings": dc.get("parameter_mappings", [])}
        for dc in full.get("dashcards", [])
    ]

    temp_id = -1
    added = 0
    for dc in export.get("dashcards", []):
        viz = dc.get("visualization_settings") or {}
        if dc.get("card_id") is not None:
            card_name = (dc.get("card") or {}).get("name")
            new_card_id = card_ids_by_name.get(card_name)
            if new_card_id is None:
                raise APIError(
                    f"card {card_name!r} on dashboard {name!r} was not "
                    f"recreated")
            identity = ("card", new_card_id)
            entry_viz = viz
        else:
            entry_viz = remap_dashcard_viz(viz, dashboard_ids_by_name,
                                           old_dashboards_by_id)
            identity = dashcard_identity({"card_id": None,
                                          "visualization_settings": entry_viz},
                                         dashboard_ids_by_name)
            new_card_id = None
        if identity in have:
            continue
        current.append({"id": temp_id, "card_id": new_card_id,
                        "row": dc["row"], "col": dc["col"],
                        "size_x": dc["size_x"], "size_y": dc["size_y"],
                        "series": [], "visualization_settings": entry_viz,
                        "parameter_mappings": []})
        temp_id -= 1
        have.add(identity)
        added += 1
    if added:
        api("PUT", f"/api/dashboard/{dashboard_id}", token=token,
            data={"dashcards": current})
        print(f"Dashboard {name!r}: added {added} dashcard(s)", flush=True)
    else:
        print(f"Dashboard {name!r}: already complete "
              f"({len(current)} dashcards)", flush=True)
    return dashboard_id


def main():
    wait_for_health()
    token = login_or_setup()

    old_tables, dashboards, cards = load_exports()

    marts_id = ensure_database(token, MARTS_DB_NAME, "marts")
    raw_id = ensure_database(token, RAW_DB_NAME, "raw")
    db_map = {2: marts_id}

    required = {(t["schema"], t["name"]) for t in old_tables.values()}
    new_meta = wait_for_sync(token, marts_id, MARTS_DB_NAME, required)
    table_map, field_map = build_id_maps(old_tables, new_meta)

    card_ids_by_name = {}
    for card_name in sorted(cards):
        card_ids_by_name[card_name] = ensure_card(
            token, cards[card_name], db_map, table_map, field_map)

    old_dashboards_by_id = {d["id"]: d["name"] for d in dashboards}
    dashboard_ids_by_name = {}
    # Replay in export order so link targets on Home resolve: Home is last.
    for export in dashboards:
        ensure_dashboard(token, export, card_ids_by_name,
                         dashboard_ids_by_name, old_dashboards_by_id)

    home_id = dashboard_ids_by_name[HOME_DASHBOARD_NAME]
    api("PUT", "/api/setting/custom-homepage", token=token,
        data={"value": True})
    api("PUT", "/api/setting/custom-homepage-dashboard", token=token,
        data={"value": home_id})
    print(f"Landing page set to Home dashboard (id {home_id})", flush=True)
    print("Metabase setup complete: "
          f"{len(card_ids_by_name)} cards, "
          f"{len(dashboard_ids_by_name)} dashboards.", flush=True)


if __name__ == "__main__":
    try:
        main()
    except AuthError as exc:
        print(f"ERROR: {exc}", file=sys.stderr, flush=True)
        sys.exit(2)
    except APIError as exc:
        print(f"ERROR: {exc}", file=sys.stderr, flush=True)
        sys.exit(1)

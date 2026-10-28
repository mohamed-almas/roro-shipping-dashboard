"""
load_roro_to_supabase.py - load all Ro-Ro CSVs into the "Ro-Ro Shipping" Supabase project (pkjnbjympugwmuylfjxp),
then refresh the dashboard cache.

Usage (PowerShell):
  $env:SUPABASE_SERVICE_KEY = "<service_role key: Dashboard > Project Settings > API>"
  python load_roro_to_supabase.py            # load tables that are empty, skip the rest
  python load_roro_to_supabase.py --reload   # wipe each table first, then load (monthly refresh)

The key is read from the environment only; never printed or committed.
Column types come from the project's own OpenAPI schema; CSV columns not in the table are skipped with a warning.
"""
import csv, os, sys, requests

URL = 'https://pkjnbjympugwmuylfjxp.supabase.co'
KEY = os.environ.get('SUPABASE_SERVICE_KEY')
BASE = os.path.dirname(os.path.abspath(__file__))
BATCH = 1000
RELOAD = '--reload' in sys.argv
ONLY = [a for a in sys.argv[1:] if not a.startswith('--')]  # optional table names, e.g. roro_trades

# table -> csv path (reference tables first: the views join on them)
TABLES = [
    ('roro_ml_ports',     'References/roro_ml_ports.csv'),
    ('roro_ml_operators', 'References/ro-ro_ml_operators.csv'),
    ('roro_ml_owners',    'References/ro-ro_ml_owners.csv'),
    ('roro_ml_vessels',   'References/ro-ro_ml_vessels.csv'),
    ('roro_transits',     'Data/Ro-Ro Canal Transits.csv'),
    ('roro_trades',       'Data/Ro-Ro Trades.csv'),
]

if not KEY:
    sys.exit('ERROR: set SUPABASE_SERVICE_KEY first (Project Settings > API > service_role).')

H = {'apikey': KEY, 'Authorization': f'Bearer {KEY}', 'Content-Type': 'application/json', 'Prefer': 'return=minimal'}


def col_types():
    r = requests.get(f'{URL}/rest/v1/', headers=H)
    r.raise_for_status()
    return {t: {c: p.get('format', 'text') for c, p in d['properties'].items()}
            for t, d in r.json()['definitions'].items()}


def conv(v, fmt):
    if v is None or v == '':
        return None
    try:
        if fmt in ('bigint', 'integer', 'smallint'):
            return int(float(v))
        if fmt in ('double precision', 'numeric', 'real'):
            return float(v)
    except ValueError:
        return None
    return v


def count(table):
    r = requests.get(f'{URL}/rest/v1/{table}?select=*&limit=1', headers={**H, 'Prefer': 'count=exact'})
    r.raise_for_status()
    return int(r.headers['Content-Range'].split('/')[-1])


def wipe(table):
    # PostgREST DELETE needs a filter: remove non-null and null values of the first column = every row
    first = next(iter(types[table]))
    for flt in ('not.is.null', 'is.null'):
        requests.delete(f'{URL}/rest/v1/{table}?{first}={flt}', headers=H).raise_for_status()


def post(table, batch, n):
    r = requests.post(f'{URL}/rest/v1/{table}', headers=H, json=batch)
    if r.status_code >= 300:
        sys.exit(f'ERROR {table} at row {n}: {r.status_code} {r.text[:400]}')


def load(table, path):
    t = types[table]
    n = 0
    with open(os.path.join(BASE, path), newline='', encoding='utf-8-sig') as f:
        rd = csv.DictReader(f)
        skipped = [c for c in rd.fieldnames if c not in t]
        if skipped:
            print(f'  WARNING {table}: CSV columns not in table, skipped: {skipped}')
        if not any(c in t for c in rd.fieldnames):
            sys.exit(f'ERROR {table}: no CSV column matches the table')
        batch = []
        for row in rd:
            batch.append({c: conv(v, t[c]) for c, v in row.items() if c in t})
            if len(batch) >= BATCH:
                post(table, batch, n)
                n += len(batch)
                batch = []
                print(f'  {table}: {n}', end='\r')
        if batch:
            post(table, batch, n)
            n += len(batch)
    print(f'  {table}: {n} rows loaded      ')


types = col_types()
for table, path in TABLES:
    if ONLY and table not in ONLY:
        continue
    have = count(table)
    if have and not RELOAD:
        print(f'{table}: already has {have} rows, skipping (use --reload to replace)')
        continue
    if have:
        print(f'{table}: wiping {have} rows')
        wipe(table)
    print(f'{table}: loading {path}')
    load(table, path)

print('Refreshing dashboard cache...')
r = requests.post(f'{URL}/rest/v1/rpc/refresh_roro_dashboard_cache', headers=H, json={})
print('cache refreshed' if r.status_code < 300 else f'WARNING cache refresh failed: {r.status_code} {r.text[:300]}')

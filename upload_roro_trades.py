"""
upload_roro_trades.py — bulk reload of roro_trades table in the "Maritime Shipping" Supabase project.

Usage:
  1. Set SUPABASE_SERVICE_KEY env variable (Supabase Dashboard -> Project Settings -> API -> service_role secret,
     project ref jeuqpnhajmatekbzlfne):
       $env:SUPABASE_SERVICE_KEY = "eyJ..."   (PowerShell)
       export SUPABASE_SERVICE_KEY="eyJ..."   (bash)
  2. Run: python upload_roro_trades.py

The service key is read only from the environment, never printed, never committed to git.
This script TRUNCATES roro_trades (via RPC) then bulk-inserts the full CSV in batches through
Supabase's PostgREST API. RLS on the table is left untouched.
"""
import os
import sys
import csv
import requests

SUPABASE_URL = 'https://jeuqpnhajmatekbzlfne.supabase.co'
SERVICE_KEY = os.environ.get('SUPABASE_SERVICE_KEY')
CSV_PATH = r'C:\Users\mohamed.almas\OneDrive\Claude\Ro-Ro Shipping\Data\Ro-Ro Trades.csv'
BATCH_SIZE = 1000

if not SERVICE_KEY:
    print('ERROR: set SUPABASE_SERVICE_KEY environment variable first.')
    print('  Find it in Supabase -> Project Settings -> API -> service_role (secret)')
    raise SystemExit(1)

headers = {
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}',
    'Content-Type': 'application/json',
    'Prefer': 'return=minimal',
}

NUMERIC_COLS = {
    'imo', 'ceu',
    'origin_port_days_total', 'origin_port_days_berthed',
    'destination_port_days_total', 'destination_port_days_berthed',
    'days_steaming', 'days_total_duration', 'distance_actual',
}


def to_row(d):
    out = {}
    for k, v in d.items():
        if v is None or v == '':
            out[k] = None
        elif k in NUMERIC_COLS:
            try:
                out[k] = float(v) if '.' in v else int(v)
            except ValueError:
                out[k] = None
        else:
            out[k] = v
    return out


def main():
    # 1. Truncate existing (incomplete) data via RPC helper, falling back to DELETE.
    print('Truncating roro_trades...')
    r = requests.post(f'{SUPABASE_URL}/rest/v1/rpc/truncate_roro_trades', headers=headers, json={})
    if r.status_code == 404:
        # No RPC helper defined - do a DELETE ALL instead.
        r = requests.delete(f'{SUPABASE_URL}/rest/v1/roro_trades?imo=not.is.null', headers=headers)
        if r.status_code >= 300:
            # imo can be null, so also clear remaining null rows
            r2 = requests.delete(f'{SUPABASE_URL}/rest/v1/roro_trades?imo=is.null', headers=headers)
    print(f'Truncate status: {r.status_code}')

    total = 0
    batch = []
    with open(CSV_PATH, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            batch.append(to_row(row))
            if len(batch) >= BATCH_SIZE:
                resp = requests.post(f'{SUPABASE_URL}/rest/v1/roro_trades', headers=headers, json=batch)
                if resp.status_code >= 300:
                    print(f'ERROR at row {total}: {resp.status_code} {resp.text[:500]}')
                    sys.exit(1)
                total += len(batch)
                print(f'Inserted {total} rows...', end='\r')
                batch = []
        if batch:
            resp = requests.post(f'{SUPABASE_URL}/rest/v1/roro_trades', headers=headers, json=batch)
            if resp.status_code >= 300:
                print(f'ERROR at final batch (row {total}): {resp.status_code} {resp.text[:500]}')
                sys.exit(1)
            total += len(batch)

    print(f'\nDone. Inserted {total} rows.')

    print('Refreshing dashboard cache (mv_roro_trades_enriched, mv_roro_dashboard_data)...')
    resp = requests.post(f'{SUPABASE_URL}/rest/v1/rpc/refresh_roro_dashboard_cache', headers=headers, json={})
    if resp.status_code >= 300:
        print(f'WARNING: cache refresh failed ({resp.status_code}): {resp.text[:500]}')
        print('Run manually in Supabase SQL editor: select refresh_roro_dashboard_cache();')
    else:
        print('Dashboard cache refreshed.')


if __name__ == '__main__':
    main()

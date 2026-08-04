# Ro-Ro Shipping Dashboard

Live dashboard: https://mohamed-almas.github.io/roro-shipping-dashboard/

Global Ro-Ro (roll-on/roll-off) car-carrier shipping executive dashboard, covering
354,000+ voyage legs across Global, Regional, Coastal Region, Port Performance,
Voyage Explorer, Operator / Owner and Vessel views, with Annual / Quarterly / Monthly
grain toggling. Data is served live from Supabase via a single RPC call — no static
data file, no rebuild needed when the underlying data refreshes.

## Files

- `dashboard_views.sql` — Postgres view definitions (`v_global_summary`, `v_regional_summary`,
  `v_coastal_region_summary`, `v_port_performance`, `v_voyage_detail`, `v_operator_summary`,
  `v_owner_summary`, `v_vessel_summary`), applied to Supabase project `jeuqpnhajmatekbzlfne` (Maritime Shipping)
- `rpc_migration.sql` — the `get_roro_dashboard_data()` SQL function (SECURITY DEFINER) that aggregates
  all 8 views into a single JSON payload for the dashboard's one-shot fetch
- `dashboard_template.html` — dashboard UI/JS template (Chart.js), fetches `rpc/get_roro_dashboard_data`
  from Supabase on load
- `assemble.py` — copies `dashboard_template.html` -> `index.html`
- `index.html` — the deployed dashboard (this is what GitHub Pages serves)
- `upload_roro_trades.py` — reloads `Data/Ro-Ro Trades.csv` into the Supabase `roro_trades` table
- `Data/` — source CSV export(s)

## Refresh workflow (monthly)

1. Export the latest voyage data to `Data/Ro-Ro Trades.csv` (same columns as before).
2. Reload it into Supabase:
   ```
   python upload_roro_trades.py
   ```
3. The analytical views (`v_global_summary`, `v_regional_summary`, etc.) are plain views over
   `roro_trades`, so they recompute automatically — no migration needed for a routine data refresh.
4. No redeploy is required: the dashboard fetches live data from the `get_roro_dashboard_data` RPC
   on every page load, so the GitHub Pages `index.html` does not need to change.
5. If `dashboard_template.html` itself changes (new charts, new sections, styling), regenerate and push:
   ```
   python assemble.py
   git add dashboard_template.html index.html
   git commit -m "Update dashboard template"
   git push
   ```
6. GitHub Pages redeploys automatically within ~1 minute of the push.

## Notes on the data

- Date columns in `roro_trades` are stored as text (`DD/MM/YYYY HH:MI`); the base view
  `v_roro_trades_enriched` parses these and derives `event_year` / `event_quarter` / `event_month`
  from `destination_port_arrival` (voyage completion date) as the canonical event date.
- Only rows with a parsed arrival date are included in the aggregated views (a small number of
  in-progress/undated legs are excluded).
- The RPC payload caps row-level detail sensibly for browser delivery: top 25 ports (annual trend),
  top 100 ports (leaderboard), top 15 trade lanes (annual trend; 25 for the all-time bar chart), top 15
  coastal-region lanes (annual trend; 30 for leaderboard), 300 most recent completed voyages, top 50
  operators/owners, and top 150 vessels by voyage count — not all 354K raw rows.
- Market intelligence commentary on the Global tab is currently data-derived only (computed live from
  the aggregated numbers). See the `<!-- MARKET_COMMENTARY: refresh with external research -->` marker
  in `dashboard_template.html` — a follow-up task will layer in external market research there.

# Ro-Ro Shipping Dashboard

Live dashboard: https://mohamed-almas.github.io/roro-shipping-dashboard/

Global Ro-Ro (roll-on/roll-off) car-carrier shipping executive dashboard, covering
354,000+ voyage legs across Global, Regional, Coastal Region, Port Performance,
Voyage Explorer, Operator / Owner and Vessel views, with Annual / Quarterly / Monthly
grain toggling. Data is served live from Supabase via a single RPC call, backed by a
materialized-view cache (sub-millisecond reads) — no static data file bundled in the repo.

## Files

- `dashboard_views.sql` — Postgres view definitions (`v_global_summary`, `v_regional_summary`,
  `v_coastal_region_summary`, `v_port_performance`, `v_voyage_detail`, `v_operator_summary`,
  `v_owner_summary`, `v_vessel_summary`), applied to Supabase project `pkjnbjympugwmuylfjxp` (Ro-Ro Shipping)
- `rpc_migration.sql` — the original `get_roro_dashboard_data()` SQL function (SECURITY DEFINER) that
  aggregates all 8 views into a single JSON payload. Superseded by the caching layer below (kept for
  reference of the aggregation logic — now runs as `compute_roro_dashboard_data()`).
- **Caching layer** (applied directly via migration, not checked in as a separate file — see Supabase
  project migrations): `mv_roro_trades_enriched` (materialized, indexed base view) and
  `mv_roro_dashboard_data` (materialized single-row cache of the full JSON payload). `get_roro_dashboard_data()`
  now just reads the cached row (~1ms vs. ~38s computing live). `refresh_roro_dashboard_cache()` recomputes both.
- `dashboard_template.html` — dashboard UI/JS template (Chart.js), fetches `rpc/get_roro_dashboard_data`
  from Supabase on load
- `assemble.py` — copies `dashboard_template.html` -> `index.html`
- `index.html` — the deployed dashboard (this is what GitHub Pages serves)
- `load_roro_to_supabase.py` — loads the Esgian CSVs (trades, canal transits, port/operator/owner/vessel references) into the Supabase project (`--reload` to replace existing rows, or name a table to load just that one), then
  calls `refresh_roro_dashboard_cache()` so the dashboard picks up the new data immediately
- `market_intelligence_commentary.md` — sourced market commentary (fleet supply, rates, China export
  demand, Red Sea/Cape routing, European port congestion, EU ETS/FuelEU regulation), integrated into
  the dashboard's insight cards
- `Data/`, `References/` — proprietary Esgian source CSVs, kept local only (git-ignored, not pushed to
  this public repo). The dashboard never reads these directly at runtime — only `load_roro_to_supabase.py`
  does, to load them into Supabase.

## Refresh workflow (monthly)

1. Export the latest voyage data to `Data/Ro-Ro Trades.csv` (same columns as before).
2. Reload it into Supabase and refresh the dashboard cache in one step:
   ```
   python load_roro_to_supabase.py --reload
   ```
   If the cache refresh at the end times out through the API (it can with 400k+ rows), run this in the
   Supabase SQL editor instead:
   ```
   set statement_timeout='600s'; select refresh_roro_dashboard_cache();
   ```
   (this truncates + reloads `roro_trades`, then calls `refresh_roro_dashboard_cache()` automatically)
3. The analytical views recompute from the freshly reloaded data, and the materialized cache is rebuilt
   by the same script — no manual SQL needed for a routine data refresh.
4. No redeploy is required: the dashboard fetches live (cached) data from the `get_roro_dashboard_data`
   RPC on every page load, so the GitHub Pages `index.html` does not need to change.
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

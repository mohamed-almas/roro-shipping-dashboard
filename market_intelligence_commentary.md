# Ro-Ro / PCTC Market Intelligence — Commentary Bank
_Compiled August 2026 from Lloyd's List, Xinde Marine News, Veson Nautical, Mordor Intelligence, ECG (European Car Transport Group), Gasgoo, iMarine, MaritimeShips.com, breakbulk.news. For use in the dashboard's Market Intelligence section — combine with live Esgian/Supabase figures (voyages, CEU deployed, port days) to make each card data-grounded rather than generic._

## 1. Fleet supply — the delivery bulge is peaking, ordering is reawakening cautiously
- Global PCTC deliveries: 12 vessels (2023) → 46 (2024) → a record 75 (2025). 133 ships (~1m CEU) entered service 2023-2025.
- A further **67 PCTCs due in 2026**, 50 in 2027, 26 in 2028 — fleet capacity growth of **~9% in 2026**, expected to outpace cargo demand growth this year (Lloyd's List, Jan 2026).
- Newbuilding orders collapsed from 83 (2023) and 73 (2024) to just **9 in 2025** — a near-total pause — but rebounded to **37 ordered by mid-July 2026** (29 in H1 2026 alone per Lloyd's List), led by MSC's Global Car Carriers (12 ships), Eastern Pacific Shipping (6), and newcomer Zhongnan Shipping (4).
- **China dominates construction**: Chinese yards hold 35 of the 37 vessels ordered in 2026 (95%), and 219 of 276 PCTCs delivering 2023-2028 (~80% of the global total).
- Net fleet growth is projected to **decelerate sharply and turn negative in 2029-2030** as scrapping accelerates against thin ordering — a structural tightening after the 2024-2025 glut (net growth was 8% in 2024, 13% in 2025).
- **Dashboard tie-in**: pair this with `v_global_summary` active_vessels trend and `v_vessel_summary` fleet composition by sub_segment to show whether Esgian-tracked fleet activity mirrors the delivery bulge.

## 2. Rates — cooling from historic highs but still well above the 2010-2020 norm
- One-year timecharter rate for a 6,500 CEU PCTC: **~USD 55,000/day** in 2026 — nearly 3x the 2010-2020 average of USD 19,400/day (European Maritime Finance, May 2026).
- Charter rates and secondhand values have corrected from their 2024 peak as the newbuilding surge landed, but **remain above 10-year historical averages** (Lloyd's List).
- Base case for 2026: a "cooler but still functional" charter market — softer base rates than 2024 peaks, with a **widening spread between top-tier (efficient, dual-fuel, EU-compliant) and older/smaller tonnage** (MaritimeShips.com).
- **Dashboard tie-in**: use `v_vessel_summary` avg_voyage_duration_days and port-day metrics as an efficiency/utilization proxy alongside this rate narrative — vessels with tighter port turnaround and higher CEU density are the ones commanding the premium described here.

## 3. Demand — China's export machine is the dominant structural driver
- China shipped **over 7 million vehicles globally in 2025**, overtaking Japan as the world's largest vehicle exporter; full-year 2026 exports (all modes) are projected at **~10 million units**, with 4.06m already shipped Jan-May 2026 (+63% YoY, CAAM data via Veson Nautical).
- Chinese vehicle exports to Europe reached **940,000 units in 2025** (+~50% YoY); Q1 2026 China-to-Europe volumes hit a quarterly record of **2.23 million vehicles (+57% YoY)** (ECG).
- Vehicle Carrier (Ro-Ro) capacity **cannot absorb the full export volume** — an estimated **~2 million vehicles in 2026** are expected to move on container ships instead as an overflow valve, up from ~1 million in 2025 (Veson Nautical, Lloyd's List).
- Fastest-growing China export destinations Jan-May 2026: **Brazil (+235% YoY)**, with UK, Belgium, Italy each posting triple-digit growth; by brand, Chery led Europe exports (202,549 units, +277.5% YoY), followed by SAIC (+61.9%) and BYD (+8.8%).
- High & Heavy (construction/mining equipment) is emerging as a **second demand engine**: deep-sea shipments from Asia +31% YoY in Q1 2026 (China +39%), adding a resilient secondary cargo layer that broadens fleet utilization beyond passenger vehicles.
- **Dashboard tie-in**: `v_regional_summary` / `v_coastal_region_summary` origin=Far East/China destination breakdowns should be the single most important trend line on the Global and Regional views — frame CEU-deployed growth on China-origin lanes against these external benchmarks.

## 4. Routing — Red Sea avoidance and Suez/Cape dynamics are structurally embedded, not temporary
- Diversions around the Cape of Good Hope add **10-14 days** to Asia-Europe voyages versus the Suez routing — this is now treated as a **structural practice**, not a temporary one, more than two years into the Red Sea disruption (ECG, Lloyd's List).
- Notably, **China-controlled tonnage** is increasingly willing to transit Suez directly (14 large vehicle carriers transited in both June and July 2026) while European and Japanese operators continue routing via the Cape — a geopolitical/flag-driven bifurcation in routing strategy.
- Strait of Hormuz inaccessibility (since Feb 2026) pushed some Middle East-bound cargo to alternate ports — Duqm (Oman), and new calls emerging in Sri Lanka and East Africa.
- Panama Canal slot availability has **improved** from 2024 bottlenecks, easing delay premiums on Asia-Americas runs.
- **Dashboard tie-in**: `roro_transits` (canal transit data) plus `days_steaming`/`distance_actual` in `v_voyage_detail` can quantify how much of the fleet's realized transit time is Cape-routed vs canal-routed, and trend it — a genuinely proprietary cut vs. the qualitative press narrative above.

## 5. Port congestion and terminal saturation — Europe's gateways are the pinch point
- Bremerhaven yard occupancy hit **95%** in June 2026; Antwerp-Bruges vehicle dwell times reached **60 days** as China overtook Japan as the port's top source of vehicle imports.
- ECG (European Car Transport Group) leadership described 2026 as "the biggest changes in more than 30 years" for European automotive logistics — Chinese export volumes are "absorbing all ro-ro capacity and saturating terminals with unsold cars."
- New/expanding terminal capacity: Neptune Lines' new automotive terminal at Port-La Nouvelle (2026); Grimaldi's Grande Seoul opened a new Asia-Europe service via Antwerp, Portbury (Bristol), and Vigo.
- **Dashboard tie-in**: `v_port_performance` avg_port_days_total / avg_port_days_berthed for major European discharge ports (Antwerp, Bremerhaven, Zeebrugge, Vigo) is the direct, data-backed evidence for this congestion narrative — likely the single strongest "so what" chart for the Port Performance view.

## 6. Regulation — EU ETS and FuelEU Maritime are now live cost factors, not future risk
- EU ETS reaches **full scope in 2026**; FuelEU Maritime is in force with GHG-intensity targets — both now factor directly into voyage economics for EU-calling PCTCs.
- Newer, fuel-efficient, dual-fuel (LNG, ammonia-ready) tonnage is commanding a **premium**, while older/smaller vessels face compounding cost pressure (carbon cost + higher fuel-per-CEU) — accelerating the two-tier market described in the rates section above.
- **Dashboard tie-in**: `sub_segment`/vessel age (via `roro_ml_vessels`."Build Year") cross-cut with `v_vessel_summary` avg_voyage_duration_days and port-day efficiency could proxy which segment of the Esgian-tracked fleet is best positioned for the compliance-driven two-tier market.

## Suggested placement in dashboard
- **Global view**: items 1 (fleet supply) and 2 (rates) — frame the "state of the market" headline.
- **Regional / Coastal Region view**: item 3 (China demand, destination shifts) — the primary trend narrative.
- **Port Performance view**: item 5 (European terminal congestion) — directly testable against live port-day data.
- **Voyage view**: item 4 (Red Sea/Cape routing) — testable against `roro_transits` + `distance_actual`/`days_steaming`.
- **Operator/Owner and Vessel views**: item 6 (regulation-driven fleet segmentation) and item 1 (newbuilding/ordering by owner group — Global Car Carriers/MSC, EPS, Zhongnan) — ties external ownership-consolidation news to the operator/owner league tables.

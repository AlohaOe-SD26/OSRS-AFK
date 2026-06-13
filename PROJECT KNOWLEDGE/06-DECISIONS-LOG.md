# Decisions Log â€” osrs_afk
> APPEND-ONLY. New entries at the end. Never rewrite history â€” if a decision
> is reversed, append a NEW entry that supersedes the old one and says so.

---

## 2026-06-11 â€” Adopted the Claude Code Project Kit
- **Decision:** Standardize on the kit's CLAUDE.md directives + PROJECT
  KNOWLEDGE structure + per-item commit/push definition of done.
- **Context:** Make every session resumable by any agent with zero context.
- **Alternatives rejected:** Ad-hoc per-chat context pasting (doesn't scale,
  loses history).

## 2026-06-11 — Backfill: standing decisions inherited from the pre-Kit era
(One-time summary so this log is complete from here on; full provenance in
`ANALYSIS REPORT/STATUS_DOCS/AGENT_MEMORY_project-status.md`.)
- **Economy attractor locked** (Step 1): wealth-proportional upkeep + town
  consumption + saturation pricing + sale tax — validated to bounded
  equilibrium; never re-derived, only integrated around.
- **Back-pressure doctrine:** every dynamic ships with its counter-force
  (generalized from 7 banked bug-class instances).
- **Measurement discipline:** emergent claims need 8–16-seed sweeps;
  default-off flags for behavior changes until gate-validated.
- **Merge plan (2026-06-09):** adopt the 2nd concept prototype's look/brain/
  content ON the validated Godot foundation; order M1→M2→M3. BRAIN_V2 kept
  default-off after 3 measured tests (needs activity breadth).
- **Funded per-unit bounty = intended Tier-1 design** (utility bounty
  clamped at +24 as interim; sweep showed ≥~36 craters the market).
- **Standing harness rules:** preload() not class_name in tools; quit() ends
  every harness; foreground gates with timeout.

## 2026-06-11 — Economy/incentives feature set: discuss-first, no code
- **Decision:** Respond to the external design partner's prompt
  (`readthis.md`) with a read-only probe + written report
  (`ANALYSIS REPORT/ANALYSIS_REPORT.md`); defer ALL B/C feature work until
  design rulings return. Sequencing proposal recorded in the report and
  mirrored as punch-list #1–#6/#10–#11 placeholders.
- **Context:** Hard rules in the prompt (read-only probe; side panels kept;
  punch list preserved; report travels to a designer without code access).
- **Alternatives rejected:** starting implementation alongside the report
  (violates the prompt's discussion-first contract).

## 2026-06-11 — Design rulings R1–R12 adopted (DESIGN_RULINGS.md)
- **Decision:** All twelve ANALYSIS_REPORT questions ruled by the design
  partner; rulings preserved at `ANALYSIS REPORT/DESIGN_RULINGS.md` and
  folded into the punch list. Headlines: treasury re-injection accepted with
  **escrow-at-posting** for city buy orders (no flow cap); purchase→treasury
  routing 40% (tune 30–50%); NPC demand floor KEPT (autonomy is the
  product); shop roster greenlit (Horvik/Lowe/Zaff/Aubury/Swordshop —
  combat-triangle supply-gating rationale); **Vannaka** (designed cast, not
  parity) at west gate with documented divergence; **one funded incentive
  doctrine** — bounty payout drives attraction through the greed-weighted
  reward term, clamped utility FIGHT bounty retires same unit; on-task
  bonus +20 open, mine to lock within gates, sweep instrumented for the §18
  monoculture prediction; loot_policy = drop-filter; shop 3% tax locked,
  GE 1% treasury-routed at open, city orders untaxed, tax on hero-side
  proceeds uniformly; bank ships WITH the GE (refund deposit target);
  save-migration scaffold pulled to Unit 0 (gate = migrated save loads +
  continues deterministically); C1 popups = Control nodes (new popups only,
  shared visual constants, render-layer, paradigm-split rule to be logged);
  day-denominated specs = sim-days. Sequencing Units 0–5 endorsed as-is.
- **Alternatives rejected (by ruling):** hard treasury outflow cap (escrow
  is structural and simpler); invented Slayer-master stand-in (lore
  invariant); separate flat utility knob for bounty attraction (one lever,
  two effects); taxing city orders (ledger noise); bank deferral (reference
  build's expiry-refund deadlock lesson).

## 2026-06-11 — Process: initial commit + push (priority #0)
- **Decision:** Committed the entire pre-rulings green state as the initial
  commit (`5fd5d97`) and pushed to origin/main; added Godot-cache and
  archive ignores first so `.godot/` never enters history. Per-item commit
  discipline (Project Kit DoD) applies from here on.

## 2026-06-12 — Live-aggro survival: canon mechanics over knob-tuning (punch-list #1d)
- **Decision:** The aggressive-monster death-loop (workers chipped faster
  than they could ever recover) is solved with three CANON OSRS mechanics —
  passive regen (1 HP/min), aggression tolerance (monsters ignore heroes
  settled >8s into a trip; harassment = arrival tax), and lair-bound bosses
  (strike trespassers only) — plus one brain term (danger = −threat ×
  frailty on gather candidates at aggro-shared camps). Deaths fell
  2,096 → 4 per 24k ticks; reputation recovered 0 → 61; goblin culling
  and the Scurrius fight both became functional for the first time.
- **Why this shape:** the bug-class rule (every force needs a counter-force)
  said the fix belongs at the SOURCE (exposure time) and in the BRAIN
  (priced risk), not in the damage numbers. Tolerance also fixed a second-
  order failure for free: perma-chasing goblins never stood still, so
  fighters stopped culling them (kills 96 → 3,730 once they wander again).
- **Alternatives rejected:** scaling the danger term alone (measured
  insufficient — favorite bias +14 outbids any sane penalty at full HP, and
  at low HP the worker is already in the loop); softening REP_PER_DEATH
  (treats the symptom, keeps the meat grinder); nerfing aggro damage
  (makes aggression cosmetic); per-pair tolerance state (canon-truer but
  save-shape-heavy; per-hero trip clock captures the same behavior).
- **Note:** per-capita gold drifted above the validated 1,065–1,211 band
  (~1,485 at day 23 — fewer deaths/flees = more productive hours). Formal
  re-baseline belongs to the #1e instrumented sweep, not a knob reaction.

## 2026-06-12 — #1e verdicts: on-task locked +20; §18 split; BRAIN_V2 stays OFF; band re-baselined
- **SLAYER_ON_TASK locked at +20** (R6 — "the number is yours"). Sweep
  (`tools/diag_unit0.gd`, 8 seeds × arms 0/10/20/35, 23d): engagement
  saturates at +20 (tasks 14→59→68→68; on-task fighters 1→9→10→11%;
  deaths/run 7.1→5.9→5.0→5.0). +35 buys nothing over +20; +0 collapses
  the Slayer loop. Alternatives rejected: +10 (half the engagement for
  the same monoculture level), +35 (no measurable return, stronger
  standing attractor on principle).
- **The banked §18 prediction held HALF-way** (R6 instrumentation):
  - Rival-lean half HELD: the social web flipped friend-leaning
    (Friend ≈ 3.5% vs Rival ≈ 0.7% of ordered pairs; KI-5-era lean was
    Rival > Friend on stored edges — sign flip is denominator-invariant).
    KI-5 RESOLVED and removed.
  - Combat-share half FAILED: monoculture 39–44% across ALL arms — above
    the bug-era 32%. Cause: the old ~8–20% "mitigation" was lethality;
    the #1d survival triad removed that counterweight and the
    price-independent combat base reasserted itself. Slayer tasks
    ORGANIZE combat (feasible targets, fewer deaths); they do not shrink
    it. KI-4 re-confirmed structural, fix path revised (combat-side
    reward saturation / price coupling, natural home = Unit-1+ pricing).
- **BRAIN_V2 default stays OFF** (4th test, `tools/diag_stage2.gd`, 8
  seeds, v1 vs v2 on the Unit-0 surface): v2 WORSENS monoculture
  (52±3 vs 44±5). Mechanism: saturating bases drain a gatherer's trained
  favorite while untrained strength remains a maximal-need refuge —
  breadth was never the missing precondition; a combat-side counter-force
  is. Keep v2's measured win in mind (per-capita gold variance ±332→±84)
  and salvage it once the combat base is price-coupled.
- **Per-capita gold band re-baselined: 1,460 ± 332** (day-23, 8 seeds,
  on-task +20; old band 1,065–1,211 was pre-survival-triad — fewer
  deaths/flees = more productive hours; variance widened because rare
  deaths now swing trajectories instead of truncating them).

## 2026-06-12 — Unit-1 catalog-migration decisions
- **Canon catalog ids win everywhere** (one v2→v3 save migration) over a
  permanent sim-id↔catalog-id mapping table. Why: the vision is canon OSRS;
  a translation layer is standing tech debt that every future pricing/GE/
  city-order feature would pay. Alternative rejected: renaming catalog ids
  to match the sim (betrays "canon stats come from the dataset" and the
  osrsreboxed ingest path).
- **Gear trades through the existing saturation curve** with the arm opened
  at fill 0.5, making the open price ≈ the old flat half-value mint by
  construction (f = 1.2 − 0.5×1.4 = 0.5) — continuity without a re-tune;
  small town gear demand (0.25/day/item, pop-scaled) bounds the arm.
  Alternative rejected: a special gear price formula (two pricing systems
  to keep coherent for no gain).
- **Upgrader values are frozen inline** (_V3_GEAR_BOARD), not read from the
  live catalog: an upgrader transforms data and must replay identically
  forever, even after future catalog edits.
- **Tradeable=false for tools/ammo** preserves the old behavior (they were
  never vendorable); starter gear became tradeable=true (it now vendors
  via the board if unequipped — minor, sensible delta).
- **New-entry base values seed from the feel-tuned GEAR_DROPS numbers**
  (iron_sword 60 etc.) rather than canon GE prices — those arrive with the
  real osrsreboxed ingest; existing catalog entries kept their values
  (leather_body 21 supersedes the table''s 24; iron_ore 17 supersedes 16,
  resolving KI-8 in the catalog''s favor).
- **KI-4 design hook noted for Unit 2:** with prices now catalog-driven,
  the combat-side counter-force (reward saturation / price coupling on the
  combat base) belongs in the shop-economy-v2 unit while pricing files are
  open — recorded on punch #3.

## 2026-06-12 — Unit-2 #3a/#3b decisions
- **Roster-as-data (`data/shops.json`)** over code-built shops: Unit 4+
  (GE/city orders) keeps editing shop defs; data is the natural home and
  matches the catalog-as-truth direction. Charge anchors live in shops.json
  (they are SHOP pricing policy), base values stay in items.json (item
  truth) — two files, two concerns, no duplication.
- **Charge-price normalization**: dynamic buy prices anchored so baseline
  fill reproduces the validated flat costs exactly (12/30/35/12). Why:
  continuity with the proven attractor at equilibrium while letting real
  scarcity move prices. Alternative rejected: re-tuning costs from scratch
  (needless re-validation of the whole sink stack).
- **Ammo supply sizing is throughput-driven, not flavor-driven**: first cut
  (baseline 8 bundles) caused a measured supply cliff (kills −25%, g/cap
  −24% — dry-punch fallback dominating). Demand math: ~700–950 kills/day
  at pop 40, ~1/3 each style, ~4–6 attacks/kill ≈ 23 bundles/day/type;
  baseline 60 gives max import inflow 30/day + a 60-bundle buffer.
  Scarcity pricing still spikes during bursts — supply-gating without
  style starvation (the R3 lesson, learned twice now).
- **Offline-gate criterion v2** (instrument fix, not goalpost move): the
  endpoint-only re-convergence Δ compared two RNG-decoupled runs; once the
  batch is absorbed their gap is run noise (measured: Δ5% mid-window →
  Δ29% endpoint on beef01). v2 = closest-tail re-entry ≤ 25% + endpoint
  runaway guard ≤ 50%. The two-sided intent (absorbed + no permanent
  shift) is preserved.
- **Food purchases route too**: R1''s "purchase routing" reads naturally as
  ALL hero shop spend; food is the dominant flow and the treasury pulse is
  the point. Hero-side sink unchanged (they pay the same price).
- **unlockLevel gates buying only**: a level-gated vendor side would
  re-break Unit-1 drop vendoring (unsellable carried tier-2 gear).
- **Shop leveling does NOT scale import baselines yet** (leveling buys
  breadth via unlocks, not import depth) — revisit with C5 crafting queues.

## 2026-06-12 — LOCKED INVARIANT: the coinpurse (per-hero gold, never pooled)
- **Every hero keeps a personal coinpurse — hero gold is NEVER pooled or
  shared.** Already true in the build (Hero.gold is the only hero gold
  store; transfers exist only as explicit one-off events, e.g. the §14
  gravestone-loot grab); recorded now as a standing invariant per the
  2026-06-12 directive so future systems (GE order matching, city buy
  orders, banking, party/social features) are designed AGAINST it: the
  bank (Unit 4) holds per-hero deposits, not a pool; the treasury is the
  TOWN''s purse (fed only by gold already removed from hero circulation),
  never a hero gold pool. Any future feature that would pool hero gold
  needs an explicit ruling to override this.

## 2026-06-12 — Directive batch: random character generation (#13–#15) + Legendary arrivals (#16)
- Recorded as punch items with full specs (see 03-PUNCH-LIST). Shape:
  founders fully rolled (name/appearance/skills/favorites/gold 20–100
  opening stance/placement; seeded RNG, debug lock path, viability
  constraint, rolled fighter styles); immigrant gold becomes rolled
  economy-fitted bands anchored to the attractor (replacing fixed
  20/45/130/320); immigrant gear rolls quality-scaled by stats; Legendary
  (GE-unlocked-this-run gate) + rarer Easter-Egg arrivals (extra unlock,
  TBD) as a design reservation so immigration/templates/achievements stay
  compatible. Engineering constraints attached: wealth changes → band
  re-sweep + re-baseline; gates stay green; SAVE_VERSION + upgrader on
  save-shape changes.

## 2026-06-13 — #3c price-bias clamp LOCKED at ±30% (sweep evidence)
- **PRICE_BIAS_MIN/MAX locked 0.70 / 1.30** (the opening stance, now
  evidence-backed). `tools/diag_bias.gd`: 6 seeds × 16 days, one bias on
  logs from day 3, organic treasury (tax + routing only). Arms vs control
  (WC share / g/cap / treasury end / premium drain):
    - control: 13.1%±2.6 / 1229±390 / 44570±5961 / 0
    - overpay 130%: 14.0%±2.3 / 1451±433 / 16724±12893 / 27634±20879
    - overpay 150%: 14.7%±4.1 / 1417±448 / 9560±9888 / 36911±17739
    - underpay 70%: 13.5%±3.0 / 1293±393 / 44798±7732 / 0
- **The binding axis is treasury FUNDING, not the steering pull.** The pull
  is real but modest+monotonic (overpay 13.1→14.0→14.7%; woodcutting is a
  minor activity); g* stays bounded in every arm (1229–1451, all within
  ~1σ — no inflation/starvation). What decides the ceiling is criterion
  (c): at 130% the treasury ends positive even at −1σ (~3.8k); at 150% it
  ends 9.6k ± 9.9k (crosses 0 within 1σ) with a 37k drain ≈ the entire
  organic inflow — the premium is NOT sustainably funded. So 130% is the
  widest funded overpay.
- **Underpay floor 0.70 is structurally safe** (underpay has zero treasury
  flow by design — it only shrinks the faucet), so the floor is bounded by
  the ruled "narrower than 50–150%" expectation, not by a funding cliff.
- REJECTED 1.50 ceiling: bigger nominal pull (14.7%) but noisier (σ 4.1 vs
  2.3) and treasury-unfunded at the tail — re-injection must stay bounded
  by real inflow (the R1 bounty rule), so an unfunded premium is out.

## 2026-06-13 — #3d KI-4 closing sweep: NEGATIVE RESULT — no shippable combat-side mitigation; congestion HELD at 0.5; Unit 2 closed
- **The experiment.** KI-4 (combat is the standing monoculture refuge) was ruled
  to need a combat-side counter-force: reward saturation / price coupling, since
  combat's appeal is price-INDEPENDENT (flat base + coin drops) while gather's
  `price*0.25` reward saturates. `diag_unit2_close.gd` swept the two combat levers
  TOGETHER (8 seeds × 23 days, integrated non-fav monoculture): COMBAT_CONGESTION_
  MULT {0.5/0.75/1.0} × a new gear-board price-coupled reward term COMBAT_GEAR_
  REWARD {off/on}. Arms (mono / kills / g-cap / board-end):
    - 0.50/off (control): 28%±5 / 21039 / 1501±235 / 17
    - 0.50/ON:            35%±6 / 24233 / 1608±76  / 11
    - 0.75/off:           27%±4 / 21553 / 1082±470 / 14
    - 0.75/ON:            31%±5 / 23347 / 1436±251 / 12
    - 1.00/off:           23%±4 / 21768 / 1435±355 / 14
    - 1.00/ON:            29%±5 / 23241 / 1435±370 / 16
- **DECISION: hold COMBAT_CONGESTION_MULT at 0.5 (NO change); gear-coupling stays
  OFF. #3d ships ZERO behavior change — both candidate counter-forces failed.**
- **Process correction (recorded honestly):** I first locked 1.0 on the sweep
  metrics alone, THEN ran the release gates and caught that 1.0 FAILS the offline
  re-convergence gate — so I reverted. The lesson: the closing-sweep criterion must
  include the offline/save-load gates, not just monoculture/kills/g-cap. (The
  two-sided criterion in diag_unit2_close.gd's header omitted them.)
- **Why 1.0 is NOT shippable:** it genuinely drops monoculture (28→23%, monotonic
  across 0.5/0.75/1.0) without cratering kills (flat ~21k — rat-camp throughput is
  respawn/travel-bound, not headcount-sensitive) — the *intended* effect works. BUT
  1.0's higher run-to-run variance (g/cap SD ±355 vs ±235 at 0.5) breaks the offline
  GATE: seed beef01 goes from closest-tail Δ0–2% at 0.5 to Δ31% at 1.0 (criterion
  ≤25%) — the offline-return arm no longer demonstrably re-converges to the control
  within the window. The offline batch itself stays bounded/absorbed/capped on every
  seed; it's the decoupled post-reconnect trajectories that diverge under the higher
  variance. A release gate that has been green project-wide must not be weakened to
  ship a tuning change, so 1.0 is out.
- **Why NOT 0.75:** it buys essentially no monoculture gain (27% vs 28%) while
  destabilizing g/cap (1082±470 — depressed mean, ~2× the variance); strictly worse
  than 0.5. An intermediate 0.5–0.75 value was NOT chased: the monoculture gain there
  would be <1pt and barely-pass-the-gate knob-fiddling is exactly the discipline trap.
- **REJECTED — the gear-drop reward coupling (FALSIFIED for KI-4):** turning it ON
  WORSENS monoculture at every congestion level (+4..+7 pts) and raises kills. It is
  a POSITIVE ~7-pt reward term, and the board only floors at ~11–17 (town demand +
  the 4% drop rate keep gear off the board floor), so the added combat appeal
  dominates the weak downward saturation — it acts as a combat ATTRACTANT, not a
  counter-force. RETAINED default-OFF (cf. BRAIN_V2) for possible future salvage:
  reformulate as a saturation PENALTY rather than a positive reward, or couple far
  harder so the board actually crashes. The mechanism + price-coupling are unit-
  tested (gated by the flag), so a future reformulation has a foundation.
- **KI-4 stays OPEN (structural, documented), NOT mitigated this unit.** Net of #3d:
  the gear coupling is falsified, congestion-1.0 is gate-blocked, 0.75 is band-
  destabilizing → the available combat-side levers can't reduce monoculture without
  violating a release gate or the band. Next attempts (recorded in KI-4): gear
  coupling as a penalty; or revisit once a variance-robust offline gate / the
  BRAIN_V2 base-shape fix lands.
- **Unit-2 CLOSING BAND re-baselined at the SHIPPING config (0.5/off): per-capita
  gold 1,501 ± 235** (8 seeds, the control arm). Supersedes the Unit-0 band of record
  1,460±332; the new mean sits inside the old band with tighter variance — a clean
  re-baseline, not a regression.
- **Unit 2 (punch #3) CLOSED** — #3a supply / #3b ledger / #3c price-bias / #3d this
  (negative result; no behavior change). Code delivered by #3d: the gear-coupling
  lever (default-OFF, unit-tested) + the `diag_unit2_close.gd` sweep tool.

## 2026-06-13 — #4c: UI paradigm split — Control nodes for complex-input forms (R11)
- **Decision:** the parameterized nudge popup (`render/NudgePopup.gd`) is the project's
  FIRST Godot Control-node UI. From here the UI is a DELIBERATE two-paradigm split:
  - **Complex-input FORMS** (dropdowns, range spinners, multi-field popups) → Godot
    **Control nodes** (OptionButton/SpinBox/Button in containers), on a dedicated
    `CanvasLayer` above the HUD.
  - **HUD / status / panels / overlays** (topbar, roster, TOWN LEDGER, hero popup,
    the nudge command row) → stay **immediate-mode** `Main._draw` + `_ui_rects`
    hit-testing, untouched.
- **Why (R11 lean (b), approved):** the hand-rolled immediate-mode toolkit has
  buttons + one slider; it has no dropdowns/spinners/forms, and hand-rolling them is
  bespoke and error-prone. Control nodes are the engine's intended path for forms and
  cut bespoke code. C1 is the experiment; if Control nodes prove better, future
  complex UI follows the same rule.
- **R11 conditions honored:** (1) existing immediate-mode panels untouched; (2) the
  popup MIRRORS Main's HUD palette (the `C_*` consts in NudgePopup = Main's hexes) so
  the mixed paradigm reads as one game; (3) render-layer only — the popup reads the
  sim read-only (`nudge_feasible`) and emits an intent that Main dispatches through
  `nudge_hero(...)`, exactly like `_dispatch_ui`; it never mutates the sim; (4) this
  entry records the split + the which-side rule above.
- **Scope note (honest):** the popup exposes the params #4a actually WIRED into the
  FSM — activity + trip-length range (count_range → count_target) + loot policy
  (fights). Per-MONSTER/camp target routing is DEFERRED: #4a carries `mon` but the FSM
  does not route on it, and there is effectively one combat camp today; the target
  dropdown returns when zones expand and the FSM routes to a chosen camp.
- **Verification boundary:** Control-node rendering cannot be confirmed headless
  (no gate covers pixels). Parse is checked via `--import`; the look/behaviour needs
  an F5 pass. This is the standing limit for all Control-node UI going forward.
- **Alternatives rejected:** extend the immediate-mode toolkit with hand-rolled
  dropdowns/spinners (more bespoke code, the thing R11 avoids); a separate .tscn scene
  (the popup is small and code-built — no inspector wiring needed, keeps it in one file).

## 2026-06-13 — #13 rolled founders: viability constraint, debug lock, band re-baseline
- **Founders are now fully ROLLED on the seeded RNG** (directive 2026-06-12): per-
  founder random favorite, weapon style (fighters), starting gold (band 20–100),
  name, appearance (skin/hair/shirt), and spawn tile inside the city walls. Same
  seed ⇒ same founders (determinism gate holds). Immigrants already rolled their
  favorite; their weapon/gear rolls are #14/#15.
- **Viability constraint (the one structural floor): ≥1 FISHER among the founders.**
  Favorites roll freely from {mining, woodcutting, fishing, fighting}; if the roll
  produces zero fishers, one slot is forced to fishing. Rationale: fishing→cooking is
  the colony's ONLY food source, and a foodless colony structurally collapses
  (fighters starve). Other roles are left free — the brain's demand-responsive labor
  covers transient ore/log shortfalls. REJECTED stronger constraints (e.g. ≥1 of each
  gather, or a fixed min fighter count): the 8-seed sweep proved ≥1-fisher alone keeps
  every colony ALIVE (pop 40–43), so more constraint would just reduce the variety the
  directive wants.
- **Debug lock (constraint b): `Config.FOUNDERS_LOCKED`** (static var, default OFF =
  rolled). ON restores the original fixed template (1 mine/1 chop/2 fish/2 fight,
  id-indexed look, 20g) with NO extra RNG draws — byte-identical to the pre-#13 sim.
  The TEST SUITE pins it ON so role-dependent checks (heroes[0] mines, etc.) stay
  stable; the rolled path has its own dedicated test. Live game + gates run OFF.
- **No SAVE_VERSION bump:** rolled founders are different VALUES in already-serialized
  hero fields (name/look/favorite/gold/weapon/pos) — no schema change.
- **RE-BASELINE (diag_founders.gd, 8 seeds × 23 days, rolled): per-capita gold
  1,482 ± 448** — supersedes 1,501 ± 235. The MEAN is preserved (the upkeep attractor
  pins g/cap regardless of the rolled starting gold, exactly as predicted); the
  VARIANCE widened (±235 → ±448) because random favorite-spreads vary the economy's
  composition run-to-run. Viability VALIDATED: min founder-fishers = 1 across all
  seeds, all colonies alive. WATCH: deaths/run 11.4 ± 16.1 — seed 7a11 is an outlier
  (50 deaths, a combat-heavy roll with 1 fisher; colony still pop 40, g/cap high) —
  narratable, not an economic break; two seeds run low g/cap (~880, alive, slow-wealth).
- **#14/#15 (immigrant gold/gear) anchor on the FRESH band 1,482 ± 448** and retire
  the immigrant `id % 3` weapon per #13(d) (the new `_new_hero` weapon param is the
  hook — pass a rolled style instead of "").
## 2026-06-13 — #14 immigrant gold in economy-fitted bands + rolled weapon style
- **Immigrant starting gold is now a ROLLED tier band, sized as a FRACTION of the
  attractor**, not a preset number (directive 2026-06-12). `NEWCOMER_TIERS` gains a
  `gold_frac` [lo,hi] per tier; `spawn_immigrant` rolls gold = round(GOLD_ATTRACTOR_REF
  × randf(lo,hi)) on the seeded RNG. Bands: Greenhorn 1–3% (≈15–44g), Seasoned 3–7%
  (≈44–104g), Veteran 8–15% (≈119–222g), Elite 18–30% (≈267–445g). They bracket the
  retired fixed anchors (20/45/130/320) and keep the SHAPE the directive asked for:
  random, tiered, low-modest / high-wealthy-but-BOUNDED (even Elite's max 445 << g*, so
  an arrival can't break per-capita; the upkeep attractor normalizes it anyway).
- **`GOLD_ATTRACTOR_REF = 1482`** (the #13 band center) is the anchor. It is a stable
  DESIGN anchor, NOT re-pointed every sweep — the measured band drifts within noise as
  the RNG stream shifts; chasing it would be circular. Re-point only on a deliberate
  economy change.
- **Immigrant fighters ROLL their weapon style** (#13(d) completed for arrivals): the
  `_new_hero` weapon param now carries a rolled sword/bow/staff; immigrant `id%3` retired.
- **No SAVE_VERSION bump** (gold/weapon are values in already-serialized fields; the
  tier shape change is in a Config const, not a save field).
- **RE-BASELINE (diag_founders.gd, 8 seeds × 23 days, rolled founders + rolled
  immigrants): per-capita gold 1,337 ± 269** — supersedes the #13 band 1,482 ± 448.
  The ~145 mean shift + tighter variance are within-noise STREAM effects (the immigrant
  rolls perturb the RNG from the first arrival on), not a real economic regression: 1,337
  and 1,482 sit inside each other's bands, all colonies viable (≥1 fisher, pop 40–43),
  and the #13 death outlier (7a11 50→10) washed out. New band of record: 1,337 ± 269.
- **#15 (immigrant gear rolls) anchors on this**, rolls main-hand to match the #14 style.

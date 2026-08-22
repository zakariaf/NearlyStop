# Idea research notes — E05 offline app hunt

Started: 2026-08-21

## Method
1. Broad parallel sweep across unrelated communities (occupational, hobby, constrained-env, non-English, printable-template niches).
2. Apply hard constraints, log rejections.
3. App Store + Google Play verification on survivors (read 1-3 star reviews).
4. Score with rubric, pick 5 finalists, self-critique, deep-dive top 3.

## Hypotheses about where the richest unmet pain lives
- H1 (conf: med-high) — Regulated/record-keeping trades where a paper logbook is legally or practically required, and phones are used with dirty hands. Pain is recurring and the workaround is literally a notebook.
- H2 (conf: med-high) — Hobbies with *multi-entity state over time* (many jars/tanks/hives/plants/instruments), where the user loses track of "which one was done when". Sticky-note workaround. Models cleanly into 5 screens.
- H3 (conf: med) — Caregiving/health self-tracking for a specific condition, where existing apps demand accounts and subscriptions and users are furious about it.
- H4 (conf: med) — Constrained environments (no signal, gloves, underwater, underground, in-flight) where offline is the *point*, not a compromise.
- H5 (conf: low-med) — Non-English communities where the English-language app market never reached them.
- H6 (conf: med) — "I made a spreadsheet / I print this template every month" niches — proof of an absorbed pain.

## Search log
(appended as sweep agents report)

## Raw candidates
(appended)

## Rejections
(appended)

## Tooling reality check (2026-08-21)
- **reddit.com is fully blocked** for both WebSearch (`allowed_domains` rejects it) and WebFetch ("unable to fetch"). Chrome extension is NOT connected either, so there is no browser fallback. **All evidence below therefore comes from non-Reddit sources**: specialty forums, Stack Exchange, Amazon reviews of printed log books, Etsy/Gumroad printable listings, app-store reviews, Quora, blogs. This is a real limitation on this research and is stated plainly in the deliverable.
- XenForo forums behind `tollbit.*` (beesource.com) return HTTP 402 to bots — unreadable. salongeek.com IS readable.
- **App Store reviews ARE reliably readable** via `https://itunes.apple.com/us/rss/customerreviews/id=<APPID>/page=1/sortby=mostrecent/json` — returns verbatim review text + author + rating. `sortby=mostcritical` also available. This is the primary app-store evidence channel.
- Google Play listing pages: testing.

## Own probe: salon client record cards (logged, low priority)
salongeek.com is fetchable. Real quotes found:
- estherlou (Apr 13 2007): "i use one a5 sheet for each client and i've been doing a new one each time they come in" — https://www.salongeek.com/threads/client-record-cards-how-do-you-do-yours.53392/
- Brandywine (Apr 13 2007): concern about "lots of bits of paper for same client/different treatment" — same thread
- charlie_c_06 (Sep 10 2019): "I'm looking for a app for client consultations so I can start going paperless." — https://www.salongeek.com/threads/paperless-client-records.330859/
VERDICT SO FAR: real pain, but the space is already served (Consult by Timely, Charm, HairTracker, Salon Card) and it drifts toward booking/payments/GDPR consent signatures. Hold as a mid-tier candidate, do not lead with it.
- Google Play **review text is not fetchable** (JS-rendered shell; apkpure/justuseapp mirrors are empty or 403). Play evidence will therefore be: listing metadata + install counts via search, plus any review text that surfaces in search snippets. App Store RSS carries the verbatim-review load. Stated honestly in the deliverable.
- Early intel that will matter: beekeeping hive records **already has an offline-first, no-account, one-time-purchase app** (HiveCompanion, https://hivecompanion.app/ , com.hexatek.hivecompanion). That category is likely already solved — good early kill.

---

# PHASE 2 — Broad sweep results (11 territories, 9 returned, 42 raw candidates)

Workflow `wf_2c313c5c-f9f`. Territories: road-trades, care-health, animals-land, water-outdoors*, craft-making, food-drink*, music-performance, non-english, printables-spreadsheets, constrained-users, paper-logbook-mining.
(*food-drink and water-outdoors died mid-response when the machine slept; re-run queued.)

## Search infrastructure the agents had to build
WebSearch hit its 200/200 session budget partway through. Agents routed around it via
`WebFetch("https://r.jina.ai/https://lite.duckduckgo.com/lite/?q=...")`, which works.
Blocked/unusable this session: reddit.com (total), Stack Exchange network (host block), google/bing/yahoo/ecosia/mojeek/startpage/all public searx instances, amazon `/product-reviews/` (sign-in wall even via proxy), etsy.com (403 + CAPTCHA), quora.com (403), any site behind `tollbit.*` (HTTP 402: beesource, hvac-talk), Google Play review text (JS-rendered).
Workable: independent hobby forums (XenForo/Discourse/SMF/FluxBB/Forumotion), the iTunes Search API, the iTunes customer-reviews RSS, r.jina.ai as a general proxy.

## Raw candidate index (42)
Format: [confidence | frequency | quotes total / read-in-full / distinct domains] title
- [high|daily|q14/fp14/d1] Solo and mobile hair/beauty pros cannot find, read, or safely store their paper client record cards — Self-employed mobile beauticians, nail techs, lash techs and chair-ren
- [high|daily|q6/fp6/d1] Hair colourists keep client colour formulas on index cards or in cloud apps that lock them out and lose the formulas — Independent / chair-renting hair colorists, mobile stylists, and adjac
- [high|daily|q8/fp8/d2] French assistantes maternelles hand-writing a monthly attendance sheet and re-computing complementary hours, meal and upkeep allowances every evening — Assistantes maternelles agréées in France (registered childminders emp
- [high|weekly|q10/fp10/d2] "I won't remember by next spring" — no record of which crop/variety was in which bed, which year — Allotment holders and raised-bed / square-foot vegetable gardeners wit
- [high|weekly|q10/fp10/d2] "Is she on day 28 or day 35?" — losing the day-count on each pregnant doe — Small-scale rabbit breeders (meat rabbits, show/pedigree rabbits, 4-H)
- [high|weekly|q7/fp6/d2] Losing the power/speed/passes settings that actually worked on a specific piece of material — Hobby laser cutter/engraver owners running non-branded material — Glow
- [high|weekly|q8/fp7/d2] Machine service history lives in a notebook, a 3-ring binder, or scratched onto the oil filter — Farmers, ranchers, custom operators and small contractors who own 5–30
- [high|weekly|q9/fp9/d2] German anglers' legally/club-mandated Fangbuch (catch log) that must be handed in on a deadline — Recreational anglers in Germany (and AT/CH) who fish on a Verein or La
- [low|daily|q3/fp3/d1] A cloud seizure diary logged someone out and deleted three years of logs — People with epilepsy (and parents/carers of epileptic children) who ke
- [low|daily|q3/fp3/d1] Paper inspection sheets that get lost between the truck and the office — Owner-operators and 1–5 truck outfits doing daily pre-trip/post-trip D
- [low|daily|q4/fp4/d1] Home blood pressure: which of the three readings do I write down, and what is the week's average — Newly-diagnosed hypertensive patients (and carers taking a parent's BP
- [low|monthly|q1/fp1/d1] Running a monthly jam3iya (rotating savings circle) and tracking who has paid on a paper sheet — The organiser of an informal monthly savings circle (جمعية / gam3eya /
- [low|monthly|q4/fp3/d2] Which filter fits this machine, and how much oil does it take — needed at the parts counter, with no signal — Owners and shop hands running several unlike machines: farmers, small 
- [low|rare|q4/fp4/d1] The three-day frequency/volume (bladder) chart the continence clinic posts out — People referred to a continence or urology clinic — and, very often, t
- [low|seasonal|q2/fp0/d1] The withdrawal clock after medicating a laying flock or a milking animal — Backyard poultry keepers and small dairy goat/sheep owners in the US w
- [low|seasonal|q3/fp3/d1] Parents storing hand-me-down clothes in loft boxes cannot recall what size and season is already in there — UK/US parents with two or more children (and larger families especiall
- [low|seasonal|q3/fp3/d2] Home canners cannot tell what is actually on the pantry shelves or how old it is — Home canners and food preservers — mostly rural/homesteading US househ
- [low|seasonal|q5/fp5/d1] Dive logbooks that make you register on a boat with no signal, then lose the dives — Recreational scuba divers logging dives from a dive boat or a liveaboa
- [low|weekly|q2/fp1/d1] "When did we last sing this?" — service-by-service repertoire history for a single church musician — Solo parish organists, cantors and small-parish music directors who ch
- [low|weekly|q3/fp1/d3] Hairdressers must re-do and re-record an allergy alert (patch) test every six months per client and have no way to know whose is expiring — UK/EU hairdressers and colourists, and lash/brow tinters, who are cont
- [low|weekly|q3/fp2/d2] Potters keep kiln firing and glaze test records in a studio notebook and cannot compare one firing to another — Studio and hobby potters, and shared-studio members who fire together 
- [low|weekly|q3/fp3/d2] Not being able to reproduce the paint mix you used on the rest of the squad — Miniature and model painters (Warhammer/Reaper/scale models) painting 
- [low|weekly|q5/fp5/d1] Proving in-and-out times so the detention claim actually gets paid — Company drivers and owner-operators sitting at a shipper or receiver d
- [low|weekly|q6/fp6/d3] Chest-freezer owners keep a whiteboard or laminated printable on the lid because they never remember to update a phone list — Households with a second chest or upright freezer in a garage, utility
- [medium|daily|q3/fp3/d2] Which of my learned pieces are going stale — repertoire review scheduling for amateur/returning classical players — Adult amateur and returning classical instrumentalists (mostly pianist
- [medium|daily|q5/fp5/d2] Spanish canary/exotic-bird breeders tracking pairings, clutches, hatch dates and ring numbers on hand-drawn cards — Federated and hobby canary/finch breeders in Spain (criadores with a c
- [medium|daily|q6/fp6/d1] 1:1 aides, RBTs and SLPAs tally behaviour and trial data on paper clipboards; the apps that replace the clipboard now demand logins and subscriptions — Behaviour technicians (RBTs), special-education paraprofessionals, SLP
- [medium|daily|q6/fp6/d1] A login screen between a field tech and their own job, in a basement with no bars — HVAC/R service techs, appliance and refrigeration techs, and other fie
- [medium|daily|q6/fp6/d1] Home dialysis patients logging every treatment through a clinic app that logs them out and eats the entry — Home haemodialysis and peritoneal dialysis patients (and their care pa
- [medium|daily|q6/fp6/d2] A carer's record of whether the dose was actually given, not a reminder to give it — Family carers looking after a parent or spouse with dementia or memory
- [medium|daily|q6/fp6/d2] Adding up surgical drain output over rolling 24 hours, per drain, after being sent home — People discharged home after mastectomy / breast reconstruction / tumm
- [medium|daily|q8/fp8/d1] Warfarin patients cannot record a different dose for each day of the week — People on long-term warfarin / Coumadin / Jantoven (mechanical heart v
- [medium|monthly|q6/fp6/d1] Soap batch records that live on paper printouts, and cure dates nobody can keep straight — Hobby and pre-commercial cold-process soapmakers — people making 1-6 b
- [medium|monthly|q7/fp6/d2] Standing in the shop with no idea whether you already own that needle size / that pot of paint — Two separate groups with an identical failure: knitters and crocheters
- [medium|monthly|q8/fp8/d1] Service records you can actually keep — and prove — when the app that held them breaks — People who maintain several vehicles/machines themselves and need the 
- [medium|seasonal|q6/fp6/d1] Small dog breeders and puppy/kitten fosterers weigh every pup twice a day and record it on paper or in a $99/year cloud app — Hobby and small-scale dog breeders, first-litter and 'oops litter' own
- [medium|weekly|q4/fp4/d1] Succession sowing that never actually happens after the first sowing — Vegetable gardeners who intend to sow lettuce/radish/beans every 2–3 w
- [medium|weekly|q4/fp4/d2] The parish choir library is a filing cabinet nobody can browse — Volunteer and part-time church choir directors / parish music director
- [medium|weekly|q5/fp5/d1] Timing film development with wet, chemical-covered gloves under a safelight, on a phone that keeps emitting white light — Home/analog black-and-white photographers developing film and prints i
- [medium|weekly|q6/fp6/d1] Beekeepers' hive card (Stockkarte) is never where they need it — notes taken with sticky gloves on tape, chalk and scrap paper — Hobby beekeepers in the German-speaking area with roughly 5–40 colonie
- [medium|weekly|q6/fp6/d3] Not being able to reconnect a finished pot to the glaze layers and firing that produced it — Hobby and community-studio potters who glaze in batches and fire in a 
- [medium|weekly|q9/fp9/d1] Hive-side record card: what I did to which hive on which date, written with gloves on — UK/EU hobby beekeepers with 2–20 colonies across one or more out-apiar

## Rejections and why

**Rejected on hard constraints:**
- *Proving in-and-out times for truck detention claims* — the claim only pays if the record is credible to a third party; that pulls toward timestamps a broker will accept, i.e. server-attested data. Also thin (q5, one domain).
- *Paper DVIR inspection sheets lost between truck and office* — DVIRs are a compliance artefact that must reach the office; that is sync by definition.
- *Jam3iya / rotating savings circle tracker* — money between people. Payments-adjacent, and the organiser's ledger is other people's financial data. Also q1: one voice only.
- *1:1 aides / RBT behaviour tallies* — the data is a child's clinical record; employers mandate their own systems; HIPAA/FERPA exposure. Wrong thing to film.
- *Home dialysis treatment logs* — the value is getting the log to the clinic. Server.
- *Church choir library / "when did we last sing this"* — drifts to a licensed repertoire database; evidence thin (q2, fp1).
- *Which filter fits this machine* — the useful version is a filter cross-reference database. Licensed content.

**Rejected as saturated / not sharply different:**
- *Chest-freezer inventory* — freezer inventory apps are numerous and the offline angle is not special. Low confidence anyway.
- *Home canning pantry inventory* — same shape as above, seasonal.
- *Knitting needle / paint "do I already own this" inventory* — monthly frequency, and stash-inventory apps exist in both niches.
- *Hand-me-down children's clothes in loft boxes* — seasonal, generic inventory, q3 one domain.
- *Home blood pressure averaging* — dozens of BP apps; the "which of three readings" angle is real but tiny and already handled by several.
- *Succession sowing reminders* — this is a habit tracker wearing a gardening hat.

**Rejected on evidence:**
- *Withdrawal clock after medicating a laying flock* — q2, and fp0: not one quote was read on a live page. Unsupported.
- *Cloud seizure diary deleted three years of logs* — q3, single domain, and it is one person's data-loss anecdote rather than a recurring pain.
- *Continence clinic 3-day bladder chart* — "rare" frequency; a one-off 3-day exercise.
- *Dive logbooks* — territory agent died mid-run; candidate survived at low confidence with 5 quotes from one domain. Re-queued.

**Held as mid-tier, not promoted:**
- Salon/mobile-beauty client record cards and colour formulas (q14 and q6, but each from a SINGLE domain — salongeek — and the space is served by Consult/Timely, Charm, HairTracker; drifts to booking, payments and GDPR consent signatures).
- Hairdresser 6-month allergy patch test records (q3/fp1 — mostly unread).
- Potters' kiln and glaze records (two variants, medium, 2-3 domains) — genuinely decent, kept as depth.
- Darkroom film development timing under a safelight (medium, q5, one domain) — best *demo* of the whole set (red-light UI, wet gloves) but weakest evidence base.
- Soap batch records and cure dates; dog-breeder puppy weights; Spanish canary breeders; German beekeepers' Stockkarte; classical repertoire staleness; carer's "was the dose actually given" record.

## Finalists sent to store verification (workflow wf_4e03fb87-d6b)
1. German anglers' mandatory paper Fangbuch
2. Warfarin per-weekday variable dose + INR log
3. Rabbit breeders' gestation day-count
4. Surgical drain output, rolling 24h per drain
5. Hobby laser material settings
Reserves: allotment bed/crop history; French assistantes maternelles monthly sheet.

## Evidence integrity spot-checks (done by me, not by an agent)
I re-fetched four pages and asked whether the claimed words were actually there. All four confirmed verbatim:
- anglerboard.de/threads/...355521 — Danielsu83 "Muss bis zum 10.01 an den Verein zurückgehen ansonsten kostet es 30 € + 120 € für den Arbeitstag..." CONFIRMED; Wertachfischer_KF "Letztens wurde ein Mitglied abgemahnt, weil sein Fangbuch völlig zerrupft und unleserlich war." CONFIRMED
- rabbittalk.com/threads/...1523 — Anntann "How many times do we say 'I can't remember if this is day 28 or 35'?" CONFIRMED
- community.breastcancer.org/...761941/p3 — toni67 seroma/mis-com quote CONFIRMED in full; Luckydog42 "24cc or less in 24 hours" CONFIRMED
- community.glowforge.com/t/...134356 — eflyguy "I keep a small notebook on the machine and number every setting I write down." CONFIRMED, dated 23 Aug 2024
Conclusion: the sweep agents are quoting accurately, so I am treating their read_full_page quotes as reliable, while still marking any search_snippet_only quote as weaker in the deliverable.

## My own store checks (corrections to sweep agents)
Ran the iTunes Search API directly.

**CORRECTION 1 — drain apps DO exist.** The sweep agent claimed "No dedicated drain-output app surfaced in any search". False. `itunes.apple.com/search?term=surgical+drain+output+log&entity=software&country=us` returns:
- Surgical Drain Logger — id 685926247, 4.4★ / **5 ratings**, free, David Cross, "HIPAA Compliant App...to Log, Track, Date, and Print results of surgical drain fluid levels"
- Drain IQ — id 1100445683, 4.45★ / **22 ratings**, free, Golem Health LLC, tracks output through the day, single or multiple drains
- BRCA Box Drain Log — id 6774968274, **0 ratings** (brand new), Dreaming Crow Productions, tracks left/right drain separately
So the honest framing is not "no app exists" but "three apps exist and essentially nobody uses them". Whether any does the rolling-24h-vs-threshold arithmetic offline is the open question → verification agent.

**CORRECTION 2 — the German catch-log category is populated.** `country=de&term=Fangbuch` returns at least ten apps, several already claiming exactly the offline/local property I assumed was the gap:
- Angel Logbuch – LogIT — id 6667102943, 4.76★ / **93 ratings** (the category leader by ratings)
- Catchium — id 1438127530, 4.17★ / 6 ratings — description says "works without internet connection"
- CatchLog — id 6757596599, brand new — "data stays on your device"
- Petri – Dein Fangbuch — id 6760222198, 4.5★ / 2 ratings — "local data processing"
- ALLE ANGELN — id 1095645023, 4.78★ / **8407 ratings** — but social/spot-sharing, i.e. the thing the forum users reject
- angelflix — id 6468769082, 3.95★ / 21 — club communications + digital permits (account product)
Pattern worth noting across both: lots of apps, almost no ratings. "An app exists" and "these people are served" are not the same claim, and I need review evidence to tell them apart before I put any of this in the shortlist.

---

# PHASE 3 — Store verification of the finalists (workflow wf_4e03fb87-d6b)

**This phase killed most of my shortlist. That is the single most important result of the whole exercise.**

| Candidate | Verdict | What killed or wounded it |
|---|---|---|
| German anglers' Fangbuch | **ALREADY_SOLVED_DROP_IT** | `Fangbuch – Angeltagebuch` (id 6788362643) shipped **2026-08-02, nineteen days ago**, whose listing reads like this brief: "Kein Konto, kein Server, keine Community. Alles bleibt auf deinem iPhone", "Funktioniert komplett offline", club PDF Fangliste with "Filter je Gewässer, Summenzeile". Plus LogIT (4.76★/93) already the offline private Fangbuch, fish trace on Android (10K+ installs, "excellent offline functionality"), and 10+ more DE catch diaries. Structural killer: clubs are digitising from the *club* side (fangmeldung.de — Fischereiverein Wüsting: "266 Mitglieder haben sich bereits in der App angemeldet und die Fangliste für 2024 digital abgegeben"), and clubs do **not** reliably accept a printed digital book anyway. |
| Rabbit gestation day-count | **ALREADY_SOLVED_DROP_IT** | `WhosDue` — $9.99 one-time, **offline, no account**, 4.40★/47 ratings. Does exactly "who is bred, to whom, nest box date, due date". Everbreed's subscription misery (2★ 2026-05-25: "There's absolutely no point in me paying for a monthly subscription to this junk anymore") is real but WhosDue already collects those refugees. |
| Warfarin per-weekday dose | **PARTIALLY_SERVED — premise falsified** | `INR Diary` (£1.99, iOS+Android, **offline, local-only, no account**, 4.3★/203 on Play, 5,000+ installs) has an "Add doses in bulk" screen with a repeating 7-slot scheme. The claim "nearly every INR app can't do per-weekday dosing" is false for the market leader. Residual gap is only *one-off single-day overrides* — too thin for an episode. The app my evidence came from (`INR log`) is abandonware. |
| Allotment bed/crop history | **PARTIALLY_SERVED** | `Raised Bed Planner` (id 6767129624, shipped 2026-05-12): "No account, no sign-up, no login. No server, no backend… Works completely offline — no network needed, ever." Plus three more with identical positioning shipped Jun–Jul 2026. All four have ~zero ratings. The incumbents that *do* have traction genuinely fail (GrowIt, Seed to Spoon, Planter, Seedtime — account-gated, subscription, "App deleted my garden") but you would be the fifth entrant in a four-month land-grab. |
| Hobby laser material settings | **PARTIALLY_SERVED** | No offline account-free *personal* settings log exists on either store — everything is vendor remotes or generic calculators. But LightBurn's local `.clb` Material Library already serves CO2 owners at the PC they're standing at, the phone-at-the-machine case is weakly evidenced (one strong quote), and lasersettingshub.com already claims that position with an account. Two calculator apps shipped Mar 2026. |
| Surgical drain output | **PARTIALLY_SERVED** | Apps do exist and more keep shipping: Drain IQ (4.45★/22), Surgical Drain Logger (4.4★/5), BRCA Box Drain Log (2026-06-30), JPal1.0, Outflow (**2026-08-13, eight days ago**), plus drain-log.com / drain-track.com / draindata.org. Open question sent back for a deep check: does *any* of them do the rolling-24h-per-drain-vs-threshold rule, or do they just total per calendar day? |
| **French assistantes maternelles** | **GAP_CONFIRMED** | The only survivor. See below. |

## THE STRATEGIC FINDING (this reframes the whole brief)

In 2025–2026 there is an active **land-grab of solo developers shipping "offline, no account, local-only, no subscription" niche loggers**. I hit it in six separate niches: anglers (19 days ago), gardening (four apps in four months), rabbits, beekeeping (HiveCompanion), kiln logs (KilnLog — "no account, works offline"), drains (two in the last eight weeks).

**"An offline no-account log for niche X" is itself now a saturated strategy.** Storing records is no longer a defensible pain. Whatever this episode builds, its value cannot be *storage*.

Why the French childminder candidate survived, and it is the only one that did: **its value is domain arithmetic, not storage.** A generic logger cannot compute mensualisation. That is the pattern, and Phase 4 hunts it deliberately.

## THE SURVIVOR — assistantes maternelles, in detail
The market splits perfectly in half and the gap is the seam:
- **Offline + no account = hour COUNTERS that refuse to do the money.** Nannix's own store copy: *"Nannix ne calcule pas de salaire, de charges ni de cotisations… C'est volontairement un outil de comptage des heures."* Also Feepio (100% hors-ligne), Calendrier Nounou+, Nounou Time — none contain the words mensualisation, heures complémentaires or indemnités d'entretien.
- **Everything that computes the money = cloud + account + subscription.** Envola 15€/mois, GardeZen 5,99€/mois, Top Assmat 2,99€/mois/contrat, OptiNounou (paid, and it calls an LLM), PAM, and the official Urssaf app which needs an Urssaf login *and* the employer to have configured the contract server-side.
- The wedge sub-case — **semaine A / semaine B and année incomplète** — is exactly what has been broken in PAM since 2021 and, per a URSSAF phone advisor, in the official app for contracts of ≤46 weeks.
- Build verdict from the verifier: ~40 lines of pure functions and eight editable constants, comfortably one day — **provided** congés payés, déduction pour absence and la régularisation annuelle are all cut. Include any one and the episode dies.

## PHASE 4 launched (workflow wf_b5cbf36f-2a5)
Hunting the surviving pattern deliberately: pains whose value is **domain computation or a mandated output format**, not storage.
Four territories: non-English regulated paperwork (Spanish *registro de jornada*, German *Fahrtenbuch*, Italian *registro trattamenti fitosanitari*…), home care arithmetic (MAR charts, drug tapering schedules, fluid/feed volumes), hobby arithmetic (soap lye, darkroom time-temp, glaze scaling, gauge-swatch resizing), and a drain deep-check on the rolling-window question plus adjacent rolling-threshold pains (10% newborn weight loss, triptan-days-per-month, peak-flow zones).

## PHASE 2b — the two re-run territories (food-drink, water-outdoors)
Both completed on the re-run. Neither produced anything that beats the survivors, and both **independently confirm the strategic finding** — the agents volunteered the saturation without being asked:
- Dive logs — "HIGH and I will not pretend otherwise — 'dive log app' is a crowded category and one genuinely good offline paid one already exists"; a new entrant `Below` (id 6756759745) already advertises the offline angle.
- Potters' glaze/firing records — "HIGH and rising fast."
- Home-preserve / pantry inventory — "High and honest: there are dozens of pantry/freezer inventory apps, and two brand-new canning-specific ones (JarTrack, Canning Log)".
- Aquarium water parameters, boat engine hours, hunting journals — all medium, all one-domain evidence, all adjacent to saturated maintenance/notes categories.
- Mildly interesting new shape: **pressure-canning stage-keeper** (losing your place mid-process when the phone leaves the app; a restarted timer can mean unsafe jars). Rejected: "timer" is a named-saturated category and the OSU app exists, and the safety-critical framing is a bad thing to get wrong on camera.
- Also logged: French FFESSM divers whose app logbook lacks the fields their paper *carnet de plongée* requires (q3, one domain — too thin, but it is the same "mandated format" shape that survived elsewhere).

Net: nothing promoted from these two territories. Candidates #2 and #3 now depend on the Phase 4 arithmetic hunt.

---

# PHASE 4 — The arithmetic hunt (workflow wf_b5cbf36f-2a5)

Targeting the only pattern that survived: value = **domain computation or mandated output format**, not storage. 16 candidates returned. This worked — six GAP_CONFIRMED.

## Confirmed gaps
| Candidate | Conf | Freq | Evidence | Why the gap is real |
|---|---|---|---|---|
| **DSNS steroid taper (PMR/GCA prednisolone)** | high | daily | q7/fp7, **3 domains** | Generic-% taper apps exist but are broken or account-gated; nothing produces the alternating-day DSNS calendar, tablet composition, or cumulative load |
| **UK PPDS / Natasha's Law ingredient label builder** | high | weekly | q5/fp5, 2 domains (**mostly Facebook**) | ZERO maker-side label generators on either store — every hit is a consumer barcode scanner |
| **CLP hazard label builder (candles/wax melts)** | med | weekly | q5/fp5, 3 domains (**mostly Facebook**) | ZERO on either store; competitors are web + locked to one supplier's oil catalogue |
| **Italian condominio minimo riparto** | high | monthly | q4/fp4, 2 domains | `itunes country=it` for "millesimi condominio riparto" returns **resultCount 0**; every condominio app is a portal client for a professional administrator |
| **Solo MAR chart (family carer / directly-employed PA)** | med | daily | q6/fp6, 3 domains | Everything is agency SaaS needing an employer account and a server |
| **Warfarin dose-to-tablet solver** | med | daily | q4/fp4, **1 domain** | Loggers exist, solvers do not — but single-domain evidence |

## Also settled
- **Surgical drain — now definitively ALREADY_SOLVED_DROP_IT.** `Outflow: Surgical Drain Log` (trackId 6793286883, released 2026-08-13, nine days ago) **does** implement the rolling per-drain 24h window against a threshold. The one arithmetic differentiator is gone. Closed.
- **Bladder diary — ALREADY_SOLVED_DROP_IT**, and the agent called the category "a textbook picture of the 2025-2026 land-grab."
- **Equilibrium cure calculator (charcuterie)** — already served on both stores plus web.
- **Hyperbolic antidepressant/benzo taper** — PARTIALLY_SERVED, contested by several live products (TaperMate, Taper, DoseDown, Prescriby). The PMR/GCA DSNS variant is the unoccupied slice, not tapering in general.
- **Heart-failure daily weight** — GAP on arithmetic but **fp0: not one quote read on a live page.** Evidence fails; dropped.
- **England school-attendance fine threshold** — genuinely empty store slot, but fp1 of 4 and low confidence; also a sensitive subject (penalty notices) to film. Held, not promoted.
- Machinist change-gear solver, smallholder medicine book, NB-UVB dose book, medication-overuse headache: all PARTIALLY_SERVED or too narrow/risky.

## EVIDENCE PROBLEM I FOUND AND ACTED ON
The two label-builder candidates rest heavily on **Facebook group permalinks**. I fetched them logged-out: only the first clause of the opening post renders (as the page meta description) — no author, no replies. That fails the brief's "working URLs I can click and read myself" standard. Launched workflow `wf_c316a722-ceb` to replace that evidence with publicly readable sources before either can enter the top three.

## My own verification of the leading candidates (done by me)
- `healthunlocked.com/pmrgcauk/posts/131189593` — **403s to bots but is public in a browser.** Read via r.jina.ai proxy: thread content confirmed present. **PMRpro** (named moderator) verbatim: *"Forget 7 days in the week. You are just taking the new dose for 1 day each time but getting those days closer together."* Confused-member quotes confirmed present, though the proxy render did not carry those usernames.
- `community.patient.info/t/reducing-pred-dead-slow-and-nearly-stop-method/531439` — **readable without login, confirmed.** anon53727290 sets out the day pattern verbatim.
- `assistantes-maternelles.net/forum/t/aide-heures-complementaires.6757` — **readable without login, confirmed.** shouby88's 0,8943 question confirmed verbatim.
- Facebook permalinks for PPDS and CLP — opening clause confirmed present, authors and replies NOT publicly visible.

## Standing at this point
1. DSNS steroid taper — evidence verified by me on public pages.
2. Assistantes maternelles — evidence verified by me on public pages.
3. Open — depends on the hardening round (PPDS label vs CLP label vs MAR chart vs condominio).

---

# PHASE 5 — Evidence hardening (workflow wf_c316a722-ceb) and final selection

Purpose: replace the Facebook-based evidence with publicly readable sources before anything entered the top three.

| Candidate | Verdict | Outcome |
|---|---|---|
| PPDS ingredient label | **STILL_THIN** | Public evidence found on CakeCentral (2008–2018) and IFSQN (2025) — but it is **US cottage-food bakers** on descending order and compound ingredients, and the QUID complaints come from **food-safety QA professionals, not home bakers**. The UK/Natasha's Law segment has essentially **no public first-person evidence**: every time a UK home baker's own words surfaced, the URL was facebook.com/groups. Demoted to finalist #5. |
| CLP hazard label | **EVIDENCE_NOW_SOLID** | Seven separate real makers across two publicly readable forums (soapmakingforum.com, craftserver.com). Bonus find: two major UK suppliers (Candle Shack vs House of Scent) **publicly contradict each other** on load-vs-content — the exact ambiguity the app resolves. Promoted to top three. |
| Solo MAR chart | **STILL_THIN** | Dropped. |
| Italian condominio minimo | **EVIDENCE_NOW_SOLID** | 20 public quotes across 6 domains, dated 2019–2026 with the best clustered 2024–2026. App Store `country=it` returns **resultCount 0** for "millesimi", "riparto spese", "rendiconto condominiale" and "millesimi condominio riparto". Finalist #4. |

## Verification I did personally in this phase
- `soapmakingforum.com/threads/blending-fragrance-oils-candle-selling.79998` — readable without login; LilyJo's quote confirmed verbatim.
- `craftserver.com/topic/117975-...` — 403 to WebFetch but renders fully via headless browser and shows the guest prompt "You can post now and register later". **Bot wall, not login wall** — a human in a browser can read it. Flagged in the deliverable as the one source to click before filming.
- `condominiopro.it` / `propit.it` / `immobilio.it` quotes — real owners, named handles, 2024–2026.
- Everything above is on top of the Phase-4 personal checks (healthunlocked, patient.info, assistantes-maternelles.net).

## Self-critique — what would collapse if pushed, and what I did about it
- **PPDS label builder** — pushed on it, and it did collapse: the UK pain is real in regulation but not documented in public in UK bakers' own words. Demoted rather than dressed up.
- **Surgical drain** — my own earlier claim that no app existed was wrong; I corrected it, then the rolling-window differentiator died too when `Outflow` (2026-08-13) turned out to implement exactly that rule. Fully dropped.
- **Warfarin** — my premise was falsified by `INR Diary`, which already does per-weekday dosing offline with no account. Dropped rather than narrowed to the thin one-off-override residual.
- **Condominio** — survives evidence pressure easily; its real weakness is **frequency** (annual), so it lost the third slot on the rubric, not on quality. Said so explicitly in the deliverable.
- **CLP** — weakest link is that 4 of 7 maker quotes sit on the Cloudflare-walled craftserver; stated in the deliverable.
- **DSNS taper** — weakest links are single-forum concentration, two quotes whose usernames did not render, and App Store review risk for a drug-dosing app; all stated.
- **Assmat** — weakest link is that `Nannix` is one product decision from closing the gap; stated.

## Final five and scores (see idea-shortlist.md)
1. DSNS steroid taper — 32
2. Assistantes maternelles — 31
3. CLP hazard label builder — 29
4. Condominio minimo riparto — 29 (lost the tie on frequency)
5. PPDS ingredient label builder — 26

**Recommendation: DSNS steroid taper**, with CLP as the swap if the medical framing is unwelcome, and condominio as the pick if an Italian-language episode is acceptable and zero competition matters most.

## Honest limits of this research
- **Reddit was completely unavailable** (search refuses the domain, fetch is blocked, Chrome extension not connected). The single richest source of "I wish there was an app for" posts is missing from all of it. If you connect the Claude Chrome extension I can go back and reinforce the top three with Reddit threads.
- **Google Play review text was never obtainable** (JS-rendered; apkpure/justuseapp dead). All verbatim store reviews in the deliverable are App Store. Play evidence is listing metadata only, and is labelled as such.
- **The whole Stack Exchange network, Amazon product-reviews pages, Etsy and Quora were unreachable**, which cost me the paper-logbook-review angle I had expected to be productive.
- WebSearch hit its 200-query session budget early; most discovery ran through `r.jina.ai` over DuckDuckGo Lite.
- Agent-reported quotes were spot-checked by me at every phase (10 pages re-fetched independently); every check passed verbatim, and the two claims that were wrong were the agents' *conclusions* (drain apps "don't exist", warfarin apps "can't do per-weekday"), not their quotes.

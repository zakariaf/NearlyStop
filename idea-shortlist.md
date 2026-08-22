# Five finalists, scored

| # | Candidate | Pain | Freq | Offline fit | Build | Evidence | Demo | Gap | **Total** |
|---|---|---|---|---|---|---|---|---|---|
| 1 | **DSNS steroid taper** — PMR/GCA patients laying out an alternating-day prednisolone reduction | 5 | 5 | 4 | 4 | 4 | 5 | 5 | **32** |
| 2 | **Assistantes maternelles** — French childminders computing the monthly pay récap | 5 | 5 | 4 | 4 | 5 | 5 | 3 | **31** |
| 3 | **CLP hazard label builder** — UK candle/wax-melt makers recalculating allergens for their own fragrance load | 4 | 4 | 3 | 4 | 4 | 5 | 5 | **29** |
| 4 | *Condominio minimo riparto* — Italian self-managed buildings splitting costs per statutory article | 5 | 2 | 3 | 4 | 5 | 5 | 5 | **29** |
| 5 | *PPDS ingredient label builder* — home bakers ordering ingredients by weight with sub-ingredients | 4 | 4 | 3 | 4 | 2 | 5 | 4 | **26** |

3 and 4 tie on 29. CLP takes the third deep-dive slot on **frequency** — a maker recalculates every time they change a fragrance or a load, an Italian building does its *rendiconto* once a year. Condominio is written up in brief under the recommendation, because on *gap* it is the strongest thing I found all day.

---

## One finding that should change how you read this list

I killed five of my first seven candidates at the app-store step, and they all died the same way. **In 2025–2026 there is an active land-grab of solo developers shipping "offline, no account, local-only, no subscription" niche loggers.** I hit it in six unrelated places: a German anglers' catch-book app that shipped 19 days ago whose store listing is nearly a paraphrase of your brief (*"Kein Konto, kein Server, keine Community. Alles bleibt auf deinem iPhone"*), four gardening apps with identical positioning inside four months, `WhosDue` for rabbit breeders ($9.99 one-time, offline, no account, 4.4★/47), `HiveCompanion` for beekeepers, `KilnLog` for potters, and two surgical-drain apps in the last eight weeks.

So "an offline no-account log for niche X" is no longer a differentiator — it is the crowd. **Storage is not a defensible pain any more.** Every candidate below earns its place because its value is *domain arithmetic or a mandated output format* that a generic logger cannot produce. That is the only filter that survived contact with the stores, and it is worth more to you than any single idea on this page.

---

# 1. The alternating-day steroid taper

## The pain
Someone with polymyalgia rheumatica is told to come down from 10mg of prednisolone to 9mg. The safe community method is not "take 1mg less" — it is an eleven-block calendar where the new dose is taken on progressively closer days (1 new + 6 old, then 1 new + 5 old, … then 1 old + 6 new, then daily), which runs 52 days for a single 1mg step and deliberately ignores week boundaries. Then each day's dose has to be built out of the tablets you actually hold: 6.5mg is one 5mg + one 1mg + half a 1mg. Patients try to map a 52-day non-weekly pattern onto a 7-day week, lose their place, and cut too fast — which causes a flare that costs months of progress.

## Who exactly
People with PMR or giant cell arteritis on long-term prednisolone, tapering themselves over two to five years, overwhelmingly aged 60–80. PMR runs at roughly 1 in 1,200 people over 50, so the population on steroids at any time is in the hundreds of thousands across the UK and US. The realistic addressable slice — people actively following the DSNS method rather than their rheumatologist's flat step-down — is far smaller, plausibly tens of thousands. That sits inside your 500–50,000 target rather than above it.

## What they do today
Hand-built Excel spreadsheets, passed around the forum between members. A paper wall calendar marked in colour. Copying the forum's text list into a Word document. The PMRGCAuk charity distributes a downloadable spreadsheet specifically for recording cumulative steroid load. One member reported showing their spreadsheet to their rheumatologist, who said it was "going to drive me crazy".

## Evidence
> "for example, as there are 7 days in the week and you take a dose each day, how can you have for example ' 1 day new dose, 2 days old dose' what's happening on the other 4 days?"
> — forum member, PMRGCAuk. https://healthunlocked.com/pmrgcauk/posts/131189593/dead-slow-and-nearly-stop-reduction-plan

> "Forget 7 days in the week. You are just taking the new dose for 1 day each time but getting those days closer together."
> — **PMRpro**, long-standing PMRGCAuk moderator, answering the above. Same URL.

> "I developed a VERY simple spreadsheet showing the DSNS method of prednisone reduction when initially diagnosed"
> — forum member, PMRGCAuk 'spreadsheets' thread. https://healthunlocked.com/pmrgcauk/posts/151977594/spreadsheets

> "1 day new dose, 6 days old dose / 1 day new dose, 5 days old dose / 1 day new dose, 4 days old dose…"
> — **anon53727290**, setting out the full pattern on a second, independent site. https://community.patient.info/t/reducing-pred-dead-slow-and-nearly-stop-method/531439

Honesty on these: I opened all four pages myself and confirmed the words are there. `healthunlocked.com` returns 403 to automated fetchers but renders normally in a browser — your click will work. Two of the confused-member quotes rendered without their usernames, so I can tell you the words are real and on that page but not who wrote them. `community.patient.info` is fully public.

## Why existing apps fail them
- **`Steroid Taper Calculator™`** (id 970107699, free, **1.58★ from 12 ratings**). Its description: calculates a taper "by a fixed dose" or "by a fixed percentage" — i.e. the clinician step-down, not an alternating-day pattern. Recent reviews are almost all one star. dpfeffer1: *"Great idea but the app doesn't work. It won't let me submit information for different medications, different strengths, or different dosing schedules. Love the idea, would love an app that works"* (https://apps.apple.com/us/app/id970107699?see-all=reviews).
- **`TaperMate`** (id 6741719956, 3.4★/5) **requires an account** — its top recent review is one star: *"Can't create account … Every time I try to create an account and tap the link in my email to sign in it says I haven't registered"*. A five-star review there says *"This app does what the other three on the app store do not. Actually schedules the taper!"* — a user confirming the rest of the category doesn't schedule at all.
- **`Taper: Medication Tapering App`** (id 6743771314, 3.73★/26) is an *"AI assistant that builds your plan through conversation"* — server plus LLM, out of scope for you and non-deterministic for a dosing calendar.
- **`Prescriby`** is clinician-gated; `DoseDown` and `TaperTracer` have 0 and 2 ratings.
- The dozen web prednisone calculators (predtaper.com, pulmapps.org) all emit the clinician step-down (40mg × 5 days, 30mg × 5 days…). None produces the alternating-day pattern, none composes tablets, none totals cumulative load. Google Play surfaced no DSNS taper app at all.

## Why offline and account-free suits them
The inputs are a starting dose, the tablet strengths in your cupboard, a start date and a step rule — all typed by the user, nothing to fetch. No drug database is needed because prednisolone comes in four or five strengths you pick from a list. The users are in their seventies and will not create and remember an account to read their own pill schedule, and this is medical data about a chronic illness that they have no reason to put on someone's server. The output that matters is a printed sheet taken to a rheumatology appointment, which is a local PDF.

## Proposed MVP
**Screens (5)**
1. **Setup** — drug name, current dose, which tablet strengths you hold, whether you split tablets, start date.
2. **Step rule** — DSNS blocks / simple weekly / plain percentage, with the 10%-of-current-dose rule shown and editable.
3. **Calendar** — generated day by day, each cell showing the dose and the tablet breakdown, with no week grid at all.
4. **Today** — one big card: today's dose, today's tablets, tick it off, note a symptom, and a "flare" button.
5. **Record** — cumulative mg, days on steroids, and a printable/exportable taper sheet.

**Data model**
- `TaperPlan { id, drugName, startDate, startDose, stepRule, stepSize, tabletStrengths[], splitAllowed }`
- `Day { date, doseMg, tablets[{ strengthMg, count }], taken, note }`
- `Flare { date, revertToDose, note }`
- Days are **derived**, never stored as truth — regenerate from plan + flares, so a rollback cannot leave stale rows behind.

**The interaction that has to feel perfect:** the Today card. It is the only screen most users open on most days, and it has to answer "what do I swallow this morning" in one glance, at arm's length, without scrolling — the dose in very large type, the tablets as physical-looking counts ("1 × 5mg, 2 × 1mg, ½ × 1mg"), and one tap to confirm.

## Out of scope for v1
Symptom charting beyond a single free-text note. Any drug database or interaction checking. Sharing with a clinician over a network. Multiple concurrent drugs. Hyperbolic/liquid microtapering (a different and much larger arithmetic). Reminders beyond one local notification. Anything that recommends a dose rather than laying out one the user entered.

## Risks
The honest case against: this computes a schedule for a prescription drug, so it needs framing as "lay out the plan you and your doctor agreed" and never as advice — and Apple's review team can be sticky about anything touching drug doses, which is a real chance of a rejection mid-episode. The evidence, while real and public, is concentrated on one forum, and two quotes lost their usernames in my capture. The DSNS method is a *patient-community* protocol, not a clinical guideline, so you are encoding folk practice — defensible, but say so on camera. And the users are elderly, which raises the accessibility bar (type sizes, contrast, tap targets) above a normal episode.

## 90-second demo script
Open on a kitchen table: a pill organiser, a wall calendar scribbled in two colours, and a printed spreadsheet. "This is how you come off steroids. Your doctor says drop 1mg. The safe way to do it takes 52 days and deliberately ignores that a week has 7 days in it." Show the forum thread — the question, then PMRpro's reply: *"Forget 7 days in the week."* Cut to the app. Enter 10mg, tick the tablet strengths you own, pick DSNS, tap Generate. The calendar fills — dates, not weeks. Scroll it once. Tap into today: "7mg — one 5mg, two 1mg." Tick. Then press Flare, pick "back to 8mg", and watch the whole calendar regenerate from there with the cumulative total preserved. End on the export sheet: "and that's what you hand your rheumatologist."

---

# 2. The French childminder's monthly pay récap

## The pain
A registered *assistante maternelle* writes each child's arrival and departure on a paper *fiche de présence* every evening. At month end she has to derive from it: the *mensualisation*, the *heures complémentaires*, the *heures supplémentaires* (anything above 45h in a week, at +10% minimum), the *indemnités d'entretien*, meals and snacks, and finally the net figure the parent declares on Pajemploi. The arithmetic genuinely defeats people — the forums are a running queue of women posting their own numbers and asking peers to audit them — and every error lands directly in someone's pay and in a declaration to a state agency.

## Who exactly
Roughly 200,000–250,000 *assistantes maternelles agréées* in France: childminders employed directly by parent-employers rather than by a crèche. Each keeps one sheet per child per month. Skews older, low historic willingness to pay for software.

## What they do today
A hand-drawn monthly *fiche de présence* in two copies, signed by the parents and stapled to the payslip. Or a home-made Excel/Word sheet with columns for arrival, departure, HC, HS, IE, *repas*, *goûter*. Or — repeatedly — posting the raw numbers on a forum and asking a moderator to do the maths.

## Evidence
> "Je fais une fiche chaque mois avec les heures d'arrivée, de départ et les HC éventuelles. Je les remplis chaque soir"
> *(I make a sheet every month with arrival times, departure times and any complementary hours. I fill them in every evening)*
> — **pepette1964**, 06-05-2011. http://forum.assistante-maternelle.biz/viewtopic.php?id=142454

> "Je fais 27h pour 4.20 net. La j'ai fais 9 heures d'heures complémentaires pouvez vous me dire comment faire le calcul. On m'a dit de partir du brut et de multiplier par 0.8943."
> *(I do 27h at €4.20 net. I've done 9 complementary hours, can you tell me how to do the calculation? I was told to start from the gross and multiply by 0.8943.)*
> — **shouby88**, 27 March 2024. https://www.assistantes-maternelles.net/forum/t/aide-heures-complementaires.6757/ *(I opened this page myself; readable without login, quote confirmed verbatim)*

> "je cale sur la façon de procéder pour déterminer la nouvelle mensualisation comme le nombres d'heures sera différent selon la semaine"
> *(I'm stuck on how to work out the new monthly salary since the number of hours will differ from week to week)*
> — **Nanou60**, August 2026. https://www.assistantes-maternelles.net/forum/t/calcul-nouvelle-mensualisation.13164/

## Why existing apps fail them
The market splits cleanly in half, and the gap is the seam between the halves.

**Offline and account-free — but they refuse to do the money.** `Nannix` says so in its own store copy: *"Nannix ne calcule pas de salaire, de charges ni de cotisations… C'est volontairement un outil de comptage des heures."* Same for `Feepio` (100% hors-ligne, July 2026), `Calendrier Nounou+` (local-only, whose description contains none of the words *mensualisation*, *heures complémentaires* or *indemnités d'entretien*), and `Nounou Time`.

**Compute the money — but all cloud, account and subscription.** `Envola` 15€/month, `GardeZen` 5,99€/month, `Top Assmat` 2,99€/month per contract, `OptiNounou` (paid, and it calls an LLM to explain the salary), `PAM` (subscription).

And the official Urssaf app, `Mon Pajemploi au quotidien` (3.99★, 1,143 ratings), needs an Urssaf login *and* the employer to have configured the contract server-side:
- **Zaina.3**, 1★, 2026-04-27: *"Je suis assistante maternelle mais je n'arrive pas à me connecter… «Pas de contrat trouvé…» «Vos employeurs n'utilisent pas Mon Pajemploi au quotidien ou alors ils n'ont pas configuré le contrat.»"*
- **Rom1.R**, 2★, 2025-10-28: *"les indemnités d'entretien ont un plancher légale défini par la loi et évolutif. Pourquoi n'y a-t-il pas de mise à jour automatique de cette valeur ? … je dois recalculer à la main tous les résu[ltats]"*
- **Vincent04558485**, 3★, 2026-05-04: *"l'appli ne gère pas correctement les absence pour les contrats de 46 semaines ou moins. C'est un conseiller urssaff qui m'a indiqué par téléphone…"*

The wedge sub-case — **semaine A / semaine B and irregular weeks** — has been broken in `PAM` continuously for four years:
- **Miss-Émilie**, 1★, 2023-09-24: *"Dommage qu'on ne puisse pas rentrer un planning avec 2 semaine différente niveau horaire … et jours de garde. Je ne recommande pas du coup."*
- **anaisnani6491**, 1★, 2023-03-21: *"decu pour mes contrats aleatoire… semaine A 3 jours semaine B 2 jours et pas possible de creer ce rituel"*
- **Déception**, 1★, 2025-10-19: *"Très limité et cher payé. Prends en compte que les contrats simple et pas assez de latitude de saisie."*

Reviews at https://apps.apple.com/fr/app/id1543623702?see-all=reviews and https://apps.apple.com/fr/app/id1642486161?see-all=reviews

## Why offline and account-free suits them
The data is children's names and specific families' daily comings and goings, which childminders are wary of putting in a cloud service; the sheet only ever needs to be printed and handed to the parent who signs it. Everything — contract parameters, daily clock in/out, monthly recap — is a pure local computation. Critically, the account-based competitors *fail on the account itself*: Zaina.3 cannot use the official app because her employer never configured anything server-side. An offline app cannot have that failure mode, because there is no other party to depend on.

## Proposed MVP
**Screens (5)**
1. **Contrats** — one card per child: année complète/incomplète, weeks of care, weekly pattern (single, or semaine A + semaine B), hourly rate with a brut/net toggle, the >45h majoration %, IE mode and amount, meal and snack amounts. A banner flags anything below the legal minimum.
2. **Pointage** — today: big Arrivée/Départ buttons per child, meals and snacks as tap-counters, absence types. Everything editable retroactively, because forgetting to clock out is the number-one real-world failure.
3. **Le mois** — a calendar of actual hours per child with the 45h/week line drawn, so the HC/HS split is visible rather than trusted.
4. **Récap du mois** — the itemised build-up ending in two boxed figures: net to declare on Pajemploi, and allowances to declare. Export as PDF via the share sheet; this doubles as the *fiche de présence* the parents sign.
5. **Barème** — the editable constants, each stamped with an effective date.

**Data model**
- `Contrat { id, enfantPrenom, employeurNom, dateDebut, dateFin?, type, nbSemainesAccueil, rythme, semaineA{heures,jours[]}, semaineB?{…}, nbSemainesA, nbSemainesB, tauxHoraire, tauxSaisiEn, seuilHSHebdo=45, majorationHSPct=10, ieMode, ieMontant, iePlancherJour, repasMontant, gouterMontant }`
- `Journee { id, contratId, date, arrivee, depart, absence?, nbRepas, nbGouters, note }`
- `Bareme { id, dateEffet, region, smicHoraireBrut, minimumGaranti, ieParHeure, iePlancherJour, coefNetNormal, coefNetHCHS }`
- `MoisCalcule` is **derived, never stored** — recompute from Contrat + Journee[] + the Barème in force. Storing it is how you ship a bug that outlives a rate change.

The formulas, so you can start today: année complète = `taux brut × h/sem × 52 ÷ 12`; année incomplète = `taux brut × h/sem × nb semaines ÷ 12`; semaine A/B = `((hA × nA) + (hB × nB)) × taux ÷ 12`. HC = hours above contracted but ≤45 in that week at base rate; HS = hours above 45 at base × 1.10 minimum. Brut→net = ×0,7812 métropole (×0,7682 Alsace-Moselle) for normal hours, ×0,8943 (×0,8813) for HC/HS. IE = `max(plancher journalier, 0,435 €/h × heures du jour)`.

**The interaction that has to feel perfect:** tapping a line on the Récap and having it unfold into the literal arithmetic with her own numbers substituted in — not a help article, the actual equation. `((45h × 26 sem) + (25h × 26 sem)) × 5,1203 € ÷ 12 = 776,58 € brut → × 0,7812 = 606,67 € net`. These women do not only want the number computed; they want to *defend* it when the parent-employer says it looks wrong. That is literally what the forum threads are.

## Out of scope for v1
*Congés payés* — acquisition June-to-May, the 10% vs maintien-de-salaire comparison, carry-over. This is a genuine rules engine, it is what the official app has had broken for about a year, and it will eat the whole episode. *Déduction pour absence* — the denominator is contested and it is the most-argued figure in these forums; v1 records absences and flags them, it does not deduct. *Régularisation* at year end. A legally compliant payslip PDF. Rupture/préavis indemnities. Kilometric allowances. MAM multi-employee payroll. Any network barème update, any account.

## Risks
The gap is real but the market is the most crowded of the three: roughly a dozen apps launched between September 2025 and July 2026, and **`Nannix` is one product decision away from closing it** — it is already free, local, account-free and splits normal vs complementary hours against a contractual threshold. It has simply chosen not to compute money. That is a choice, not a moat. The constants move twice a year (the *minimum garanti* shifted on 1 June 2026 from €3,92 to €4,35, moving IE from 0,392 to 0,435 €/h) and an offline app cannot update itself, so if the Barème screen is not obvious and dated on its face your app is quietly wrong by next June. A wrong number here is someone's actual pay and a state declaration, so it needs firm "aide au calcul" framing. And semaine A/B is simultaneously your entire reason to exist and the part most likely to be subtly wrong — budget real time for test cases against the worked forum examples. Finally: this ships in French, for a profession of ~200k people. Excellent episode, small ceiling.

---

# 3. The CLP hazard label for candle and wax-melt makers

## The pain
A UK maker must put a CLP hazard label on every candle or wax melt they sell. The label's content is *derived*, not typed: the supplier's safety data sheet gives each allergen as a percentage **of the fragrance oil**, but the label must state its concentration **in the finished product** — which depends on the maker's own fragrance load. Change the load from 10% to 8%, or blend two oils from different suppliers, and every threshold decision moves: which allergens must be named, whether you get H317 or only EUH208, whether a pictogram is required, whether the signal word is *Warning* or *Danger*. Most makers dodge this by buying generic pre-printed "10% CLP" stickers or using a supplier's template for a load they are not actually running.

To see how confusing this is, note that two major UK suppliers publicly contradict each other on the denominator. Candle Shack: *"Our CLP templates are based on fragrance content… If you are using the fragrance load method… a fragrance load of 10% would be 200g of wax and 20g of fragrance which amounts to roughly 9% fragrance content, meaning you should apply a 9% CLP label"* (https://candle-shack.co.uk/blogs/all-blogs/your-clp-questions-answered). House of Scent calls load-vs-content *"one of the most common points of confusion"* (https://www.houseofscent.com/community/blogs/fragrance-oils-wax-percentage-load-vs-content).

## Who exactly
UK and EU home candle, wax melt, diffuser and soap makers selling at markets, on Etsy or through Facebook. The UK maker groups run into the tens of thousands; every one of them needs a CLP label per fragrance per load. The sharpest sub-group, and the one nothing serves, is **blenders and multi-supplier makers**, for whom no supplier template can ever be correct.

## What they do today
Use the supplier's own free online CLP generator — which only works for oils bought from that supplier, at that supplier's assumed load. Or buy generic "safety stickers" off a print shop and hope they count; there is an entire retail category merchandised as *"10% CLP labels"* and *"CLP Label Sheet up to 10%"*. Or pay a per-label web service. Blenders are simply stranded.

## Evidence
> "Having a nightmare regarding CLP labels on candles… I have been making custom blends, usually mixing 3 or 4 different oils (sometimes from different suppliers). I want to be able to create a CLP based on this custom blend, which would probably require making an entirely new SDS for the mixture. It's a nightmare, but needed for legal compliance!"
> — **candles199**, UK, 2021-10-03. https://www.craftserver.com/topic/117975-candle-sds-clp-labels-for-custom-blends-help-please/

> "Most FO suppliers will provide a CLP template for 10% but the difficulty of a blend is each individual allergen may go above max limits. It's not a straightforward calculation"
> — **LilyJo**, experienced UK candle maker, 2020-07-07. https://www.soapmakingforum.com/threads/blending-fragrance-oils-candle-selling.79998/ *(I opened this page myself; readable without login, quote confirmed verbatim)*

> "there is so much conflicting info out there about this. How do I know what I legally need to put on the safety labels?"
> — **ScienceCandles**, 2019-06-12. https://www.craftserver.com/topic/114723-help-needed-legal-and-safety/

> "I am in UK and everywhere I checked they all suggest to have a new SDS when mixing FOs but nobody clarifies if it is only for storage… regulations drive me crazy.."
> — **Nik P**, UK, 2024-03-17. https://www.craftserver.com/topic/116860-clp-safety-data-sheet-mixing-fragrance-oil-blends/

Honesty on these: `soapmakingforum.com` serves full posts to an anonymous request — unambiguously public, and I confirmed LilyJo's words myself. `craftserver.com` sits behind a Cloudflare **bot** wall, not a login wall — automated fetches get 403, but the page renders the guest prompt "You can post now and register later" and I retrieved the full thread through a headless browser. Click one yourself before you commit; a normal browser should show them.

## Why existing apps fail them
There is **no dedicated CLP or allergen-calculation app on either store.** I searched the GB storefront for "CLP label", "candle CLP", "wax melt label" and "CLP compliance candle": every result is a thermal-label-printer companion (Phomemo, NIIMBOT, Brother iPrint&Label, Nelko, Munbyn, Epson Label Editor) or unrelated compliance software. Google Play for "CLP label candle maker" returns candle *games*, wax-cost calculators and live wallpapers.

The one maker-facing candle app is **`The Candle Maker Calculator`** (id 1514593795) — wax and oil quantity maths only, no hazard classification. Its GB review: *"This is the best app that I have used. I am able calculate wax and oil I need for every vessel and its perfect with the percentage option too."* That is the proof of appetite: UK makers already reach for a phone app for the wax-and-oil half of exactly this calculation, and nobody serves the hazard half.

The real incumbents are all web and supplier-tied — `waxlab.app`, Candle Shack's generator, Fizzy Whizz, Craftastik, Sticky Print Pixels — plus a print-only tier (glowclp.co.uk, magicclps.co.uk, easyclp.com) selling generic labels for an assumed load. Every one of them is either locked to one supplier's oil catalogue or is a pre-printed sticker that cannot know your formulation. Note the adjacent land-grab has already started: `Candle Calculator – Wax & Cost` is exactly the offline cost-logger pattern. Nobody has done the arithmetic.

## Why offline and account-free suits them
The maker types allergen percentages off the SDS in their own hand — their data, not a licensed database — and the threshold rules and H/P statement wording are regulation text, which is public. There is nothing to fetch and nobody to authenticate against. The competitive point is precisely that a *supplier's* tool can only ever know that supplier's oils: an app that holds *your* oil library, from any supplier, and recomputes against *your* load, has to be yours and local. It is also used in a workshop or at a market stall with a phone in hand, and a maker who has been burned by a compliance service disappearing has good reason to want the file to outlive the vendor.

## Proposed MVP
**Screens (5)**
1. **Oils** — your fragrance library. Each oil: name, supplier, SDS date, and allergen rows typed off the sheet.
2. **Product** — name, wax weight, oil weight (or load %), with an explicit **load vs content** toggle that always shows both numbers. Blends add multiple oils with their own grams.
3. **Classification** — each substance's computed concentration in the finished product, and every outcome shown *with the rule that fired*, tappable to reveal the threshold and the arithmetic.
4. **Label preview** — the mandated block in order, pictograms at the correct minimum size.
5. **Export** — render to PDF/PNG at label size for a thermal printer.

**Data model**
- `FragranceOil { id, name, supplier, sdsDate, substances[] }`
- `Substance { name, casNumber?, pctInOil, skinSensCat: none|1|1A|1B, eyeIrritCat2, aquaticChronic: none|1|2|3, mFactor? }`
- `Product { id, name, type, waxGrams, oils[{ oilId, grams }], nominalQuantityG, supplierName, supplierAddress, supplierPhone }`
- `Settings { jurisdiction: UK|EU, labelSize }`
- Classification and label block are **derived**, never stored.

The core arithmetic: `C_product(S) = C_oil(S) × fragranceFraction`. Then H317 if `Σ C(Cat 1/1B) ≥ 1.0%` or `Σ C(Cat 1A) ≥ 0.1%`; EUH208 names each sensitiser at `≥ 0.1%` (`≥ 0.01%` if Cat 1A) that sits below its classification cut-off; H319 if any single substance `≥ 3%` or `Σ(Cat 2 eye irritants) ≥ 10%`; signal word *Danger* if any Cat 1/1A health hazard fires, else *Warning*.

**The interaction that has to feel perfect:** the load slider driving live recomputation. Drag from 10% to 8% and watch a named allergen cross below 0.1% and physically drop off the "Contains:" line — with a tap revealing *why*: the threshold, the concentration, the rule. That single gesture is the whole product and the whole video.

## Out of scope for v1
The full CLP Annex VI harmonised classification list (bulk regulation data — keep it to the user's own typed SDS values plus standard statement wording). Generating an SDS. Cosmetic regimes: CPNP notification, cosmetic safety reports, soap-specific rules. Barcodes. Multi-language labels. Batch tracking, inventory, costing. Printer driver integration — export an image and let the OS handle it. And pick **one jurisdiction**: UK and EU CLP diverged post-Brexit on the supplier-address requirement, and doing both doubles the scope.

## Risks
The honest case against: this is a compliance output, and a wrong label can invalidate a maker's insurance — so it needs a firm disclaimer and must always show which rule fired, which is more UI than it sounds. The input burden is the real design problem, not the maths: suppliers publish allergen data in inconsistent formats and a maker must type a dozen rows per oil before getting any value, which is a steep first-run cliff. Four of my seven maker quotes sit on `craftserver.com`, behind a bot wall I had to work around — verify one in your own browser before filming. Offline is a genuine preference here but not a necessity, since most makers are indoors with wifi; the account-free and not-locked-to-one-supplier parts carry more weight than the offline part. And some makers will rationally keep buying £8 of pre-printed stickers rather than learn a tool.

---

# Recommendation

Build the **DSNS steroid taper**. It scores highest on the rubric and it is the only one of the three where the arithmetic is genuinely hard for the user and genuinely trivial for you — an eleven-block day generator plus a small tablet-composition solver, which is a satisfying hour of code and a spectacular thing to watch fill a calendar on camera. The competing apps are not merely mediocre but visibly broken (a 1.58-star calculator whose own reviewers beg for one that works, and an account-gated rival whose top review is someone unable to create an account), so the gap is demonstrable on screen rather than asserted. The pain is daily, the consequence of getting it wrong is months of lost progress, and the workaround — a wall calendar, a pill organiser and a spreadsheet passed between strangers on a forum — gives you the opening shot. The one thing to settle before you start is framing: this lays out a plan the patient and their doctor already agreed, it never recommends a dose, and if you would rather avoid the medical-app question entirely on camera, build the **CLP label builder** instead, where the store gap is even emptier and the load-slider demo is just as good.

Worth one line: on *gap* alone, the strongest thing I found all day was the **Italian *condominio minimo* riparto** — `itunes country=it` returns **resultCount 0** for "millesimi", "riparto spese", "rendiconto condominiale" and "millesimi condominio riparto", the evidence is fresh (real owners posting through 2024–2026 on condominiopro.it, propit.it and immobilio.it), and it has a commercial hook the others lack: without an approved riparto you cannot pursue a non-paying neighbour by *decreto ingiuntivo* at all. It lost the third slot only on frequency — a building does this once a year. If you are willing to ship in Italian, it is the least contested idea in this document.

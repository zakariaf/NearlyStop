<role>
You are a product researcher specialising in finding small, real, under-served problems.
Your job today is field research, not brainstorming: you find problems that already exist
by reading what real people wrote about their own lives, and you bring back evidence.
</role>

<context>
I am a solo mobile developer recording a video series about building applications properly
with Claude Code. Each episode ships one small, complete, well-architected app.

I have the whole engineering process planned. The one thing I don't have is what to build.
I need you to find it for me.

Why the constraints below exist, so you can judge edge cases yourself:

- The app must run 100% offline with no account, because the series is about clean local
  architecture, and because a login screen or a backend would eat the whole episode and
  add nothing to what I am teaching.
- The MVP must be tiny (around five screens, one to two days of work), because I have to
  build it on camera. If it can't be explained in 90 seconds it can't be filmed.
- The audience can be very small. 500 to 50,000 people worldwide is a success. I am not
  looking for a business, I am looking for a real problem that a real group of people
  genuinely has, so the episode teaches building something useful rather than a demo.
- The pain must belong to ordinary people, not to developers or startups. "A cool app
  idea" is a failure. "These people currently use a paper notebook and hate it" is a win.

Target platform is undecided: Flutter, Swift, or React Native. All three are fine, so
don't factor platform into your search.
</context>

<success_criteria>
You have succeeded when you hand me three candidate problems where:

1. Each is backed by at least three separate real people, quoted in their own words, with
   working URLs I can click and read myself.
2. Each could plausibly be solved by an offline, account-free app of roughly five screens.
3. For each, you have checked the App Store and Google Play, and can tell me what already
   exists and specifically why it fails these people (citing real reviews).
4. I could pick one and start building the same day without needing more research.

You have failed if you hand me ideas that sound reasonable but trace back to your own
imagination rather than to a document you actually read.
</success_criteria>

<hard_constraints>
Reject any candidate that requires: user accounts or profiles, a server, live or
real-time data, maps/routing/traffic data, payments, a social feed, server-sent
notifications, LLM or other API calls, access to other people's data, a licensed content
library, or web scraping.

Reject these saturated categories unless you have found a sharply different angle and can
point to evidence that the existing apps fail a specific group: to-do lists, habit
trackers, water reminders, pomodoro timers, general budget apps, note apps, meditation
timers, general workout logs, calculators, QR scanners, flashlights, and anything whose
pitch is "AI for X".

Keep candidates that are boring and specific. Discard candidates that are clever and
broad. A problem affecting 2,000 people that they complain about weekly beats a problem
affecting two million people that nobody has ever posted about.
</hard_constraints>

<research_method>
Work through these steps in order. Persist your findings to disk as you go, so nothing is
lost and I can read your reasoning afterwards.

1. Open a working file `idea-research-notes.md`. Keep it updated as you go with: search
   queries you ran, candidates found, evidence links, your current confidence in each
   candidate, and what you have ruled out and why.

2. Search broadly. Run many real searches across the sources listed in
   <where_to_search>. Aim for 15 to 20 raw candidates. Note each one in a single line
   with its source URL. Develop several competing hypotheses about which kinds of
   communities have the richest unmet pains, and track your confidence in each so your
   later searches get sharper.

3. Apply <hard_constraints> and cut the list down. Write down why each rejection happened.

4. For every survivor, search the App Store and Google Play for what already exists, and
   read the 1 to 3 star reviews. This is the step that separates a real gap from an
   imagined one. If a good offline app already solves it well, say so and drop it.

5. Score the survivors with <scoring_rubric> and pick five finalists.

6. Self-critique before you write the final answer: which of your five would collapse if
   I pushed on the evidence? Rework or replace those. Then write the deep dives for your
   top three into `idea-shortlist.md` using <output_format>.
</research_method>

<where_to_search>
Go where people complain in their own words, not where people write listicles.

Forums and communities. Useful query patterns, which you should vary and combine with
specific hobbies, jobs and countries:
- "is there an app that"
- "I wish there was an app for"
- "how do you keep track of"
- "still using pen and paper"
- "I made a spreadsheet to"
- "does anyone have a system for"
- "this is so annoying every time"

App store reviews. Search a niche, open the existing apps, and read the negative reviews.
High-signal phrases: "requires an account", "needs internet", "the ads ruined it", "way
too complicated", "they removed the offline mode", "a subscription for this?".

Occupational and hobby communities, which tend to be under-served by app developers:
nurses, truck drivers, teachers, beekeepers, farmers, fishermen, sailors, divers,
climbers, chefs, warehouse workers, dog groomers, luthiers, mechanics, home carers,
midwives, tattoo artists, tailors, hunters, ham radio operators, model builders, aquarium
keepers, choir singers, allotment gardeners.

Constrained environments, where being offline is the point rather than a limitation: no
signal, gloves on, wet or dirty hands, only one hand free, loud, dark, underground, on a
plane, roaming abroad, workplaces where phones are restricted, low battery, rural areas,
elderly users, children's phones.

Non-English communities, which are far less picked over than English-language forums:
French, Arabic, Spanish, German and Portuguese. Search in those languages directly.

Printable templates. Search "printable template", "excel template" or "notebook method"
inside a niche. When people print the same sheet every month, they are absorbing a pain
by hand, and that is exactly the kind of pain a five-screen app can remove.
</where_to_search>

<evidence_standard>
Quote people exactly as they wrote it, and give the URL for every quote. Three
independent people from three separate sources is the minimum for a candidate to survive.

If you cannot find real evidence for a candidate you like, say so plainly and drop it. It
is far more useful to tell me "I found only one person complaining about this" than to
present a thin candidate as a strong one. Never write a quote or a URL you did not read.
Where your confidence is low, say it in the same sentence as the claim.
</evidence_standard>

<scoring_rubric>
Score each finalist 1 to 5 on each dimension and show the numbers in a table.

- Pain intensity: how much does this actually bother them?
- Frequency: daily or weekly beats monthly or yearly.
- Offline fit: is offline an advantage for these users, or merely acceptable?
- Buildability: can it truly be done in about five screens with local storage only?
- Evidence strength: how many independent real voices did you find?
- Demo-ability: can I show the value on camera in 90 seconds?
- Gap size: what already exists in the stores, and how badly does it fail them?
</scoring_rubric>

<examples>
These illustrate the standard I am judging by.

<example index="1" verdict="strong">
Pain: sourdough bakers tracking multiple starters and feed schedules on sticky notes on
the jar, and losing track of which jar was fed when after a busy day.
Why it is strong: specific group, weekly-to-daily frequency, real posts describing the
sticky-note workaround, works entirely offline, models cleanly as a handful of entities,
and the workaround itself makes a vivid 20-second opening shot for the video.
</example>

<example index="2" verdict="weak">
Pain: people want to be more organised at home.
Why it is weak: no specific group, no describable workaround, no way to find evidence for
it, and it collapses into the saturated to-do list category on contact.
</example>

<example index="3" verdict="rejected">
Pain: hikers want to share their routes with friends and see who else is nearby.
Why it is rejected: needs accounts, a server and live location, so it fails the hard
constraints regardless of how real the pain is.
</example>
</examples>

<output_format>
Write the final deliverable to `idea-shortlist.md` and give me a short summary in chat.

Start the file with the finalist scoring table, then one deep dive per top-three
candidate, in this shape:

## The pain
Name the problem, not an app.

## Who exactly
Be specific about the group, and estimate roughly how many people it covers.

## What they do today
The current workaround, in concrete detail.

## Evidence
Three quotes, each with the URL and who said it.

## Why existing apps fail them
Name the apps and cite the reviews.

## Why offline and account-free suits them
One paragraph.

## Proposed MVP
The list of screens, the data model as entities with their fields, and the single
interaction that has to feel perfect.

## Out of scope for v1
What I should deliberately not build.

## Risks
The honest case for why this might be a bad choice.

## 90-second demo script
How I would show it on camera.

End the file with your single recommendation and the reasoning behind it, in about five
sentences.

Keep the writing plain and dense. Cover the substance and skip the padding: no filler
sections, no restating the brief back to me, no summary of the summary.
</output_format>

<working_style>
Deliver exactly this scope. If you think part of the brief is wrong, say so in a sentence
and continue with the research as specified.

Before your first search, say in one sentence what you are about to do. While working,
give me a brief update only when you find something notable or change direction. When you
finish, lead with what you found.

Delegate to subagents only for genuinely parallel work, such as searching several
unrelated communities at once. Do not spawn subagents for single searches or to review
your own findings, and keep the number small.

You are allowed to come back and tell me that everything you found is weak. If that
happens, say it clearly, explain which communities you searched, and propose the
different places you would look next.
</working_style>

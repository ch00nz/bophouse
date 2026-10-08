# Bop House Simulator — Game Design Document

**Version:** 0.1 (pre-production)  
**Genre:** Adult-themed idle tycoon / management and life simulation  
**Engine:** Godot 4, GDScript  
**Platforms:** Browser prototype → Windows/Steam → possible Android/iOS  
**Visual direction:** Colourful, expressive 2D cartoon cutaway house, inspired by *Fallout Shelter* and *Game Dev Tycoon*  
**Audience:** Adults 18+

> **Development note:** This is the long-term product vision, not the specification for the first coding milestone. Implement the initial vertical slice only, and expand in small, testable iterations.

## 1. Premise and vision

The player manages a growing house of adult female social-media and subscription-content creators. Starting with one creator and a modest house, the player earns money through content production, subscriptions, tips and sponsorships, then invests in rooms, equipment, recruitment and business growth.

Creators are autonomous people with distinct traits, abilities, ambitions, relationships, health and personal boundaries. Rotating trends change the economics of content categories. Unexpected but logically triggered events — from viral success to household disputes, controlling relationships or health interruptions — create emergent stories and difficult management choices.

The tone is satirical, cheeky, humorous and sometimes dramatic. The content is **suggestive rather than sexually explicit**. On-screen activity can include glamorous outfits, swimwear and lingerie; optional topless art is the proposed upper visual limit. Sexual acts are not depicted. Content production can be represented through room activity, icons, income reports and off-screen implications. All characters depicted in romantic or adult-industry contexts are unambiguously **18 or older**.

### Design pillars

1. **A living house:** Residents visibly walk, work, rest, socialise and react in a side-on, multiroom environment.
2. **Idle progression:** Revenue and audience growth continue without constant clicking, including capped offline progression.
3. **Distinct, autonomous creators:** Their traits, boundaries, preferences and ambitions matter mechanically.
4. **Shifting trends:** No creator or content type is always optimal.
5. **Persistent consequences:** Events can develop through connected storylines, not just isolated popups.
6. **Meaningful decisions:** Investments, schedules, recruitment, room upgrades and responses to events create trade-offs.
7. **Visual progression:** House upgrades, furnishings and character styling visibly change the world.

## 2. Core gameplay loop

**Recruit → Assign opportunities and activities → Publish content → Grow followers/subscribers → Earn revenue → Upgrade house and equipment → Manage consequences → Expand.**

The player starts with a single creator, a modest house, a bedroom and a basic content studio. The first progression milestones could include earning $1,000, reaching 10,000 followers, unlocking subscriptions, recruiting another creator and purchasing room upgrades. Later goals include five residents, a luxury mansion and one million combined followers. All milestones are provisional and subject to balancing.

## 3. Creator data and behaviour

### Core stats (0–100)

| Stat | Main influence |
|---|---|
| Looks | Broad visual appeal to relevant audience segments |
| Wildness | Impulsive choices, attention-grabbing opportunities and chaos |
| Adaptability | Ability to benefit from shifting trends |
| Charisma | Engagement, livestream tips, retention, chemistry |
| Work Ethic | Frequency and reliability of content production |
| Stamina | Work capacity, fatigue and recovery |
| Confidence | Response to setbacks, social situations and performance |
| Drama | Propensity for gossip, disputes and public controversies |

Other creator properties: name, age (18+), portraits/sprites, appearance tags, personality traits, preferences and hard boundaries, ambitions, mood, energy, health/wellbeing, personal finances, followers, paying subscribers, reputation, activity, friendships, trust, rivalries and collaboration compatibility.

### Example traits

Party Animal, Girl Next Door, Drama Queen, Fitness Fanatic, Ambitious Hustler, Social Butterfly, Hopeless Romantic, Perfectionist, Luxury Obsessed, Business Savvy, Shy, Loyal Friend, Unreliable, Natural Beauty and Bombshell.

### Autonomy and boundaries

The player manages house facilities, business opportunities, contracts and proposed schedules; creators can accept, reject or renegotiate opportunities. Personal content boundaries, relationships and medical decisions are never overridden by player spending or upgrades. A creator who only wants solo work must be able to remain commercially successful.

### World behaviour

Residents choose activities (rest, walk, work, socialise, exercise) according to needs, schedules, room availability and preferences. Use simple state-machine behaviour for the prototype; deeper needs and relationships can be layered in later. Give creators visually readable activity states.

## 4. Content production and revenue

### Content categories

- Mainstream social media and influencer content
- Glamour / modelling
- Solo subscription content
- Premium topless sets (non-explicit presentation)
- Boy/girl collaborations (implied/off-screen)
- Girl/girl collaborations (implied/off-screen)
- Couples content (implied/off-screen)
- Livestreaming and subscriber engagement
- Niche/fetish-themed content (non-explicit presentation)
- Custom subscriber requests within creator-defined boundaries

Each category has equipment/room needs, an audience segment, production demands, potential revenue and creator eligibility rules. Higher-intensity content should **not** inherently yield better returns.

### Income streams

Subscriptions, tips, premium content, mainstream platform monetisation, sponsorships, collaborations and eventually merchandise.

### Proposed income model

`Expected revenue = audience × conversion rate × average revenue per paying fan × content fit × trend modifier × quality modifier × productivity modifier`

Account for diminishing returns, costs, subscriber churn, audience overlap and follower-to-subscriber conversion. Do not confuse total followers with paying subscribers.

### Resources

- **Cash:** Spending and cashflow.
- **Followers:** Reach and discovery potential.
- **Subscribers:** Recurring paying audience.
- **Hype:** Short-lived publicity multiplier.
- **House reputation:** Long-term recruiting and sponsor credibility.

Ongoing costs can include rent/mortgage, utilities, creator compensation/revenue share, equipment maintenance and staff.

## 5. Dynamic trends

Trends rotate each in-game week (timing configurable), sometimes overlapping. Each trend specifies a duration, strength, applicable audience, matching appearance tags, relevant stats, supported content categories, room bonuses and special event hooks.

Illustrative trends: Gym Girl Summer, Natural Beauty Era, Bombshell Craze, MILF Mania, Pregnancy Lifestyle Wave, Luxury Influencer, Collaboration Boom, Gamer Girl Surge, Cosplay Craze, Reality TV Drama, Wholesome Lifestyle, Poolside Glamour, Couples Content Wave.

High adaptability helps a creator pivot successfully. Some rare creator events can originate a new local trend. For early development, all trends are fictional and bundled locally rather than scraped from current platforms.

## 6. Cosmetic and appearance system

Potential creator-initiated appearance changes include breast augmentation, Brazilian butt lift (BBL), lip fillers, rhinoplasty, cosmetic dentistry, hairstyle/makeup, and gradual fitness changes. The player can offer funding or resources where appropriate, but cannot force a procedure.

Procedures or makeovers can affect sprite/portrait appearance, audience niche fit, confidence, costs, downtime and complications. No procedure is a guaranteed attractiveness or income upgrade. Natural looks and enhanced looks can each have viable market segments.

The art pipeline should eventually support interchangeable body, hairstyle, clothing and accessory layers or controlled sprite variants; do not try to generate every permutation for the prototype.

## 7. House and rooms

Show a side-on cutaway building with clickable rooms and visible characters. Characters travel between rooms and perform simple loops. Rooms include capacity, upgrade level, visual variant, supported activities, efficiency bonuses and costs.

### Potential room types

| Room | Function |
|---|---|
| Bedroom | Rest, mood and personal interactions |
| Content studio | Solo shoots, portraits and premium content production |
| Living room | Social events, rest and relationships |
| Glam room | Styling and appearance-related opportunities |
| Collaboration studio | Multi-creator content when all involved agree |
| Livestream room | Streams, tips and live audience engagement |
| Gym | Fitness, wellness and trend alignment |
| Pool / hot tub | Lifestyle content and social gatherings |
| Office | Sponsorships, admin and financial management |
| Kitchen | Lifestyle content, health and social interactions |
| Podcast room | Commentary, interviews and gossip |
| Editing suite | Content quality / throughput improvements |
| Family accommodation | Optional later-life or family storylines |

**Prototype house:** bedroom, living room and content studio only. Use clear placeholder room graphics and clickable upgrade controls. Add rooms later through data rather than special-case coding.

## 8. Relationships

Track pairwise friendship, trust, rivalry and collaboration chemistry. Co-location, shared activities and events gradually modify relationships. Strong friendships can make collaboration easier and provide emotional support; rivalry can cause conflict or publicity; poor compatibility may block otherwise profitable plans. These are gameplay relationships, not a justification for removing consent.

## 9. Events and ongoing storylines

Events are selected through **weighted eligibility rules** informed by personality, mood, current circumstances, relationships, traits and world state. Some events resolve immediately; others introduce persistent flags or multi-stage arcs. Avoid purely random catastrophic outcomes and long stretches of uncontrollable punishment.

### Event categories and examples

**Career:** viral post, sponsor proposal, suspension, leaked messages, competitor poaching, TV offer, fanbase shift, content ownership dispute, surprising subscriber growth.

**Relationships:** new romance, jealousy, breakup, housemate feud, unexpected friendship, controlling partner, partner interfering with work, creator voluntarily leaving, support from housemates.

**Health and wellbeing:** STI diagnosis, treatment/recovery time, fatigue, burnout, general illness, surgery complication, wellbeing improvements. These should be presented sensitively and medically plausibly. Do not automatically assign STI events based on sexual orientation, content category or perceived promiscuity; do not automatically make private health information public or apply reputational penalties.

**Life changes:** pregnancy, changing goals, maternity leave, family/lifestyle sponsorship opportunities, new responsibilities, independent living, career transition.

**Household:** loud party, broken equipment, missing property, property damage, argument over room use, surprise visit, house scandal.

**Financial:** surprise expense, tax or contract difficulty, maintenance bill, favourable partnership, bad investment.

### Illustrative multi-stage controlling relationship arc

1. A creator starts a new relationship on her own initiative.
2. Over time the partner may become more demanding or attempt to interfere with work and friendships.
3. Scheduling conflicts, changes in mood and isolation can become visible.
4. The house can offer practical support or flexibility; the creator makes her own decisions.
5. Possible outcomes include setting boundaries, getting support, ending the relationship, changing work arrangements or voluntarily moving out.

Never frame coercion as an ideal path to profits or allow the player to control a creator's private relationship.

### Illustrative health arc

A creator privately reports an STI diagnosis and may independently choose time off or adjustments to activities. Some costs or workload changes can arise; successful support and recovery may return her to normal. Exact health timelines should not be presented as medical advice; keep the mechanics abstract. Confidentiality matters.

### Illustrative pregnancy/family arc

Pregnancy may alter activity preferences, timing and priorities, and open family/lifestyle audience opportunities. It should not simply act as a flat penalty, automatically follow from a Wildness stat, or dictate that the creator must follow one career route. Family-related events are part of autonomous character storylines.

### Event data schema (conceptual)

- ID and category
- Title, description and optional illustration
- Eligible states and conditions
- Weight and cooldown
- Affected characters / rooms
- Player response options
- Immediate effect definitions
- Deferred effect definitions
- Follow-up event IDs and story flags

Major unresolved events should be queued during offline time rather than silently concluding.

## 10. Idle progression and game time

Support accelerated in-game time and configurable day/week duration. While running, process earnings, costs, activity and follower growth in stable simulation ticks. On reopening a saved game, calculate elapsed time and simulate bounded earnings, costs and recovery. Use a reasonable offline cap initially and prevent duplicate credit from clock manipulation. Do not resolve major irreversible story events offline.

Save with a versioned format containing game time, resources, rooms, residents, relationships, active trends, queued events, temporary modifiers and the last real-world save timestamp. Provide autosave and manual save. For browser builds, support a reliable local save strategy and consider export/import backups.

## 11. Art and UX

### Visual style

Colourful, polished cartoon graphics; bold readable silhouettes; clear outlines; expressive faces; coherent lighting and proportions. Avoid photorealism and avoid highly detailed animation. On-screen production should be conveyed through cameras, lights, devices, poses, icons, speech bubbles and room statuses.

### Initial animation list

Idle, walk, film, livestream, socialise, rest, celebrate and argue. Start with only idle, walk and film in the vertical slice.

### Core UI

- Top bar: cash, followers, subscribers, hype and time
- House view with camera pan/zoom when needed
- Character profile: portrait, stats, current job, energy, earnings, accepted work categories
- Room panel: level, current usage, available actions, upgrade price
- Trend panel: active trends and countdowns
- Event modal / journal: narrative choices and outcomes
- Income overview: rates and sources

The interface should be mouse-first initially but adaptable to touchscreens. Keep minimum interactive target sizes in mind and avoid layouts that depend on hover.

### AI art workflow

Start with placeholders. Later establish a short style bible: line weight, proportions, colour palette, camera/view angle, sprite dimensions, lighting and export rules. Generate coherent character turnarounds, clothing/body variants, furniture and room layers. Correct transparency/alignment and animation consistency using a sprite editor before importing. Keep source artwork and licenses documented.

## 12. Technical architecture

**Use Godot 4 and GDScript**, not C#, so the game can be exported to the web. Simulation systems must be testable without rendering and independent from visual nodes.

Suggested systems (names provisional):

- `GameManager` — overall state and progression
- `TimeManager` — clock, ticks, offline progression
- `EconomyManager` — income, costs and audience economics
- `CreatorManager` — recruitment, traits, needs, activity selection
- `TrendManager` — active modifiers and rotation
- `RoomManager` — room state, capacity, upgrades and assignments
- `RelationshipManager` — pairwise compatibility and social changes
- `EventManager` — eligibility, random selection, chains and decisions
- `SaveManager` — persistence, migrations and backups
- `HouseView` / UI controllers — rendering and input

Store creator templates, trait definitions, room types, upgrades, trends, event scripts and tuning parameters in Godot Resources or JSON. Prefer deterministic calculations with injectable random seeds for repeatable tests. Avoid circular dependencies and tightly coupled UI/business logic. Use Git from the beginning.

### Quality bar

- Project launches without scene/script errors.
- Web export can be tested in a browser.
- Core economy and time calculations have automated checks.
- Save/load round trips preserve state.
- Visual placeholders can be replaced without refactoring gameplay.
- Balance constants are configurable.
- New creators/rooms can be added as data.

## 13. MVP and phased roadmap

### Phase 1 — First playable vertical slice (BUILD THIS FIRST)

1. New Godot 4 GDScript project with clean folder structure.
2. Three-room side-on house: bedroom, living room, studio.
3. One visibly adult placeholder creator who moves between rooms.
4. Simple idle, walk and working states.
5. Accelerated game time.
6. Passive cash and follower growth, with visible counters.
7. Clickable creator profile with basic stats and activity.
8. Clickable room and one functional upgrade per room.
9. Local autosave plus bounded offline earnings.
10. Basic economic and save/load tests; runnable web export.

**Definition of done:** Player can launch the game, see a creator move/work, watch resources increase, buy a meaningful room upgrade, close and reopen without losing progress, and test in a browser.

### Phase 2 — Functional management game

Add two recruitable creators, individual preferences/boundaries, a few content types, subscriber conversion/churn, five rotating trends, room activity choices and a basic income breakdown.

### Phase 3 — Emergent drama

Add ten to fifteen events, a small relationship model, one multi-stage relationship storyline, one health storyline, character-specific ambitions and an event journal.

### Phase 4 — Appearance and expansion

Add selectable cosmetic appearance changes, treatment/recovery downtime where appropriate, multiple outfits/body variants, more rooms, additional storylines, balancing and better visuals.

### Phase 5 — Commercial polish

Final art pipeline, sound, onboarding, accessibility, performance, save migration, achievements, Steam integration, content declarations, adult-content compliance and store presentation.

## 14. Product and publishing considerations

Before any commercial release, verify current platform rules governing adult-themed artwork, topless content, age-gating, AI-generated assets, disclosure and regional distribution. Do not assume a browser prototype and a Steam version have identical compliance requirements. Avoid using real influencers' identities, likenesses or branding without permission. Use fictional platform branding instead of copying protected logos or trade dress.

## 15. Guidance for Claude Code

1. Read this document as a **vision/specification**, not a request to code every system at once.
2. First propose architecture, directories, implementation milestones and risks.
3. Implement **Phase 1 only** in small tested steps.
4. Use simple placeholders and a visually understandable house view.
5. Keep every early system expandable through configuration and modular data.
6. Explicitly identify anything unimplemented instead of pretending it exists.
7. Test the Godot project and web build where tooling permits; explain any tests that cannot be run.
8. Do not add sophisticated events, surgeries, pregnancy or complicated adult-content systems before the basic management loop is fun and reliable.

SECTION 40 — BALANCE & SCALING FRAMEWORK

This section defines how Shops & Shadows scales difficulty, rewards, and power across:

Regions

Dungeons

Heroes

Items

Facilities

Post-campaign cycles

The goal is to ensure the game remains:

Challenging but fair

Predictable but flexible

Resistant to runaway power

Tunable via data, not code rewrites

40.1 Balance Design Philosophy

Horizontal Progression Over Vertical Spikes

Power grows through options, not raw numbers

Synergy matters more than stat inflation

Risk-Based Power

High power requires risk (refinement, death, resource loss)

Safe play yields stability, not dominance

Region-Gated Difficulty

Difficulty increases by region, not endlessly per dungeon

Regions act as clear balance brackets

40.2 Core Scaling Axes

All balance scaling operates on four primary axes:

A. Region Index

Primary difficulty driver

Controls:

Enemy stats

AI tier

Status complexity

Reward ceilings

B. Dungeon Floor

Controls encounter density

Introduces stronger enemy compositions

Slightly increases rewards per floor

C. Facility Tier

Increases player options, not raw stats

Enables higher-quality items and systems

D. Post-Campaign Cycle

Reuses same systems with higher pressure

No new currencies introduced

40.3 Hero Power Scaling
Hero Strength Comes From:

Class abilities

Weapon abilities

Status synergy

Positioning

Item quality (not quantity)

Explicit Non-Scaling Factors

No exponential stat growth

No infinite level scaling

No multiplicative stacking beyond defined limits

40.4 Enemy Scaling Rules

Enemies scale by region, not by time spent farming.

Enemy scaling increases:

Max HP

Damage

Ability access

AI tier

Resistance to stacking effects

Enemy scaling does NOT:

Increase endlessly

Ignore player systems

Require grind to overcome

40.5 Item Power Ceilings

Item strength is bounded by:

Quality tier

Affix caps

Refinement risk

Rules

Refinement above safe tiers introduces break chance

Perfect items are possible but rare

Legendary items are strong but not mandatory

40.6 Refinement Risk Curve

Refinement tiers are grouped:

Tier Range	Risk
+1 to +4	Safe
+5 to +8	Increasing negative effects
+9 to +10	High break chance
Design Intent

Early refinement feels rewarding

Mid refinement feels risky

Late refinement is a gamble

40.7 Facility Scaling Impact

Facilities scale option space, not raw power.

Examples:

More shop slots

Higher quality floors

Access to blueprints

Refinement systems

Facilities never trivialize combat alone.

40.8 Gold & Economy Scaling

Gold scaling rules:

Early regions: tight but forgiving

Mid regions: stable with planning

Late regions: pressure returns

Gold sinks scale faster than sources to prevent hoarding dominance.

40.9 Defense Scaling

Town defense difficulty scales by:

Region progression

Number of towns owned

Campaign phase

Defense remains:

Non-lethal to heroes

A training and income system

A maintenance pressure, not a punishment

40.10 Region Boss Scaling

Region bosses:

Use fixed stat brackets per region

Do not scale infinitely

Remain dangerous due to mechanics, not numbers

Repeat kills reward:

Normalized loot chances

No guaranteed legendary after first clear

40.11 Status Effect Scaling

Status scaling is bounded by:

Stack caps

Countdown limits

Boss resistances

Higher regions:

Introduce more countdown effects

Reduce effectiveness of low-tier status spam

40.12 Post-Campaign Scaling

Post-campaign cycles:

Increase enemy pressure

Increase material requirements

Increase refinement risk relevance

No new systems introduced.

40.13 Anti-Exploitation Rules

To prevent degenerate strategies:

No infinite loops

No passive-only wins

No zero-risk farming

All powerful strategies require exposure to loss.

40.14 Balance Data Ownership

All scaling values are:

Data-driven

Editable via tables

Not hardcoded

Claude should:

Implement systems with tunable values

Avoid baking numbers into logic

SECTION 40 — BALANCE & SCALING FRAMEWORK

This section defines how Shops & Shadows scales difficulty, rewards, and power across:

Regions

Dungeons

Heroes

Items

Facilities

Post-campaign cycles

The goal is to ensure the game remains:

Challenging but fair

Predictable but flexible

Resistant to runaway power

Tunable via data, not code rewrites

40.1 Balance Design Philosophy

Horizontal Progression Over Vertical Spikes

Power grows through options, not raw numbers

Synergy matters more than stat inflation

Risk-Based Power

High power requires risk (refinement, death, resource loss)

Safe play yields stability, not dominance

Region-Gated Difficulty

Difficulty increases by region, not endlessly per dungeon

Regions act as clear balance brackets

40.2 Core Scaling Axes

All balance scaling operates on four primary axes:

A. Region Index

Primary difficulty driver

Controls:

Enemy stats

AI tier

Status complexity

Reward ceilings

B. Dungeon Floor

Controls encounter density

Introduces stronger enemy compositions

Slightly increases rewards per floor

C. Facility Tier

Increases player options, not raw stats

Enables higher-quality items and systems

D. Post-Campaign Cycle

Reuses same systems with higher pressure

No new currencies introduced

40.3 Hero Power Scaling
Hero Strength Comes From:

Class abilities

Weapon abilities

Status synergy

Positioning

Item quality (not quantity)

Explicit Non-Scaling Factors

No exponential stat growth

No infinite level scaling

No multiplicative stacking beyond defined limits

40.4 Enemy Scaling Rules

Enemies scale by region, not by time spent farming.

Enemy scaling increases:

Max HP

Damage

Ability access

AI tier

Resistance to stacking effects

Enemy scaling does NOT:

Increase endlessly

Ignore player systems

Require grind to overcome

40.5 Item Power Ceilings

Item strength is bounded by:

Quality tier

Affix caps

Refinement risk

Rules

Refinement above safe tiers introduces break chance

Perfect items are possible but rare

Legendary items are strong but not mandatory

40.6 Refinement Risk Curve

Refinement tiers are grouped:

Tier Range	Risk
+1 to +4	Safe
+5 to +8	Increasing negative effects
+9 to +10	High break chance
Design Intent

Early refinement feels rewarding

Mid refinement feels risky

Late refinement is a gamble

40.7 Facility Scaling Impact

Facilities scale option space, not raw power.

Examples:

More shop slots

Higher quality floors

Access to blueprints

Refinement systems

Facilities never trivialize combat alone.

40.8 Gold & Economy Scaling

Gold scaling rules:

Early regions: tight but forgiving

Mid regions: stable with planning

Late regions: pressure returns

Gold sinks scale faster than sources to prevent hoarding dominance.

40.9 Defense Scaling

Town defense difficulty scales by:

Region progression

Number of towns owned

Campaign phase

Defense remains:

Non-lethal to heroes

A training and income system

A maintenance pressure, not a punishment

40.10 Region Boss Scaling

Region bosses:

Use fixed stat brackets per region

Do not scale infinitely

Remain dangerous due to mechanics, not numbers

Repeat kills reward:

Normalized loot chances

No guaranteed legendary after first clear

40.11 Status Effect Scaling

Status scaling is bounded by:

Stack caps

Countdown limits

Boss resistances

Higher regions:

Introduce more countdown effects

Reduce effectiveness of low-tier status spam

40.12 Post-Campaign Scaling

Post-campaign cycles:

Increase enemy pressure

Increase material requirements

Increase refinement risk relevance

No new systems introduced.

40.13 Anti-Exploitation Rules

To prevent degenerate strategies:

No infinite loops

No passive-only wins

No zero-risk farming

All powerful strategies require exposure to loss.

40.14 Balance Data Ownership

All scaling values are:

Data-driven

Editable via tables

Not hardcoded

Claude should:

Implement systems with tunable values

Avoid baking numbers into logic
30. Audio Design & Feedback Rules
30.1 Audio Design Philosophy

Audio in Shops & Shadows exists to:

Reinforce clarity and intent

Provide immediate feedback for player actions

Support atmosphere without overwhelming the player

Audio must never:

Obscure gameplay information

Replace visual clarity

Become fatiguing during long play sessions

Audio is supportive, not dominant.

30.2 Global Audio Rules

Across the entire game:

Every meaningful action has audio feedback

No audio cue should be the only indicator of information

Volume balance favors:

Combat-critical sounds

UI confirmation sounds

Ambient audio

Music

Audio settings must be adjustable independently.

30.3 Combat Audio
30.3.1 Basic Combat Sounds

Attacks:

Light, medium, heavy variants

Impacts:

Hit

Block

Miss

Death:

Short, clear, non-dramatic

No overly long combat sounds.

30.3.2 Ability Audio

Every ability has:

Cast sound

Impact or resolution sound

Ability audio must:

Match element/type (fire, void, crystal, etc.)

Be distinct from basic attacks

Cooldown completion may have a subtle audio cue (optional, toggleable)

No global “ability spam” effects.

30.4 Status Effect Audio

Status effects use lightweight, non-repeating cues.

Application

Single short sound on application

No looping sounds per unit

Countdown Effects

Subtle tick when countdown decreases

Clear cue when countdown reaches 0

No constant ticking sounds.

30.5 Weapon Audio Identity

Weapon types have thematic audio identity.

Examples:

Swords: clean metallic strikes

Hammers: heavy impact with low-frequency emphasis

Bows: snap + release

Staves: tonal hum or pulse

Higher-tier weapons may add layered sound detail, not louder volume.

30.6 Enemy & Boss Audio
Standard Enemies

Short attack and death sounds

Minimal vocalization

Avoid audio clutter in group fights

Bosses

Clear audio telegraphs for:

Phase changes

Major abilities

Boss audio must:

Be readable

Never mislead

Never mask UI sounds

Boss audio escalates tension but stays controlled.

30.7 Town & Facility Audio
Town Ambience

Soft looping ambience per region

Minimal NPC chatter

Subtle environmental sounds

Facilities

Each facility has:

One ambient loop

One interaction sound

Upgraded facilities may slightly enrich audio texture

No production “machinery noise spam”.

30.8 Shop & UI Audio
UI Interaction Sounds

Confirm

Cancel

Error / unavailable

Purchase success

UI sounds must be:

Short

Soft

Never startling

Shop Audio

Item purchase confirmation

Rarity-based accent (very subtle)

No gacha-style stingers

Legendary items do not use loud or flashy audio.

30.9 Dungeon & Exploration Audio
Dungeon Ambience

Region-specific loops

Light reverb

Minimal melodic content

Room Transitions

Short stinger on:

Floor completion

Boss room entry

Exploration audio should never distract from combat decisions.

30.10 Music System Rules
Music Layers

Town music

Dungeon exploration music

Combat music

Boss music

Music transitions are:

Smooth

Crossfaded

Non-abrupt

Music Priority

Boss music

Combat music

Dungeon ambience

Town ambience

Music pauses or fades during critical UI interactions.

30.11 Dynamic Audio Rules

Dynamic audio may respond to:

Combat intensity

Boss phase changes

Low party health (subtle)

Dynamic changes must:

Never spike volume

Never override player control

30.12 Accessibility & Audio Options

Audio options must include:

Master volume

Music volume

SFX volume

UI volume

Mute toggles

Optional:

Visual alternatives for critical audio cues

Subtitle-like indicators for major events

30.13 Godot / Claude Implementation Notes

Recommended approach:

Audio buses by category

One-shot sound nodes for effects

Looping ambience via controlled audio players

No hardcoded volume values

All audio triggers should be event-driven.
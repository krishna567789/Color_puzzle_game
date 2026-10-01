# Content

Levels, colours, chapters, side-mode ladders, quests, events, achievements, shop
rows and every economy number ship as JSON in `assets/content/`. Code reads that
set; it does not own it.

- **Content is data.** A new level, goal, skin or chapter is a JSON change.
- **Tunables are remote config.** A number in the set may be retuned for a cohort
  without a release.
- **An admin panel is an editor over this same JSON.** It gets no storage of its
  own, because then there would be two authorities and they would disagree.

## The hard rule

> Remote Config may change a NUMBER. It may never introduce an ID.

A value that names a thing — a colour id, a level id, a chapter id, a store
product id, a quest id — only ever arrives with a build. Ids are what the board,
the wallet and the player's own progress refer to; a remote value that invents
one is a reference to something the binary cannot render.

Numbers are safe to remote-tune precisely because nothing points at them: the
coin price of a hint, the levels-per-colour step, an event's goal. The id of the
thing being priced is not.

## Layout

Every document carries the same two-line envelope, so a file can never be
mistaken for a different schema's output:

```json
{ "schemaVersion": 1, "contentVersion": "2026.10.01-1", ... }
```

| Document | Holds |
| --- | --- |
| `manifest.json` | The list of documents, and the version they all share |
| `colors.json` | Palette: id, name, ARGB, and the colourblind mark it wears |
| `chapters.json` | Chapter ids, names, the level each starts at, its art and colours, and the purse it pays |
| `levels/curve.json` | The difficulty numbers the curve runs on, and the biggest board the screen lays out |
| `levels/pack_001.json` … `pack_005.json` | Authored boards, one pack per chapter, with the par each was proved at |
| `modes.json` | The side modes' own ladders: which curve level each stage sits on |
| `quests.json` | The daily tasks a day draws five of |
| `events.json` | The live-ops calendar: goal, metric, cycle length and purse |
| `achievements.json` | Long-term goals, three deep on each counter the game keeps |
| `shop.json` | What exists, what it costs, which store product sells it, and what that purchase hands out |
| `wheel.json` | The spin's wedges: what each one pays, and how many there are |
| `rewards.json` | Coin, XP, streak, spin and power-up tuning |

`contentVersion` is checked against the manifest's for every document, so a
half-pasted content set is refused whole rather than served mixed.

## One validator

`lib/content/content_validator.dart` exposes `validateContent(GameContent,
{assetExists})`. Three callers, one authority:

- `tools/content/generate.dart`, before it writes a pack;
- `test/content_contract_test.dart`, on the files as they ship;
- the admin panel's save endpoint, when there is one.

The checks are split by cost. Structural and cross-reference checks — every id
resolves, no two colours wear the same mark, no board overflows a bottle, every
power-up has a price, a skin has art — run in the app at load. Solver-based
winnability runs in the generator and in CI, never on a launch screen.

Two of them exist because a content edit can otherwise reach a player in a worse
state than a build error:

- **A board has to fit the board.** `levels/curve.json` carries `maxBoardTubes`,
  and an authored level asking for more bottles than that is refused.
- **A paid row has to pay out.** `grantCoins` or `entitlement` says what a
  purchase delivers, and `IapService` reads that row and nothing else. A listing
  with neither is refused, because the alternative is a player who pays money and
  receives nothing.

Art is checked against `AssetManifest.bin` at launch, so a document naming a file
the build never packed is caught as a refusal instead of painted as an exception
box - and a manifest that cannot be read is treated as "cannot check", never as
"bad content".

`ContentRepository` only swaps a set in when it both parses and validates. A
refusal leaves the previous set serving and records the reasons in
`ContentRepository.source.issues`.

## A chapter is a piece of content, not a number

`chapters.json` gives each block of `levelsPerChapter` levels a name, a blurb, a
backdrop image, a tint for the map, an accent for its cards and node ring, a
`rewardCoins`/`rewardGems` purse, and optionally its own `palette`.

The palette is a *shorter shelf*, not a new colour set: chapter one deals only
from six plain hues so the first boards cannot ask a player to tell teal from
cyan, chapter two adds three more, and a chapter that names none deals from the
whole twelve. Rules the validator holds:

- every id has to be a colour that exists, and none may appear twice;
- a chapter must name enough colours to fill its own widest board — naming five
  when `curve.json` asks for six at its last level is a refusal;
- silence is legal and means "the whole palette".

The generator is the only reader of a palette; nothing in the runtime branches on
it. The ids are spelled out rather than taken by position, because
`parseContentDocuments` sorts colours alphabetically by id — a positional read
would silently change which hues a chapter owns whenever a colour was added.

The purse is paid by the level that *closes* the block, once. `GameController`
folds it into the win's payout before it reaches storage, so the end-of-level
dialog quotes the number that was actually granted instead of inventing one.
`StorageService.claimChapter` is what makes a second playthrough of L20 pay the
board and not the chapter, and cloud save merges claims as a union: a chapter
claimed on one phone stays claimed on the others, because merging the other way
would hand the purse out again.

## A side mode is a ladder, not a level number

Challenge and Time Attack used to read the campaign's unlocked level and ride
three levels past it, so they had no map, no end and nothing of their own to
record. `modes.json` gives each one a list of `stages`, and every stage names the
**curve level** it sits on: Challenge stage 4 plays whatever `levels/curve.json`
says level 21 is. A ladder therefore rides the same difficulty maths as the
campaign without needing boards authored for it, and a stage means the same board
on every device whether the player is on campaign level 5 or level 500.

What the validator holds:

- an id has to be one of `kSideModeIds` — the names of `GameController`'s ladder
  modes — and every one of those has to have a ladder, or its map has no stages;
- a ladder has at least `kSideLadderMinStages` stages, and its anchors climb, so
  stage 7 is never easier than stage 6;
- a Challenge anchor stays inside `kSideLadderColorCeiling` colours. Challenge
  sets its move limit to six over the *proved* shortest solution, and past that
  many colours the search never concludes, so the limit would be measured against
  an estimate nobody checked — a board a player can lose without doing anything
  wrong. The ceiling and `GameController.searchableColorCount` are one number a
  test keeps in step.

The records are per stage and filed under `'<modeId>@<stage>'`, which is why a
Time Attack best cannot land on a Challenge stage, and why campaign stars and
ladder stars are separate maps. They only ever move forward, so cloud save (v4)
can hand a whole ladder to a second phone without any risk of taking a stage
back. A ladder ends: the win card drops NEXT on the last stage instead of dealing
the board the player just beat.

Editing a ladder is a content change like any other — regenerate, because the
compiled fallback carries its bytes.

## The other catalogues

Quests, events, achievements and the spin wheel are the same kind of thing as a
level: a number a player works towards, a purse that pays it, and a screen that
reads both. The shop is the same again with prices on it. They ship as documents,
and the validator treats a goal nobody can reach — or a row that sells a picture
nobody packed — as a build error.

### `quests.json` — fifteen tasks, five a day

The catalogue is deliberately three times the slate. `QuestCatalog.forDay` draws
`kDailyQuestCount` of them seeded from the day's own key (FNV-1a over the date
digits, not `String.hashCode`, which is free to change between runs), so every
device shows the same five on the same date and restarting the app cannot reroll
a task already finished. Ties break by id for the same reason.

Two rules make the draw worth having: at most `kDailyQuestsPerStat` cards from one
counter, or a day can be five flavours of "win more"; and progress is read from
today's counters rather than tracked per quest, so a day nobody played starts at
zero instead of leaving half-finished tasks behind.

A task's `stat` has to be one of `DailyStat.known`, and its `target` has to be
something a day can actually reach — `DailyStat.dailyCeilings` is where that is
written down.

### `events.json` — a calendar of windows

Each event names a metric, a goal, how long its run lasts and how much of that
cycle it stays open. The doc spells the metric as the enum's name
(`levelsWon`, `starsEarned`, `perfectWins`) while `EventMetric.storageKey` stays
snake_case, so renaming a doc value can never orphan progress already banked
under the old one.

Progress is stored per window, keyed by the run's start date, which is why a
season rollover needs no reset code: the new run reads a key nobody has written
to. `EventService.claim` pays from what storage says rather than from the card
that was tapped, so a screen left open across a rollover cannot collect the run
that just closed.

### `achievements.json` — three cards per counter the game actually keeps

Ten counters, three goals each. Every one is something `AchievementService` can
read today; nothing was invented for a card, and no new storage key was added for
one either.

The interesting check is the ceiling. `AchievementStat.ceilingOf(content)` works
out, from the same content set, the most each counter can ever hold — three stars
on every board of a campaign that runs to `chapters × levelsPerChapter`, one stage
per rung of every ladder in `modes.json`, every non-IAP row in `shop.json`. A goal
above its ceiling is refused: not hard, but a bar that sits half-filled forever.
Within one counter the ladder has to climb, so a harder goal that pays less is
also a refusal.

The ceilings are why this lives beside the content rather than in a screen:
`lib/game/` never imports `lib/core/`, so the *stat list and its maths* are in
`lib/game/achievements.dart` and the *reading of live counters* is in
`lib/core/achievement_service.dart`.

`playGamesId` is not generated. It is a string pasted from the Play Games console
for that exact achievement, and a card without one is simply a card that is not
mirrored there.

### `wheel.json` — sixteen wedges, and the maths that caps them

The screen stops the wheel on a random angle, so every wedge is equally likely
and the document's expected payout is `sum(amount) / segments`. That number is
what the validator bounds (`kWheelMaxExpectedCoins`, `kWheelMaxExpectedGems`),
along with a wedge count the dial can still draw, no duplicate ids, nothing
wearing an amount, and at least one paying and one empty wedge — a wheel that
always wins is a purse with no lid, and one that never wins is a button.

Wedge art scales with the chord, so adding wedges narrows the icons rather than
overlapping them.

### `shop.json` — rows, and the art a row promises

A `tubeSkin` row is a bottle the player can put on the board, so it has to come
with both renders: `assets/skins/<id>.png` (the sprite the board clips liquid
to) and `assets/skins/hero_<id>.png` (the three-quarter render the card shows).
`test/skin_sprite_render_test.dart` reads the shop list rather than a hand-written
one, and checks each sprite against `BottleClipper` at the pixel level — a wall a
millimetre narrower than the clip puts the bottom layer outside the glass, and no
amount of correct maths in Dart would notice.

A `theme` row is the room behind the board, and it now says what it paints:
either an `image` that exists in the bundle, or a `gradient` of at least two ARGB
stops the screen draws as a radial wash. The shop preview is the same value, which
is the whole point — a theme that only existed as an `if (id == 'forest_theme')`
branch in two files could be sold for a picture the game never showed.

## The fallback is the same bytes

`lib/content/generated/compiled_content.dart` holds every JSON document verbatim
and is generated by the tool, not written by hand. It is what serves when the
asset bundle cannot be read, so the fallback cannot drift from the shipped
content, and a build with a broken bundle plays the same game.

## Working with it

Regenerate after any change to the curve, the palette or the chapters — the pack
is derived from them:

```
flutter test tools/content/generate.dart
```

It deals a pack per chapter, proves every board with `WaterSortSolver` inside the
node budget, writes each pack with the proved `parMoves`, and recompiles the
fallback. Boards are dealt by undoing legal pours, so they are winnable by
construction rather than by luck; what is chosen by hand is *which* proved deal
opens a chapter (the plainest of the eight) and which closes it (the deepest), so
a chapter ends on its hardest board instead of a random one.
Then:

```
flutter test            # the contract test reads the files off disk
flutter analyze
```

Remote Config is not wired up yet. When it is, it lands here as a number-only
override - `levels.curve.maxColorCount`, `rewards.powerUps.costs.hint` - applied
to the parsed bundle before validation, and it stays inside the rule above.

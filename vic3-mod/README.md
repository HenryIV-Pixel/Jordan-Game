# Jordan 1950: a Victoria 3 sub-mod for Cold War Era

A small mod that loads after Cold War Era and adds Jordan's 1950s story chain and economic decisions. Version 0.1 has not yet been tested in the game.

## Install

1. Copy the `jordan_1950` folder (including the hidden `.metadata` folder inside it) to
   `Documents\Paradox Interactive\Victoria 3\mod\`.
   You should end up with `...\Victoria 3\mod\jordan_1950\.metadata\metadata.json`.
2. Open the Paradox launcher. Go to **Playsets**, add **Jordan 1950** to the playset that has Cold War Era, and put it **below** Cold War Era.
3. Start a game as Jordan.

## What is in 0.1

- **Journal entries** (Historical content):
  - The Hashemite Kingdom: a hub entry that carries the British subsidy.
  - The Baghdad Pact: from November 1955.
  - Glubb Pasha's Army: from March 1956.
  - The Nabulsi Government: from October 1956.
- **Events `jor.1`–`jor.9`:**
  - Templer's mission and the pact riots.
  - Glubb's dismissal.
  - The 1956 election.
  - The Arab Solidarity Agreement and the end of the British treaty.
  - The April 1957 crisis and martial law.
  - Each event has a "what really happened" option and an alternative.
- **Money from abroad** (British subsidy, then Arab subsidy, then American aid) is modelled as minting income.
- **Interest group reactions** are 5-year approval modifiers on the army, landowners, intelligentsia, trade unions, clergy, petty bourgeoisie, industrialists and rural folk.
- **Decisions:**
  - Develop the phosphate mines (mining throughput).
  - Build up Aqaba (construction and bureaucracy).

## Things that may need changing after the first test

- **Country tag.** Jordan is assumed to be `JOR`. It is written once, in `common/scripted_triggers/jor_triggers.txt`. Other tags (`GBR`, `EGY`, `SYR`, `SAU`, `IRQ`, `USA`) are guarded, so a wrong tag just skips that line.
- **Interest group names.** The vanilla keys are used. If Cold War Era renamed them, those reactions silently do nothing.
- **Modifier keys** such as `country_minting_add` and `building_group_bg_mining_throughput_add`. A wrong key shows up in the error log.

## Testing

1. Start the game with the playset, then load as Jordan in 1950.
2. In the console (open it with the `` ` `` key; it needs the `-debug_mode` launch option), try:
   - `event jor.1` to fire an event.
   - `date 1955.11.2` to jump to the pact.
3. Send `Documents\Paradox Interactive\Victoria 3\logs\error.log` back. Every line mentioning `jor` is something to fix.

Offline checks (brackets, localisation, references) can run without the game:

```
python tools/check_vic3_mod.py vic3-mod/jordan_1950
```

This mod is free. Paradox's licence does not allow selling mods.

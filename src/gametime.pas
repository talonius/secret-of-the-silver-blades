{ Camp rest: the game clock and the rest-time countdown, party healing, effect time-outs and scribe timers. }
{$O+,F+,I-,V-}
unit GameTime;

interface

uses Types, Magic, FxEngine, CharHlp, MenuCore, TextRend, GameIo, Crt, GDConsts, GDVars, C_Keys,
  C_Ifc, C_Spell;

{ Empty routine with no callers. }
procedure NoopGameTime;

{ Advances the game clock one unit at a time, carrying each component into the next, then ages the party's timed effects
  by the same span.
  @param(amt Number of units.)
  @param(lvl Clock component counted: 1 minutes, 2 tens of minutes, 3 hours, 4 days, 5 months, 6 years.) }
procedure AdvanceTime(amt: Byte; lvl: ShortInt);

{ Rests the party for the rest time. Interactive, it first runs the rest menu, redraws the rest time now and then and
  asks whether to stop when a key is pressed. Each five-minute step advances the clock, heals the party once a day,
  carries spell memorizing and scribing forward, and, once per rest period of the zone, rolls the zone's interruption
  chance. Silent rest skips the menu, the redraws and the key check.
  @param(mode True to show the menu and the rest time.)
  @returns(True when a wandering encounter interrupted the rest.) }
function CampRest(mode: Byte): Boolean;

{ Ages the timed effects of the party by a span of time, amt units of clock component lvl turned into minutes, in steps
  of at most ten minutes; an effect whose time runs out is removed. castFlag marks the members that still have timed
  effects. Outside camp every member is aged; in camp only flagged members are, and nothing happens when none is
  flagged. Note: a span in years overflows the minute count.
  @param(amt Number of units.)
  @param(lvl Clock component counted.) }
procedure TimeOutEffects(amt, lvl: Byte);

{ Carries each clock component that has reached its limit into the next one. A year rollover ages every party member by
  one year and notes that aging happened.
  @param(arr The clock to normalize.) }
procedure ValidateClock(var arr: Types.TRestClock);

{ Normalizes the rest time, folds its months into days and caps it at 99 days. }
procedure ValidateRestTime;

{ Takes a span off the rest time, borrowing from the larger components as needed; when there is nothing left to borrow,
  the rest time is cleared. Nothing happens when no days, hours or minutes are left.
  @param(a Number of units.)
  @param(b Clock component counted.) }
procedure DecrementRestTime(a: Byte; b: ShortInt);

{ Formats a number with at least two digits, keeping the first two.
  @param(n The number.)
  @returns(The digits, with a leading zero below 10.) }
function TwoDigitStr(n: Byte): Types.TStr40;

{ Shows the rest time as days, hours and minutes on the message line, the selected field in white.
  @param(sel Clock component shown in white: 2 minutes, 3 hours, 4 days; 0 for none.) }
procedure DisplayRestTime(sel: ShortInt);

{ Runs the rest-time menu: Days, Hours and Mins select the field, Add and Subtract (or the up and down arrows) change
  it, minutes by five, and the left and right arrows move between the fields. Rest or Enter starts resting; Exit or
  Escape leaves.
  @returns(True when Rest was chosen.) }
function CampRestMenu: Byte;

{ Counts one five-minute rest step; once a day of steps has passed, restores a hit point to each party member, shows
  "The Whole Party Is Healed" and pauses, redrawing the party when anyone was healed.
  @param(redraw True to redraw the rest time first.) }
procedure CheckRestingHeal(redraw: Byte);

{ Scans a character's memorized-spell slots for spells still being memorized. Unless the finished flag is already set,
  the first such spell is finished and announced, and the flag is set; the scan then goes on to the next one.
  @param(ch The character.)
  @param(f The finished flag: True to only look up the next pending spell; set when a spell is finished.)
  @returns(The level of the next spell still pending, or 0 when there is none.) }
function CheckMemorizeDone(ch: Types.PCharRecord; var f: Byte): Byte;

{ Unless f is already set, finishes scribing the first marked spell on a readable scroll the character carries (each
  sub-record of a bundle): the spell becomes known, leaves the scroll, and is reported. Then looks for the next marked
  spell.
  @param(ch The character.)
  @param(f Set to 1 once a spell is scribed.)
  @returns(The level of the next spell still to be scribed, or 0.) }
function CheckScribeDone(ch: Types.PCharRecord; var f: Byte): Byte;

{ Counts down each party member's spell-preparation timer; when it runs out and the member's preparation wait is over,
  the next spell being scribed or else memorized is finished and the timer restarts at three times the following spell's
  level. }
procedure AdvanceSpellPrep;

{ Counts rest steps; every twelfth step, each party member's preparation wait drops by one, and when it reaches zero the
  member's spell-preparation timer starts at three times the level of the next spell to scribe or memorize.
  @param(p The step counter, kept by the caller.) }
procedure AdvanceSpellPrepBase(var p: Byte);

implementation

procedure TimeOutEffects(amt, lvl: Byte);
var
  l: ShortInt;
  i: Byte;
  stepMins: Byte;
  elapsedMins: Word;
  ch: Types.PCharRecord;
  matchFlag: Byte;
  anyFlag: Byte;
  spellLast: Types.PEffectRec;
  spell: Types.PEffectRec;
  nextSpell: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  deadframe: array[1..257] of Byte;
begin
  if GDVars.interfaceState <> C_Ifc.CAMPING then
    FillChar(GDVars.castFlag, SizeOf(GDVars.castFlag), 1)
  else begin
    anyFlag := 0;
    i := 1;
    repeat
      if GDVars.castFlag[i] <> 0 then anyFlag := 1;
      Inc(i);
    until (anyFlag <> 0) or (i > GDVars.zone1^.partySize);
    if anyFlag = 0 then Exit;
  end;

  elapsedMins := amt;
  l := lvl;
  while l > 1 do begin
    elapsedMins := GDConsts.clockRadix[Pred(l)] * elapsedMins;
    l := Pred(l);
  end;

  while elapsedMins > 0 do begin
    if elapsedMins > 10 then stepMins := 10 else stepMins := elapsedMins;
    i := 1;
    ch := GDVars.creatureList;
    while ch <> nil do begin
      if GDVars.castFlag[i] <> 0 then begin
        GDVars.castFlag[i] := 0;
        spell := ch^.effectsAddr;
        spellLast := ch^.effectsAddr;
        if ch^.effectsAddr <> nil then
          while spellLast^.next <> nil do
            spellLast := spellLast^.next;
        matchFlag := 0;
        while (spell <> nil) and (matchFlag = 0) do begin
          if spell = spellLast then matchFlag := 1;
          if spell^.minutes = 0 then
            spell := spell^.next
          else if stepMins < spell^.minutes then begin
            Dec(spell^.minutes, stepMins);
            GDVars.castFlag[i] := 1;
            spell := spell^.next;
          end else begin
            nextSpell := spell^.next;
            FxEngine.RemoveEffect(ch, spell^.id, spell);
            spell := nextSpell;
          end;
        end;
        while spell <> nil do begin
          if spell^.minutes > 0 then GDVars.castFlag[i] := 1;
          spell := spell^.next;
        end;
      end;
      Inc(i);
      ch := ch^.nextCharAddr;
    end;
    if elapsedMins > 10 then Dec(elapsedMins, 10) else elapsedMins := 0;
  end;
end;

procedure ValidateClock(var arr: Types.TRestClock);
var
  i: ShortInt;
  ch: Types.PCharRecord;
begin
  for i := 0 to 6 do
    if arr[i] >= GDConsts.clockRadix[i] then begin
      if i <> 6 then begin
        Inc(arr[Succ(i)]);
        arr[i] := arr[i] - GDConsts.clockRadix[i];
      end else begin
        ch := GDVars.creatureList;
        while ch <> nil do begin
          Inc(ch^.age);
          ch := ch^.nextCharAddr;
        end;
        arr[6] := arr[6] - GDConsts.clockRadix[6];
        GDVars.agingFlag := 1;
      end;
    end;
end;

procedure ValidateRestTime;
begin
  GameTime.ValidateClock(GDVars.restClock);
  if GDVars.restClock[5] > 0 then begin
    Inc(GDVars.restClock[4], GDConsts.clockRadix[4] * GDVars.restClock[5]);
    GDVars.restClock[5] := 0;
    if GDVars.restClock[4] > 99 then GDVars.restClock[4] := 99;
  end;
end;

procedure AdvanceTime(amt: Byte; lvl: ShortInt);
var
  arr: Types.TRestClock;
  i: ShortInt;
  k: Byte;
begin
  for i := 0 to 6 do arr[i] := GDVars.zone0^.clock[$4BC6 + i];
  for k := 1 to amt do begin
    Inc(arr[lvl]);
    GameTime.ValidateClock(arr);
  end;
  for i := 0 to 6 do GDVars.zone0^.clock[$4BC6 + i] := arr[i];
  GameTime.TimeOutEffects(amt, lvl);
end;

procedure DecrementRestTime(a: Byte; b: ShortInt);
var
  c: ShortInt;
  e: ShortInt;
begin
  if (GDVars.restClock[4] <> 0) or (GDVars.restClock[3] <> 0) or (GDVars.restClock[2] <> 0) or
      (GDVars.restClock[1] <> 0) then begin
    while a > GDVars.restClock[b] do begin
      c := Succ(b);
      while (GDVars.restClock[c] = 0) and (c < 5) do c := Succ(c);
      if c = 5 then begin
        GameIo.FillWord(GDVars.restClock[0], SizeOf(GDVars.restClock));
        a := 0;
      end else
        for e := c downto Succ(b) do begin
          Dec(GDVars.restClock[e]);
          Inc(GDVars.restClock[Pred(e)], GDConsts.clockRadix[Pred(e)]);
        end;
    end;
    Dec(GDVars.restClock[b], a);
    GameTime.ValidateRestTime;
  end;
end;

function TwoDigitStr(n: Byte): Types.TStr40;
var
  s: Types.TStr40;
begin
  s := CharHlp.Uint8Str(n);
  if n < 10 then s := '0' + s;
  TwoDigitStr := Copy(s, 1, 2);
end;

procedure DisplayRestTime(sel: ShortInt);
var
  i: ShortInt;
  colr: array[0..6] of Word;
  row: Byte;
begin
  for i := 0 to 6 do colr[i] := LightGreen;
  colr[sel] := White;
  TextRend.DisplayString(1, 17, LightGreen, 0, 'Rest Time:');
  row := 11;
  for i := 4 downto 3 do begin
    TextRend.DisplayString(row + 1, 17, Lo(colr[i]), 0, GameTime.TwoDigitStr(GDVars.restClock[i]));
    TextRend.DisplayString(row + 1 + 2, 17, LightGreen, 0, ':');
    Inc(row, 3);
  end;
  TextRend.DisplayString(row + 1, 17, Lo(colr[2]), 0,
                         GameTime.TwoDigitStr(GDVars.restClock[2] * 10 + GDVars.restClock[1]));
end;

function CampRestMenu: Byte;
var
  active: Boolean;
  key: Char;
  field: ShortInt;
begin
  CampRestMenu := 0;
  field := 2;
  repeat
    GameTime.DisplayRestTime(field);
    key := MenuCore.MenuHorizontal('', 'Rest Days Hours Mins Add Subtract Exit', LightMagenta, LightGreen, White, 1, 0,
                                   active);
    if active then
      case key of
        C_Keys.UP: key := 'A';
        C_Keys.DOWN: key := 'S';
        C_Keys.LEFT: begin Inc(field); if field > 4 then field := 2; key := 'X'; end;
        C_Keys.RIGHT: begin Dec(field); if field < 2 then field := 4; key := 'X'; end;
      else
        key := 'X';
      end;
    if key = C_Keys.ENTER then key := 'R';
    case key of
      'R': CampRestMenu := 1;
      'D': field := 4;
      'H': field := 3;
      'M': field := 2;
      'A': begin
             if field = 2 then Inc(GDVars.restClock[1], 5) else Inc(GDVars.restClock[field]);
             GameTime.ValidateRestTime;
           end;
      'S': begin
             if field = 2 then GameTime.DecrementRestTime(5, 1) else GameTime.DecrementRestTime(1, field);
             GameTime.ValidateRestTime;
           end;
    end;
  until key in [C_Keys.NONE, 'E', 'R'];
end;

procedure CheckRestingHeal(redraw: Byte);
var
  healedAny: Byte;
  ch: Types.PCharRecord;
begin
  Inc(GDVars.healTicks);
  if GDVars.healTicks >= 288 then begin
    healedAny := 0;
    ch := GDVars.creatureList;
    while ch <> nil do begin
      if FxEngine.RestoreHitPoints(ch, 1, 0) then healedAny := 1;
      ch := ch^.nextCharAddr;
    end;
    if redraw <> 0 then GameTime.DisplayRestTime(0);
    TextRend.DisplayString(1, 19, LightGreen, 0, 'The Whole Party Is Healed');
    if healedAny <> 0 then CharHlp.DisplayRoster(GDVars.curChar);
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
    GDVars.healTicks := 0;
  end;
end;

function CheckMemorizeDone(ch: Types.PCharRecord; var f: Byte): Byte;
var
  found: Byte;
  i: Byte;
begin
  found := 0;
  i := 0;
  while (i <= 74) and (found = 0) do begin
    if ch^.memorizedSpells[i] > C_Spell.ID_MASK then begin
      if f <> 0 then
        found := GDConsts.spellDefs[ch^.memorizedSpells[i] and C_Spell.ID_MASK].level
      else begin
        Dec(ch^.memorizedSpells[i], C_Spell.PENDING_FLAG);
        GameTime.DisplayRestTime(0);
        Magic.PrintCastSpellMsg(ch, 'has memorized', ch^.memorizedSpells[i]);
        f := 1;
      end;
    end;
    Inc(i);
  end;
  CheckMemorizeDone := found;
end;

function CheckScribeDone(ch: Types.PCharRecord; var f: Byte): Byte;
var
  outer: Byte;
  inner: Byte;
  spellId: Byte;
  found: Byte;
  item: Types.PItemRec;
  sub: Types.PItemRec;
begin
  found := 0;
  item := ch^.itemsAddr;
  while (item <> nil) and (found = 0) do begin
    if Magic.ItemReadable(item) then begin
      if item^.itemType = Ord('I') then begin
        sub := item^.bundleNext;
        for outer := 1 to item^.count do begin
          inner := 1;
          while (inner <= 3) and (found = 0) do begin
            if sub^.spells[inner] > C_Spell.PENDING_FLAG then
              if f <> 0 then
                found := GDConsts.spellDefs[sub^.spells[inner] and C_Spell.ID_MASK].level
              else begin
                spellId := sub^.spells[inner] and C_Spell.ID_MASK;
                ch^.known[spellId] := 1;
                Magic.RemoveSpellFromScroll(ch, item, spellId);
                GameTime.DisplayRestTime(0);
                Magic.PrintCastSpellMsg(ch, 'has scribed', spellId);
                f := 1;
              end;
            Inc(inner);
          end;
          sub := sub^.bundleNext;
        end;
      end else begin
        inner := 1;
        while (inner <= 3) and (found = 0) do begin
          if item^.spells[inner] > C_Spell.PENDING_FLAG then
            if f <> 0 then
              found := GDConsts.spellDefs[item^.spells[inner] and C_Spell.ID_MASK].level
            else begin
              spellId := item^.spells[inner] and C_Spell.ID_MASK;
              ch^.known[spellId] := 1;
              Magic.RemoveSpellFromScroll(ch, item, spellId);
              GameTime.DisplayRestTime(0);
              Magic.PrintCastSpellMsg(ch, 'has scribed', spellId);
              f := 1;
            end;
          Inc(inner);
        end;
      end;
    end;
    item := item^.next;
  end;
  CheckScribeDone := found;
end;

procedure AdvanceSpellPrep;
var
  i: Byte;
  found: Byte;
  ch: Types.PCharRecord;
  flag: Byte;
begin
  i := 1;
  ch := GDVars.creatureList;
  while ch <> nil do begin
    if GDVars.prepTimers[i] > 0 then Dec(GDVars.prepTimers[i]);
    if (GDVars.prepTimers[i] = 0) and (ch^.prepBase = 0) then begin
      flag := 0;
      found := GameTime.CheckScribeDone(ch, flag);
      if found = 0 then found := GameTime.CheckMemorizeDone(ch, flag);
      GDVars.prepTimers[i] := found * 3;
    end;
    ch := ch^.nextCharAddr;
    Inc(i);
  end;
end;

procedure AdvanceSpellPrepBase(var p: Byte);
var
  i: Byte;
  found: Byte;
  ch: Types.PCharRecord;
  flag: Byte;
begin
  Inc(p);
  if p >= 12 then begin
    p := 0;
    i := 1;
    ch := GDVars.creatureList;
    while ch <> nil do begin
      if ch^.prepBase > 0 then begin
        Dec(ch^.prepBase);
        if ch^.prepBase = 0 then begin
          flag := 1;
          found := GameTime.CheckScribeDone(ch, flag);
          if found = 0 then found := GameTime.CheckMemorizeDone(ch, flag);
          GDVars.prepTimers[i] := found * 3;
        end;
      end;
      ch := ch^.nextCharAddr;
      Inc(i);
    end;
  end;
end;

function CampRest(mode: Byte): Boolean;
var
  ch: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  member: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  memberCount: Byte;
  i: Byte;
  tick: Byte;
  cnt: Byte;
  abort: Byte;
  { Unused in this version; see the other implementations of this routine. }
  interrupted: Byte;
begin
  CampRest := False;
  interrupted := 0;
  i := 1;
  ch := GDVars.creatureList;
  while ch <> nil do begin
    GDVars.prepTimers[i] := 0;
    Inc(i);
    ch := ch^.nextCharAddr;
  end;
  FillChar(GDVars.castFlag, SizeOf(GDVars.castFlag), 1);
  tick := 0;
  cnt := 0;
  if mode <> 0 then begin
    TextRend.ClearRect(1, 17, 38, 22);
    GameTime.DisplayRestTime(0);
  end;
  GDVars.restActive := 1;
  if mode <> 0 then
    abort := Ord(GameTime.CampRestMenu = 0)
  else
    abort := 0;
  while (abort = 0) and
      ((GDVars.restClock[4] > 0) or (GDVars.restClock[3] > 0) or (GDVars.restClock[2] > 0) or
       (GDVars.restClock[1] > 0)) do begin
    if mode <> 0 then
      if GameIo.InputPending then begin
        GameTime.DisplayRestTime(0);
        if MenuCore.YesNoMenu('Stop Resting? ', LightMagenta, LightGreen, White, 1) = 'Y' then abort := 1
        else MenuCore.ClearBottomLine;
      end;
    if abort = 0 then begin
      GameTime.DecrementRestTime(5, 1);
      Inc(cnt);
      if (mode <> 0) and (cnt >= 5) then begin
        GameTime.DisplayRestTime(0);
        cnt := 0;
      end;
      GameTime.AdvanceTime(5, 1);
      GameTime.CheckRestingHeal(mode);
      GameTime.AdvanceSpellPrep;
      GameTime.AdvanceSpellPrepBase(tick);
      if GDVars.zone1^.restSafeTime > 0 then begin
        Inc(GDVars.restTicks);
        if GDVars.restTicks >= GDVars.zone1^.restSafeTime then begin
          GDVars.restTicks := 0;
          if FxEngine.RollDice(1, 100) <= GDVars.zone1^.restInterruptPct then begin
            CharHlp.ClearMessageWindow;
            GameTime.DisplayRestTime(0);
            TextRend.DisplayString(1, 19, White, 0, 'Your repose is suddenly interrupted!');
            abort := 1;
            CampRest := True;
            TextRend.PauseOnly;
          end;
        end;
      end;
    end;
  end;
  TextRend.ClearRect(1, 17, 38, 22);
  GDVars.restActive := 0;
end;

procedure NoopGameTime;
begin
end;

begin
end.

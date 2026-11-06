{ Character creation and party management: the roster menu, character creation, modification and removal, portrait and
  icon selection, training, and the mouse and joystick configuration screens. }
{$O+,F+,A-,I-,V-}
unit CharGen;

interface

uses Types, SaveLoad, ViewChar, FxEngine, CharHlp, ClassCal, MenuCore, MapTiles, CbtMap, Blit, Border, TextRend,
  Joystick, Mouse, Crt, GameIo, GDConsts, GDVars, C_Race, C_Align, C_Status, C_Money,
  C_Class, C_Keys, C_Ifc, C_Stat, C_Spell, C_Effect;

{ Runs the top-level FUNCTION menu until play begins: Create, Drop, Modify, Train and Human change class (while the zone
  trains or free training is on), View, Add, Remove (saving a player character first; an NPC is dropped), Load, Save,
  Begin, Init mouse/joystick and Exit, the entries offered depending on whether there is a party. Any choice but Exit
  and Save marks the game unsaved. A class change replaces the paladin's protection from evil or the ranger's damage
  bonus to suit the new class. Begin, with a party or in demo mode, restores the interface state the menu was entered
  from, redraws its frame and the party, and clears the zone's training mask. Exit asks again for an unsaved party,
  saving it on No. With the developer keyword as the second parameter, J turns free training on or off. }
procedure MainMenu;

{ Asks whether to add from Secret or Curse saves, lists the saved characters and adds the chosen ones to the party until
  Exit or the party is full (six player characters or eight members). A character already listed with a star, already in
  the party, a paladin joining evil members, a fourth ranger, or an evil character joining a paladin is refused, the
  last three with a message. Note: addExit is never set, so whether Exit is offered depends on whatever the local
  held. }
procedure AddCharacterMenu;

{ Unlinks the current character from the party roster and frees it. Its predecessor, or else the roster head, becomes
  the current character. A character that is not in the roster is left untouched.
  @param(suppressSizeDec True leaves the party size alone.)
  @param(freeAnim True also frees the character's icon animation.) }
procedure RemoveCreature(suppressSizeDec, freeAnim: Boolean);

{ Runs the icon editor for the current character, showing the old and new icons side by side: Parts picks a head or
  body, colors 1 and 2 change the six icon colors (not on CGA), and Size switches between small and large; each change
  is kept or undone. It repeats until the player accepts the icon. }
procedure CustomizeIcon;

{ Trains a character a level in each class it has the experience for (or each class under free training, which raises
  the experience to match), within the racial level limits and the classes the zone trains; outside creation it picks
  the character, trains conscious ones only, asks first and trims experience past the level after next to one point
  below it. A class level gained recovers a drained level, recalculates the class values, lets a magic-user (or a ranger
  above level 8) pick a new spell and restores an earlier ranger's or paladin's effect, or during creation gives a
  magic-user its fixed spells, and rolls the new hit points. When nothing can be trained, creation's training loop is
  told to stop. Note: the second pass over the trainable classes reads the level of the last class examined for each of
  them. }
procedure TrainingMenu;

{ Looks up a character's Constitution hit-point bonus for a class in the Constitution bonus table; a fighter, ranger or
  paladin gets 1 more at 17, 2 at 18, 3 at 19..20, 4 at 21..23 and 5 at 24..25.
  @param(cr The character.)
  @param(cls The class.)
  @returns(The bonus per hit die.) }
function ConHpBonus(cr: Types.PCharRecord; cls: Byte): ShortInt;

{ Picks the current character's default icon head from its gender and race size, and its body from its classes. }
procedure SetDefaultIcon;

{ Creates a character: picks race (with its racial effects), gender, class (with starting levels and experience) and
  alignment, works out the starting age and rolls the six abilities (best of six rolls, adjusted for age and held within
  the race and class limits), sets up spells, starting money and first-level hit points, and trains as far as the
  experience allows; the abilities can be rerolled. It then takes a name and an icon and offers to save the character.
  Escape at any pick abandons it. Note: abandoning frees only the record, not its effects; the class list is not freed
  before the alignment list; a cleric-thief gets no starting age; and the racial ability adjustments test the race
  list's loop counter instead of the race. }
procedure CreateCharacterMenu;

{ Drops the selected character for good after asking twice: deletes its saved files and removes it from the party. }
procedure DropCharacterMenu;

{ Lets the player adjust a picked new character (one still at a starting experience total and never dual-classed): its
  six abilities within the race and class limits, its maximum hit points between HpMinimum and HpMaximum, and its name.
  The arrow keys or a mouse click move between fields, Add and Subtract change them, Keep accepts and Exit or Escape
  undoes every change. Keeping recalculates the spell slots, marks the character modified and works out its rolled hit
  points again. }
procedure ModifyCharacterMenu;

{ Works out the highest maximum hit points a character may be given: per class, its hit die's top value plus the
  Constitution adjustment for each level (a level more for a ranger), or a fixed figure past the class's hit-dice limit,
  averaged over the classes. Note: a class past its limit replaces the total gathered so far instead of adding to it.
  @param(cr The character.)
  @returns(The maximum.) }
function HpMaximum(cr: Types.PCharRecord): Byte;

{ Works out the lowest maximum hit points a character may be given: one point per level of each class (a level more for
  a ranger) plus each class's Constitution bonus, averaged over the classes, at least 1 when the bonus is negative.
  @param(cr The character.)
  @returns(The minimum.) }
function HpMinimum(cr: Types.PCharRecord): Byte;

{ Rolls hit points for the classes in mask that are below their hit-dice limit, keeping the better of two rolls (one die
  past first level), or a fixed gain past the limit, plus the Constitution bonus per die; both are divided among divisor
  classes, the dice at least 1. The gain goes to the rolled and maximum hit points, keeping the damage taken. Note: a
  class past its limit replaces the dice gathered so far instead of adding to them.
  @param(cr The character.)
  @param(mask Class bits of the classes rolled for.)
  @param(divisor The number of classes the gain is shared among.) }
procedure RollFirstLevelHp(cr: Types.PCharRecord; mask, divisor: Byte);

{ Lets the player turn the mouse or joystick on or off, or disable both, calibrating the joystick when it is turned on.
  Each change rewrites the configuration file: line 3 holds the input mode (M, J, or N) and the joystick calibration, or
  zeros, follow the five header lines. }
procedure InitMouseJoystick;

{ Calibrates joystick 1 in the text window, like Joystick.CalibrateJoystick: exits at once when Joystick.ProbeJoystick
  finds no stick; otherwise the center from 20 readings, then the upper-left and lower-right extremes with button 1
  down, and boundaries a third and two thirds of the way to the center. 20000 polls without a press, or a failed read,
  abort with "Unable to read joystick"; success enables the joystick. }
procedure CalibrateJoystickInWindow;

implementation

const
  { TCharRecord.alignment }
  ALIGN_LAWFUL_NEUTRAL = 1;
  ALIGN_TRUE_NEUTRAL = 4;
  ALIGN_CHAOTIC_NEUTRAL = 7;
  { TCharRecord.charClass }
  CLASS_DRUID = 1;
  { TCharRecord.gender }
  GENDER_FEMALE = 1;
  { extended scan code, after a #0 prefix }
  KEY_DEL = #83;

{ Frees a creature record with its combat record, items and effects. Note: a nil creature only prints a warning and is
  then used anyway.
  @param(cr The creature; nil on return.) }
procedure FreeCreature(var cr: Types.PCharRecord);
var
  hold: Types.PItemRec;
  it: Types.PItemRec;
  holdE: Types.PEffectRec;
  eff: Types.PEffectRec;
begin
  if cr = nil then
    CharHlp.PrintBottomLine('disposing a nil char');
  with cr^ do begin
    if combatAddr <> nil then
      FreeMem(combatAddr, SizeOf(Types.TCombatRec));
    it := itemsAddr;
    while it <> nil do begin
      hold := it;
      it := it^.next;
      FreeMem(hold, SizeOf(Types.TItemRec));
    end;
    eff := effectsAddr;
    while eff <> nil do begin
      holdE := eff;
      eff := eff^.next;
      FreeMem(holdE, SizeOf(Types.TEffectRec));
    end;
  end;
  FreeMem(cr, SizeOf(Types.TCharRecord));
  cr := nil;
end;

procedure MainMenu;
var
  i: Byte;
  ch: Char;
  { Unused in this version; see the other implementations of this routine. }
  ext: Byte;
  { var-passed to both MenuVertical and ViewCharMenu }
  ext2: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  menuEnabled: array[1..9] of Byte;
  { displayed-row count }
  n: ShortInt;
  redraw: Boolean;
  { saved interfaceState }
  stateB: Byte;
  { Unused in this version; see the other implementations of this routine. }
  loopActive: Byte;
  head: Types.PItemRec;
  sel: Types.PItemRec;
  p: Types.PItemRec;
  cnt: Integer;
  cls: Byte;
  eff: Types.PEffectRec;
begin
  GDVars.rosterMouseOn := 0;
  stateB := GDVars.interfaceState;
  GDVars.interfaceState := C_Ifc.MAIN_MENU;
  redraw := True;
  GDVars.freeTraining := 0;
  cnt := 0;
  while True do begin
    if redraw then begin
      Border.DrawWindowFrame(1);
      if GDVars.curChar <> nil then begin
        CharHlp.DisplayRoster(GDVars.curChar);
        GDConsts.menuTbl[1].enabled := 1;
        GDConsts.menuTbl[2].enabled := 1;
        GDConsts.menuTbl[3].enabled := Ord((GDVars.zone1^.trainMask > 0) or (GDVars.freeTraining <> 0));
        GDConsts.menuTbl[3].enabled := GDConsts.menuTbl[3].enabled;
        GDConsts.menuTbl[4].enabled := Ord((GDVars.zone1^.trainMask > 0) or (GDVars.freeTraining <> 0));
        GDConsts.menuTbl[5].enabled := 1;
        GDConsts.menuTbl[7].enabled := 1;
        GDConsts.menuTbl[8].enabled := 0;
        GDConsts.menuTbl[9].enabled := 1;
        GDConsts.menuTbl[10].enabled := 1;
        GDConsts.menuTbl[11].enabled := 0;
        GDConsts.menuTbl[12].enabled := 1;
      end else begin
        GDConsts.menuTbl[1].enabled := 0;
        GDConsts.menuTbl[2].enabled := 0;
        GDConsts.menuTbl[3].enabled := 0;
        GDConsts.menuTbl[4].enabled := 0;
        GDConsts.menuTbl[5].enabled := 0;
        GDConsts.menuTbl[7].enabled := 0;
        GDConsts.menuTbl[8].enabled := 1;
        GDConsts.menuTbl[9].enabled := 0;
        GDConsts.menuTbl[10].enabled := 0;
        GDConsts.menuTbl[11].enabled := 1;
        GDConsts.menuTbl[12].enabled := 1;
      end;
      n := 0;
      for i := 0 to 12 do
        if GDConsts.menuTbl[i].enabled <> 0 then
          Inc(n);
      MenuCore.AllocStringList(n, head);
      p := head;
      for i := 0 to 12 do
        if GDConsts.menuTbl[i].enabled <> 0 then begin
          p^.name := GDConsts.menuTbl[i].name;
          p := p^.next;
        end;
    end;
    ext2 := True;
    ch := MenuCore.MenuVertical('Choose a FUNCTION ', 'Select ', LightMagenta, LightGreen, White, 9, 12, 38, 22, head,
                                0, ext2, cnt, sel);
    ch := sel^.name[1];
    if redraw then
      MenuCore.FreeStringList(head);
    if not (ch in ['E', 'S']) then
      GDVars.gameSaved := 0;
    case ch of
      'C':
        if GDConsts.menuTbl[0].enabled <> 0 then CharGen.CreateCharacterMenu;
      'D':
        if GDConsts.menuTbl[1].enabled <> 0 then CharGen.DropCharacterMenu;
      'H':
        if GDConsts.menuTbl[4].enabled <> 0 then
          if ViewChar.PickCharacter then begin
            cls := ClassCal.ChangeClass(GDVars.curChar);
            if cls <> 17 then begin
              if CharHlp.HasEffect(GDVars.curChar, C_Effect.PROTECTION_FROM_EVIL, eff) then
                FxEngine.RemoveEffect(GDVars.curChar, C_Effect.PROTECTION_FROM_EVIL, nil);
              if CharHlp.HasEffect(GDVars.curChar, C_Effect.RANGER_DAMAGE_BONUS, eff) then
                FxEngine.RemoveEffect(GDVars.curChar, C_Effect.RANGER_DAMAGE_BONUS, nil);

              case cls of
                C_Class.PALADIN: FxEngine.AddEffect(GDVars.curChar, C_Effect.PROTECTION_FROM_EVIL, 0, 255, 0);
                C_Class.RANGER: FxEngine.AddEffect(GDVars.curChar, C_Effect.RANGER_DAMAGE_BONUS, 0, 255, 0);
              end;
            end;
          end;
      'M':
        if GDConsts.menuTbl[2].enabled <> 0 then CharGen.ModifyCharacterMenu;
      'T':
        if GDConsts.menuTbl[3].enabled <> 0 then CharGen.TrainingMenu;
      'V':
        if GDConsts.menuTbl[5].enabled <> 0 then
          if ViewChar.PickCharacter then
            ViewChar.ViewCharMenu(ext2);
      'A':
        if GDConsts.menuTbl[6].enabled <> 0 then CharGen.AddCharacterMenu;
      'R':
        if GDConsts.menuTbl[7].enabled <> 0 then
          if GDVars.curChar <> nil then
            if ViewChar.PickCharacter then begin
              if GDVars.curChar^.npc < $80 then begin
                SaveLoad.SaveChar(GDVars.curChar, '');
                CharGen.RemoveCreature(False, True);
              end else
                CharGen.DropCharacterMenu;
              if GDVars.curChar = nil then
                if GDVars.returnedFromCharGen = 0 then
                  GDVars.partyDefeated := 1;
            end;
      'L':
        if GDConsts.menuTbl[8].enabled <> 0 then SaveLoad.LoadGame;
      'S':
        if GDConsts.menuTbl[9].enabled <> 0 then
          if GDVars.creatureList <> nil then SaveLoad.SaveGame;
      'B':
        if GDConsts.menuTbl[10].enabled <> 0 then begin
          GDVars.rosterMouseOn := 1;
          if (GDVars.creatureList <> nil) or (GDVars.demoMode) then begin
            GDVars.interfaceState := stateB;
            if (GDVars.loadedSave = 0) or (GDVars.picArcId = 9) then begin
              if (GDVars.interfaceState = C_Ifc.OVERLAND) and (GDVars.zone0^.areaView = 0) then
                Border.ScreenText
              else
                Border.DrawExploreFrame;
              CharHlp.DisplayRoster(GDVars.curChar);
            end else begin
              if (GDVars.zone0^.prevEcl = 0) or (GDVars.zone0^.areaView <> 0) then begin
                Border.DrawExploreFrame;
                CharHlp.DisplayRoster(GDVars.curChar);
              end;
            end;
            MenuCore.ClearBottomLine;
            GDVars.zone1^.trainMask := 0;
            Exit;
          end;
        end;
      'I':
        if GDConsts.menuTbl[11].enabled <> 0 then CharGen.InitMouseJoystick;
      'E':
        if GDConsts.menuTbl[12].enabled <> 0 then begin
          ch := MenuCore.YesNoMenu('Quit to DOS ', Yellow, LightGreen, White, 2);
          if ch = 'Y' then
          begin
            if GDVars.creatureList <> nil then
              if GDVars.gameSaved = 0 then begin
                ch := MenuCore.YesNoMenu('Game NOT saved.  Quit anyway? ', Yellow, LightGreen, White, 2);
                if ch = 'N' then SaveLoad.SaveGame;
              end;
            if ch = 'Y' then GameIo.ExitGame;
          end;
        end;
      'J':
        if ParamStr(2) = GDVars.stingKey then begin
          GDVars.freeTraining := Ord(GDVars.freeTraining = 0);
          if GDVars.freeTraining <> 0 then
            CharHlp.PrintBottomLine('Free training on')
          else
            CharHlp.PrintBottomLine('Free training off');
        end;
    end;
  end;
end;

procedure CreateCharacterMenu;
var
  cr: Types.PCharRecord;
  cr2: Types.PCharRecord;
  head: Types.PItemRec;
  { MenuVertical's var cur }
  m: Types.PItemRec;
  { MenuVertical's var cnt }
  cnt: Integer;
  i: Byte;
  { the six-roll counter, then a cleric spell id }
  scratch: Byte;
  rolledStat: Byte;
  ch: Char;
  j: ShortInt;
  genderIdx: ShortInt;
  classIdx: ShortInt;
  statIdx: ShortInt;
  choiceCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  conBonus: array[1..3] of Byte;
  classCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hpRoll: Byte;
  { nonzero has MenuVertical offer Exit }
  showExit: Byte;
  { set to have MenuVertical repaint the list }
  redrawList: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  redraw: Byte;
  haveLevelText: Byte;
  buf: Types.TStr40;
  savedTrainMask: Byte;
  { Unused in this version; see the other implementations of this routine. }
  alignmentIds: array[1..6] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellMask: Byte;
  { Unused in this version; see the other implementations of this routine. }
  bitValue: Byte;
  startingCoins: Byte;
  { Unused in this version; see the other implementations of this routine. }
  rollIndex: Byte;
begin
  New(cr);
  GameIo.FillWord(cr^, SizeOf(Types.TCharRecord));
  with cr^ do begin
    for i := 1 to 6 do
      statPack[i] := GDConsts.statInitTbl[i] + (GDConsts.statInitTbl[i] + 8) shl 4;
    acBase := 50;
    baseToHit := 40;
    status := C_Status.OKAY;
    enabled := 1;
    iconDimensions := 1;
    combatIconId := Random(256);
    orderNumber := 10;
  end;
  MenuCore.AllocStringList(7, head);
  head^.isHeader := 1;
  head^.name := 'Pick Race';
  for j := 1 to 6 do begin
    m := MenuCore.FindListMember(j, head);
    m^.name := '  ' + GDConsts.raceNames[j];
  end;
  m := head;
  cnt := 1;
  redrawList := True;
  showExit := 1;
  repeat
    ch := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, head, showExit, redrawList,
                                cnt, m);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(head);
      FreeMem(cr, SizeOf(Types.TCharRecord));
      Exit;
    end;
  until ch = 'S';
  with cr^ do begin
    race := cnt;
    { raceSize 1 is the three small races and 2 the medium ones; Human lands in the else. }
    case race of
      C_Race.HALFLING: begin
           raceSize := 1;
           FxEngine.AddEffect(cr, 97, 0, 255, 0);
         end;
      C_Race.DWARF: begin
           raceSize := 1;
           FxEngine.AddEffect(cr, 47, 0, 255, 0);
           FxEngine.AddEffect(cr, 26, 0, 255, 0);
           FxEngine.AddEffect(cr, 97, 0, 255, 0);
         end;
      C_Race.GNOME: begin
           raceSize := 1;
           FxEngine.AddEffect(cr, 48, 0, 255, 0);
           FxEngine.AddEffect(cr, 7, 0, 255, 0);
           FxEngine.AddEffect(cr, 97, 0, 255, 0);
         end;
      C_Race.ELF: begin
           raceSize := 2;
           FxEngine.AddEffect(cr, 95, 0, 255, 0);
         end;
      C_Race.HALF_ELF: begin
           raceSize := 2;
           FxEngine.AddEffect(cr, 18, 0, 255, 0);
         end;
    else
      raceSize := 2;
    end;
  end;

  MenuCore.FreeStringList(head);
  MenuCore.AllocStringList(3, head);
  head^.isHeader := 1;
  head^.name := 'Pick Gender';
  for genderIdx := 0 to 1 do begin
    m := MenuCore.FindListMember(genderIdx + 1, head);
    m^.name := '  ' + GDConsts.genderNames[genderIdx];
  end;
  m := head;
  cnt := 1;
  showExit := 1;
  redrawList := True;
  repeat
    ch := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, head, showExit, redrawList,
                                cnt, m);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(head);
      FreeMem(cr, SizeOf(Types.TCharRecord));
      Exit;
    end;
  until ch = 'S';
  cr^.gender := cnt - 1;

  MenuCore.FreeStringList(head);
  choiceCount := GDConsts.raceClassTbl[cr^.race, 0];
  MenuCore.AllocStringList(choiceCount + 1, head);
  head^.isHeader := 1;
  head^.name := 'Pick Class';
  for i := 1 to choiceCount do begin
    m := MenuCore.FindListMember(i, head);
    m^.name := '  ' + GDConsts.classNames[GDConsts.raceClassTbl[cr^.race, i]];
  end;
  m := head;
  cnt := 1;
  showExit := 1;
  redrawList := True;
  repeat
    ch := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, head, showExit, redrawList,
                                cnt, m);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(head);
      FreeMem(cr, SizeOf(Types.TCharRecord));
      Exit;
    end;
  until ch = 'S';

  with cr^ do begin
    experience := 200000;
    charClass := GDConsts.raceClassTbl[race, cnt];
    highestLevel := 1;
    case charClass of
      C_Class.CLERIC..C_Class.FIGHTER: classLevelA[charClass] := 1;
      C_Class.MAGE..C_Class.THIEF: classLevelA[charClass] := 1;
      C_Class.PALADIN: begin
              cr^.cureDiseaseLeft := 1;
              classLevelA[C_Class.PALADIN] := 1;
              FxEngine.AddEffect(cr, C_Effect.PROTECTION_FROM_EVIL, 0, 255, 0);
            end;
      C_Class.RANGER: begin
              classLevelA[C_Class.RANGER] := 1;
              FxEngine.AddEffect(cr, C_Effect.RANGER_DAMAGE_BONUS, 0, 255, 0);
            end;
      C_Class.CLERIC_FIGHTER: begin
              classLevelA[C_Class.CLERIC] := 1;
              classLevelA[C_Class.FIGHTER] := 1;
              experience := 100000;
            end;
      C_Class.CLERIC_FIGHTER_MAGE: begin
              classLevelA[C_Class.CLERIC] := 1;
              classLevelA[C_Class.FIGHTER] := 1;
              classLevelA[C_Class.MAGE] := 1;
              experience := 66667;
            end;
      C_Class.CLERIC_RANGER: begin
              classLevelA[C_Class.CLERIC] := 1;
              classLevelA[C_Class.RANGER] := 1;
              FxEngine.AddEffect(cr, C_Effect.RANGER_DAMAGE_BONUS, 0, 255, 0);
              experience := 100000;
            end;
      C_Class.CLERIC_MAGE: begin
              classLevelA[C_Class.CLERIC] := 1;
              classLevelA[C_Class.MAGE] := 1;
              experience := 100000;
            end;
      C_Class.CLERIC_THIEF: begin
              classLevelA[C_Class.CLERIC] := 1;
              classLevelA[C_Class.THIEF] := 1;
              experience := 100000;
            end;
      C_Class.FIGHTER_MAGE: begin
              classLevelA[C_Class.FIGHTER] := 1;
              classLevelA[C_Class.MAGE] := 1;
              experience := 100000;
            end;
      C_Class.FIGHTER_THIEF: begin
              classLevelA[C_Class.FIGHTER] := 1;
              classLevelA[C_Class.THIEF] := 1;
              experience := 100000;
            end;
      C_Class.FIGHTER_MAGE_THIEF: begin
              classLevelA[C_Class.FIGHTER] := 1;
              classLevelA[C_Class.MAGE] := 1;
              classLevelA[C_Class.THIEF] := 1;
              experience := 66667;
            end;
      { Note: gets the three-class 66667 }
      C_Class.MAGE_THIEF: begin
              classLevelA[C_Class.MAGE] := 1;
              classLevelA[C_Class.THIEF] := 1;
              experience := 66667;
            end;
    end;

    if classLevelA[C_Class.THIEF] > 0 then ClassCal.RecalcThiefSkills(cr);
    classMask := 0;
    baseToHit := 0;

    for classIdx := C_Class.CLERIC to C_Class.THIEF do
      if classLevelA[classIdx] > 0 then begin
        if GDConsts.baseToHitTbl[classIdx, classLevelA[classIdx]] > baseToHit then
          baseToHit := GDConsts.baseToHitTbl[classIdx, classLevelA[classIdx]];
        Inc(classMask, GDConsts.classMaskTbl[classIdx]);
      end;
  end;

  ClassCal.RecalcSaves(cr);

  choiceCount := GDConsts.classAlignTbl[cr^.charClass, 0];
  MenuCore.AllocStringList(choiceCount + 1, head);
  head^.isHeader := 1;
  head^.name := 'Pick Alignment';
  for i := 1 to choiceCount do begin
    m := MenuCore.FindListMember(i, head);
    m^.name := '  ' + GDConsts.alignNames[ShortInt(GDConsts.classAlignTbl[cr^.charClass, i])];
  end;
  m := head;
  cnt := 1;
  showExit := 1;
  redrawList := True;
  repeat
    ch := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, head, showExit, redrawList,
                                cnt, m);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(head);
      FreeMem(cr, SizeOf(Types.TCharRecord));
      Exit;
    end;
  until ch = 'S';
  { the alignment store }
  cr^.alignment := GDConsts.classAlignTbl[cr^.charClass, cnt];
  MenuCore.FreeStringList(head);

  case cr^.alignment of
    C_Align.LAWFUL_GOOD, C_Align.NEUTRAL_GOOD, C_Align.CHAOTIC_GOOD:
      if (cr^.experience = 0) and (cr^.classLevelA[C_Class.CLERIC] > 0) then
        cr^.experience := 2000;
    CharGen.ALIGN_LAWFUL_NEUTRAL, CharGen.ALIGN_TRUE_NEUTRAL, CharGen.ALIGN_CHAOTIC_NEUTRAL:
      if (cr^.experience = 0) and (cr^.classLevelA[C_Class.CLERIC] > 0) then
        cr^.experience := 1500;
  end;

  if cr^.charClass <= C_Class.THIEF then
    with GDConsts.startAgeTbl[cr^.race, cr^.charClass] do
      cr^.age := base + FxEngine.RollDice(dice, sides)
  else

    with cr^ do
      case charClass of
        C_Class.CLERIC_FIGHTER, C_Class.CLERIC_FIGHTER_MAGE, C_Class.CLERIC_MAGE,
          C_Class.CLERIC_RANGER:
          age := GDConsts.startAgeTbl[race, C_Class.CLERIC].base
                 + GDConsts.startAgeTbl[race, C_Class.CLERIC].sides * GDConsts.startAgeTbl[race, C_Class.CLERIC].dice;
        C_Class.FIGHTER_MAGE, C_Class.FIGHTER_MAGE_THIEF, C_Class.MAGE_THIEF:
          age := GDConsts.startAgeTbl[race, C_Class.MAGE].base
                 + GDConsts.startAgeTbl[race, C_Class.MAGE].sides * GDConsts.startAgeTbl[race, C_Class.MAGE].dice;
        C_Class.FIGHTER_THIEF:
          age := GDConsts.startAgeTbl[race, C_Class.FIGHTER].base
                 + GDConsts.startAgeTbl[race, C_Class.FIGHTER].sides * GDConsts.startAgeTbl[race, C_Class.FIGHTER].dice;
      end;

  cr2 := GDVars.curChar;
  GDVars.curChar := cr;
  ViewChar.DisplayChar;

  repeat
  for classIdx := C_Class.CLERIC to C_Class.THIEF do
    if GDVars.curChar^.classLevelA[classIdx] > 0 then
      GDVars.curChar^.classLevelA[classIdx] := 1;
  cr^.strExc := 0;

  for statIdx := C_Stat.STRENGTH to C_Stat.CHARISMA do begin
    cr^.stats[statIdx].cur := 0;
    for scratch := 1 to 6 do begin
      rolledStat := FxEngine.RollDice(3, 6) + 1;
      case j of
        C_Race.DWARF: case statIdx of
             C_Stat.CONSTITUTION: Inc(rolledStat);
             C_Stat.CHARISMA: Dec(rolledStat);
           end;
        C_Race.ELF: case statIdx of
             C_Stat.DEXTERITY: Inc(rolledStat);
             C_Stat.CONSTITUTION: Dec(rolledStat);
           end;
        C_Race.HALFLING: case statIdx of
             C_Stat.STRENGTH: Dec(rolledStat);
             C_Stat.DEXTERITY: Inc(rolledStat);
           end;
      end;
      if cr^.stats[statIdx].cur < rolledStat then
        cr^.stats[statIdx].cur := rolledStat;
    end;
    with cr^ do
      case statIdx of
        C_Stat.STRENGTH: begin
             if (stats[statIdx].cur > 0) and (GDConsts.ageTbl[race, 0] < age) then
               Inc(stats[statIdx].cur);
             if (stats[statIdx].cur > 0) and (GDConsts.ageTbl[race, 1] < age) then
               Dec(stats[statIdx].cur);
             if (stats[statIdx].cur > 0) and (GDConsts.ageTbl[race, 2] < age) then
               Dec(stats[statIdx].cur, 2);
             if (stats[statIdx].cur > 0) and (GDConsts.ageTbl[race, 3] < age) then
               Dec(stats[statIdx].cur);
             if stats[statIdx].cur < GDConsts.raceLimits[race].strMin[gender] then
               stats[statIdx].cur := GDConsts.raceLimits[race].strMin[gender];
             if stats[statIdx].cur > GDConsts.raceLimits[race].strMax[gender] then
               stats[statIdx].cur := GDConsts.raceLimits[race].strMax[gender];
             if stats[statIdx].cur < GDConsts.classMinTbl[charClass, statIdx] then
               stats[statIdx].cur := GDConsts.classMinTbl[charClass, statIdx];

             if stats[C_Stat.STRENGTH].cur = 18 then
               if (classLevelA[C_Class.FIGHTER] > 0) or (classLevelA[C_Class.RANGER] > 0)
                  or (classLevelA[C_Class.PALADIN] > 0) then begin
                 strExc := Random(100) + 1;
                 if GDConsts.raceLimits[race].strExcMax[gender] < strExc then
                   strExc := GDConsts.raceLimits[race].strExcMax[gender];
               end;
           end;
        C_Stat.INTELLIGENCE: begin
             if GDConsts.ageTbl[race, 1] < age then Inc(stats[statIdx].cur);
             if GDConsts.ageTbl[race, 3] < age then Inc(stats[statIdx].cur);
             if stats[statIdx].cur < GDConsts.raceLimits[race].intMin then
               stats[statIdx].cur := GDConsts.raceLimits[race].intMin;
             if stats[statIdx].cur > GDConsts.raceLimits[race].intMax then
               stats[statIdx].cur := GDConsts.raceLimits[race].intMax;
             if stats[statIdx].cur < GDConsts.classMinTbl[charClass, statIdx] then
               stats[statIdx].cur := GDConsts.classMinTbl[charClass, statIdx];
           end;
        C_Stat.WISDOM: begin

             if GDConsts.ageTbl[race, 0] >= age then Dec(stats[statIdx].cur);
             if GDConsts.ageTbl[race, 1] < age then Inc(stats[statIdx].cur);
             if GDConsts.ageTbl[race, 2] < age then Inc(stats[statIdx].cur);
             if GDConsts.ageTbl[race, 3] < age then Inc(stats[statIdx].cur);
             if stats[statIdx].cur < GDConsts.raceLimits[race].wisMin then
               stats[statIdx].cur := GDConsts.raceLimits[race].wisMin;
             if stats[statIdx].cur > GDConsts.raceLimits[race].wisMax then
               stats[statIdx].cur := GDConsts.raceLimits[race].wisMax;
             if stats[statIdx].cur < GDConsts.classMinTbl[charClass, statIdx] then
               stats[statIdx].cur := GDConsts.classMinTbl[charClass, statIdx];
             if (stats[statIdx].cur < 13) and
                 (charClass in [C_Class.CLERIC_FIGHTER..C_Class.CLERIC_THIEF]) then
               stats[statIdx].cur := 13;
           end;
        C_Stat.DEXTERITY: begin
             if GDConsts.ageTbl[race, 2] < age then Dec(stats[statIdx].cur, 2);
             if GDConsts.ageTbl[race, 3] < age then Dec(stats[statIdx].cur);
             if stats[statIdx].cur < GDConsts.raceLimits[race].dexMin then
               stats[statIdx].cur := GDConsts.raceLimits[race].dexMin;
             if stats[statIdx].cur > GDConsts.raceLimits[race].dexMax then
               stats[statIdx].cur := GDConsts.raceLimits[race].dexMax;
             if stats[statIdx].cur < GDConsts.classMinTbl[charClass, statIdx] then
               stats[statIdx].cur := GDConsts.classMinTbl[charClass, statIdx];
           end;
        C_Stat.CONSTITUTION: begin
             if GDConsts.ageTbl[race, 1] < age then Dec(stats[statIdx].cur);
             if GDConsts.ageTbl[race, 2] < age then Dec(stats[statIdx].cur);
             if GDConsts.ageTbl[race, 3] < age then Dec(stats[statIdx].cur);
             if stats[statIdx].cur < GDConsts.raceLimits[race].conMin then
               stats[statIdx].cur := GDConsts.raceLimits[race].conMin;
             if stats[statIdx].cur > GDConsts.raceLimits[race].conMax then
               stats[statIdx].cur := GDConsts.raceLimits[race].conMax;
             if stats[statIdx].cur < GDConsts.classMinTbl[charClass, statIdx] then
               stats[statIdx].cur := GDConsts.classMinTbl[charClass, statIdx];
           end;
        C_Stat.CHARISMA: begin
             if stats[statIdx].cur < GDConsts.raceLimits[race].chaMin then
               stats[statIdx].cur := GDConsts.raceLimits[race].chaMin;
             if stats[statIdx].cur > GDConsts.raceLimits[race].chaMax then
               stats[statIdx].cur := GDConsts.raceLimits[race].chaMax;
             if stats[statIdx].cur < GDConsts.classMinTbl[charClass, statIdx] then
               stats[statIdx].cur := GDConsts.classMinTbl[charClass, statIdx];
           end;
      end;
    cr^.stats[statIdx].base := cr^.stats[statIdx].cur;
    if statIdx = 0 then
      cr^.strExcMax := cr^.strExc;
    ViewChar.PrintStat(statIdx, False);
  end;

  with cr^ do begin
    hpCur := hpMax;
    attacks := 2;
    unarmedRollsA[1] := 1;
    unarmedDiceA[1] := 2;
    useStrength := 1;
    movementBase := 12;
    hpRoll := 0;
    classCount := 0;
    startingCoins := 0;
    GameIo.FillWord(spellSlots, SizeOf(spellSlots));
    for classIdx := C_Class.CLERIC to C_Class.THIEF do
      if classLevelA[classIdx] > 0 then begin
        case classIdx of
          C_Class.CLERIC: spellSlots[C_Spell.CLERIC_LIST, 1] := 2;
          C_Class.MAGE: spellSlots[C_Spell.MAGE_LIST, 1] := 1;
        end;
        case classIdx of
          C_Class.CLERIC: begin
               ClassCal.RecalcSpellSlots(cr);
               i := 1;
               scratch := 255;
               while (i <= 10) and (scratch <> 0) do begin
                 scratch := GDConsts.clericSpellsByLevel[1, i];
                 if scratch <> 0 then
                   known[scratch] := 1;
                 Inc(i);
               end;
             end;
          C_Class.MAGE: begin
               known[11] := 1;
               known[18] := 1;
               known[19] := 1;
               known[21] := 1;
             end;
          C_Class.THIEF: Inc(startingCoins, FxEngine.RollDice(2, 6));
        end;
        Inc(classCount);
      end;
    coinsA[C_Money.GOLD] := startingCoins;
  end;
  cr^.hpMax := 0;
  cr^.hpRolled := 0;
  cr^.hpCur := 0;

  CharGen.RollFirstLevelHp(cr, $FF, classCount);
  savedTrainMask := GDVars.zone1^.trainMaskLo;
  GDVars.zone1^.trainMask := $FF;
  GDVars.trainMenuDone := 0;
  GDVars.newCharTraining := 1;
  repeat
    CharGen.TrainingMenu;
  until GDVars.trainMenuDone <> 0;
  GDVars.zone1^.trainMask := savedTrainMask;
  GDVars.newCharTraining := 0;

  haveLevelText := 0;
  buf := '';
  for classIdx := C_Class.CLERIC to C_Class.THIEF do
    if (GDVars.curChar^.classLevelA[classIdx] > 0)
       or ((GDVars.curChar^.classLevelB[classIdx] < ClassCal.CurrentDualClassLevel(GDVars.curChar)) and
           (GDVars.curChar^.classLevelB[classIdx] > 0)) then begin
      if haveLevelText <> 0 then
        buf := buf + '/';
      buf := buf + CharHlp.Uint8Str(GDVars.curChar^.classLevelA[classIdx] + GDVars.curChar^.classLevelB[classIdx]);
      haveLevelText := 1;
    end;
  TextRend.DisplayString(7, 7, White, 0, buf);
  ViewChar.PrintCombatStats;
  ViewChar.PrintMoney;
  ch := MenuCore.YesNoMenu('Reroll stats? ', LightMagenta, LightGreen, White, 1);
  until ch = 'N';

  ViewChar.DisplayChar;
  repeat
    cr^.name := TextRend.ReadString('Character name: ', LightMagenta, 0, 15);
  until Length(cr^.name) <> 0;
  CharGen.SetDefaultIcon;
  CharGen.CustomizeIcon;
  for statIdx := C_Stat.STRENGTH to C_Stat.CHARISMA do
    cr^.stats[statIdx].base := cr^.stats[statIdx].cur;
  cr^.strExcMax := cr^.strExc;

  ch := MenuCore.YesNoMenu('Save ' + cr^.name + '? ', LightMagenta, LightGreen, White, 1);
  if ch = 'N' then
  begin
    FreeMem(cr, SizeOf(Types.TCharRecord));
    GDVars.curChar := cr2;
  end else begin
    SaveLoad.SaveChar(cr, '');
    FreeMem(cr, SizeOf(Types.TCharRecord));
    GDVars.curChar := cr2;
  end;
end;

{ Computes the current character's Constitution hit-point adjustment for a class: -2 at Constitution 3, -1 at 4 to 6, 0
  at 7 to 14, +1 at 15, +2 at 16, and at 17 to 19 the Constitution less 14 for fighters, rangers and paladins or +2 for
  others. Note: a Constitution outside 3 to 19 leaves the result undefined.
  @param(cls The class level index.)
  @returns(The hit-point adjustment per level.) }
function ClassConAdj(cls: Byte): ShortInt;
var
  bonus: ShortInt;
begin
  case GDVars.curChar^.stats[C_Stat.CONSTITUTION].cur of
    3: bonus := -2;
    4..6: bonus := -1;
    7..14: bonus := 0;
    15: bonus := 1;
    16: bonus := 2;
    17..19: if (cls = C_Class.FIGHTER) or (cls = C_Class.RANGER) or (cls = C_Class.PALADIN) then
                  bonus := GDVars.curChar^.stats[C_Stat.CONSTITUTION].cur - 14
                else
                  bonus := 2;
  end;
  ClassConAdj := bonus;
end;

procedure DropCharacterMenu;
var
  { Unused in this version; see the other implementations of this routine. }
  answer: Byte;
begin
  if ViewChar.PickCharacter then begin
    if GDVars.curChar <> nil then
      with GDVars.curChar^ do begin
        if (MenuCore.YesNoMenu('Drop ' + name + ' forever? ', Yellow, LightGreen, White, 2) = 'Y') and
            (MenuCore.YesNoMenu('Are you sure? ', Yellow, LightGreen, White, 2) = 'Y') then
        begin
          if enabled = 0 then
            CharHlp.PrintBottomLine('You dump ' + name + ' out back.')
          else
            CharHlp.PrintBottomLine(name + ' bids you farewell.');
          SaveLoad.DeleteCharacterFiles(GDVars.curChar);
          CharGen.RemoveCreature(False, True);
        end else
          CharHlp.PrintBottomLine(name + ' breathes a sigh of relief.');
      end;
    CharHlp.DisplayRoster(GDVars.curChar);
  end;
end;

procedure ModifyCharacterMenu;
var
  { entry copy of stats[].cur }
  savedStats: array[0..5] of Byte;
  { entry copy of strExc }
  savedStrExc: Byte;
  { entry copy of hpMax }
  savedHpMax: Byte;
  { entry copy of name }
  savedName: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  nameIdx: Byte;
  cls: ShortInt;
  i: ShortInt;
  key: Char;
  extFlag: Boolean;
  { which row is being edited }
  field: Byte;
  { Unused in this version; see the other implementations of this routine. }
  statRows: array[1..7] of Byte;
  { column within the name }
  cursorCol: Byte;
  j: Byte;

  { Draws the field being modified, highlighted when idx is nonzero. }
  procedure DisplayModifyField(idx: Byte);
  begin
    case field of

      0..5: ViewChar.PrintStat(field, Boolean(idx));
      7: CharHlp.PrintHitPoints(GDVars.curChar, 31, 3, idx, 0);
      6: if idx <> 0 then begin
              TextRend.PrintSpaces(Length(GDVars.curChar^.name) + 1, 1, 0, 1);
              TextRend.DisplayString(1, 1, LightMagenta, 0, GDVars.curChar^.name);

              if GDVars.curChar^.name[cursorCol] = ' ' then
                TextRend.DisplayString(cursorCol, 1, White, 0, '%')
              else
                TextRend.DisplayString(cursorCol, 1, White, 0, GDVars.curChar^.name[cursorCol]);
            end else
              TextRend.DisplayString(1, 1, LightGreen, 0, GDVars.curChar^.name);
    end;
  end;

begin

  if not ViewChar.PickCharacter then Exit;

  if not (((GDVars.curChar^.experience = 0) or (GDVars.curChar^.experience = 66667) or
           (GDVars.curChar^.experience = 100000) or (GDVars.curChar^.experience = 200000)) and
      (GDVars.curChar^.dualClassThreshold = 0)) then begin
    TextRend.PrintAndPause(GDVars.curChar^.name + ' can''t be modified.', Yellow, 0);
    Exit;
  end;

  GDVars.mouseMenuRow := 255;
  GDVars.modifyMenuActive := 1;
  ViewChar.DisplayChar;
  for i := C_Stat.STRENGTH to C_Stat.CHARISMA do
    savedStats[i] := GDVars.curChar^.stats[i].cur;
  savedStrExc := GDVars.curChar^.strExc;
  savedHpMax := GDVars.curChar^.hpMax;
  savedName := GDVars.curChar^.name;

  cursorCol := 1;
  field := 7;
  DisplayModifyField(0);
  field := 0;
  DisplayModifyField(1);

  with GDVars.curChar^ do
  repeat
    if field = 6 then begin

      extFlag := False;
      repeat until GameIo.InputPending;
      key := GameIo.ReadGameKey;
      if key in ['1'..'9', '\'] then
      begin
        if key = '\' then
          key := '7'
        else
          key := Chr(GDConsts.keyRemap[Ord(key) - Ord('1')]);
        extFlag := True;
      end;
      if key = #0 then begin
        key := GameIo.ReadGameKey;
        extFlag := True;
      end;
      if key = C_Keys.ESCAPE then key := C_Keys.NONE;
    end else
      key := MenuCore.MenuHorizontal('Modify: ', 'Add Subtract Keep Exit', LightMagenta, LightGreen, White, 1, 0,
                                     extFlag);
    DisplayModifyField(0);
    if extFlag then begin

      case key of
        CharGen.KEY_DEL:

          if (field = 6) and (Length(GDVars.curChar^.name) > 1) then begin
            if cursorCol = Length(GDVars.curChar^.name) then begin
              Dec(GDVars.curChar^.name[0]);
              cursorCol := Length(GDVars.curChar^.name);
            end else begin
              for j := cursorCol to Length(GDVars.curChar^.name) - 1 do
                GDVars.curChar^.name[j] := GDVars.curChar^.name[j + 1];
              Dec(GDVars.curChar^.name[0]);
            end;
          end;
        C_Keys.DOWN:
          begin
            GDVars.mouseMenuRow := 255;
            Inc(field);
            if field > 7 then field := 0;
          end;
        C_Keys.UP:
          begin
            GDVars.mouseMenuRow := 255;
            Dec(field);
            if field = 255 then field := 7;
          end;
        C_Keys.HOME:

          if GDVars.mouseClk and (GDVars.mouseMenuRow <> 255) then
            field := GDVars.mouseMenuRow;
      end;
    end else begin

      case key of
        'S':

          if field < 6 then begin
            i := field;
            Dec(stats[i].cur);
            case i of
              C_Stat.STRENGTH: begin
                   if strExc > 0 then begin
                     Dec(strExc);
                     Inc(stats[i].cur);
                   end else
                     if stats[i].cur < GDConsts.raceLimits[race].strMin[gender] then
                       stats[i].cur := GDConsts.raceLimits[race].strMin[gender];
                   if stats[i].cur < GDConsts.classMinTbl[charClass, C_Stat.STRENGTH] then
                     stats[i].cur := GDConsts.classMinTbl[charClass, C_Stat.STRENGTH];
                 end;
              C_Stat.INTELLIGENCE: begin
                   if stats[i].cur < GDConsts.raceLimits[race].intMin then
                     stats[i].cur := GDConsts.raceLimits[race].intMin;
                   if stats[i].cur < GDConsts.classMinTbl[charClass, C_Stat.INTELLIGENCE] then
                     stats[i].cur := GDConsts.classMinTbl[charClass, C_Stat.INTELLIGENCE];
                 end;
              C_Stat.WISDOM: begin
                   if stats[i].cur < GDConsts.raceLimits[race].wisMin then
                     stats[i].cur := GDConsts.raceLimits[race].wisMin;
                   if stats[i].cur < GDConsts.classMinTbl[charClass, C_Stat.WISDOM] then
                     stats[i].cur := GDConsts.classMinTbl[charClass, C_Stat.WISDOM];
                   if spellSlots[C_Spell.CLERIC_LIST, 1] > 0 then spellSlots[C_Spell.CLERIC_LIST, 1] := 1;
                 end;
              C_Stat.DEXTERITY: begin
                   if stats[i].cur < GDConsts.raceLimits[race].dexMin then
                     stats[i].cur := GDConsts.raceLimits[race].dexMin;
                   if stats[i].cur < GDConsts.classMinTbl[charClass, C_Stat.DEXTERITY] then
                     stats[i].cur := GDConsts.classMinTbl[charClass, C_Stat.DEXTERITY];
                 end;
              C_Stat.CONSTITUTION: begin

                   if stats[i].cur < GDConsts.raceLimits[race].conMin then
                     stats[i].cur := GDConsts.raceLimits[race].conMin;
                   if stats[i].cur < GDConsts.classMinTbl[charClass, C_Stat.CONSTITUTION] then
                     stats[i].cur := GDConsts.classMinTbl[charClass, C_Stat.CONSTITUTION];
                   if CharGen.HpMaximum(GDVars.curChar) < hpMax then
                     hpMax := CharGen.HpMaximum(GDVars.curChar);
                   hpCur := hpMax;
                   field := 6;
                   DisplayModifyField(0);
                   field := 4;
                 end;
              C_Stat.CHARISMA: begin
                   if stats[i].cur < GDConsts.raceLimits[race].chaMin then
                     stats[i].cur := GDConsts.raceLimits[race].chaMin;
                   if stats[i].cur < GDConsts.classMinTbl[charClass, C_Stat.CHARISMA] then
                     stats[i].cur := GDConsts.classMinTbl[charClass, C_Stat.CHARISMA];
                 end;
            end;
          end else if field = 7 then begin
            Dec(hpMax);
            if CharGen.HpMinimum(GDVars.curChar) > hpMax then
              hpMax := CharGen.HpMinimum(GDVars.curChar);
            hpCur := hpMax;
          end else
            if cursorCol = 1 then
              cursorCol := Length(GDVars.curChar^.name)
            else
              Dec(cursorCol);
        'A':

          if field < 6 then begin
            i := field;
            Inc(stats[i].cur);
            case i of
              C_Stat.STRENGTH: if stats[i].cur > GDConsts.raceLimits[race].strMax[gender] then begin

                   if stats[i].cur > 18 then
                     if (classLevelA[C_Class.FIGHTER] > 0) or (classLevelA[C_Class.PALADIN] > 0)
                        or (classLevelA[C_Class.RANGER] > 0) then
                       if GDConsts.raceLimits[race].strExcMax[gender] > strExc then
                         Inc(strExc);
                   stats[i].cur := GDConsts.raceLimits[race].strMax[gender];
                 end;
              C_Stat.INTELLIGENCE: if stats[i].cur > GDConsts.raceLimits[race].intMax then
                   stats[i].cur := GDConsts.raceLimits[race].intMax;
              C_Stat.WISDOM: begin
                   if stats[i].cur > GDConsts.raceLimits[race].wisMax then
                     stats[i].cur := GDConsts.raceLimits[race].wisMax;
                   if spellSlots[C_Spell.CLERIC_LIST, 1] > 0 then spellSlots[C_Spell.CLERIC_LIST, 1] := 1;
                 end;
              C_Stat.DEXTERITY: if stats[i].cur > GDConsts.raceLimits[race].dexMax then
                   stats[i].cur := GDConsts.raceLimits[race].dexMax;
              C_Stat.CONSTITUTION: begin
                   if stats[i].cur > GDConsts.raceLimits[race].conMax then
                     stats[i].cur := GDConsts.raceLimits[race].conMax;
                   if CharGen.HpMinimum(GDVars.curChar) > hpMax then
                     hpMax := CharGen.HpMinimum(GDVars.curChar);
                   hpCur := hpMax;
                   field := 6;
                   DisplayModifyField(0);
                   field := 4;
                 end;
              C_Stat.CHARISMA: if stats[i].cur > GDConsts.raceLimits[race].chaMax then
                   stats[i].cur := GDConsts.raceLimits[race].chaMax;
            end;
          end else if field = 7 then begin
            Inc(hpMax);
            if CharGen.HpMaximum(GDVars.curChar) < hpMax then
              hpMax := CharGen.HpMaximum(GDVars.curChar);
            hpCur := hpMax;
          end else
            if cursorCol = Length(GDVars.curChar^.name) then
              cursorCol := 1
            else
              Inc(cursorCol);
        C_Keys.ENTER:
          begin
            Inc(field);
            if field > 7 then field := 0;
          end;
        C_Keys.BACKSPACE:

          if (cursorCol > 1) and (field = 6) then begin
            for j := cursorCol to Length(GDVars.curChar^.name) do
              GDVars.curChar^.name[j - 1] := GDVars.curChar^.name[j];
            Dec(GDVars.curChar^.name[0]);
            if cursorCol > Length(GDVars.curChar^.name) then
              cursorCol := Length(GDVars.curChar^.name);
          end;
        ' '..'z':
          if field = 6 then begin

            if cursorCol <= 15 then begin
              GDVars.curChar^.name[cursorCol] := key;
              Inc(cursorCol);
              if cursorCol > 15 then cursorCol := 15;
              if cursorCol > Length(GDVars.curChar^.name) then begin
                Inc(GDVars.curChar^.name[0]);
                GDVars.curChar^.name[cursorCol] := ' ';
              end;
            end;
          end else
            if key = 'E' then
            begin

              for i := C_Stat.STRENGTH to C_Stat.CHARISMA do
                GDVars.curChar^.stats[i].cur := savedStats[i];
              GDVars.curChar^.strExc := savedStrExc;
              GDVars.curChar^.hpMax := savedHpMax;
              GDVars.curChar^.hpCur := hpMax;
              GDVars.curChar^.name := savedName;
              CharHlp.RecalcStats(GDVars.curChar);
              GDVars.modifyMenuActive := 0;
              Exit;
            end;
        C_Keys.NONE:
          begin

            for i := C_Stat.STRENGTH to C_Stat.CHARISMA do
              GDVars.curChar^.stats[i].cur := savedStats[i];
            GDVars.curChar^.strExc := savedStrExc;
            GDVars.curChar^.hpMax := savedHpMax;
            GDVars.curChar^.name := savedName;
            GDVars.curChar^.hpCur := hpMax;
            CharHlp.RecalcStats(GDVars.curChar);
            GDVars.modifyMenuActive := 0;
            Exit;
          end;
      end;
    end;

    CharHlp.RecalcStats(GDVars.curChar);
    ViewChar.PrintCombatStats;
    DisplayModifyField(1);
  until (not extFlag) and (key = 'K');

  ClassCal.RecalcSpellSlots(GDVars.curChar);
  GDVars.curChar^.modified := 1;
  with GDVars.curChar^ do begin
    savedHpMax := 0;
    j := 0;
    for cls := C_Class.CLERIC to C_Class.THIEF do
      if classLevelA[cls] > 0 then begin
        if classLevelA[cls] < GDConsts.firstFixedHpLevel[cls] then begin
          if cls = C_Class.RANGER then
            Inc(savedHpMax, CharGen.ClassConAdj(cls) * (classLevelA[cls] + 1))
          else
            Inc(savedHpMax, CharGen.ClassConAdj(cls) * classLevelA[cls]);
        end else
          Inc(savedHpMax, CharGen.ClassConAdj(cls) * (GDConsts.firstFixedHpLevel[cls] - 1));
        Inc(j);
      end;
    savedHpMax := savedHpMax div j;
    hpRolled := hpMax - savedHpMax;
  end;
  for i := C_Stat.STRENGTH to C_Stat.CHARISMA do
    GDVars.curChar^.stats[i].base := GDVars.curChar^.stats[i].cur;
  GDVars.curChar^.strExcMax := GDVars.curChar^.strExc;
  GDVars.modifyMenuActive := 0;
end;

procedure AddCharacterMenu;
var
  { saved-name list (display) }
  displayList: Types.PItemRec;
  { parallel record list }
  recordList: Types.PItemRec;
  { MenuVertical's var cur }
  cur: Types.PItemRec;
  { node fetched by index }
  selRec: Types.PItemRec;
  newChar: Types.PCharRecord;
  { party-scan cursor }
  scan: Types.PCharRecord;
  { MenuVertical's var cnt }
  selIdx: Integer;
  ch: Char;
  { nonzero has MenuVertical offer Exit }
  addExit: Byte;
  { set to have MenuVertical repaint the list }
  redraw: Boolean;
  { savable party members }
  realCount: Byte;
  rangerCount: Byte;
  evilFlag: Byte;
  paladinFlag: Byte;
  { the paladin's name }
  existName: Types.TStr40;
  ext: Boolean;
begin
  evilFlag := 0;
  paladinFlag := 0;
  rangerCount := 0;
  Border.ClearBox(1, 1, 38, 22);
  ch := MenuCore.MenuHorizontal('Add from where? ', 'Secret Curse Exit', LightMagenta, LightGreen, White, 0, 0, ext);
  case ch of
    'S': GDVars.saveMode := 1;
    'C': GDVars.saveMode := 0;
    'E', C_Keys.NONE: Exit;
  end;
  SaveLoad.LoadCharlist(displayList, recordList);
  if displayList = nil then Exit;
  selIdx := 0;
  cur := displayList;
  redraw := True;
  repeat
    ch := MenuCore.MenuVertical('Add a character: ', 'Add ', LightMagenta, LightGreen, White, 1, 2, 38, 22, displayList,
                                addExit,
                       redraw, selIdx, cur);
    if (ch = C_Keys.ENTER) or (ch = 'A') then
      if cur^.name[1] <> '*' then
      begin
        MenuCore.ClearBottomLine;
        New(newChar);
        selRec := MenuCore.FindListMember(selIdx, recordList);
        SaveLoad.LoadChar(selRec^.name, newChar, False, True);
        cur^.name := '* ' + cur^.name;
        realCount := 0;
        if GDVars.creatureList = nil then begin
          GDVars.zone1^.partySize := 0;
          SaveLoad.AddCharToParty(newChar);
          SaveLoad.LoadCharIconAnim(True);
        end else begin
          scan := GDVars.creatureList;
          rangerCount := 0;

          while (scan <> nil) and
              ((scan^.name <> newChar^.name) or (scan^.combatIconId <> newChar^.combatIconId)) do begin
            if scan^.npc < $80 then Inc(realCount);
            if scan^.classLevelA[C_Class.RANGER] > 0 then Inc(rangerCount);
            if ShortInt((scan^.alignment + 1) mod 3) = 0 then evilFlag := 1;
            if scan^.classLevelA[C_Class.PALADIN] > 0 then begin
              paladinFlag := 1;
              existName := scan^.name;
            end;
            scan := scan^.nextCharAddr;
          end;
          if (scan = nil) and
              (((newChar^.npc < $80) and (realCount < 6)) or
               ((newChar^.npc > $7F) and (GDVars.zone1^.partySize < 8))) and
              not ((newChar^.classLevelA[C_Class.PALADIN] <> 0) and (evilFlag <> 0)) and
              not ((newChar^.classLevelA[C_Class.RANGER] <> 0) and (rangerCount >= 3)) and
              not ((ShortInt((newChar^.alignment + 1) mod 3) = 0) and (paladinFlag <> 0)) then begin
            SaveLoad.AddCharToParty(newChar);
            SaveLoad.LoadCharIconAnim(True);
            if newChar^.npc < $80 then Inc(realCount);
          end else begin
            Delete(cur^.name, 1, 2);
            if (newChar^.classLevelA[C_Class.PALADIN] > 0) and (evilFlag <> 0) then begin
              CharHlp.PrintBottomLine('paladins do not join with evil scum');
              TextRend.PauseOnly;
            end else if (newChar^.classLevelA[C_Class.RANGER] > 0) and (rangerCount > 2) then
              CharHlp.PrintBottomLine('too many rangers in party')
            else if (ShortInt((newChar^.alignment + 1) mod 3) = 0) and (paladinFlag <> 0) then
              CharHlp.PrintBottomLine(existName + ' will tolerate no evil!');
            Dispose(newChar);
          end;
        end;
      end;
  until (ch = 'E') or (ch = C_Keys.NONE) or (realCount > 5) or (GDVars.zone1^.partySize > 7);
  MenuCore.FreeStringList(displayList);
end;

procedure RemoveCreature;
var
  prev: Types.PCharRecord;
begin
  if GDVars.creatureList = nil then Exit;
  prev := GDVars.creatureList;
  if prev <> GDVars.curChar then begin
    while (prev^.nextCharAddr <> GDVars.curChar) and (prev^.nextCharAddr <> nil) do
      prev := prev^.nextCharAddr;
    if prev^.nextCharAddr <> nil then begin
      if freeAnim then
        MapTiles.FreeIconAnim(GDVars.curChar^.orderNumber);
      prev^.nextCharAddr := GDVars.curChar^.nextCharAddr;
      CharGen.FreeCreature(GDVars.curChar);
      GDVars.curChar := prev;
      if not suppressSizeDec then
        Dec(GDVars.zone1^.partySize);
    end;
  end else begin
    if freeAnim then
      MapTiles.FreeIconAnim(GDVars.curChar^.orderNumber);
    GDVars.creatureList := GDVars.curChar^.nextCharAddr;
    prev := GDVars.curChar^.nextCharAddr;
    CharGen.FreeCreature(GDVars.curChar);
    GDVars.curChar := prev;
    if not suppressSizeDec then
      Dec(GDVars.zone1^.partySize);
  end;
  if GDVars.curChar = nil then
    GDVars.curChar := GDVars.creatureList;
end;

procedure SetDefaultIcon;
begin
  with GDVars.curChar^ do begin
    if gender = CharGen.GENDER_FEMALE then begin
      if raceSize = 2 then
        portraitHead := 9
      else
        portraitHead := 7;
    end else begin
      if raceSize = 2 then
        portraitHead := 5
      else
        portraitHead := 0;
    end;
    if classLevelA[C_Class.CLERIC] > 0 then
      portraitBody := 23
    else if classLevelA[C_Class.RANGER] > 0 then
      portraitBody := 1
    else if (classLevelA[C_Class.PALADIN] > 0) or (classLevelA[C_Class.FIGHTER] > 0) then
      portraitBody := 24
    else if classLevelA[C_Class.MAGE] > 0 then
      portraitBody := 29
    else
      portraitBody := 5;
  end;
end;

procedure CustomizeIcon;

  { Draws the edited icon's two frames at a map cell, over a cursor backdrop outside CGA. }
  procedure ShowIconFrames(row, col: Byte);
  begin
    if GDVars.displayMode = Types.Cga then
      Blit.FillPicRect(row * 3, col * 24, 12, 24, 3, GDConsts.cmapStd, GDVars.viewBuf)
    else begin
      Blit.FillPicRect(row * 3, col * 24, 12, 24, 0, GDConsts.cmapStd, GDVars.viewBuf);
      MapTiles.DrawIconAnimSprite(row, col, 0, 0, 25);

      MapTiles.DrawIconAnimSprite(row + 3, col, 0, 0, 25);
    end;
    MapTiles.DrawIconAnimSprite(row, col, 0, 0, 12);
    MapTiles.DrawIconAnimSprite(row + 3, col, 0, 1, 12);
    Blit.FlushView;
  end;

  { Copies an icon slot's two frames to another, recoloring them with the character's icon colors when asked. }
  procedure CopyIconPics(src, dst, rebuild: Byte);
  var
    i: Byte;
    { Unused in this version; see the other implementations of this routine. }
    frameIdx: Byte;
    grid1: Types.TColorTab;
    grid2: Types.TColorTab;
    cnt: Word;
  begin
    cnt := GDVars.iconAnims[dst, 0]^.imgSize;
    Move(GDVars.iconAnims[src, 0]^.data, GDVars.iconAnims[dst, 0]^.data, GDVars.iconAnims[dst, 0]^.imgSize);
    Move(GDVars.iconAnims[src, 1]^.data, GDVars.iconAnims[dst, 1]^.data, GDVars.iconAnims[dst, 1]^.imgSize);
    Move(GDVars.iconAnims[src, 0]^.transp^, GDVars.iconAnims[dst, 0]^.transp^, cnt);
    Move(GDVars.iconAnims[src, 1]^.transp^, GDVars.iconAnims[dst, 1]^.transp^, cnt);
    if rebuild <> 0 then
      with GDVars.curChar^ do begin
        for i := 0 to 15 do begin
          grid1[i] := i;
          grid2[i] := i;
        end;

        for i := 1 to 6 do begin
          grid2[GDConsts.statInitTbl[i]] := statPack[i] and $F;
          grid2[GDConsts.statInitTbl[i] + 8] := (statPack[i] and $F0) shr 4;
        end;
        Blit.RemapPic(grid1, grid2, 0, False, GDVars.iconAnims[dst, 0]);
        Blit.RemapPic(grid1, grid2, 0, False, GDVars.iconAnims[dst, 1]);
      end;
  end;

var
  { Unused in this version; see the other implementations of this routine. }
  oldState: Byte;
  ch: Char;
  escFlag: Boolean;
  savedHead: Byte;
  savedBody: Byte;
  { the entry raceSize }
  savedIcon: Byte;
  savedOrder: Byte;
  { 1..5, the menu state }
  state: Byte;
  { 'Small' / 'Large' / '' }
  sizeName: string[5];
  { Unused in this version; see the other implementations of this routine. }
  partSlot: Byte;
  { entry copy of statPack }
  iconData: Types.TStatPack;
  { 1..6, which icon part }
  partIdx: Byte;
  { 0 = hair, 1 = face }
  colorMode: Byte;
  { low nibble }
  sizeVal: Byte;
  { high nibble }
  colVal: Byte;
  { state to return to }
  retState: Byte;
  subKey: Char;
begin
  Border.DrawWindowFrame(1);
  CbtMap.SetCombatPalette;
  repeat
    SaveLoad.LoadCharIconAnim(False);
    with GDVars.curChar^ do begin
      state := 1;
      iconData := statPack;
      savedOrder := orderNumber;
      orderNumber := 12;
      SaveLoad.LoadCharIconAnim(False);
      orderNumber := savedOrder;
      savedHead := portraitHead;
      savedBody := portraitBody;
      savedIcon := raceSize;
      CopyIconPics(orderNumber, 12, 1);
      ShowIconFrames(1, 2);
      TextRend.DisplayString(8, 6, White, 0, 'old');
      TextRend.DisplayString(3, 10, White, 0, 'ready   action');
      TextRend.DisplayString(8, 12, White, 0, 'new');
      TextRend.DisplayString(3, 16, White, 0, 'ready   action');
      repeat
        ShowIconFrames(1, 4);
        sizeName := '';
        if state = 4 then begin
          if raceSize = 2 then
            sizeName := 'Small'
          else
            sizeName := 'Large';
        end;
        ch := MenuCore.MenuHorizontal('', sizeName + GDConsts.hMenuTable[state], LightMagenta, LightGreen, White, 0, 0,
                                      escFlag);
        if not escFlag then
          case state of
            1: begin
                 retState := 1;
                 case ch of
                   'P': state := 2;
                   '1': if GDVars.displayMode = Types.Cga then
                          TextRend.PrintAndPause('Sorry, not in CGA', Yellow, 0)
                        else begin
                          state := 3;
                          colorMode := 0;
                          Delete(GDConsts.hMenuTable[3], 13, 4);
                          Insert('Hair', GDConsts.hMenuTable[3], 13);
                        end;
                   '2': if GDVars.displayMode = Types.Cga then
                          TextRend.PrintAndPause('Sorry, not in CGA', Yellow, 0)
                        else begin
                          state := 3;
                          colorMode := 1;
                          Delete(GDConsts.hMenuTable[3], 13, 4);
                          Insert('Face', GDConsts.hMenuTable[3], 13);
                        end;
                   'S': state := 4;
                 end;
               end;
            2: begin
                 retState := 2;
                 if ch in [C_Keys.NONE, 'E'] then
                   state := 1
                 else begin
                   subKey := ch;
                   state := 5;
                 end;
               end;
            3: begin
                 retState := 3;
                 case ch of
                   'W': partIdx := 6;
                   'B': partIdx := 1;
                   'H': partIdx := 4;
                   'F': partIdx := 4;
                   'S': partIdx := 5;
                   'A': partIdx := 2;
                   'L': partIdx := 3;
                 else
                   partIdx := 1;
                 end;
                 if ch in [C_Keys.NONE, 'E'] then
                   state := 1
                 else
                   state := 5;
               end;
            4: begin
                 case ch of
                   'L': begin raceSize := 2; SaveLoad.LoadCharIconAnim(False); end;
                   'S': begin raceSize := 1; SaveLoad.LoadCharIconAnim(False); end;
                   'K': begin
                          savedIcon := raceSize;
                          state := 1;
                          ch := ' ';
                        end;
                   'E', C_Keys.NONE: begin
                              raceSize := savedIcon;
                              state := 1;
                              ch := ' ';
                            end;
                 end;
                 SaveLoad.LoadCharIconAnim(False);
               end;
            5: case retState of
                 2: case subKey of
                      'H':
                        begin
                          case ch of
                            'P': if portraitHead > 0 then
                                   Dec(portraitHead)
                                 else
                                   portraitHead := 13;
                            'N': if portraitHead < 13 then
                                   Inc(portraitHead)
                                 else
                                   portraitHead := 0;
                            'K': begin
                                   with GDVars.curChar^ do
                                     savedHead := portraitHead;
                                   state := retState;
                                   ch := ' ';
                                 end;
                            'E', C_Keys.NONE: begin
                                       portraitHead := savedHead;
                                       state := retState;
                                       ch := ' ';
                                     end;
                          end;
                          SaveLoad.LoadCharIconAnim(False);
                        end;
                      'W':
                        begin
                          case ch of
                            'P': if portraitBody > 0 then
                                   Dec(portraitBody)
                                 else
                                   portraitBody := 31;
                            'N': if portraitBody < 31 then
                                   Inc(portraitBody)
                                 else
                                   portraitBody := 0;
                            'K': begin
                                   with GDVars.curChar^ do
                                     savedBody := portraitBody;
                                   state := retState;
                                   ch := ' ';
                                 end;
                            'E', C_Keys.NONE: begin
                                       portraitBody := savedBody;
                                       state := retState;
                                       ch := ' ';
                                     end;
                          end;
                          SaveLoad.LoadCharIconAnim(False);
                        end;
                    end;
                 3: begin
                      sizeVal := statPack[partIdx] and $F;
                      colVal := (statPack[partIdx] and $F0) shr 4;
                      case ch of
                        'N': begin
                               if colorMode <> 0 then
                                 colVal := (colVal + 1) mod 16
                               else
                                 sizeVal := (sizeVal + 1) mod 16;
                               statPack[partIdx] := (colVal shl 4) + sizeVal;
                             end;
                        'P': begin
                               if colorMode <> 0 then
                                 colVal := (colVal - 1) and $F
                               else
                                 sizeVal := (sizeVal - 1) and $F;
                               statPack[partIdx] := (colVal shl 4) + sizeVal;
                             end;
                        'K': begin
                               iconData := statPack;
                               state := retState;
                               ch := ' ';
                             end;
                        'E', C_Keys.NONE: begin
                                   statPack := iconData;
                                   state := retState;
                                   ch := ' ';
                                 end;
                      end;
                    end;
               end;
          end;
        CopyIconPics(orderNumber, 12, 1);
      until (retState = 1) and (ch in [C_Keys.NONE, 'E']);
      portraitHead := savedHead;
      portraitBody := savedBody;
      raceSize := savedIcon;
      statPack := iconData;
      CopyIconPics(orderNumber, 12, 1);
      CopyIconPics(12, orderNumber, 0);
    end;
    MenuCore.ClearBottomLine;
    MapTiles.FreeIconAnim(12);

    ch := MenuCore.YesNoMenu('Is this icon ok? ', LightMagenta, LightGreen, White, 1);
  until ch = 'Y';
  CbtMap.SetNoncombatPalette;
end;

function ConHpBonus;
var
  bonus: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  classIdx: Byte;
begin
  bonus := 0;
  Inc(bonus, GDConsts.conBonusTbl[cr^.stats[C_Stat.CONSTITUTION].cur]);
  if (cls = C_Class.FIGHTER) or (cls = C_Class.RANGER)
     or (cls = C_Class.PALADIN) then
    case cr^.stats[C_Stat.CONSTITUTION].cur of
      17: Inc(bonus);
      18: Inc(bonus, 2);
      19, 20: Inc(bonus, 3);
      21..23: Inc(bonus, 4);
      24, 25: Inc(bonus, 5);
    end;
  ConHpBonus := bonus;
end;

function HpMinimum;
var
  clsCount: Byte;
  conB: ShortInt;
  sum: Byte;
  cls: ShortInt;
begin
  with cr^ do begin
    conB := 0;
    clsCount := 0;
    sum := 0;
    for cls := C_Class.CLERIC to C_Class.THIEF do
      if classLevelA[cls] > 0 then begin
        Inc(sum, classLevelA[cls]);
        Inc(clsCount);
        case cls of
          C_Class.RANGER: Inc(sum);
        end;
        Inc(conB, CharGen.ConHpBonus(cr, cls));
      end;
  end;
  if conB < 0 then begin
    if sum > Abs(conB) + clsCount then
      sum := (sum + conB) div clsCount
    else
      sum := 1;
  end else
    sum := (sum + conB) div clsCount;
  HpMinimum := sum;
end;

function HpMaximum;
var
  clsCount: Byte;
  total: Byte;
  adj: ShortInt;
  cls: ShortInt;
  over: Byte;
begin
  with cr^ do begin
    clsCount := 0;
    total := 0;
    for cls := C_Class.CLERIC to C_Class.THIEF do
      if classLevelA[cls] > 0 then begin
        adj := CharGen.ClassConAdj(cls);
        if classLevelA[cls] < GDConsts.firstFixedHpLevel[cls] then begin
          Inc(clsCount);
          case cls of
            C_Class.CLERIC: Inc(total, (adj + 8) * classLevelA[cls]);
            CharGen.CLASS_DRUID: Inc(total, (adj + 8) * classLevelA[cls]);
            C_Class.FIGHTER, C_Class.PALADIN:
              Inc(total, (adj + 10) * classLevelA[cls]);
            C_Class.RANGER:
              Inc(total, (adj + 8) * (classLevelA[cls] + 1));
            C_Class.MAGE: Inc(total, (adj + 4) * classLevelA[cls]);
            C_Class.THIEF: Inc(total, (adj + 6) * classLevelA[cls]);
          end;
        end else begin
          Inc(clsCount);
          over := classLevelA[cls] - GDConsts.firstFixedHpLevel[cls] + 1;
          case cls of
            C_Class.CLERIC: total := over * 2 + 72;
            CharGen.CLASS_DRUID: total := 112;
            C_Class.FIGHTER, C_Class.PALADIN, C_Class.RANGER:
              total := over * 2 + 88;
            C_Class.MAGE: total := over + 44;
            C_Class.THIEF: total := over * 2 + 60;
          end;
        end;
      end;
  end;
  total := total div clsCount;
  HpMaximum := total;
end;

procedure RollFirstLevelHp;
var
  best: Byte;
  roll2: Byte;
  hpTotal: Byte;
  dice: Byte;
  conTotal: Byte;
  i: ShortInt;
begin
  hpTotal := 0;
  conTotal := 0;
  for i := C_Class.CLERIC to C_Class.THIEF do begin

    if (cr^.classLevelA[i] > 0) and ((GDConsts.rollClassMaskTbl[i] and mask) > 0) then begin
      if cr^.classLevelA[i] < GDConsts.firstFixedHpLevel[i] then begin
        if cr^.classLevelA[i] > 1 then
          dice := 1
        else
          dice := GDConsts.firstLevelDiceTbl[i];
        best := FxEngine.RollDice(dice, GDConsts.hitDieSidesTbl[i]);
        roll2 := FxEngine.RollDice(dice, GDConsts.hitDieSidesTbl[i]);
        if roll2 > best then
          best := roll2;
        Inc(hpTotal, best);
        Inc(conTotal, dice * CharGen.ConHpBonus(cr, i));
      end else

        case i of
          C_Class.FIGHTER, C_Class.PALADIN: hpTotal := 3;
          C_Class.RANGER, C_Class.CLERIC, C_Class.THIEF: hpTotal := 2;
          C_Class.MAGE: hpTotal := 1;
        end;
    end;
  end;
  with cr^ do begin
    hpTotal := hpTotal div divisor;
    if hpTotal < 1 then
      hpTotal := 1;
    Inc(hpRolled, hpTotal);
    conTotal := conTotal div divisor;
    best := hpMax - hpCur;
    Inc(hpMax, hpTotal + conTotal);
    hpCur := hpMax - best;
  end;
end;

procedure TrainingMenu;
var
  atLimit: Boolean;
  { highest met next-level XP - 1 }
  bestXp: LongInt;
  xpTmp: LongInt;
  { trainable-now class bits }
  maskA: Byte;
  { all-party-class bits }
  maskB: Byte;
  { maskA masked by trainableHere }
  trainHere: Byte;
  classCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hpTotal: Integer;
  { Unused in this version; see the other implementations of this routine. }
  avgHp: Integer;
  { Unused in this version; see the other implementations of this routine. }
  hpDelta: Byte;
  { class index }
  i: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  conBonusV: Integer;
  { display row }
  row: Byte;
  { the mage level before training }
  oldLvl5: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  oldRangerLevel: ShortInt;
  { classLevelA[i] }
  curLvl: ShortInt;
  { SpellMenu pick }
  selResult: Byte;
  { SpellMenu var idx }
  sentinel: Integer;
  selIdx: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  selClass: Byte;
  { classes this trainer teaches }
  trainableHere: Byte;
  { auto-mode best next-level XP }
  bestXp2: LongInt;
  { auto-mode class }
  bestClass: ShortInt;
  eff: Types.PEffectRec;
begin
  if GDVars.newCharTraining = 0 then
    if not ViewChar.PickCharacter then Exit;
  if (GDVars.curChar^.status <> C_Status.OKAY) and (GDVars.freeTraining = 0) then begin
    TextRend.PrintAndPause('we only train conscious people', Yellow, 0);
    Exit;
  end;

  maskA := 0;
  maskB := 0;
  bestXp := 0;
  trainableHere := GDVars.zone1^.trainMaskLo;

  with GDVars.curChar^ do begin
    bestXp := 0;
    for i := C_Class.CLERIC to C_Class.THIEF do
      if classLevelA[i] > 0 then begin
        Inc(maskB, GDConsts.rollClassMaskTbl[i]);
        atLimit := False;
        curLvl := classLevelA[i];
        { no arm for Human: AD&D gives humans no level limit }
        case race of
          C_Race.DWARF: begin
               if i = C_Class.FIGHTER then
                 if (curLvl = 9)
                    or ((curLvl = 8) and (stats[C_Stat.STRENGTH].cur = 17))
                    or ((curLvl = 7) and (stats[C_Stat.STRENGTH].cur < 17)) then atLimit := True;
               if (i = C_Class.CLERIC) and (curLvl >= 8) then atLimit := True;
             end;
          C_Race.ELF: begin
               if i = C_Class.FIGHTER then
                 if (curLvl = 7)
                    or ((curLvl = 6) and (stats[C_Stat.STRENGTH].cur = 17))
                    or ((curLvl = 5) and (stats[C_Stat.STRENGTH].cur < 17)) then atLimit := True;
               if i = C_Class.MAGE then
                 if (curLvl = 11)
                    or ((curLvl = 9) and (stats[C_Stat.INTELLIGENCE].cur < 17))
                    or ((curLvl = 10) and (stats[C_Stat.INTELLIGENCE].cur = 17)) then atLimit := True;
               if (i = C_Class.CLERIC) and (curLvl >= 7) then atLimit := True;
             end;
          C_Race.GNOME: begin
               if i = C_Class.FIGHTER then
                 if (curLvl = 6)
                    or ((curLvl = 5) and (stats[C_Stat.STRENGTH].cur < 18)) then atLimit := True;
               if (i = C_Class.CLERIC) and (curLvl >= 7) then atLimit := True;
             end;
          C_Race.HALF_ELF: if (i = C_Class.CLERIC) and (curLvl = 5) then atLimit := True
             else begin
               if (i = C_Class.FIGHTER) or (i = C_Class.RANGER) then
                 if (curLvl = 8)
                    or ((curLvl = 7) and (stats[C_Stat.STRENGTH].cur = 17))
                    or ((curLvl = 6) and (stats[C_Stat.STRENGTH].cur < 17)) then atLimit := True;
               if i = C_Class.MAGE then
                 if (curLvl = 8)
                    or ((curLvl = 7) and (stats[C_Stat.INTELLIGENCE].cur = 17))
                    or ((curLvl = 6) and (stats[C_Stat.INTELLIGENCE].cur < 17)) then atLimit := True;
             end;
          C_Race.HALFLING: if i = C_Class.FIGHTER then
               if (curLvl = 6)
                  or ((curLvl = 5) and (stats[C_Stat.STRENGTH].cur = 17))
                  or ((curLvl = 4) and (stats[C_Stat.STRENGTH].cur < 17)) then atLimit := True;
        end;
        if not atLimit then
          if (GDConsts.classProgression[i].nextLevelXp[Succ(curLvl)] <= experience) or (GDVars.freeTraining <> 0) then
            if GDConsts.classProgression[i].nextLevelXp[Succ(curLvl)] > 0 then begin
              if GDVars.freeTraining <> 0 then
                if GDConsts.classProgression[i].nextLevelXp[Succ(curLvl)] > 0 then
                  if GDConsts.classProgression[i].nextLevelXp[Succ(curLvl)] > experience then
                    experience := GDConsts.classProgression[i].nextLevelXp[Succ(curLvl)];
              Inc(maskA, GDConsts.rollClassMaskTbl[i]);
              xpTmp := GDConsts.classProgression[i].nextLevelXp[Succ(Succ(curLvl))];
              if (xpTmp > 0) and (experience >= xpTmp) and (xpTmp > bestXp) then
                bestXp := xpTmp - 1;
            end;
      end;

    if GDVars.newCharTraining = 0 then begin
      bestXp2 := 0;
      xpTmp := 0;
      for i := C_Class.CLERIC to C_Class.THIEF do
        if (GDConsts.rollClassMaskTbl[i] and maskA) <> 0 then
          if GDConsts.classProgression[i].nextLevelXp[Succ(curLvl)] > bestXp2 then begin
            bestXp2 := GDConsts.classProgression[i].nextLevelXp[Succ(curLvl)];
            bestClass := i;
          end;
      if bestXp2 > 0 then begin
        maskA := maskA or GDConsts.rollClassMaskTbl[bestClass];
        xpTmp := GDConsts.classProgression[bestClass].nextLevelXp[Succ(Succ(curLvl))];
        if (xpTmp > 0) and (experience >= xpTmp) and (xpTmp > bestXp) then
          bestXp := xpTmp - 1;
      end;
    end;

    if (bestXp > 0) and (GDVars.newCharTraining = 0) then
      experience := bestXp;

    if GDVars.freeTraining = 0 then begin
      if ((maskB and trainableHere) = 0) and (GDVars.newCharTraining = 0) then begin
        TextRend.PrintAndPause('We don''t train that class here', Yellow, 0);
        Exit;
      end else if (maskA and trainableHere) = 0 then begin
        GDVars.trainMenuDone := 1;
        if GDVars.newCharTraining = 0 then
          TextRend.PrintAndPause('Not Enough Experience', Yellow, 0);
        Exit;
      end;
    end;

    if GDVars.freeTraining = 0 then trainHere := maskA and trainableHere
    else trainHere := maskA;

    if GDVars.newCharTraining = 0 then begin
      Border.ClearBox(1, 1, 38, 22);
      row := 4;
      CharHlp.DisplayCreatureName(GDVars.curChar, 4, row, False);
      TextRend.DisplayString(Length(name) + 4, row, LightGreen, 0, ' will become:');
      for i := C_Class.CLERIC to C_Class.THIEF do
        if classLevelA[i] > 0 then
          if (GDConsts.rollClassMaskTbl[i] and trainHere) > 0 then begin
            Inc(row);
            if row = 5 then
              TextRend.DisplayString(6, row, LightGreen, 0,
                            '    a level ' + CharHlp.Uint8Str(classLevelA[i] + 1) + ' ' + GDConsts.classNames[i])
            else
              TextRend.DisplayString(6, row, LightGreen, 0,
                            'and a level ' + CharHlp.Uint8Str(classLevelA[i] + 1) + ' ' + GDConsts.classNames[i]);
          end;
      if MenuCore.YesNoMenu('Do you wish to train? ', LightMagenta, LightGreen, White, 1) <> 'Y' then Exit;
      CharHlp.PrintBottomLine('Congratulations...');
    end;

    classCount := 0;
    oldLvl5 := classLevelA[C_Class.MAGE];
    oldRangerLevel := classLevelA[C_Class.RANGER];
    classMask := 0;
    for i := C_Class.CLERIC to C_Class.THIEF do
      if classLevelA[i] > 0 then begin
        Inc(classCount);
        if (GDConsts.rollClassMaskTbl[i] and trainHere) > 0 then begin
          Inc(classLevelA[i]);
          if drainedLevels > 0 then begin
            Dec(drainedHps, drainedHps div drainedLevels);
            Dec(drainedLevels);
          end;
        end;
      end;
    ClassCal.RecalcClassStats(GDVars.curChar);

    if GDVars.newCharTraining = 0 then begin
      if (classLevelA[C_Class.MAGE] > oldLvl5) or (classLevelA[C_Class.RANGER] > 8) then begin

        sentinel := -1;
        repeat
          selResult := ViewChar.SpellMenu(4, 4, sentinel, selIdx);
        until (selResult > 0) or (not selIdx);
        if selResult > 0 then
          known[selResult] := 1;
      end;

      if ClassCal.EarlierClassActive(GDVars.curChar) then begin
        if GDVars.curChar^.classLevelB[C_Class.RANGER] > 0 then
          if not CharHlp.HasEffect(GDVars.curChar, C_Effect.RANGER_DAMAGE_BONUS, eff) then
            FxEngine.AddEffect(GDVars.curChar, C_Effect.RANGER_DAMAGE_BONUS, 0, 255, 0);
        if GDVars.curChar^.classLevelB[C_Class.PALADIN] > 0 then
          if not CharHlp.HasEffect(GDVars.curChar, C_Effect.PROTECTION_FROM_EVIL, eff) then
            FxEngine.AddEffect(GDVars.curChar, C_Effect.PROTECTION_FROM_EVIL, 0, 255, 0);
      end;
    end;

    if GDVars.newCharTraining <> 0 then
      case classLevelA[C_Class.MAGE] of
        6: begin
             known[12] := 1; known[15] := 1; known[30] := 1; known[3] := 1;
             known[34] := 1; known[47] := 1; known[51] := 1; known[54] := 1;
           end;
        7: begin
             known[14] := 1; known[16] := 1; known[29] := 1; known[35] := 1;
             known[45] := 1; known[48] := 1; known[81] := 1;
           end;
        8: begin
             known[10] := 1; known[9] := 1; known[32] := 1; known[55] := 1;
             known[85] := 1;
           end;
        9: begin
             known[50] := 1; known[52] := 1; known[82] := 1; known[88] := 1;
             known[94] := 1;
           end;
      end;

    if highestLevel > dualClassThreshold then
      CharGen.RollFirstLevelHp(GDVars.curChar, trainHere, classCount);
  end;
end;

procedure InitMouseJoystick;
var
  { the 3-node menu list }
  list: Types.PItemRec;
  { fill cursor }
  node: Types.PItemRec;
  done: Byte;
  key: Char;
  { set to have MenuVertical repaint the list }
  menuRedraw: Boolean;
  { MenuVertical's var cnt = the row }
  sel: Integer;
  mb: Integer;
  { GetMouse x }
  mx: Integer;
  my: Integer;
  { MenuVertical's var cur }
  cur: Types.PItemRec;
  cfgIn: Text;
  cfgOut: Text;
  { every loop shares it }
  i: Byte;
  line: array[1..5] of String;
  items: array[1..3] of Types.TStr40;
begin
  MenuCore.AllocStringList(3, list);
  menuRedraw := True;
  done := 0;
  cur := list;
  sel := 0;
  repeat

    Assign(cfgIn, GDConsts.cfgName);
    Reset(cfgIn);
    for i := 1 to 5 do
      ReadLn(cfgIn, line[i]);
    Close(cfgIn);

    if GDVars.mouseOn then items[1] := 'mouse ON' else items[1] := 'mouse OFF';
    if GDVars.joyOn then items[2] := 'joystick ON' else items[2] := 'joystick OFF';
    items[3] := 'disable both';

    node := list;
    for i := 1 to 3 do begin
      node^.name := items[i];
      node^.isHeader := 0;
      node := node^.next;
    end;

    menuRedraw := True;
    key := MenuCore.MenuVertical('Init Mouse/Joystick: ', 'Select', LightMagenta, LightGreen, White, 9, 12, 38, 22,
                                 list, 1, menuRedraw, sel, cur);
    if key = 'S' then
      case sel of
        0:
          begin

            GDVars.mouseOn := GDVars.mouseOn = False;
            Assign(cfgOut, GDConsts.cfgName);
            Rewrite(cfgOut);
            if GDVars.mouseOn then begin
              GDVars.rosterMouseOn := 1;
              GDVars.buttonCount := 0;
              Mouse.InitMouse;

              if GDVars.mouseOn then begin
                if GDVars.displayMode = Types.Cga then
                  GDVars.cursorMask := @GDConsts.cursorMaskCga
                else
                  GDVars.cursorMask := @GDConsts.cursorMaskHi;
                Mouse.SetMouseCursor(0, 0, GDVars.cursorMask);
                GDVars.mouseScaled := True;

                Mouse.SetMouse(639, 100);
                Mouse.GetMouse(mb, mx, my);
                GDVars.mouseScaled := (mx >= 321) = False;
                GDVars.joyOn := False;
                Mouse.ShowMouse;
                line[3] := 'M';
                for i := 1 to 5 do
                  WriteLn(cfgOut, line[i]);
                for i := 0 to 13 do
                  WriteLn(cfgOut, '0');
                Close(cfgOut);
                GDVars.mouseX := 160;
                GDVars.mouseY := 100;
                GDVars.mouseOldX := 0;
                GDVars.mouseOldY := 0;
              end;
            end;
            if not GDVars.mouseOn then begin
              line[3] := 'N';
              for i := 1 to 5 do
                WriteLn(cfgOut, line[i]);
              for i := 0 to 13 do
                WriteLn(cfgOut, '0');
              Close(cfgOut);

              GDVars.mouseOn := True;
              Mouse.HideMouse;
              GDVars.mouseOn := False;
            end;
          end;
        1:
          begin

            GDVars.joyOn := GDVars.joyOn = False;
            Assign(cfgOut, GDConsts.cfgName);
            Rewrite(cfgOut);
            if GDVars.joyOn then begin
              CharGen.CalibrateJoystickInWindow;

              if GDVars.joyOn then begin
                line[3] := 'J';
                for i := 1 to 5 do
                  WriteLn(cfgOut, line[i]);
                for i := 0 to 6 do begin
                  WriteLn(cfgOut, GDVars.joyCal[1].x.words[i]);
                  WriteLn(cfgOut, GDVars.joyCal[1].y.words[i]);
                end;
                Close(cfgOut);
                if GDVars.joyOn then begin
                  Mouse.HideMouse;
                  GDVars.mouseOn := False;
                end;
              end;
            end;
            if not GDVars.joyOn then begin
              line[3] := 'N';
              for i := 1 to 5 do
                WriteLn(cfgOut, line[i]);
              for i := 0 to 13 do
                WriteLn(cfgOut, '0');
              Close(cfgOut);
            end;
          end;
        2:
          begin

            GDVars.joyOn := False;
            Mouse.HideMouse;
            GDVars.mouseOn := False;
            Assign(cfgOut, GDConsts.cfgName);
            Rewrite(cfgOut);
            line[3] := 'N';
            for i := 1 to 5 do
              WriteLn(cfgOut, line[i]);
            for i := 0 to 13 do
              WriteLn(cfgOut, '0');
            Close(cfgOut);
          end;
      end else
      done := 1;
  until done <> 0;
  MenuCore.FreeStringList(list);
end;

procedure CalibrateJoystickInWindow;
var
  { accumulator, then min, then max }
  sumX: Word;
  sumY: Word;
  { last ReadJoystick result }
  ok: Byte;
  x: Word;
  y: Word;
  { Unused in this version; see the other implementations of this routine. }
  sampleIndex: Byte;
  { the 20000-iteration button wait }
  j: Word;
  buttons: Byte;
begin
  Joystick.ProbeJoystick;
  if not GDVars.joyOn then Exit;

  sumX := 0;
  sumY := 0;
  for j := 1 to 20 do begin
    ok := Byte(Joystick.ReadJoystick(1, x, y, buttons));
    Inc(sumX, x);
    Inc(sumY, y);
  end;
  GDVars.joyCal[1].x.thr[3] := sumX div 20;
  GDVars.joyCal[1].y.thr[3] := sumY div 20;

  repeat
    Border.ClearBox(1, 1, 38, 22);
    TextRend.DisplayString(1, 3, LightMagenta, 0, 'Push JOYSTICK #1 to the extreme upper');
    TextRend.DisplayString(1, 5, LightMagenta, 0, 'left position and press button #1.');
    j := 0;
    repeat
      ok := Byte(Joystick.ReadJoystick(1, x, y, buttons));
      Inc(j);
    until (j > 20000) or ((ok <> 0) and ((buttons and 1) <> 0));
    if j > 20000 then begin
      Border.ClearBox(1, 1, 38, 22);
      TextRend.DisplayString(1, 3, LightMagenta, 0, 'Unable to read joystick');
      Delay(2000);
      Exit;
    end;
    sumX := 65535;
    sumY := 65535;
    for GDVars.loopIdx := 1 to 20 do begin
      if Joystick.ReadJoystick(1, x, y, buttons) then begin
        if (buttons and 1) <> 0 then begin
          if x < sumX then sumX := x;
          if y < sumY then sumY := y;
        end;
      end else begin
        Border.ClearBox(1, 1, 38, 22);
        TextRend.DisplayString(1, 3, LightMagenta, 0, 'Unable to read joystick');
        Delay(2000);
        Exit;
      end;
    end;
  until ok <> 0;

  GDVars.joyCal[1].x.lo := sumX;
  GDVars.joyCal[1].x.thr[1] := GDVars.joyCal[1].x.lo + (GDVars.joyCal[1].x.thr[3] - GDVars.joyCal[1].x.lo) div 3;
  GDVars.joyCal[1].x.thr[2] := GDVars.joyCal[1].x.lo + (GDVars.joyCal[1].x.thr[3] - GDVars.joyCal[1].x.lo) * 2 div 3;
  GDVars.joyCal[1].y.lo := sumY;
  GDVars.joyCal[1].y.thr[1] := GDVars.joyCal[1].y.lo + (GDVars.joyCal[1].y.thr[3] - GDVars.joyCal[1].y.lo) div 3;
  GDVars.joyCal[1].y.thr[2] := GDVars.joyCal[1].y.lo + (GDVars.joyCal[1].y.thr[3] - GDVars.joyCal[1].y.lo) * 2 div 3;

  repeat until not Joystick.JoyButton(1, 1);

  repeat
    Border.ClearBox(1, 1, 38, 22);
    TextRend.DisplayString(1, 3, LightMagenta, 0, 'Push JOYSTICK #1 to the extreme lower');
    TextRend.DisplayString(1, 5, LightMagenta, 0, 'right position and press button #1.');
    j := 0;
    repeat
      ok := Byte(Joystick.ReadJoystick(1, x, y, buttons));
      Inc(j);
    until (j > 20000) or ((ok <> 0) and ((buttons and 1) <> 0));
    if j > 20000 then begin
      Border.ClearBox(1, 1, 38, 22);
      TextRend.DisplayString(1, 3, LightMagenta, 0, 'Unable to read joystick');
      Delay(2000);
      Exit;
    end;
    sumX := 0;
    sumY := 0;
    for GDVars.loopIdx := 1 to 20 do begin
      if Joystick.ReadJoystick(1, x, y, buttons) then begin
        if (buttons and 1) <> 0 then begin
          if x > sumX then sumX := x;
          if y > sumY then sumY := y;
        end;
      end else begin
        Border.ClearBox(1, 1, 38, 22);
        TextRend.DisplayString(1, 3, LightMagenta, 0, 'Unable to read joystick');
        Delay(2000);
        Exit;
      end;
    end;
  until ok <> 0;
  GDVars.joyCal[1].x.hi := sumX;
  GDVars.joyCal[1].x.thr[4] := GDVars.joyCal[1].x.thr[3] + (GDVars.joyCal[1].x.hi - GDVars.joyCal[1].x.thr[3]) div 3;
  GDVars.joyCal[1].x.thr[5] := GDVars.joyCal[1].x.thr[3] +
    (GDVars.joyCal[1].x.hi - GDVars.joyCal[1].x.thr[3]) * 2 div 3;
  GDVars.joyCal[1].y.hi := sumY;
  GDVars.joyCal[1].y.thr[4] := GDVars.joyCal[1].y.thr[3] + (GDVars.joyCal[1].y.hi - GDVars.joyCal[1].y.thr[3]) div 3;
  GDVars.joyCal[1].y.thr[5] := GDVars.joyCal[1].y.thr[3] +
    (GDVars.joyCal[1].y.hi - GDVars.joyCal[1].y.thr[3]) * 2 div 3;
  GDVars.joyOn := True;
end;

{ Does nothing; the coins are taken elsewhere.
  @param(gp Unused.)
  @param(cr Unused.) }
procedure TakeCoins(gp: LongInt; cr: Types.PCharRecord);
begin
end;

begin
end.

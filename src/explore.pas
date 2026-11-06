{ The dungeon action menu. }
{$O+,F+}
unit Explore;

interface

uses Blit, Border, Types, Crt, Camp, ViewChar, GameTime, FxEngine, CharHlp, ClassCal, MenuCore, Portrait, SoundDrv,
  TextRend, View3D, GDConsts, GDVars, C_Status, C_Class, C_Keys, C_Ifc, C_Dir, C_Stat;

{ Carries out the step the map menu asked for. In the 3D view, an open way (barrier type 1) moves the party; a locked
  barrier (types 2 and 3) offers Bash, Pick and Knock as the door flags, the party's thieves and its memorized Knock
  spells allow, and when nothing can be offered ChangeBarrierImpassable is called. On a held barrier (type 3) Pick only
  uses up the attempt. When the zone's move lock is 255 the lock is cleared instead. The portraits and the big animation
  are freed on the way out. }
procedure ResolveMovement;

{ Runs the map menu until the party moves or leaves it. In the 3D view the menu offers Move, Area, Cast, View, Encamp,
  Search and Look: Move switches to arrow-key movement (forward, turn around, turn left, turn right) with Exit; Area
  turns the automap on or off where the area allows it or the second parameter matches stingKey, else shows 'Not Here';
  Cast needs the current character to be okay; Search turns searching on or off; Look searches the spot for ten minutes
  and points the script at its search entry. Extended keys change the current character. Outside the 3D view no menu
  runs. The bottom window is cleared once afterwards.
  @returns(The key that ended the menu.) }
function MapMainMenu: Char;

{ Meant to clear the barrier bits of one side of a map cell. Note: it exits at once, so nothing is changed.
  @param(a Cell column.)
  @param(b Cell row.)
  @param(c Side of the cell.) }
procedure ChangeBarrierImpassable(a, b: ShortInt; c: Byte);

{ Opens the barrier on one side of a 3D map cell (barrier type 1). A cell outside the 16x16 map is ignored.
  @param(a Map column of the cell.)
  @param(b Map row of the cell.)
  @param(c The side, a cardinal direction.) }
procedure ChangeBarrierPassable(a, b: ShortInt; c: Byte);

{ Tells whether any party member has levels in a class, counting a former class only while ClassCal.EarlierClassActive
  says it still applies.
  @param(idx The class.)
  @returns(True when a member has the class.) }
function PartyHasClass(idx: ShortInt): Boolean;

{ Has each party member in turn try to bash open the barrier ahead until one succeeds, by Strength: a held barrier (type
  3) needs Strength 18/91 or more, and a weaker member marks it unbashable; other barriers use the plain Strength table.
  On success both sides of the barrier become open.
  @returns(True when the barrier was opened.) }
function BashDoor: Boolean;

{ Has the party pick the lock of the door ahead: each member in turn rolls d100 against its Open Locks skill, and the
  roll counts only for a member who is okay. The Pick choice closes at this door whatever the result. Success opens the
  door from both sides.
  @returns(True when the door was opened.) }
function PickLock: Boolean;

{ Finds a memorized spell in a character's spell slots.
  @param(spellId The spell.)
  @param(p The character.)
  @returns(The slot, or 255 when the spell is not memorized.) }
function FindMemorizedSpell(spellId: Byte; p: Types.PCharRecord): Byte;

{ Finds a party member with a spell memorized.
  @param(spellId The spell.)
  @returns(The first party member with it memorized, or nil.) }
function FindCharWithSpell(spellId: Byte): Types.PCharRecord;

{ Spends the first memorized Knock spell in the party.
  @returns(True when a member had Knock memorized.) }
function PartyCastsKnock: Boolean;

{ Clears the zone's leave-map flag, then, when the barrier ahead lets the party through and the step would leave the
  16x16 map, clamps the position to the edge and sets the flag. }
procedure MoveForward;

{ Steps the party one cell forward on the 3D map with the step sound and a short pause, wrapping at the map's edges,
  refreshes the wall ahead and the cell's event, reopens the door choices and advances the clock one minute, or one turn
  while searching. }
procedure MovePartyForward3D;

{ Does nothing. }
procedure NoopExplore;

implementation

const
  { the TCharRecord.thiefSkills column that Pick rolls against }
  THIEF_OPEN_LOCKS = 2;

procedure ChangeBarrierImpassable(a, b: ShortInt; c: Byte);
begin
  Exit;
  case c of
    C_Dir.WEST: GDVars.geo^.barriers[b, a] := GDVars.geo^.barriers[b, a] and $3F;
    C_Dir.SOUTH: GDVars.geo^.barriers[b, a] := GDVars.geo^.barriers[b, a] and $CF;
    C_Dir.EAST: GDVars.geo^.barriers[b, a] := GDVars.geo^.barriers[b, a] and $F3;
    C_Dir.NORTH: GDVars.geo^.barriers[b, a] := GDVars.geo^.barriers[b, a] and $FC;
  end;
end;

procedure ChangeBarrierPassable(a, b: ShortInt; c: Byte);
begin
  if (a < 0) or (a > 15) or (b < 0) or (b > 15) then Exit;
  case c of
      C_Dir.WEST: GDVars.geo^.barriers[b, a] := GDVars.geo^.barriers[b, a] and $3F or $40;
      C_Dir.SOUTH: GDVars.geo^.barriers[b, a] := GDVars.geo^.barriers[b, a] and $CF or $10;
      C_Dir.EAST: GDVars.geo^.barriers[b, a] := GDVars.geo^.barriers[b, a] and $F3 or $04;
      C_Dir.NORTH: GDVars.geo^.barriers[b, a] := GDVars.geo^.barriers[b, a] and $FC or $01;
    end;
end;

function PartyHasClass(idx: ShortInt): Boolean;
var
  cur: Types.PCharRecord;
  found: Boolean;
begin
  found := False;
  cur := GDVars.creatureList;
  while (cur <> nil) and not found do begin
    if (cur^.classLevelA[idx] > 0) or ((cur^.classLevelB[idx] > 0) and ClassCal.EarlierClassActive(cur)) then
      found := True;
    cur := cur^.nextCharAddr;
  end;
  PartyHasClass := found;
end;

function BashDoor: Boolean;
var
  cur: Types.PCharRecord;
  found: Boolean;
begin
  found := False;
  cur := GDVars.creatureList;
  while (cur <> nil) and not found do begin
    with cur^ do
    if View3D.GetBarrierType(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing) = 3 then begin
      case stats[C_Stat.STRENGTH].cur of
        18:
          case strExc of
            91..99: if FxEngine.RollDice(1, 6) = 1 then found := True;
            100: if FxEngine.RollDice(1, 6) <= 2 then found := True;
          else
            GDVars.bashOffered := 0;
          end;
        19, 20: if FxEngine.RollDice(1, 6) <= 3 then found := True;
        21, 22: if FxEngine.RollDice(1, 6) <= 4 then found := True;
        23: if FxEngine.RollDice(1, 6) <= 5 then found := True;
        24: if FxEngine.RollDice(1, 8) <= 7 then found := True;
        25: found := True;
      else
        GDVars.bashOffered := 0;
      end;
    end else begin
      case stats[C_Stat.STRENGTH].cur of
        3..7: if FxEngine.RollDice(1, 6) = 1 then found := True;
        8..15: if FxEngine.RollDice(1, 6) <= 2 then found := True;
        16..17: if FxEngine.RollDice(1, 6) <= 3 then found := True;
        18:
          case strExc of
            0..50: if FxEngine.RollDice(1, 6) <= 3 then found := True;
            51..99: if FxEngine.RollDice(1, 6) <= 4 then found := True;
            100: if FxEngine.RollDice(1, 6) <= 5 then found := True;
          end;
        19, 20: if FxEngine.RollDice(1, 8) <= 7 then found := True;
        21: if FxEngine.RollDice(1, 10) <= 9 then found := True;
        22, 23: if FxEngine.RollDice(1, 12) <= 11 then found := True;
        24: if FxEngine.RollDice(1, 20) <= 19 then found := True;
        25: found := True;
      end;
    end;
    cur := cur^.nextCharAddr;
  end;
  if found then begin
    Explore.ChangeBarrierPassable(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
    Explore.ChangeBarrierPassable(GDVars.partyPos.mapX + GDConsts.dirDx[GDVars.partyPos.facing],
                                  GDVars.partyPos.mapY + GDConsts.dirDy[GDVars.partyPos.facing],
                                  (GDVars.partyPos.facing + 4) mod 8);
  end;
  BashDoor := found;
end;

function PickLock: Boolean;
var
  cur: Types.PCharRecord;
  found: Boolean;
begin
  found := False;
  cur := GDVars.creatureList;
  while (cur <> nil) and not found do begin
    with cur^ do
      if (FxEngine.RollDice(1, 100) <= thiefSkills[Explore.THIEF_OPEN_LOCKS]) and
          (status = C_Status.OKAY) then found := True;
    cur := cur^.nextCharAddr;
  end;
  GDVars.pickOffered := 0;
  if found then begin
    Explore.ChangeBarrierPassable(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
    Explore.ChangeBarrierPassable(GDVars.partyPos.mapX + GDConsts.dirDx[GDVars.partyPos.facing],
                                  GDVars.partyPos.mapY + GDConsts.dirDy[GDVars.partyPos.facing],
                                  (GDVars.partyPos.facing + 4) mod 8);
  end;
  PickLock := found;
end;

function FindMemorizedSpell(spellId: Byte; p: Types.PCharRecord): Byte;
var
  i: Byte;
begin
  i := 0;
  while (i <= 74) and (p^.memorizedSpells[i] <> spellId) do Inc(i);
  if i <= 74 then FindMemorizedSpell := i
  else FindMemorizedSpell := 255;
end;

function FindCharWithSpell(spellId: Byte): Types.PCharRecord;
var
  cur: Types.PCharRecord;
begin
  cur := GDVars.creatureList;
  while (cur <> nil) and (Explore.FindMemorizedSpell(spellId, cur) = 255) do cur := cur^.nextCharAddr;
  FindCharWithSpell := cur;
end;

function PartyCastsKnock: Boolean;
var
  p: Types.PCharRecord;
begin
  p := Explore.FindCharWithSpell(31);
  if p <> nil then begin
    p^.memorizedSpells[Explore.FindMemorizedSpell(31, p)] := 0;
    PartyCastsKnock := True;
  end else PartyCastsKnock := False;
end;

procedure MoveForward;
var
  x: Integer;
  y: Integer;
  fc: Integer;
begin
  x := GDVars.partyPos.mapX;
  y := GDVars.partyPos.mapY;
  fc := GDVars.partyPos.facing;
  GDVars.zone1^.leaveMap := 0;
  if View3D.GetBarrierType(x, y, fc) <> 0 then begin
    Inc(x, GDConsts.dirDx[fc]);
    Inc(y, GDConsts.dirDy[fc]);
    if x > 15 then begin GDVars.partyPos.mapX := 15; GDVars.zone1^.leaveMap := 1; end;
    if x < 0 then begin GDVars.partyPos.mapX := 0; GDVars.zone1^.leaveMap := 1; end;
    if y > 15 then begin GDVars.partyPos.mapY := 15; GDVars.zone1^.leaveMap := 1; end;
    if y < 0 then begin GDVars.partyPos.mapY := 0; GDVars.zone1^.leaveMap := 1; end;
  end;
end;

procedure MovePartyForward3D;
begin
  SoundDrv.SoundCommand(GDConsts.stepSound);
  Delay(50);
  Inc(GDVars.partyPos.mapX, GDConsts.dirDx[GDVars.partyPos.facing]);
  Inc(GDVars.partyPos.mapY, GDConsts.dirDy[GDVars.partyPos.facing]);
  if GDVars.partyPos.mapX < 0 then GDVars.partyPos.mapX := 15;
  if GDVars.partyPos.mapX > 15 then GDVars.partyPos.mapX := 0;
  if GDVars.partyPos.mapY < 0 then GDVars.partyPos.mapY := 15;
  if GDVars.partyPos.mapY > 15 then GDVars.partyPos.mapY := 0;
  GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
  FillChar(GDVars.bashOffered, 3, 1);
  GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
  if (GDVars.zone1^.searchFlags and 1) > 0 then GameTime.AdvanceTime(1, 2)
  else GameTime.AdvanceTime(1, 1);
end;

function MapMainMenu: Char;
var
  flagA: Boolean;
  sel: Char;
  abort: Boolean;
  localV: array[1..42] of Byte;
  vcmFlag: Boolean absolute localV;
  { Unused in this version; see the other implementations of this routine. }
  oldZone: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  oldWindow: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  oldPicture: Pointer;
  savedChoice: Byte;
begin
  GDVars.zone1^.moveLocked := 0;
  case GDVars.interfaceState of
   C_Ifc.INDOORS: begin
    flagA := False;
    sel := C_Keys.NONE;
    repeat
      if GDVars.moveMode = 0 then begin
        GDVars.rosterPickMenu := 1;
        sel := MenuCore.MenuHorizontal('', 'Move Area Cast View Encamp Search Look', LightMagenta, LightGreen, White, 1,
                                       0, abort);
        savedChoice := GDVars.horizChoice;
        if not abort then begin
          case sel of
            'M': begin
                   MenuCore.ClearBottomLine;
                   GDVars.moveMode := 1;
                 end;
            'A': if (GDVars.zone0^.noAutomap = 0) or (ParamStr(2) = GDVars.stingKey) then
                 begin
                   GDVars.automapOn := GDVars.automapOn = False;
                   View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
                 end else begin
                   TextRend.PrintAndPause('Not Here', Yellow, 0);
                   CharHlp.PrintPositionAndTime;
                 end;
            'C': begin
                   GDVars.rosterPickMenu := 0;
                   if GDVars.curChar^.status = C_Status.OKAY then begin
                     GDVars.horizChoice := 1;
                     Camp.NoncombatCastMenu;
                   end;
                 end;
            'V': begin
                   GDVars.rosterPickMenu := 0;
                   GDVars.horizChoice := 1;
                   ViewChar.ViewCharMenu(vcmFlag);
                 end;
            'E': begin
                   flagA := True;
                   GDVars.horizChoice := 1;
                 end;
            'S': begin
                   GDVars.zone1^.searchFlags := GDVars.zone1^.searchFlags xor 1;
                   CharHlp.PrintPositionAndTime;
                 end;
            'L': begin
                   GDVars.zone1^.searchFlags := GDVars.zone1^.searchFlags or 2;
                   GameTime.AdvanceTime(1, 2);
                   CharHlp.PrintPositionAndTime;
                   GDVars.eclIp := GDVars.vmRun[2];
                   flagA := True;
                 end;
          end;
        end else begin
          CharHlp.DisplayParty(GDVars.curChar, False);
          ViewChar.SelectPrevNextChar(sel);
          CharHlp.DisplayParty(GDVars.curChar, True);
          CharHlp.PrintPositionAndTime;
        end;
        GDVars.horizChoice := savedChoice;
      end else begin
        sel := MenuCore.MenuHorizontal('', 'Exit', LightMagenta, LightGreen, White, 1, 0, abort);
        if not abort then begin
          case sel of
            'E': GDVars.moveMode := 0;
          end;
        end else begin
          case sel of
            C_Keys.UP: begin
                   Explore.MoveForward;
                   flagA := True;
                   CharHlp.PrintPositionAndTime;
                   sel := C_Keys.NONE;
                 end;
            C_Keys.DOWN: begin
                   GDVars.partyPos.facing := (GDVars.partyPos.facing + 4) mod 8;
                   GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                                   GDVars.partyPos.facing);
                   View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
                   CharHlp.PrintPositionAndTime;
                   sel := C_Keys.NONE;
                 end;
            C_Keys.LEFT: begin
                   GDVars.partyPos.facing := (GDVars.partyPos.facing + 6) mod 8;
                   SoundDrv.SoundCommand(GDConsts.stepSound);
                   GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                                   GDVars.partyPos.facing);
                   View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
                   CharHlp.PrintPositionAndTime;
                   sel := C_Keys.NONE;
                 end;
            C_Keys.RIGHT: begin
                   GDVars.partyPos.facing := (GDVars.partyPos.facing + 2) mod 8;
                   SoundDrv.SoundCommand(GDConsts.stepSound);
                   GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                                   GDVars.partyPos.facing);
                   View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
                   CharHlp.PrintPositionAndTime;
                   sel := C_Keys.NONE;
                 end;
          end;
        end;
      end;
    until flagA;
      end;
  end;
  if GDVars.bottomClear = 0 then begin
    Border.ClearBox(1, 17, 38, 22);
    GDVars.bottomClear := 1;
  end;
  MapMainMenu := sel;
end;

procedure ResolveMovement;
var
  result: Boolean;
  ext2: Boolean;
  strC: String[40];
  sel2: Char;
begin
  result := False;
  case GDVars.interfaceState of
   C_Ifc.INDOORS: begin
    if GDVars.zone1^.moveLocked < 255 then begin
      GDVars.viewDirty := 1;
      case View3D.GetBarrierType(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing) of
        1: result := True;
        2: begin
             strC[0] := #0;
             if GDVars.bashOffered <> 0 then strC := 'Bash';
             if (GDVars.pickOffered <> 0) and Explore.PartyHasClass(C_Class.THIEF) then strC := strC + ' Pick';
             if (GDVars.knockOffered <> 0) and (Explore.FindCharWithSpell(31) <> nil) then
               strC := strC + ' Knock';
             strC := strC + ' Exit';
             if strC =
                 ' Exit' then Explore.ChangeBarrierImpassable(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                              GDVars.partyPos.facing)
             else begin
               sel2 := MenuCore.MenuHorizontal('Locked. ', strC, LightMagenta, LightGreen, White, 0, 0, ext2);
               case sel2 of
                 'B': result := Explore.BashDoor;
                 'P': result := Explore.PickLock;
                 'K': result := Explore.PartyCastsKnock;
               end;
             end;
           end;
        3: begin
             strC[0] := #0;
             if GDVars.bashOffered <> 0 then strC := 'Bash';
             if (GDVars.pickOffered <> 0) and Explore.PartyHasClass(C_Class.THIEF) then strC := strC + ' Pick';
             if (GDVars.knockOffered <> 0) and (Explore.FindCharWithSpell(31) <> nil) then
               strC := strC + ' Knock';
             strC := strC + ' Exit';
             if strC =
                 ' Exit' then Explore.ChangeBarrierImpassable(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                              GDVars.partyPos.facing)
             else begin
               sel2 := MenuCore.MenuHorizontal('Locked. ', strC, LightMagenta, LightGreen, White, 0, 0, ext2);
               case sel2 of
                 'B': result := Explore.BashDoor;
                 'P': GDVars.pickOffered := 0;
                 'K': result := Explore.PartyCastsKnock;
               end;
             end;
           end;
      end;
      if result then Explore.MovePartyForward3D;
      CharHlp.PrintPositionAndTime;
    end else GDVars.zone1^.moveLocked := 0;
      end;
  end;
  Portrait.FreeAnimation(GDVars.animData);
  Blit.FreePic(GDVars.portraits[1].pic);
  Blit.FreePic(GDVars.portraits[2].pic);
  GDVars.portraits[1].fileId := 255;
  GDVars.portraits[2].fileId := 255;
end;

procedure NoopExplore;
begin
end;

begin
end.

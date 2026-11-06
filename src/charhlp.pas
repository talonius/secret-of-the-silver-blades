{ Character helpers: roster display, item handling and character math. This overlay provides the shared character, item,
  spellbook, formatting and combat-display helpers used throughout the game. }
{$O+,F+,I-}
unit CharHlp;

interface

uses Types, ClassCal, MenuCore, MapView, Portrait, Pathing, CbtMap, Border, Blit, TextRend, GameIo, SoundDrv, Crt,
  GDConsts, GDVars, C_Race, C_Status, C_Effect, C_Keys, C_Dir, C_Ifc, C_Spell, C_Money,
  C_Stat;

type
  TAcAdjust = array[0..4] of ShortInt;

{ Builds an item's display name in its own name field: a Yes/No readied column for the inventory view, '*' on a magical
  item (plus, save bonus or cursed) when any party member has Detect Magic, the quantity (not for a bundle), then the
  identified name components, at most one of them pluralized when the quantity is above 1; a bundle shows its quantity
  in place of its middle component.
  @param(owner Unused.)
  @param(it The item to name.)
  @param(col Screen column for doDisplay.)
  @param(row Screen row for doDisplay.)
  @param(showReadied Adds the readied column.)
  @param(doDisplay Also prints the name at (col, row).) }
procedure PrintItemString(owner: Types.PCharRecord; it: Types.PItemRec; col, row, showReadied, doDisplay: Byte);

{ Draws the party roster: a Name, AC and HP heading on row 2 and one line per member from row 4 (highlighted in white,
  others colored by DisplayCreatureName), with AC and hit points right-aligned, and records its rows for mouse picks.
  The roster starts in column 1 in the main menu and column 17 otherwise, and is not drawn on the overland map without
  an area view or while the roster is locked.
  @param(sel The member to highlight, usually the current character.) }
procedure DisplayRoster(sel: Types.PCharRecord);

{ Redraws one member's roster line, the member in GDVars.redrawChar (taken from cr when none is set), highlighted in
  white when selected; redrawChar is cleared afterwards. Like DisplayRoster it records the roster rows for mouse picks
  and is not drawn on the overland map without an area view or while the roster is locked.
  @param(cr The member to redraw when redrawChar is not set.)
  @param(selected True to highlight the line.) }
procedure DisplayParty(cr: Types.PCharRecord; selected: Boolean);

{ Prints a creature's current hit points at a screen position: yellow when wounded, light green when whole, light
  magenta when asked. When asked, the maximum follows after a slash in light green.
  @param(cr The creature.)
  @param(col The column.)
  @param(row The row.)
  @param(dying Set to print in light magenta.)
  @param(withMax Set to add the maximum after a slash.) }
procedure PrintHitPoints(cr: Types.PCharRecord; col, row, dying, withMax: Byte);

{ Prints a character's armor class in light green: 60 minus the stored value, with a minus sign when the value is above
  60.
  @param(cr The character.)
  @param(col Screen column.)
  @param(row Screen row.) }
procedure PrintArmorClass(cr: Types.PCharRecord; col, row: Byte);

{ Fills the combat side panel for a creature when the panel is marked dirty (and clears the mark): name, hit points,
  armor class, readied weapon, and the status name of a creature out of play, '(Helpless)' or '(Casting)'.
  @param(cr The creature to show.) }
procedure CombatPrintCreatureInfo(cr: Types.PCharRecord);

{ Tells whether a creature is helpless: any of the four helplessness effects is on it.
  @param(cr The creature.)
  @returns(True when the creature is helpless.) }
function IsHelpless(cr: Types.PCharRecord): Boolean;

{ Formats a number in decimal with commas between groups of three digits. Note: a number of more than nine digits loses
  its leading digits.
  @param(v The number.)
  @returns(The digits, grouped.) }
function Int32Str(v: LongInt): String;

{ Formats a number in decimal.
  @param(v The number.)
  @returns(Its decimal digits.) }
function Uint16Str(v: Word): String;

{ Formats a number in decimal.
  @param(v The number.)
  @returns(Its decimal digits.) }
function Uint8Str(v: Byte): String;

{ Computes the Dexterity missile adjustment from the current Dexterity: -4 at 0..2, -3..-1 at 3..5, +1..+3 at 16..18, 3
  at 19..20, 4 at 21..23, 5 at 24..25, else 0.
  @param(cr The creature.)
  @returns(The adjustment.) }
function DexMissileAdjust(cr: Types.PCharRecord): ShortInt;

{ Computes the Dexterity defensive adjustment from the current Dexterity: -4 at 1..3, -3..-1 at 4..6, +1..+4 at 15..18,
  4 at 19..20, 5 at 21..23, 6 at 24..25, else 0.
  @param(cr The creature.)
  @returns(The adjustment.) }
function DexterityArmorAdjustment(cr: Types.PCharRecord): ShortInt;

{ Computes the Strength to-hit bonus on TranslatedStrength's scale (-3 at 1..3 up to +7 at 30), or 0 unless the
  creature's Strength bonus applies.
  @param(cr The creature.)
  @returns(The to-hit bonus.) }
function StrToHitAdjust(cr: Types.PCharRecord): ShortInt;

{ Computes the Strength damage bonus on TranslatedStrength's scale (-2 at 1..2 up to +14 at 30), or 0 unless the
  creature's Strength bonus applies.
  @param(cr The creature.)
  @returns(The damage bonus.) }
function StrDamageAdjust(cr: Types.PCharRecord): ShortInt;

{ Computes the extra carrying allowance for a character's Strength on TranslatedStrength's scale, from -350 at 1..3 to
  15000 at 30, and 0 at 8..11.
  @param(cr The character.)
  @returns(The allowance, which may be negative.) }
function WeightAllowance(cr: Types.PCharRecord): Integer;

{ Clears the first memorized-spell byte equal to id (used when a spell being cast is lost).
  @param(cr The creature whose memorized spells are searched.)
  @param(id The spell to forget.) }
procedure RemoveSpell(cr: Types.PCharRecord; id: Byte);

{ Unlinks an item from a character's list and disposes of it, a bundle's sub-items first, with a message for a nil item
  or one not in the list.
  @param(cr The owner.)
  @param(item The item to remove.) }
procedure RemoveItem(cr: Types.PCharRecord; item: Types.PItemRec);

{ Appends a copy of an item to the end of a character's item list.
  @param(cr The character who receives the copy.)
  @param(item The item to copy.) }
procedure AddItemCopy(cr: Types.PCharRecord; item: Types.PItemRec);

{ Shows a message on the bottom row in light green for the text delay, then clears the row.
  @param(s The message.) }
procedure PrintBottomLine(s: Types.TStr40);

{ Shows a creature's name and a message: in combat in the side panel, otherwise in the lower text window.
  @param(cr The creature to name.)
  @param(s The message.)
  @param(row The first side-panel row, in combat.)
  @param(pause Waits and then clears the message area.) }
procedure PrintCreatureMessage(cr: Types.PCharRecord; s: String; row: Byte; pause: Boolean);

{ Clears the message area: the side panel's rows 10..21 in combat, otherwise rows 18..22. }
procedure ClearMessageWindow;

{ Prints a creature's name in light red when out of play, yellow when hostile in combat, light cyan otherwise.
  @param(cr The creature.)
  @param(x Screen column.)
  @param(y Screen row.)
  @param(possessive Appends 's.) }
procedure DisplayCreatureName(cr: Types.PCharRecord; x, y: Byte; possessive: Boolean);

{ Copies one frame of an icon slot, mirrored or not, into one frame of the combat view picture.
  @param(a The icon slot.)
  @param(b The icon frame to copy, 0 or 1.)
  @param(c The picture frame to fill.)
  @param(mirror Mirrors the frame.) }
procedure CopyIconFacing(a, b, c: Byte; mirror: Boolean);

{ Builds the four-frame moving-icon sheet from an icon: frame 0 straight and mirrored, then frame 1 mirrored and
  straight.
  @param(a The icon slot.) }
procedure BuildIconFacings(a: Byte);

{ Flies the combat view picture from one arena cell to another along a third-cell path, cycling its frames and keeping
  it in view: the view stays put when both ends are visible, is centered between them when they lie within 6 cells of
  each other, and otherwise follows the picture and finishes at the target. With a pause of 0 the picture is drawn on
  cell edges and skipped between them. Paths of fewer than four steps are not drawn.
  @param(fromCol Start column.)
  @param(fromRow Start row.)
  @param(toCol Target column.)
  @param(toRow Target row.)
  @param(frameCount The number of picture frames to cycle.)
  @param(delayVal Milliseconds to pause on each drawn step.) }
procedure CombatAnimateMovingIcon(fromCol, fromRow, toCol, toRow: Integer; frameCount,
                                  delayVal: Byte);

{ Recomputes a character's derived values from its inventory: refills the readied-slot table (by item slot, with two
  ring slots, arrows in slot 11 and quarrels in slot 12), the item count, the hands in use and the encumbrance (item
  weights times quantity, plus every coin type); resets the current damage dice to the unarmed dice; and rebuilds THAC0
  and damage (WeaponAdjust, or the Strength adjustments unarmed), movement (RecalcMovement) and armor class from
  Dexterity and readied items (AddItemArmorAdjust), magic body armor cancelling the ring bonus. acCurArr[0] gets the
  full AC value and acCurArr[1] the AC without Dexterity or shield, less 2; the attack level gets the highest fighter,
  ranger or paladin level of a character with such levels (an earlier fighter class counting while active) that is not a
  tribble or monster, else 1.
  @param(cr The character to update.) }
procedure RecalcStats(cr: Types.PCharRecord);

{ Announces an effect on a creature. In combat, builds the effect picture from icon slot 22 for an effect or 23 for
  damage, scrolls to the creature, plays the matching sound, prints the message and animates the picture over it (one
  more time than the game delay for an effect, once followed by a pause for damage); elsewhere prints the message with a
  pause.
  @param(cr The creature.)
  @param(hit Set for an effect, clear for damage.)
  @param(msg The message.) }
procedure PrintNameStringAnim(cr: Types.PCharRecord; hit: Byte; msg: String);

{ Finds a creature's first copy of an effect.
  @param(cr The creature.)
  @param(id The effect to look for.)
  @param(eff Receives that effect, or nil.)
  @returns(True when the creature has the effect.) }
function HasEffect(cr: Types.PCharRecord; id: Byte; var eff: Types.PEffectRec): Boolean;

{ Subtracts damage from a creature's hit points. Falling more than 9 below 0, or an animated creature reaching 0, kills
  it; 1..9 below makes it dying (in combat the deficit is kept as overkill); landing on 0 makes it unconscious. A
  creature whose status is then anything but okay or animated is disabled at 0 hit points and, in combat, removed from
  its side's count and loses its initiative.
  @param(cr The creature.)
  @param(damage The damage.) }
procedure InflictDamage(cr: Types.PCharRecord; damage: Byte);

{ Prints 'is fully healed' or 'is partially healed' for a creature, and outside combat redraws the roster.
  @param(cr The healed creature.) }
procedure AnnounceHealStatus(cr: Types.PCharRecord);

{ Finds a creature's opposing team.
  @param(cr The creature.)
  @returns(1 for a creature that is not hostile, else 0.) }
function EnemyTeam(cr: Types.PCharRecord): ShortInt;

{ Recounts the creatures in play on each side. }
procedure CountTeams;

{ Builds the target list within a range of a creature, narrows it to the creature's enemies and copies their creature
  indices into the target-slot table. A creature under effect 91 gets its preferred target moved to the front.
  @param(cr The creature at the center.)
  @param(kind The range.)
  @returns(The number of targets kept.) }
function CountTargets(cr: Types.PCharRecord; kind: Byte): Byte;

{ Measures the distance in whole steps from one creature to another, read from a fresh range-255 target list built
  ignoring terrain (the previous list is saved and restored). Note: an absent target gives the last entry's distance.
  @param(from The creature measuring.)
  @param(target The creature to find.)
  @returns(The distance.) }
function CalcDistance(from, target: Types.PCharRecord): Byte;

{ Ends a creature's actions for the round: clears its initiative, casting, guarding and movement.
  @param(cr The creature.)
  @returns(Always True.) }
function EndActions(cr: Types.PCharRecord): Boolean;

{ Ends a creature's actions and, unless it is turned, sets it guarding with a 'Guarding' message.
  @param(cr The creature.)
  @returns(Always True.) }
function Guard(cr: Types.PCharRecord): Boolean;

{ Computes the current character's caster level for a spell. With no cleric or magic-user levels and a ranger below 8,
  it is 6. Otherwise by the spell's class: cleric spells use the higher of the cleric and paladin levels; druid spells
  ranger level - 7 (at least 0); magic-user spells the higher of the magic-user level and ranger level - 8; special
  spells give 12. Dual-class earlier levels count while ClassCal.EarlierClassActive allows them. While an item is being
  used, any spell but a special one is cast at level 6.
  @param(spell The spell.)
  @returns(The caster level.) }
function GetCasterLevel(spell: Byte): Byte;

{ Lets the player pick a party member: the up and down arrows move through the party (a mouse click on the roster picks
  directly), Enter or S selects, and E or Escape ends the pick.
  @param(prompt The prompt text.)
  @param(allowExit Nonzero offers an Exit choice; Exit or Escape then sets sel to nil.)
  @param(lockSel Nonzero lets a mouse pick go to the member sel held at the start instead of the current character.)
  @param(sel The member highlighted at the start; receives the pick.) }
procedure SelectChar(prompt: Types.TStr40; allowExit, lockSel: Byte; var sel: Types.PCharRecord);

{ Redraws the noncombat screen for the current interface state (main menu, vault, shop or temple, camp, 3D view,
  overland map unless picture 9 or an area view is shown, treasure), with the roster and status line where they apply,
  and marks the view for redraw. }
procedure DisplayNoncombatInterface;

{ Draws the status line on row 15: the map position (the zone's override when set, else the party's), compass direction
  and time, '*' while debugOn is set, and ' camping' or ' search' when they apply. Not drawn on the overland map. }
procedure PrintPositionAndTime;

{ Switches to the combat palette, draws the combat frame and rebuilds the combat view. }
procedure DisplayCombatInterface;

{ Tells whether a creature's readied weapon has a range above 1.
  @param(cr The creature.)
  @returns(True for a ranged weapon.) }
function HasRangedWeapon(cr: Types.PCharRecord): Boolean;

{ Tells whether a creature's readied weapon is ranged and either is thrown as its own missile or is item type 67.
  @param(cr The creature.)
  @returns(True for a thrown weapon.) }
function HasThrowableWeapon(cr: Types.PCharRecord): Boolean;

{ Finds the item that does the damage in a ranged attack: the readied weapon itself when thrown, else the readied arrows
  for a bow or the readied quarrels for a crossbow, or nil when there is none.
  @param(cr The creature.)
  @param(sel Receives the item, or nil.)
  @returns(True when an item is found, and also for a weapon whose properties are exactly $0A, which needs no
    ammunition.) }
function FindDamagingRangedWeapon(cr: Types.PCharRecord; var sel: Types.PItemRec): Boolean;

{ Works out a creature's movement: its base movement, limited by readied body armor and encumbrance, doubled by haste
  and halved by slow; it is stored as the creature's current movement and the global movement, where a party member gets
  the zone's party movement bonus, and the total is doubled into half-steps.
  @param(cr The creature.)
  @returns(The movement in half-steps.) }
function RecalcMovement(cr: Types.PCharRecord): Byte;

{ Empty routine with no callers. }
procedure NoopCharHlp;

{ Tells whether any party member (a side-0 player or non-player character) is dying. With `apply` set, the first dying
  member found is bandaged: it becomes unconscious, its overkill is cleared and the bandaging is announced.
  @param(apply Set to bandage the first dying member.)
  @returns(True when a member is dying.) }
function BandageDying(apply: Byte): Boolean;

{ Classifies the direction from one creature's cell to another's into one of eight 45-degree sectors, tried clockwise
  from north with the slopes tan 22.5 and tan 67.5 degrees in 8.8 fixed point.
  @param(creature The creature looking.)
  @param(other The creature looked at.)
  @returns(The direction, 0..7.) }
function DirTowardTarget(creature, other: Types.PCharRecord): Byte;

{ Sets the readied weapon's THAC0 and damage. THAC0 (toHitCur) starts from baseToHit, plus the Dexterity missile
  adjustment for a missile weapon (props bit 1) and the Strength to-hit bonus for a weapon that uses Strength (props bit
  2), which also adds the Strength damage bonus. The damage modifier (curModA[1]) starts from the weapon's small-target
  modifier. The weapon's plus and its ammunition's plus (quarrels, slot 12, for props bit 7; arrows, slot 11, for props
  bit 0) are added to both the damage modifier and THAC0, and item types 18, 19 and 22..26 add 1 more to THAC0 alone.
  The damage dice are the small-target dice. Does nothing without a readied weapon.
  @param(cr The character.) }
procedure WeaponAdjust(cr: Types.PCharRecord);

{ Sets movement from readied body armor's weight: the base movement up to 150, 9 up to 399, else 6; magic armor adds 3
  when that leaves 9 or less.
  @param(cr The character.)
  @param(it A readied item; anything but body armor is ignored.) }
procedure ArmorMoveAdjust(cr: Types.PCharRecord; it: Types.PItemRec);

{ Adds one readied item's armor-class part: a shield sets the first part; an item with armor code 0 adds its plus to the
  second part (rings keep the best ring plus in the third part instead) and its save bonus to the wearer's save bonus;
  other armor keeps the best code plus its plus in the fourth part. Items without an armor code add nothing.
  @param(cr The wearer.)
  @param(it A readied item.)
  @param(adj The armor-class parts being collected.)
  @param(isMagicBody Set by magic body armor, which later cancels the ring bonus.) }
procedure AddItemArmorAdjust(cr: Types.PCharRecord; it: Types.PItemRec; var adj: TAcAdjust;
                             var isMagicBody: Boolean);

{ Lowers a creature's movement for the coins it carries past its weight allowance: up to 512 over changes nothing, and
  each further band of 256 steps down to 9, 6 and 3. The movement is only ever lowered.
  @param(cr The creature.) }
procedure EncumbranceAdjust(cr: Types.PCharRecord);

implementation

procedure WeaponAdjust(cr: Types.PCharRecord);
var
  w: Types.PItemRec;
  wtype: Byte;
  plus: ShortInt;
begin
  w := cr^.equipped[0];
  if w = nil then Exit;
  wtype := w^.itemType;
  cr^.toHitCur := cr^.baseToHit;
  if (GDVars.baseItems[wtype].props and 2) <> 0 then
    cr^.toHitCur := CharHlp.DexMissileAdjust(cr) + cr^.toHitCur;
  cr^.curModA[1] := GDVars.baseItems[wtype].dmgSmMod;
  if (GDVars.baseItems[wtype].props and 4) <> 0 then begin
    cr^.toHitCur := CharHlp.StrToHitAdjust(cr) + cr^.toHitCur;
    cr^.curModA[1] := CharHlp.StrDamageAdjust(cr) + cr^.curModA[1];
  end;
  plus := w^.plus;
  if GDVars.baseItems[wtype].props > $7F then
    if cr^.equipped[12] <> nil then
      plus := plus + cr^.equipped[12]^.plus;
  if (GDVars.baseItems[wtype].props and 1) > 0 then
    if cr^.equipped[11] <> nil then
      plus := plus + cr^.equipped[11]^.plus;
  cr^.curModA[1] := cr^.curModA[1] + plus;
  if ((w^.itemType >= 22) and (w^.itemType <= 26)) or (w^.itemType = 19) or (w^.itemType = 18) then
    Inc(plus);
  cr^.toHitCur := cr^.toHitCur + plus;
  cr^.curRollsA[1] := GDVars.baseItems[wtype].dmgSmRolls;
  cr^.curDiceA[1] := GDVars.baseItems[wtype].dmgSmDice;
end;

procedure ArmorMoveAdjust(cr: Types.PCharRecord; it: Types.PItemRec);
begin
  if GDVars.baseItems[it^.itemType].slot = 2 then begin
    case it^.weight of
      0..150: cr^.movementCur := cr^.movementBase;
      151..399: cr^.movementCur := 9;
    else
      cr^.movementCur := 6;
    end;
    if (it^.plus <> 0) and (cr^.movementCur <= 9) then
      cr^.movementCur := cr^.movementCur + 3;
  end;
end;

procedure AddItemArmorAdjust(cr: Types.PCharRecord; it: Types.PItemRec; var adj: TAcAdjust; var isMagicBody: Boolean);
var
  descr: Byte;
  slot: Byte;
begin
  descr := GDVars.baseItems[it^.itemType].acDescr;
  if descr > $7F then begin
    descr := descr and $7F;
    slot := GDVars.baseItems[it^.itemType].slot;
    if slot = 1 then
      adj[1] := descr + it^.plus
    else if descr = 0 then begin
      if slot = 9 then begin
        if it^.plus > adj[3] then
          adj[3] := it^.plus;
      end else
        adj[2] := adj[2] + it^.plus;
      cr^.saveBonus := cr^.saveBonus + it^.saveBonus;
    end else begin
      if descr + it^.plus > adj[4] then begin
        adj[4] := descr + it^.plus;
        if it^.plus > 0 then
          if slot = 2 then
            isMagicBody := True;
      end;
    end;
  end;
end;

procedure EncumbranceAdjust(cr: Types.PCharRecord);
var
  net: Integer;
  mv: Byte;
begin
  net := cr^.encumbrance - CharHlp.WeightAllowance(cr);
  if net < 0 then net := 0;
  case net of
    0..512: mv := cr^.movementCur;
    513..768: mv := 9;
    769..1024: mv := 6;
  else
    mv := 3;
  end;
  if mv < cr^.movementCur then cr^.movementCur := mv;
end;

procedure PrintItemString(owner: Types.PCharRecord; it: Types.PItemRec; col, row, showReadied, doDisplay: Byte);
var
  i: Byte;
  mask: Byte;
  { HasEffect's var out-param }
  eff: Types.PEffectRec;
  found: Byte;
  { set once an 's ' has been emitted }
  spaced: Byte;
  p: Types.PCharRecord;
  { Str() destination }
  qs: String[4];
begin
  it^.name := '';
  if showReadied <> 0 then
    if it^.equipped <> 0 then
      it^.name := ' Yes  '
    else
      it^.name := ' No   ';
  found := 0;
  p := GDVars.creatureList;
  while (p <> nil) and (found = 0) do begin
    if CharHlp.HasEffect(p, 5, eff) then found := 1;
    p := p^.nextCharAddr;
  end;
  if found <> 0 then
    if (it^.plus > 0) or (it^.saveBonus > 0) or (it^.cursed <> 0) then
      it^.name := it^.name + '*' + ' ';
  if it^.quantity > 0 then
    if it^.itemType <> Ord('I') then
      it^.name := it^.name + CharHlp.Uint8Str(it^.quantity) + ' ';
  { which name fragments are BOTH present and identified -- unidMask is indexed from the opposite end (3 - i), so it
    cannot share this loop's shift }
  mask := 0;
  for i := 1 to 3 do
    if it^.nameIds[i] <> 0 then
      if ((it^.unidMask shr (3 - i)) and 1) = 0 then
        Inc(mask, 1 shl (i - 1));
  spaced := 0;
  for i := 3 downto 1 do
    if ((mask shr (i - 1)) and 1) > 0 then begin
      if (it^.itemType = Ord('I')) and (i = 2) then begin
        Str(it^.quantity, qs);
        it^.name := it^.name + qs;
      end else
        it^.name := it^.name + GDConsts.itemNames[it^.nameIds[i]];
      if (it^.quantity < 2) or (spaced <> 0) then
        it^.name := it^.name + ' '
      else if (1 shl (i - 1) = mask)
              or ((i = 1) and (mask > 4))
              or ((i = 1) and (it^.itemType = Ord('I')))
              or ((i = 2) and not Odd(mask))
              or
                ((i = 3) and ((it^.itemType = 30) or (it^.itemType = 5) or (it^.itemType = 12)) and
                 (it^.nameIds[3] <> 93)) then begin
        it^.name := it^.name + 's ';
        spaced := 1;
      end else
        it^.name := it^.name + ' ';
    end;
  if doDisplay <> 0 then
    TextRend.DisplayString(col, row, LightGreen, 0, it^.name);
end;

procedure DisplayRoster(sel: Types.PCharRecord);
var
  p: Types.PCharRecord;
  col: Byte;
  row: Byte;
  cls: Byte;
begin
  if ((GDVars.interfaceState = C_Ifc.OVERLAND) and (GDVars.zone0^.areaView = 0)) or
      (GDVars.rosterLock <> 0) then
    Exit;
  if GDVars.interfaceState = C_Ifc.MAIN_MENU then col := 1 else col := 17;
  GDVars.rosterLeft := col;
  GDVars.rosterTop := 4;
  GDVars.rosterRight := 38;
  GDVars.rosterBottom := 3;
  row := 2;
  TextRend.DisplayString(col, row, White, 0, 'Name');
  TextRend.DisplayString(33, row, White, 0, 'AC  HP');
  Inc(row, 2);
  p := GDVars.creatureList;
  while p <> nil do begin
    Inc(GDVars.rosterBottom);
    Border.ClearBox(col, row, 38, row);
    if p = sel then
      TextRend.DisplayString(col, row, White, 0, p^.name)
    else
      CharHlp.DisplayCreatureName(p, col, row, False);
    case p^.acCurArr[0] of
      0..50: cls := 1;
      51..60: cls := 2;
      61..69: cls := 1;
    else
      cls := 0;
    end;
    CharHlp.PrintArmorClass(p, cls + 32, row);
    case p^.hpCur of
      0..9: cls := 2;
      10..99: cls := 1;
    else
      cls := 0;
    end;
    CharHlp.PrintHitPoints(p, cls + 36, row, 0, 0);
    Inc(row);
    p := p^.nextCharAddr;
  end;
  Border.ClearBox(col, row, 38, row);
end;

procedure DisplayParty(cr: Types.PCharRecord; selected: Boolean);
var
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  redrawTarget: Types.PCharRecord;
  col: Byte;
  row: Byte;
  cls: Byte;
begin
  if ((GDVars.interfaceState = C_Ifc.OVERLAND) and (GDVars.zone0^.areaView = 0)) or
      (GDVars.rosterLock <> 0) then
    Exit;
  if GDVars.redrawChar = nil then GDVars.redrawChar := cr;
  if GDVars.interfaceState = C_Ifc.MAIN_MENU then col := 1 else col := 17;
  GDVars.rosterLeft := col;
  GDVars.rosterTop := 4;
  GDVars.rosterRight := 38;
  GDVars.rosterBottom := 3;
  row := 4;
  p := GDVars.creatureList;
  while p <> nil do begin
    Inc(GDVars.rosterBottom);
    if p = GDVars.redrawChar then begin
      if selected then
        TextRend.DisplayString(col, row, White, 0, p^.name)
      else
        CharHlp.DisplayCreatureName(p, col, row, False);
      case p^.acCurArr[0] of
        0..50: cls := 1;
        51..60: cls := 2;
        61..69: cls := 1;
      else
        cls := 0;
      end;
      CharHlp.PrintArmorClass(p, cls + 32, row);
      case p^.hpCur of
        0..9: cls := 2;
        10..99: cls := 1;
      else
        cls := 0;
      end;
      CharHlp.PrintHitPoints(p, cls + 36, row, 0, 0);
    end;
    Inc(row);
    p := p^.nextCharAddr;
  end;
  Border.ClearBox(col, row, 38, row);
  GDVars.redrawChar := nil;
end;

procedure PrintArmorClass(cr: Types.PCharRecord; col, row: Byte);
var
  s: String;
  { Unused in this version; see the other implementations of this routine. }
  color: Byte;
begin
  s := CharHlp.Uint8Str(Abs(cr^.acCurArr[0] - 60));
  if cr^.acCurArr[0] > 60 then s := '-' + s;
  TextRend.DisplayString(col, row, LightGreen, 0, s);
end;

procedure PrintHitPoints(cr: Types.PCharRecord; col, row, dying, withMax: Byte);
var
  s: String;
  fg: Byte;
  n: ShortInt;
begin
  if cr^.hpCur < cr^.hpMax then fg := Yellow else fg := LightGreen;
  if dying <> 0 then fg := LightMagenta;
  s := CharHlp.Uint8Str(cr^.hpCur);
  TextRend.DisplayString(col, row, fg, 0, s);
  if withMax <> 0 then begin
    n := Length(s);
    TextRend.DisplayString(col + n, row, LightGreen, 0, '/' + CharHlp.Uint8Str(cr^.hpMax));
  end;
end;

procedure CombatPrintCreatureInfo(cr: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  displayColumn: Byte;
  row: Byte;
begin
  if GDVars.panelDirty = 0 then Exit;
  GDVars.panelDirty := 0;
  Border.ClearBox(23, 1, 38, 21);
  row := 1;
  CharHlp.PrintCreatureMessage(cr, ' ', row, False);
  Inc(row);
  TextRend.DisplayString(23, row + 1, LightGreen, 0, 'Hitpoints');
  CharHlp.PrintHitPoints(cr, 33, row + 1, 0, 0);
  Inc(row, 2);
  TextRend.DisplayString(23, row + 1, LightGreen, 0, 'AC');
  CharHlp.PrintArmorClass(cr, 26, row + 1);
  GDVars.curRow := row + 1;
  if cr^.equipped[0] <> nil then begin
    Inc(row, 2);
    displayColumn := 23;
    CharHlp.PrintItemString(cr, cr^.equipped[0], 0, 0, 0, 0);
    TextRend.DisplayMessageWindow(23, row + 1, 38, row + 1 + 2, LightGreen, 0, True, cr^.equipped[0]^.name);
  end;
  row := GDVars.curRow + 1;
  if cr^.enabled = 0 then
    TextRend.DisplayString(23, row + 1, White, 0, GDConsts.statusNames[cr^.status])
  else if CharHlp.IsHelpless(cr) then
    TextRend.DisplayString(23, row + 1, White, 0, '(Helpless)')
  else if cr^.combatAddr^.spellCast > 0 then
    TextRend.DisplayString(23, row + 1, White, 0, '(Casting)');
end;

function IsHelpless(cr: Types.PCharRecord): Boolean;
var
  i: Byte;
  eff: Types.PEffectRec;
begin
  IsHelpless := False;
  for i := 1 to 4 do
    if CharHlp.HasEffect(cr, GDConsts.helplessFx[i], eff) then
      IsHelpless := True;
end;

function Uint8Str(v: Byte): String;
var
  s: String;
begin
  Str(v, s);
  Uint8Str := s;
end;

function Uint16Str(v: Word): String;
var
  s: String;
begin
  Str(v, s);
  Uint16Str := s;
end;

function Int32Str(v: LongInt): String;
var
  digits: String;
  acc: String;
  len: Byte;
begin
  Str(v, digits);
  len := Length(digits);
  if len > 3 then begin
    acc := ',' + Copy(digits, len - 2, 3);
    if len > 6 then begin
      acc := ',' + Copy(digits, len - 5, 3) + acc;
      if len > 9 then
        acc := ',' + Copy(digits, len - 8, 3) + acc
      else
        acc := Copy(digits, 1, len - 6) + acc;
    end else
      acc := Copy(digits, 1, len - 3) + acc;
  end else
    acc := digits;
  Int32Str := acc;
end;

function DexterityArmorAdjustment(cr: Types.PCharRecord): ShortInt;
var
  d: Byte;
begin
  d := cr^.dexCur;
  case d of
    1..3: DexterityArmorAdjustment := -4;
    4..6: DexterityArmorAdjustment := d - 7;
    15..18: DexterityArmorAdjustment := d - 14;
    19..20: DexterityArmorAdjustment := 4;
    21..23: DexterityArmorAdjustment := 5;
    24..25: DexterityArmorAdjustment := 6;
  else
    DexterityArmorAdjustment := 0;
  end;
end;

function DexMissileAdjust(cr: Types.PCharRecord): ShortInt;
var
  d: Byte;
begin
  d := cr^.dexCur;
  case d of
    0..2: DexMissileAdjust := -4;
    3..5: DexMissileAdjust := d - 6;
    16..18: DexMissileAdjust := d - 15;
    19..20: DexMissileAdjust := 3;
    21..23: DexMissileAdjust := 4;
    24..25: DexMissileAdjust := 5;
  else
    DexMissileAdjust := 0;
  end;
end;

{ Converts Strength to one scale: 0..17 as is; 18 by exceptional Strength (without it 18, 01-50 19, 51-75 20, 76-90 21,
  91-99 22, 00 23); 19..25 become 24..30. Note: other values leave the result undefined.
  @param(cr The creature.)
  @returns(Strength on that scale.) }
function TranslatedStrength(cr: Types.PCharRecord): Byte;
begin
  case cr^.stats[C_Stat.STRENGTH].cur of
    0..17: TranslatedStrength := cr^.stats[C_Stat.STRENGTH].cur;
    18:
      case cr^.strExc of
        0: TranslatedStrength := 18;
        1..50: TranslatedStrength := 19;
        51..75: TranslatedStrength := 20;
        76..90: TranslatedStrength := 21;
        91..99: TranslatedStrength := 22;
        100: TranslatedStrength := 23;
      end;
    19..25: TranslatedStrength := cr^.stats[C_Stat.STRENGTH].cur + 5;
  end;
end;

function StrToHitAdjust(cr: Types.PCharRecord): ShortInt;
var
  ts: Byte;
begin
  StrToHitAdjust := 0;
  ts := CharHlp.TranslatedStrength(cr);
  if cr^.useStrength <> 0 then
    case ts of
      1..3: StrToHitAdjust := -3;
      4..5: StrToHitAdjust := -2;
      6..7: StrToHitAdjust := -1;
      17..19: StrToHitAdjust := 1;
      20..22: StrToHitAdjust := 2;
      23..25: StrToHitAdjust := 3;
      26..27: StrToHitAdjust := 4;
      28..30: StrToHitAdjust := ts - 23;
    end;
end;

function StrDamageAdjust(cr: Types.PCharRecord): ShortInt;
var
  ts: Byte;
begin
  StrDamageAdjust := 0;
  ts := CharHlp.TranslatedStrength(cr);
  if cr^.useStrength <> 0 then
    case ts of
      1..2: StrDamageAdjust := -2;
      3..5: StrDamageAdjust := -1;
      16: StrDamageAdjust := 1;
      17..19: StrDamageAdjust := ts - 16;
      20..29: StrDamageAdjust := ts - 17;
      30: StrDamageAdjust := 14;
    end;
end;

function WeightAllowance(cr: Types.PCharRecord): Integer;
var
  ts: Byte;
begin
  ts := CharHlp.TranslatedStrength(cr);
  case ts of
    1..3: WeightAllowance := -350;
    4..5: WeightAllowance := -250;
    6..7: WeightAllowance := -150;
    12..13: WeightAllowance := 100;
    14..15: WeightAllowance := 200;
    16: WeightAllowance := 350;
    17..21: WeightAllowance := (ts - 17) * 250 + 500;
    22..26: WeightAllowance := (ts - 22) * 1000 + 2000;
    27: WeightAllowance := 7500;
    28..30: WeightAllowance := (ts - 28) * 3000 + 9000;
  else
    WeightAllowance := 0;
  end;
end;

procedure RemoveSpell(cr: Types.PCharRecord; id: Byte);
var
  i: Byte;
begin
  i := 0;
  while i <= 74 do begin
    if cr^.memorizedSpells[i] = id then begin
      cr^.memorizedSpells[i] := 0;
      i := 75;
    end;
    Inc(i);
  end;
end;

procedure RemoveItem(cr: Types.PCharRecord; item: Types.PItemRec);
var
  p: Types.PItemRec;
begin
  if item = nil then begin
    TextRend.DisplayAndPause(Yellow, 0, 'Nil Item pointer...');
    Exit;
  end;
  if item^.itemType = Ord('I') then
    while item^.enchantChain <> nil do begin
      p := item^.enchantChain;
      item^.enchantChain := p^.enchantChain;
      FreeMem(p, SizeOf(p^));
    end;
  p := cr^.itemsAddr;
  if p = item then
    cr^.itemsAddr := item^.next
  else
    while (p <> nil) and (p^.next <> item) do
      p := p^.next;
  if p = nil then begin
    TextRend.DisplayAndPause(Yellow, 0, 'Tried to Lose item & couldn''t find it!');
    Exit;
  end;
  p^.next := item^.next;
  item^.next := nil;
  FreeMem(item, SizeOf(item^));
end;

procedure AddItemCopy(cr: Types.PCharRecord; item: Types.PItemRec);
var
  p: Types.PItemRec;
  nw: Types.PItemRec;
begin
  New(nw);
  Move(item^, nw^, SizeOf(Types.TItemRec));
  nw^.next := nil;
  p := cr^.itemsAddr;
  if p = nil then
    cr^.itemsAddr := nw
  else begin
    while p^.next <> nil do
      p := p^.next;
    p^.next := nw;
  end;
end;

procedure PrintBottomLine(s: Types.TStr40);
begin
  Border.ClearBox(0, 24, 39, 24);
  TextRend.DisplayString(0, 24, LightGreen, 0, s);
  TextRend.PauseOnly;
  Border.ClearBox(0, 24, 39, 24);
end;

procedure PrintCreatureMessage(cr: Types.PCharRecord; s: String; row: Byte; pause: Boolean);
var
  r: Byte;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    Border.ClearBox(23, row, 38, 21);
    CharHlp.DisplayCreatureName(cr, 23, row, False);
    TextRend.DisplayMessageWindow(23, row + 1, 38, 21, LightGreen, 0, True, s);
  end else begin
    if GDVars.restActive <> 0 then
      r := 18
    else
      r := 17;
    Border.ClearBox(1, r, 38, 22);
    CharHlp.DisplayCreatureName(cr, 1, r + 1, False);
    TextRend.DisplayMessageWindow(1, r + 2, 38, 22, LightGreen, 0, True, s);
  end;
  if pause then begin
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
  end;
end;

procedure NoopCharHlp;
begin
end;

procedure ClearMessageWindow;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then
    Border.ClearBox(23, 10, 38, 21)
  else
    Border.ClearBox(1, 18, 38, 22);
end;

procedure DisplayCreatureName(cr: Types.PCharRecord; x, y: Byte; possessive: Boolean);
var
  col: Byte;
begin
  if cr^.enabled = 0 then
    col := LightRed
  else if (cr^.hostile = 1) and (GDVars.interfaceState = C_Ifc.IN_COMBAT) then
    col := Yellow
  else
    col := LightCyan;
  TextRend.DisplayString(x, y, col, 0, cr^.name);
  if possessive then
    TextRend.DisplayString(x + Length(cr^.name), y, col, 0, '''s');
end;

procedure CopyIconFacing(a, b, c: Byte; mirror: Boolean);
var
  tmp: Types.PImgBuf;
  sz: Word;
  ofsv: Word;
begin
  sz := GDVars.iconBuf^.imgSize;
  ofsv := c * sz;
  if mirror then begin
    Blit.AllocPic(24, 3, 1, 1, tmp);
    Blit.MirrorPic(GDVars.iconAnims[a, b], tmp);
    Move(tmp^.data, GDVars.iconBuf^.data[ofsv], sz);
    Move(tmp^.transp^, GDVars.iconBuf^.transp^[ofsv], sz);
    Blit.FreePic(tmp);
  end else begin
    Move(GDVars.iconAnims[a, b]^.data, GDVars.iconBuf^.data[ofsv], sz);
    Move(GDVars.iconAnims[a, b]^.transp^, GDVars.iconBuf^.transp^[ofsv], sz);
  end;
end;

procedure BuildIconFacings(a: Byte);
begin
  CharHlp.CopyIconFacing(a, 0, 0, False);
  CharHlp.CopyIconFacing(a, 0, 1, True);
  CharHlp.CopyIconFacing(a, 1, 2, True);
  CharHlp.CopyIconFacing(a, 1, 3, False);
end;

procedure CombatAnimateMovingIcon(fromCol, fromRow, toCol, toRow: Integer; frameCount, delayVal: Byte);
var
  path: array[0..147] of Byte;
  st: Types.TPathReq;
  { Unused in this version; see the other implementations of this routine. }
  pathCount: Integer;
  n: Byte;
  limit: Byte;
  frameIx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  lastFrame: Byte;
  near: Byte;
  stop: Boolean;
  cursorCol: Integer;
  cursorRow: Integer;
  { Unused in this version; see the other implementations of this routine. }
  prevX: Integer;
  { Unused in this version; see the other implementations of this routine. }
  prevY: Integer;
  accumX: Integer;
  accumY: Integer;
  dCol: Integer;
  dRow: Integer;
  stepX: Integer;
  stepY: Integer;
  pixX: Integer;
  pixY: Integer;
  clampX: Integer;
  clampY: Integer;
begin
  prevX := fromCol;
  prevY := fromRow;
  FillChar(path, SizeOf(path), 8);
  GameIo.FillWord(st, SizeOf(st));
  n := 0;
  frameIx := 0;
  st.sx := fromCol * 3;
  st.sy := fromRow * 3;
  st.ex := toCol * 3;
  st.ey := toRow * 3;
  Pathing.PathFind(st);
  repeat
    stop := not Pathing.NextPathStep(st);
    path[n] := st.step;
    Inc(n);
  until stop;
  limit := n - 2;
  if (limit < 2) or (n < 2) then Exit;
  dCol := toCol - fromCol;
  dRow := toRow - fromRow;
  if not (CbtMap.ViewCoordsValid(fromCol - GDVars.arenaPtr^.ox, fromRow - GDVars.arenaPtr^.oy) and
          CbtMap.ViewCoordsValid(toCol - GDVars.arenaPtr^.ox, toRow - GDVars.arenaPtr^.oy)) then begin
    if (Abs(dCol) <= 6) and (Abs(dRow) <= 6) then begin
      near := 1;
      cursorCol := dCol div 2 + fromCol;
      cursorRow := dRow div 2 + fromRow;
    end else begin
      near := 0;
      cursorCol := GDVars.arenaPtr^.ox + 3;
      cursorRow := GDVars.arenaPtr^.oy + 3;
    end;
  end else begin
    near := 1;
    cursorCol := GDVars.arenaPtr^.ox + 3;
    cursorRow := GDVars.arenaPtr^.oy + 3;
  end;
  CbtMap.ScrollView(ShortInt(cursorCol), ShortInt(cursorRow), 255, C_Dir.CENTER);
  n := 0;
  accumX := 0;
  accumY := 0;
  repeat
    pixX := (fromCol - GDVars.arenaPtr^.ox) * 3 + accumX;
    pixY := (fromRow - GDVars.arenaPtr^.oy) * 3 + accumY;
    prevX := fromCol;
    prevY := fromRow;
    stop := False;
    repeat
      stepX := GDConsts.dirDx[path[n]];
      stepY := GDConsts.dirDy[path[n]];
      Inc(pixX, stepX);
      Inc(pixY, stepY);
      if (delayVal > 0) or (pixX mod 3 = 0) or (pixY mod 3 = 0) then begin
        Blit.BlitTileClipped(pixX, pixY, frameIx, 5, GDVars.iconBuf, GDVars.viewBuf);
        Blit.FlushView;
        Delay(delayVal);
        Blit.BlitTileClipped(pixX, pixY, 0, 0, GDVars.saveUnder, GDVars.viewBuf);
        Inc(frameIx);
        if frameIx >= frameCount then frameIx := 0;
      end;
      Inc(n);
      if (pixX < 0) or (pixX > 18) or (pixY < 0) or (pixY > 18) then stop := True;
      if (not stop) and (n < limit) then begin
        Inc(accumX, stepX);
        Inc(accumY, stepY);
        if Abs(accumX) = 3 then begin
          Inc(fromCol, Pathing.SignOf(accumX));
          Inc(cursorCol, Pathing.SignOf(accumX));
          accumX := 0;
        end;
        if Abs(accumY) = 3 then begin
          Inc(fromRow, Pathing.SignOf(accumY));
          Inc(cursorRow, Pathing.SignOf(accumY));
          accumY := 0;
        end;
      end;
    until (n >= limit) or stop;
    if n < limit then begin
      clampX := 0;
      clampY := 0;
      accumY := 0;
      accumX := 0;
      fromCol := toCol;
      fromRow := toRow;
      prevX := fromCol;
      prevY := fromRow;
      if toCol + 3 > 49 then
        clampX := toCol - 49
      else if toCol < 3 then
        clampX := 3 - toCol;
      if toRow + 3 > 24 then
        clampY := toRow - 24
      else if toRow < 3 then
        clampY := 3 - toRow;
      cursorCol := toCol + clampX;
      cursorRow := toRow + clampY;
      CbtMap.ScrollView(ShortInt(cursorCol), ShortInt(cursorRow), 255, C_Dir.CENTER);
      pixX := (toCol - GDVars.arenaPtr^.ox) * 3;
      pixY := (toRow - GDVars.arenaPtr^.oy) * 3;
      n := limit;
      stop := False;
      repeat
        stepX := -GDConsts.dirDx[path[n]];
        stepY := -GDConsts.dirDy[path[n]];
        Inc(pixX, stepX);
        Inc(pixY, stepY);
        if pixX > 18 then
          fromCol := GDVars.arenaPtr^.ox + 6
        else if pixX < 0 then
          fromCol := GDVars.arenaPtr^.ox;
        if pixY > 18 then
          fromRow := GDVars.arenaPtr^.oy + 6
        else if pixY < 0 then
          fromRow := GDVars.arenaPtr^.oy;
        if (pixX < 0) or (pixX > 18) or (pixY < 0) or (pixY > 18) then stop := True;
        if not stop then begin
          Inc(accumX, stepX);
          Inc(accumY, stepY);
          if Abs(accumX) = 3 then begin
            Inc(fromCol, Pathing.SignOf(accumX));
            Inc(cursorCol, Pathing.SignOf(accumX));
            accumX := 0;
          end;
          if Abs(accumY) = 3 then begin
            Inc(fromRow, Pathing.SignOf(accumY));
            Inc(cursorRow, Pathing.SignOf(accumY));
            accumY := 0;
          end;
          Dec(n);
        end;
      until stop;
    end else begin
      near := 1;
      if not CbtMap.ViewCoordsValid(toCol - GDVars.arenaPtr^.ox, toRow - GDVars.arenaPtr^.oy) then
        CbtMap.ScrollView(ShortInt(toCol), ShortInt(toRow), 3, C_Dir.CENTER);
      pixX := (toCol - GDVars.arenaPtr^.ox) * 3;
      pixY := (toRow - GDVars.arenaPtr^.oy) * 3;
      Blit.BlitTileClipped(pixX, pixY, frameIx, 5, GDVars.iconBuf, GDVars.viewBuf);
      if delayVal > 0 then begin
        Blit.FlushView;
        Delay(delayVal);
        Blit.BlitTileClipped(pixX, pixY, 0, 0, GDVars.saveUnder, GDVars.viewBuf);
      end;
    end;
  until near <> 0;
  Blit.FlushView;
end;

procedure RecalcStats(cr: Types.PCharRecord);
var
  k: Byte;
  j: ShortInt;
  p: Types.PItemRec;
  isMagicBody: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  bag: Byte;
  adj: TAcAdjust;
  e: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  propertySlot: Byte;
  c: ShortInt;
  w: Word;
  slot: Byte;
begin
  for e := 0 to 12 do
    cr^.equipped[e] := nil;
  bag := 0;
  cr^.numberOfItems := 0;
  p := cr^.itemsAddr;
  cr^.handsEquipped := 0;
  cr^.encumbrance := 0;
  GDVars.gEquipWeight := 0;
  while p <> nil do begin
    Inc(cr^.numberOfItems);
    w := p^.weight;
    if p^.quantity > 0 then
      w := p^.quantity * w;
    Inc(cr^.encumbrance, w);
    if p^.equipped <> 0 then begin
      Inc(GDVars.gEquipWeight, w);
      slot := GDVars.baseItems[p^.itemType].slot;
      case slot of
        0..8: cr^.equipped[ShortInt(slot)] := p;
        9:
          if cr^.equipped[9] <> nil then begin
            if cr^.equipped[10] = nil then
              cr^.equipped[10] := p;
          end else
            cr^.equipped[9] := p;
      end;
      if p^.itemType = 30 then
        cr^.equipped[11] := p;
      if p^.itemType = 12 then
        cr^.equipped[12] := p;
      cr^.handsEquipped := cr^.handsEquipped + GDVars.baseItems[p^.itemType].hands;
    end;
    p := p^.next;
  end;
  for c := C_Money.COPPER to C_Money.JEWELRY do
    cr^.encumbrance := cr^.encumbrance + cr^.coinsA[c];
  for k := 1 to 2 do begin
    cr^.curRollsA[k] := cr^.unarmedRollsA[k];
    cr^.curDiceA[k] := cr^.unarmedDiceA[k];
    cr^.curModA[k] := cr^.unarmedModA[k];
  end;
  for j := 0 to 4 do
    adj[j] := 0;
  isMagicBody := False;
  cr^.saveBonus := 0;
  cr^.acCurArr[0] := cr^.acBase;
  cr^.toHitCur := cr^.baseToHit;
  adj[0] := CharHlp.DexterityArmorAdjustment(cr);
  if cr^.equipped[0] = nil then begin
    cr^.toHitCur := cr^.toHitCur + CharHlp.StrToHitAdjust(cr);
    cr^.curModA[1] := cr^.curModA[1] + CharHlp.StrDamageAdjust(cr);
  end;
  CharHlp.WeaponAdjust(cr);
  p := cr^.itemsAddr;
  while p <> nil do begin
    if p^.equipped <> 0 then
      CharHlp.AddItemArmorAdjust(cr, p, adj, isMagicBody);
    p := p^.next;
  end;
  if isMagicBody then
    adj[3] := 0;
  cr^.movementCur := CharHlp.RecalcMovement(cr) div 2;
  if adj[4] < cr^.acCurArr[0] then
    adj[4] := cr^.acCurArr[0];
  cr^.acCurArr[0] := 0;
  for j := 0 to 4 do
    cr^.acCurArr[0] := cr^.acCurArr[0] + adj[j];
  cr^.acCurArr[1] := adj[4] + adj[2] + adj[3] - 2;
  { Note: the inner disjunction tests fighterOldLevelV1 three times where the outer one walks
    fighterLevelV1/paladinLevelV1/rangerLevelV1. }
  if ((ShortInt(cr^.fighterLevelV1) > 0) or (ShortInt(cr^.paladinLevelV1) > 0) or (ShortInt(cr^.rangerLevelV1) > 0) or
      (((ShortInt(cr^.fighterOldLevelV1) > 0) or (ShortInt(cr^.fighterOldLevelV1) > 0) or
        (ShortInt(cr^.fighterOldLevelV1) > 0)) and
       ClassCal.EarlierClassActive(cr)))
     and (cr^.race <> C_Race.TRIBBLE) and (cr^.race <> C_Race.MONSTER) then begin
    cr^.attackLevelV1 := cr^.fighterLevelV1;
    if cr^.rangerLevelV1 > cr^.attackLevelV1 then cr^.attackLevelV1 := cr^.rangerLevelV1;
    if cr^.paladinLevelV1 > cr^.attackLevelV1 then cr^.attackLevelV1 := cr^.paladinLevelV1;
  end else
    cr^.attackLevelV1 := 1;
end;

function RecalcMovement(cr: Types.PCharRecord): Byte;
var
  p: Types.PItemRec;
  eff: Types.PEffectRec;
begin
  cr^.movementCur := cr^.movementBase;
  p := cr^.itemsAddr;
  while p <> nil do begin
    if p^.equipped <> 0 then
      CharHlp.ArmorMoveAdjust(cr, p);
    p := p^.next;
  end;
  CharHlp.EncumbranceAdjust(cr);
  if CharHlp.HasEffect(cr, C_Effect.HASTED, eff) then
    cr^.movementCur := cr^.movementCur * 2;
  if CharHlp.HasEffect(cr, C_Effect.SLOWED, eff) then
    cr^.movementCur := cr^.movementCur div 2;
  if CharHlp.HasEffect(cr, 74, eff) then
    cr^.movementCur := cr^.movementCur * 2;
  GDVars.movement := cr^.movementCur;
  if cr^.hostile = 0 then
    GDVars.movement := GDVars.movement + GDVars.zone1^.partyMoveBonus;
  GDVars.movement := GDVars.movement * 2;
  RecalcMovement := GDVars.movement;
end;

procedure PrintNameStringAnim(cr: Types.PCharRecord; hit: Byte; msg: String);
var
  deltaX: ShortInt;
  deltaY: ShortInt;
  facing: Byte;
  j: Byte;
  i: Byte;
  reps: Byte;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    if hit <> 0 then facing := 22 else facing := 23;
    CharHlp.BuildIconFacings(facing);
    if not CbtMap.CombatIconVisible(cr, 1) then
      CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 3, C_Dir.CENTER);
    if hit <> 0 then SoundDrv.SoundCommand(GDConsts.hitSound) else SoundDrv.SoundCommand(GDConsts.missSound);
    CharHlp.PrintCreatureMessage(cr, msg, 10, False);
    if hit <> 0 then reps := GDVars.gameDelay else reps := 0;
    deltaX := GDVars.gridX[CbtMap.CombatSlot(cr)] * 3;
    deltaY := GDVars.gridY[CbtMap.CombatSlot(cr)] * 3;
    for i := 0 to reps do
      for j := 0 to 3 do begin
        Blit.BlitTileClipped(deltaX, deltaY, j, 5, GDVars.iconBuf, GDVars.viewBuf);
        Blit.FlushView;
        Delay(70);
        Blit.BlitTileClipped(deltaX, deltaY, 0, 0, GDVars.saveUnder, GDVars.viewBuf);
      end;
    Blit.FlushView;
    if reps = 0 then TextRend.PauseOnly;
  end else
    CharHlp.PrintCreatureMessage(cr, msg, 10, True);
end;

function HasEffect(cr: Types.PCharRecord; id: Byte; var eff: Types.PEffectRec): Boolean;
var
  found: Boolean;
begin
  found := False;
  eff := cr^.effectsAddr;
  while (eff <> nil) and not found do
    if eff^.id = id then
      found := True
    else
      eff := eff^.next;
  HasEffect := found;
end;

procedure InflictDamage(cr: Types.PCharRecord; damage: Byte);
var
  overkill: Byte;
  remaining: Byte;
begin
  overkill := 0;
  remaining := 0;
  if cr^.hpCur >= damage then
    remaining := cr^.hpCur - damage
  else
    overkill := damage - cr^.hpCur;
  if (overkill > 9) or ((remaining = 0) and (cr^.status = C_Status.ANIMATED)) then
    cr^.status := C_Status.DEAD_STATUS
  else if overkill > 0 then begin
    cr^.status := C_Status.DYING;
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then
      cr^.combatAddr^.damageTaken := overkill;
  end else if remaining = 0 then
    cr^.status := C_Status.UNCONSCIOUS;
  if not (cr^.status in [C_Status.OKAY, C_Status.ANIMATED]) then begin
    cr^.enabled := 0;
    cr^.hpCur := 0;
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
      Dec(GDVars.teamCount[cr^.hostile]);
      cr^.combatAddr^.initiativeV1 := 0;
    end;
  end else
    cr^.hpCur := remaining;
end;

procedure AnnounceHealStatus(cr: Types.PCharRecord);
var
  s: Types.TStr40;
begin
  if cr^.hpCur = cr^.hpMax then
    s := 'is fully healed'
  else
    s := 'is partially healed';
  CharHlp.PrintCreatureMessage(cr, s, 10, True);
  if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
    CharHlp.DisplayParty(cr, cr = GDVars.curChar);
end;

function EnemyTeam(cr: Types.PCharRecord): ShortInt;
begin
  if cr^.hostile = 0 then
    EnemyTeam := 1
  else
    EnemyTeam := 0;
end;

procedure CountTeams;
var
  p: Types.PCharRecord;
begin
  GDVars.teamCount[0] := 0;
  GDVars.teamCount[1] := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    if p^.enabled <> 0 then
      Inc(GDVars.teamCount[p^.hostile]);
    p := p^.nextCharAddr;
  end;
end;

function CountTargets(cr: Types.PCharRecord; kind: Byte): Byte;
var
  cnt: Byte;
  t: Byte;
  i: Byte;
  eff: Types.PEffectRec;
  done: Boolean;
begin
  Pathing.BuildTargetList(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), kind, 255, CbtMap.GetIconSize(cr),
                          GDVars.arenaPtr);
  cnt := GDVars.targetCount;
  t := 0;
  if cnt > 0 then begin
    for i := 1 to cnt do
      if CharHlp.EnemyTeam(cr) = GDVars.creatures[GDVars.targets[i].who]^.hostile then begin
        Inc(t);
        Move(GDVars.targets[i], GDVars.targets[t], SizeOf(Types.TTarget));
      end;
    cnt := t;
    GDVars.targetCount := t;
  end;
  CountTargets := cnt;
  for i := 1 to cnt do
    GDVars.targetIdx[i] := GDVars.targets[i].who;
  if CharHlp.HasEffect(cr, 91, eff) then begin
    i := 1;
    done := False;
    while (i <= cnt) and not done do begin
      if GDVars.creatures[GDVars.targetIdx[i]] = GDVars.curCreature then begin
        t := GDVars.targetIdx[1];
        GDVars.targetIdx[1] := GDVars.targetIdx[i];
        GDVars.targetIdx[i] := t;
        done := True;
      end;
      Inc(i);
    end;
  end;
end;

function CalcDistance(from, target: Types.PCharRecord): Byte;
var
  save: array[1..255] of Types.TTarget;
  i: Byte;
begin
  Move(GDVars.targets, save, SizeOf(GDVars.targets));
  GDVars.arenaPtr^.distMode := 1;
  Pathing.BuildTargetList(CbtMap.CombatCellX(from), CbtMap.CombatCellY(from), 255, 255, CbtMap.GetIconSize(from),
                          GDVars.arenaPtr);
  GDVars.arenaPtr^.distMode := 0;
  i := 1;
  while (GDVars.creatures[GDVars.targets[i].who] <> target) and (i < GDVars.targetCount) do
    Inc(i);
  CalcDistance := GDVars.targets[i].dist2 div 2;
  Move(save, GDVars.targets, SizeOf(GDVars.targets));
end;

function EndActions(cr: Types.PCharRecord): Boolean;
begin
  cr^.combatAddr^.initiativeV1 := 0;
  cr^.combatAddr^.spellCast := 0;
  cr^.combatAddr^.guarding := 0;
  cr^.combatAddr^.movement := 0;
  EndActions := True;
end;

function Guard(cr: Types.PCharRecord): Boolean;
begin
  Guard := CharHlp.EndActions(cr);
  if cr^.combatAddr^.forcedFlee = 0 then begin
    cr^.combatAddr^.guarding := 1;
    CharHlp.PrintBottomLine('Guarding');
  end;
end;

function GetCasterLevel(spell: Byte): Byte;
var
  a: ShortInt;
  b: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  lookupValue: Word;
begin
  if (GDVars.curChar^.clericLevelV1 = 0) and (GDVars.curChar^.mageLevelV1 = 0)
     and (ShortInt(GDVars.curChar^.rangerLevelV1) < 8) then
    GetCasterLevel := 6
  else
    case GDConsts.spellDefs[spell].castClass of
      C_Spell.CLERIC_LIST: begin
           a := ShortInt(GDVars.curChar^.clericLevelV1)
                + ShortInt(GDVars.curChar^.clericOldLevelV1) * Ord(ClassCal.EarlierClassActive(GDVars.curChar));
           b := ShortInt(GDVars.curChar^.paladinLevelV1)
                + ShortInt(GDVars.curChar^.paladinOldLevelV1) * Ord(ClassCal.EarlierClassActive(GDVars.curChar));
           if a > b then GetCasterLevel := a else GetCasterLevel := b;
         end;
      C_Spell.DRUID_LIST: begin
           a := ShortInt(GDVars.curChar^.rangerLevelV1)
                + ShortInt(GDVars.curChar^.rangerOldLevelV1) * Ord(ClassCal.EarlierClassActive(GDVars.curChar)) - 7;
           if a > 0 then GetCasterLevel := a else GetCasterLevel := 0;
         end;
      C_Spell.MAGE_LIST: begin
           a := ShortInt(GDVars.curChar^.mageLevelV1)
                + ShortInt(GDVars.curChar^.mageOldLevelV1) * Ord(ClassCal.EarlierClassActive(GDVars.curChar));
           b := ShortInt(GDVars.curChar^.rangerLevelV1)
                + ShortInt(GDVars.curChar^.rangerOldLevelV1) * Ord(ClassCal.EarlierClassActive(GDVars.curChar)) - 8;
           if a > b then GetCasterLevel := a else GetCasterLevel := b;
         end;
      C_Spell.SPECIAL_LIST: GetCasterLevel := 12;
    end;
  if (GDVars.usingItemFlag <> 0) and
      (GDConsts.spellDefs[spell].castClass <> C_Spell.SPECIAL_LIST) then GetCasterLevel := 6;
end;

procedure DisplayNoncombatInterface;
begin
  GDVars.viewDirty := 1;
  case GDVars.interfaceState of
    C_Ifc.MAIN_MENU: Border.DrawWindowFrame(1);
    C_Ifc.IN_VAULT, C_Ifc.SHOP_TEMPLE: begin
            if GDVars.shopPanelOn <> 0 then Border.DrawExploreFrame;
            Portrait.DisplayImageBuf(3, 3, Boolean(1), GDVars.animData.frames[1].pic);
            CharHlp.DisplayRoster(GDVars.curChar);
            CharHlp.PrintPositionAndTime;
          end;
    C_Ifc.CAMPING: begin
         Border.DrawExploreFrame;
         Portrait.LoadAnimation('PIC', 59, 0, GDVars.animData);
         CharHlp.DisplayRoster(GDVars.curChar);
         CharHlp.PrintPositionAndTime;
       end;
    C_Ifc.INDOORS: begin
         Border.DrawExploreFrame;
         if GDVars.zone0^.areaView = 0 then MapView.DisplayMapView;
         CharHlp.DisplayRoster(GDVars.curChar);
         CharHlp.PrintPositionAndTime;
         GDVars.needPanelRedraw := 0;
       end;
    C_Ifc.OVERLAND: if (GDVars.picArcId <> 9) and (GDVars.zone0^.areaView = 0) then MapView.DisplayMapView;
    C_Ifc.LOOT: begin
         Border.DrawExploreFrame;
         Portrait.LoadAnimation('PIC', 60, 0, GDVars.animData);
         CharHlp.DisplayRoster(GDVars.curChar);
       end;
  end;
end;

procedure PrintPositionAndTime;
var
  mapX: Byte;
  mapY: Byte;
  hourStr: String[2];
  minuteStr: String[2];
  line: Types.TStr40;
  dirIx: Byte;
  useZoneCoords: Boolean;
begin
  if GDVars.interfaceState = C_Ifc.OVERLAND then Exit;
  line := '';
  if GDVars.zone0^.statusX = 255 then useZoneCoords := False else useZoneCoords := True;
  if useZoneCoords then begin
    mapX := Byte(GDVars.zone0^.statusX);
    mapY := GDVars.zone0^.statusY;
  end else begin
    mapX := GDVars.partyPos.mapX;
    mapY := GDVars.partyPos.mapY;
  end;
  hourStr := CharHlp.Uint16Str(GDVars.zone0^.clock[$4BC9]);
  if Length(hourStr) < 2 then hourStr := '0' + hourStr;
  minuteStr := CharHlp.Uint16Str(GDVars.zone0^.clock[$4BC8] * 10 + GDVars.zone0^.clock[$4BC7]);
  if Length(minuteStr) < 2 then minuteStr := '0' + minuteStr;
  line := CharHlp.Uint8Str(mapX) + ',' + CharHlp.Uint8Str(mapY) + ' ';
  if GDVars.zone0^.view3dFlag <> 0 then
    dirIx := GDVars.zone0^.facingOffset * 2 + GDVars.partyPos.facing
  else
    dirIx := GDVars.partyPos.facing + GDVars.zone0^.facingOffset;
  if dirIx >= 8 then Dec(dirIx, 8);
  line := line + GDConsts.dirNames[dirIx] + ' ';
  line := line + hourStr + ':' + minuteStr;
  if GDVars.debugOn then line := line + '*';
  if GDVars.interfaceState = C_Ifc.CAMPING then
    line := line + ' camping'
  else if (GDVars.zone1^.searchFlags and 1) > 0 then
    line := line + ' search';
  Border.ClearBox(17, 15, 38, 15);
  TextRend.DisplayString(17, 15, LightGreen, 0, line);
end;

procedure DisplayCombatInterface;
begin
  CbtMap.SetCombatPalette;
  Border.DrawCombatFrame;
  CbtMap.ScrollView(ShortInt(GDVars.arenaPtr^.ox + 3), ShortInt(GDVars.arenaPtr^.oy + 3), 255, C_Dir.CENTER);
end;

function HasRangedWeapon(cr: Types.PCharRecord): Boolean;
begin
  if (cr^.equipped[0] <> nil) and (GDVars.baseItems[cr^.equipped[0]^.itemType].range > 1) then
    HasRangedWeapon := True
  else
    HasRangedWeapon := False;
end;

function HasThrowableWeapon(cr: Types.PCharRecord): Boolean;
begin
  if CharHlp.HasRangedWeapon(cr) and
      (((GDVars.baseItems[cr^.equipped[0]^.itemType].props and $14) = $14) or (cr^.equipped[0]^.itemType = 67)) then
    HasThrowableWeapon := True
  else
    HasThrowableWeapon := False;
end;

function FindDamagingRangedWeapon(cr: Types.PCharRecord; var sel: Types.PItemRec): Boolean;
var
  w: Types.PItemRec;
  props: Byte;
begin
  FindDamagingRangedWeapon := False;
  w := cr^.equipped[0];
  sel := nil;
  props := 0;
  if w <> nil then begin
    props := GDVars.baseItems[w^.itemType].props;
    if (props and $10) <> 0 then
      sel := w;
    if (props and $8) <> 0 then begin
      if (props and $1) <> 0 then
        sel := cr^.equipped[11];
      if (props and $80) <> 0 then
        sel := cr^.equipped[12];
    end;
  end;
  if (sel <> nil) or (props = $A) then
    FindDamagingRangedWeapon := True;
end;

function BandageDying(apply: Byte): Boolean;
var
  p: Types.PCharRecord;
  any: Boolean;
begin
  any := False;
  p := GDVars.creatureList;
  while p <> nil do begin
    if (p^.combatAddr^.notPcNpcV1 = 0) and (p^.hostile = 0) and (p^.status = C_Status.DYING) then begin
      any := True;
      if apply <> 0 then begin
        p^.status := C_Status.UNCONSCIOUS;
        p^.combatAddr^.damageTaken := 0;
        CharHlp.PrintCreatureMessage(p, 'is bandaged', 10, True);
        apply := 0;
      end;
    end;
    p := p^.nextCharAddr;
  end;
  BandageDying := any;
end;

procedure SelectChar(prompt: Types.TStr40; allowExit, lockSel: Byte; var sel: Types.PCharRecord);
var
  key: Char;
  ext: Boolean;
  style: Byte;
  p: Types.PCharRecord;
  items: Types.TStr40;
  savedRosterMouse: Byte;
  savedRosterPick: Byte;
begin
  savedRosterMouse := GDVars.rosterMouseOn;
  savedRosterPick := GDVars.rosterPickMenu;
  GDVars.rosterPickMenu := 1;
  GDVars.selOverride := lockSel;
  GDVars.selOverrideWho := sel;
  key := ' ';
  items := '';
  if allowExit <> 0 then items := ' Exit';
  while not (key in [C_Keys.ENTER, C_Keys.ESCAPE, 'E', 'S']) do
  begin
    CharHlp.DisplayRoster(sel);
    if (GDVars.interfaceState = C_Ifc.CAMPING) or
        (GDVars.interfaceState = C_Ifc.LOOT) then style := 1 else style := 0;
    if (GDVars.interfaceState = C_Ifc.MAIN_MENU) or
        (GDVars.interfaceState = C_Ifc.CAMPING) then GDVars.rosterMouseOn := 1;
    key := MenuCore.MenuHorizontal(prompt + ' ', 'Select' + items, LightMagenta, LightGreen, White, 1, style, ext);
    GDVars.rosterMouseOn := savedRosterMouse;
    p := sel;
    if ext then begin
      case key of
        C_Keys.DOWN:
          begin
            p := p^.nextCharAddr;
            if p = nil then p := GDVars.creatureList;
          end;
        C_Keys.UP:
          if GDVars.mouseClk then begin
            if GDVars.selOverride <> 0 then p := GDVars.selOverrideWho else p := GDVars.curChar;
          end else begin
            p := GDVars.creatureList;
            if sel <> GDVars.creatureList then begin
              while p^.nextCharAddr <> sel do p := p^.nextCharAddr;
            end else begin
              while p^.nextCharAddr <> nil do p := p^.nextCharAddr;
            end;
          end;
      end;
    end else
      if allowExit <> 0 then
        if (key = 'E') or (key = C_Keys.NONE) then p := nil;
    sel := p;
  end;
  GDVars.rosterPickMenu := savedRosterPick;
  GDVars.selOverride := 0;
end;

function DirTowardTarget(creature, other: Types.PCharRecord): Byte;
var
  dir: Byte;
  found: Boolean;
  x1: Integer;
  y1: Integer;
  x2: Integer;
  y2: Integer;
  deltaX: Integer;
  deltaY: Integer;
begin
  x1 := ShortInt(CbtMap.CombatCellX(creature));
  y1 := ShortInt(CbtMap.CombatCellY(creature));
  x2 := ShortInt(CbtMap.CombatCellX(other));
  y2 := ShortInt(CbtMap.CombatCellY(other));
  deltaX := Abs(x2 - x1);
  deltaY := Abs(y2 - y1);
  dir := C_Dir.NORTH;
  found := False;
  while not found do begin
    case dir of
      C_Dir.NORTHEAST: found := (y2 < y1) and (x2 > x1)
                  and (deltaX * 618 div 256 >= deltaY)
                  and (deltaX * 106 div 256 <= deltaY);
      C_Dir.SOUTHEAST: found := (y2 > y1) and (x2 > x1)
                  and (deltaX * 618 div 256 >= deltaY)
                  and (deltaX * 106 div 256 <= deltaY);
      C_Dir.SOUTHWEST: found := (y2 > y1) and (x2 < x1)
                  and (deltaX * 618 div 256 >= deltaY)
                  and (deltaX * 106 div 256 <= deltaY);
      C_Dir.NORTHWEST: found := (y2 < y1) and (x2 < x1)
                  and (deltaX * 618 div 256 >= deltaY)
                  and (deltaX * 106 div 256 <= deltaY);
      C_Dir.NORTH: found := (y2 <= y1) and (deltaX * 618 div 256 <= deltaY);
      C_Dir.EAST: found := (x2 >= x1) and (deltaX * 106 div 256 >= deltaY);
      C_Dir.SOUTH: found := (y2 >= y1) and (deltaX * 618 div 256 <= deltaY);
      C_Dir.WEST: found := (x2 <= x1) and (deltaX * 106 div 256 >= deltaY);
    end;
    if not found then Inc(dir);
  end;
  DirTowardTarget := dir;
end;

begin
end.

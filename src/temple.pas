{ Temple healing services. }
{$O+,F+,I-}
unit Temple;

interface

uses Types, EclMenu, ViewChar, Magic, Money, FxEngine, CharHlp, MenuCore, Border, TextRend, GameIo, Crt, GDConsts,
  GDVars, C_Race, C_Status, C_Class, C_Effect, C_Keys, C_Ifc, C_Stat;

{ Runs a temple. The money pool starts empty; the menu offers Heal, View, Pool and Appraise, plus Take and Share while
  the pool holds money; the up and down arrow keys change the current character. Exit with money left in the pool asks
  whether to go back for it. }
procedure TempleMainMenu;

{ Cure Blindness for the current character: removes Blind, or says it is not blind. }
procedure CureBlindness;

{ Cures the current character's disease: removes the four disease effects with the effect lock set and recalculates its
  Strength, or says it is not diseased. }
procedure CureDisease;

{ Heals the current character, or tells a dead, petrified or gone character, or one at full hit points, why it is not
  healed.
  @param(kind 1 for 1d8, 2 for 2d8 + 1, 3 for 3d8 + 3, 4 for all but 1d4 hit points with Blind, Feebleminded and the
    disease effects removed and Intelligence and Wisdom recalculated.) }
procedure CureWounds(kind: Byte);

{ Raise Dead for the current character (a character that is not dead, or an elf, is told so and nothing changes): it
  comes back okay at 1 hit point, with poison removed under the effect lock, and loses a point of Constitution. At
  Constitution 14 and up, its hit points above the rolled ones are divided by its Constitution hit-point bonus over its
  class levels (undivided when that bonus is 0), and the result comes off its maximum when its Constitution is below 17
  or it has fighter levels, and its stats are recalculated. Note: the class loop runs one entry past the current levels,
  and a third test, the fighter level against dualClassThreshold, adds no case to the fighter test. }
procedure RaiseDead;

{ Neutralize Poison for the current character: a poisoned character loses Poisoned and both slow-poison effects under
  the effect lock, comes back into play okay, and has at least 1 hit point; otherwise it is told it is not poisoned. }
procedure NeutralizePoison;

{ Remove Curse for the current character: casts the spell (Magic.SpellRemoveCurse) when it carries a cursed item or has
  the Bestow Curse effect, else says it is not cursed. }
procedure RemoveCurse;

{ Stone to Flesh for the current character: a petrified character comes back into play okay at 1 hit point; otherwise it
  is told it is not petrified. }
procedure StoneToFlesh;

{ Lists the temple's ten healing services and runs the chosen one (Heal or Enter) for the current character until the
  player leaves, then redraws the party display. }
procedure HealMenu;

implementation

procedure CureBlindness;
var
  eff: Types.PEffectRec;
  s: String;
begin
  if not CharHlp.HasEffect(GDVars.curChar, C_Effect.BLIND, eff) then
    s := 'is not blind'
  else begin
    FxEngine.RemoveEffect(GDVars.curChar, C_Effect.BLIND, nil);
    s := 'can see!';
  end;
  CharHlp.PrintCreatureMessage(GDVars.curChar, s, 10, True);
end;

procedure CureDisease;
var
  eff: Types.PEffectRec;
  s: String;
  i: Byte;
  found: Byte;
begin
  found := 0;
  for i := 1 to 4 do
    if CharHlp.HasEffect(GDVars.curChar, GDConsts.diseaseFx[i], eff) then begin
      found := 1;
      i := 4;
    end;
  if found = 0 then
    s := 'is not Diseased'
  else begin
    s := GDConsts.curedMsg;
    GDVars.effectLock := 1;
    for i := 1 to 4 do FxEngine.RemoveEffect(GDVars.curChar, GDConsts.diseaseFx[i], nil);
    FxEngine.RecalcAbility(GDVars.curChar, C_Stat.STRENGTH);
    GDVars.effectLock := 0;
  end;
  CharHlp.PrintCreatureMessage(GDVars.curChar, s, 0, True);
end;

procedure CureWounds(kind: Byte);
var
  r: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  restored: Boolean;
  p: Types.PCharRecord;
  fully: Byte;
  healed: Byte;
  s: String;
  eff: Types.PEffectRec;
begin
  p := GDVars.curChar;
  healed := 0;
  fully := 0;
  s := 'is healed';
  if p^.status = C_Status.DEAD_STATUS then begin kind := 0; s := 'must be raised from dead'; end;
  if p^.status = C_Status.PETRIFIED then begin kind := 0; s := 'can only be healed by a stonemason'; end;
  if p^.status = C_Status.GONE then begin kind := 0; s := 'is not here'; end;
  if p^.hpCurrent = p^.hpMax then begin fully := 1; s := 'has no need of healing'; end;
  case kind of
    1: if fully = 0 then r := FxEngine.RollDice(1, 8);
    2: if fully = 0 then r := FxEngine.RollDice(2, 8) + 1;
    3: if fully = 0 then r := FxEngine.RollDice(3, 8) + 3;
    4: begin
         if fully = 0 then r := p^.hpMax - p^.hpCurrent - FxEngine.RollDice(1, 4);
         if CharHlp.HasEffect(p, C_Effect.BLIND, eff) then begin FxEngine.RemoveEffect(p, C_Effect.BLIND,
             nil); healed := 1; end;
         if CharHlp.HasEffect(p, C_Effect.FEEBLEMINDED, eff) then begin
           FxEngine.RemoveEffect(p, C_Effect.FEEBLEMINDED, nil);
           healed := 1;
         end;
         for i := 1 to 4 do
           if CharHlp.HasEffect(p, GDConsts.diseaseFx[i], eff) then begin
             FxEngine.RemoveEffect(p, GDConsts.diseaseFx[i], nil);
             healed := 1;
           end;
         if healed <> 0 then CharHlp.PrintCreatureMessage(p, GDConsts.curedMsg, 0, True);
         if (fully = 0) and (healed <> 0) then s := 'is fully healed';
         FxEngine.RecalcAbility(p, C_Stat.INTELLIGENCE);
         FxEngine.RecalcAbility(p, C_Stat.WISDOM);
       end;
  end;
  if fully = 0 then restored := FxEngine.RestoreHitPoints(p, r, 0);
  CharHlp.PrintCreatureMessage(p, s, 0, True);
end;

procedure RaiseDead;
var
  { Unused in this version; see the other implementations of this routine. }
  effectNode: Types.PEffectRec;
  s: String;
  flag1: Byte;
  hpLoss: Byte;
  hpTotal: Byte;
  classIdx: ShortInt;
  p: Types.PCharRecord;
  flag2: Byte;
begin
  p := GDVars.curChar;
  flag1 := 0;
  flag2 := 0;
  if p^.status = C_Status.DEAD_STATUS then flag1 := 1;
  { an elf cannot be raised, so flag2 turns the prayer into 'cannot be raised' }
  if p^.race = C_Race.ELF then flag2 := 1;
  if flag1 = 0 then
    s := 'is not dead yet'
  else if flag2 <> 0 then
    s := 'cannot be raised'
  else begin
    s := 'is ressurected';
    GDVars.effectLock := 1;
    FxEngine.RemoveEffect(p, C_Effect.POISONED, nil);
    GDVars.effectLock := 0;
    p^.hpCurrent := 1;
    p^.status := C_Status.OKAY;
    p^.enabled := 1;
    if p^.stats[C_Stat.CONSTITUTION].cur > 0 then Dec(p^.stats[C_Stat.CONSTITUTION].cur);
    if p^.hpMax > p^.hpRolled then
      hpLoss := p^.hpMax - p^.hpRolled
    else
      hpLoss := 0;
    hpTotal := 0;
    if p^.stats[C_Stat.CONSTITUTION].cur >= 14 then begin
      { Note: the eighth pass reads classLevelB[0] }
      for classIdx := 0 to 7 do
        if p^.classLevelA[classIdx] > 0 then begin
          if (classIdx = C_Class.FIGHTER) or (classIdx = C_Class.PALADIN) or
              (classIdx = C_Class.RANGER) then
            Inc(hpTotal, (p^.stats[C_Stat.CONSTITUTION].cur - 14) * p^.classLevelA[classIdx])
          else if p^.stats[C_Stat.CONSTITUTION].cur > 15 then
            Inc(hpTotal, p^.classLevelA[classIdx] * 2)
          else
            Inc(hpTotal, p^.classLevelA[classIdx]);
        end;
      if hpTotal > 0 then hpLoss := hpLoss div hpTotal;
      if (p^.stats[C_Stat.CONSTITUTION].cur < 17) or (p^.classLevelA[C_Class.FIGHTER] > 0) or
          (p^.classLevelA[C_Class.FIGHTER] > p^.dualClassThreshold) then
        Dec(p^.hpMax, hpLoss);
      CharHlp.RecalcStats(p);
    end;
  end;
  CharHlp.PrintCreatureMessage(p, s, 0, True);
end;

procedure NeutralizePoison;
var
  eff: Types.PEffectRec;
  s: String;
begin
  if CharHlp.HasEffect(GDVars.curChar, C_Effect.POISONED, eff) then begin
    if GDVars.curChar^.hpCurrent = 0 then GDVars.curChar^.hpCurrent := 1;
    GDVars.effectLock := 1;
    FxEngine.RemoveEffect(GDVars.curChar, C_Effect.POISONED, nil);
    FxEngine.RemoveEffect(GDVars.curChar, C_Effect.SLOW_POISON_END, nil);
    FxEngine.RemoveEffect(GDVars.curChar, C_Effect.SLOW_POISON_HIT, nil);
    GDVars.effectLock := 0;
    GDVars.curChar^.enabled := 1;
    GDVars.curChar^.status := C_Status.OKAY;
    s := 'is no longer poisoned';
  end else
    s := 'is not poisoned';
  CharHlp.PrintCreatureMessage(GDVars.curChar, s, 0, True);
end;

procedure RemoveCurse;
var
  found: Byte;
  item: Types.PItemRec;
  eff: Types.PEffectRec;
  s: String;
begin
  found := 0;
  item := GDVars.curChar^.itemsAddr;
  while (item <> nil) and (found = 0) do begin
    if item^.cursed <> 0 then found := 1;
    item := item^.next;
  end;
  if (found <> 0) or CharHlp.HasEffect(GDVars.curChar, C_Effect.BESTOW_CURSE, eff) then begin
    GDVars.castTargets[1] := GDVars.curChar;
    Magic.SpellRemoveCurse;
    s := 'rejoices.  The curse has been lifted!';
  end else
    s := 'is not cursed';
  CharHlp.PrintCreatureMessage(GDVars.curChar, s, 0, True);
end;

procedure StoneToFlesh;
var
  { Unused in this version; see the other implementations of this routine. }
  effectNode: Types.PEffectRec;
  s: String;
begin
  if GDVars.curChar^.status <> C_Status.PETRIFIED then
    s := 'is not petrified'
  else begin
    GDVars.curChar^.status := C_Status.OKAY;
    GDVars.curChar^.enabled := 1;
    GDVars.curChar^.hpCurrent := 1;
    s := 'is turned to flesh';
  end;
  CharHlp.PrintCreatureMessage(GDVars.curChar, s, 0, True);
end;

procedure HealMenu;
var
  list: Types.PItemRec;
  firstPtr: Types.PItemRec;
  highlight: Boolean;
  idx: Byte;
  selIdx: Integer;
  done: Byte;
  prompt: Types.TStr40;
  key: Char;
begin
  done := 0;
  list := nil;
  firstPtr := nil;
  MenuCore.AllocStringList(10, list);
  firstPtr := list;
  idx := 1;
  while list <> nil do begin
    list^.name := GDConsts.healServices[idx];
    list^.isHeader := 0;
    list := list^.next;
    Inc(idx);
  end;
  list := firstPtr;
  TextRend.ClearRect(0, 24, 39, 24);
  highlight := True;
  Border.ScreenText;
  repeat
    prompt := GDVars.curChar^.name + ', how can we help you?';
    TextRend.DisplayString(1, 1, White, 0, prompt);
    key := MenuCore.MenuVertical('', 'Heal Exit', LightMagenta, LightGreen, White, 2, 4, 38, 15, list, 0, highlight,
                                 selIdx, firstPtr);
    case key of
      'H', C_Keys.ENTER:
        case selIdx of
          0: Temple.CureBlindness;
          1: Temple.CureDisease;
          2: Temple.CureWounds(1);
          3: Temple.CureWounds(2);
          4: Temple.CureWounds(3);
          5: Temple.CureWounds(4);
          6: Temple.NeutralizePoison;
          7: Temple.RaiseDead;
          8: Temple.RemoveCurse;
          9: Temple.StoneToFlesh;
          10: done := 1;
        end;
      C_Keys.NONE: done := 1;
    end;
  until done <> 0;
  MenuCore.FreeStringList(list);
  CharHlp.DisplayNoncombatInterface;
  CharHlp.DisplayRoster(GDVars.curChar);
end;

procedure TempleMainMenu;
var
  key: Char;
  done: Byte;
  sub: Boolean;
  msg: Types.TStr40;
  moneyF: Boolean;
  itemsF: Boolean;
  confirm: Byte;
  appraiseF: Boolean;
begin
  GDVars.interfaceState := C_Ifc.SHOP_TEMPLE;
  GDVars.shopPanelOn := 0;
  CharHlp.DisplayNoncombatInterface;
  GDVars.shopPanelOn := 1;
  CharHlp.DisplayRoster(GDVars.curChar);
  GameIo.FillWord(GDVars.treasureMoney, SizeOf(GDVars.treasureMoney));
  GDVars.treasureMoneyFlag := False;
  done := 0;
  repeat
    Money.DetermineTreasure(moneyF, itemsF);
    if moneyF then
      msg := 'Heal View Take Pool Share Appraise Exit'
    else
      msg := 'Heal View Pool Appraise Exit';
    key := MenuCore.MenuHorizontal('', msg, LightMagenta, LightGreen, White, 1, 0, sub);
    case key of
      'H': if not sub then Temple.HealMenu else ViewChar.SelectPrevNextChar(key);
      'V': ViewChar.ViewCharMenu(sub);
      'T': Money.TakeMoneyMenu;
      'P': if not sub then Money.PoolMoney else ViewChar.SelectPrevNextChar(key);
      'S': Money.ShareMoney;
      'A': Money.AppraiseMenu(appraiseF);
      'E': begin
             Money.DetermineTreasure(moneyF, itemsF);
             if moneyF then begin
               msg := '~Yes ~No';
               TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True,
                                    'As you leave a priest says, "Excuse me but you have left some money here" ');
               TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True,
                                    'Do you want to go back and retrieve your money?');
               confirm := EclMenu.MenuHorizontalCharacterSelect('', msg, LightMagenta, LightGreen, White, False, False);
               if confirm = 1 then
                 done := 1
               else
                 TextRend.ClearRect(1, 17, 38, 22);
             end else
               done := 1;
           end;
    end;
    case key of
      'B', 'T': CharHlp.DisplayNoncombatInterface;
      'A': if appraiseF then CharHlp.DisplayNoncombatInterface;
    end;
    CharHlp.DisplayRoster(GDVars.curChar);
  until done <> 0;
end;

begin
end.

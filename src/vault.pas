{ The pool and vault item-storage screen.

  PoolVault opens <dir>vault.dat, reads the coin block (treasureMoney) and then a linked list of item records (container
  items, itemType 'I', carry a chain of sub-items); runs a View / Take / Pool / Exit menu (Take only when there is
  treasure; the up and down arrows change the current character); and on exit computes the needed disk space, warns if
  DiskFree is short, writes the list back, and frees it. Note: the estimate counts top-level items only; bundled
  sub-items are written but not counted. }
{$O+,F+,I-}
unit Vault;

interface

uses Dos, Types, GameIo, DaxIo, PostCbt, SaveLoad, ViewChar, Money, CharHlp, MenuCore, TextRend, Crt, GDVars,
  C_Keys, C_Ifc;

{ Runs the vault, once the save directory is ready: loads the stored coins and items from vault.dat (each bundle with
  its sub-items), then offers View, Take (when there is treasure), Pool and Exit, the up and down arrows changing the
  current character. On exit the vault is written back, with a warning when the disk lacks room, and the item list is
  freed. Note: the room estimate counts top-level items only. }
procedure PoolVault;

implementation

procedure PoolVault;
var
  f: File;
  choice: Char;
  readResult: Word;
  { Unused in this version; see the other implementations of this routine. }
  bytesRead: Byte;
  node: Types.PItemRec;
  t: Types.PItemRec;
  itemBuf: Types.PItemRec;
  daxBuf: String[44];
  exitFlag: Boolean;
  menuFlag: Boolean;
  flagA: Boolean;
  flagB: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  ext: Byte;
  loopI: Byte;
  needed: Word;
  { Unused in this version; see the other implementations of this routine. }
  moved: Integer;
  menuStr: String[40];
begin
  GDVars.interfaceState := C_Ifc.IN_VAULT;
  GDVars.shopPanelOn := 1;
  CharHlp.DisplayNoncombatInterface;
  GDVars.shopPanelOn := 1;
  CharHlp.DisplayRoster(GDVars.curChar);
  if not SaveLoad.CheckSaveDir then Exit;
  GDVars.treasureItems := nil;

  if DaxIo.FileExists(GDVars.saveDir + 'vault.dat') then
  begin
    bytesRead := Ord(DaxIo.OpenWithRetry(GDVars.saveDir + 'vault.dat', daxBuf, #0, f));
    BlockRead(f, GDVars.treasureMoney, SizeOf(GDVars.treasureMoney), readResult);
    flagB := False;
    GetMem(itemBuf, SizeOf(itemBuf^));
    repeat
      BlockRead(f, itemBuf^, SizeOf(Types.TItemRec), readResult);
      if readResult = SizeOf(Types.TItemRec) then begin
        if GDVars.treasureItems = nil then begin
          GetMem(GDVars.treasureItems, SizeOf(GDVars.treasureItems^));
          GDVars.treasureItems^ := itemBuf^;
          GDVars.vaultCur := GDVars.treasureItems;
        end else begin
          GetMem(GDVars.vaultCur^.next, SizeOf(GDVars.vaultCur^.next^));
          GDVars.vaultCur := GDVars.vaultCur^.next;
          GDVars.vaultCur^ := itemBuf^;
        end;
        flagB := True;
        if GDVars.vaultCur^.itemType = Ord('I') then begin
          node := GDVars.vaultCur;
          for loopI := 1 to GDVars.vaultCur^.count do begin
            GetMem(node^.bundleNext, SizeOf(node^.bundleNext^));
            node := node^.bundleNext;
            BlockRead(f, node^, SizeOf(Types.TItemRec), readResult);
            node^.next := nil;
          end;
        end;
      end;
    until readResult <> SizeOf(Types.TItemRec);
    Close(f);
    FreeMem(itemBuf, SizeOf(itemBuf^));
  end else
    GameIo.FillWord(GDVars.treasureMoney, SizeOf(GDVars.treasureMoney));

  GDVars.treasureMoneyFlag := False;
  exitFlag := False;
  repeat
    menuStr := 'View';
    Money.DetermineTreasure(flagA, flagB);
    if flagA or flagB then menuStr := menuStr + ' Take';
    menuStr := menuStr + ' Pool Exit';
    choice := MenuCore.MenuHorizontal('', menuStr, LightMagenta, LightGreen, White, 1, 0, menuFlag);
    if not menuFlag then begin
      case choice of
        'P': Money.PoolMoney;
        'V': ViewChar.ViewCharMenu(menuFlag);
        'T': PostCbt.LootTakeMenu(flagA, flagB);
        'E': exitFlag := True;
      end;
    end else if (choice = C_Keys.DOWN) or (choice = C_Keys.UP) then begin
      CharHlp.DisplayParty(GDVars.curChar, False);
      ViewChar.SelectPrevNextChar(choice);
      CharHlp.DisplayParty(GDVars.curChar, True);
    end;
  until exitFlag;

  needed := 0;
  Inc(needed, SizeOf(GDVars.treasureMoney));
  if GDVars.treasureItems <> nil then begin
    GDVars.vaultCur := GDVars.treasureItems;
    while GDVars.vaultCur <> nil do begin
      Inc(needed, SizeOf(Types.TItemRec));
      GDVars.vaultCur := GDVars.vaultCur^.next;
    end;
  end;

  DaxIo.DeleteIfPresent(GDVars.saveDir + 'vault.dat');
  if needed > DiskFree(Ord(UpCase(GDVars.saveDir[1])) - 64) then begin
    TextRend.DisplayAndPause(Yellow, 0, 'Can''t save.  No room on this disk.');
    TextRend.DisplayAndPause(Yellow, 0, 'Please insert another disk.');
  end;

  Assign(f, GDVars.saveDir + 'vault.dat');
  Rewrite(f, 1);
  BlockWrite(f, GDVars.treasureMoney, SizeOf(GDVars.treasureMoney));
  GDVars.vaultCur := GDVars.treasureItems;
  while GDVars.vaultCur <> nil do begin
    BlockWrite(f, GDVars.vaultCur^, SizeOf(Types.TItemRec));
    itemBuf := GDVars.vaultCur;
    if GDVars.vaultCur^.itemType = Ord('I') then
      for loopI := 1 to GDVars.vaultCur^.count do begin
        itemBuf := itemBuf^.bundleNext;
        BlockWrite(f, itemBuf^, SizeOf(Types.TItemRec));
      end;
    GDVars.vaultCur := GDVars.vaultCur^.next;
  end;
  Close(f);

  node := GDVars.treasureItems;
  while node <> nil do begin
    if (node^.itemType = Ord('I')) and (node^.bundleNext <> nil) then begin
      GDVars.vaultCur := node;
      node := node^.bundleNext;
      for loopI := 1 to GDVars.vaultCur^.count do begin
        t := node;
        node := node^.bundleNext;
        FreeMem(t, SizeOf(t^));
      end;
      node := GDVars.vaultCur;
    end;
    t := node;
    node := node^.next;
    FreeMem(t, SizeOf(t^));
  end;
  GDVars.treasureItems := nil;
end;

begin
end.

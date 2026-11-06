{ Secret of the Silver Blades: the main program. }
{$M 16384,0,655360}
{$F+,O+}
program FixMain;

uses
  Overlay, Dos, Crt, ModeInit, Ub74, SoundDrv,
  Joystick, Mouse, GameIo, DaxIo, TextRend, Blit,
  GameBoot, Sym8x8, Border, EclTrace, MapTiles, CbtMap,
  Pathing, EmptyC,
  View3D, Portrait, MapView, MenuCore,
  ClassCal, CharHlp, FxEngine, Money, Magic, GameTime,
  ViewChar, SaveLoad, CharGen, Camp, MapCurs, Explore,
  CbtActs, EffHndlr, GameInit, CombatSt, CombatAi, Combat,
  EclMenu, Shop, PostCbt, Temple, CopyProt, Vault,
  EclVm, SndLoad, Intro, HeapErr, Types,
  GDConsts, GDVars;

{$O HeapErr}
{$O Intro}
{$O SndLoad}
{$O EclVm}
{$O Vault}
{$O CopyProt}
{$O Temple}
{$O PostCbt}
{$O Shop}
{$O EclMenu}
{$O Combat}
{$O CombatAi}
{$O CombatSt}
{$O GameInit}
{$O EffHndlr}
{$O CbtActs}
{$O Explore}
{$O MapCurs}
{$O Camp}
{$O CharGen}
{$O SaveLoad}
{$O ViewChar}
{$O GameTime}
{$O Magic}
{$O Money}
{$O FxEngine}
{$O CharHlp}
{$O ClassCal}
{$O MenuCore}
{$O MapView}
{$O Portrait}
{$O View3D}
{$O Pathing}
{$O CbtMap}
{$O MapTiles}
{$O EclTrace}
{$O Sym8x8}

begin
  GameInit.InitializeGame;
  SoundDrv.StartSound;

  if ParamStr(1) <> 'Hoop' then
    Intro.Introduction
  else
    GDVars.heapFailureSaveEnabled := 1;

  GDVars.diskNum := 2;
  GDVars.autoDelay := 3000;
  GDVars.defaultKey := Ord('D');
  TextRend.DisplayString(0, 22, 0, LightGreen, '      Secret of the Silver Blades      ');
  TextRend.DisplayString(0, 23, 0, LightGreen, '   Version 1.30           May 18,1990  ');
  GDVars.menuResult := MenuCore.MenuHorizontal('              ', 'Play Demo', LightMagenta, LightGreen, White, 0, 0,
                                               GDVars.menuOut);
  GDVars.autoDelay := 0;
  GDVars.defaultKey := 0;
  if GDVars.menuResult = 'D' then
    GDVars.demoMode := True;

  repeat
    if GDVars.demoMode then begin
      GDVars.diskNum := 2;
      GDVars.gameDelay := 9;
    end else
      GDVars.diskNum := 1;

    if GDVars.soundActive <> 0 then
      SoundDrv.SoundCommand(GDConsts.sfxReset);
    if GDVars.soundActive = 0 then
      SoundDrv.StartSound;

    if not GDVars.demoMode then begin
      CharGen.MainMenu;
      if ParamStr(2) <> GDVars.stingKey then begin
        if CopyProt.CopyProtection <> True then
          GameIo.ExitGame;

        for GDVars.checkIdx := 1 to 4 do begin
          if GDVars.protectFlags[GDVars.checkIdx] = 0 then
            GameIo.ExitGame;
        end;
      end;

      if (GDVars.interfaceState = 3) and (GDVars.zone0^.areaView = 0) then
        Border.ScreenText
      else
        Border.DrawExploreFrame;
      CharHlp.DisplayRoster(GDVars.curChar);
    end;

    if GDVars.soundActive <> 0 then
      SoundDrv.SoundCommand(GDConsts.sfxReset);
    if GDVars.soundActive = 0 then
      SoundDrv.StartSound;

    View3D.SetView3DColors(GDVars.viewColSky, GDVars.viewColHorz1, GDVars.viewColHorz2, GDVars.viewColFloor);

    if GDVars.soundActive <> 0 then
      SoundDrv.SoundCommand(GDConsts.sfxReset);
    if GDVars.soundActive = 0 then
      SoundDrv.StartSound;

    EclVm.GameLoop;

    if GDVars.soundActive <> 0 then
      SoundDrv.SoundCommand(GDConsts.sfxReset);
    if GDVars.soundActive = 0 then
      SoundDrv.StartSound;

    GameInit.ResetGameState;

    if GDVars.demoMode then begin
      SoundDrv.SoundCommand(GDConsts.sfxReset);
      Intro.Introduction;
      SoundDrv.StartSound;
      GameIo.FlushKeys;
      GDVars.autoDelay := 1000;
      GDVars.defaultKey := Ord('D');
      GDVars.menuResult := MenuCore.MenuHorizontal('Secret of the Silver Blades ', 'Play Demo', LightMagenta,
                                                   LightGreen, White, 0, 0, GDVars.menuOut);
      GDVars.autoDelay := 0;
      GDVars.defaultKey := 0;
      GDVars.demoMode := GDVars.menuResult = 'D';
      SoundDrv.SoundCommand(GDConsts.sfxOff);
    end;
  until False;
end.

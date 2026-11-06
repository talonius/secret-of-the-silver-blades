{ 3-D view refresh: DisplayMapView redraws the 3-D viewport or large portrait from the current view state. Its nested
  classify function selects a horizon color. }
{$O+,F+}
unit MapView;

interface

{ Redraws the map view. Nothing is drawn while partyDefeated is set. When view3dFlag or areaView is set, the sky color
  comes from the zone's sky selector (eventSkyIndex when the event at the party's cell is above $7F, else skyIndex); on
  CGA the band and floor colors are recomputed from the ECL selectors after an ECL write to them, and otherwise the
  floor is dark gray; an area that hides the map or the position turns the automap off, and View3D draws the view.
  Otherwise the current picture is redisplayed if a redraw was requested; while picture 9 is loaded the request is
  dropped. }
procedure DisplayMapView;

implementation

uses View3D, Portrait, GDConsts, GDVars;

{ skyColors, read with the zone's sky index, which can run past the table's 16 entries. }
var
  eventTileMap: array[0..4095] of Byte absolute GDConsts.skyColors;

procedure DisplayMapView;
var
  { Unused in this version; see the other implementations of this routine. }
  wildX: Integer;
  { Unused in this version; see the other implementations of this routine. }
  wildY: Integer;

  { CGA color 1 for a ceiling and floor selection. }
  function HorizonUpperColorOf(k: Byte): Byte;
  begin
    case k of
      $08: HorizonUpperColorOf := 0;
      $41: HorizonUpperColorOf := 0;
      $E8: HorizonUpperColorOf := 15;
    else
      HorizonUpperColorOf := 15;
    end;
  end;

begin
  if GDVars.picArcId = 9 then
    GDVars.viewDirty := 0;
  if GDVars.partyDefeated = 0 then begin
    if (GDVars.zone0^.view3dFlag <> 0) or (GDVars.zone0^.areaView <> 0) then begin
      GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
      if GDVars.partyPos.eventAtCell > $7F then
        GDVars.viewColSky := eventTileMap[GDVars.zone0^.eventSkyIndex]
      else
        GDVars.viewColSky := eventTileMap[GDVars.zone0^.skyIndex];
      if GDVars.displayMode = Types.Cga then begin
        if GDVars.picRegionW then begin
          GDVars.viewColHorz1 := HorizonUpperColorOf(GDVars.ceilFloorColorSel);
          GDVars.viewColHorz2 := 3;
          GDVars.viewColFloor := 3;
          View3D.SetView3DColors(GDVars.viewColSky, GDVars.viewColHorz1, GDVars.viewColHorz2,
                                 GDVars.viewColFloor);
        end else
          GDVars.viewColFloor := 8;
      end;
      if GDVars.zone0^.noAutomap <> 0 then
        GDVars.automapOn := False;
      if GDVars.zone0^.statusX <> 255 then
        GDVars.automapOn := False;
      View3D.Display3DMapView(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
    end else begin
      if GDVars.viewDirty <> 0 then
        Portrait.DisplayBigPic;
    end;
    GDVars.viewDirty := 0;
  end;
end;

{ Empty routine with no callers. }
procedure NoopMapViewA;
begin
end;

{ Empty routine with no callers. }
procedure NoopMapViewB;
begin
end;

begin
end.

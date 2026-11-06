{ A near-empty overlay unit whose one live entry, Probe, has an empty body. The other four entries are reserved. }
{$O+,F+}
unit MapCurs;

interface

{ Empty routine with no callers. }
procedure NoopMapCursA;

{ Empty routine with no callers. }
procedure NoopMapCursB;

{ Empty: no party cursor is drawn. }
procedure DrawCursor;

{ Empty routine with no callers. }
procedure NoopMapCursC;

{ Empty routine with no callers. }
procedure NoopMapCursD;

implementation

procedure DrawCursor;
begin
end;

procedure NoopMapCursA;
begin
end;

procedure NoopMapCursB;
begin
end;

procedure NoopMapCursC;
begin
end;

procedure NoopMapCursD;
begin
end;

begin
end.

unit cmdloop; 

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, dbgTypes, commands; 

procedure RunLoop(Process: TDbgProcess);
  
implementation

var
  LastCommand : String;
  DbgEvent    : TDbgEvent;

  Running       : Boolean = false;
  callwaitnext  : Boolean = false;

const
  CmdPrefix = 'duby> ';

type
  { TRunComand }

  TRunComand = class(TCommand)
    procedure Execute(CmdParams: TStrings; Process: TDbgProcess); override;
  end;

  { TContinueCommand }

  TContinueCommand = class(TCommand)
    procedure Execute(CmdParams: TStrings; Process: TDbgProcess); override;
  end;

{ TContinueCommand }

procedure TContinueCommand.Execute(CmdParams: TStrings; Process: TDbgProcess);
begin
  if not Running then
    writeln('not running')
  else
    callwaitnext := true;
end;

{ TRunComand }

procedure TRunComand.Execute(CmdParams: TStrings; Process: TDbgProcess);
begin
  if not Running then begin
    running := true;
    writeln('starting process');
    callwaitnext := true;
  end else
    writelN('process already started');
end;

function GetNextWord(const s: AnsiString; var index: Integer): String;
const
  WhiteSpace = [' ',#8,#10];
  Literals   = ['"',''''];
var
  Wstart,wend : Integer;
  InLiteral   : Boolean;
  LastLiteral : AnsiChar;

begin
  WStart:=index;
  while (WStart<=Length(S)) and (S[WStart] in WhiteSpace) do
    Inc(WStart);

  WEnd:=WStart;
  InLiteral:=False;
  LastLiteral:=#0;
  while (Wend<=Length(S)) and (not (S[Wend] in WhiteSpace) or InLiteral) do begin
    if S[Wend] in Literals then
      If InLiteral then
        InLiteral:=not (S[Wend]=LastLiteral)
      else begin
        InLiteral:=True;
        LastLiteral:=S[Wend];
      end;
    inc(wend);
  end;

  Result:=Copy(S,WStart,WEnd-WStart);

  if (Length(Result) > 0)
     and (Result[1] = Result[Length(Result)]) // if 1st char = last char and..
     and (Result[1] in Literals) then // it's one of the literals, then
    Result:=Copy(Result, 2, Length(Result) - 2); //delete the 2 (but not others in it)

  while (WEnd<=Length(S)) and (S[Wend] in WhiteSpace) do
    inc(Wend);
  index := Wend;
end;

procedure ParseCommand(const Cmd: String; items: Tstrings);
var
  i : integer;
  w : String;
begin
  if not Assigned(items)then Exit;
  i:=1;
  while i <= length(Cmd) do begin
    w := GetNextWord(cmd, i);        
    items.Add(w);
  end;  
end;

  
procedure ExecuteNextCommand(AProcess: TDbgProcess);
var
  s : string;
  p : TStringList;
  cmd : TCommand;
begin
  write(CmdPrefix);
  readln(s);
  if s = '' then begin
    s := LastCommand;
    writeln(CmdPrefix,s);
  end;

  if s <> '' then begin
    p := TStringList.Create;
    ParseCommand(s, p);
    if not ExecuteCommand(p, AProcess, cmd) then 
      writeln('unknown command ', p[0])
    else begin
      LastCommand := s;
      if cmd.ResetParamsCache then 
        LastCommand := p[0];
    end;
    p.Free;
  end;
end;

procedure DoRunLoop(Process: TDbgProcess);
var
  ProcTerm  : Boolean;
begin
  if not Assigned(Process) then begin
    writeln('no process to debug (internal error?)');
    Exit;
  end;

  ProcTerm := false;
  while true do begin
    callwaitnext := false;
    ExecuteNextCommand(Process);

    if CallWaitNext and not ProcTerm then begin
      if not Process.WaitNextEvent(DbgEvent) then
        writeln('process terminated?')
      else begin
        writeln('event: ', DbgEvent.Debug);
      end;
      if DbgEvent.Kind = dek_ProcessTerminated then
        writeln('process has been terminated');
    end;
  end;
end;

procedure RunLoop(Process: TDbgProcess);
begin
  try
    DoRunLoop(Process);
  except
  end;
end;

procedure RegisterLoopCommands;
begin
  RegisterCommand(['run','r'], TRunComand.Create);
  RegisterCommand(['c'], TContinueCommand.Create);
end;

initialization
  RegisterLoopCommands;

end.

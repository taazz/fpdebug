unit nixDbgTypes;

{ Linux base debugging type }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, BaseUnix, Unix,
  nixPtrace, linuxDbgProc,
  dbgTypes, dbgCPU, dbgUtils;

type
  TCpuType = (cpi386, cpx64);


  TExcAddrProc = function (pid: TPid; var addr: TDbgPtr): Boolean;

  { TLinuxProcess }

  TLinuxProcess = class(TDbgTarget)
  private
    fChild      : TPid;
    fContSig    : Integer;
    fTerminated : Boolean;
    fWaited     : Boolean;
    fcputype    : TCpuType;

    EmulateThread : Boolean; // the next WaitEvent is CreateThread!
    Started       : Boolean; // has start thread been reported?

  protected
    function GetNextEmulatedEvent(var Event: TDbgEvent): Boolean;

  public
    constructor Create;
    function WaitNextEvent(var Event: TDbgEvent): Boolean; override;
    procedure Terminate; override;

    function GetThreadsCount(procID: TDbgProcessID): Integer; override;
    function GetThreadID(procID: TDbgProcessID; AIndex: Integer): TDbgThreadID; override;
    function GetThreadRegs(procID: TDbgProcessID; ThreadID: TDbgThreadID; Registers: TDbgDataList): Boolean; override;
    function SetThreadRegs(procID: TDbgProcessID; ThreadID: TDbgThreadID; Registers: TDbgDataList): Boolean; override;

    function SetSingleStep(procID: TDbgProcessID; ThreadID: TDbgThreadID): Boolean; override;

    function MainThreadID(procID: TDbgProcessID): TDbgThreadID; override;

    function ReadMem(procID: TDbgProcessID; Offset: TDbgPtr; Count: Integer; var Data: array of byte): Integer; override;
    function WriteMem(procID: TDbgProcessID; Offset: TDbgPtr; Count: Integer; const Data: array of byte): Integer; override;

    // Linux specific methods
    function StartProcess(const ACmdLine: String): Boolean;
  end;

function DebugLinuxProcessStart(const ACmdLine: String): TDbgTarget;

implementation

const
  HexSize = sizeof(TDbgPtr)*2;

function DebugLinuxProcessStart(const ACmdLine: String): TDbgTarget;
var
  dbg : TLinuxProcess;
begin
  dbg := TLinuxProcess.Create;
  if not dbg.StartProcess(ACmdLine) then begin
    dbg.Free;
    Result := nil;
  end else
    Result := dbg;
end;

{ TLinuxProcess }

function TLinuxProcess.GetThreadsCount(procID: TDbgProcessID): Integer;
begin
  Result := 0;
end;

function TLinuxProcess.GetThreadID(procID: TDbgProcessID; AIndex: Integer): TDbgThreadID;
begin
  Result := 0;
end;

function TLinuxProcess.GetThreadRegs(procID: TDbgProcessID; ThreadID: TDbgThreadID; Registers: TDbgDataList): Boolean;
begin
  case fcputype of
    cpi386:
      Result := ReadRegsi386(ThreadId, Registers);
    cpx64: begin
      writeln('reading x86_64 registers... ', ThreadID);
      Result := ReadRegsx64(ThreadId, Registers);
    end;
  else
    Result := false;
  end;
end;

function TLinuxProcess.SetThreadRegs(procID: TDbgProcessID; ThreadID: TDbgThreadID; Registers: TDbgDataList): Boolean;
begin
  case fcputype of
    cpi386:
      Result := WriteRegsi386(ThreadId, Registers);
    cpx64:
      Result := WriteRegsx64(ThreadId, Registers);
  else
    Result := false;
  end;
end;

function TLinuxProcess.ReadMem(procID: TDbgProcessID; Offset: TDbgPtr; Count: Integer; var Data: array of byte): Integer;
begin
  Result := ReadProcMem(fChild, Offset, Count, Data);
end;

function TLinuxProcess.WriteMem(procID: TDbgProcessID; Offset: TDbgPtr; Count: Integer; const Data: array of byte): Integer;
begin
  Result := WriteProcMem(fChild, Offset, Count, Data);
end;

function TLinuxProcess.SetSingleStep(procID: TDbgProcessID; ThreadID: TDbgThreadID): Boolean;
begin
  Result := ptraceSingleStep(ThreadID);
end;

function TLinuxProcess.MainThreadID(procID: TDbgProcessID): TDbgThreadID;
begin
  Result := fChild;
end;

function TLinuxProcess.GetNextEmulatedEvent(var Event: TDbgEvent): Boolean;
begin
  //todo: some events must not be emulated but catched via ptracing syscall()
  Result:=False;
  if not Started then begin
    Event.Kind:=dek_ProcessStart;
    Event.Process:=fChild;
    Event.Thread:=0;
    Event.Addr:=0;
    EmulateThread:=True;
    Started:=True;
    Result:=True;
  end else if EmulateThread then begin
    Event.Kind:=dek_ThreadStart;
    Event.Process:=fChild;
    Event.Thread:=fChild;
    Event.Addr:=0;
    EmulateThread:=False;
    Result:=True;
  end;
end;

constructor TLinuxProcess.Create;
begin
  {$ifdef cpui386}
  fcputype:=cpi386;
  {$endif}
  {$ifdef CPUx86_64}
  fcputype:=cpx64;
  {$endif}
end;

function TLinuxProcess.StartProcess(const ACmdLine: String): Boolean;
begin
  Result := ForkAndDebugProcess(ACmdLine, fChild);
  if not Result then Exit;
end;

procedure TLinuxProcess.Terminate;
begin
  // Terminate
  FpKill(fChild, SIGKILL);
end;

function TLinuxProcess.WaitNextEvent(var Event: TDbgEvent): Boolean;
var
  Status : Integer;
  fCh    : TPid;
begin
  if fChild = 0 then begin
    Result := false;
    Exit;
  end;

  if GetNextEmulatedEvent(Event) then Exit;

  if fWaited then ptraceCont(fChild, fContSig);

  if fTerminated then begin
    Result := false;
    Exit;
  end;

  fCh := FpWaitPid(fChild, Status, 0);

  if fCh < 0 then begin // failed to wait
    Result := false;
    fChild := 0;
    fTerminated := true;
    Exit;
  end else if Status = 0 then begin
    //terminated?
  end;

  if isStopped(Status, fContSig) then begin
    case fContSig of
      SIGTRAP: fContSig := 0;
    end;
  end;

  Result := WaitStatusToDbgEvent(fChild, fCh, Status, Event);

  fWaited := Result;
  fTerminated := Event.Kind = dek_ProcessTerminated;
end;

initialization
  DebugProcessStart := @DebugLinuxProcessStart;

end.


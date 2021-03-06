{
    fpDebug  -  A debugger for the Free Pascal Compiler.

    Copyright (c) 2012 by Graeme Geldenhuys.

    See the file LICENSE.txt, included in this distribution,
    for details about redistributing fpDebug.

    Description:
      .
}
unit PESource;

{
 This unit contains the types needed for reading PE images.
 At some time this may go to be part of the rtl ?

 ---------------------------------------------------------------------------

 @created(Thu May 4th WET 2006)
 @lastmod($Date: 2009-01-16 03:26:10 +0300 (Пт, 16 янв 2009) $)
 @author(Marc Weustink <marc@@dommelstein.nl>)

 @modified by dmitry boyarintsev (july 2009: 
   + removed Windows unit dependancy. added SectionCount and 
   + added Sections access by Index
}
{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, dbgInfoTypes, dbgPETypes; 
  
type
  TDbgImageSection = record
    RawData : Pointer;
    Size    : QWord;
    VirtualAdress: QWord;
  end;
  PDbgImageSection = ^TDbgImageSection;

  { TDbgImageLoader }

  TDbgImageLoader = class(TObject)
  private
    FImage64Bit: Boolean;
    FImageBase: QWord;
    FSections: TStringList;
    function GetSection(const AName: String): PDbgImageSection;
  protected
    procedure Add(const AName: String; ARawData: Pointer; ASize: QWord; AVirtualAdress: QWord);
    procedure SetImageBase(ABase: QWord);
    procedure SetImage64Bit(AValue: Boolean);
    procedure LoadSections; virtual; abstract;
    procedure UnloadSections; virtual; abstract;
    function GetSectionsCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function GetSectionByIndex(i: Integer):  PDbgImageSection;
    property ImageBase: QWord read FImageBase;
    Property Image64Bit: Boolean read FImage64Bit;
    property Section[const AName: String]: PDbgImageSection read GetSection;
    property SectionsCount: Integer read GetSectionsCount;
  end;
  
  { TDbgPEImageLoader }

  TDbgPEImageLoader = class(TDbgImageLoader)
  private
  protected
    function  LoadData(out AModuleBase: Pointer; out AHeaders: PImageNtHeaders): Boolean; virtual; abstract;
    procedure LoadSections; override;
    procedure UnloadData; virtual; abstract;
    procedure UnloadSections; override;
  public
  end;
  
  { TDbgWinPEImageLoader }

  TDbgWinPEImageLoader = class(TDbgPEImageLoader)
  private
    FStream   : TStream;
    OwnStream : Boolean;
    data      : array of byte;
    FModulePtr: Pointer;
    procedure DoCleanup;
  protected
    function  LoadData(out AModuleBase: Pointer; out AHeaders: PImageNtHeaders): Boolean; override;
    procedure UnloadData; override;
  public
    constructor Create(ASource: TStream; AOwnStream: Boolean);
  end;

  
  { TPEFileSource }

  TPEFileSource = class(TDbgDataSource)
  private
    fLoader     : TDbgWinPEImageLoader;
    fStream     : TStream;
    fOwnStream  : Boolean;
    fLoaded     : Boolean;
  public
    class function isValid(ASource: TStream): Boolean; override;
    class function UserName: AnsiString; override;
  public
    constructor Create(ASource: TStream; OwnSource: Boolean); override;
    destructor Destroy; override;

    function GetSectionInfo(const SectionName: AnsiString; var Size: int64): Boolean; override;
    function GetSectionData(const SectionName: AnsiString; Offset, Size: Int64; var Buf: array of byte): Int64; override;
  end;

implementation

function isValidPEStream(ASource: TStream): Boolean;
var
  DosHeader: TImageDosHeader;
begin
  try
    Result := false;
    if ASource.Read(DosHeader, sizeof(DosHeader)) <> sizeof(DosHeader) then 
      Exit;
    if (DosHeader.e_magic <> IMAGE_DOS_SIGNATURE) or (DosHeader.e_lfanew = 0) then 
      Exit;
    Result := true;
  except
    Result := false;
  end;
end;

constructor TPEFileSource.Create(ASource: TStream; OwnSource: Boolean);  
begin
  fLoader := TDbgWinPEImageLoader.Create(ASource, False);
  fLoaded:=True;
  fStream:=ASource;
  fOwnStream:=OwnSource;
  inherited Create(ASource, OwnSource);  
end;

destructor TPEFileSource.Destroy;  
begin
  fLoader.Free;
  if fOwnStream then fStream.Free;
  inherited Destroy;  
end;

function TPEFileSource.GetSectionInfo(const SectionName: AnsiString; var Size: int64): Boolean;  
var
  section : PDbgImageSection;
begin
  section := fLoader.Section[SectionName];
  Result := Assigned(section);
  if not Result then Exit;
  Size := section^.Size;
end;

function TPEFileSource.GetSectionData(const SectionName: AnsiString; Offset,  
  Size: Int64; var Buf: array of byte): Int64;
var
  section : PDbgImageSection;
  data    : PByteArray;
  sz      : Integer;
begin
  Result := 0;
  
  section := fLoader.Section[SectionName];
  if not Assigned(section) then Exit;

  sz := section^.Size - Offset;
  if sz < 0 then Exit;
  if sz > Size then sz := Size;
  
  data := PByteArray(section^.RawData);
  Move(data^[Offset], Buf[0], sz);
  Result := sz;
end;

class function TPEFileSource.isValid(ASource: TStream): Boolean;  
begin
  Result := isValidPEStream(ASource);
end;

class function TPEFileSource.UserName: AnsiString;
begin
  Result:='PE file';
end;

{ TDbgImageLoader }

procedure TDbgImageLoader.Add(const AName: String; ARawData: Pointer; ASize: QWord; AVirtualAdress: QWord);
var
  p: PDbgImageSection;
  idx: integer;
begin
  idx := FSections.AddObject(AName, nil);
  New(p);
  P^.RawData := ARawData;
  p^.Size := ASize;
  p^.VirtualAdress := AVirtualAdress;
  FSections.Objects[idx] := TObject(p);
end;

constructor TDbgImageLoader.Create;
begin
  inherited Create;
  FSections := TStringList.Create;
  FSections.Sorted := True;
  //FSections.Duplicates := dupError;
  FSections.CaseSensitive := False;
  LoadSections;
end;

destructor TDbgImageLoader.Destroy;
var
  n: integer;
begin
  UnloadSections;
  for n := 0 to FSections.Count - 1 do begin
    Dispose(PDbgImageSection(FSections.Objects[n]));
  end;
  FSections.Clear;
  FreeAndNil(FSections);
  inherited Destroy;
end;

function TDbgImageLoader.GetSectionByIndex(i: Integer): PDbgImageSection; 
begin
  Result := PDbgImageSection(FSections.Objects[i]);
end;

function TDbgImageLoader.GetSection(const AName: String): PDbgImageSection;
var
  idx: integer;
begin
  idx := FSections.IndexOf(AName);
  if idx = -1
  then Result := nil
  else Result := PDbgImageSection(FSections.Objects[idx]);
end;

procedure TDbgImageLoader.SetImage64Bit(AValue: Boolean);
begin
  FImage64Bit := AValue;
end;

function TDbgImageLoader.GetSectionsCount: Integer; 
begin
  Result := FSections.Count;
end;

procedure TDbgImageLoader.SetImageBase(ABase: QWord);
begin
  FImageBase := ABase;
end;

{ TDbgPEImageLoader }

procedure TDbgPEImageLoader.LoadSections;
var
  ModulePtr: Pointer;
  NtHeaders: PImageNtHeaders;
  NtHeaders32: PImageNtHeaders32 absolute NtHeaders;
  NtHeaders64: PImageNtHeaders64 absolute NtHeaders;
  SectionHeader: PImageSectionHeader;
  n: Integer;
  p: Pointer;
  SectionName: array[0..IMAGE_SIZEOF_SHORT_NAME] of Char;
begin
  if not LoadData(ModulePtr, NtHeaders) then Exit;
  
  if NtHeaders^.Signature <> IMAGE_NT_SIGNATURE
  then begin
    //WriteLn('Invalid NT header: ', IntToHex(NtHeaders^.Signature, 8));
    Exit;
  end;

  SetImage64Bit(NtHeaders^.OptionalHeader.Magic = IMAGE_NT_OPTIONAL_HDR64_MAGIC);

  if Image64Bit
  then SetImageBase(NtHeaders64^.OptionalHeader.ImageBase)
  else SetImageBase(NtHeaders32^.OptionalHeader.ImageBase);

  for n := 0 to NtHeaders^.FileHeader.NumberOfSections - 1 do
  begin
    SectionHeader := Pointer(@NtHeaders^.OptionalHeader) + NtHeaders^.FileHeader.SizeOfOptionalHeader + SizeOf(TImageSectionHeader) * n;
    // make a null terminated name
    Move(SectionHeader^.Name, SectionName, IMAGE_SIZEOF_SHORT_NAME);
    SectionName[IMAGE_SIZEOF_SHORT_NAME] := #0;
    if (SectionName[0] = '/') and (SectionName[1] in ['0'..'9'])
    then begin
      // long name
      p := ModulePtr + NTHeaders^.FileHeader.PointerToSymbolTable + NTHeaders^.FileHeader.NumberOfSymbols * IMAGE_SIZEOF_SYMBOL + StrToIntDef(PChar(@SectionName[1]), 0);
      Add(PChar(p), ModulePtr + SectionHeader^.PointerToRawData, SectionHeader^.Misc.VirtualSize,  SectionHeader^.VirtualAddress);
    end
    else begin
      // short name
      Add(SectionName, ModulePtr + SectionHeader^.PointerToRawData, SectionHeader^.Misc.VirtualSize,  SectionHeader^.VirtualAddress);
    end
  end;
end;

procedure TDbgPEImageLoader.UnloadSections;
begin
  UnloadData;
end;

{ TDbgWinPEImageLoader }

constructor TDbgWinPEImageLoader.Create(ASource: TStream; AOwnStream: Boolean);
begin
  fStream := ASource;
  OwnStream := AOwnStream;
  inherited Create;
end;

procedure TDbgWinPEImageLoader.DoCleanup;
begin
  if OwnStream then FStream.Free;
  FStream:=nil;  
  SetLength(data, 0);
end;

function TDbgWinPEImageLoader.LoadData(out AModuleBase: Pointer; out AHeaders: PImageNtHeaders): Boolean;
var
  DosHeader: PImageDosHeader;
begin
  Result := False;

  try
    SetLength(data, FStream.Size);
    FStream.Read(data[0], length(data));

    //FModulePtr := MapViewOfFile(FMapHandle, FILE_MAP_READ, 0, 0, 0);
    FModulePtr := @data[0];
    if FModulePtr = nil
    then begin
      //WriteLn('Could not map view');
      Exit;
    end;

    DosHeader := FModulePtr;
    if (DosHeader^.e_magic <> IMAGE_DOS_SIGNATURE)
    or (DosHeader^.e_lfanew = 0)
    then begin
      //WriteLn('Invalid DOS header');
      Exit;
    end;
    
    AModuleBase := FModulePtr;
    AHeaders := FModulePtr + DosHeader^.e_lfanew;
    Result := True;
  finally
    if not Result
    then begin
      // something failed, do some cleanup
      DoCleanup;
    end;
  end;
end;

procedure TDbgWinPEImageLoader.UnloadData;
begin
  DoCleanup;
end;

initialization
  RegisterDataSource(TPEFileSource);

end.


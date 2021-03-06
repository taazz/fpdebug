{
       THIS UNIT IS CURRENTLY NOT USED ANYWHERE
}
unit debugStabs;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, debugTypes, debugloader;

const
  //Non-Stab Symbol Types
  //The following types are used by the linker and assembler, not by stab directives.
  //Since this document does not attempt to describe aspects of object file format
  //other than the debugging format, no details are given.

  N_UNDF     = $00;  // Undefined symbol
  N_EXT      = $01;  // External modifier

  N_ABS      = $02;  // File scope absolute symbol
  N_ABS_EXT  = N_ABS or N_EXT;  // External absolute symbol

  N_TEXT     = $04;  // File scope text symbol
  N_TEXT_EXT = N_TEXT or N_EXT; // External text symbol

  N_DATA     = $06; // File scope data symbol
  N_DATA_EXT = $07; // External data symbol

  N_BSS      = $08; // File scope BSS symbol
  N_BSS_EXT  = N_BSS or N_EXT; // External BSS symbol

  N_FN_SEQ   = $0c; // Same as N_FN, for Sequent compilers
  N_INDR     = $0a; // Symbol is indirected to another symbol
  N_COMM     = $12; // Common--visible after shared library dynamic link

  N_SETA     = $14; //Absolute set element
  N_SETA_EXT = N_SETA or N_EXT;

  N_SETT     = $16; // Text segment set element
  N_SETT_EXT = N_SETT or N_EXT;

  N_SETD     = $18;  // Data segment set element
  N_SETD_EXT = N_SETD or N_EXT;

  N_SETB     = $1a; // BSS segment set element
  N_SETB_EXT = N_SETB or N_EXT;

  N_SETV     = $1c; // Pointer to set vector
  N_SETV_EXT = N_SETV or N_EXT;

  N_WARNING  = $1e; // Print a warning message during linking
  N_FN       = $1f; // File name of a `.o' file

const
  //Stab Symbol Types
  //The following symbol types indicate that this is a stab. This is the full
  //list of stab numbers, including stab types that are used in languages
  //other than C.

  N_GSYM   = $20; // Global symbol; see section Global Variables.
  N_FNAME  = $22; // Function name (for BSD Fortran); see section Procedures.
  N_FUN    = $24; // Function name (see section Procedures) or text segment variable (see section Static Variables).
  N_STSYM  = $26; // Data segment file-scope variable; see section Static Variables.
  N_LCSYM  = $28; // BSS segment file-scope variable; see section Static Variables.
  N_MAIN   = $2a; // Name of main routine; see section Main Program.
  N_ROSYM  = $2c; // Variable in .rodata section; see section Static Variables.
  N_PC     = $30; // Global symbol (for Pascal); see section N_PC.
  N_NSYMS  = $32; // Number of symbols (according to Ultrix V4.0); see section N_NSYMS.
  N_NOMAP  = $34; // No DST map; see section N_NOMAP.
  N_OBJ    = $38; // Object file (Solaris2).
  N_OPT    = $3c; // Debugger options (Solaris2).
  N_RSYM   = $40; // Register variable; see section Register Variables.
  N_M2C    = $42; // Modula-2 compilation unit; see section N_M2C.
  N_SLINE  = $44; // Line number in text segment; see section Line Numbers.
  N_DSLINE = $46; // Line number in data segment; see section Line Numbers.
  N_BSLINE = $48; // Line number in bss segment; see section Line Numbers.
  N_BROWS  = $48; // Sun source code browser, path to `.cb' file; see section N_BROWS.
  N_DEFD   = $4a; // GNU Modula2 definition module dependency; see section N_DEFD.
  N_FLINE  = $4c; // Function start/body/end line numbers (Solaris2).
  N_EHDECL = $50; // GNU C++ exception variable; see section N_EHDECL.
  N_MOD2   = $50; // Modula2 info "for imc" (according to Ultrix V4.0); see section N_MOD2.
  N_CATCH  = $54; // GNU C++ catch clause; see section N_CATCH.
  N_SSYM   = $60; // Structure of union element; see section N_SSYM.
  N_ENDM   = $62; // Last stab for module (Solaris2).
  N_SO     = $64; // Path and name of source file; see section Paths and Names of the Source Files.
  N_LSYM   = $80; // Stack variable (see section Automatic Variables Allocated on the Stack) or type (see section Giving a Type a Name).
  N_BINCL  = $82; // Beginning of an include file (Sun only); see section Names of Include Files.
  N_SOL    = $84; // Name of include file; see section Names of Include Files.
  N_PSYM   = $a0; // Parameter variable; see section Parameters.
  N_EINCL  = $a2; // End of an include file; see section Names of Include Files.
  N_ENTRY  = $a4; // Alternate entry point; see section Alternate Entry Points.
  N_LBRAC  = $c0; // Beginning of a lexical block; see section Block Structure.
  N_EXCL   = $c2; // Place holder for a deleted include file; see section Names of Include Files.
  N_SCOPE  = $c4; // Modula2 scope information (Sun linker); see section N_SCOPE.
  N_RBRAC  = $e0; // End of a lexical block; see section Block Structure.
  N_BCOMM  = $e2; // Begin named common block; see section Common Blocks.
  N_ECOMM  = $e4; // End named common block; see section Common Blocks.
  N_ECOML  = $e8; // Member of a common block; see section Common Blocks.
  N_WITH   = $ea; // Pascal with statement: type,,0,0,offset (Solaris2).
  N_NBTEXT = $f0; // Gould non-base registers; see section Non-base registers on Gould systems.
  N_NBDATA = $f2; // Gould non-base registers; see section Non-base registers on Gould systems.
  N_NBBSS  = $f4; // Gould non-base registers; see section Non-base registers on Gould systems.
  N_NBSTS  = $f6; // Gould non-base registers; see section Non-base registers on Gould systems.
  N_NBLCS  = $f8; // Gould non-base registers; see section Non-base registers on Gould systems.

type
  Tbfd_vma = Integer;

  TInternalNList = packed record
    n_strx  : LongWord;         { index into string table of name }
    n_type  : Byte;             { type of symbol }
    n_other : Byte;             { misc info (usually empty) }
    n_desc  : Word;             { description field }
    n_Value : Tbfd_vma;         { value of symbol }
  end;
  PInternalNList = ^TInternalNList;

  TInternalNListArray = array [Word] of TInternalNList;
  PInternalNListArray = ^TInternalNListArray;

  { TStabsSymbol }

  TStabsSymbol = class(TDbgSymbol)
  private
    fParent   : TStabsSymbol;

  protected
    function GetChild(AIndex: Integer): TDbgSymbol; override;
    function GetColumn: Cardinal; override;
    function GetCount: Integer; override;
    function GetFile: String; override;
    function GetFlags: TDbgSymbolFlags; override;
    function GetLine: Cardinal; override;
    function GetParent: TDbgSymbol; override;
    function GetReference: TDbgSymbol; override;
    function GetSize: Integer; override;

  public
    fSubItems : TList;
    RawStab   : TInternalNList;
    RawString : string;
    StabName  : string;
    constructor Create(const AName: String; AKind: TDbgSymbolKind; AAddress: TDbgPtr);    
    destructor Destroy; override;
  end;

  { TStabsInfo }

  TStabsInfo = class(TDbgInfo)
  private
    StabStr : AnsiString;
  protected
    procedure LoadStabs(ALoader: TDbgImageLoader);
  public
    fItems  : TList;
    constructor Create(ALoader: TDbgImageLoader); override;
    destructor Destroy; override;
  end;

implementation

function GetNextSubStr(const s: AnsiString; index: Integer; StopChar: AnsiChar): AnsiString;
var
  i : Integer;
begin
  for i := index to length(s) do
    if s[i] = StopChar then begin
      Result := Copy(s, index, i - index);
      Exit;
    end;
  Result := Copy(s, index, length(s)-index -1);
end;


procedure ParseStabFuncStr(const s: AnsiString; var name, descr, subname, parent: AnsiString);
var
  i : Integer;
begin
  i := 1;
  name := GetNextSubStr(s, 1, ':');
  inc(i, length(name)+1);
  descr := GetNextSubStr(s, i, ',');
  inc(i, length(descr)+1);
  subname := GetNextSubStr(s, i, ',');
  inc(i, length(subname)+1);
  parent := GetNextSubStr(s, i, #0);
end;

function StabsTypeToKind(_type: Byte): TDbgSymbolKind;
begin
  case _type of
    N_FUN: Result := skFunction
  else
    Result := skNone;
  end;
end;

function StabsTypeToStr(_type: Byte): string;
begin
  case _type of
    N_GSYM: Result := 'GSYM';
    N_FNAME: Result := 'FNAME';
    N_FUN: Result := 'FUN';
    N_STSYM: Result := 'STSYM';
    N_LCSYM: Result := 'LCSYM';
    N_MAIN: Result := 'MAIN';
    N_ROSYM: Result := 'ROSYM';
    N_PC: Result := 'PC';
    N_NSYMS: Result := 'NSYMS';
    N_NOMAP: Result := 'NOMAP';
    N_OBJ: Result := 'OBJ';
    N_OPT: Result := 'OPT';
    N_RSYM: Result := 'RSYM';
    N_M2C: Result := 'M2C';
    N_SLINE: Result := 'SLINE';
    N_DSLINE: Result := 'DSLINE';
    N_BSLINE: Result := 'BSLINE';
    //N_BROWS: Result := 'BROWS';
    N_DEFD: Result := 'DEFD';
    N_FLINE: Result := 'FLINE';
    N_EHDECL: Result := 'EHDECL';
    //N_MOD2: Result := 'MOD2';
    N_CATCH: Result := 'CATCH';
    N_SSYM: Result := 'SSYM';
    N_ENDM : Result := 'ENDM';
    N_SO: Result := 'SO';
    N_LSYM: Result := 'LSYM';
    N_BINCL: Result := 'BINCL';
    N_SOL: Result := 'SOL';
    N_PSYM: Result := 'PSYM';
    N_EINCL : Result := 'EINCL';
    N_ENTRY: Result := 'ENTRY';
    N_LBRAC: Result := 'LBRAC';
    N_EXCL: Result := 'EXCL';
    N_SCOPE: Result := 'SCOPE';
    N_RBRAC: Result := 'RBRAC';
    N_BCOMM: Result := 'BCOMM';
    N_ECOMM: Result := 'ECOMM';
    N_ECOML: Result := 'ECOML';
    N_WITH: Result := 'WITH';
    N_NBTEXT: Result := 'NBTEXT';
    N_NBDATA: Result := 'NBDATA';
    N_NBBSS: Result := 'NBBSS';
    N_NBSTS: Result := 'NBSTS';
    N_NBLCS: Result := 'NBLCS';
  else
    Result := INtToHex(_type, 2);
  end;
end;

function StrFromIndex(const s: AnsiString; index: integer): string;
var
  i : integer;
begin
  Result := '';
  if index <= length(s) then begin
    for i := index to length(s) do
      if s[i] = #0 then begin
        Result := Copy(s, index, i - index);
        Exit;
      end;
    Result := Copy(s, index, length(s) - index+1);
  end;
end;


{ TStabsInfo }

function SortByNValue(p1, p2: Pointer): Integer;
var
  i1, i2: TStabsSymbol;
  sum : Int64;
begin
  i1 := TStabsSymbol(p1);
  i2 := TStabsSymbol(p2);
  sum := i1.RawStab.n_Value - i2.RawStab.n_Value;
  if sum < 0 then Result := -1
  else if sum > 0 then Result := 1
  else Result := 0;
end;

procedure TStabsInfo.LoadStabs(ALoader: TDbgImageLoader);
var
  sc    : PDbgImageSection;
  i     : integer;
  pb    : PByteArray;
  list  : PInternalNListArray;
  cnt   : Integer;

  parent  : TStabsSymbol;
  symb    : TStabsSymbol;
  addr    : TDbgPtr;
begin
  sc := ALoader.Section['.stabstr'];
  if Assigned(sc) then begin
    SetLength(StabStr, sc^.Size);
    Move(sc^.RawData^, StabStr[1], sc^.Size);
  end;

  sc := ALoader.Section['.stab'];
  if not Assigned(sc) then Exit;
  SetHasInfo;

  list := sc^.RawData;
  cnt := sc^.Size div sizeof(TInternalNList);

  parent := nil;

  for i := 0 to cnt - 1 do begin
    if list^[i].n_type in [N_GSYM..N_NBLCS] then begin

      addr:=list^[i].n_Value;
      //todo: 
      case list^[i].n_type of
        N_LSYM, N_PSYM: addr :=0;                  
      end;
      
      symb := TStabsSymbol.Create(StabsTypeToStr(list^[i].n_type), 
        StabsTypeToKind(list^[i].n_type), addr);
        
      symb.RawStab := list^[i];
      symb.RawString := StrFromIndex(StabStr, symb.RawStab.n_strx+1);
      fItems.Add(symb);
      case list^[i].n_type of
        N_FUN: begin
          if parent <> nil then
            parent.fSubItems.Sort(@SortByNValue);
          parent := symb;
        end;
      else
        if Assigned(parent) then 
          parent.fSubItems.Add(symb);
      end;
    end;
  end;

end;

constructor TStabsInfo.Create(ALoader: TDbgImageLoader);
begin
  fItems := TList.Create;
  LoadStabs(ALoader);
end;

destructor TStabsInfo.Destroy;
var
  i : Integer;
begin
  for i := 0 to fItems.Count - 1 do
    TStabsSymbol(fItems[i]).Free;
  fItems.Free;
  inherited Destroy;
end;

{ TStabsSymbol }

function TStabsSymbol.GetParent: TDbgSymbol;
begin
  Result:=fParent;
end;

function TStabsSymbol.GetChild(AIndex: Integer): TDbgSymbol;
begin
  Result := TDbgSymbol(fSubItems[AIndex]);
end;

function TStabsSymbol.GetCount: Integer;
begin
  Result:=fSubItems.Count;
end;

function TStabsSymbol.GetColumn: Cardinal;
begin
  Result := 0;
end;

function TStabsSymbol.GetFile: String;
begin
  Result := '';
end;

function TStabsSymbol.GetLine: Cardinal;
begin
  Result:=0;
end;


function TStabsSymbol.GetFlags: TDbgSymbolFlags;
begin
  Result := [];
end;


function TStabsSymbol.GetReference: TDbgSymbol;
begin
  Result := nil;
end;

function TStabsSymbol.GetSize: Integer;
begin
  Result := 0;
end;

constructor TStabsSymbol.Create(const AName: String; AKind: TDbgSymbolKind; AAddress: TDbgPtr);
begin
  inherited Create(AName, AKind, AAddress);
  fSubItems := TList.Create;
end;


destructor TStabsSymbol.Destroy;
begin
  fSubItems.Free;
  inherited Destroy;
end;

end.


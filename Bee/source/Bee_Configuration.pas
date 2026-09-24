unit Bee_Configuration;

{ Contains:

  Bee configuration support.

  (C) 2003-2005 Andrew Filinsky, Melchiorre Caruso

  Modifyed:

  v0.7.8 build 0153 - 2005/07/08 by Andrew Filinsky
}

{$R-,Q-,S-}

interface

uses
  SysUtils,            // Trim
  Classes,             // TStringList
  Bee_Common;

const
  TableSize = 20;
  TableCols = 2;

type
  TTableCol = array [0..TableSize] of Cardinal;
  TTable = packed record
    Level: Cardinal;
    T: array [1..TableCols] of TTableCol;
  end;

  TTableParameters = array [1..SizeOf (TTable) div 4] of byte;

  TConfigSection = class (TStringList)
    function   GetTable (const Ext: string; var T: TTableParameters): boolean;
    procedure  PutData  (const Name: string; var Data; aCount: integer);
    function   GetData  (const Name: string; var Data; aCount: integer): boolean;
  end;

  TConfiguration = class (TStringList)
  public
    constructor Create;
    destructor  Destroy; override;

    procedure   LoadFromFile (const FileName: string); override;
    procedure   SaveToFile   (const FileName: string); override;
    function    GetTable     (const Ext: string; var T: TTableParameters): boolean;
    procedure   PutData      (const Name: string; var Data; aCount: integer);
    function    GetData      (const Name: string; var Data; aCount: integer): boolean;
    procedure   Selector     (const Name: string);
    function    Split        (const S: string; var Name, Value: string): boolean;

  public
    CurrentSection: TConfigSection;
  end;

implementation

(***************************************************************************)
(* Class:  TConfiguration | methods
(* Domain: public
(***************************************************************************)

constructor TConfiguration.Create;
begin
  inherited;
  Selector ('\main');
end;

destructor TConfiguration.Destroy; 
var 
  I: integer;
begin
  for I := 0 to Count - 1 do Objects [I].Free;
  inherited;
end;

procedure TConfiguration.LoadFromFile (const FileName: string); 
var
  T: TextFile;
  S, aName, aValue: string;
  B: array [1..4096] of byte;
begin
  AssignFile (T, FileName); SetTextBuf (T, B); Reset (T); Selector ('\main');

  while not System.Eof (T) do 
  begin
    Readln (T, S);
    if (S > '') and (S [1] = '\') then
      Selector (S)
    else if (S = '') or (S [1] = ';') or not Split (S, aName, aValue) then
      CurrentSection.Add (S)
    else
      CurrentSection.Values [aName] := aValue
  end;

  Close (T); Selector ('\main');
end;

procedure TConfiguration.SaveToFile (const FileName: string);
var
  T: TextFile;
  I: integer;
  B: array [1..4096] of byte;
begin
  AssignFile (T, FileName); SetTextBuf (T, B); Rewrite (T);

  for I := 0 to Count - 1 do begin
    Writeln (T, Names [I]);
    Write (T, TConfigSection (Objects [I]).Text);
  end;

  Close (T);
end;

function TConfiguration.GetTable (const Ext: string; var T: TTableParameters): boolean;
var
  OldSection: TConfigSection;
begin
  OldSection := CurrentSection;
  Selector ('\main');
  Selector ('\m' + CurrentSection.Values ['Method']);
  Result := CurrentSection.GetTable (Ext, T);
  CurrentSection := OldSection;
end;

procedure TConfiguration.PutData (const Name: string; var Data; aCount: integer);
begin
  CurrentSection.PutData (Name, Data, aCount);
end;

function TConfiguration.GetData (const Name: string; var Data; aCount: integer): boolean;
begin
  Result := CurrentSection.GetData (Name, Data, aCount);
end;

procedure TConfiguration.Selector (const Name: string);
var
  Index: integer;
begin
  Index := IndexOfName (Name);
  if Index < 0 then begin
    CurrentSection := TConfigSection.Create;
    Objects [Add (Name + '=yes')] := CurrentSection;
  end else
    CurrentSection := TConfigSection (Objects [Index]);
end;

function TConfiguration.Split (const S: string; var Name, Value: string): boolean;
var
  Index: integer;
begin
  Index  := Pos ('=', S);
  Result := Index > 0;
  if Result then begin
    Name  := Trim (Copy (S, 1, Index - 1));
    Value := Trim (Copy (S, Index + 1, MaxInt));
  end;
end;

(***************************************************************************)
(* Class:  TConfigSection | methods
(* Domain: public
(***************************************************************************)

function TConfigSection.GetTable (const Ext: string; var T: TTableParameters): boolean;
var
  S: string;
begin
  S := Values [Ext];
  Result := GetData (Ext, T, SizeOf (T));
  if not Result then Result := (S = '') and (CompareText (Ext, '.Default') <> 0) and GetTable ('.Default', T);
  if not Result then Result := (S > '') and (IndexOfName (S) >= 0) and (IndexOfName (S) < IndexOfName (Ext)) and GetTable (S, T);
end;

procedure TConfigSection.PutData (const Name: string; var Data; aCount: integer);
begin
  Values [Name] := Hex (Data, aCount);
end;

function TConfigSection.GetData (const Name: string; var Data; aCount: integer): boolean;
begin
  FillChar (Data, aCount, 0);
  Result := HexToData (Values [Name], Data, aCount);
end;

end.


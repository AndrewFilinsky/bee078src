unit Bee_Headers;

{ Contains:

  Archive headers processing.

  (C) 1999-2005 Andrew Filinsky, Melchiorre Caruso

  Modifyed:

  v0.7.8 build 0150 - 2005/06/27 Melchiorre Caruso
  v0.7.8 build 0154 - 2005/07/23 Melchiorre Caruso
}

{$R-,Q-,S-}

interface

uses
  Math,
  Classes,            // TList
  SysUtils,           // TSearchRec

  Bee_Common,         // FSplit, DirectoryExists, ...
  Bee_Configuration;

type

  // Header flags

  THeaderFlag  =
  (foVersion , foMethod  , foDictionary, foTable   , foTear    , foMoved   , foLast,
   fo08Unused, fo09Unused, fo10Unused  , fo11Unused, fo12Unused, fo13Unused, fo14Unused,
   fo15Unused, fo16Unused, fo17Unused  , fo18Unused, fo19Unused, fo20Unused, fo21Unused,
   fo22Unused, fo23Unused, fo24Unused  , fo25Unused, fo26Unused, fo27Unused, fo28Unused,
   fo29Unused, fo30Unused, fo31Unused  , fo32Unused);

  THeaderFlags = set of THeaderFlag;

type

  // Header action

  THeaderAction = ( toUpdate, toFresh, toCopy, toSwap, toExtract, toTest, toSkip, toQuit, toDelete, toRename, toList, toNone );

  // Headers actions

  THeaderActions = set of THeaderAction;

type

  // Header structure, order of fields is significant

  THeader =  class
  public
    //Start - File header

    Flags:       THeaderFlags;
    Version:     byte;
    Method:      byte;
    Dictionary:  byte;
    Table:       TTableParameters;
    Size:        integer;
    Time:        integer;
    Attr:        integer;
    Crc:         cardinal;
    PackedSize:  integer;
    StartPos:    integer;
    Name:        string;

    // End - File header

    Action:      THeaderAction;
    Option:      string;
    TSize:       integer;

    function     Fresh    (const cOption: string; const Path: string; const T: TSearchRec): integer;
    constructor  Create   (const cOption: string; const Path: string; const T: TSearchRec);
    constructor  Read     (Stream: TStream; Default: THeaderAction);
    function     SetTable (Config: TConfiguration): boolean;
    procedure    Write    (Stream: TStream);
    function     GetName: string;
    destructor   Destroy; override;
  end;

  // Tidy List

  TTidyList = class (TList)
  public
    function     InsertItem (Item: pointer): integer;
    function     SearchItem (const FileName: string): pointer;
  end;

  // Headers list

  THeaders = class (TList)
  public
    cOption:     string;
    fOption:     boolean;
    uOption:     boolean;
    xOption:     TStringList;

    constructor  Create;
    destructor   Destroy;   override;

    function     AddNews    (const aMask: string): integer;
    procedure    MarkItems  (Masks: TStringList; MaskAct, Action: THeaderAction);
    procedure    MarkItem   (Index: integer; Action: THeaderAction);
    procedure    MarkAll    (Action: THeaderAction);

    procedure    SortNews   (Config: TConfiguration; sOption: boolean; eOption: string);

    procedure    ReadItems  (Stream: TStream; Default: THeaderAction);
    procedure    WriteItems (Stream: TStream);

    function     GetBack    (Child: integer; Action: THeaderAction): integer; overload;
    function     GetNext    (Child: integer; Action: THeaderAction): integer; overload;
    function     GetBack    (Child: integer; Flag: THeaderFlag): integer; overload;
    function     GetNext    (Child: integer; Flag: THeaderFlag): integer; overload;

    function     GetSize       (Action: THeaderAction): integer; overload;
    function     GetPackedSize (Action: THeaderAction): integer; overload;
    function     GetSize       (Actions: THeaderActions): integer; overload;
    function     GetPackedSize (Actions: THeaderActions): integer; overload;

    function     GetCount      (Actions: THeaderActions): integer;
    function     GetPointer    (const FileName: string; Actions: THeaderActions): pointer;

  private
    TidyList:    TTidyList;

    procedure    AddItem       (Item: pointer);
    procedure    QuickSort     (L, R: integer);
    procedure    SearchNews    (const aMask: string; var Size: integer);

    procedure    MarkLast      (Last: THeaderAction);
    function     MaskInMasks   (const Mask: string; Masks: TStringList): boolean;
  end;

implementation

const

  // Id marker

  Marker: integer = 442852674;
  RecursiveSign = '*\';

  // Compare header function

  function  CompareFn (L: TList; Index1, Index2: integer): integer;
  var
    bool1, bool2 : boolean;
  begin
    with THeader (L.Items [Index1]) do bool1 := (Action = toUpdate);
    with THeader (L.Items [Index2]) do bool2 := (Action = toUpdate);

    if ( bool1 and bool2 ) then
    begin
      Result := CompareText                    (ExtractFileExt  (THeader (L.Items [Index1]).Name), ExtractFileExt  (THeader (L.Items [Index2]).Name));
      if Result = 0 then Result := CompareText (ExtractFileName (THeader (L.Items [Index1]).Name), ExtractFileName (THeader (L.Items [Index2]).Name));
      if Result = 0 then Result := CompareText                  (THeader (L.Items [Index1]).Name ,                  THeader (L.Items [Index2]).Name );
    end else
      if bool1 then
        Result := 1
      else
        if bool2 then
          Result := -1
        else
          Result := Index1 - Index2;
  end;

  // THeader

  constructor  THeader.Create;
  begin
    Action     := toUpdate;
    Option     := cOption;
    TSize      := T.Size;
    // --
    Flags      := [foTear, foTable];
    Version    := 1;                                     // Bee 0.3.x  - Version := 2 for Bee 0.7.8 ?
    Method     := 1;
    Dictionary := 2;
    Time       := T.Time;
    Crc        := cardinal (-1);
    Name       := Path + T.Name;
  end;

  function     THeader.Fresh;
  begin
    Time       := T.Time;
    Name       := Path + T.Name;
    Result     := T.Size - TSize;
    // --
    Option     := cOption;
    TSize      := T.Size;

    if Action = toCopy then
      Action := toFresh;
  end;

  constructor  THeader.Read;
  var
    J: integer;
  const
    sSecondPart = SizeOf (Size) + SizeOf (Time) + SizeOf (Attr) + SizeOf (Crc) + SizeOf (PackedSize) + SizeOf (StartPos);
  begin
    Action  := Default;
    Option  := '';
    TSize   :=  0;

    if Stream.Read (Flags, SizeOf (Flags))                                         <> SizeOf (Flags)      then Fail;
    if foVersion    in Flags then if Stream.Read (Version, SizeOf (Version))       <> SizeOf (Version)    then Fail;
    if foMethod     in Flags then if Stream.Read (Method, SizeOf (Method))         <> SizeOf (Method)     then Fail;
    if foDictionary in Flags then if Stream.Read (Dictionary, SizeOf (Dictionary)) <> SizeOf (Dictionary) then Fail;
    if foTable      in Flags then if Stream.Read (Table, SizeOf (Table))           <> SizeOf (Table)      then Fail;
    if Stream.Read (Size, sSecondPart)                                             <> sSecondPart         then Fail;

    if Stream.Read (J, SizeOf (J))                                                 <> SizeOf (J)          then Fail;
    SetLength (Name, J);
    if Stream.Read (Name [1], J)                                                   <> J                   then Fail;

    DoDirSeparators (Name);
  end;

  destructor THeader.Destroy;
  begin
    SetLength (Name, 0);
    SetLength (Option, 0);
  end;

  procedure  THeader.Write;
  var
    NLength: integer;
    FName: string;
  const
    sSecondPart = SizeOf (Size) + SizeOf (Time) + SizeOf (Attr) + SizeOf (Crc) + SizeOf (PackedSize) + SizeOf (StartPos);
  begin
    Stream.Write (Flags, SizeOf (Flags));

    if foVersion    in Flags then Stream.Write (Version,    SizeOf (Version   ));
    if foMethod     in Flags then Stream.Write (Method,     SizeOf (Method    ));
    if foDictionary in Flags then Stream.Write (Dictionary, SizeOf (Dictionary));
    if foTable      in Flags then Stream.Write (Table,      SizeOf (Table     ));

    Stream.Write (Size, sSecondPart);

    FName := GetName;
    NLength := Length (FName);
    Stream.Write (NLength, SizeOf (NLength));
    Stream.Write (FName [1], NLength);
  end;

  function  THeader.SetTable (Config: TConfiguration): boolean;
  begin
    Result := Config.GetTable (ExtractFileExt (Name), Table);
  end;

  function  THeader.GetName;
  begin
    Result := Option + DeleteFileDrive (Name);
  end;

  // TidyList

  function  TTidyList.SearchItem;
  var
    L, M, H: integer;
  begin
    L :=   0;
    M := - 1;
    H := Count - 1;

    while H >= L do
    begin
      M := (L + H) div 2;
      if CompareText (FileName, THeader (Items [M]).GetName) > 0 then
        L := M + 1
      else
        if CompareText (FileName, THeader (Items [M]).GetName) < 0 then
          H := M - 1
        else
          H := - 2;
    end;

    if not (H = - 2) then
      Result := nil
    else
      Result := Items [M];
  end;

  function TTidyList.InsertItem;
  var
    L, M, H: integer;
    FName: string;
  begin
    L :=   0;
    M := - 1;
    H := Count - 1;

    FName := THeader (Item).GetName;
    while H >= L do
    begin
      M := (L + H) div 2;
      if CompareText (FName, THeader (Items [M]).GetName) > 0 then
        L := M + 1
      else
        if CompareText (FName, THeader (Items [M]).GetName) < 0 then
          H := M - 1
        else
          H := - 2;
    end;

    if M = - 1 then
      Result := 0
    else
      if CompareText (FName, THeader (Items [M]).GetName) = -1 then
        Result := M
      else
        Result := M + 1;

    Insert (Result, Item);    
  end;

  // THeaders

  constructor THeaders.Create;
  begin
    inherited Create;
    cOption  := '';
    fOption  := False;
    uOption  := False;
    xOption  := nil;
    TidyList := TTidyList.Create;
  end;

  destructor  THeaders.Destroy;
  var
    I: integer;
  begin
    TidyList.Destroy;
    for I := Count - 1 downto 0 do
      THeader (Items [I]).Destroy;
    inherited Destroy;
  end;

  function   THeaders.AddNews;
  begin
    Result := 0;
    SearchNews (aMask, Result);
  end;

  procedure  THeaders.MarkItems;
  var
    I: integer;
  begin
    for I := 0 to Count - 1 do
      if (THeader (Items [I]).Action = MaskAct) and (MaskInMasks (THeader (Items [I]).Name, Masks)) then
        THeader (Items [I]).Action := Action;
  end;

  procedure  THeaders.MarkItem;
  begin
    THeader (Items [Index]).Action := Action;
  end;

  procedure  THeaders.MarkAll;
  var
    I: integer;
  begin
    for I := 0 to Count - 1 do
      THeader (Items [I]).Action := Action;
  end;
  
  procedure  THeaders.SortNews;
  var
    P: THeader;
    First, I, Method, Dictionary: integer;
    CurrentExt, PreviousExt: string;
  begin
    QuickSort (0, Count -1);
    
    Config.Selector ('\main');
    Method     := StrToInt (Config.CurrentSection.Values ['Method']);
    Dictionary := StrToInt (Config.CurrentSection.Values ['Dictionary']);
    Config.Selector ('\m' + Config.CurrentSection.Values ['Method']);

    First := GetNext (0, toUpdate);
    if not (First = -1) then
    begin
      CurrentExt := '.';
      I := First;
      repeat
        P := Get (I);

        if I = First then P.Flags := P.Flags + [foVersion, foMethod, foDictionary];

        P.Method     := Method;
        P.Dictionary := Dictionary;
        PreviousExt  := CurrentExt;

        if Length (eOption) = 0 then
          CurrentExt := ExtractFileExt (P.Name)
        else
          CurrentExt := eOption;

        if (Method = 0) or (not Config.GetTable (CurrentExt, P.Table)) then begin
          Include (P.Flags, foMoved);
          Exclude (P.Flags, foTable);
        end else
        if CompareText (CurrentExt, PreviousExt) <> 0 then begin
          Include (P.Flags, foTable);
        end else
        begin
          Exclude (P.Flags, foTable);
          if sOption then Exclude (P.Flags, foTear);
        end;

        Inc (I);
      until I = Count;
    end;
  end;

  procedure  THeaders.ReadItems;
  var
    Id: integer;
    P: THeader;
  begin
    Stream.Seek (0, 0);
    repeat
      if (not (Stream.Read (Id, 4) = 4)) or (not (Id = Marker)) then Exit;
      P := THeader.Read (Stream, Default);
      if not (P = nil) then
        AddItem (P);
    until foLast in P.Flags;
    if not (P = nil) then
      Exclude(P.Flags, foLast);
  end;

  procedure  THeaders.WriteItems;
  var
    I: integer;
  begin
    MarkLast (toDelete);
    Stream.Seek (0, 0);    
    for I := 0 to Count - 1 do
      if not (THeader (Items [I]).Action = toDelete) then
      begin
        Stream.Write (Marker, 4);
        THeader (Items [I]).Write (Stream);
      end;
  end;

  function  THeaders.GetPointer;
  begin
    Result := TidyList.SearchItem (FileName);
    if not (Result = nil) then
      if not (THeader (Result).Action in Actions) then
        Result := nil;
  end;
  
  function  THeaders.GetCount;
  var
    I: integer;
  begin
    Result := 0;
    for I := 0 to Count - 1 do
      if (THeader (Items [I]).Action in Actions) then
        Inc (Result);
  end;

  function  THeaders.GetNext (Child: integer; Action: THeaderAction): integer;
  var
    I: integer;
  begin
    Result := -1;
    for I := Child to Count - 1 do
      if (THeader (Items [I]).Action = Action) then
      begin
        Result := I;
        Exit;
      end;
  end;

  function  THeaders.GetBack (Child: integer; Action: THeaderAction): integer; 
  var
    I: integer;
  begin
    Result := -1;
    for I := Child downto 0 do
      if (THeader (Items [I]).Action = Action) then
      begin
        Result := I;
        Exit;
      end;
  end;

  function  THeaders.GetNext (Child: integer; Flag: THeaderFlag): integer;
  var
    I: Integer;
  begin
    Result := -1;  
    for I := Child to Count - 1 do
    begin
      if (Flag in THeader ( Items [I]).Flags) then
      begin
        Result := I;
        Exit;
      end;
    end;
  end;

  function  THeaders.GetBack (Child: integer; Flag: THeaderFlag): integer;
  var
    I: Integer;
  begin
    Result := -1;
    for I := Child downto 0 do
    begin
      if (Flag in THeader ( Items [I]).Flags) then
      begin
        Result := I;
        Exit;
      end;
    end;
  end;

  function  THeaders.GetSize (Action: THeaderAction): integer;
  var
    I: integer;
  begin
    Result := 0;
    for I := 0 to Count - 1 do
      if THeader (Items [I]).Action = Action then
        Inc (Result, THeader (Items [I]).Size);
  end;

  function  THeaders.GetPackedSize (Action: THeaderAction): integer;
  var
    I: integer;
  begin
    Result := 0;
    for I := 0 to Count - 1 do
      if THeader (Items [I]).Action = Action then
        Inc (Result, THeader (Items [I]).PackedSize);
  end;

  function  THeaders.GetSize (Actions: THeaderActions): integer;
  var
    I: integer;
  begin
    Result := 0;
    for I := 0 to Count - 1 do
      if THeader (Items [I]).Action in Actions then
        Inc (Result, THeader (Items [I]).Size);
  end;

  function  THeaders.GetPackedSize (Actions: THeaderActions): integer;
  var
    I: integer;
  begin
    Result := 0;
    for I := 0 to Count - 1 do
      if THeader (Items [I]).Action in Actions then
        Inc (Result, THeader (Items [I]).PackedSize);
  end;

  // Private procedure and function

  procedure THeaders.AddItem;
  begin
    Add (Item);
    TidyList.InsertItem (Item);
  end;

  procedure THeaders.QuickSort;
  var
    I, J, Pivot: integer;
  begin
    repeat
      I := L;
      J := R;
      Pivot := (L + R) div 2;
      repeat
        while CompareFn (Self, I, Pivot) < 0 do Inc (I);
        while CompareFn (Self, J, Pivot) > 0 do Dec (J);
        if I <= J then
        begin          
          Exchange (I, J);
          if Pivot = I then
            Pivot := J
          else
            if Pivot = J then
              Pivot := I;
          Inc (I);
          Dec (j);
        end;
      until I > J;
      if L < J then QuickSort (L, J);
      L := I;
    until I >= R;
  end;

  procedure  THeaders.MarkLast;
  var
    I: integer;
  begin
    for I := Count - 1 downto 0 do 
      if not (THeader (Items [I]).Action = Last) then
      begin
        Include (THeader (Items [I]).Flags, foLast);
        Exit;
      end;
  end;

  function  THeaders.MaskInMasks;
  var
    Path, Name, Ext: string;
    jPath, jName, jExt: string;
    j, jCount: integer;
    Recursive: integer;
  begin
    Result := False;
    if (not (Masks = nil)) and (not (Masks.Count = 0)) then
    begin
      Path := ExtractFilePath (Mask);
      Name := ChangeFileExt   (ExtractFileName (Mask), '');
      Ext := ExtractFileExt   (Mask);
      jCount := 0;

      for j := 0  to Masks.Count - 1 do
      begin
        jPath := ExtractFilePath (Masks.Strings [j]);
        jName := ChangeFileExt   (ExtractFileName (Masks.Strings [j]), '');
        jExt  := ExtractFileExt  (Masks.Strings [j]);
        jCount:= 0;

        Recursive := Pos (RecursiveSign, jPath);
        if Recursive = (Length (jPath) - 1) then
        begin
          System.Delete (jPath, Recursive, 2);
          if not (Recursive = 1) then
            if not IsPathDelimiter (jPath, Recursive - 1) then Continue;
        end else
            if not (Recursive = 0) then
              Continue;

        if Recursive = 0 then
        begin
          if (CompareText (jPath, Path) = 0) then Inc (jCount);
        end else
          if ( (Length (jPath) = 0) or (PosText (jPath, Path) = 1) ) then Inc (jCount);

        if ( (jName = '*') or (CompareText (jName, Name) = 0) ) then Inc (jCount);
        if ( (jExt = '.*') or (CompareText (jExt,  Ext ) = 0) ) then Inc (jCount);

        if (jCount = 3) then Break;
      end;

      if (jCount = 3) then Result := True else Result := False;
    end;
  end;

  procedure  THeaders.SearchNews;
  var
    Mask, Path, Name: string;
    Recursive: integer;
    T: TSearchRec;
    P: THeader;
    J: Pointer;
  begin
    if DirectoryExists (aMask) then
      Mask := IncludeDelimiter (aMask) + '*\*.*'
    else
      Mask := aMask;

    Path := ExtractFilePath (Mask);
    Name := ExtractFileName (Mask);

    Recursive := Pos (RecursiveSign, Path);
    if Recursive = (Length (Path) - 1) then
    begin
      System.Delete (Path, Recursive, 2);
      System.Delete (Mask, Recursive, 2);
      if not (Recursive = 1) then
        if not IsPathDelimiter (Path, Recursive - 1) then Exit;
    end else
    if not (Recursive = 0) then Exit;

    // This directory...

    if FindFirst (Mask, faAnyFile - faDirectory, T) = 0 then
    repeat
      if not MaskInMasks (Path + T.Name, xOption) then                           // if not excluded
      begin
        J := TidyList.SearchItem (cOption + DeleteFileDrive (Path + T.Name));    // search this filename
        if not (fOption xor uOption) then                                        // Update and Fresh
        begin
          if (J = nil) then
          begin
            P := THeader.Create (cOption, Path, T);
            Inc (Size, T.Size);
            AddItem (P);                                                         
          end else
            if (T.Time > THeader (J).Time) then
              Size := Size + THeader (J).Fresh (cOption, Path, T);
        end else
          if fOption then // Fresh
          begin
            if (not (J = nil)) and (T.Time > THeader (J).Time) then
              Size := Size + THeader (J).Fresh (cOption, Path, T);
          end else // Update
          begin
            if (J = nil) then
            begin
              P := THeader.Create (cOption, Path, T);
              Inc (Size, T.Size);
              AddItem (P);  
            end;
          end;
      end;

    until not (FindNext (T) = 0);
    FindClose (T);

    if Recursive = 0 then exit;

    // SubDirectoryes...

    if FindFirst (Path + '*.*', faDirectory, T) = 0 then
    repeat
      if (T.Name <> '.') and (T.Name <> '..') and (T.Attr and faDirectory = faDirectory) then
        SearchNews (Path + T.Name + '\' + RecursiveSign + Name, Size);
    until not (FindNext (T) = 0);
    FindClose (T);
  end;

end.

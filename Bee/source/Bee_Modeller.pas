unit Bee_Modeller;

{ Contains:

  TBaseCoder class, PPM modeller;

  (C) 1999-2005 Andrew Filinsky.

  Modifyed:

  v0.7.8 build 0153 - 2005/07/08 by Andrew Filinsky.
}

{$R-,Q-,S-}

interface

uses
  Math,                  // Max (), Min (), ...
  Classes,               // TStream
  Bee_Codec,             // TSecondaryCodec, ...
  Bee_Configuration,     // TTable, TTableCol, ...
  Bee_Common;            // Diag, ...

const
  BitChain  = 4;                    // Size of data portion, bit
  MaxSymbol = 1 shl BitChain - 1;   // Size of source alphabet, symbols
  Increment = 8;                    // Increment of symbol frequency

type
  PNode = ^ TNode;                  // Pointer to modeller's node information...
  PPNode = ^ PNode;                 // Array of nodes...

  // Modeller's node information...

  TNode = record
    Next, Up: PNode;                // Next node of this or high level
    K: word;                        // Frequency of this symbol
    C: byte;                        // This symbol itself
    D: byte;                        // Used for incoming data storage
    case Cardinal of
      1: (A: integer);              // Source address
      2: (Tear: PNode);             // Next free node
  end;

  /// PPM modeller...

  TBaseCoder = class (TObject)
    constructor Create (aCodec: TSecondaryCodec);
    destructor  Destroy; override;

    procedure   SetTable (const T: TTableParameters);
    procedure   SetDictionary (aDictionaryLevel: cardinal);
    procedure   FreshFlexible;
    procedure   FreshSolid;
    function    UpdateModel (aSymbol: cardinal): cardinal;

  private
    NewNode:   function (aA: cardinal; aNext: PNode): PNode of object;

    function   FirstNewNode (aA: cardinal; aNext: PNode): PNode;
    function   SecondNewNode (aA: cardinal; aNext: PNode): PNode;
    procedure  Cut;
    procedure  Cut_Tail (I, J: PPNode);
    procedure  Add (B: cardinal);
    function   Tail (N: PNode): PNode;
    procedure  Account;
    procedure  Step;

  private
    Pos: cardinal;
    LowestPos: integer;

    FDictionaryLevel: cardinal;
    MaxCounter,                     // Maximal heap size
    SafeCounter,                    // Safe heap size
    Counter: cardinal;              // Current heap size

    Heap: array of TNode;
    Cuts: array of PNode;
    List: array of PNode;
    ListCount: cardinal;

    Root,
    Last,
    Tear: PNode;

    IncreaseIndex: cardinal;
    R, Q: cardinal;

    Symbol: cardinal;

    Codec: TSecondaryCodec;         // Secondary encoder or decoder...
    W: TFreq;                       // Symbol frequencyes...

    Part: ^TTableCol;               // Part of parameters Table...
    Table: TTable;                  // Parameters Table...
  end;

implementation

/// TBaseCoder...

  constructor  TBaseCoder.Create (aCodec: TSecondaryCodec);
  begin
    inherited Create;
    Codec := aCodec;
    SetLength (W, MaxSymbol + 1);
    SetLength (List, 16);
  end;

  destructor  TBaseCoder.Destroy;
  begin
    W    := nil;
    Heap := nil;
    Cuts := nil;
    List := nil;
    inherited Destroy;
  end;

  procedure  TBaseCoder.SetTable (const T: TTableParameters);
  var
    I: integer;
    P: ^integer;
    aPart: ^TTableCol;
  begin
    P := @ Table; I := 1; repeat P^ := integer (T [I]) + 1; Inc (P); Inc (I); until I > SizeOf (T);

    Table.Level := Table.Level - 1;
    Table.Level := Table.Level and $F;

    For I := 1 to 2 do begin
      aPart := @ Table.T [I];
      aPart [0]             := aPart [0] + 256;
      aPart [MaxSymbol + 2] := aPart [MaxSymbol + 2] + 32;
      aPart [MaxSymbol + 3] := Increment * aPart [MaxSymbol + 3] shl 2;
      aPart [MaxSymbol + 4] := aPart [MaxSymbol + 4] div 8; /// Zero-valued parameter allowed...
      aPart [MaxSymbol + 5] := Round (IntPower (1.082, aPart [MaxSymbol + 5]));
    end;
  end;

  procedure  TBaseCoder.SetDictionary (aDictionaryLevel: cardinal);
  begin
    if (FDictionaryLevel = 0) or (FDictionaryLevel <> aDictionaryLevel) then
    begin
      FDictionaryLevel := aDictionaryLevel;
      MaxCounter  := 1 shl (17 + Min (Max (0, FDictionaryLevel), 9)) - 1;
      SafeCounter := MaxCounter - 64;
      SetLength (Heap, 0);
      SetLength (Heap, MaxCounter + 1);
    end;
    FreshFlexible;
  end;

  procedure  TBaseCoder.FreshFlexible;
  begin
    NewNode := FirstNewNode;
    Tear := nil;
    Last := @ Heap [MaxCounter + 1];
    Counter := 0;
    ListCount := 0;
    Pos := 0;
    Root := NewNode (0, nil);
    LowestPos := - MaxCounter;
  end;

  procedure  TBaseCoder.FreshSolid;
  begin
    if Counter > 1 then begin
      ListCount := 1;
      List [0] := Root;
    end else
      ListCount := 0;
  end;

  procedure TBaseCoder.Add (B: cardinal);
  begin
    Inc (Pos);
    Inc (LowestPos);
    Heap [Pos and MaxCounter].D := B;
  end;

  function  TBaseCoder.FirstNewNode (aA: cardinal; aNext: PNode): PNode;
  begin
    Inc (Counter);
    Dec (Last);
    Result := Last;

    if Result = @ Heap [0] then NewNode := SecondNewNode;

    Result.Next := aNext;
    Result.Up := nil;
    Result.K := Increment;
    Result.C := Heap [aA and MaxCounter].D;
    Result.A := aA + 1;
  end;

  function  TBaseCoder.SecondNewNode (aA: cardinal; aNext: PNode): PNode;
  var
    Link: PNode;
  begin
    Inc (Counter);

    Result := Tear;
    Link := Result.Tear;
    if Result.Next <> nil then begin Result.Next.Tear := Link; Link := Result.Next; end;
    if Result.Up <> nil then begin Result.Up.Tear := Link; Link := Result.Up; end;
    Tear := Link;

    Result.Next := aNext;
    Result.Up := nil;
    Result.K := Increment;
    Result.C := Heap [aA and MaxCounter].D;
    Result.A := aA + 1;
  end;

  procedure  TBaseCoder.Cut;
  var
    I, J: PPNode; P: PNode; Bound: integer;
  begin
    SetLength (Cuts, MaxCounter + 1);
    I := @ Cuts [0]; J := I; Inc (J); I^ := Root; ListCount := 0; Bound := SafeCounter * 3 div 4;

    repeat
      P := I^^.Up;
      repeat
        Dec (Bound);
        if P.Up <> nil then
          if P.A > LowestPos then begin
            J^ := P; Inc (J);
          end else begin
            P.Up.Tear := Tear; Tear := P.Up; P.Up := nil;
          end;
        P := P.Next;
      until P = nil;
      Inc (I);
    until (I = J) or (Bound < 0);

    if I <> J then Cut_Tail (I, J);

    Counter := integer (SafeCounter * 3 div 4) - Bound + 1;
  end;

  procedure  TBaseCoder.Cut_Tail (I, J: PPNode);
  var
    P: PNode;
  begin
    P := Tear;
    repeat
      I^.Up.Tear := P;
      P := I^.Up;
      I^.Up := nil;
      Inc (I);
    until I = J;
    Tear := P;
  end;

  procedure  TBaseCoder.Account;
  var
    I, J, K: cardinal;
    P, Stored: PNode;
  begin
    I := 0; IncreaseIndex := 0; Q := 0;
    repeat
      P := List [I];
      if P.Up <> nil then begin
        if IncreaseIndex = 0 then IncreaseIndex := I;
        P := P.Up;
        if P.Next <> nil then begin
          /// Undetermined context ...
          K := 0;
          J := 0;
          Stored := P; Inc (J); Inc (K, P.K * Part [MaxSymbol + 2] div 32); P := P.Next; repeat Inc (J); Inc (K, P.K); P := P.Next; until P = nil;
          Q := Q + Part [J];
          /// Account:
          K := R div (K + Q);
          P := Stored; J := K * P.K * Part [MaxSymbol + 2] div 32; Inc (W [P.C], J); Dec (R, J); P := P.Next; repeat J := K * P.K; Inc (W [P.C], J); Dec (R, J); P := P.Next; until P = nil;
        end else begin
          /// Determined context ...
          K := P.K * Part [1] div Increment + 256;
          K := (R div K) shl 8;
          Inc (W [P.C], R - K);
          R := K;
        end;
      end else if P.A > LowestPos then begin
        /// Determined context, encountered at first time ...
        P.Up := NewNode (P.A, nil);
        K := R div Part [0] shl 8;
        Inc (W [P.Up.C], R - K);
        R := K;
      end;
      I := I + 1;
    until (I = ListCount) or (R <= Part [MaxSymbol + 5]);
    ListCount := I;
  end;

  function TBaseCoder.Tail (N: PNode): PNode;
  var
    P: PNode;
    C: byte;
  begin
    Result := N.Up;
    N.A := Pos;

    if Result = nil then
      N.Up := NewNode (N.A, nil)
    else begin
      C := Symbol;
      if Result.C <> C then begin
        repeat
          P := Result; Result := Result.Next;
          if Result = nil then begin
            N.Up := NewNode (N.A, N.Up);
            break;
          end else if Result.C = C then begin
            P.Next := Result.Next; Result.Next := N.Up; N.Up := Result;
            break;
          end;
        until false;
      end;
    end;
  end;

  procedure  TBaseCoder.Step;
  var
    I, J: cardinal;
    P: PNode;
  begin
    I := Length (W); repeat Dec (I); W [I] := 0; until I = 0;
    R := MaxFreq - MaxSymbol - 1;

    if ListCount > 0 then Account;

    /// Update aSymbol...
    J := R shr BitChain + 1;
    I := 0; repeat Inc (W [I], J); Inc (I); until I = MaxSymbol + 1;

    Symbol := Codec.UpdateSymbol (W, Symbol);
    Add (Symbol);

    if ListCount > 0 then begin
      /// Update frequencyes...
      I := 0;
      repeat
        P := List [I];
        if I = IncreaseIndex then begin
          /// Special case...
          Inc (P.K, Increment);
        end else begin
          /// General case...
          Inc (P.K, Part [MaxSymbol + 4]);
        end;
        if P.K > Part [MaxSymbol + 3] then
          repeat
            P.K := P.K shr 1;
            P := P.Next;
          until P = nil;
        Inc (I);
      until I > IncreaseIndex;

      /// Update Tree:
      I := 0; J := 0;
      repeat
        P := Tail (List [I]);
        if P <> nil then begin List [J] := P; Inc (J); end;
        Inc (I);
      until I = ListCount;
      ListCount := J;
    end;
  end;

  function  TBaseCoder.UpdateModel (aSymbol: cardinal): cardinal;
  begin
    Result := 0;
    Part := @ Table.T [1]; Symbol := aSymbol shr $4; Step; Inc (Result, Symbol shl 4);
    Part := @ Table.T [2]; Symbol := aSymbol and $F; Step; Inc (Result, Symbol);

    /// Reduce tree...
    if SafeCounter < Counter then Cut;

    /// Update NodeList...
    if ListCount > Table.Level then Move (List [1], List [0], (ListCount - 1) * 4) else Inc (ListCount);
    List [ListCount - 1] := Root;
  end;

end.

unit Bee_MainPacker;

{ Contains:

  TEncoder class, file encoder;
  TDecoder class, file decoder;

  (C) 1999-2005 Andrew Filinsky, Melchiorre Caruso

  Modifyed:

  v0.7.8 build 0148 - 2005/06/23 Melchiorre Caruso
  v0.7.8 build 0153 - 2005/07/08 by Andrew Filinsky.
}

{$R-,Q-,S-}

interface

  uses
    SysUtils,     // FileSetAttr...
    Classes,      // TStream
    Bee_Files,    // TBufferizedReader
    Bee_Crc,      // UpdCrc32...
    Bee_Headers,
    Bee_Common,   // Diag...
    Bee_Codec,    // TSecondaryEncoder, TSecondaryDecoder...
    Bee_Modeller; // TBaseCoder...

  const
    InformationWidth = 60;

    msgUpdating   = 'Updating   ';
    msgExtracting = 'Extracting ';
    msgTesting    = 'Testing    ';
    msgSkipping   = 'Skipping   ';
    msgEncoding   = 'Encoding   ';
    msgDecoding   = 'Decoding   ';
    msgCopying    = 'Copying    ';
    msgDeleting   = 'Deleting   ';
    msgScanning   = 'Scanning   ';
    msgOpening    = 'Opening    ';
    msgListing    = 'Listing    ';
    msgRenaming   = 'Renaming   ';
    msgRename     = 'Rename     ';

  // Extracting Modes:
  //   pmNorm  Extract files
  //   pmSkip  Extract files, but skip current
  //   pmTest  Test files (Extract to nul)
  //   pmQuit  Cancel extracting

  type
    TExtractMode = (pmNorm, pmSkip, pmTest, pmQuit);

  // Encoding Modes:
  //   emNorm  Encode files
  //   emOpt   Encode files to nul, with no messages

  type
    TEncodingMode = (emNorm, emOpt);

  // Execution Estimator, estimates execution percentage...

  type
    TExecutionPercentes = class
    public
      GeneralSize: cardinal;
      RemainSize:  cardinal;

      constructor  Create;
      procedure    Display;
      procedure    Tick;
    end;

  // Encoder...

  type
    TEncoder = class
      constructor  Create       (aStream: TStream; aPercentes: TExecutionPercentes);
      destructor   Destroy;     override;
      function     EncodeFile   (Header: THeader; Mode: TEncodingMode): Boolean;
      function     EncodeStrm   (Header: THeader; Mode: TEncodingMode; SrcStrm: TStream): Boolean;
      function     CopyStrm     (Header: THeader; Mode: TEncodingMode; SrcStrm: TStream): Boolean;
      procedure    EncodeBlock  (const Src; Size: Integer; Solid: Boolean; Mode: TEncodingMode);
    private
      Stream: TStream;
      PPM: TBaseCoder;
      SecondaryCodec: TSecondaryCodec;
      Percentes: TExecutionPercentes;
    end;

  // Decoder...

  type
    TDecoder = class
      constructor  Create       (aStream: TStream; aPercentes: TExecutionPercentes);
      destructor   Destroy;     override;
      function     DecodeFile   (Header: THeader; Mode: TExtractMode): Boolean;
      function     DecodeStrm   (Header: THeader; Mode: TExtractMode; DstStrm: TStream): Boolean;
    private
      Stream: TStream;
      PPM: TBaseCoder;
      SecondaryCodec: TSecondaryCodec;
      Percentes: TExecutionPercentes;
    end;

implementation

  // TExecutionPercentes:

  constructor  TExecutionPercentes.Create;
  begin
    GeneralSize := 0;
    RemainSize := 0;
  end;

  procedure  TExecutionPercentes.Display;
  begin
    if GeneralSize > 0 then
      Write (#8#8#8#8#8#8, RemainSize/GeneralSize*100:5:1, '%');
  end;

  procedure  TExecutionPercentes.Tick;
  begin
    if RemainSize and $FFFF = 0 then Display;
    Inc (RemainSize);
  end;

  // TEncoder:

  constructor  TEncoder.Create;
  begin
    Stream := aStream;
    Percentes := aPercentes;
    SecondaryCodec := TSecondaryEncoder.Create (aStream);
    PPM := TBaseCoder.Create (SecondaryCodec);
  end;

  destructor  TEncoder.Destroy;
  begin
    PPM.Free;
    SecondaryCodec.Free;
  end;

  function  TEncoder.EncodeFile;
  var
    SrcFile: TFileReader;
    Symbol: byte;
    I: integer;
    Msg: ansistring;
  begin
    if foDictionary in Header.Flags then PPM.SetDictionary (Header.Dictionary);
    if foTable in Header.Flags then PPM.SetTable (Header.Table);
    if foTear in Header.Flags then PPM.FreshFlexible else PPM.FreshSolid;

    Header.StartPos := Stream.Position;
    Header.Crc := Cardinal (-1);

    try
      SrcFile := TFileReader.Create (Header.Name, fmOpenRead + fmShareDenyWrite);
    except
      SrcFile := nil;
    end;

    if not (SrcFile = nil) then
    begin

      if Mode = emNorm then
      begin
        Msg := msgUpdating + Header.GetName;
        I := (80 + 60 - Length (Msg) mod 80) mod 80;
        Write (Msg, StringOfChar (' ', I + 7));
        Percentes.Display;
      end;

      Header.Size := SrcFile.Size;
      Header.Attr := FileGetAttr (Header.Name);

      if foMoved in Header.Flags then
      begin
        for I := 1 to Header.Size do
        begin
          if Mode = emNorm then Percentes.Tick;
          if SrcFile.Read (Symbol, 1) <> 1 then raise EReadError.Create ('Error reading symbol');
          UpdCrc32 (Header.Crc, Symbol);
          Stream.Write (Symbol, 1);
        end;
      end else begin
        SecondaryCodec.Start;
        for I := 1 to Header.Size do
        begin
          if Mode = emNorm then Percentes.Tick;
          if SrcFile.Read (Symbol, 1) <> 1 then raise EReadError.Create ('Error reading symbol');
          UpdCrc32 (Header.Crc, Symbol);
          PPM.UpdateModel (Symbol);
        end;
        SecondaryCodec.Flush;
      end;

      SrcFile.Free;
      Header.PackedSize := Stream.Position - Header.StartPos;
      if Mode = emNorm then
        if Length (Msg) Mod 80 in [0, 61..79] then DelLine Else Writeln (#8#8#8#8#8#8'      ');
    end else
      Write ('Error: file ', Header.Name, ' not found');

    if Header.PackedSize > Header.Size then
    begin
      Include (Header.Flags, foTear);
      Include (Header.Flags, foMoved);
      Stream.Size := Header.StartPos;
      Result := EncodeFile (Header, emOpt);
    end else
      Result := True;
  end;

  function  TEncoder.EncodeStrm;
  var
    SrcFile: TStream;
    SrcPosition: integer;
    Symbol: Byte;
    I: Integer;
    Msg: ansistring;
  begin
    if foDictionary in Header.Flags then PPM.SetDictionary (Header.Dictionary);
    if foTable in Header.Flags then PPM.SetTable (Header.Table);
    if foTear in Header.Flags then PPM.FreshFlexible else PPM.FreshSolid;

    SrcPosition := 0;
    SrcFile := SrcStrm;
    if not (SrcFile = nil) then
    begin
      if Mode = emNorm then
      begin
        Msg := msgEncoding + Header.Name;
        I := (80 + 60 - Length (Msg) mod 80) mod 80;
        Write (Msg, StringOfChar (' ', I + 7));
        Percentes.Display;
      end;

      if not (SrcFile.Position = Header.StartPos) then
        SrcFile.Position := Header.StartPos;

      SrcPosition     := Header.StartPos;
      Header.StartPos := Stream.Position;
      Header.Crc      := Cardinal (-1);

      if foMoved in Header.Flags then
      begin
        for I := 1 to Header.Size do
        begin
          if Mode = emNorm then Percentes.Tick;
          if SrcFile.Read (Symbol, 1) <> 1 then raise EReadError.Create ('Error reading symbol');
          UpdCrc32 (Header.Crc, Symbol);
          Stream.Write (Symbol, 1);
        end;
      end else
      begin
        SecondaryCodec.Start;
        for I := 1 to Header.Size do
        begin
          if Mode = emNorm then Percentes.Tick;
          if SrcFile.Read (Symbol, 1) <> 1 then raise EReadError.Create ('Error reading symbol');
          UpdCrc32 (Header.Crc, Symbol);
          PPM.UpdateModel (Symbol);
        end;
        SecondaryCodec.Flush;
      end;

      Header.PackedSize := Stream.Position - Header.StartPos;
      if Mode = emNorm then
        if Length (Msg) Mod 80 in [0, 61..79] then DelLine Else Writeln (#8#8#8#8#8#8'      ');
    end else
      Write ('Error: stream  not found');

    if Header.PackedSize > Header.Size then
    begin
      Include (Header.Flags, foTear);
      Include (Header.Flags, foMoved);
      Stream.Size := Header.StartPos;

      // Rescue Position
      Header.StartPos := SrcPosition;

      Result := EncodeStrm (Header, emOpt, SrcStrm);
    end else
      Result := True;
  end;

  function  TEncoder.CopyStrm;
  var
    SrcFile: TStream;
    Symbol: Byte;
    I: Integer;
    Msg: ansistring;
  begin
    if foDictionary in Header.Flags then PPM.SetDictionary (Header.Dictionary);
    if foTable in Header.Flags then PPM.SetTable (Header.Table);
    if foTear in Header.Flags then PPM.FreshFlexible else PPM.FreshSolid;

    SrcFile := SrcStrm;
    if not (SrcFile = nil) then
    begin
      if Mode = emNorm then
      begin
        Msg := msgCopying + Header.Name;
        I := (80 + 60 - Length (Msg) mod 80) mod 80;
        Write (Msg, StringOfChar (' ', I + 7));
        Percentes.Display;
      end;

      if not (SrcFile.Position = Header.StartPos) then
        SrcFile.Position := Header.StartPos;

      Header.StartPos := Stream.Position;

      for I := 1 to Header.PackedSize do
      begin
        if Mode = emNorm then Percentes.Tick;
        if SrcFile.Read (Symbol, 1) <> 1 then raise EReadError.Create ('Error reading symbol');
        Stream.Write (Symbol, 1);
      end;

      if Mode = emNorm then
        if Length (Msg) Mod 80 in [0, 61..79] then DelLine Else Writeln (#8#8#8#8#8#8'      ');        
    end else
      Write ('Error: stream  not found');
   
    Result := True;
  end;

  procedure  TEncoder.EncodeBlock;
  var
    SrcBuffer: array [1..$FFFFFFF] of Byte absolute Src;
    I: Integer;
  begin
    if Mode = emNorm then Write ('       ');

    if Solid then
      PPM.FreshSolid
    else
      PPM.FreshFlexible;

    SecondaryCodec.Start;
    for I := 1 to Size do
    begin
      if Mode = emNorm then Percentes.Display;
      PPM.UpdateModel (SrcBuffer [I]);
    end;
    SecondaryCodec.Flush;

    if Mode = emNorm then Write (#8#8#8#8#8#8'      ');
  end;

  // TDecoder:

  constructor  TDecoder.Create;
  begin
    Stream := aStream;
    Percentes := aPercentes;
    SecondaryCodec := TSecondaryDecoder.Create (aStream);
    PPM := TBaseCoder.Create (SecondaryCodec);
  end;

  destructor  TDecoder.Destroy;
  begin
    PPM.Free;
    SecondaryCodec.Free;
  end;

  function  TDecoder.DecodeFile;
  var
    DstFile: TStream;
    Symbol: Byte;
    I, Crc: Cardinal;
    Msg: ansistring;
  begin
    if foDictionary in Header.Flags then PPM.SetDictionary (Header.Dictionary);
    if foTable in Header.Flags then PPM.SetTable (Header.Table);
    if foTear in Header.Flags then PPM.FreshFlexible else PPM.FreshSolid;

    case Mode of
      pmSkip: Msg := msgSkipping;
      pmTest: Msg := msgTesting;
      pmNorm: Msg := msgExtracting;
      pmQuit: begin Result := True; Exit; end;
    end;

    Msg := Msg + Header.Name;
    I := (80 + 60 - Length (Msg) mod 80) mod 80;
    Write (Msg, StringOfChar (' ', I + 7));

    Stream.Position := Header.StartPos;
    Crc := Cardinal (-1);

    if Mode = pmNorm then
    try
      DstFile := TFileWriter.Create (Header.Name, fmCreate)
    except
      DstFile := TNulWriter.Create;
    end else
      DstFile := TNulWriter.Create;

    if foMoved in Header.Flags then
    begin
      for I := 1 to Header.Size do
      begin
        Percentes.Tick;
        Stream.Read (Symbol, 1);
        UpdCrc32 (Crc, Symbol);
        DstFile.Write (Symbol, 1);
      end;
    end else
    begin
      SecondaryCodec.Start;
      for I := 1 to Header.Size do
      begin
        Percentes.Tick;
        Symbol := PPM.UpdateModel (0);
        UpdCrc32 (Crc, Symbol);
        DstFile.Write (Symbol, 1);
      end;
      SecondaryCodec.Flush;
    end;

    if Mode = pmNorm then
    begin
      TFileWriter (DstFile).Flush;
      FileSetDate (TFileWriter (DstFile).Handle, Header.Time);
    end;
    DstFile.Free;

    if Mode = pmNorm then FileSetAttr (Header.Name, Header.Attr);

    Result := Header.Crc = Crc;
    if Result then Writeln (#8#8#8#8#8#8'Ok    ') else Writeln (#8#8#8#8#8#8'-- CRC Error');
  end;

  function  TDecoder.DecodeStrm;
  var
    DstFile: TStream;
    Symbol: Byte;
    I, Crc: Cardinal;
    Msg: ansistring;
  begin
    if foDictionary in Header.Flags then PPM.SetDictionary (Header.Dictionary);
    if foTable in Header.Flags then PPM.SetTable (Header.Table);
    if foTear in Header.Flags then PPM.FreshFlexible else PPM.FreshSolid;

    case Mode of
      pmSkip: Msg := msgSkipping;
      pmTest: Msg := msgTesting;
      pmNorm: Msg := msgDecoding;
      pmQuit: begin Result := True; Exit; end;
    end;

    Msg := Msg + Header.Name;
    I := (80 + 60 - Length (Msg) mod 80) mod 80;
    Write (Msg, StringOfChar (' ', I + 7));

    Stream.Position := Header.StartPos;
    Crc := Cardinal (-1);

    if Mode = pmNorm then
    try
      DstFile         := DstStrm;
      Header.StartPos := DstFile.Position;
    except
      DstFile := TNulWriter.Create;
    end else
      DstFile := TNulWriter.Create;
    
    if foMoved in Header.Flags then
    begin
      for I := 1 to Header.Size do
      begin
        Percentes.Tick;
        Stream.Read (Symbol, 1);
        UpdCrc32 (Crc, Symbol);
        DstFile.Write (Symbol, 1);
      end;
    end else
    begin
      SecondaryCodec.Start;
      for I := 1 to Header.Size do
      begin
        Percentes.Tick;
        Symbol := PPM.UpdateModel (0);
        UpdCrc32 (Crc, Symbol);
        DstFile.Write (Symbol, 1);
      end;
      SecondaryCodec.Flush;
    end;

    if Mode = pmNorm then TFileWriter (DstFile).Flush;

    Result := Header.Crc = Crc;
    if Result then Writeln (#8#8#8#8#8#8'Ok    ') else Writeln (#8#8#8#8#8#8'-- CRC Error');
  end;

end.

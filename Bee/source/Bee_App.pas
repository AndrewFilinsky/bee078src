unit Bee_App;

{ Contains:

  Bee archiver shell.

  (C) 2003-2005 Andrew Filinsky, Melchiorre Caruso

  Modifyed:

  v0.7.8 build 0150 - 2005/06/27 Melchiorre Caruso
  v0.7.8 build 0153 - 2005/07/08 by Andrew Filinsky
  v0.7.8 build 0154 - 2005/07/23 by Melchiorre Caruso
}

{$R-,Q-,S-}

interface

uses
  Windows,               // SetPriorityClass, GetCurrentProcess...
  SysUtils,              // faReadOnly, ...
  Math,                  // Max (), Min (), ...
  Classes,               // TStringList, ...

  Bee_Files,
  Bee_Headers,
  Bee_Configuration,     // TConfiguration, TTable
  Bee_Common,            // Various helper routines
  Bee_MainPacker;        // TEncoder...

type

  TBeeApp = class
  public
    constructor Create                  (const SelfName: string);
    destructor  Destroy;                override;
    procedure   DisplayUsage;
    function    Run: boolean;

  private
    function    OpenArchive (Headers: THeaders; Default: THeaderAction): boolean;

    procedure   ProcessOptions;
    procedure   ProcessFileMasks;

    procedure   ProcessFilesToFresh     (Headers: THeaders);                          // find and prepare sequences
    procedure   ProcessFilesToSwap      (Headers: THeaders);                          // decode solid sequences using a swapfile

    procedure   ProcessFilesToDelete    (Headers: THeaders);                          // find and prepare sequences
    procedure   ProcessFilesDeleted     (Headers: THeaders);

    procedure   ProcessFilesToDecode    (Headers: THeaders; Action : THeaderAction);  //
    procedure   ProcessFilesToExtract   (Headers: THeaders);                          //
    procedure   ProcessFilesToOverWrite (Headers: THeaders);                          //

    procedure   EncodeShell;
    procedure   DecodeShell  (Action: THeaderAction);
    procedure   RenameShell;
    procedure   DeleteShell;
    procedure   ListShell;

    function    MethodToStr  (P: THeader; Method, Dictionary: integer): string;
    function    SizeToStr    (Size: integer): string;
    function    RatioToStr   (PackedSize, Size: integer): string;
    function    AttrToStr    (Attr: integer): string;
    function    VersionToStr (VersionId: cardinal): string;

  private
    ArcFile:    TFileReader;
    ArcName:    string;                 // Archive Name
    SwapName:   string;                 // swap file name
    SwapFile:   TStream;

    CfgName:    string;
    Cfg:        TConfiguration;

    Command:    char;                   // Command
    cOption:    string;                 //
    eOption:    string;                 // forced file extension
    fOption:    boolean;
    pOption:    string;
    rOption:    boolean;
    sOption:    boolean;
    tOption:    boolean;
    uOption:    boolean;
    xOption:    TStringList;

    FileMasks:  TStringList;            // FileMasks
    Percentes:  TExecutionPercentes;    // global process percentage
  end;

implementation

/// TBeeApp...

  constructor TBeeApp.Create (const SelfName: string);
  begin
    Randomize;                                    /// Randomize, uses for unique filename generation...
    SetFileApisToOEM;
    Writeln (Cr, SelfName);                       /// Display header...

    ArcName       :=  '';
    ArcFile       := nil;
    SwapName      :=  '';
    SwapFile      := nil;

    CfgName       := SelfPath + 'bee.ini';
    Cfg           := TConfiguration.Create;

    Command       := ' ';
    cOption       :=  '';
    eOption       :=  '';                         /// forced file extension
    fOption       := False;
    pOption       :=  '';
    rOption       := False;
    sOption       := False;
    tOption       := False;
    uOption       := False;
    xOption       := TStringList.Create;

    FileMasks     := TStringList.Create;
    Percentes     := TExecutionPercentes.Create;  /// Create global percentes

    ProcessOptions;                               /// Process options
  end;

  destructor TBeeApp.Destroy;
  begin
    Cfg.Free;
    xOption.Free;
    FileMasks.Free;
    Percentes.Free;
  end;

  procedure TBeeApp.DisplayUsage;
  begin
    Writeln ('  Usage: Bee <Command> -<Option 1> -<Option N> <ArchiveName> <FileNames...>');
    Writeln (Cr + '  Commands:' + Cr);

    Writeln ('    a   Add files to archive');
    Writeln ('    d   Delete files from archive');
    Writeln ('    e   Extract files from archive');
    Writeln ('    x   eXtract files from archive with path name');
    Writeln ('    l   List archive');
    Writeln ('    t   Test archive files');
    Writeln ('    r   Rename files in archive');

    Writeln (Cr + '  Options:' + Cr);

    Writeln ('    r       Recurse subdirectories');
    Writeln ('    u       Update files to archive');
    Writeln ('    f       Freshen files to archive');
    Writeln ('    e       force file Extention');
    Writeln ('    s       create Solid archive');
    Writeln ('    m<0..3> set compression Method (0-store...1-default...3-maximal)');
    Writeln ('    d<1..9> set Dictionary size (d1 uses < 5M, d2 (default) < 10M, d3 < 20M...)' + CR);

    // Not aviable: Writeln ('    p       Set password');
    Writeln ('    x       eXclude filenames');
    Writeln ('    t       Test files after adding');
    Writeln ('    c<dir>  insert (with ''a'' cmd) or delete (with ''x'' cmd) part of file path');

    Writeln ('    pri<P>  set process Priority (0-Idle, 1-Normal, 2-High, 3-RealTime)');

    Writeln (Cr + '  Use BeeOpt to make most optimal parameters.');
    Writeln (Cr + '  Type "Bee | more" if You can not see whole usage.');
  end;

  function TBeeApp.Run;
  const
    SetOfCommands = ['A', 'D', 'E', 'L', 'R', 'T', 'X'];
  begin
    Result := ((Command in SetOfCommands) and (ArcName > '')) or (Command = '?');
    if Result then
      case Command of
        'A': EncodeShell;
        'D': DeleteShell;
        'E': DecodeShell (toExtract);
        'L': ListShell;
        'R': RenameShell;
        'T': DecodeShell (toTest);
        'X': DecodeShell (toExtract);
        '?': DisplayUsage;
      end;
  end;

  function TBeeApp.OpenArchive (Headers: THeaders; Default: THeaderAction): boolean;
  begin
    Result := True;
    if FileExists (ArcName) then
      try
        ArcFile := TFileReader.Create (ArcName, fmOpenRead + fmShareDenyWrite);
        Headers.ReadItems (ArcFile, Default);
      except
        Result := False;
      end;
  end;

  // Options processing;

  procedure  TBeeApp.ProcessOptions;
  var
    I: integer;
    S: string;
  begin
    // Catch -cfg
    for I := 1 to ParamCount do
    begin
      S := ParamToOEM (ParamStr (I));
      if Pos ('-CFG', UpperCase (S)) = 1 then CfgName := Copy (S, 5, MaxInt);
    end;

    // Default Configuration
    Cfg.Selector ('\main');
    Cfg.CurrentSection.Values ['Method']     := '1';
    Cfg.CurrentSection.Values ['Dictionary'] := '2';

    // Process configuration
    if FileExists (CfgName) then
      Cfg.LoadFromFile (CfgName)
    else
      Writeln ('Configuration file ', CfgName, ' not found, using default settings.' + Cr);

    // Catch options, command, archive name and name of files
    for I := 1 to ParamCount do
    begin
      S := ParamToOEM (ParamStr (I));
      if (Length (S) > 1) and (S [1] = '-') then
        // Options...
        case UpCase (S [2]) of
          'S': sOption := True;
          'U': uOption := True;
          'F': fOption := True;
          'T': tOption := True;
          'R': rOption := True;
          'P':
            begin
              Delete (S, 1, 2);
              pOption := S;
            end;
          'M':
            begin
              Delete (S, 1, 2);
              Cfg.Selector ('\main');
              Cfg.CurrentSection.Values ['Method'] := IntToStr (Max (0, Min (StrToInt (S), 3)));
            end;
          'D':
            begin
              Delete (S, 1, 2);
              Cfg.Selector ('\main');
              Cfg.CurrentSection.Values ['Dictionary'] := IntToStr (Max (0, Min (StrToInt (S), 9)));
            end;
          'E':
            begin
              Delete (S, 1, 2);
              if not (ExtractFileExt ('.' + S) = '.') then
                eOption := ExtractFileExt ('.' + S);
            end;
          'X':
            begin
              Delete (S, 1, 2);
              xOption.Add (S);
            end;
          'C':
            begin
              Delete (S, 1, 2);
              cOption := IncludeDelimiter (DeleteFileDrive (S));
            end;
          else
            if Pos ('-PRI', UpperCase (S)) = 1 then
            begin
              Delete (S, 1, 4);
              SetPriority (StrToInt (S));
            end;
        end
      else
        // Command or Filenames...
        if Command = ' ' then
        begin
          if Length (S) = 1 then
            Command := UpCase (S [1])
          else
            Command := '?';
        end else
          if ArcName = '' then
          begin
            ArcName := S;
            if ExtractFileExt (ArcName) = '' then
              ArcName := ChangeFileExt (ArcName, '.bee');
          end else
            FileMasks.Add (S);
    end; // end for Loop

    ProcessFileMasks;
  end;

  procedure TBeeApp.ProcessFileMasks;
  var
    I: integer;
  begin
    if rOption then
    begin
      for I := 0 to FileMasks.Count - 1 do
        if (not DirectoryExists (FileMasks [I])) and (not (Pos('*\', FileMasks [I]) = Length (ExtractFilePath (FileMasks [I])) - 1)) then
          FileMasks [I] := ExtractFilePath (FileMasks [I]) + '*\' + ExtractFileName (FileMasks [I]);

      for I := 0 to xOption.Count - 1 do
        if (not DirectoryExists (xOption [I])) and (not (Pos('*\', xOption [I]) = Length (ExtractFilePath (xOption [I])) - 1)) then
          xOption [I] := ExtractFilePath (xOption [I]) + '*\' + ExtractFileName (xOption [I]);
    end;
    if FileMasks.Count = 0 then FileMasks.Add ('*\*.*');
  end;

  // OvewWrite file processing;

  procedure TBeeApp.ProcessFilesToOverWrite;
  var
    I, J: integer;
    NewFileName: string;
  begin
    I := 0;
    while I < Headers.Count do
    begin
      if (THeader (Headers.Items [I]).Action = toExtract) and (FileExists (THeader (Headers.Items [I]).Name)) then
        case UpCase (Ask ('"' + THeader (Headers.Items [I]).Name + '" already exists.' + CR + 'Overwrite it?  Yes/No/Rename/All/Skip/Quit ', ['Y', 'y', 'N', 'n', 'R', 'r', 'A', 'a', 'S', 's', 'Q', 'q'])) of
          'A': Break;
          'N': THeader (Headers.Items [I]).Action := toNone;
          'R': begin
                 repeat
                   Write (msgRename + '"' + THeader (Headers.Items [I]).Name + '" as (enter to skip): ');
                   Readln (NewFileName);
                   Writeln;

                   NewFileName := DeleteFileDrive (NewFileName);
                   if (FileExists (NewFileName)) then
                     Writeln ('File "',NewFileName ,'" already exists!');

                 until (not FileExists (NewFileName));

                 if Length (NewFileName) > 0 then
                   THeader (Headers.Items [I]).Name := NewFileName
                 else
                   THeader (Headers.Items [I]).Action := toNone;
               end;
          'S': for J := I to Headers.Count -1 do
               begin
                 THeader (Headers.Items [J]).Action := toNone;
                 I := J;
               end;
          'Q': for J := 0 to Headers.Count -1 do
               begin
                 THeader (Headers.Items [J]).Action := toNone;
                 I := J;
               end;
        end;
      Inc (I);
    end;
  end;

  // Sequences processing;

  procedure TBeeApp.ProcessFilesToFresh;
  var
    I, J, BackTear, NextTear: integer;
  begin
    I := Headers.GetBack (Headers.Count - 1, toFresh);
    while I > -1 do                                                                            // Find sequences and mark as toSwap files that not toFresh
    begin
      BackTear := Headers.GetBack (I, foTear);
      NextTear := Headers.GetNext (I + 1, foTear);
      if NextTear = -1 then NextTear := Headers.Count;

      if ((NextTear - BackTear) > 1) then                                                      // If is solid header
      begin
        NextTear := Headers.GetBack (NextTear - 1, toCopy);
        for J := BackTear to NextTear do
          case THeader (Headers.Items [J]).Action of
            toCopy   : begin
                         THeader (Headers.Items [J]).Action := toSwap;
                         Inc (Percentes.GeneralSize, THeader (Headers.Items [J]).Size * 2);    // Decoding  and Encoding size
                       end;
            toFresh  : Inc (Percentes.GeneralSize, THeader (Headers.Items [J]).Size);          // Decoding size
          end;
        I := BackTear;
      end;
      I := Headers.GetBack (I - 1, toFresh);
    end;
    Inc (Percentes.GeneralSize, Headers.GetPackedSize (toCopy));
  end;

  procedure TBeeApp.ProcessFilesToDelete;
  var
    I, J, BackTear, NextTear: integer;
  begin
    I := Headers.GetBack (Headers.Count - 1, toDelete);
    while I > -1 do                                                                            // Find sequences and ...
    begin
      BackTear := Headers.GetBack (I, foTear);
      NextTear := Headers.GetNext (I + 1, foTear);
      if NextTear = -1 then NextTear := Headers.Count;

      if ((NextTear - BackTear) > 1) then                                                      // If is solid header
      begin
        NextTear := Headers.GetBack (NextTear - 1, toCopy);
        if Headers.GetBack (NextTear , toDelete) > (BackTear - 1) then                         // If exists an header toDelete
          for J := BackTear to NextTear do
            case THeader (Headers.Items [J]).Action of
              toCopy:   begin
                          THeader (Headers.Items [J]).Action := toSwap;
                          Inc (Percentes.GeneralSize, THeader (Headers.Items [J]).Size * 2);
                        end;
              toDelete: Inc (Percentes.GeneralSize, THeader (Headers.Items [J]).Size);
            end;
        I := BackTear;
      end;
      I := Headers.GetBack (I - 1, toDelete);
    end;
    Inc (Percentes.GeneralSize, Headers.GetPackedSize (toCopy));
  end;

  procedure TBeeApp.ProcessFilesToSwap;
    var
      I, J: integer;
      iMethod, iDictionary, iTable, iTear: integer;
      CurrMethod, CurrDictionary, CurrTable: integer;
      Decoder: TDecoder;
  begin
    I := Headers.GetBack (Headers.Count - 1, toSwap);
    if I > - 1 then
    begin
      SwapName := GenerateFileName ('');
      SwapFile := TFileWriter.Create (SwapName, fmCreate);

      CurrMethod     := Headers.Count - 1;
      CurrDictionary := Headers.Count - 1;
      CurrTable      := Headers.Count - 1;

      Decoder := TDecoder.Create (ArcFile, Percentes);                            // GeneralSize!
      while I > - 1 do
      begin
        iMethod     := Headers.GetBack (I, foMethod);                             // Find method info
        iDictionary := Headers.GetBack (I, foDictionary);                         // Find dictionary info
        iTable      := Headers.GetBack (I, foTable);                              // Find table info
        iTear       := Headers.GetBack (I, foTear);                               // Find tear info

        if (iMethod > - 1) and (iMethod < CurrMethod) and (iMethod < iTear) then
        begin
          CurrMethod := iMethod;
          Decoder.DecodeStrm (THeader (Headers.Items [iMethod]), pmQuit, SwapFile);
        end;

        if (iDictionary < CurrDictionary) and (iDictionary > CurrMethod) and (iDictionary < iTear) then
        begin
          CurrDictionary := iDictionary;
          Decoder.DecodeStrm (THeader (Headers.Items [iDictionary]), pmQuit, SwapFile);
        end;

        if (iTable < CurrTable) and (iTable > CurrDictionary) and (iTable < iTear) then
        begin
          CurrTable := iTable;
          Decoder.DecodeStrm (THeader (Headers.Items [iTable]), pmQuit, SwapFile);
        end;

        for J := iTear to I do
        begin
          if THeader (Headers.Items [J]).Action = toSwap then
            Decoder.DecodeStrm (Headers.Items [J], pmNorm, SwapFile)
          else
            Decoder.DecodeStrm (Headers.Items [J], pmSkip, SwapFile);
        end;

        I := Headers.GetBack (iTear - 1, toSwap);
      end;
      Decoder.Destroy;
      FreeAndNil (SwapFile);
    end;
  end;
                                                                                         
  procedure TBeeApp.ProcessFilesDeleted;
  var
    I: integer;
  begin
    with Headers do                                                            // Rescue header informatios
      for I := 0 to Count - 2 do
        if THeader (Items [I]).Action = toDelete then
        begin
          if (foVersion in THeader (Items [I]).Flags) and (not (foVersion in THeader (Items [I + 1]).Flags)) then
          begin
            Include (THeader (Items [I + 1]).Flags, foVersion);
            THeader (Items [I + 1]).Version := THeader (Items [I]).Version;
          end;

          if (foMethod in THeader (Items [I]).Flags) and (not (foMethod in THeader (Items [I + 1]).Flags)) then
          begin
            Include (THeader (Items [I + 1]).Flags, foMethod);
            THeader (Items [I + 1]).Method := THeader (Items [I]).Method;
          end;

          if (foDictionary in THeader (Items [I]).Flags) and (not (foDictionary in THeader (Items [I + 1]).Flags)) then
          begin
            Include (THeader (Items [I + 1]).Flags, foDictionary);
            THeader (Items [I + 1]).Dictionary := THeader (Items [I]).Dictionary;
          end;

          if (foTable in THeader (Items [I]).Flags) and (not (foTable in THeader (Items [I + 1]).Flags)) then
          begin
            Include (THeader (Items [I + 1]).Flags, foTable);
            THeader (Items [I + 1]).Table := THeader (Items [I]).Table;
          end;

          if (foTear in THeader (Items [I]).Flags) and (not (foTear in THeader (Items [I + 1]).Flags)) then
          begin
            Include (THeader (Items [I + 1]).Flags, foTear);
          end;
        end;
  end;

  procedure TBeeApp.ProcessFilesToDecode;
  var
    I, J: integer;
    Method, Dictionary,
    Table, Tear: integer;
  begin
    I := Headers.GetBack  (Headers.Count - 1, Action);                       // Last header
    while I > -1 do
    begin
      Method     := Headers.GetBack (I, foMethod);                           // Find method info
      Dictionary := Headers.GetBack (I, foDictionary);                       // Find dictionary info
      Table      := Headers.GetBack (I, foTable);                            // Find table info
      Tear       := Headers.GetBack (I, foTear);                             // Find tear info

      for J := Tear to (I - 1) do
        if THeader (Headers.Items [J]).Action in [toNone, toQuit] then       // in [toNone, toQuit] this is the patch
        begin
          THeader (Headers.Items [J]).Action := toSkip;
          Inc (Percentes.GeneralSize, THeader (Headers.Items [J]).Size);
        end;

      if (Method > -1)         and (THeader (Headers.Items [Method    ]).Action = toNone) then THeader (Headers.Items [Method    ]).Action := toQuit;
      if (Dictionary > Method) and (THeader (Headers.Items [Dictionary]).Action = toNone) then THeader (Headers.Items [Dictionary]).Action := toQuit;
      if (Table > Dictionary)  and (THeader (Headers.Items [Table     ]).Action = toNone) then THeader (Headers.Items [Table     ]).Action := toQuit;

      I := Headers.GetBack  (Tear - 1, Action); 
    end;
  end;

  procedure TBeeApp.ProcessFilesToExtract;
  var I: integer;
  begin
    if (CompareText (Command, 'E') = 0) or (not (Length (cOption) = 0)) then
      for I := 0 to Headers.Count - 1 do
        with THeader (Headers.Items [I]) do
          if Action = toExtract then
          begin
            if CompareText (Command, 'E') = 0 then
              Name := ExtractFileName (Name)
            else
              Name := DeleteText (cOption, Name);
          end;
  end;
  
  // Shell procedures;

  procedure TBeeApp.EncodeShell;
    var
      I: integer;
      Encoder: TEncoder;
      TmpFileName: string;
      TmpFile: TFileWriter;
      Headers: THeaders;
      Time: Double;
  begin
    Headers := THeaders.Create;

    Writeln (msgOpening, 'archive ', ArcName, Cr);
    if not OpenArchive (Headers, toCopy) then
      Abort ('Error: can''t open archive.');                                                        // Open Existing Archive

    Headers.cOption := cOption;
    Headers.fOption := fOption;
    Headers.uOption := uOption;
    Headers.xOption := xOption;

    Writeln (msgScanning, '...');
    for I := 0 to FileMasks.Count - 1 do
      Inc (Percentes.GeneralSize, Headers.AddNews (FileMasks [I]));                                 // Process FileMasks and xFileMasks

    if Headers.GetCount ([toUpdate, toFresh]) > 0 then                                              // Process Files
    begin
      Time        := Now;
      TmpFileName := GenerateFileName ('');
      TmpFile     := TFileWriter.Create (TmpFileName, fmCreate);

      ProcessFilesToFresh (Headers);                                                                // Find sequences and...
      ProcessFilesToSwap (Headers);                                                                 // Decode solid header modified in a swap file

      Headers.SortNews (Cfg, sOption,eOption);                                                      // Sort headers (only toUpdate headers)

      if not (SwapName = '') then                                                                   // if exists a modified solid sequence
        SwapFile := TFileReader.Create (SwapName, fmOpenRead + fmShareDenyWrite);                   // Open Swap file

      Headers.WriteItems (TmpFile);                                                                 // Write Headers
      Encoder := TEncoder.Create (TmpFile, Percentes);                                              // Global GeneralSize
      for I := 0 to Headers.Count - 1 do
        case THeader (Headers.Items [I]).Action of
          toCopy  : Encoder.CopyStrm   (Headers.Items [I], emNorm, ArcFile);
          toSwap  : Encoder.EncodeStrm (Headers.Items [I], emNorm, SwapFile);
          toFresh : Encoder.EncodeFile (Headers.Items [I], emNorm);
          toUpdate: Encoder.EncodeFile (Headers.Items [I], emNorm);
        end;
      Encoder.Destroy;
      Headers.WriteItems (TmpFile);                                                                 // Rewrite Headers

      Writeln;
      Writeln ('Archive size ', TmpFile.Size, ' bytes, ', TimeDifference (Time):1:2, ' seconds');

      if Assigned (SwapFile) then FreeAndNil (SwapFile);
      if Assigned (ArcFile) then FreeAndNil (ArcFile);
      FreeAndNil (TmpFile);

      DeleteFile (SwapName);
      DeleteFile (ArcName);
      if not RenameFile (TmpFileName, ArcName) then
      begin
        DeleteFile (TmpFileName);
        Abort ('Error: can''t rename TempFile to ' + ArcName);
      end;

      if tOption then
      begin
        Percentes.GeneralSize := 0;
        Percentes.RemainSize  := 0;

        Writeln;
        DecodeShell (toTest);
      end;
    end
    else
      Writeln ('Warning: no files to encode.');

    Headers.Free;
    if Assigned (ArcFile) then FreeAndNil (ArcFile);
  end;

  procedure TBeeApp.DecodeShell (Action: THeaderAction);
  var
    Decoder: TDecoder;
    I, errors: integer;
    Headers: THeaders;
  begin
    Errors  := 0;
    Headers := THeaders.Create;

    Writeln (msgOpening, 'archive ', ArcName, Cr);
    if not OpenArchive (Headers, toNone) then
      Abort ('Error: can''t open archive.');

    Writeln (msgScanning, '...');
    Headers.MarkItems (FileMasks, toNone, Action);
    Headers.MarkItems (xOption  , Action, toNone);

    if (Action = toExtract) then
    begin
      ProcessFilesToExtract (Headers);
      ProcessFilesToOverWrite (Headers);
    end;

    Percentes.GeneralSize := Headers.GetSize (Action);
    if not (Headers.GetNext (0, Action) = - 1) then                              // Action = toTest or toExtract
    begin
      ProcessFilesToDecode (Headers, Action);

      Decoder := TDecoder.Create (ArcFile, Percentes);                           // GeneralSize
      for I := 0 to Headers.Count - 1 do
         case THeader (Headers.Items [I]).Action of
           toExtract: if not Decoder.DecodeFile (Headers.Items [I], pmNorm) then Inc (Errors);
           toTest   : if not Decoder.DecodeFile (Headers.Items [I], pmTest) then Inc (Errors);
           toSkip   : if not Decoder.DecodeFile (Headers.Items [I], pmSkip) then Inc (Errors);
           toQuit   : if not Decoder.Decodefile (Headers.Items [I], pmQuit) then Inc (Errors);
         end;
      Decoder.Destroy;

      if Errors = 0 then
        Writeln (Cr + 'Everything went Ok')
      else
        Writeln ( Cr + 'Total errors: ', Errors, ' of ', Headers.GetCount ([Action, toSkip]));

    end
    else
      Writeln ('Warning: no files to decode.');

    if Assigned (ArcFile) then FreeAndNil (ArcFile);
    Headers.Free;
  end;

  procedure TBeeApp.DeleteShell;
  var
    TmpFileName: string;
    TmpFile: TFileWriter;
    I: integer;
    Time: double;
    Headers: THeaders;
    Encoder: TEncoder;
  begin
    Headers := THeaders.Create;

    Writeln (msgOpening, 'archive ', ArcName, Cr);
    if not OpenArchive (Headers, toCopy) then
      Abort('Error: can''t open archive.');

    Writeln (msgScanning, '...');
    Headers.MarkItems (FileMasks, toCopy, toDelete);
    Headers.MarkItems (xOption  , toDelete, toCopy);

    if not (Headers.GetNext (0, toDelete) = - 1) then
    begin
      Time        := Now;
      TmpFileName := GenerateFileName ('');
      TmpFile     := TFileWriter.Create (TmpFileName, fmCreate);

      ProcessFilesToDelete (Headers);                                                            // Find sequences
      ProcessFilesToSwap (Headers);
      ProcessFilesDeleted (Headers);                                                             // Rescue headers information

      if not (SwapName = '') then                                                                // if SwapSequences has found a modified sequence
        SwapFile := TFileReader.Create (SwapName, fmOpenRead + fmShareDenyWrite);                // Open Swap file

      Headers.WriteItems (TmpFile);                                                              // Write Headers
      Encoder := TEncoder.Create  (TmpFile, Percentes);                                          // GeneralSize
      for I := 0 to Headers.Count - 1 do
        case THeader (Headers.Items [I]).Action of
          toCopy  : Encoder.CopyStrm   (Headers.Items [I], emNorm, ArcFile);
          toSwap  : Encoder.EncodeStrm (Headers.Items [I], emNorm, SwapFile);
          toDelete: Writeln (msgDeleting + THeader (Headers.Items [I]).Name);
        end;
      Encoder.Destroy;
      Headers.WriteItems (TmpFile);

      Writeln;
      Writeln ('Archive size ', TmpFile.Size, ' bytes, ', TimeDifference (Time):1:2, ' seconds');

      if Assigned (SwapFile) then FreeAndNil (SwapFile);
      if Assigned (ArcFile) then FreeAndNil (ArcFile);
      FreeAndNil (TmpFile);

      DeleteFile (SwapName);
      DeleteFile (ArcName);
      if not RenameFile (TmpFileName, ArcName) then
        Abort ('Error: can''t rename TempFile to ' + ArcName);
    end else
      Writeln ('Warning: no files to delete.');

    if Assigned (ArcFile) then FreeAndNil (ArcFile);
    Headers.Free;
  end;
  
  procedure TBeeApp.ListShell;
  var
    Info: THeaders;
    P: THeader;
    I, TotalPacked, TotalSize,
    Version, Method, Dictionary,
    CountFiles, Tmp: integer;
    TmpStr: string;
  begin
    Info := THeaders.Create;

    Writeln (msgOpening, 'archive ', ArcName, Cr);
    if not OpenArchive (Info, toNone) then
      Abort ('Error: can''t opening archive.')
    else
      if Assigned (ArcFile) then FreeAndNil (ArcFile);

    Writeln (msgScanning, '...');
    Info.MarkItems (FileMasks, toNone, toList);
    Info.MarkItems (xOption  , toList, toNone);

    if not (Info.GetNext (0, toList) = -1) then
    begin
      TotalSize   :=  0;
      TotalPacked :=  0;
      Version     := -1;
      Method      := -1;
      Dictionary  := -1;
      CountFiles  :=  0;
      Writeln ('Name                        Size Packed Ratio    Date  Time   Attr     CRC Meth');
      Writeln (StringOfChar ('-', 79));

      for I := 0 to Info.Count - 1 do
        if THeader (Info.Items [I]).Action = toList then
        begin
          P := Info.Items [I];

          if foVersion    in P.Flags then Version    := P.Version;
          if foMethod     in P.Flags then Method     := P.Method;
          if foDictionary in P.Flags then Dictionary := P.Dictionary;

          Tmp := 80 + 25 - Length (P.Name) mod 80;
          if Tmp >= 80 then Dec (Tmp, 80);
          Write (P.Name, '':Tmp);

          Write (Format (' %6s %6s %4s %14s %6s %8.8x %3s' + Cr, [
            SizeToStr   (P.Size                     ),
            SizeToStr   (P.PackedSize               ),
            RatioToStr  (P.PackedSize, P.Size       ),
            DateTime    (FileDateToDateTime (P.Time)),
            AttrToStr   (P.Attr                     ),
            P.Crc,
            MethodToStr (P, Method, Dictionary)])   );

          Inc (TotalSize  , P.Size      );
          Inc (TotalPacked, P.PackedSize);
          Inc (CountFiles);
        end;

      Writeln (StringOfChar ('-', 79));
      TmpStr := Format ('%d files', [CountFiles]);
      Write (TmpStr, '':25 - Length (TmpStr));
      Write (Format (' %6s %6s %4s' + Cr, [SizeToStr (TotalSize), SizeToStr (TotalPacked), RatioToStr (TotalPacked, TotalSize)]));
    end else
      Writeln ('Warning: no files to list.');

    Info.Free;
  end;

  procedure TBeeApp.RenameShell;
  var
    TmpFileName: string;
    NewFileName: string;
    TmpFile: TFileWriter;
    I: integer;
    Time: double;
    Headers: THeaders;
    Encoder: TEncoder;
  begin
    Headers := THeaders.Create;

    Writeln (msgOpening, 'archive ', ArcName, Cr);
    if not OpenArchive (Headers, toCopy) then
      Abort('Error: can''t opening archive.');

    Writeln (msgScanning, '...');
    Headers.MarkItems (FileMasks, toCopy, toRename);
    Headers.MarkItems (xOption  , toRename, toCopy);

    Percentes.GeneralSize := Headers.GetPackedSize ([toCopy, toRename]);

    if not (Headers.GetNext (0, toRename) = - 1) then
    begin
      Time        := Now;
      TmpFileName := GenerateFileName ('');
      TmpFile     := TFileWriter.Create (TmpFileName, fmCreate);

      for I := 0 to Headers.Count - 1 do
      begin
        if (THeader (Headers.Items [I]).Action = toRename) then
        begin
          repeat
            Write (msgRename + '"' + THeader (Headers.Items [I]).Name + '" as (empty to skip): ');
            Readln (NewFileName);
            Writeln;

            NewFileName := DeleteFileDrive (NewFileName);
            if not (Headers.GetPointer (NewFileName, [toNone, toRename]) = nil) then
              Writeln ('File "',NewFileName ,'" already existing in archive!');

          until Headers.GetPointer (NewFileName, [toNone, toRename]) = nil;

          if Length (NewFileName) > 0 then
            THeader (Headers.Items [I]).Name := NewFileName;
        end;
      end;

      Headers.WriteItems (TmpFile);
      Encoder := TEncoder.Create (TmpFile, Percentes);
      for I := 0 to Headers.Count - 1 do
        Encoder.CopyStrm (Headers.Items [I], emNorm, ArcFile);
      Encoder.Destroy;
      Headers.WriteItems (TmpFile);

      Writeln;
      Writeln ('Archive size ', TmpFile.Size, ' bytes, ', TimeDifference (Time):1:2, ' seconds');
      FreeAndNil (TmpFile);

      if Assigned (ArcFile) then FreeAndNil (ArcFile);

      DeleteFile (ArcName);
      if not RenameFile (TmpFileName, ArcName) then
        Abort ('Error: can''t rename TempFile to ' + ArcName);
    end else
      Writeln ('Warning: no files to rename.');

    if Assigned (ArcFile) then FreeAndNil (ArcFile);
    Headers.Free;
  end;

  // String function;

  function TBeeApp.SizeToStr (Size: integer): string;
  begin
    if Size < 999999 then
      Result := Format ('%u', [Size])
    else
    if Size < 99999999 then
      Result := Format ('%uk', [Size div 1000])
    else
      Result := Format ('%uM', [Size div 1000000]);
  end;

  function TBeeApp.RatioToStr (PackedSize, Size: integer): string;
  begin
    Result := Format ('%3.0f%%', [PackedSize / Max (1, Size) * 100]);
  end;

  function TBeeApp.AttrToStr (Attr: integer): string;
  begin
    Result := '..RHSA';
    if Attr and faReadOnly = 0 then Result [3] := '.';
    if Attr and faHidden   = 0 then Result [4] := '.';
    if Attr and faSysFile  = 0 then Result [5] := '.';
    if Attr and faArchive  = 0 then Result [6] := '.';
  end;

  function TBeeApp.MethodToStr (P: THeader; Method, Dictionary: integer): string;
  begin
    Result := 'm0a';
    if not (foTear in P.Flags) then Result [1] := 's';
    if not (foMoved in P.Flags) then if Method in [1..3] then Result [2] := char (byte ('0') + Method) else Result [3] := '?';
    if Dictionary in [1..9] then Result [3] := char (byte ('a') - 1 + Dictionary) else Result [4] := '?';
  end;

  function TBeeApp.VersionToStr (VersionId: cardinal): string;
  begin
    case VersionId of
      0: Result := ' 0.2';
      1: Result := ' 0.3';
      else Result := ' ?.?';
    end;
  end;

end.


{ Implements Genetic optimization for make optimal parameters
  for Bee 0.7.7.
}
{$R-,Q-,S-}

unit BeeOpt_Form;

interface

uses
  Windows, Messages, SysUtils, Classes, Forms, RXShell, ComCtrls, StdCtrls, Controls,
  Math,               // Max (), Min (), ...
  Bee_Configuration,
  Bee_Common,
  Bee_Files,
  Bee_Headers,
  Bee_Codec,          // TSecondaryEncoder, TSecondaryDecoder...
  Bee_Modeller;       // TBaseCoder...

const
  CrossoverProbability = 0.15; /// Вероятность кроссовера
  MutationProbability  = 0.01; /// Вероятность мутации
  DefaultCfgName = 'Bee.ini';  /// Стандартное имя файла конфигурации

type

  /// Особь (в смысле генетического алгоритма)

  TPerson = class (TObject)
    Genome: TTableParameters;  /// Геном особи
    Cost: integer;             /// Качество особи

    constructor Create; overload;
    constructor Create (Parent1, Parent2: TPerson); overload;
    constructor Create (Stream: TStream); overload;
    procedure   Save (Stream: TStream);
    procedure   MarkToRecalculate;        /// Отметить особь как не оцененую
    procedure   ConvertIn;
    procedure   ConvertOut;
    function    IsEqual (Person: TPerson): boolean;
  end;

  /// Популяция особей (в смысле генетического алгоритма), определяющих параметры определенного уровня сжатия

  TPopulation = class (TList)
    constructor Create; overload;                   /// Создать пустую популяцию
    constructor Create (Stream: TStream); overload; /// Прочитать популяцию из потока
    destructor  Destroy; override;        /// Уничтожить популяцию вместе с содержимым
    procedure   Save (Stream: TStream);
    procedure   Add (P: TPerson);         /// Добавить особь, не нарушая упорядоченность
    procedure   MarkToRecalculate;        /// Отметить все особи как не оцененые
    function    HasPerson (Person: TPerson): boolean;
  end;

  /// Множество популяций (в смысле генетического алгоритма), каждая из которых определяет параметры определенного уровня сжатия

  TPopulations = class (TList)
    CurrentPopulation: integer;           /// Номер текущей популяции
    CurrentAge: integer;                  /// Номер текущего годе
    Improvements: integer;                /// Количество улучшенных особей

    constructor Create; overload;                    /// Создать набор пустых популяций
    constructor Create (const FileName: string); overload; /// Прочитать набор популяций
    procedure   Save (const FileName: string);  /// Записать набор популяций
    procedure   Live;                     /// Имитировать размножение одной из особей одной из популяций
    procedure   MarkToRecalculate;        /// Отметить все особи всех популяций как не оцененые
    destructor  Destroy; override;        /// Уничтожить набор популяций вместе с содержимым
  end;

  /// Тело сжимаемого файла

  TBody = class
    Data: Pointer;  /// Данные
    Size: integer;  /// Размер данных

    constructor Create (const aFileName: string);
    destructor  Destroy; override;
  end;

  /// Окружение мира, в котором происходит эволюция

  TApp = class
    constructor Create;
    procedure   Evolution; /// Запустить эволюцию
    destructor  Destroy; override;

    procedure   ExtractLevels (World: TPopulations; const Ext: string);
    procedure   CollectWorlds (const Path: string);
    procedure   CollectConfigurations (CfgName: string);
    /// Собрать рекурсивно несколько dat файлов в один ...
    procedure   MergeDataRecursively (const Path, Name: string; World: TPopulations);
    procedure   DrawLevelProgress;

  public
    SrcName: string;       /// Имя обрабатываемого каталога
    Cfg: TConfiguration;   /// Параметры конфигурации
    World: TPopulations;   /// Мир, набор популяций

    Headers: THeaders;     /// Список файлов
    Bodyes: TList;         /// Содержимое файлов
    SamplesSize: integer;  /// Размер выборки файлов

    Encoder: TBaseCoder;   /// Упаковщик
    SecondaryCodec: TSecondaryCodec;   /// Допаковщик
    Nowhere: TNulWriter;   /// Выходной поток упаковщика

    Priority: Cardinal;    /// Выбранный приоритет задачи оптимизации

  private
    ConfigurationName: string;

  private
    procedure   ReduceSection (Section: TConfigSection); /// Reduce unneeded strings from given Section of Bee.Ini
  end;

  TMainForm = class (TForm)
    RxTrayIcon1: TRxTrayIcon;
    PageControl: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet3: TTabSheet;
    Label_Extension: TLabel;
    Label_ExtensionValue: TLabel;
    Label_variantsEstimated: TLabel;
    Label_variantsEstimatedValue: TLabel;
    Label_PercentOfImprovements: TLabel;
    Label_PercentOfImprovementsValue: TLabel;
    Label_LevelValue: TLabel;
    StatusBar: TStatusBar;
    Label_About: TLabel;
    Label_SampleSize: TLabel;
    Label_SampleSizeValue: TLabel;
    Label_PackedSize: TLabel;
    Label_PackedSizeValue: TLabel;
    Label_DictionaryLevel: TLabel;
    Label_DictionaryLevelValue: TLabel;

    procedure RxTrayIcon1Click (Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
    procedure FormCreate (Sender: TObject);
    procedure FormClose (Sender: TObject; var Action: TCloseAction);
    procedure FormDestroy (Sender: TObject);

  private
    { Private declarations }
    NeedToRecalculate,        /// Нужно вычислить оценки особей заново?
    NeedToCollectConfig,      /// Is it need to collect configurations to Bee.ini?
    NeedToReduceIni,          /// Is it need to reduce Bee.ini?
    NeedToMerge,              /// Нужно собрать рекурсивно все ".dat" файлы в один.
    NeedToClose,              /// Нужно прекратить расчет и закончить работу программы?
    NeedToRun: Boolean;       /// Нужно начать расчет?

    NeedToHide: Boolean;      /// Нужно спрятать приложение?

    procedure ApplicationMinimize (Sender: TObject);
    procedure ApplicationRestore (Sender: TObject);

  public
    { Public declarations }
    App: TApp;
  end;

var
  MainForm: TMainForm;

// Реализация
// ------------------------------------------------------------------------

implementation

  /// TPerson

  constructor TPerson.Create;
  var
    I: integer;
  begin
    /// Построить геном случайным образом
    for I := 1 to SizeOf (Genome) do Genome [I] := Random (256);
    /// Качество еще не оценено
    Cost := 0;
  end;

  constructor TPerson.Create (Parent1, Parent2: TPerson);
  var
    Parents: array [0..1] of TPerson; // Массив предков, для удобства выбора
    ParentIndex: integer;             // Текущий номер предка
    I, J: integer;                    // Текущий номер хромосомы и гена в хромосоме
  begin
    /// Сконвертировать в форму для смешивания...
    Parent1.ConvertIn;
    Parent2.ConvertIn;
    /// Приготовиться к смешиванию...
    Parents [0] := Parent1;
    Parents [1] := Parent2;
    ParentIndex := Random (2);
    /// Формируем новый геном
    for I := 2 to SizeOf (Genome) do begin
      /// Меняем предка с некоторой вероятностью
      if Random < CrossoverProbability then ParentIndex := ParentIndex xor 1;
      Genome [I] := Parents [ParentIndex].Genome [I];
      /// Гены мутируют с некоторой вероятностью
      for J := 0 to 7 do
        if Random < MutationProbability then Genome [I] := Genome [I] xor (1 shl J);
    end;
    /// Качество еще не оценено
    Cost := 0;
    /// Сконвертировать из формы для смешивания...
    Parent1.ConvertOut;
    Parent2.ConvertOut;
    ConvertOut;
  end;

  constructor TPerson.Create (Stream: TStream);
  begin
    Stream.ReadBuffer (Genome, SizeOf (Genome));
    Stream.ReadBuffer (Cost, SizeOf (Cost));
  end;

  procedure   TPerson.Save (Stream: TStream);
  begin
    Stream.WriteBuffer (Genome, SizeOf (Genome));
    Stream.WriteBuffer (Cost, SizeOf (Cost));
  end;

  procedure   TPerson.MarkToRecalculate;
  begin
    Cost := 0;
  end;

  procedure  TPerson.ConvertIn;
  var
    Temp: TTableParameters;
    I: integer;
  begin
    Temp := Genome;
    for I := 1 to SizeOf (Genome) div 2 do begin
      Genome [I * 2] := Temp [1 + I];
      Genome [I * 2 + 1] := Temp [1 + I + SizeOf (Genome) div 2];
    end;
  end;

  procedure  TPerson.ConvertOut;
  var
    Temp: TTableParameters;
    I: integer;
  begin
    Temp := Genome;
    for I := 1 to SizeOf (Genome) div 2 do begin
      Genome [1 + I] := Temp [I * 2];
      Genome [1 + I + SizeOf (Genome) div 2] := Temp [I * 2 + 1];
    end;
  end;

  function  TPerson.IsEqual (Person: TPerson): boolean;
  var
    I: integer;
  begin
    Result := false;
    for I := 2 to SizeOf (Genome) do
      if Genome [I] <> Person.Genome [I] then exit;
    Result := true;
  end;

  /// TPopulation

  constructor TPopulation.Create;
  begin
    Inherited;
  end;

  constructor TPopulation.Create (Stream: TStream);
    var
      NewCount: integer;
  begin
    Inherited Create;
    /// Прочитать численность новой популяции
    Stream.ReadBuffer (NewCount, SizeOf (NewCount));
    /// Прочитать особи новой популяции
    while Count < NewCount do
      Add (TPerson.Create (Stream));
  end;

  procedure   TPopulation.Save (Stream: TStream);
  var
    I: integer;
  begin
    /// Записать численность популяции
    Stream.WriteBuffer (Count, SizeOf (Count));
    /// Записать особи популяции
    for I := 0 to Count - 1 do TPerson (List [I]).Save (Stream);
  end;

  procedure   TPopulation.Add (P: TPerson);
  var
    I: integer;
  begin
    I := 0; while (I < Count) and (TPerson (List [I]).Cost < P.Cost) do Inc (I);
    Insert (I, P);
  end;

  procedure   TPopulation.MarkToRecalculate;
  begin
    while Count > 1 do TPerson (Extract (Last)).Free;
    if Count > 0 then TPerson (First).MarkToRecalculate;
  end;

  destructor  TPopulation.Destroy;
  begin
    while Count > 0 do TPerson (Extract (First)).Free;
    Inherited;
  end;

  function  TPopulation.HasPerson (Person: TPerson): boolean;
  var
    I: integer;
  begin
    Result := true;
    for I := 0 to Count - 1 do
      if Person.IsEqual (TPerson (List [I])) then exit;
    Result := false;
  end;

  /// TPopulations

  constructor TPopulations.Create;
  begin
    Inherited;
    CurrentPopulation := 0;
    CurrentAge := 0;
    Improvements := 0;
    while Count < 15 do Add (TPopulation.Create);
  end;

  constructor TPopulations.Create (const FileName: string);
  var
    Stream: TFileReader;       /// Поток для чтения состояния мира
  begin
    Inherited Create;
    /// Поток не создан
    Stream := Nil;
    /// Создать поток
    if FileExists (FileName + '.Err') then Stream := TFileReader.Create (FileName + '.Err', fmOpenRead) else
    if FileExists (FileName) then Stream := TFileReader.Create (FileName, fmOpenRead);
    /// Поток создан?
    if Stream <> Nil then begin
      /// Прочитать мир из потока
      Stream.ReadBuffer (CurrentPopulation, SizeOf (CurrentPopulation));
      Stream.ReadBuffer (CurrentAge, SizeOf (CurrentAge));
      Stream.ReadBuffer (Improvements, SizeOf (Improvements));
      while Count < 15 do Add (TPopulation.Create (Stream));
      /// Закрыть поток
      Stream.Free;
    end else begin
      CurrentPopulation := 0;
      CurrentAge := 0;
      Improvements := 0;
      while Count < 15 do Add (TPopulation.Create);
    end;
  end;

  procedure   TPopulations.Save (const FileName: string);
  var
    Stream: TFileWriter;       /// Поток для записи состояния мира
    I: integer;                /// Номер популяции
  begin
    RenameFile (FileName, FileName + '.Err');
    DeleteFile (FileName);
    /// Создать новый файл для сохранения состояния мира
    /// Сохранить состояние мира
    Stream := TFileWriter.Create (FileName, fmCreate);
    Stream.WriteBuffer (CurrentPopulation, SizeOf (CurrentPopulation));
    Stream.WriteBuffer (CurrentAge, SizeOf (CurrentAge));
    Stream.WriteBuffer (Improvements, SizeOf (Improvements));
    for I := 0 to Count - 1 do
      TPopulation (List [I]).Save (Stream);
    Stream.Free;
    /// Удалить резервную копию файла
    DeleteFile (FileName + '.Err');
  end;

  procedure  TPopulations.Live;
  var
    FullSize,                 /// Размер популяции
    HalfSize: integer;        /// Размер половины популяции
    Population1,              /// Основная популяция...
    Population2: TPopulation;  /// Соседняя популяция...
    Parent1,                  /// Перый родитель
    Parent2,                  /// Второй родитель
    Person: TPerson;          /// Новая особь
  var
    DictionaryLevel: integer;
    I, Start, Finish: integer;
    Pi: ^Byte;
  begin
    /// Вычислить размер популяции
    FullSize := 1;
    HalfSize := 1;

    /// Переоценка нужна?
    if CurrentAge mod 2000 = 0 then begin
      /// Выполнить переоценку ...
      for I := 0 to Count - 1 do TPopulation (List [I]).MarkToRecalculate;
      /// Потратить один год ...
      Inc (CurrentAge);
    end;

    /// Получить доступ к текущей популяции
    Population1 := List [CurrentPopulation];

    if Population1.Count = 0 then begin /// Популяция пуста?
      /// Построить новую особь случайным образом...
      Person := TPerson.Create;
      MainForm.StatusBar.Panels.Items [0].Text := 'Generate random creature...';
    end else if TPerson (Population1.First).Cost = 0 then begin /// Первая особь популяции не оценена?
      /// Изъять первую особь из популяции...
      Person := Population1.Extract (Population1.First);
      MainForm.StatusBar.Panels.Items [0].Text := 'Recalculate creature estimation...';
    end else begin
      repeat
        /// Выбрать популяцию второго родителя
        repeat
          Population2 :=
            List [Max (0, Min (CurrentPopulation + Random (3) - 1, Count - 1))];
        until Population2.Count > 0;
        /// Выбрать первого родителя
        Parent1 := Population1.List [Random (Population1.Count)];
        /// Выбрать второго родителя
        Parent2 := Population2.List [Random (Population2.Count)];
      until Parent1 <> Parent2;
      /// Построить новую особь, взяв за образец генотипы родителей
      repeat
        Person := TPerson.Create (Parent1, Parent2);
        if Population1.HasPerson (Person) then FreeAndNil (Person);
      until Person <> nil;
      MainForm.StatusBar.Panels.Items [0].Text := 'Creatures optimization...';
    end;

    /// Оценить особь
    begin
      /// Перевести номер популяции в уровень сжатия
      Person.Genome [1] := CurrentPopulation + 1;
      /// Передать геном кодировщику
      MainForm.App.Encoder.SetTable (Person.Genome);
      /// Установить размер словаря для кодировщика
      DictionaryLevel := CurrentAge div 2000 + 1;
      MainForm.App.Encoder.SetDictionary (DictionaryLevel);
      MainForm.Label_DictionaryLevelValue.Caption := Format ('%d (~%d Mb)', [DictionaryLevel, (1 shl (17 + Min (Max (0, DictionaryLevel), 9))) * 20 shr 20]);
      /// Очистить выходной поток
      MainForm.App.Nowhere.Position := 0;
      /// Очистить допаковщик
      MainForm.App.SecondaryCodec.Start;
      /// Закодировать список блоков
      for I := 0 to MainForm.App.Bodyes.Count - 1 do begin
        MainForm.App.Encoder.FreshFlexible;

        Start := 0;
        Pi := TBody (MainForm.App.Bodyes [I]).Data;
        while Start < TBody (MainForm.App.Bodyes [I]).Size do begin
          Finish := Min (Start + 1024, TBody (MainForm.App.Bodyes [I]).Size);
          while Start < Finish do begin
            MainForm.App.Encoder.UpdateModel (Pi^);
            Inc (Pi);
            Inc (Start);
          end;

          Application.ProcessMessages;
          if MainForm.NeedToClose = True then Break;
        end;
        if MainForm.NeedToClose = True then Break;
      end;

      /// Сбросить буфер допаковщика
      MainForm.App.SecondaryCodec.Flush;
      /// Аннулировать результат упаковки и выйти, если прервано...
      if MainForm.NeedToClose = True then begin
        /// Добавить (неоцененную) особь в популяцию ...
        Population1.Add (Person);
        /// Выйти ...
        Exit;
      end else begin
        /// Запомнить результат упаковки ...
        Person.Cost := MainForm.App.Nowhere.Position;
      end;
    end;

    /// Расчитать статистику и Изменить текущую популяцию ...
    begin
      if Population1.Count > 0 then begin
        /// Расчитать возраст мира ...
        if TPerson (Population1.First).Cost > 0 then Inc (CurrentAge);
        /// Расчитать процент усовершенствований ...
        if TPerson (Population1.First).Cost > Person.Cost then Inc (Improvements);
      end;
      /// Добавить особь в популяцию ...
      Population1.Add (Person);

      /// Популяция полна & Все особи популяции оценены?
      if (Population1.Count > FullSize) and (TPerson (Population1.First).Cost > 0) then
        /// Популяция полна. Уничтожить половину самых слабых ...
        while Population1.Count > HalfSize do TPerson (Population1.Extract (Population1.Last)).Free;
    end;

    /// Вывести отчет о популяции...
    WriteText (MainForm.App.SrcName + '.log.txt', Format ('%d' + #9, [TPerson (Population1.First).Cost]));
    /// Вывести отчет обо всех популяциях...
    if CurrentPopulation = 14 then
      WriteText (MainForm.App.SrcName + '.log.txt', Format ('| %5d turn, -d%d, %d jumps (%1.1f%%).' + Cr, [CurrentAge, DictionaryLevel, Improvements, Improvements / (CurrentAge + 1) * 100]));
    /// Перейти к следующей популяции
    CurrentPopulation := (CurrentPopulation + 1) mod 15;
  end;

  procedure   TPopulations.MarkToRecalculate;
  var
    I: integer;
  begin
    for I := 0 to Count - 1 do TPopulation (List [I]).MarkToRecalculate;
    CurrentPopulation := 0;
    CurrentAge := 0;
    Improvements := 0;
  end;

  destructor  TPopulations.Destroy;
  begin
    while Count > 0 do TPopulation (Extract (First)).Free;
    Inherited;
  end;

  /// Окружение мира, в котором происходит эволюция

  constructor TApp.Create;
  var
    I: integer;
    S: string;
  begin
    Inherited Create;
    SetFileApisToOEM;
    Randomize;

    /// Создать пустой мир
    World := TPopulations.Create;
    /// Имя каталога по умолчанию не выбрано
    SrcName := '';
    /// Создать пустую конфигурацию
    Cfg := TConfiguration.Create;
    /// Наполнить конфигурацию значениями по умолчанию
    Cfg.Selector ('\main');
    Cfg.CurrentSection.Values ['Method']     := '3';
    Cfg.CurrentSection.Values ['Dictionary'] := '5';

    /// Дефолтный приоритет = 0

    Priority := 0;

    /// Разобрать параметры командной строки
    for I := 1 to ParamCount do begin
      S := UpperCase (ParamStr (I));
      /// Задан режим переоценки особей?
      if Pos ('-RECALCULATE', S) = 1 then begin
        MainForm.NeedToRecalculate := True;
      end Else
      /// Задано собрать несколько .dat файлов в один?
      if Pos ('-REDUCE', S) = 1 then begin
        MainForm.NeedToReduceIni := True;
      end Else
      /// Задано собрать несколько .dat файлов в один?
      if Pos ('-MERGE', S) = 1 then begin
        MainForm.NeedToMerge := True;
      end Else
      /// Задано спрятать приложение?
      if Pos ('-HIDE', S) = 1 then begin
        MainForm.NeedToHide := True;
      end Else
      /// Задан уровень сжатия?
      if Pos ('-M', S) = 1 then begin
        Delete (S, 1, 2);
        Cfg.Selector ('\main');
        Cfg.CurrentSection.Values ['Method'] := IntToStr (Max (1, Min (StrToInt (S), 3)));
      end Else
      /// Задан размер словаря?
      if Pos ('-D', S) = 1 then begin
        Delete (S, 1, 2);
        Cfg.Selector ('\main');
        Cfg.CurrentSection.Values ['Dictionary'] := IntToStr (Max (0, Min (StrToInt (S), 9)));
      end Else
      /// Задана сборка файла конфигурации?
      if Pos ('-C', S) = 1 then begin
        ConfigurationName := Copy (ParamStr (I), 3, MaxInt);
        MainForm.NeedToCollectConfig := True;
        MainForm.NeedToRun := False;
      end Else
      /// Задан приоритет?
      if Pos ('-PRI', S) = 1 then begin
        Priority := StrToInt (Copy (ParamStr (I), 5, MaxInt));
      end Else
      /// Какой-то другой параметр?
      if S [1] in ['-', '/'] then begin
        /// Nothing
      end Else
      /// Имя каталога еще не определено?
      if SrcName = '' then begin
        SrcName := ParamStr (I);
        MainForm.Label_ExtensionValue.Caption := '<' + SrcName + '>';
      end;
    end;

    Headers     := THeaders.Create;
    Bodyes      := TList.Create;
    SamplesSize := 0;

    if SrcName <> '' then begin
      /// Просканировать указанный каталог
      Headers.ScanFileNames (SrcName, False {not Recursive});
      Headers.Sort (Cfg, False {not Solid});
      /// Прочитать все блоки данных
      for I := 0 to Headers.Count - 1 do begin
        Bodyes.Add (TBody.Create (THeader (Headers [I]).Name));
        SamplesSize := SamplesSize + TBody (Bodyes [I]).Size;
      end;
    end;

    Nowhere := TNulWriter.Create;
    SecondaryCodec := TSecondaryEncoder.Create (Nowhere);
    Encoder := TBaseCoder.Create (SecondaryCodec);

    MainForm.Label_SampleSizeValue.Caption := Format ('%d', [SamplesSize]);

    /// Свернуть приложение

    MainForm.ApplicationMinimize (Nil);
  end;

  destructor  TApp.Destroy;
  begin
    World.Free;
    Cfg.Free;
    Headers.Free;
    while Bodyes.Count > 0 do begin TBody (Bodyes.First).Free; Bodyes.Delete (0); end;
    Bodyes.Free;
    Encoder.Free;
    SecondaryCodec.Free;
    Nowhere.Free;
    Inherited;
  end;

  procedure  TApp.ExtractLevels (World: TPopulations; const Ext: string);
  var
    Levels: TList;
    I: integer;
  begin
    Levels := TList.Create;

    /// Собрать лучших представителей популяций
    WriteText ('Collect.txt', Cr + Ext + ':' + Cr);
    for I := 0 to World.Count - 1 do begin
      if TPopulation (World.List [I]).Count = 0 then Continue;
      WriteText ('Collect.txt', Format ('%d:', [TPerson (TPopulation (World.List [I]).First).Genome [1]]) + #9 + Format ('%d', [TPerson (TPopulation (World.List [I]).First).Cost]));
      if TPerson (TPopulation (World.List [I]).First).Genome [1] < 3 then begin
        WriteText ('Collect.txt', Cr);
        Continue;
      end else if (Levels.Count > 0) and (TPerson (TPopulation (World.List [I]).First).Cost > TPerson (Levels.Last).Cost) then begin
        WriteText ('Collect.txt', Cr);
        Continue;
      end else begin
        WriteText ('Collect.txt', ' +' + Cr);
        Levels.Add (TPopulation (World.List [I]).First);
      end;
    end;

    /// Добавить в конфигурацию представителей для трех степеней сжатия
    if Levels.Count > 0 then begin
      Cfg.Selector ('\m1');
      Cfg.CurrentSection.Values [Ext + '.Size'] := IntToStr (TPerson (Levels.First).Cost);
      Cfg.PutData (Ext, TPerson (Levels.First).Genome, SizeOf (TPerson (Levels.First).Genome));
      Cfg.Selector ('\m2');
      Cfg.CurrentSection.Values [Ext + '.Size'] := IntToStr (TPerson (Levels.List [Levels.Count div 2]).Cost);
      Cfg.PutData (Ext, TPerson (Levels.List [Levels.Count div 2]).Genome, SizeOf (TPerson (Levels.First).Genome));
      Cfg.Selector ('\m3');
      Cfg.CurrentSection.Values [Ext + '.Size'] := IntToStr (TPerson (Levels.Last).Cost);
      Cfg.PutData (Ext, TPerson (Levels.Last).Genome, SizeOf (TPerson (Levels.First).Genome));
    end;
  end;

  procedure  TApp.CollectWorlds (const Path: string);
  var
    World: TPopulations;
    T: TSearchRec;
  begin
    /// Найти в заданном каталоге миры и добавить их параметры в файл конфигурации
    if FindFirst (Path + '*.dat', faAnyFile - faDirectory, T) = 0 then
      repeat
        if (T.Name <> '.') and (T.Name <> '..') then begin
          World := TPopulations.Create (Path + T.Name);
          ExtractLevels (World, '.' + ChangeFileExt (ExtractFileName (T.Name), ''));
          World.Free;
        end;
      until FindNext (T) <> 0;
    FindClose (T);

    /// Найти подкаталоги и вызвать их рекурсивную обработку
    if FindFirst (Path + '*.*', faDirectory, T) = 0 then
      repeat
        if (T.Name <> '.') and (T.Name <> '..') then CollectWorlds (Path + T.Name + '\');
      until FindNext (T) <> 0;
    FindClose (T);
  end;

  procedure  TApp.CollectConfigurations (CfgName: string);
  begin
    /// Задать стандартное имя файла конфигурации, если имя файла не указано
    if CfgName = '' then CfgName := DefaultCfgName;
    /// Добавить к имени стандартное расширение, если расширение не указано явно
    if ExtractFileExt (CfgName) = '' then CfgName := CfgName + '.ini';
    /// Прочитать заданный файл конфигурации
    if FileExists (SelfPath + CfgName) then Cfg.LoadFromFile (SelfPath + CfgName);
    /// Собрать рекурсивно все файлы описания миров
    CollectWorlds (SelfPath);
    /// Reduce Cfg if need ...
    if MainForm.NeedToReduceIni then
    begin
      Cfg.Selector ('\m1'); ReduceSection (Cfg.CurrentSection);
      Cfg.Selector ('\m2'); ReduceSection (Cfg.CurrentSection);
      Cfg.Selector ('\m3'); ReduceSection (Cfg.CurrentSection);
    end;
    /// Сохранить собранный файл конфигурации
    Cfg.SaveToFile (CfgName);
  end;

  /// Собрать рекурсивно несколько ".dat" файлов в один ...

  procedure  TApp.MergeDataRecursively (const Path, Name: string; World: TPopulations);
  var
    TmpWorld: TPopulations;
    T: TSearchRec;
    I: integer;
  begin
    /// Найти в заданном каталоге миры и добавить их параметры в файл конфигурации
    if FindFirst (Path + Name, faAnyFile - faDirectory, T) = 0 then
      repeat
        if (T.Name <> '.') and (T.Name <> '..') then begin
          TmpWorld := TPopulations.Create (Path + T.Name);
          World.CurrentAge :=
            Max (0, Min (World.CurrentAge, TmpWorld.CurrentAge - 2000));
          TmpWorld.MarkToRecalculate;
          for I := 0 to TmpWorld.Count - 1 do
            if TPopulation (TmpWorld.List [I]).Count > 0 then begin
              TPopulation (World.List [I]).Add (TPopulation (TmpWorld.List [I]).First);
              TPopulation (TmpWorld.List [I]).Delete (0);
            end;
          TmpWorld.Free;
        end;
      until FindNext (T) <> 0;
    FindClose (T);

    /// Найти подкаталоги и вызвать их рекурсивную обработку
    if FindFirst (Path + '*.*', faDirectory, T) = 0 then
      repeat
        if (T.Name <> '.') and (T.Name <> '..') then
          MergeDataRecursively (Path + T.Name + '\', Name, World);
      until FindNext (T) <> 0;

    /// Закончить поиск ...
    FindClose (T);
  end;

  procedure TApp.Evolution;
  begin
    /// Установить выбранный приоритет приложения

    SetPriority (Priority);

    /// Collect configuration, if needed ...
    if MainForm.NeedToCollectConfig then
      CollectConfigurations (ConfigurationName);

    /// Выполнить подготовку к пересчету, если нужно ...
    if MainForm.NeedToRecalculate then begin
      World.Free;
      World := TPopulations.Create (SrcName + '.dat');
      World.MarkToRecalculate;
      World.Save (SrcName + '.dat');
      MainForm.StatusBar.Panels.Items [0].Text := 'Parameters will be re-estimated at next run...';
      Exit;
    end;

    /// Выполнить сборку ".dat" файлов, если нужно ...
    if MainForm.NeedToMerge then begin
      World.Free;
      World := TPopulations.Create;
      World.CurrentAge := 12000;
      /// Собрать рекурсивно все файлы описания миров
      MergeDataRecursively ('.\', SrcName + '.dat', World);
      /// Установить год продолжения оптимизации ...
      World.CurrentAge := (World.CurrentAge div 2000) * 2000 + 1;
      /// Сохранить собранный .dat файл ...
      World.Save (SrcName + '.dat');
      /// Выдать status bar ...
      MainForm.StatusBar.Panels.Items [0].Text := 'All "' + SrcName + '.dat" merged. Run again to continue...';
      Exit;
    end;

    /// Выполнить проверки обязательных условий оптимизации ...

    if MainForm.NeedToRun = False then begin MainForm.StatusBar.Panels.Items [0].Text := 'Configuration file was maked.'; Exit; end;
    if SrcName = '' then begin MainForm.StatusBar.Panels.Items [0].Text := 'Folder is not selected.'; Exit; end;
    if Headers.Count = 0 then begin MainForm.StatusBar.Panels.Items [0].Text := 'No Files for Optimization.'; Exit; end;
    MainForm.StatusBar.Panels.Items [0].Text := 'Optimization...';

    /// Начать / продолжить эволюцию...

    World.Free;
    World := TPopulations.Create (SrcName + '.dat');

    repeat
      DrawLevelProgress;
      World.Live;
      if Not MainForm.NeedToClose then World.Save (SrcName + '.dat');
    until MainForm.NeedToClose;
  end;

  procedure  TApp.DrawLevelProgress;
  begin
    MainForm.Label_variantsEstimatedValue.Caption := Format ('%d', [World.CurrentAge]);
    MainForm.Label_PercentOfImprovementsValue.Caption := Format ('%1.3f%%', [World.Improvements / (World.CurrentAge + 1) * 100]);
    MainForm.Label_LevelValue.Caption := Format ('%d', [World.CurrentPopulation + 1]);

    if TPopulation (World.List [World.CurrentPopulation]).Count > 0 then
      MainForm.Label_PackedSizeValue.Caption := Format ('%d', [TPerson (TPopulation (World.List [World.CurrentPopulation]).First).Cost])
    Else
      MainForm.Label_PackedSizeValue.Caption := '?';

    MainForm.RxTrayIcon1.Hint := Format ('%d variants, %1.3f%% improvements.', [World.CurrentAge, World.Improvements / (World.CurrentAge + 1) * 100]);
  end;

  procedure TApp.ReduceSection (Section: TConfigSection);
  var
    I: Integer;
  begin
    I := 0;
    while I < Section.Count do
      if Pos ('.Size', Cfg.CurrentSection.Names [I]) > 0 then
        Section.Delete (I)
      else
        Inc (I);
  end;

  /// TBody...

  constructor TBody.Create;
  var
    F: TFileStream;
  begin
    F := TFileStream.Create (aFileName, fmOpenRead + fmShareDenyWrite);
    Size := F.Size;
    GetMem (Data, Size);
    F.ReadBuffer (Data^, Size);
    F.Free;
  end;

  destructor  TBody.Destroy;
  begin
    FreeMem (Data);
  end;

{$R *.DFM}

// TForm1
// --------------------------------------------------------------------------

  procedure TMainForm.FormCreate (Sender: TObject);
  begin
    Application.Icon       := Icon;
    Application.OnMinimize := ApplicationMinimize;
    Application.OnRestore  := ApplicationRestore;

    ShowWindow (Application.Handle, SW_SHOWNORMAL);
    ShowWindow (Application.Handle, SW_HIDE);

    NeedToRecalculate := False;
    NeedToReduceIni := False;
    NeedToClose := False;
    NeedToRun := True;
    NeedToHide := False;

    App := TApp.Create;
  end;

  procedure TMainForm.FormClose (Sender: TObject; var Action: TCloseAction);
  begin
    NeedToClose := True;
    MainForm.StatusBar.Panels.Items [0].Text := 'Saving...';
  end;

  procedure TMainForm.FormDestroy (Sender: TObject);
  begin
    if App <> Nil then App.Free;
  end;

  procedure TMainForm.ApplicationMinimize (Sender:TObject);
  begin
    ShowWindow (Application.Handle, SW_HIDE);
    RxTrayIcon1.Active := Not NeedToHide;
  end;

  procedure TMainForm.ApplicationRestore (Sender:TObject);
  begin
    ShowWindow (Application.Handle, SW_RESTORE);
    SetForegroundWindow (Application.Handle);
    RxTrayIcon1.Active := False;
  end;

  procedure TMainForm.RxTrayIcon1Click (Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
  begin
    MainForm.Visible := True;
    Application.ShowMainForm := True;
    Application.Restore;
    RxTrayIcon1.Active := False;
  end;

end.


program BeeOpt;

uses
  Forms,
  BeeOpt_Form in 'BeeOpt_Form.pas' {MainForm},
  Bee_Configuration in '..\Bee_Configuration.pas',
  Bee_Common in '..\Bee_Common.pas',
  Bee_Files in '..\Bee_Files.pas',
  Bee_Headers in '..\Bee_Headers.pas',
  Bee_MainPacker in '..\Bee_MainPacker.pas',
  Bee_Crc in '..\Bee_Crc.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm (TMainForm, MainForm);
  If MainForm.App <> Nil then MainForm.App.Evolution;
  Application.Run;
end.

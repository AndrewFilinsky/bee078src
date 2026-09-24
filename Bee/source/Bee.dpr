program Bee;

{ Contains:

  The data compression utility.

  Features:

  1. Uses context modelling and some variant of arithmetic encoding.
  2. Uses integer arithmetic only.
  3. Uses half-byte alphabet.

  (C) 1999-2005 Andrew Filinsky, Melchiorre Caruso

  Modifyed:

  v0.7.8 build 0150 - 2005/06/27 Melchiorre Caruso
  v0.7.8 build 0153 - 2005/07/08 by Andrew Filinsky
  v0.7.8 build 0154 - 2005/07/23 by Melchiorre Caruso
}

uses
  SysUtils,
  Bee_Common,
  Bee_App;

var
  App: TBeeApp;

begin
  /// Create command-line shell ...
  App := TBeeApp.Create (
    'The Bee 0.7.8 build 0154 archiver utility, freeware version, Jun 2005.' + Cr +
    '(c) 1999-2005 Andrew Filinsky, Melchiorre Caruso' + Cr);

  /// Run command-line shell, then free ...
  if not (App = nil) then
  begin
    if not App.Run then App.DisplayUsage;
    App.Free;
  end;
end.

unit Bee_Codec;

{ Contains:

  TSecondaryCodec class,   abstract secondary codec, similar to RangeCoder or Arithmetic Coder;
  TSecondaryEncoder class, implementation of secondary encoder;
  TSecondaryDecoder class, implementation of secondary decoder;

  (C) 2003-2005 Andrew Filinsky

  Modifyed:

  v0.7.8 build 0153 - 2005/07/08 by Andrew Filinsky
}

{$R-,Q-,S-}

interface

uses
  Classes,              /// TStream
  Bee_RangeCoder1m;     /// TRangeCoder, ...

const
  MaxFreq = Bee_RangeCoder1m.MaxFreq;

type
  /// Array of Frequencyes...

  TFreq = array of cardinal;

  /// Abstract secondary codec, like a RangeCoder or Arithmetic Coder...

  TSecondaryCodec = class (TRangeCoder)
    procedure   Start; virtual; abstract;
    procedure   Flush; virtual; abstract;
    function    UpdateSymbol (Freq0, Freq1, aSymbol: cardinal): cardinal; overload; virtual; abstract;
    function    UpdateSymbol (const Freq: TFreq; aSymbol: cardinal): cardinal; overload; virtual; abstract;
  end;

  /// Range Encoder...

  TSecondaryEncoder = class (TSecondaryCodec)
    procedure   Start; override;
    procedure   Flush; override;
    function    UpdateSymbol (Freq0, Freq1, aSymbol: cardinal): cardinal; override;
    function    UpdateSymbol (const Freq: TFreq; aSymbol: cardinal): cardinal; override;
  end;

  /// Range Decoder...

  TSecondaryDecoder = class (TSecondaryCodec)
    procedure   Start; override;
    procedure   Flush; override;
    function    UpdateSymbol (Freq0, Freq1, aSymbol: cardinal): cardinal; override;
    function    UpdateSymbol (const Freq: TFreq; aSymbol: cardinal): cardinal; override;
  end;

/// Opcode extension functions...

  function  MulDiv (A, B, C: cardinal): cardinal; Forward;

implementation

/// TSecondaryEncoder...

  procedure  TSecondaryEncoder.Start;
  begin
    StartEncode;
  end;

  procedure  TSecondaryEncoder.Flush;
  begin
    FinishEncode;
  end;

  function  TSecondaryEncoder.UpdateSymbol (Freq0, Freq1, aSymbol: cardinal): cardinal;
  begin
    if aSymbol = 0 then
      Encode (0, Freq0, Freq0 + Freq1)
    else
      Encode (Freq0, Freq1, Freq0 + Freq1);
    Result := aSymbol;
  end;

  function  TSecondaryEncoder.UpdateSymbol (const Freq: TFreq; aSymbol: cardinal): cardinal;
  var
    CumFreq, TotFreq, I: cardinal;
  begin
    /// Count CumFreq...
    CumFreq := 0;
    I := 0;
    while I < aSymbol do begin Inc (CumFreq, Freq [I]); Inc (I); end;
    /// Count TotFreq...
    TotFreq := CumFreq;
    I := Length (Freq);
    repeat Dec (I); Inc (TotFreq, Freq [I]); until I = aSymbol;
    /// Encode...
    Encode (CumFreq, Freq [aSymbol], TotFreq);
    /// Return Result...
    Result := aSymbol;
  end;

/// TSecondaryDecoder...

  procedure  TSecondaryDecoder.Start;
  begin
    StartDecode;
  end;

  procedure  TSecondaryDecoder.Flush;
  begin
    FinishDecode;
  end;

  function  TSecondaryDecoder.UpdateSymbol (Freq0, Freq1, aSymbol: cardinal): cardinal;
  begin
    if GetFreq (Freq0 + Freq1) < Freq0 then begin
      Decode (0, Freq0, Freq0 + Freq1);
      Result := 0;
    end else begin
      Decode (Freq0, Freq1, Freq0 + Freq1);
      Result := 1;
    end;
  end;

  function  TSecondaryDecoder.UpdateSymbol (const Freq: TFreq; aSymbol: cardinal): cardinal;
  var
    CumFreq, TotFreq, SumFreq: cardinal;
  begin
    /// Count TotFreq...
    TotFreq := 0;
    aSymbol := Length (Freq);
    repeat Dec (aSymbol); Inc (TotFreq, Freq [aSymbol]); until aSymbol = 0;
    /// Count CumFreq...
    CumFreq := GetFreq (TotFreq);
    /// Search aSymbol...
    SumFreq := 0;
    aSymbol := 0;
    while SumFreq + Freq [aSymbol] <= CumFreq do begin Inc (SumFreq, Freq [aSymbol]); Inc (aSymbol); end;
    /// Finish Decode...
    Decode (SumFreq, Freq [aSymbol], TotFreq);
    /// Return Result...
    Result := aSymbol;
  end;

/// Opcode extension functions...

  function  MulDiv (A, B, C: cardinal): cardinal; assembler;
  asm
    MUL B
    DIV C
  end;

end.


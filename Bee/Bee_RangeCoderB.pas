Unit Bee_RangeCoderB;

  { Unit contains classes:
    -- TRangeCoder, range coder (based on BeeAri (based on arithmetic coder), MaxFreq = 2^29);
    Created:
    -- Andrew Filinsky, 2002;
  }
  {$R-,Q-,S-}

Interface

  Uses
    Classes;  /// TStream

  Const
    ValueBits = 26; /// 31;
    FirstQtr  = 1 shl (ValueBits - 2);
    Half      = 2 * FirstQtr;
    ThirdQtr  = 3 * FirstQtr;
    TopValue  = Half - 1 + Half;
    MaxFreq   = FirstQtr - 1;

// Types...

  Type
    /// TRangeCoder...

    TRangeCoder = Class
      Constructor Create (aStream: TStream);

      Procedure   StartEncode;
      Procedure   FinishEncode;
      Procedure   Encode (CumFreq, Freq, TotFreq: Cardinal);

      Procedure   StartDecode;
      Procedure   FinishDecode;
      Function    GetFreq (TotFreq: Cardinal): Cardinal;
      Procedure   Decode (CumFreq, Freq, TotFreq: Cardinal);

    private
      /// For encoding...
      Procedure   OutBit (Bit: Cardinal);
      Procedure   BitPlusFollow (Bit: Cardinal);
      /// For decoding...
      Function    InputBit: Cardinal;

    private
      Stream: TStream;

      Buffer, Bits,                       // For bytes output/input...
      BitsToFollow,                       // For encoding...
      Value,                              // For decoding...
      Low, High: Cardinal;                // For both encoding and decoding...
    End;

/// Opcode extension functions...

  Function  MulDiv (A, B, C: Cardinal): Cardinal; Forward;
  Function  MulDecDiv (A, B, C: Cardinal): Cardinal; Forward;

Implementation

/// TRangeCoder...

  Constructor  TRangeCoder.Create (aStream: TStream);
  Begin
    Inherited Create;
    Stream := aStream;
  End;

  Procedure  TRangeCoder.StartEncode;
  Begin
    Low := 0; High := TopValue; BitsToFollow := 0; Buffer := 0; Bits := 1;
  End;

  Procedure  TRangeCoder.FinishEncode;
  Begin
    If Bits = 0 then Exit;
    Inc (BitsToFollow);
    If Low < FirstQtr then BitPlusFollow (0) else BitPlusFollow (Cardinal (-1));
    If Bits > $00800000 then Stream.Write (Buffer, 4) else
    If Bits > $00008000 then Stream.Write (Buffer, 3) else
    If Bits > $00000080 then Stream.Write (Buffer, 2) else
    If Bits > $00000001 then Stream.Write (Buffer, 1);
    Bits := 0;
  End;

  Procedure  TRangeCoder.Encode (CumFreq, Freq, TotFreq: Cardinal);
    Var
      Range: Cardinal;
  Begin
    /// Recount bounds...
    Range := High - Low + 1;
    High  := Low + MulDiv (Range, CumFreq + Freq, TotFreq) - 1;
    Low   := Low + MulDiv (Range, CumFreq, TotFreq);
    /// Emit bites...
    While True do begin
      if High < Half then
        BitPlusFollow (0)
      Else if Low >= Half then begin
        BitPlusFollow (Cardinal (-1));
        Dec (Low, Half);
        Dec (High, Half);
      end else if (Low >= FirstQtr) and (High < ThirdQtr) then begin
        Inc (BitsToFollow);
        Dec (Low, FirstQtr);
        Dec (High, FirstQtr);
      end else
        break;
      Low  := Low shl 1;
      High := High shl 1 + 1;
    End;
  End;

  /// For encoding...

  Procedure  TRangeCoder.OutBit (Bit: Cardinal);
  Begin
    Inc (Buffer, Bits and Bit);
    Bits := Bits shl 1;
    If Bits = 0 then begin
      Stream.Write (Buffer, SizeOf (Buffer));
      Buffer := 0;
      Inc (Bits);
    End;
  End;

  Procedure  TRangeCoder.BitPlusFollow (Bit: Cardinal);
  Begin
    OutBit (Bit);
    While BitsToFollow > 0 do begin OutBit (Not Bit); Dec (BitsToFollow); end;
  End;

  Procedure  TRangeCoder.StartDecode;
    Var
      I: Cardinal;
  Begin
    Bits := 0; Value := 0; Low := 0; High := TopValue;
    For I := 1 to ValueBits do Value := Value shl 1 + InputBit;
  End;

  Procedure  TRangeCoder.FinishDecode;
  Begin
    /// Nothing to do...
  End;

  Function  TRangeCoder.GetFreq (TotFreq: Cardinal): Cardinal;
    Var
      Range: Cardinal;
  Begin
    Range  := High - Low + 1;
    Result := MulDecDiv (Value - Low + 1, TotFreq, Range);
  End;

  Procedure  TRangeCoder.Decode (CumFreq, Freq, TotFreq: Cardinal);
    Var
      Range: Cardinal;
  Begin
    /// Recount bounds...
    Range := High - Low + 1;
    High  := Low + MulDiv (Range, CumFreq + Freq, TotFreq) - 1;
    Low   := Low + MulDiv (Range, CumFreq, TotFreq);
    /// Emit bites...
    While True do begin
      if High < Half then
        // nothing
      else if Low >= Half then begin
        Dec (Value, Half);
        Dec (Low, Half);
        Dec (High, Half);
      end else if (Low >= FirstQtr) and (High < ThirdQtr) then begin
        Dec (Value, FirstQtr);
        Dec (Low, FirstQtr);
        Dec (High, FirstQtr);
      end else
        break;
      Low   := Low shl 1;
      High  := High shl 1 + 1;
      Value := Value shl 1 + InputBit;
    End;
  End;

  Function  TRangeCoder.InputBit: Cardinal;
  Begin
    If Bits = 0 then begin Stream.Read (Buffer, 1); Bits := 8; end;
    Result := Buffer and 1;
    Buffer := Buffer shr 1;
    Dec (Bits);
  End;

/// Opcode extension functions...

  Function  MulDiv (A, B, C: Cardinal): Cardinal; Assembler;
    Asm
      MUL B
      DIV C
    End;

  Function  MulDecDiv (A, B, C: Cardinal): Cardinal; Assembler;
    Asm
      MUL B
      SUB EAX, 1
      SBB EDX, 0
      DIV C
    End;

End.

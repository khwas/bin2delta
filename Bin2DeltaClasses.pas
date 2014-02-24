unit Bin2DeltaClasses;

interface
uses
  Classes; 

  procedure DoIt;

implementation
uses
  SysUtils, FileMapping;

type
  TLengthsArray = Array [Byte] of Cardinal;
  TSquareOfLengthsArrays = Array [Byte] of TLengthsArray;
  TOffsetsArray = Array [0 .. 1] of Cardinal;
  POffsetsArray = ^TOffsetsArray;
  TRowOfOffsetsArrays = Array [Byte] of POffsetsArray;
  TSquareOfOffsetsArrays = Array [Byte] of TRowOfOffsetsArrays;

var
  SquareOfLength: TSquareOfLengthsArrays;
  SquareOfIndex : TSquareOfLengthsArrays;
  SquareOfOffsetsArrays: TSquareOfOffsetsArrays;

procedure PrepareSquareOfLength (const InputSequence: TFileMappingAsByteArray);
var
  Offset, CasesCount: Cardinal;
  X, Y: Byte;
begin
  { Fill square of lengths with 0s }
  for X := Low(SquareOfLength) to High(SquareOfLength) do begin
    for Y := Low(SquareOfLength[X]) to High(SquareOfLength[X]) do
      SquareOfLength[X][Y] := 0;
  end {for};
  { Count all byte-to-byte pairs in square }
  if InputSequence.ArraySize > 0 then begin
    {$R-}
    X := InputSequence.ByteArray[0]; 
    {$R+}
    for Offset := 1 to InputSequence.ArraySize - 1 do begin
      {$R-}
      Y := InputSequence.ByteArray[Offset];
      {$R+}
      Inc(SquareOfLength[X][Y]);
      X := Y;
    end {for};
  end {if};
  { Use square of lengths to setlengths }
  for X := Low(SquareOfLength) to High(SquareOfLength) do
    for Y := Low(SquareOfLength[X]) to High(SquareOfLength[X]) do
      begin
        CasesCount := SquareOfLength[X][Y];
        if CasesCount = 0 then begin
          SquareOfOffsetsArrays [X][Y] := Nil;
          end else begin
          GetMem(SquareOfOffsetsArrays[X][Y], CasesCount * SizeOf(Cardinal));
          Assert(Assigned(SquareOfOffsetsArrays[X][Y]));
        end {if};
      end {for};
end {PrepareSquareOfLength};

procedure UnPrepareSquareOfLength;
var
  X, Y: Byte;
  CasesCount: Cardinal;
  OffsetsArray: POffsetsArray;
begin
  for X := Low(SquareOfLength) to High(SquareOfLength) do
    for Y := Low(SquareOfLength[X]) to High(SquareOfLength[X]) do begin
      OffsetsArray := SquareOfOffsetsArrays[X][Y];
      CasesCount   := SquareOfLength[X][Y];
      Assert((CasesCount =  0) and (not Assigned(OffsetsArray)) or
             (CasesCount <> 0) and Assigned(OffsetsArray));
      if Assigned(OffsetsArray) then FreeMem(OffsetsArray, CasesCount * SizeOf(Cardinal));
      SquareOfLength[X][Y] := 0;
      SquareOfOffsetsArrays[X][Y] := Nil;
    end {for};
end {UnPrepareSquareOfLength};

procedure PrepareSquareOfIndexes(const InputSequence: TFileMappingAsByteArray);
var
  Offset: Cardinal;
  X, Y: Byte;
  AppendingAt: Cardinal;
  OffsetsArray: POffsetsArray;
begin
  { Fill square of Index with 0s }
  for X := Low(SquareOfIndex) to High(SquareOfIndex) do begin
    for Y := Low(SquareOfIndex[X]) to High(SquareOfIndex[X]) do
      SquareOfIndex[X][Y] := 0;
  end {for};
  { Fill Square with offsets }
  if InputSequence.ArraySize > 0 then begin
    {$R-}
    X := InputSequence.ByteArray[0];
    {$R+}
    for Offset := 1 to InputSequence.ArraySize - 1 do begin
      {$R-}
      Y := InputSequence.ByteArray[Offset];
      {$R+}
      AppendingAt := SquareOfIndex[X][Y];
      OffsetsArray := SquareOfOffsetsArrays[X][Y];
      Assert(Assigned(OffsetsArray));
      {$R-}
      Assert(AppendingAt < SquareOfLength[X][Y]);
      OffsetsArray^[AppendingAt] := Offset - 1;
      {$R+}
      Inc(SquareOfIndex[X][Y]);
      X := Y;
    end {for};
  end {if};
end {PrepareSquareOfIndexes};

procedure UnPrepareSquareOfIndexes;
begin
  { Do nothing }
end {UnPrepareSquareOfIndexes};

function SearchLongestSequence(const SourceSequence: TFileMappingAsByteArray;
                               const TargetSequence: TFileMappingAsByteArray;
                               const TargetOffset, TargetToGo: Cardinal;
                               var   OffsetFound, LengthFound: Cardinal): Boolean;
var
  SourceOffset: Cardinal;
  X, Y, S, T: Byte;
  CasesCount, CasesIndex: Cardinal;
  OffsetsArray: POffsetsArray;
  SourceToGo: Cardinal;
  ByteIndex: Cardinal;
  Success: Boolean;
begin
  if (TargetToGo <=2) or (TargetOffset = TargetSequence.ArraySize) then begin
    Result := False;
    OffsetFound := $FFFFFFFF;
    LengthFound := 0;
    Exit;
  end {if};

  Assert(TargetOffset + 1 < TargetSequence.ArraySize);
  Assert(TargetToGo = TargetSequence.ArraySize - TargetOffset);

  { Get byte pairs from target }
  {$R-}
  X := TargetSequence.ByteArray[TargetOffset];
  Y := TargetSequence.ByteArray[TargetOffset + 1];
  {$R+}

  { find list of all places, where X is before Y }
  OffsetsArray := SquareOfOffsetsArrays[X][Y];
  Result := Assigned(OffsetsArray);

  { if there is no one place in SourceSequence then exit }
  if not Result then begin
    OffsetFound := $FFFFFFFF;
    LengthFound := 0;
    Exit;
  end {if};

  { Result is true and OffsetsArray is assigned }
  { found list of all places, where X is before Y }
  LengthFound := 2;
  OffsetFound := OffsetsArray[0];

  { take list of all places, where X is before Y }
  CasesCount := SquareOfLength[X][Y];

  { walk over all cases from 0 to CasesCount - 1 }
  { increase LengthFound while it's possible     }
  for CasesIndex := 0 to CasesCount - 1 do begin
    { is found sequence long enough ? }
    if LengthFound >= TargetToGo then Break;

    { get offset of start of sequence i }
    {$R-}
    SourceOffset := OffsetsArray[CasesIndex];
    {$R+}

    { quick test of case by length }
    SourceToGo := SourceSequence.ArraySize - SourceOffset;
    if SourceToGo <= LengthFound then Continue;

    { quick test of case by byte }
    {$R-}
    Assert(SourceOffset + LengthFound < SourceSequence.ArraySize);
    S := SourceSequence.ByteArray[SourceOffset + LengthFound];
    Assert(TargetOffset + LengthFound < TargetSequence.ArraySize);
    T := TargetSequence.ByteArray[TargetOffset + LengthFound];
    {$R+}
    if S <> T then Continue;

    { long test for all bytes from 3rd to LastFound }
    Success := True; { this chain can have length=0 }
    for ByteIndex := 2 to LengthFound - 1 do begin
      {$R-}
      Assert(SourceOffset + ByteIndex < SourceSequence.ArraySize);
      S := SourceSequence.ByteArray[SourceOffset + ByteIndex];
      Assert(TargetOffset + ByteIndex < TargetSequence.ArraySize);
      T := TargetSequence.ByteArray[TargetOffset + ByteIndex];
      {$R+}
      Success := S = T;
      if not Success then Break;
    end {for};
    if not Success then Continue;

    { found sequence is at least 1 byte more long then previous best }
    OffsetFound := SourceOffset;
    Inc(LengthFound);

    { try to increase LengthFound }
    while Success and (LengthFound < TargetToGo) and (LengthFound < SourceToGo) do begin
      {$R-}
      S := SourceSequence.ByteArray[SourceOffset + LengthFound];
      T := TargetSequence.ByteArray[TargetOffset + LengthFound];
      {$R+}
      Success := (S = T);
      if Success then Inc(LengthFound);
    end {while};
  end {for};
end {SearchLongestSequence};

procedure DoIt;
var
  FMB: TFileMappingAsByteArray;
  NewDataCount,
  NewDataStart: Cardinal;
  DiffFile: TFileStream;
  TotalLength: Cardinal;

  procedure FlushNew;
  var
    DiffBuffer: Array [0..4] of byte;
  begin
      { write any new data }
      if NewDataCount > 0 then begin
        TotalLength := TotalLength + NewDataCount;
        case NewDataCount of
          0:
            begin
              Assert(False);
            end {0};
          1..246:                 {01..F6}
            begin
              DiffBuffer[0] := (NewDataCount and $000000FF) shr 00;
              DiffFile.WriteBuffer(DiffBuffer, SizeOf(Byte) * 1);
              {$R-}
              DiffFile.WriteBuffer(FMB.ByteArray[NewDataStart], NewDataCount);
              {$R+}
            end {1..246};
          247..65535:
            begin
              DiffBuffer[0] := 247; {F7}
              DiffBuffer[1] := (NewDataCount and $0000FF00) shr 08;
              DiffBuffer[2] := (NewDataCount and $000000FF) shr 00;
              DiffFile.WriteBuffer(DiffBuffer, SizeOf(Byte) * 3);
              {$R-}
              DiffFile.WriteBuffer(FMB.ByteArray[NewDataStart], NewDataCount);
              {$R+}
            end {247..65535};
          else
            {65535..beyond}
            begin
              DiffBuffer[0] := 248; {F8}
              DiffBuffer[1] := (NewDataCount and $FF000000) shr 24;
              DiffBuffer[2] := (NewDataCount and $00FF0000) shr 16;
              DiffBuffer[3] := (NewDataCount and $0000FF00) shr 08;
              DiffBuffer[4] := (NewDataCount and $000000FF) shr 00;
              DiffFile.WriteBuffer(DiffBuffer, SizeOf(Byte) * 5);
              {$R-}
              DiffFile.WriteBuffer(FMB.ByteArray[NewDataStart], NewDataCount);
              {$R+}
            end {else};
        end {case};
        NewDataCount := 0;
        NewDataStart := 0;
      end {if newdata};
  end {FlushNew};

var
  Offset, OffsetFound, LengthFound, Crc32, FileNameLength, HeaderSize, CharIndex: Cardinal;
  FileName: String;
  DotsPrinted: Cardinal;
  DotsToPrint: Cardinal;
  DiffBuffer: Array [0..8] of byte;
  NameBuffer: Array [0..1024] of byte;
  FMA: TFileMappingAsByteArray;
begin
  write('Step 1. ');
  TotalLength := 0;
  FMA      := TFileMappingAsByteArray.Create(ParamStr(1));
  FMB      := TFileMappingAsByteArray.Create(ParamStr(2));
  PrepareSquareOfLength(FMA);
  write('Step 2. ');
  PrepareSquareOfIndexes(FMA);
  write('Step 3. ');
  DiffFile := TFileStream.Create(ParamStr(3), fmCreate);
  NewDataStart := 0;
  NewDataCount := 0;
  Offset       := 0;

  FileName     := ExtractFileName(ParamStr(1));
  HeaderSize   := 2 +              { size Of HeaderSize }
                  2 +              { size Of length of FileName }
                  Length(FileName)+{ length of FileName }
                  4 +              { source file crc32  }
                  4;               { target file crc32  }
  DiffBuffer [0] := (HeaderSize and $000000FF) shr 00;
  DiffBuffer [1] := (HeaderSize and $0000FF00) shr 08;
  FileNameLength  := Length(FileName);
  DiffBuffer [2] := (FileNameLength and $000000FF) shr 00;
  DiffBuffer [3] := (FileNameLength and $0000FF00) shr 08;
  DiffFile.WriteBuffer(DiffBuffer, 4);

  if FileNameLength > 1024 then
    raise Exception.Create('Too long source filename');
  for CharIndex := 1 to FileNameLength do NameBuffer[CharIndex - 1] := Ord(FileName[CharIndex]);
  DiffFile.WriteBuffer(NameBuffer, FileNameLength);

  Crc32        := FMA.CRC32;
  DiffBuffer [3] := (Crc32 and $FF000000) shr 24;
  DiffBuffer [2] := (Crc32 and $00FF0000) shr 16;
  DiffBuffer [1] := (Crc32 and $0000FF00) shr 08;
  DiffBuffer [0] := (Crc32 and $000000FF) shr 00;
  DiffFile.WriteBuffer(DiffBuffer, 4);

  Crc32        := FMB.CRC32;
  DiffBuffer [3] := (Crc32 and $FF000000) shr 24;
  DiffBuffer [2] := (Crc32 and $00FF0000) shr 16;
  DiffBuffer [1] := (Crc32 and $0000FF00) shr 08;
  DiffBuffer [0] := (Crc32 and $000000FF) shr 00;
  DiffFile.WriteBuffer(DiffBuffer, 4);

  DiffBuffer [0] := $D1;
  DiffBuffer [1] := $FF;
  DiffBuffer [2] := $D1;
  DiffBuffer [3] := $FF;
  DiffBuffer [4] := $04;
  DiffFile.WriteBuffer(DiffBuffer, 5);

  DotsPrinted := 0;
  write('Step 4. ');
  while Offset < FMB.ArraySize do begin
    DotsToPrint := Round((100 * Offset)/FMB.ArraySize) div 2;
    while DotsPrinted < DotsToPrint do begin
      write('.');
      Inc(DotsPrinted);
    end {while};
    if SearchLongestSequence(FMA,
                             FMB,
                             Offset,
                             FMB.ArraySize - Offset,
                             OffsetFound,
                             LengthFound)
                             and
      (LengthFound > 4) then begin
      Assert(OffsetFound + LengthFound <= FMA.ArraySize);
      Offset := Offset + LengthFound;
      FlushNew;
      { put copy command }
      TotalLength := TotalLength + LengthFound;
      case LengthFound of
        0 .. 4:
          begin
            raise Exception.Create('Internal error');
          end {0..4};
        5..255:
          begin
            if OffsetFound <= 65535 then begin
              DiffBuffer[0] := 249; {F9}
              DiffBuffer[1] := (OffsetFound and $0000FF00) shr 08;
              DiffBuffer[2] := (OffsetFound and $000000FF) shr 00;
              DiffBuffer[3] := (LengthFound and $000000FF) shr 00;
              DiffFile.WriteBuffer(DiffBuffer, 4);
              end else begin
              DiffBuffer[0] := 252; {FC}
              DiffBuffer[1] := (OffsetFound and $FF000000) shr 24;
              DiffBuffer[2] := (OffsetFound and $00FF0000) shr 16;
              DiffBuffer[3] := (OffsetFound and $0000FF00) shr 08;
              DiffBuffer[4] := (OffsetFound and $000000FF) shr 00;
              DiffBuffer[5] := (LengthFound and $000000FF) shr 00;
              DiffFile.WriteBuffer(DiffBuffer, 6);
            end {if};
          end {5..255};
        256..65535:
          begin
            if OffsetFound <= 65535 then begin
              DiffBuffer[0] := 250; {FA}
              DiffBuffer[1] := (OffsetFound and $0000FF00) shr 08;
              DiffBuffer[2] := (OffsetFound and $000000FF) shr 00;
              DiffBuffer[3] := (LengthFound and $0000FF00) shr 08;
              DiffBuffer[4] := (LengthFound and $000000FF) shr 00;
              DiffFile.WriteBuffer(DiffBuffer, 5);
              end else begin
              DiffBuffer[0] := 253; {FD}
              DiffBuffer[1] := (OffsetFound and $FF000000) shr 24;
              DiffBuffer[2] := (OffsetFound and $00FF0000) shr 16;
              DiffBuffer[3] := (OffsetFound and $0000FF00) shr 08;
              DiffBuffer[4] := (OffsetFound and $000000FF) shr 00;
              DiffBuffer[5] := (LengthFound and $0000FF00) shr 08;
              DiffBuffer[6] := (LengthFound and $000000FF) shr 00;
              DiffFile.WriteBuffer(DiffBuffer, 7);
            end {if};
          end {256..65535};
        else
          begin
            if OffsetFound <= 65535 then begin
              DiffBuffer[0] := 251; {FB}
              DiffBuffer[1] := (OffsetFound and $0000FF00) shr 08;
              DiffBuffer[2] := (OffsetFound and $000000FF) shr 00;
              DiffBuffer[3] := (LengthFound and $FF000000) shr 24;
              DiffBuffer[4] := (LengthFound and $00FF0000) shr 16;
              DiffBuffer[5] := (LengthFound and $0000FF00) shr 08;
              DiffBuffer[6] := (LengthFound and $000000FF) shr 00;
              DiffFile.WriteBuffer(DiffBuffer, 7);
              end else begin
              DiffBuffer[0] := 254; {FE}
              DiffBuffer[1] := (OffsetFound and $FF000000) shr 24;
              DiffBuffer[2] := (OffsetFound and $00FF0000) shr 16;
              DiffBuffer[3] := (OffsetFound and $0000FF00) shr 08;
              DiffBuffer[4] := (OffsetFound and $000000FF) shr 00;
              DiffBuffer[5] := (LengthFound and $FF000000) shr 24;
              DiffBuffer[6] := (LengthFound and $00FF0000) shr 16;
              DiffBuffer[7] := (LengthFound and $0000FF00) shr 08;
              DiffBuffer[8] := (LengthFound and $000000FF) shr 00;
              DiffFile.WriteBuffer(DiffBuffer, 9);
            end {if};
          end {else};
      end {case};
      end else begin
      { no copy ability found }
      if NewDataCount = 0 then NewDataStart := Offset;
      Inc(Offset);
      Inc(NewDataCount);
    end {if};
  end {while};
  FlushNew;

  { flush tail }
  if Offset <> FMB.ArraySize then raise Exception.Create('Internal error');

  { write stop command }
  write(' Step 5. ');
  DiffBuffer [0] := $00;
  DiffFile.WriteBuffer(DiffBuffer, 1);
  Assert(TotalLength = FMB.ArraySize);

  DiffFile.Free;
  UnPrepareSquareOfIndexes;
  UnPrepareSquareOfLength;
  FMB.Free;
  FMA.Free;
  Writeln ('OK');
end {DoIt};


end.

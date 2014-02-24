unit Delta2binClasses;

interface

procedure DoIt;

implementation
uses
  SysUtils,
  Classes,
  FileMapping;

procedure DoIt;
var
  FMA, FMP: TFileMappingAsByteArray;
  CRC32A, CRC32B: Cardinal;
  TargetStream: TStream;
  HeaderSize: Cardinal;
  FileNameLength: Cardinal;
  InstructionIndex: Cardinal;
  Instruction: Byte;
  Count, Offset: Cardinal;
begin
  write('Step 1 '); // open files
  FMA := TFileMappingAsByteArray.Create(ParamStr(1));
  FMP := TFileMappingAsByteArray.Create(ParamStr(3));
  TargetStream := TFileStream.Create(ParamStr(2), fmCreate);
  write('Step 2 '); // check crc

  if FMP.ArraySize < 4 then
    raise Exception.Create('Patch file contains no header.');
  HeaderSize     := FMP.ByteArray[0] or (FMP.ByteArray[1] shl 8);
  FileNameLength := FMP.ByteArray[2] or (FMP.ByteArray[3] shl 8);
  if (2 +               // Header size 2 bytes
      2 +               // Filename length 2 bytes
      FileNameLength +  // Filename
      4 +               // CRC 32 A 4 bytes
      4 >               // CRC 32 B 4 bytes
      HeaderSize) then
    raise Exception.Create('Patch file header corrupted.');
  CRC32A := (FMP.ByteArray[HeaderSize - 8] shl 00) or
            (FMP.ByteArray[HeaderSize - 7] shl 08) or
            (FMP.ByteArray[HeaderSize - 6] shl 16) or
            (FMP.ByteArray[HeaderSize - 5] shl 24);
  CRC32B := (FMP.ByteArray[HeaderSize - 4] shl 00) or
            (FMP.ByteArray[HeaderSize - 3] shl 08) or
            (FMP.ByteArray[HeaderSize - 2] shl 16) or
            (FMP.ByteArray[HeaderSize - 1] shl 24);
  if FMA.CRC32 <> CRC32A then
    raise Exception.Create('Source file checksum don''t match');

  // magic signature check
  if (FMP.ByteArray[HeaderSize + 0] <> $D1) or
     (FMP.ByteArray[HeaderSize + 1] <> $FF) or
     (FMP.ByteArray[HeaderSize + 2] <> $D1) or
     (FMP.ByteArray[HeaderSize + 3] <> $FF) then
    raise Exception.Create(Paramstr(3) + ' is not a patch');

  if (FMP.ByteArray[HeaderSize + 4] <> $04) then
    raise Exception.Create('Unsupported version of patch format ');

  write('Step 3 '); // make target
  InstructionIndex := HeaderSize + 2 + 2 + 1; {D1FFF1FF04}
  while InstructionIndex < FMP.ArraySize - 1 do begin
    Instruction := {$R-} FMP.ByteArray[InstructionIndex]; {$R+}
    case Instruction of
      0:
        begin
          raise Exception.Create('Unexpected stop instruction before end of patch file');
        end {0};
      1..246:
        begin
          Count := Instruction;
          if InstructionIndex + Count + 2 > FMP.ArraySize then
            raise Exception.Create('Unexpected end of patch file');
          TargetStream.WriteBuffer({$R-} FMP.ByteArray[InstructionIndex + 1] {$R+}, Count);
          InstructionIndex := InstructionIndex + 1 + Count;
        end {1..246};
      247:
        begin
          if InstructionIndex + 4 > FMP.ArraySize then
            raise Exception.Create('Unexpected end of patch file');
          {$R-}
          Count := (FMP.ByteArray[InstructionIndex + 1] shl 08) or
                   (FMP.ByteArray[InstructionIndex + 2] shl 00);
          {$R+}
          if InstructionIndex + Count + 4 > FMP.ArraySize then
            raise Exception.Create('Unexpected end of patch file');
          TargetStream.WriteBuffer({$R-} FMP.ByteArray[InstructionIndex + 3] {$R+}, Count);
          InstructionIndex := InstructionIndex + 3 + Count;
        end {247};
      248:
        begin
          if InstructionIndex + 6 > FMP.ArraySize then
            raise Exception.Create('Unexpected end of patch file');
          {$R-}
          Count := (FMP.ByteArray[InstructionIndex + 1] shl 24) or
                   (FMP.ByteArray[InstructionIndex + 2] shl 16) or
                   (FMP.ByteArray[InstructionIndex + 3] shl 08) or
                   (FMP.ByteArray[InstructionIndex + 4] shl 00);
          {$R+}
          if InstructionIndex + Count + 6 > FMP.ArraySize then
            raise Exception.Create('Unexpected end of patch file');
          TargetStream.WriteBuffer({$R-} FMP.ByteArray[InstructionIndex + 5] {$R+}, Count);
          InstructionIndex := InstructionIndex + 5 + Count;
        end {248};
      249: { F9 }
        begin
          if InstructionIndex + 5 > FMP.ArraySize then
            raise Exception.Create('Unexpected end of patch file');
          {$R-}
          Offset:= (FMP.ByteArray[InstructionIndex + 1] shl 08) or
                   (FMP.ByteArray[InstructionIndex + 2] shl 00);
          Count := (FMP.ByteArray[InstructionIndex + 3] shl 00);
          {$R+}
          if Offset + Count > FMA.ArraySize then
            raise Exception.Create('Seek beyond source file end. Instruction at ' + IntToStr(InstructionIndex));
          TargetStream.WriteBuffer({$R-} FMA.ByteArray[Offset] {$R+}, Count);
          InstructionIndex := InstructionIndex + 4;
        end {249};
      250: {FA}
        begin
          if InstructionIndex + 6 > FMP.ArraySize then
            raise Exception.Create('Unexpected end of patch file');
          {$R-}
          Offset:= (FMP.ByteArray[InstructionIndex + 1] shl 08) or
                   (FMP.ByteArray[InstructionIndex + 2] shl 00);
          Count := (FMP.ByteArray[InstructionIndex + 3] shl 08) or
                   (FMP.ByteArray[InstructionIndex + 4] shl 00);
          {$R+}
          if Offset + Count > FMA.ArraySize then
            raise Exception.Create('Seek beyond source file end. Instruction at ' + IntToStr(InstructionIndex));
          TargetStream.WriteBuffer({$R-} FMA.ByteArray[Offset] {$R+}, Count);
          InstructionIndex := InstructionIndex + 5;
        end {250};
      251: {FB}
        begin
          if InstructionIndex + 8 > FMP.ArraySize then
            raise Exception.Create('Unexpected end of patch file');
          {$R-}
          Offset:= (FMP.ByteArray[InstructionIndex + 1] shl 08) or
                   (FMP.ByteArray[InstructionIndex + 2] shl 00);
          Count := (FMP.ByteArray[InstructionIndex + 3] shl 24) or
                   (FMP.ByteArray[InstructionIndex + 4] shl 16) or
                   (FMP.ByteArray[InstructionIndex + 5] shl 08) or
                   (FMP.ByteArray[InstructionIndex + 6] shl 00);
          {$R+}
          if Offset + Count > FMA.ArraySize then
            raise Exception.Create('Seek beyond source file end. Instruction at ' + IntToStr(InstructionIndex));
          TargetStream.WriteBuffer({$R-} FMA.ByteArray[Offset] {$R+}, Count);
          InstructionIndex := InstructionIndex + 7;
        end {251};
      252: {FC}
        begin
          if InstructionIndex + 7 > FMP.ArraySize then
            raise Exception.Create('Unexpected end of patch file');
          {$R-}
          Offset:= (FMP.ByteArray[InstructionIndex + 1] shl 24) or
                   (FMP.ByteArray[InstructionIndex + 2] shl 16) or
                   (FMP.ByteArray[InstructionIndex + 3] shl 08) or
                   (FMP.ByteArray[InstructionIndex + 4] shl 00);
          Count := (FMP.ByteArray[InstructionIndex + 5] shl 00);
          {$R+}
          if Offset + Count > FMA.ArraySize then
            raise Exception.Create('Seek beyond source file end. Instruction at ' + IntToStr(InstructionIndex));
          TargetStream.WriteBuffer({$R-} FMA.ByteArray[Offset] {$R+}, Count);
          InstructionIndex := InstructionIndex + 6;
        end {252};
      253: {FD}
        begin
          if InstructionIndex + 8 > FMP.ArraySize then
            raise Exception.Create('Unexpected end of patch file');
          {$R-}
          Offset:= (FMP.ByteArray[InstructionIndex + 1] shl 24) or
                   (FMP.ByteArray[InstructionIndex + 2] shl 16) or
                   (FMP.ByteArray[InstructionIndex + 3] shl 08) or
                   (FMP.ByteArray[InstructionIndex + 4] shl 00);
          Count := (FMP.ByteArray[InstructionIndex + 5] shl 08) or
                   (FMP.ByteArray[InstructionIndex + 6] shl 00);
          {$R+}
          if Offset + Count > FMA.ArraySize then
            raise Exception.Create('Seek beyond source file end. Instruction at ' + IntToStr(InstructionIndex));
          TargetStream.WriteBuffer({$R-} FMA.ByteArray[Offset] {$R+}, Count);
          InstructionIndex := InstructionIndex + 7;
        end {253};
      254:
        begin
          if InstructionIndex + 10 > FMP.ArraySize then
            raise Exception.Create('Unexpected end of patch file');
          {$R-}
          Offset:= (FMP.ByteArray[InstructionIndex + 1] shl 24) or
                   (FMP.ByteArray[InstructionIndex + 2] shl 16) or
                   (FMP.ByteArray[InstructionIndex + 3] shl 08) or
                   (FMP.ByteArray[InstructionIndex + 4] shl 00);
          Count := (FMP.ByteArray[InstructionIndex + 5] shl 24) or
                   (FMP.ByteArray[InstructionIndex + 6] shl 16) or
                   (FMP.ByteArray[InstructionIndex + 7] shl 08) or
                   (FMP.ByteArray[InstructionIndex + 8] shl 00);
          {$R+}
          if Offset + Count > FMA.ArraySize then
            raise Exception.Create('Seek beyond source file end. Instruction at ' + IntToStr(InstructionIndex));
          TargetStream.WriteBuffer({$R-} FMA.ByteArray[Offset] {$R+}, Count);
          InstructionIndex := InstructionIndex + 9;
        end {254};
      else
        raise Exception.Create('64-bit length of file is not supported in this version');
    end {case};
  end {while};
  if InstructionIndex <> FMP.ArraySize - 1 then
    raise Exception.Create('Internal error checking the stop instruction');
  Assert(InstructionIndex = FMP.ArraySize - 1);
  if {$R-} FMP.ByteArray[InstructionIndex] <> 0 {$R+} then
    raise Exception.Create('Unexpected end of patch file');

  write('Step 4 '); // check target crc
  FMA.Free;
  TargetStream.Free;
  FMA := TFileMappingAsByteArray.Create(ParamStr(2));
  if FMA.CRC32 <> CRC32B then begin
    FMA.Free;
    //DeleteFile(ParamStr(2));
    raise Exception.Create('Target file checksum don''t match');
  end {if};
  FMA.Free;

  write('Step 5 ');
  FMP.Free;

  writeln('OK');
end {DoIt};

end.

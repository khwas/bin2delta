program bin2delta;

{$APPTYPE CONSOLE}

{$R *.res}
uses
  SysUtils,
  Classes,
  FileMapping in 'FileMapping.pas',
  Bin2DeltaClasses in 'Bin2DeltaClasses.pas';

begin
  try
    writeln('Bin2delta [version 0.0.1 alpha] Binary files comparator, patch generator');
    writeln('(c) Copyright 2002 Vasiliy Khabituyev, khwas@yahoo.com');
    if ParamCount <> 3 then begin
      writeln;
      writeln('Usage:');
      writeln('  bin2delta <source> <target> <patch>');
      writeln;
      writeln('Where:');
      writeln('  <source> - name of older file for which the patch have to be generated');
      writeln('  <target> - name of newer file which is different to source file');
      writeln('  <patch>  - name of patch file to create');
      halt(1);
    end {if};
    DoIt;
  except on E: Exception do
    begin
      writeln;
      writeln('Bin2delta ERROR: ' + E.Message);
      halt(2);
    end {except};  
  end {try};
end.

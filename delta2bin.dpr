program delta2bin;

{$APPTYPE CONSOLE}
{$R *.res}
uses
  SysUtils,
  Classes,
  Delta2binClasses in 'Delta2binClasses.pas',
  FileMapping in 'FileMapping.pas';

begin
  try
    writeln('Delta2bin [version 0.0.1 alpha] Binary files patch applicator');
    writeln('(c) Copyright 2002 Vasiliy Khabituyev, khwas@yahoo.com');
    if ParamCount <> 3 then begin
      writeln;
      writeln('Usage:');
      writeln('  delta2bin <source> <target> <patch>');
      writeln;
      writeln('Where:');
      writeln('  <source> - name of older file for which the patch have to be generated');
      writeln('  <target> - name of newer file to create using source file');
      writeln('  <patch>  - name of patch file to use');
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

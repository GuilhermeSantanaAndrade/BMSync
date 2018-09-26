unit MyFuncs;

interface

uses Windows, SysUtils, Controls, ComObj, ActiveX, Scanner, IniFiles, Declarations,
     Messages, IBQuery, IBDatabase, Classes, wtsStream, wtsIntF, wtsMethodView;

type
  ArrayOfString = Array of String;

Function HoraValida(strh:string): Boolean;
function VarToBool(const v:Variant):Boolean;
Function NotNull(const Value: Variant): Boolean;
Function IsNull(const Value: Variant): Boolean;
Function IIF(Expresion:Boolean ; TrueResult, FalseResult:Variant):Variant;
function tempoPorExtenso(n, tipo: integer): string;
function tempoResumido(Tempo:TDateTime):String;
function MSecsToDateTime(MS:Integer):TDateTime;
function GenerateGuid: string;
Function VarToDouble(value:Variant):Double;
function StringToArray(Str:String):ArrayOfString;
procedure ClearDirectory(Dir:String);
Function CountChar(Texto:String ; C:Char) : Integer;
procedure AtualizarLastExp(DataHora:TDateTime);
procedure InitializeQuery(var Query:TIBQuery; DBase:TIBDatabase=nil);
procedure InitializeTrans(var IBTrans:TIBTransaction; DBase:TIBDatabase=nil);
function  ParseFTPDirectories(TextoList:String):ArrayOfString;
procedure SetToDefault(rs:TwtsRecordset;add:Boolean=False);

function GetMillenniumDB(ServerPath:String):String;

Const
  WM_CheckErros  = WM_USER+1;

implementation

function VarToBool(const v:Variant):Boolean;
begin
     if VarToStr(v)<>'' then
        Result := v
     else
        result := False;
end;

Function HoraValida(strh:string): Boolean;
var
  hh   : Integer;
  mm   : Integer;
  ss   : Integer;
  code : Integer;
begin
  Result := True;
   If (Length(Strh) = 0) or (Strh[1] = ' ') or
                            (Strh[2] = ' ') or
                            (Strh[4] = ' ') or
                            (Strh[5] = ' ') or
                            (Strh[7] = ' ') or
                            (Strh[8] = ' ') then
   begin
      Result := False;
   end else
   begin
      Val(Copy(Strh, 1, 2), hh, Code);
      Val(Copy(Strh, 4, 2), mm, Code);
      Val(Copy(Strh, 7, 2), ss, Code);      

      If (hh >= 24) or (mm >= 60) or (ss >= 60) then
      begin
          Result := False;
      end;
   end;
end;

Function NotNull(const Value: Variant): Boolean;
begin
  if  VarIsNull(Value)                  or
      VarIsEmpty(Value)                 or
     (VarAsType(Value, varString) = '') or
     (UpperCase(VarAsType(Value, varString)) = 'NULL' ) Then
    Result := False
  Else
    Result := True;
end;

Function IsNull(const Value: Variant): Boolean;
Begin
    Result := not NotNull(Value);
end;

Function IIF(Expresion:Boolean ; TrueResult, FalseResult:Variant):Variant;
Begin
    If Expresion Then
       Result := TrueResult
    Else
       Result := FalseResult;
end;

function tempoPorExtenso(n, tipo: integer): string;
const
    parte: array[0..19] of string = ('zero', 'um', 'dois', 'três',
            'quatro', 'cinco', 'seis', 'sete', 'oito', 'nove',
            'dez', 'onze', 'doze', 'treze', 'quatorze', 'quinze',
            'dezesseis', 'dezessete', 'dezoito', 'dezenove');
    dezena: array[2..5] of string = ('vinte', 'trinta', 'quarenta', 'cinquenta');
var dez, unid: integer;
s: string;
begin
    if (n <= 19) then
        s := parte[n]
    else
    begin
        dez := n div 10;
        unid := n mod 10;
        s := dezena[dez];
        if (unid <> 0) then 
          if (tipo = 1)  then
            if (unid = 1)  then
                s := s + ' e uma'
            else
            if (unid = 2)  then
                s := s + ' e duas'
            else
                s := s + ' e ' + parte[unid]
          else
            s := s + ' e ' + parte[unid];
    end;

    if (tipo = 1) then
      s := s + ' hora'
    else
    if (tipo = 2) then
      s := s + ' minuto'
    else
      s := s + ' segundo';

    if (n > 1) then
      s := s + 's';

    tempoPorExtenso := s;
end;

function MSecsToDateTime(MS:Integer):TDateTime;
var
  segs,hh,nn,ss,zz:Integer;
  ano,mes,dia:Integer;
begin
    segs := ms div 1000;
    hh   := (segs div 60) div 60;
    nn   := (segs div 60) mod 60;
    ss   := (segs mod 60);
    zz   := ms mod 1000;

    Result := EncodeTime(hh,nn,ss,zz);
end;

function tempoResumido(Tempo:TDateTime):String;
Var
  h,m,s,ms:Word;
  dias:Word;
begin
    DecodeTime(Tempo,h,m,s,ms);

    dias := StrToInt(FormatFloat('00000',Tempo));

    Result := '';
    if (dias > 0) then
    begin
       Result := result + IntToStr(dias)+'dia(s) ';
    End;
    
    If h > 0 Then
      Result := result + IntToStr(h)+'hr ';
    If m > 0 Then
      Result := result + IntToStr(m)+'min ';
    Result := result + IntToStr(s)+'s ';
end;

function GenerateGuid: string;
var
  ID: TGUID;
begin
  Result := '';

  if CoCreateGuid(ID) = S_OK then
     Result := GUIDToString(ID);
end;

Function VarToDouble(value:Variant):Double;
Begin
     If VarToStr(Value)='' Then
        Result := 0
     Else Result := Value;
End;

function StringToArray(Str:String):ArrayOfString;
Var
  Scanner : TScanner;
  y, iCount : integer;
begin
    Scanner             := TScanner.Create;
    Scanner.AdditionalChars := '_.';
    Try
       Scanner.AnalyzeStr(Str);

       iCount := 0;
       For y:=0 To Pred(Scanner.Count) do
         If Scanner.Token[y].Token in [ttIdentifier] Then
            Inc(iCount);

       SetLength(Result, iCount);

       iCount := 0;
       For y:=0 To Pred(Scanner.Count) do
         If Scanner.Token[y].Token in [ttIdentifier] Then
         Begin
             Result[iCount] := Scanner.TextI(y);
             inc(iCount);
         End;
    Finally
       Scanner.Free;
    End;
end;

procedure ClearDirectory(Dir:String);
Var
  SR:TSearchRec;
  x:Integer;
begin
    If Copy(Dir, Length(Dir), 1)<> '\' Then
       Dir := Dir + '\';

    x := FindFirst(Dir+'*.*', faArchive, SR);
    Try
      While x = 0 Do
      Begin
          DeleteFile(PChar(Dir + SR.Name));
          x := FindNext(SR);
      end;
    Finally
      FindClose(SR);
    End;
end;

Function CountChar(Texto:String ; C:Char) : Integer;
var
   i,vTot : Integer;
begin
   vTot := 0;

   For i := 1 to Length(Texto) do
   begin
      If (Texto[i] = C) or (LowerCase(Texto[i]) = LowerCase(C)) then
         vTot := vTot + 1;
   end;

   Result := vTot;
end;

procedure AtualizarLastExp(DataHora:TDateTime);
Var
  IniFile:TIniFile;
  Dia : Word;
  Mes : Word;
  Ano : Word;
  Hora: Word;
  Min : Word;
  Seg : Word;
  MS  : Word;
begin
    IniFile := TIniFile.Create(sIniName);
    Try
       DecodeDate(DataHora, Ano, Mes, Dia);
       DecodeTime(DataHora, Hora, Min, Seg, Ms);

       IniFile.WriteInteger('LASTEXP', 'ANO' , Ano);
       IniFile.WriteInteger('LASTEXP', 'MES' , Mes);
       IniFile.WriteInteger('LASTEXP', 'DIA' , Dia);
       IniFile.WriteInteger('LASTEXP', 'HORA', Hora);
       IniFile.WriteInteger('LASTEXP', 'MIN' , Min);
       IniFile.WriteInteger('LASTEXP', 'SEG' , Seg);
    Finally
       FreeAndNil(IniFile);
    End;
end;

procedure InitializeQuery(var Query:TIBQuery ; DBase:TIBDatabase=nil);
begin
    Query          := TIBQuery.Create(nil);
    if DBase = nil then
       Query.Database := glb_IBDataBase
    else
       Query.Database := DBase;

    Query.Close;
    Query.SQL.Clear;
end;

procedure InitializeTrans(var IBTrans:TIBTransaction ; DBase:TIBDatabase=nil);
begin
    IBTrans  := TIBTransaction.Create(nil);
    IBTrans.Params.Add('read_committed');
    IBTrans.Params.Add('rec_version');
    IBTrans.Params.Add('nowait');
    if DBase <> nil then
       DBase.DefaultTransaction := IBTrans;
end;

function GetMillenniumDB(ServerPath:String):String;
Var
  wtsDataSource:TIniFile;
  sPath:string;
begin
  If (Trim(ServerPath) <> '') And (Copy(ServerPath, Length(ServerPath), 1) <> '\') Then
      ServerPath := ServerPath + '\';

  wtsDataSource := TIniFile.Create(ServerPath + 'wtsDataSources.ini');
  try
    sPath := wtsDataSource.ReadString('DataSources', 'MILLENIUM', '');
    if Pos(':',sPath) > 0 then
       sPath := Copy(sPath, Pos(':',sPath)+1, MaxInt);

    if Pos(',',sPath) > 0 then
       sPath := Copy(sPath, 1, Pos(',',sPath)-1);

    Result := sPath;
  finally
    wtsDataSource.Free;
  end;
end;

function ParseFTPDirectories(TextoList:String):ArrayOfString;
var
  i:Integer;
  Texto:String;
  Item:String;
  IndexDelimitador:Integer;
  IndexSub:Integer;
const
  Delimitador = ';';
begin
    I := 0;
    SetLength(Result, i);

    If Trim(TextoList) = '' Then
      Exit;

    Texto := TextoList + Delimitador;
    Repeat
       IndexDelimitador := Pos(Delimitador, Texto);
       If IndexDelimitador = 0 Then
          Break;

       Item  := Copy(Texto, 1, IndexDelimitador-1);
       Texto := Copy(Texto, IndexDelimitador+1, MaxInt);

       SetLength(Result, i+1);
       Result[i] := Item;
       Inc(i);
    Until Pos(Delimitador, Texto) = 0;
end;
                  
procedure SetToDefault(rs:TwtsRecordset;add:Boolean=False);
var
   x,c:Integer;
   ss:TwtsSymbolDef;

   procedure DoExpression(s:TwtsSymbolDef);
   var r:Variant;
   begin
        if Length(Trim(s.Default))>0 then
        begin
             if not EvaluateExpression('',s,s.Default,r) then
             begin
                  if s.Format = 'B' then
                  begin
                       if StrToIntDef(r,0)=0 then
                          r := False
                       else
                          r := True;
                  end
             end;
             rs.FieldValuesByName[s.Name] := r;
        end;
   end;

begin
     c := rs.Struct.Count;
     If add or rs.Eof Then
     Begin
          rs.New;
//          rs.Add;
     End;

     for x:=0 to c-1 do
     begin
          ss := rs.Struct[x];

          Try
             DoExpression(ss);
          Except
             If ss<>nil then
                Raise Exception.Create(PChar('Erro atribuindo default ao campo '+ss.name));
          End;
     end;
     rs.Update;
end;

end.

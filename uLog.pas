unit uLog;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, FileCtrl;

type
  TStatus = (Erro, Aviso, Informacao, Sucesso, Falha);
const
  AStatus : Array[TStatus] of String = ('0','1','2','3','4');

type
  TAcao = (Exportacao, Importacao);

  PEstruturaLog=^TEstruturaLog;
  TEstruturaLog = Record
    Status,
    Acao,
    Objeto,
    Mensagem,
    Detalhe: String;
  end;

  TPEstruturaLogs = Array of TEstruturaLog;

  TLog = class(TComponent)
  private
    { Private declarations }
    FNivelLog:Byte;
    fDefaultDirectoryOutput:String;
    FLog: TStringList;
    FErros,
    FAvisos: Integer;
  protected
    { Protected declarations }
  public
    { Public declarations }
    constructor Create(Owner: TComponent); override;
    destructor Destroy; override;
    function GravaLog(Caminho: String ; ALogFileName:String ; Status:TStatus=Sucesso): String;
    function CarregaLog(Arquivo: String): TPEstruturaLogs;
    procedure AddLog(Nivel:Byte ; Status: TStatus; Msg: String; Diretorio:string; LogFileName:String ; Detalhes: String = '.');
    function ErrosCount:Integer;
    function GetFileLogName:String;
  published
    property QtdErros: Integer read FErros;
    property QtdAvisos: Integer read FAvisos;
    property Nivel: Byte read FNivelLog write FNivelLog;
    property DefaultDirectoryOutput:String read fDefaultDirectoryOutput write fDefaultDirectoryOutput;
  end;

const
  _FileLogName   = 'BMSync';
  LogMinimun     = 1;
  LogModerate    = 2;
  LogTechnician  = 3;
  LogMax         = 4;

implementation
{ TLog }

procedure TLog.AddLog(Nivel:Byte ; Status: TStatus; Msg: String; Diretorio:string; LogFileName:string ; Detalhes: String = '.');
Var sStatus, sAcao: String;
begin
  If Nivel <= FNivelLog Then
  Begin
      Case Status of
        Erro: sStatus := '0';
        Aviso: sStatus := '1';
        Informacao: sStatus := '2';
        Sucesso: sStatus := '3';
        Falha: sStatus := '4';
      end;

      if (sStatus = '0') or (sStatus = '4') then
        FErros := FErros + 1;

      if sStatus = '1' then
        FAvisos := FAvisos + 1;
      if Trim(Detalhes) = '' then
        Detalhes := '.';

      Detalhes := StringReplace(Detalhes,#10,'&',[rfReplaceAll]);
      Detalhes := StringReplace(Detalhes,#13,'&',[rfReplaceAll]);

      FLog.Add(Format('%s;%s;%s;', [sStatus, Msg, Detalhes]));

      If Diretorio <> '' then
         GravaLog(Diretorio, LogFileName, Status)
      else
      if fDefaultDirectoryOutput <> '' Then
         GravaLog(fDefaultDirectoryOutput, LogFileName);
  End;
end;

constructor TLog.Create(Owner: TComponent);
begin
  inherited;
  FLog := TStringList.Create;
  FAvisos := 0;
  FErros := 0;
  FNivelLog := LogMax;
end;

destructor TLog.Destroy;
begin
  inherited;
  FreeAndNil(FLog);
end;

function TLog.GravaLog(Caminho: String; ALogFileName:String ; Status:TStatus=Sucesso): String;
Var
  Path: String;
  fileName:String;
begin
  ForceDirectories(Caminho);

  if ALogFileName <> '' then
     fileName := ALogFileName
  else
     fileName := _FileLogName;

  Case Status of
    Erro    : Path := Caminho + ChangeFileExt(fileName,'')+ '.Err';
    Sucesso : Path := Caminho + ChangeFileExt(fileName,'')+ '.Log';
  else
    Path := Caminho + fileName;
  end;
  
  FLog.SaveToFile(Path);
  Result := Path;
end;

function TLog.CarregaLog(Arquivo: String): TPEstruturaLogs;
Var Log, FLinha: TStringList;
    I, J: Integer;
    EstruturaLogs: TPEstruturaLogs;
begin
  Log := TStringList.Create;
  FLinha := TStringList.Create;
  Log.LoadFromFile(Arquivo);
  SetLength(EstruturaLogs, Log.Count);
  for I := 0 to Log.Count - 1 do
  begin
    FLinha.Clear;
    ExtractStrings([';'], [' '], PChar(Log[I]), FLinha);
    EstruturaLogs[I].Status   := FLinha[0];
    EstruturaLogs[I].Mensagem := FLinha[1];
    EstruturaLogs[I].Detalhe := FLinha[2];
  end;
  FreeAndNil(Log);
  FreeAndNil(FLinha);
  Result := EstruturaLogs;
end;



function TLog.ErrosCount: Integer;
var
  I:Integer;
  FLinha:TStringList;
begin
    FLinha := TStringList.Create;
    Result := 0;
    
    for I := 0 to Pred(FLog.Count) do
    begin
      FLinha.Clear;
      ExtractStrings([';'], [' '], PChar(FLog[I]), FLinha);

      If FLinha[0] = '0' Then
         Inc(Result);
    end;
end;

function TLog.GetFileLogName: String;
begin
    Result := _FileLogName;
end;

end.

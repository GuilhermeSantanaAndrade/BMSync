unit Declarations;

interface

uses SysUtils, Forms, IBDatabase;

const
   Output_TypeStruct=0;
   Input_TypeStruct =1;

type
  TFieldPay_x_FieldFilho = record
    FieldPai:String;
    FieldFilho:String;
  end;

  ArrOfFieldPai_FieldFilho = Array of TFieldPay_x_FieldFilho;

  PExportConfig = ^TExportConfig;
  TExportConfig = record
    NameArq:String;
    MethodExport :String;
    Prioridade:Integer;
    TypeStruct:Integer;
    Filho:PExportConfig;
    FieldsPaixFilho:ArrOfFieldPai_FieldFilho;
    TriggerControl, LastUpdateControl:Boolean;
    TriggerFieldTabela, TriggerFieldID:String;
  end;

  ArrayExportConfigs = Array of TExportConfig;

var
  sAppPath:String;
  sIniName:String;
  sDefaultTableName, sDefaultGeneratorName:String;
  glb_IBDataBase    : TIBDataBase;
  glb_MILLENNIUM_DATABASE : TIBDataBase;
  glb_IBTransaction : TIBTransaction;
  glb_MILLENNIUM_Transaction : TIBTransaction;

const
  _pastaErros       = 'Erros\';
  _pastaProcessados = 'Processados\';
  _pastaLog         = 'Log\';
  _DBName           = 'SYNC.dat';
  _TriggerAlter     = 'UPDATE';
  _TriggerInsert    = 'INSERT';
  _TriggerDelete    = 'DELETE';

implementation

initialization
  sAppPath          := ExtractFilePath(Application.ExeName);
  sIniName          := sAppPath + 'BMSync.ini';
  sDefaultTableName := 'FBRECS';
  sDefaultGeneratorName := 'GN9999';

end.

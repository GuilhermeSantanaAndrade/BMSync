program BMSync;

uses
  Forms,
  uMain in 'uMain.pas' {frmMain},
  uConfig in 'uConfig.pas' {frmConfig},
  MyFuncs in 'MyFuncs.pas',
  uExport in 'uExport.pas',
  uImport in 'uImport.pas',
  Declarations in 'Declarations.pas',
  Visualizador in 'Visualizador.pas' {frmVisualizador},
  uSenha in 'uSenha.pas' {frmSenha},
  uLog in 'uLog.pas',
  uActivation in 'BMSyncAct\uActivation.pas',
  UConectFtp in 'UConectFtp.pas',
  gsftp in 'gsftp.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'BM Synchronizer';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.

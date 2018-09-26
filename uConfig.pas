unit uConfig;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, wtsMethodFrame, ExtCtrls, ComCtrls, LinkList, IniFiles, MyFuncs, FileUtils,
  Declarations, Menus, gsftp, Buttons;

type
  TModo = (mExportacao, mImportacao);
  TModoTransf = (mNone, mFTP, mREDE);

  TConfigsFTP = record
    Ativo:Boolean;
    Modo,
    DirRecebimentos,
    DirEnvios,
    Servidorftp:String;
    Passiveftp,
    Delafterupload,
    Delafterdownload:Boolean;
    Porta:Integer;
    User,
    Password,
    Servidorproxy,
    Proxytype:string;
  end;

  TConfigs = record
    Modo       :TModo;
    ServerPath :String;
    //Export
    DirGravacao:String;
    TempoExp   :String[8];
    TempoExpSegundosTotais :Integer;
    TableMaterializada:String[40];
    AutoExp    :Boolean;
    //Import
    DirLeitura :String;
    TempoImp   :String[8];
    TempoImpSegundosTotais :Integer;
    AutoImp    :Boolean;
    Versao     :String;
    FTP:TConfigsFTP;
  end;

  TfrmConfig = class(TForm)
    pnl3: TPanel;
    lbl5: TLabel;
    cboModo: TFlatComboBox;
    LinkList1: TLinkList;
    GroupDivider3: TGroupDivider;
    pmPopupFunctions: TPopupMenu;
    mnuVisualizarArquivoBinario: TMenuItem;
    pnl4: TPanel;
    pnl2: TPanel;
    pnlImportacao: TPanel;
    GroupDivider2: TGroupDivider;
    lbl3: TLabel;
    lbl4: TLabel;
    txtDirLeitura: TFlatEdit;
    hrImport: TDateTimePicker;
    chkImpAuto: TCheckBox;
    pnlExportacao: TPanel;
    GroupDivider1: TGroupDivider;
    lbl1: TLabel;
    lbl2: TLabel;
    txtDirGravacao: TFlatEdit;
    hrExport: TDateTimePicker;
    chkExpAuto: TCheckBox;
    pnl1: TPanel;
    pnl5: TPanel;
    GroupDivider4: TGroupDivider;
    lbl7: TLabel;
    lblDirComum: TLabel;
    HintHelp1: TImage;
    cbModoTransf: TFlatComboBox;
    txtDirEnvios: TFlatEdit;
    pnlFTP: TPanel;
    lbl6: TLabel;
    lbl9: TLabel;
    lbl11: TLabel;
    lbl12: TLabel;
    lbl13: TLabel;
    lbl14: TLabel;
    EdServidorFtp: TFlatEdit;
    EdUsuario: TFlatEdit;
    CbTpProxy: TFlatComboBox;
    EdServidorProxy: TFlatEdit;
    chkAfterUpload: TFlatCheckBox;
    chkAfterDownload: TFlatCheckBox;
    EdPorta: TFlatEdit;
    EdPass: TFlatEdit;
    ChkPassive: TFlatCheckBox;
    lbl8: TLabel;
    txtDirRecebimentos: TFlatEdit;
    HintHelp2: TImage;
    btn1: TSpeedButton;
    btn2: TSpeedButton;
    chkAtivo: TFlatCheckBox;
    lbl10: TLabel;
    cboVersao: TFlatComboBox;
    procedure cboModoChange(Sender: TObject);
    procedure LinkList1Links0Click(Sender: TObject);
    procedure LinkList1Links1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure LinkList1Links2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure mnuVisualizarArquivoBinarioClick(Sender: TObject);
    procedure cbModoTransfChange(Sender: TObject);
  private
    SenhaOK:Boolean;
  public
    { Public declarations }
    class procedure Execute(AParent:TWinControl);
  end;

  function ValidateConfigs(Configs:TConfigs ; CanRaise:Boolean=True):Boolean;
  function GetIniConfigs:TConfigs;
  procedure SetIniConfigs(Configs:TConfigs);
  Function StrToModoTransf(Value:String):TModoTransf;
  
implementation

uses uMain, uSenha, Visualizador;

{$R *.DFM}

procedure TfrmConfig.cboModoChange(Sender: TObject);
begin
    If AnsiUpperCase(cboModo.Text) = 'EXPORTAÇÃO' Then
    Begin
       pnlExportacao.Visible := True;
       pnlImportacao.Visible := False;
    end else
    if AnsiUpperCase(cboModo.Text) = 'IMPORTAÇÃO' then
    begin
       pnlExportacao.Visible := False;
       pnlImportacao.Visible := True;
    end;
end;

procedure TfrmConfig.LinkList1Links0Click(Sender: TObject);
var
  Configs:TConfigs;
begin
    If AnsiUpperCase(cboModo.Text) = 'EXPORTAÇÃO' Then
    Begin                      
        Configs.DirGravacao := txtDirGravacao.Text;
        If (Trim(Configs.DirGravacao) <> '') And (Copy(Configs.DirGravacao, Length(Configs.DirGravacao), 1) <> '\') Then
           Configs.DirGravacao := Configs.DirGravacao + '\';
        Configs.Modo        := mExportacao;
        Configs.TempoExp    := TimeToStr(hrExport.Time);
        Configs.AutoExp     := chkExpAuto.Checked;
    End else
    if AnsiUpperCase(cboModo.Text) = 'IMPORTAÇÃO' then
    begin
        Configs.DirLeitura  := txtDirLeitura.Text;
        If (Trim(Configs.DirLeitura) <> '') And (Copy(Configs.DirLeitura, Length(Configs.DirLeitura), 1) <> '\') Then
           Configs.DirLeitura := Configs.DirLeitura + '\';
        Configs.Modo        := mImportacao;
        Configs.TempoImp    := TimeToStr(hrImport.Time);
        Configs.AutoImp     := chkImpAuto.Checked;
    end;

    Configs.Versao               := cboVersao.Text;
    Configs.FTP.Ativo            := ChkAtivo.Checked;
    If AnsiUpperCase(cbModoTransf.Text) = 'FTP' Then
    Begin
       Configs.FTP.Modo             := 'FTP';
       Configs.FTP.ServidorFTP      := EdServidorFtp.Text;
       Configs.FTP.PassiveFTP       := ChkPassive.Checked;
       Configs.FTP.DelAfterUpload   := chkAfterUpload.Checked;
       Configs.FTP.DelAfterDownload := chkAfterDownload.Checked;
       Configs.FTP.User             := EdUsuario.TEXT;
       Configs.FTP.Password         := EdPass.Text;
       Configs.FTP.ProxyType        := CbTpProxy.Text;
       Configs.FTP.ServidorProxy    := EdServidorProxy.Text;
       Configs.FTP.Porta            := StrToIntDef(EdPorta.Text,0);
    end else
    If AnsiUpperCase(cbModoTransf.Text) = 'REDE' Then
    Begin
       Configs.FTP.Modo    := 'REDE';
    End;

    Configs.FTP.DirEnvios       := txtDirEnvios.Text;
    Configs.FTP.DirRecebimentos := txtDirRecebimentos.Text;

    ValidateConfigs(Configs);
    SetIniConfigs(Configs);
    Close;
end;

procedure TfrmConfig.LinkList1Links1Click(Sender: TObject);
begin
    Close;
end;

procedure TfrmConfig.FormClose(Sender: TObject; var Action: TCloseAction);
begin
    Action  := caFree;
    frmMain.SetFormStatus(screenDefault, True);
end;

class procedure TfrmConfig.Execute(AParent:TWinControl);
var
  frmConfig: TfrmConfig;
  Configs:TConfigs;
  procedure LoadConfigsOnForm(AConfigs:TConfigs);
  Begin
      With frmConfig Do
      Begin
          txtDirGravacao.Text := Configs.DirGravacao;
          txtDirLeitura.Text  := Configs.DirLeitura;
          hrExport.Time       := StrToTime(Configs.TempoExp);
          hrImport.Time       := StrToTime(Configs.TempoImp);          
          chkExpAuto.Checked  := Configs.AutoExp;
          chkImpAuto.Checked  := Configs.AutoImp;

          if Configs.Modo = mExportacao Then
             cboModo.ItemIndex := 0
          Else
             cboModo.ItemIndex := 1;

          if Configs.Versao = '2009' Then
             cboVersao.ItemIndex := 0
          Else
          if Configs.Versao = '5' Then
             cboVersao.ItemIndex := 1
          Else
             cboVersao.ItemIndex := 0;

          ChkAtivo.Checked     := Configs.FTP.Ativo;
          if StrToModoTransf(Configs.FTP.Modo) = mFTP Then
             cbModoTransf.ItemIndex := 1
          Else
             cbModoTransf.ItemIndex := 0;

          txtDirEnvios.Text        := Configs.FTP.DirEnvios;
          txtDirRecebimentos.Text  := Configs.FTP.DirRecebimentos;

          EdServidorFtp.Text     := Configs.FTP.Servidorftp;
          ChkPassive.Checked     := Configs.FTP.Passiveftp;
          EdUsuario.Text         := Configs.FTP.User;
          EdPass.Text            := Configs.FTP.Password;
          CbTpProxy.ItemIndex    := CbTpProxy.Items.IndexOf( Configs.FTP.Proxytype );
          EdServidorProxy.Text   := Configs.FTP.Servidorproxy;
          EdPorta.Text           := IntToStr(Configs.FTP.Porta);
          chkAfterUpload.Checked := Configs.FTP.Delafterupload;
          chkAfterDownload.Checked := Configs.FTP.Delafterdownload;
      End;
  end;
begin
    frmConfig := TfrmConfig.Create(Application);
    With frmConfig Do
    Begin
        Parent := AParent;
        Align  := alClient;
        HintHelp1.Hint := 'Diretórios de envio de arquivos. (Separados por vírgula) ';
        HintHelp2.Hint := 'Diretórios de recebimentos de arquivos. (Separados por vírgula) ';

        Configs := GetIniConfigs;
        LoadConfigsOnForm(Configs);

        cboModoChange(nil);
        cbModoTransfChange(nil);
        Show;
    End;
end;

function ValidateConfigs(Configs:TConfigs ; CanRaise:Boolean=True):Boolean;
begin
    Result := True;
//    If not DirectoryExists(Configs.FTP.Dirrede) Then
//    Begin
//       Result := False;
//       If CanRaise Then raise Exception.Create('Diretório comum inválido.');
//    End;

    if Configs.Modo = mExportacao Then
    Begin
        If not DirectoryExists(Configs.DirGravacao) Then
        Begin
           Result := False;
           If CanRaise Then raise Exception.Create('Diretório de Gravação inválido.');
        End;

        If not HoraValida(Configs.TempoExp) Then
        Begin
           Result := False;
           If CanRaise Then raise Exception.Create('Hora Exportar não é inválida.');
        End;
    End else
    if Configs.Modo = mImportacao then
    begin
        If not DirectoryExists(Configs.DirLeitura) Then
        Begin
           Result := False;
           If CanRaise Then raise Exception.Create('Diretório de Leitura inválido.');
        End;
        If not HoraValida(Configs.TempoImp) Then
        Begin
           Result := False;
           If CanRaise Then raise Exception.Create('Hora Importação não é inválida.');
        End;
    end;
end;

function GetIniConfigs:TConfigs;
var
  ArqIni:TIniFile;
  TxtFile:TextFile;
  hr,min,seg,ms:Word;
begin
    If not FileExists(sIniName) Then
    begin
       AssignFile(TxtFile, sIniName);
       ReWrite(txtFile);
       WriteLn(txtFile, '[Geral]');
       CloseFile(txtFile);
    end;

    ArqIni := TIniFile.Create(sIniName);
    Try
      Result.Versao             := ArqINI.ReadString('Geral', 'Versao', '2009');
      
      if UpperCase(ArqINI.ReadString('Geral', 'Modo', 'EXPORTACAO')) = 'EXPORTACAO' Then
         Result.Modo     := mExportacao
      else
         Result.Modo     := mImportacao;

      If Result.Modo = mExportacao Then
      Begin
          if not ArqIni.SectionExists('LASTEXP') Then
          begin
              AtualizarLastExp(Now);
          end else
          begin
              if (ArqINI.ReadInteger('LASTEXP', 'ANO', 0) = 0) Or
                 (ArqINI.ReadInteger('LASTEXP', 'MES', 0) = 0) Or
                 (ArqINI.ReadInteger('LASTEXP', 'DIA', 0) = 0) Then
                 AtualizarLastExp(Now);
          end;
      end else
      begin
          if ArqIni.SectionExists('LASTEXP') Then
             ArqIni.EraseSection('LASTEXP');
      end;

      Result.DirGravacao        := ArqINI.ReadString('Export', 'DirGravacao','');
      Result.TempoExp           := ArqINI.ReadString('Export', 'TempoExp',   '00:05:00');
      Result.TableMaterializada := ArqINI.ReadString('Export', 'MatName',   sDefaultTableName);
      Result.AutoExp            := ArqINI.ReadBool(  'Export', 'AutoExp',   False);
      Result.ServerPath         := ArqINI.ReadString('Geral', 'ServerPath', 'c:\wts');

      DecodeTime(StrToTime(Result.TempoExp),hr,min,seg,ms);
      seg := seg + (min * 60);
      seg := seg + (hr * 3600);
      Result.TempoExpSegundosTotais := seg;

      Result.DirLeitura         := ArqINI.ReadString('Import', 'DirLeitura', '');
      Result.TempoImp           := ArqINI.ReadString('Import', 'TempoImp',   '00:05:00');
      Result.AutoImp            := ArqINI.ReadBool(  'Import', 'AutoImp',   False);

      DecodeTime(StrToTime(Result.TempoImp),hr,min,seg,ms);
      seg := seg + (min * 60);
      seg := seg + (hr * 3600);
      Result.TempoImpSegundosTotais := seg;

      Result.FTP.Ativo            := ArqIni.ReadBool  ('FTP', 'ATIVO'            ,False);
      Result.FTP.DirEnvios        := ArqIni.ReadString('FTP', 'DIRENVIOS'        ,'');
      Result.FTP.DirRecebimentos  := ArqIni.ReadString('FTP', 'DIRRECEBIMENTOS'  ,'');
      
      Result.FTP.Modo             := ArqIni.ReadString('FTP', 'MODO'             ,'');
      Result.FTP.ServidorFTP      := ArqIni.ReadString('FTP', 'SERVIDORFTP'      ,'');
      Result.FTP.PassiveFTP       := ArqIni.ReadBool  ('FTP', 'PASSIVEFTP'       ,False);
      Result.FTP.DelAfterUpload   := ArqIni.ReadBool  ('FTP', 'DELAFTERUPLOAD'   ,False);
      Result.FTP.DelAfterDownload := ArqIni.ReadBool  ('FTP', 'DELAFTERDOWNLOAD' ,False);
      Result.FTP.User             := ArqIni.ReadString('FTP', 'USER'             ,'');
      Result.FTP.Password         := ArqIni.ReadString('FTP', 'PASSWORD'         ,'');
      Result.FTP.ProxyType        := ArqIni.ReadString('FTP', 'PROXYTYPE'        ,'');
      Result.FTP.ServidorProxy    := ArqIni.ReadString('FTP', 'SERVIDORPROXY'    ,'');
      Result.FTP.Porta            := ArqIni.ReadInteger('FTP', 'PORTA'           ,0);
    Finally
      ArqIni.Free;
    End;
end;

procedure SetIniConfigs(Configs:TConfigs);
var
  ArqIni:TIniFile;
  TxtFile:TextFile;
begin
    If not FileExists(sIniName) Then
    begin
       AssignFile(TxtFile, sIniName);
       ReWrite(txtFile);
       WriteLn(txtFile, '[Geral]');
       CloseFile(txtFile);
    end;

    ArqIni := TIniFile.Create(sIniName);
    Try
      if Configs.Modo = mExportacao Then
      begin
         ArqINI.WriteString('Geral',  'Modo',       'EXPORTACAO');
         ArqINI.WriteString('Export', 'DirGravacao',Configs.DirGravacao);
         ArqINI.WriteString('Export', 'TempoExp',   Configs.TempoExp);
         ArqINI.WriteString('Export', 'MatName',    sDefaultTableName);
         ArqINI.WriteBool(  'Export', 'AutoExp',    Configs.AutoExp);
         if ArqIni.SectionExists('Import') Then
            ArqIni.EraseSection('Import');
      end else
      begin
         ArqINI.WriteString('Geral',  'Modo',       'IMPORTACAO');
         ArqINI.WriteString('Import', 'DirLeitura', Configs.DirLeitura);
         ArqINI.WriteString('Import', 'TempoImp',   Configs.TempoImp);
         ArqINI.WriteBool(  'Import', 'AutoImp',    Configs.AutoImp);
         if ArqIni.SectionExists('Export') Then
            ArqIni.EraseSection('Export');
      end;

      If StrToModoTransf(Configs.FTP.Modo) = mFTP Then
      begin
         ArqIni.DeleteKey('FTP', 'DIRREDE');
      end else
      If StrToModoTransf(Configs.FTP.Modo) = mREDE Then
      begin
         ArqIni.DeleteKey('FTP', 'DIRFTP');
         ArqIni.DeleteKey('FTP', 'SERVIDORFTP');
         ArqIni.DeleteKey('FTP', 'PASSIVEFTP');
         ArqIni.DeleteKey('FTP', 'DELAFTERUPLOAD');
         ArqIni.DeleteKey('FTP', 'DELAFTERDOWNLOAD');
         ArqIni.DeleteKey('FTP', 'USAR');
         ArqIni.DeleteKey('FTP', 'PASSWORD');
         ArqIni.DeleteKey('FTP', 'PROXYTYPE');
         ArqIni.DeleteKey('FTP', 'SERVIDORPROXY');
         ArqIni.DeleteKey('FTP', 'PORTA');
      end;

      ArqINI.WriteString('Geral', 'Versao', Configs.Versao);
      ArqIni.WriteBool  ('FTP', 'ATIVO'            , Configs.FTP.Ativo           );
      ArqIni.WriteString('FTP', 'DIRRECEBIMENTOS'  , Configs.FTP.DirRecebimentos );
      ArqIni.WriteString('FTP', 'DIRENVIOS'        , Configs.FTP.DirEnvios       );

      ArqIni.WriteString('FTP', 'MODO'             , Configs.FTP.Modo            );
      ArqIni.WriteString('FTP', 'SERVIDORFTP'      , Configs.FTP.ServidorFTP     );
      ArqIni.WriteBool  ('FTP', 'PASSIVEFTP'       , Configs.FTP.PassiveFTP      );
      ArqIni.WriteBool  ('FTP', 'DELAFTERUPLOAD'   , Configs.FTP.DelAfterUpload  );
      ArqIni.WriteBool  ('FTP', 'DELAFTERDOWNLOAD' , Configs.FTP.DelAfterDownload);
      ArqIni.WriteString('FTP', 'USER'             , Configs.FTP.User            );
      ArqIni.WriteString('FTP', 'PASSWORD'         , Configs.FTP.Password        );
      ArqIni.WriteString('FTP', 'PROXYTYPE'        , Configs.FTP.ProxyType       );
      ArqIni.WriteString('FTP', 'SERVIDORPROXY'    , Configs.FTP.ServidorProxy   );
      ArqIni.WriteInteger('FTP','PORTA'            , Configs.FTP.Porta           );
    Finally
      ArqIni.Free;
    End;
end;

procedure TfrmConfig.LinkList1Links2Click(Sender: TObject);
Var
  p:TPoint;
begin
     If (SenhaOK) or (TfrmSenha.Execute) Then
     Begin
         SenhaOK := True;
         p := TLink(sender).Rect.TopLeft;
         p := LinkList1.ClientToScreen(p);

         pmPopupFunctions.Popup(p.x,p.y);
     End;
end;

procedure TfrmConfig.FormCreate(Sender: TObject);
begin
    SenhaOK := False;
end;

procedure TfrmConfig.mnuVisualizarArquivoBinarioClick(Sender: TObject);
begin
    showmessage('Função temporariamente removida.');
//    TfrmVisualizador.Execute;
end;

procedure TfrmConfig.cbModoTransfChange(Sender: TObject);
begin
    If AnsiUpperCase(cbModoTransf.Text) = 'FTP' Then
    Begin
       pnlFTP.Visible      := True;
    end else
    if AnsiUpperCase(cbModoTransf.Text) = 'REDE' then
    begin
       pnlFTP.Visible      := False;
    end;
end;

Function StrToModoTransf(Value:String):TModoTransf;
Begin
  if Value = 'FTP' Then
    Result := mFTP
  Else if Value = 'REDE' Then
    Result := mREDE
  Else // Todos os outros casos serão considerados proxyNone
    Result := mNone;
End;

Function ModoTransfToStr( ModoTransf:TModoTransf ):String;
Begin
  Case ModoTransf of
     mFTP     : Result:= 'FTP';
     mREDE    : Result:= 'Rede';
  Else
    Result := 'mNone';
  End;
End;

end.

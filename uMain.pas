unit uMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, wtsClient, wtsStream,
  ExtCtrls, LinkList, uConfig, IniFiles, MyFuncs, uExport, uImport,
  StdCtrls, wtsMethodFrame, Declarations, uActivation, UConectFTP, uLog, math,
  IBDatabase, Db, IBCustomDataSet, IBQuery, gsFtp;

type
  TFormStatus = (screenDefault, screenConfig, screenCargaInicial, screenExportando_Auto,
                 screenExportando_Manual, screenImportando, screenAtualizandoGUIDs, screenDownloadingFiles);

  TfrmMain = class(TForm)
    LinkList1: TLinkList;
    pnlMain: TPanel;
    pnlWarning: TPanel;
    HintHelp1: TImage;
    lblWarning: TLabel;
    pnlTempo: TPanel;
    lbl_capt_ProxProcessamento: TLabel;
    lbl_ProxProcessamento: TLabel;
    lbl_capt_processar_a_cada: TLabel;
    lbl_processar_a_Cada: TLabel;
    chkAutomaticamente: TCheckBox;
    pnlImgTempo: TPanel;
    img1: TImage;
    TimerExport_Import: TTimer;
    pnl_erros: TPanel;
    lbl1: TLabel;
    lblResumoErros: TLabel;
    lbl3: TLabel;
    lblQtdeErros: TLabel;
    pnl_ButtonErros: TPanel;
    img2: TImage;
    lbl5: TLabel;
    lblTitleErros: TLabel;
    pictureERROR: TImage;
    pictureOK: TImage;
    lbl2: TLabel;
    lblDirErros: TLabel;
    IBDatabase1: TIBDatabase;
    IBTransaction1: TIBTransaction;
    IBDatabaseMILLENNIUM: TIBDatabase;
    IBTransaction2: TIBTransaction;
    TimerEnvioFTP: TTimer;
    Imgdown: TImage;
    ImgUp: TImage;
    lblStatusFTP: TLabel;
    bvlStatus1: TBevel;
    bvlStatus2: TBevel;
    lbl_Upload_Down: TLabel;
    lblTipo_Imp_Exp: TLabel;
    lbl4: TLabel;
    procedure LinkList1Links2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure LinkList1Links1Click(Sender: TObject);
    procedure LinkList1Links0Click(Sender: TObject);
    procedure pnlTempoResize(Sender: TObject);
    procedure img1Click(Sender: TObject);
    procedure pnlMainResize(Sender: TObject);
    procedure TimerExport_ImportTimer(Sender: TObject);
    procedure chkAutomaticamenteClick(Sender: TObject);
    procedure pnl_errosResize(Sender: TObject);
    procedure img2Click(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure TimerEnvioFTPTimer(Sender: TObject);
  private
    fFormStatus:TFormStatus;
    IniConfigs:TConfigs;
    AcumTimerParaProcessar:Integer;
    procedure AtualizaTimer;
    procedure CheckErrors;
    procedure WMCheckErrors(var Msg: TWMSysCommand); Message WM_CheckErros;
    procedure Download_FTP_Files;
  public
    AppStarted, Processing:Boolean;
    procedure AtualizaTela;
    procedure SetFormStatus(Status:TFormStatus ; Atualizar:Boolean=False);
  end;

  TSendArqs = Class(TThread)
  private

  protected
    procedure Execute; override;
  End;

var
  frmMain: TfrmMain;
  fSend:TSendArqs;
  fSendTime:Cardinal;
  fSend_In_Progress:Boolean;

function CreateFTP: IConnectFTP;

implementation

{$R *.DFM}

procedure TfrmMain.AtualizaTela;
begin
    LinkList1.Links[0].Visible := False;
    LinkList1.Links[1].Visible := False;
    LinkList1.Links[2].Visible := False;

    Case fFormStatus of
      screenDefault :
      Begin
          LinkList1.Visible          := True;
          LinkList1.Links[2].Visible := True;
          pnlTempo.Visible           := True;

          IniConfigs := GetIniConfigs;
          If ValidateConfigs(IniConfigs, False) Then
          Begin
             pnlWarning.Visible := False;
             If IniConfigs.Modo = mExportacao Then
             begin
                frmMain.Caption := 'BM SYNC (EXPORTADOR)';
                lblTipo_Imp_Exp.Caption := 'EXPORTADOR';
                lblStatusFTP.Color      := $00FF7171;
                LinkList1.Links[1].Visible := True
             end else
             begin
                frmMain.Caption         := 'BM SYNC (IMPORTADOR)';
                lblTipo_Imp_Exp.Caption := 'IMPORTADOR';
                lblStatusFTP.Color      := $0000FF80;
                LinkList1.Links[0].Visible := True;
             end;

             //*** FTP ***
             bvlStatus1.Left     := 7;
             lbl_Upload_Down.Left:= 7;
             bvlStatus2.Left     := 7;
             bvlStatus1.Visible  := (IniConfigs.Modo = mExportacao); //Upload
             bvlStatus2.Visible  := (IniConfigs.Modo = mImportacao); //Download

             ImgUp.Left          := bvlStatus1.Left;
             ImgUp.Top           := bvlStatus1.Top;

             ImgDown.Left        := bvlStatus1.Left;
             ImgDown.Top         := bvlStatus1.Top;

             if StrToModoTransf(IniConfigs.FTP.Modo) = mFTP then
                lblStatusFTP.Caption := ' TRANSF. FTP: '+ IIF(IniConfigs.FTP.Ativo,'"ATIVO"','INATIVO')
             else
                lblStatusFTP.Caption := ' TRANSF. REDE: '+ IIF(IniConfigs.FTP.Ativo,'"ATIVO"','INATIVO');
             //***********

             If IniConfigs.Modo = mExportacao Then
             Begin
                 chkAutomaticamente.Checked         := IniConfigs.AutoExp;
                 lbl_capt_processar_a_cada.Caption  := 'Exporta��o a cada';
                 lbl_capt_ProxProcessamento.Caption := 'Pr�xima Exporta��o em';

                 lbl_processar_a_cada.Caption       := tempoResumido(StrToTime(IniConfigs.TempoExp));
                 If IniConfigs.AutoExp Then
                    lbl_ProxProcessamento.Caption := tempoResumido(StrToTime(IniConfigs.TempoExp))
                 Else
                    lbl_ProxProcessamento.Caption := 'Manual';

                 lblDirErros.Caption := IniConfigs.DirGravacao + _pastaErros;
             End Else
             Begin
                 chkAutomaticamente.Checked         := IniConfigs.AutoImp;
                 lbl_processar_a_cada.Caption       := tempoResumido(StrToTime(IniConfigs.TempoImp));
                 lbl_capt_processar_a_cada.Caption  := 'Importa��o a cada';
                 lbl_capt_ProxProcessamento.Caption := 'Pr�xima Importa��o em';

                 If IniConfigs.AutoImp Then
                    lbl_ProxProcessamento.Caption := tempoResumido(StrToTime(IniConfigs.TempoImp))
                 Else
                    lbl_ProxProcessamento.Caption := 'Manual';

                 lblDirErros.Caption := IniConfigs.DirLeitura + _pastaErros;
             end;
          end else
          Begin
             lblWarning.Caption := 'Configura��es inv�lidas.';
             pnlWarning.Visible := True;
          end;

          CheckErrors;
      end;
      screenConfig :
      Begin
          LinkList1.Visible          := False; 
          LinkList1.Links[2].Visible := False;
          pnlTempo.Visible           := False;
      end;
      screenCargaInicial :
      Begin
          lblWarning.Caption := 'Aguarde, Realizando Carga de dados...';
          pnlWarning.Visible := True;
      end;
      screenExportando_Auto :
      Begin
          lblWarning.Caption := 'Exportando...';
          pnlWarning.Visible := True;
          LinkList1.Links[0].Visible := False;
          LinkList1.Links[1].Visible := False;
          LinkList1.Links[2].Visible := False;
      end;
      screenExportando_Manual :
      Begin
          lblWarning.Caption := 'Exportando...';
          pnlWarning.Visible := True;
          LinkList1.Links[0].Visible := False;
          LinkList1.Links[1].Visible := False;
          LinkList1.Links[2].Visible := False;
      end;
      screenImportando :
      Begin
          lblWarning.Caption := 'Importando...';
          pnlWarning.Visible := True;
          LinkList1.Links[0].Visible := False;
          LinkList1.Links[1].Visible := False;
          LinkList1.Links[2].Visible := False;
      end;
      screenDownloadingFiles :
      Begin
          lblWarning.Caption := 'Baixando arquivos '+ IIF(StrToModoTransf(IniConfigs.FTP.Modo) = mFTP, 'do FTP', 'da Rede') +'...';
          pnlWarning.Visible := True;
          LinkList1.Links[0].Visible := False;
          LinkList1.Links[1].Visible := False;
          LinkList1.Links[2].Visible := False;
      end;
      screenAtualizandoGUIDs:
      Begin
          lblWarning.Caption := 'Aguarde, realizando atualiza��o inicial de GUIDs...';
          pnlWarning.Visible := True;
          LinkList1.Links[0].Visible := False;
          LinkList1.Links[1].Visible := False;
          LinkList1.Links[2].Visible := False;
      end;
    End;
    pnlWarning.Width := pnlMain.Width;
    pnlWarning.Top   := (pnlMain.Height div 2) - (pnlWarning.Height div 2);
    pnlWarning.Left  := pnlMain.Left;

    lblWarning.Left := (pnlWarning.Width div 2) - (lblWarning.Width div 2);
    HintHelp1.Left  := lblWarning.Left - (HintHelp1.Width + 5);
    Application.ProcessMessages;
end;

procedure TfrmMain.LinkList1Links2Click(Sender: TObject);
begin
    frmMain.SetFormStatus(screenConfig, True);
    TfrmConfig.Execute(pnlMain);
    IniConfigs := GetIniConfigs;
end;

procedure TfrmMain.SetFormStatus(Status: TFormStatus  ; Atualizar:Boolean=False);
begin
    fFormStatus := Status;
    Case fFormStatus of
      screenDefault :
      Begin
          AcumTimerParaProcessar := 0;
          If (((IniConfigs.Modo = mExportacao) And IniConfigs.AutoExp) or
             ((IniConfigs.Modo = mImportacao) And IniConfigs.AutoImp)) And ValidateConfigs(IniConfigs, False) Then
             TimerExport_Import.Enabled := True;
      end;
      screenConfig :
      Begin
          If TimerExport_Import.Enabled Then
             TimerExport_Import.Enabled := False;
      end;
      screenCargaInicial :;
      screenExportando_Auto :;
      screenExportando_Manual :;
      screenImportando :;
    Else
    
    End;

    If Atualizar Then
       AtualizaTela;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
Var
  Act:TActivation;
//  fLog:TLog;
begin
//    fLog := TLog.Create(nil);
//    fLog.DefaultDirectoryOutput := ExtractFilePath(ParamStr(0));

//    If not FileExists('SYNC.dat') then
//       raise Exception.Create('Arquivo Sync.dat n�o foi encontrado.');

    IniConfigs := GetIniConfigs;

    // SYNC.DAT
//    IBDatabase1.DatabaseName := sAppPath + 'SYNC.dat';
//    IBDatabase1.Connected    := True;
//    glb_IBDataBase           := IBDatabase1;
//    glb_IBTransaction        := IBTransaction1;

    // MILLENNIUM
    IBDatabaseMILLENNIUM.DatabaseName := GetMillenniumDB(IniConfigs.ServerPath);
    IBDatabaseMILLENNIUM.Connected    := True;
    glb_MILLENNIUM_DATABASE           := IBDatabaseMILLENNIUM;
    glb_MILLENNIUM_Transaction        := IBTransaction2;

    Act := TActivation.Create;
    if not Act.VerifyLicense then
    begin
        Act.Free;
        Application.Terminate;
    end;
    SetFormStatus(screenDefault, True);

    Application.HintPause     := 100;
    Application.HintHidePause := 9000;
    Application.HintColor     := $00FFE7CE;
    AppStarted                := True;
    Processing                := False;
//fLog.Free;    
end;

procedure TfrmMain.LinkList1Links1Click(Sender: TObject);
var
  Exportacao:TExport;
  DataHoraInicio:TDateTime;
  fLog:TLog;
  sLogName:String;
  InicioExp:Cardinal;
begin
    // Exportacao
    Exportacao := TExport.Create;
    Processing := True;
    Try
      fLog := TLog.Create(nil);
      fLog.DefaultDirectoryOutput := ExtractFilePath(ParamStr(0));

      sLogName := 'EXP'+FormatDateTime('yyyymmddhhnnss', Now())+'.Log';
      Exportacao.Configs := GetIniConfigs;
      Exportacao.Log     := fLog;
      Exportacao.LogName := sLogName;
      Exportacao.LogDir  := Exportacao.Configs.DirGravacao + _pastaLog;

      InicioExp := GetTickCount;
      FLog.AddLog(LogMinimun, Informacao, 'Iniciando exporta��o', Exportacao.LogDir, sLogName,
                  FormatDateTime('dd/mm/yyyy hh:nn:ss',Now()));

      Exportacao.Exportados.Materializar;

      SetFormStatus(screenCargaInicial, True);
      Exportacao.CheckTriggers;
      SetFormStatus(screenAtualizandoGUIDs, True);

      // Criar GUID para os registros da tabela REGISTROS_DIARIOS
      // ** Necess�rio para permitir exportar corretamente os caixas **
      Exportacao.AtualizaGUIDCaixas;

      SetFormStatus(screenExportando_Auto, True);

//      ******* Testes *******
//      SetLength(Arr, 1);
//      Arr[0].IDTabela := -714699376;
//      Arr[0].Tabela   := 'SAIDAS';

//      SetLength(Arr, 2);
//      Arr[0].IDTabela := 24;
//      Arr[0].Tabela   := 'SAIDAS';

//      SetLength(Arr, 3);
//      Arr[0].IDTabela := 94;
//      Arr[0].Tabela   := 'SAIDAS';
///      Arr[0].IDTabela := 11000024;
///      Arr[0].Tabela   := 'SAIDAS';

//      Arr[1].IDTabela := 30;
//      Arr[1].Tabela   := 'SAIDAS';

//      Arr[2].IDTabela := 3;
//      Arr[2].Tabela   := 'SAIDAS';

//      Exportacao.Exportados.DeleteEmLote(Arr);

      Exportacao.DataHoraLastExportacao := Exportacao.GetLastExp;
      DataHoraInicio := Now;
      Exportacao.ProcessaExportacao;

      FLog.AddLog(LogMinimun, Informacao, 'Fim da exporta��o', Exportacao.LogDir, sLogName,
                  FormatDateTime('dd/mm/yyyy hh:nn:ss',Now()) + ' - Tempo Total: '+ tempoResumido(MSecsToDateTime(GetTickCount - InicioExp)));

      AtualizarLastExp(DataHoraInicio);
    Finally
      FreeAndNil(Exportacao);
      FreeAndNil(fLog);
      SetFormStatus(screenDefault, True);
      Processing := False;
    End;
end;

procedure TfrmMain.LinkList1Links0Click(Sender: TObject);
var
  Importacao:TImport;
begin
    // Importa��o
    Importacao := TImport.Create;
    Processing := True;
    Try
      Importacao.Configs := GetIniConfigs;
      SetFormStatus(screenDownloadingFiles, True);

      Download_FTP_Files;

      SetFormStatus(screenImportando, True);

      Importacao.ProcessaImportacao;
    Finally
      FreeAndNil(Importacao);
      SetFormStatus(screenDefault, True);
      Processing := False;
    End;
end;

procedure TfrmMain.pnlTempoResize(Sender: TObject);
begin
    pnlImgTempo.Left := pnlMain.Width - pnlTempo.Width - pnlImgTempo.Width;
end;

procedure TfrmMain.img1Click(Sender: TObject);
begin
    If pnlTempo.Width > 0 Then
       pnlTempo.Width := 0
    Else
       pnlTempo.Width := 153;
end;

procedure TfrmMain.pnlMainResize(Sender: TObject);
begin
    pnlWarning.Width := pnlMain.Width;
end;

procedure TfrmMain.TimerExport_ImportTimer(Sender: TObject);
Var
  SegundosTotais:Integer;
begin
    TimerExport_Import.Enabled  := False;

    AcumTimerParaProcessar      := AcumTimerParaProcessar + TimerExport_Import.Interval;
    AtualizaTimer;

    If IniConfigs.Modo = mExportacao Then
       SegundosTotais := GetIniConfigs.TempoExpSegundosTotais
    Else
       SegundosTotais := GetIniConfigs.TempoImpSegundosTotais;

    If AcumTimerParaProcessar >= (SegundosTotais * 1000) then
    begin
       AcumTimerParaProcessar := 0;
       If IniConfigs.Modo = mExportacao Then
          LinkList1Links1Click(Sender) //Exportacao
       Else
          LinkList1Links0Click(Sender); //Importa��o
    end;
    TimerExport_Import.Enabled := True;
end;

procedure TfrmMain.chkAutomaticamenteClick(Sender: TObject);
Var
  IniFile:TIniFile;
  ConfigsAtuais:TConfigs;
begin
    ConfigsAtuais := GetIniConfigs;
    IniFile := TIniFile.Create(sIniName);
    Try
      if ConfigsAtuais.Modo = mExportacao Then
         IniFile.WriteBool('Export', 'AutoExp', chkAutomaticamente.Checked)
      Else
         IniFile.WriteBool('Import', 'AutoImp', chkAutomaticamente.Checked);
      FreeAndNil(IniFile);

      IniConfigs := GetIniConfigs;
      If ValidateConfigs(IniConfigs, False) Then
      Begin
          TimerExport_Import.Enabled := chkAutomaticamente.Checked;
          AcumTimerParaProcessar := 0;
          AtualizaTimer;
      End;
    Finally
      FreeAndNil(IniFile);
    End;
end;

procedure TfrmMain.AtualizaTimer;
Var
  hr,min,seg,ms:Integer;
  Tempo:TTime;
begin
    If ((IniConfigs.Modo = mExportacao) And IniConfigs.AutoExp) or
       ((IniConfigs.Modo = mImportacao) And IniConfigs.AutoImp) Then
    Begin
        If (IniConfigs.Modo = mExportacao) Then
           Seg := IniConfigs.TempoExpSegundosTotais - (AcumTimerParaProcessar div 1000)
        Else
           Seg := IniConfigs.TempoImpSegundosTotais - (AcumTimerParaProcessar div 1000);

        If Seg < 0 Then
           Seg := 0;
        Hr  := (Seg Div 3600);
        If Hr > 0 Then
           Seg := (Seg Mod 3600);
        Min := (Seg Div 60);
        If Min > 0 Then
           Seg := (Seg Mod 60);
        ms := 0;

        Tempo := EncodeTime(hr,min,seg,ms);
        lbl_ProxProcessamento.Caption := tempoResumido(Tempo);
        Application.ProcessMessages;
    End Else
    Begin
        lbl_ProxProcessamento.Caption := 'Manual';
    end;
end;

procedure TfrmMain.pnl_errosResize(Sender: TObject);
begin
    pnl_ButtonErros.Left := pnlMain.Width - pnl_erros.Width - pnl_ButtonErros.Width;
end;

procedure TfrmMain.img2Click(Sender: TObject);
begin
    If pnl_erros.Width > 0 Then
       pnl_erros.Width := 0
    Else
       pnl_erros.Width := 153;
end;

procedure TfrmMain.CheckErrors;
Var
  SR:TSearchRec;
  x, y, z, CountErr:Integer;
  fLog:TLog;
  LogResult:TPEstruturaLogs;
  ListErros:TStringList;
  Dir : String;
begin
  fLog := TLog.Create(nil);
  fLog.DefaultDirectoryOutput := ExtractFilePath(ParamStr(0));
  ListErros            := TStringList.Create;
  CountErr := 0;

  Try
    If IniConfigs.Modo = mExportacao Then
       Dir := ExtractFilePath(IniConfigs.DirGravacao)
    else
    If IniConfigs.Modo = mImportacao Then
       Dir := ExtractFilePath(IniConfigs.DirLeitura);

    x := FindFirst(Dir + _pastaErros + '*.err', faArchive, sr);
    Try
      While x = 0 Do
      Begin
         LogResult := fLog.CarregaLog(Dir + _pastaErros + SR.Name);
         for y:= Low(LogResult) to High(LogResult) Do
         begin
             if LogResult[y].Status = AStatus[Erro] then
             begin
                Inc(CountErr);
                if ListErros.IndexOf(LogResult[y].Detalhe) = -1 then
                   ListErros.Add(LogResult[y].Detalhe);
             end;
         end;
         x := FindNext(SR);
      End;
    Finally
      FindClose(SR);
    End;

    lblQtdeErros.Caption   := IntToStr(CountErr);
    lblResumoErros.Caption := '';

    for z:= 0 to Pred(ListErros.count) Do
       lblResumoErros.Caption := lblResumoErros.Caption + '-Erro '+ IntToStr(z+1) +': '+ ListErros[z] + #13#10;
    lblResumoErros.Hint := lblResumoErros.Caption;

    if CountErr = 0 Then
    begin
        img2.Picture.Assign(pictureOK.Picture.Bitmap);
        lblTitleErros.Color := clLime;
    end else
    begin
        img2.Picture.Assign(pictureERROR.Picture.Bitmap);
        lblTitleErros.Color := clRed;
    end;
  finally
    FreeAndNil(fLog);
    FreeAndNil(ListErros);
  end;
end;

procedure TfrmMain.WMCheckErrors(var Msg: TWMSysCommand);
begin
    CheckErrors;
end;

procedure TfrmMain.FormActivate(Sender: TObject);
begin
    if AppStarted and (not Processing) then
       CheckErrors;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
    IBDatabase1.Connected := False;
end;

{ TSendArqs }

function CreateFTP: IConnectFTP;
Var FtpConfig:TFtpConfig;
    con:TConnectFtp;
    Configs:TConfigs;
begin
     Configs := GetIniConfigs;

     If StrToModoTransf(Configs.FTP.Modo) = mFTP Then
     Begin
          FtpConfig.ServidorFtp := Configs.FTP.ServidorFtp;
          FtpConfig.Passive     := Configs.FTP.Passiveftp;
          FtpConfig.User        := Configs.FTP.User;
          FtpConfig.Pass        := Configs.FTP.Password;
          FtpConfig.ProxyType   := StrToProxyType(Configs.FTP.ProxyType);
          FtpConfig.ProxyServer := Configs.FTP.Servidorproxy;
          FtpConfig.Port        := 21;//Configs.FTP.Porta;
          con := TConnectFtp.Create;
          If Not con.ConnectFtp( FtpConfig ) Then
          Begin
               FreeAndNil(con);
               Raise Exception.Create( 'Configura��o de Ftp Incorreta.' );
          End;
          Result := con;
     End Else
     Begin
          Result := TConnectRede.Create;
     End;

     if Configs.Modo = mExportacao then
        Result.SetFtpDirectory( ParseFTPDirectories(Configs.FTP.DirEnvios) )
     else
        Result.SetFtpDirectory( ParseFTPDirectories(Configs.FTP.DirRecebimentos) );
end;

procedure TSendArqs.Execute;
var x,z:Integer;
    s:TSearchRec;
    dir:String;
    ftp:TGFTP;
    Conn:IConnectFtp;
    Configs:TConfigs;
    fst:TFileStream;
    Files:TStringList;

    Procedure AddToLog(Const s:String);
//    var
//    FLog:TFileStream;
//        d:String;
    Begin
{         If FileExists(Dir + '\LogFTP.txt') Then
            Flog := TFileStream.Create( Dir + '\LogFTP.txt', fmOpenReadWrite)
         Else
            Flog := TFileStream.Create( Dir + '\LogFTP.txt', fmCreate);
         If FLog.Size>1048576 Then
         Begin
              Flog.Free;
              DeleteFile( Dir + '\LogFTP-6.txt');
              RenameFile( Dir + '\LogFTP-5.txt', Dir + '\LogFTP-6.txt');
              RenameFile( Dir + '\LogFTP-4.txt', Dir + '\LogFTP-5.txt');
              RenameFile( Dir + '\LogFTP-3.txt', Dir + '\LogFTP-4.txt');
              RenameFile( Dir + '\LogFTP-2.txt', Dir + '\LogFTP-3.txt');
              RenameFile( Dir + '\LogFTP-1.txt', Dir + '\LogFTP-2.txt');
              RenameFile( Dir + '\LogFTP.txt',   Dir + '\LogFTP-1.txt');
              Flog := TFileStream.Create( Dir + '\LogFTP.txt', fmCreate);
         End;
         FLog.Position := Flog.Size;
         d := FormatDateTime( 'dd/mm/yyyy hh:mm:ss:zzz', Now ) + ' ';
         FLog.Write(d[1],Length(d));
         FLog.Write(s[1],Length(s));
         FLog.Write(#13#10,2);
         FLog.Free;}
    End;
begin
     Configs := GetIniConfigs;
     if not Configs.FTP.Ativo then
     begin
         Terminate;
         Exit;
     end;

     Try
        Try
           AddToLog('Iniciando Envio');

           While not Terminated do
           Begin
                z := 0;
                Files := TStringList.Create;
                Try
                   Try
                      Dir := Configs.DirGravacao;

                      AddToLog('Adicionando na Fila');
                      x := FindFirst( Dir + prefixExp + '*.zip' ,faAnyFile , s );
                      Try
                         While x=0 do
                         Begin
                              Files.Add(Dir + s.Name);
                              x := FindNext(s);
                         End;
                      Finally
                         FindClose(s);
                      End;

                      If Files.Count>0 Then
                      Begin
                           conn := CreateFtp;
                           Try
                              Conn.DelAfterUpload := Configs.FTP.DelAfterUpload;
                              Conn.UploadPath     := Dir;
                              ftp := TGFTP.Create;
                              Try
                                 Conn.SetParams(ftp);

                                 For x:=0 To Pred(Files.Count) do
                                 Begin
                                      Try  // Tenta abrir o arquivo em modo exclusivo para transmitir
                                         fst := TFileStream.Create(Files[x],fmOpenRead or fmShareExclusive);
                                         fst.Free;
                                         Conn.UploadArqFtp( Files[x] , ftp );
                                         Inc(z);
                                      Except
                                         On e:Exception do AddToLog('Erro: '+E.Message);
                                      End;
                                 End;
                              Finally
                                 ftp.Quit;
                                 FreeAndNil(ftp);
                              End;
                           Finally
                              conn := nil;
                           End;
                      End;
                   Except
                     On e:Exception do
                        AddToLog('Erro: '+E.Message);
                   End;
                Finally
                   Files.Free;
                End;

                AddToLog(IntToStr(z) + ' Arquivos enviados');
                Terminate;
           End;
        Except
           On e:Exception do AddToLog('Erro: '+E.Message);
        End;
     Finally
        AddToLog('Envio Terminado');
     End;
end;

procedure TfrmMain.TimerEnvioFTPTimer(Sender: TObject);
begin
  if not fSend_In_Progress then
  begin
     if (IniConfigs.Modo <> mExportacao) or (not IniConfigs.FTP.Ativo) then
        Exit;
  End;

  TimerEnvioftp.Enabled := False;
  Try
    if fSend = nil then
    begin
        fSend_In_Progress := True;

        ImgUp.Left := bvlStatus1.Left;
        ImgUp.Top  := bvlStatus1.Top;
        ImgUp.Visible := True;
        lbl_Upload_Down.Caption   := 'Upload';

        Application.ProcessMessages;

        fSend := TSendArqs.Create(True);
        fSend.FreeOnTerminate := False;
        fSend.Resume;

        TimerEnvioFTP.Interval := 2000;
        fSendTime := GetTickCount;
    end;

    if not fSend.Terminated then
    Begin
         If (getTickCount - fSendTime) > (5 * 60000) Then
         Begin
           fSend.Suspend;
           fSend.Terminate;
           FreeAndNil(fSend);

           ImgUp.Visible     := False;
           lbl_Upload_Down.Caption := '.........';
           TimerEnvioFTP.Interval := 15000;
           fSend_In_Progress := False;
         End;
    end else
    begin
        FreeAndNil(fSend);
        ImgUp.Visible     := False;
        lbl_Upload_Down.Caption := '.........';
        TimerEnvioFTP.Interval := 15000;
        fSend_In_Progress := False;
    end;
  Finally
    TimerEnvioftp.Enabled := True;
  End;
end;

procedure TfrmMain.Download_FTP_Files;
Var
  conn: IConnectFtp;
begin
    IniConfigs := GetIniConfigs;

    if IniConfigs.FTP.Ativo then
    begin
        If IniConfigs.FTP.DirRecebimentos <> '' Then
        Begin
            conn := CreateFtp;
            Try
               ImgUp.Left      := bvlStatus2.Left;
               ImgUp.Top       := bvlStatus2.Top;
               Imgdown.Visible := True;
               lbl_Upload_Down.Caption := 'Download';
               Application.ProcessMessages;

               conn.DelAfterDownLoad := True;  //IniConfigs.FTP.Delafterdownload;
               conn.DownLoadPath := IniConfigs.DirLeitura;
               //conn.OnStatus := StatusFTP;
               conn.downLoad(prefixExp);
            Finally
               conn := nil;
               ImgDown.Visible   := False;
               lbl_Upload_Down.Caption := '.........';
            End;
        End;
    end;
end;

end.

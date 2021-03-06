unit UConectFtp;

interface

uses
  Windows, SysUtils, gsftp, FileCtrl, Controls, Forms, Classes, MyFuncs;

Type
  TPrepareRoutine = Procedure( Value:Integer ) of Object;
  TCallRoutine = Procedure of Object;
  TOnStatus = procedure(Const Status:String) of Object;
  TCheckFileFunction = Function (Const FileName:String;Commit:Boolean):Boolean of object;

  TFtpConfig = Record
    ServidorFtp,
    User,
    Pass:String;
    Passive:Boolean;
    ProxyType:TMFtpProxyType;
    ProxyServer:String;
    Directory:String;
    Port:Integer;
  End;

  IConnectFTP = Interface
    procedure DoStatus(Const msg:String);
    function GetDnPath: String;
    function GetUpPath: String;
    procedure SetDnPath(const Value: String);
    procedure SetOnStatus(const Value: TOnStatus);
    procedure SetUpPath(const Value: String);
    procedure SetDelAfterUpload(const Value: Boolean);
    procedure SetDelAfterDownLoad(const Value: Boolean);
    procedure SetParams(const ftp: TGFTP);
    Function  DownLoad(Const Prefix:String):Boolean;
    procedure CleanUp(Const Prefix:String);
    Function  UploadArqFtp( ArqName:String; iftp:TGFTP=nil ):Boolean;
    procedure SetCallProc(const Value: TCallRoutine);
    procedure SetCheckFile(const Value: TCheckFileFunction);
    procedure SetPrepProc(const Value: TPrepareRoutine);
    procedure SetFtpDirectory(const Value: ArrayOfString);
    Property  DelAfterUpload:Boolean write SetDelAfterUpload;
    Property DelAfterDownLoad:Boolean write SetDelAfterDownLoad;
    property OnStatus:TOnStatus Write SetOnStatus;
    property UploadPath:String Read GetUpPath Write SetUpPath;
    property DownLoadPath:String Read GetDnPath Write SetDnPath;
    property CheckFile:TCheckFileFunction write SetCheckFile;
    property CallRoutine:TCallRoutine write SetCallProc;
    property PrepareRoutine:TPrepareRoutine write SetPrepProc;
  End;

  TConnectRede = Class(TInterfacedObject,IConnectFTP)
  private
    FUpPath,FDnPath: String;
    FFTPDir:ArrayOfString;
    FDelAfterDownLoad: Boolean;
    FDelAfterUpload: Boolean;
    FCheckFile: TCheckFileFunction;
    FCallProc: TCallRoutine;
    FOnStatus: TOnStatus;
    FPrepProc: TPrepareRoutine;
    j:THintWindow;
    procedure DoStatus(Const msg:String);
    function  GetFileList(const Prefix: String): TStringList;
  public
    function  GetDnPath: String;
    function  GetUpPath: String;
    procedure SetDnPath(const Value: String);
    procedure SetOnStatus(const Value: TOnStatus);
    procedure SetUpPath(const Value: String);
    procedure SetDelAfterUpload(const Value: Boolean);
    procedure SetDelAfterDownLoad(const Value: Boolean);
    procedure SetCallProc(const Value: TCallRoutine);
    procedure SetCheckFile(const Value: TCheckFileFunction);
    procedure SetPrepProc(const Value: TPrepareRoutine);
    procedure SetFtpDirectory(const Value: ArrayOfString);
    procedure SetParams(const ftp: TGFTP);
    Function  DownLoad(Const Prefix:String):Boolean;
    procedure CleanUp(Const Prefix:String);
    Function  UploadArqFtp( ArqName:String; iftp:TGFTP=nil ):Boolean;
  End;

  TConnectFtp = Class(TInterfacedObject,IConnectFTP)
  private
    { Private declarations }
    FtpConfig:TFtpConfig;
    FDelAfterDownLoad: Boolean;
    FDelAfterUpload: Boolean;
    FCheckFile: TCheckFileFunction;
    FCallProc: TCallRoutine;
    FPrepProc: TPrepareRoutine;
    FOnStatus: TOnStatus;
    FUpPath: String;
    FDnPath: String;
    j:THintWindow;
    procedure SetDelAfterDownLoad(const Value: Boolean);
    procedure SetDelAfterUpload(const Value: Boolean);
    procedure DoStatus(Const msg:String);
    function GetDnPath: String;
    function GetUpPath: String;
    procedure SetDnPath(const Value: String);
    procedure SetOnStatus(const Value: TOnStatus);
    procedure SetUpPath(const Value: String);
    procedure SetCallProc(const Value: TCallRoutine);
    procedure SetCheckFile(const Value: TCheckFileFunction);
    procedure SetPrepProc(const Value: TPrepareRoutine);
  public
    { Public declarations }
    FtpDirectory:ArrayOfString;
    destructor Destroy;override;
    procedure SetParams(const ftp: TGFTP);
    Function  DownLoad(Const Prefix:String):Boolean;
    procedure CleanUp(Const Prefix:String);
    procedure SetFtpDirectory(const Value: ArrayOfString);
    Function UploadArqFtp( ArqName:String; iftp:TGFTP=nil ):Boolean;
    Function ConnectFtp( FtpConfig:TFtpConfig ):Boolean;
    Property DelAfterUpload:Boolean read FDelAfterUpload write SetDelAfterUpload Default False;
    Property DelAfterDownLoad:Boolean read FDelAfterDownLoad write SetDelAfterDownLoad Default False;
    property CheckFile:TCheckFileFunction read FCheckFile write SetCheckFile;
    property CallRoutine:TCallRoutine read FCallProc write SetCallProc;
    property PrepareRoutine:TPrepareRoutine read FPrepProc write SetPrepProc;
    property OnStatus:TOnStatus Read FOnStatus Write SetOnStatus;
    property UploadPath:String Read GetUpPath Write SetUpPath;
    property DownLoadPath:String Read GetDnPath Write SetDnPath;
  end;

  Function StrToProxyType( Value:String):TMFtpProxyType;
  Function ProxyTypeToStr( ProxyType:TMFtpProxyType ):String;
  Function TestFtpConnection(FtpConfig: TFtpConfig): Boolean;

implementation

uses AbUnzper;

{ Global Method�s }

Function StrToProxyType( Value:String):TMFtpProxyType;
Begin
  if Value = 'proxyHost' Then
    Result := proxyHost
  Else if Value = 'proxyHostUser' Then
    Result := proxyHostUser
  Else if Value = 'proxyOpen' Then
    Result := proxyOpen
  Else if Value = 'proxySite' Then
    Result := proxySite
  Else if Value = 'proxyUserSite' Then
    Result := proxyUserSite
  Else // Todos os outros casos ser�o considerados proxyNone
    Result := proxyNone;
End;

Function ProxyTypeToStr( ProxyType:TMFtpProxyType ):String;
Begin
  Case ProxyType of
     proxyHost     : Result:= 'proxyHost';
     proxyHostUser : Result:= 'proxyHostUser';
     proxyOpen     : Result:= 'proxyOpen';
     proxySite     : Result := 'proxySite';
     proxyUserSite : Result := 'proxyUserSite';
  Else
    Result := 'proxyNone';
  End;
End;

Function TestFtpConnection(FtpConfig: TFtpConfig): Boolean;
Var Ftp:TGFTP;
begin
  Ftp := TGFTP.Create;
  Try
    Ftp.ProxyServer := FtpConfig.ProxyServer;
    Ftp.ProxyPort   := FtpConfig.Port;
    Ftp.ProxyType   := ftpconfig.ProxyType;
    Ftp.Server   := FtpConfig.ServidorFtp;
    Ftp.UserName := FtpConfig.User;
    Ftp.Password := FtpConfig.Pass;
    Ftp.Passive  := FtpConfig.Passive;
    Ftp.Login;
    Ftp.ChangeDirectory( FtpConfig.Directory );
    Ftp.List('*.zip');
    Ftp.Quit;
    Ftp.Free;
    Result := True;
  Except on E:Exception do
    Begin
      Ftp.Free;
      Raise Exception.Create( e.message );
    End;
  End;
end;

{ TConnectFtp }

function TConnectFtp.ConnectFtp(FtpConfig: TFtpConfig): Boolean;
begin
  DoStatus('Conectando ao Servidor FTP');
  Try
    Try
      Self.FtpConfig := FtpConfig;
      (*Ftp.ProxyServer := FtpConfig.ProxyServer;
      Ftp.ProxyPort   := FtpConfig.Port;
      Ftp.ProxyType   := ftpconfig.ProxyType;
      Ftp.Server   := FtpConfig.ServidorFtp;
      Ftp.UserName := FtpConfig.User;
      Ftp.Password := FtpConfig.Pass;
      Ftp.Passive  := FtpConfig.Passive;*)
      Result := True;
    Except
      Result := False;
    End;
  Finally
    DoStatus('');
  End;
end;

procedure TConnectFtp.SetParams(const ftp:TGFTP);
Begin
     Ftp.ProxyServer := FtpConfig.ProxyServer;
     Ftp.ProxyPort   := FtpConfig.Port;
     Ftp.ProxyType   := ftpconfig.ProxyType;
     Ftp.Server   := FtpConfig.ServidorFtp;
     Ftp.UserName := FtpConfig.User;
     Ftp.Password := FtpConfig.Pass;
     Ftp.Passive  := FtpConfig.Passive;
     Ftp.Login;
End;


function TConnectFtp.UploadArqFtp(ArqName: String; iftp:TGFTP=nil): Boolean;
var Ftp:TGFTP;
    dir,new:String;
    dd,mm,yy:Word;
    x, i:Integer;
begin
  Try
    DoStatus('Enviando para o FTP '+ArqName);
    If iFtp=nil Then
       Ftp := TGFTP.Create
    Else
       Ftp := iFtp;

    Try
       If iFtp=nil Then
          SetParams(Ftp);

       for i := Low(FtpDirectory) To High(FtpDirectory) Do
       Begin
           Ftp.ChangeDirectory( FtpDirectory[i] );

           // Apaga arquivos se existirem
         //  Ftp.List(ChangeFileExt(ExtractFileName(ArqName) ,'.*'));
         //  For x:=0 to Pred(Ftp.Files.Count) Do
         //      If AnsiCompareStr(ftp.Files.Items[x].Filename,ChangeFileExt(ExtractFileName( ArqName ),'.tmp'))=0 Then
         //         Ftp.DeleteFile(ftp.Files.Items[x].Filename)
         //      Else If AnsiCompareStr(ftp.Files.Items[x].Filename,ExtractFileName( ArqName ))=0 Then
         //         Ftp.DeleteFile(ftp.Files.Items[x].Filename);
           Ftp.UpLoad( ArqName , ChangeFileExt(ExtractFileName( ArqName ),'.tmp') );
           ftp.RenameFile(ChangeFileExt(ExtractFileName( ArqName ),'.tmp'), ExtractFileName( ArqName ));
       end;

       DecodeDate(Date,yy,mm,dd);
       dir := ExtractFilePath(ArqName) + 'Enviados\' + FormatFloat('00',dd)+'_'+ FormatFloat('00',mm) + '_' + FormatFloat('0000',yy);
       ForceDirectories(dir);
       new := dir + '\' + ExtractFileName( ArqName );
       DeleteFile(new);
       MoveFile(PChar(ArqName),PChar(new));
    Finally
       If iFtp=nil Then
       Begin
            Ftp.Quit;
            FreeAndNil(Ftp);
       End;
      DoStatus('');
    End;
    Result := True;
  Except on e:Exception do Begin
    Raise Exception.Create( E.Message );
    End;
  End;
end;

procedure TConnectFtp.SetFtpDirectory(const Value: ArrayOfString);
begin
  FtpDirectory := Value;
end;

Function TConnectFtp.DownLoad(Const Prefix:String):Boolean;
Var x, i:Integer;
    ok:Boolean;
    Ftp:TGFTP;
    unz:TAbUnZipper;
    fil:String;
    erz:Boolean;
    sr:TSearchRec;
begin
  Result := False;

  DoStatus('Baixando arquivos do FTP');
  Ftp := TGFTP.Create;
  Try
    SetParams(Ftp);

    for i := Low(FtpDirectory) To High(FtpDirectory) Do
    begin
        Ftp.ChangeDirectory( FtpDirectory[i] );
        Ftp.List(Prefix+'*.zip');
        If Assigned( PrepareRoutine ) Then
          PrepareRoutine( Ftp.Files.Count );
        ForceDirectories( DownLoadPath );
        For x := 0 to Ftp.Files.Count -1 Do
        Begin
             If Assigned(CheckFile) Then
                ok := CheckFile(ftp.Files.Items[x].Filename,False)
             Else ok := True;
             If ok Then
             Begin
                  fil := DownLoadPath + Ftp.Files.Items[x].Filename;
                  DoStatus('Baixando '+ ftp.Files.Items[x].Filename);
                  // Apaga o arquivo antes
                  DeleteFile( fil );
                  Ftp.Download( fil , Ftp.Files.Items[x].Filename );

                  If FindFirst(fil,faAnyFile,sr)=0 Then
                  Begin
                       erz := (sr.Size<>StrToIntDef(Ftp.Files.Items[x].Size,-1)); // Tamanho do arquivo inv�lido
                       If not erz Then
                       Begin
                            unz := TAbUnZipper.Create( Nil );
                            Try
                               unz.FileName := fil;
                               erz := (unz.Count=0);
                            Finally
                               unz.Free;
                            End;
                       End;
                       FindClose(sr);
                  End Else
                      erz := True;

                  If erz Then DeleteFile( fil );  // Arquivo com erro vai tentar baixar novamente

                  If FDelAfterDownLoad and not erz Then
                     Ftp.DeleteFile( ftp.Files.Items[x].Filename );
                  Result := True;
                  If Assigned( CallRoutine ) Then
                     CallRoutine;
                  If Assigned(CheckFile) Then
                     CheckFile(ftp.Files.Items[x].Filename,True);
             End Else
             Begin
                  If FDelAfterDownLoad Then
                     Ftp.DeleteFile( ftp.Files.Items[x].Filename );
             End;
        end;
    End;
  Finally
    Ftp.Quit;
    FreeAndNil(Ftp);
    DoStatus('');
  End;
end;

procedure TConnectFtp.SetDelAfterDownLoad(const Value: Boolean);
begin
  FDelAfterDownLoad := Value;
end;

procedure TConnectFtp.SetDelAfterUpload(const Value: Boolean);
begin
  FDelAfterUpload := Value;
end;

procedure TConnectFtp.DoStatus(const msg: String);
//var p:TRect;
begin
{     FreeAndNil(j);
     If msg<>'' Then
     Begin
         j := THintWindow.Create(nil);
         SystemParametersInfo(SPI_GETWORKAREA,0,@p,0);
         p.Top := p.Bottom - (j.Canvas.TextHeight('E') + 4);
         p.Left := p.Right - (j.Canvas.TextWidth(Msg)+5);
         j.ActivateHint(p,Msg);
         j.Update;
     End;

     If Assigned(fOnStatus) Then
        FOnStatus(msg);
}     
end;

function TConnectFtp.GetDnPath: String;
begin
     If FDnPath='' Then
        FDnPath := ExtractFilePath( ParamStr( 0 ) ) + 'DownLoad\';
     If Copy(FDnPath,Length(Trim(FDnPath)),1)<>'\' Then
        FDnPath := FDnPath + '\';
     Result := FDnPath;
     ForceDirectories(Result);
end;

function TConnectFtp.GetUpPath: String;
begin
     If FDnPath='' Then
        FUpPath := ExtractFilePath( ParamStr( 0 ) ) + 'UpLoad\';
     If Copy(FUpPath,Length(Trim(FUpPath)),1)<>'\' Then
        FUpPath := FUpPath + '\';
     Result := FUpPath;
     ForceDirectories(Result);
end;

destructor TConnectFtp.Destroy;
begin
     FreeAndNil(j);
     inherited;
end;

procedure TConnectFtp.CleanUp(const Prefix: String);
Var x,z:Integer;
    Ftp:TGFTP;
    dd,mm,yy:Word;
    s:String;
    i:Integer;
begin
     DoStatus('Limpando arquivos antigos do FTP');
     Ftp := TGFTP.Create;
     Try
        SetParams(Ftp);
        for i := Low(FtpDirectory) To High(FtpDirectory) do
        begin
            Ftp.ChangeDirectory( FtpDirectory[i] );
            Ftp.List(Prefix+'*.zip');
            For x := 0 to Ftp.Files.Count -1 Do
            Begin
                 Try
                    // Data vem em formato americano
                    s := Ftp.Files[x].DateTime;
                    z := Pos('/',s);
                    mm := StrToIntDef(Copy(s,1,Pred(z)),1);
                    s := Copy(s,Succ(z),MaxInt);
                    z := Pos('/',s);
                    dd := StrToIntDef(Copy(s,1,Pred(z)),1);
                    s := Copy(s,Succ(z),MaxInt);
                    z := Pos(' ',s);
                    yy := StrToIntDef(Copy(s,1,Pred(z)),1);
                    If yy<1000 Then yy := 2000+yy;
                    If EncodeDate(yy,mm,dd)<(Date-10) Then
                       Ftp.DeleteFile( ftp.Files.Items[x].Filename );
                 Except
                 End;
            End;
        end;
     Finally
       Ftp.Quit;
       FreeAndNil(Ftp);
       DoStatus('');
     End;
end;

procedure TConnectFtp.SetDnPath(const Value: String);
begin
     FDnPath := Value;
end;

procedure TConnectFtp.SetOnStatus(const Value: TOnStatus);
begin
     FOnStatus := Value;
end;

procedure TConnectFtp.SetUpPath(const Value: String);
begin
     FUpPath := Value;
end;

procedure TConnectFtp.SetCallProc(const Value: TCallRoutine);
begin
     FCallProc := Value;
end;

procedure TConnectFtp.SetCheckFile(const Value: TCheckFileFunction);
begin
     FCheckFile := Value;
end;

procedure TConnectFtp.SetPrepProc(const Value: TPrepareRoutine);
begin
     FPrepProc := Value;
end;

{ TConnectRede }

Function TConnectRede.GetFileList(Const Prefix:String):TStringList;
var
  sr:TSearchRec;
  i:integer;
Begin
     Result := TStringList.Create;

     for i := Low(FFTPDir) To High(FFTPDir) do
     begin
         If FindFirst( FFTPDir[i] + '\' + Prefix + '*.zip',faAnyFile, sr)=0 Then
         Begin
              Repeat
                 Result.Add(FFTPDir[i] + '\' + sr.Name);
              Until FindNext(sr)<>0;
              FindClose(sr);
         End;
     end;

     Result.Sort;
End;

procedure TConnectRede.CleanUp(const Prefix: String);
Var x:Integer;
    ls:TStringList;
begin
     DoStatus('Limpando arquivos antigos da rede');

     ls := GetFileList(prefix);
     Try
        For x:=0 To Pred(ls.Count) do
            If FileDateToDateTime(FileAge(ls[x]))<(Date-10) Then
               DeleteFile(ls[x]);
     Finally
        ls.Free;
        DoStatus('');
     End;
end;

procedure TConnectRede.DoStatus(const msg: String);
//var p:TRect;
begin
{     FreeAndNil(j);
     If msg<>'' Then
     Begin
         j := THintWindow.Create(nil);
         SystemParametersInfo(SPI_GETWORKAREA,0,@p,0);
         p.Top := p.Bottom - (j.Canvas.TextHeight('E') + 4);
         p.Left := p.Right - (j.Canvas.TextWidth(Msg)+5);
         j.ActivateHint(p,Msg);
         Application.ProcessMessages;
     End;

     If Assigned(fOnStatus) Then
        FOnStatus(msg);
}
end;

function TConnectRede.DownLoad(const Prefix: String): Boolean;
Var x:Integer;
    ok:Boolean;
    ls:TStringList;
begin
     Result := False;

     DoStatus('Copiando arquivos da rede');

     ls := GetFileList(prefix);
     Try
        If Assigned( FPrepProc ) Then
           FPrepProc( ls.Count );

        For x := 0 to ls.Count -1 Do
        Begin
             If Assigned(FCheckFile) Then
                ok := FCheckFile(ExtractFileName(ls[x]),False)
             Else
                ok := True;
                
             If ok Then
             Begin
                  DoStatus('Copiando '+ ExtractFileName(ls[x]));
                  // Apaga o arquivo antes
                  ForceDirectories(FDnPath);
                  CopyFile(PChar(ls[x]),PChar(FDnPath + ExtractFileName(ls[x])),False);
                  If FDelAfterDownLoad Then
                     DeleteFile(ls[x]);
                  Result := True;
                  If Assigned( FCallProc ) Then
                     FCallProc;
                  If Assigned(FCheckFile) Then
                     FCheckFile(ExtractFileName(ls[x]),True);
             End Else
             Begin
                  If FDelAfterDownLoad Then
                     DeleteFile(ls[x]);
             End;
        End;
     Finally
        ls.Free;
        DoStatus('');
     End;
end;

function TConnectRede.GetDnPath: String;
begin
     Result := FDnPath;
end;

function TConnectRede.GetUpPath: String;
begin
     Result := FUpPath;
end;

procedure TConnectRede.SetCallProc(const Value: TCallRoutine);
begin
     FCallProc := Value;
end;

procedure TConnectRede.SetCheckFile(const Value: TCheckFileFunction);
begin
     FCheckFile := Value;
end;

procedure TConnectRede.SetDelAfterDownLoad(const Value: Boolean);
begin
     FDelAfterDownLoad := Value;
end;

procedure TConnectRede.SetDelAfterUpload(const Value: Boolean);
begin
     FDelAfterUpload := Value;
end;

procedure TConnectRede.SetDnPath(const Value: String);
begin
     FDnPath := Value;
end;

procedure TConnectRede.SetFtpDirectory(const Value: ArrayOfString);
begin
     FFTPDir := Value;
end;

procedure TConnectRede.SetOnStatus(const Value: TOnStatus);
begin
     FOnStatus := Value;
end;

procedure TConnectRede.SetParams(const ftp: TGFTP);
begin
     // Nada � Fazer
end;

procedure TConnectRede.SetPrepProc(const Value: TPrepareRoutine);
begin
     FPrepProc := Value;
end;

procedure TConnectRede.SetUpPath(const Value: String);
begin
     FUpPath := Value;
end;

function TConnectRede.UploadArqFtp(ArqName: String; iftp: TGFTP): Boolean;
var dir,new:String;
    dd,mm,yy:Word;
    i:Integer;
    ok:boolean;
begin
     Try
        DoStatus('Enviando para o FTP '+ArqName);
        Try
           ok := True;
           for i := Low(FFTPDir) To High(FFTPDir) Do
           begin
               ForceDirectories(FFTPDir[i]);
               if not CopyFile(PChar(ArqName),PChar(FFTPDir[i] + '\' + ExtractFileName( ArqName )), False ) Then
                  ok := False;                  
           end;
Sleep(15000);
           if ok then
           Begin
               DecodeDate(Date,yy,mm,dd);

               dir := ExtractFilePath(ArqName) + 'Enviados\' + FormatFloat('00',dd)+'_'+ FormatFloat('00',mm) + '_' + FormatFloat('0000',yy);
               ForceDirectories(dir);
               new := dir + '\' + ExtractFileName( ArqName );
               DeleteFile(new);
               MoveFile(PChar(ArqName),PChar(new));
           End;
        Finally
           DoStatus('');
        End;
        Result := True;
     Except
           on e:Exception do Raise Exception.Create( E.Message );
     End;
end;

end.

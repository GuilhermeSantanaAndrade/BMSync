unit gsftp;

interface

uses Classes, IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient, IdFTP,
     IdFTPList, FtpData, SysUtils, FtpParse, IdFTPCommon;

type

     TMFtpServerType = (ftpstAutoDetect, ftpstDefault,
                      ftpstUNIX, ftpstULTRIX, ftpstClix, ftpstChameleon,
                      ftpstNCSA, ftpstQVT, ftpstBSD, ftpstSunOS,
                      ftpstVmsMultinet, ftpstVmsUcx, ftpstMVS, ftpstVM, ftpstVMVPS,
                      ftpstMSFTP, ftpstNetTerm, ftpstServU, ftpstWFTPD, ftpWarFTPD,
                      ftpstNetware, ftpstNetPresenz);

     TFtpError = (ftpProtocolError,ftpPermissionDenied,ftpServerDown,
                  ftpAccessDenied,ftpNoServer,ftpGeneralWinsockError,
                  ftpHostUnreachable,ftpNoDirectory,ftpNoFile);

     TMFtpProxyType = (proxyNone, proxyHost, proxyHostUser, proxyOpen, proxySite,
                     proxyUserSite);

     TOnProgress=procedure (Sender:TObject;const opid:String;Progress,ByteCount:Integer) of object;
     TProgressProc=procedure (const opid:String;Progress,ByteCount:Integer) of object;
     TFtpProc = procedure(const Line: String) of object;
     TTransferMode = (tmAlpha,tmBinary);

     TByteSet=set of byte;

     TGFTP=class
     private
          FUseRestart: Boolean;
          FProcessMsgs: Boolean;
          FPassive: Boolean;
          FLoggedIn: Boolean;
          fFTP:TIdFTP;
          fPort: Integer;
          FProxyPort: Integer;
          fServer: String;
          fTotalSize:Integer;
          FIDirectory: String;
          fUser: String;
          fPUser: String;
          fPPass: String;
          fProxyServer: String;
          fPass: String;
          fProxyType: TMFtpProxyType;
          fOnProgress: TOnProgress;
          FFiles,
          FDirectories:TMFtpFileInfoList;
          function GetCurrrentDirectory: String;
          procedure SetPass(const Value: String);
          procedure SetPort(const Value: Integer);
          procedure SetPPass(const Value: String);
          procedure SetProxyPort(const Value: Integer);
          procedure SetProxyServer(const Value: String);
          procedure SetProxyType(const Value: TMFtpProxyType);
          procedure SetPUser(const Value: String);
          procedure SetServer(const Value: String);
          procedure SetUser(const Value: String);
          procedure SetUseRestart(const Value: Boolean);
          function  GetSupportResume: Boolean;
          procedure SetPassive(const Value: Boolean);
          procedure DoOnStatus(ASender: TObject; const AStatus: TIdStatus; const AStatusText: string);
          procedure DoOnWork(Sender: TObject; AWorkMode: TWorkMode; const AWorkCount: Integer);
     protected
          property  IntFTP:TIdFTP read fFTP;
     public
          procedure Connect;
          procedure Login;
          procedure List(FileMask:String);
          procedure ChangeDirectory(const dirname:String);

          procedure StreamDownload(stream: TStream; const rfile, opid: String; startpos, rfilesize: Integer);

          procedure Download(const rfile, lfile, opid:String;rfilesize:Integer);overload;
          procedure Download(const rfile, lfile: String);overload;

          procedure UpLoad(const lfile,rfile:String;const opid:String='');
          procedure CreateDirectory(const dirname:String);
          procedure DeleteDirectory(const dirname:String);
          procedure DeleteFile(const filename:String);
          procedure RenameFile(const ofilename,nfilename:String);
          procedure ChangeToParentDir;
          procedure Quit;

          property  ProxyType:TMFtpProxyType read fProxyType write SetProxyType;
          property  ProxyServer:String read fProxyServer write SetProxyServer;
          property  ProxyPort:Integer read FProxyPort write SetProxyPort;
          property  ProxyUser:String read fPUser write SetPUser;
          property  ProxyPass:String read fPPass write SetPPass;

          property  Server:String read fServer write SetServer;
          property  Port:Integer read fPort write SetPort;
          property  UserName:String read fUser write SetUser;
          property  Password:String read fPass write SetPass;

          property  Files:TMFtpFileInfoList read fFiles;
          property  Directories:TMFtpFileInfoList read fDirectories;

          property  UseRestart:Boolean read fUseRestart write SetUseRestart;
          property  CurrentDirectory:String read GetCurrrentDirectory write ChangeDirectory;
          property  InitialDirectory:String read FIDirectory write FIDirectory;
          property  ProcessMsgs:Boolean read FProcessMsgs write FProcessMsgs;

          property  LoggedIn:Boolean read FLoggedIn;
          property  SupportResume:Boolean read GetSupportResume;

          property  OnProgress:TOnProgress read fOnProgress write fOnProgress;
          property  Passive:Boolean read FPassive write SetPassive;

          constructor Create;
          destructor  Destroy;override;
     end;

implementation



{ TGFTP }

procedure TGFTP.ChangeDirectory(const dirname: String);
begin
     fFTP.ChangeDir(dirname);
end;

procedure TGFTP.ChangeToParentDir;
begin
     fFTP.ChangeDirUp;
end;

constructor TGFTP.Create;
begin
     fFTP := TIdFTP.Create(nil);
     fFtp.OnStatus := DoOnStatus;
     fFtp.OnWork := DoOnWork;
     FFiles := TMFtpFileInfoList.Create;
     FDirectories := TMFtpFileInfoList.Create;
end;

procedure TGFTP.CreateDirectory(const dirname: String);
begin
     fFTP.MakeDir(dirname);
end;

procedure TGFTP.DeleteDirectory(const dirname: String);
begin
     fFTP.RemoveDir(dirname);
end;

procedure TGFTP.DeleteFile(const filename: String);
begin
     fFtp.Delete(filename);
end;

procedure TGFTP.Download(const rfile, lfile, opid: String;
  rfilesize: Integer);
begin
     fTotalSize := fFTP.Size(rFile);
     fFTP.Get(rfile,lfile);
end;

destructor TGFTP.Destroy;
begin
     inherited;
     fFTP.Free;
     fFiles.Free;
     FDirectories.Free;
end;

procedure TGFTP.Download(const rfile, lfile: String);
begin
     fTotalSize := fFTP.Size(rFile);
     fFTP.Get(lfile,rfile);
end;

procedure TGFTP.List(FileMask: String);
var dl:TStringList;
    x:Integer;
    line,
    fname, size, date,
    symlink, attrib,
    owner, group:String;
    IsDir:Boolean;

    Function InFileMask(Const name,mask:String):Boolean;
    var x,z:Integer;
    Begin
         Result := True;
         z := 1;
         For x:=1 To Length(mask) do
             Case mask[x] of
                  '_' : inc(z);
                  '*' : While (z<Length(name)) and (name[z]<>'.') do Inc(z);
                  else Begin
                            If UpCase(mask[x])<>UpCase(name[z]) Then
                            Begin
                                 Result := False;
                                 Break;
                            End Else
                                Inc(z);
                       End;
             End;
    End;
begin
     dl := TStringList.Create;
     Try
        fFTP.TransferType := ftBinary;
        fFTP.List(dl,'',True);

        FFiles.Clear;
        FDirectories.Clear;

        For x:=0 To Pred(dl.Count) do
        Begin
          line := dl[x];
          if ParseListingLine(FtpParse.TMFtpServerType(0),
                              Line, fname,
                              size, date, symlink, attrib,
                              owner, group,
                              IsDir) then
          begin
             If InFileMask(fName,FileMask) Then
             Begin
                 if IsDir then
                 begin
                    if (fname <> '.') and (fname <> '..') then
                       fDirectories.Add(fname, Attrib, Date, Size, Symlink, owner, group, '');
                 end
                 else
                 begin
                    fFiles.Add(fname, Attrib, Date, Size, Symlink, owner, group, '');
                 end;
             End;
          end;
        end;
     Finally
       dl.Free;
     End;
end;

procedure TGFTP.Login;
begin
     fFTP.Connect;
end;

procedure TGFTP.Quit;
begin
     fFTP.Disconnect;
end;

procedure TGFTP.RenameFile(const ofilename, nfilename: String);
begin
     fFTP.Rename(ofilename,nfilename);
end;

procedure TGFTP.StreamDownload(stream: TStream; const rfile, opid: String;
  startpos, rfilesize: Integer);
begin
     fTotalSize := fFTP.Size(rFile);
     fFTP.Get(rfile,stream,(startpos>0));
end;

procedure TGFTP.UpLoad(const lfile, rfile, opid: String);
var f:TFileStream;
begin
     f := TFileStream.Create(lFile,fmOpenRead);
     Try
        fTotalSize := f.Size;
     Finally
        f.Free;
     End;
     fFTP.Put(lfile,rfile);
end;

procedure TGFTP.Connect;
begin
     fFTP.Connect;
end;

function TGFTP.GetCurrrentDirectory: String;
begin
     Result := fFTP.GetNamePath;
end;

procedure TGFTP.SetPass(const Value: String);
begin
     fPass := Value;
     fFTP.Password := fPass;
end;

procedure TGFTP.SetPort(const Value: Integer);
begin
     fPort := Value;
     fFTP.Port := fPort;
end;

procedure TGFTP.SetPPass(const Value: String);
begin
     fPPass := Value;
     fFTP.ProxySettings.Password := fPPass;
end;

procedure TGFTP.SetProxyPort(const Value: Integer);
begin
     FProxyPort := Value;
     fFTP.ProxySettings.Port := FProxyPort;
end;

procedure TGFTP.SetProxyServer(const Value: String);
begin
     fProxyServer := Value;
     fFTP.ProxySettings.Host := fProxyServer;
end;

procedure TGFTP.SetProxyType(const Value: TMFtpProxyType);
begin
     fProxyType := Value;

     Case fProxyType of
          proxyNone     : fFTP.ProxySettings.ProxyType := fpcmNone;
          proxyHost     : fFTP.ProxySettings.ProxyType := fpcmTransparent;
          proxyHostUser : fFTP.ProxySettings.ProxyType := fpcmUserPass;
          proxyOpen     : fFTP.ProxySettings.ProxyType := fpcmOpen;
          proxySite     : fFTP.ProxySettings.ProxyType := fpcmSite;
          proxyUserSite : fFTP.ProxySettings.ProxyType := fpcmUserSite;
     End;
end;

procedure TGFTP.SetPUser(const Value: String);
begin
     fPUser := Value;
     fFTP.ProxySettings.UserName := Value;
end;

procedure TGFTP.SetServer(const Value: String);
begin
     fServer := Value;
     fFTP.Host := Value;
end;

procedure TGFTP.SetUser(const Value: String);
begin
     fUser := Value;
     fFTP.Username := Value;
end;

procedure TGFTP.SetUseRestart(const Value: Boolean);
begin
     fUseRestart := Value;
end;

function TGFTP.GetSupportResume: Boolean;
begin
     Result := fFTP.ResumeSupported;
end;

procedure TGFTP.SetPassive(const Value: Boolean);
begin
     FPassive := Value;
     fFTP.Passive := FPassive;
end;

procedure TGFTP.DoOnStatus(ASender: TObject; const AStatus: TIdStatus;
  const AStatusText: string);
begin

end;

procedure TGFTP.DoOnWork(Sender: TObject; AWorkMode: TWorkMode;
  const AWorkCount: Integer);
begin
     If Assigned(fOnProgress) Then
        fOnProgress(Sender,'',AWorkCount,fTotalSize);
end;

end.

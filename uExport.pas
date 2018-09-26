unit uExport;

interface

uses Windows, Messages, Dialogs, SysUtils, Classes, Forms, MyFuncs, MD5,
     wtsClient, wtsStream, Declarations, uConfig, IniFiles, WtsXmlConvert, FileCtrl,
     AbUnzper, AbZipper, AbBase, AbZipTyp, AbArcTyp, AbBrowse, AbZBrows,
     uLog, IBQuery, DB, IBDatabase;

type
  PRecordExp = ^TRecordExp;
  TRecordExp = record
    ID        : Integer;
    Tabela    : String[40];
    IDTabela  : Integer;
  end;

  ArrayOfRecordExp = Array of TRecordExp;

  PExport = ^TExport;

  TExportados = class
     private
       fConfigs : TConfigs;
       Pai:^TObject;
       fArqDataset:TIBQuery;
     public
      constructor Create(pai:PExport);
      destructor  Destroy; override;

      procedure  SetGenerator(GenId:Integer);
      procedure  SetGeneratorMaxId;

      function   GetArqAsList:TStringList;
      function   GetArqAsDataset(ReConsultar:Boolean = False): TIBQuery;

      procedure  DeleteReg(Tabela:String ; IDTabela:Integer);
      procedure  DeleteEmLote(var ArrayDeletar:ArrayOfRecordExp);
      procedure  LoadOnRecordSet(var RSet:TWtsRecordset);

      function   CheckTableExists:Boolean;
      function   Materializar:Boolean;

      property   Configs:TConfigs read fConfigs write fConfigs;
  end;

  TExport = class
    private
      fDirGravacao       : String;
      fExportados        : TExportados;
      fConfigs           : TConfigs;
      ExportMethods      : ArrayExportConfigs;
      fDataHoraLastExportacao: TDateTime;
      fLog:TLog;
      fLogName:String;
      fLogDir:String;

      procedure LoadExportMethodConfig;
      procedure SetConfigs(AConfigs:TConfigs);
      function CarregarCamposPaixFilho(TextoList:String):ArrOfFieldPai_FieldFilho;
    public
      constructor Create;
      destructor  Destroy; override;
      procedure   ProcessaExportacao;
      procedure   AtualizaGUIDCaixas;
      function    GetLastExp:TDateTime;
      procedure   CheckTriggers;

      property    DirGravacao:String read fDirGravacao write fDirGravacao;
      property    Exportados:TExportados read fExportados;
      property    Configs:TConfigs read fConfigs write SetConfigs;
      property    DataHoraLastExportacao:TDateTime read fDataHoraLastExportacao write fDataHoraLastExportacao;
      property    Log     : TLog read fLog write fLog;
      property    LogDir  : String read fLogDir write fLogDir;
      property    LogName : String read fLogName write fLogName;
  end;

  function  Key(Tabela:String ; IDTabela:Integer):String;
  procedure ClearList(Lst:TStringList);

const
  prefixExp = 'BM_';

implementation

uses uMain;

function Key(Tabela:String ; IDTabela:Integer):String;
begin
    Result := Tabela + ';' + IntToStr(IDTabela);
end;

{ TExport }

constructor TExport.Create;
begin
    fDataHoraLastExportacao := 0;
    fExportados         := TExportados.Create(Pointer(Self));
    LoadExportMethodConfig;
end;

destructor TExport.Destroy;
var
  x:Integer;
begin
    FreeAndNil(fExportados);
    For x:= Low(ExportMethods) to High(ExportMethods) Do
       if Assigned(ExportMethods[x].Filho) then
          Dispose(ExportMethods[x].Filho);
    inherited;
end;

procedure TExportados.LoadOnRecordSet(var RSet: TWtsRecordset);
var
  Qry:TIBQuery;
begin
    InitializeQuery(Qry);
    Try
      if Assigned(RSet) or (RSet<>nil) Then
         FreeAndNil(RSet);

      RSet             := TwtsRecordset.CreateFromStream(TMemoryStream.Create);
      RSet.Transaction := 'BMSYNC.CONTROLE.REG_EXPORTADO';

      Qry.SQL.Add('SELECT ID, TABELA, IDTABELA FROM REGS');
      Qry.Open;

      While Not Qry.Eof Do
      Begin
          RSet.New;
          RSet.FieldValuesByName['ID']       := Qry.FieldByName('ID').AsInteger;
          RSet.FieldValuesByName['TABELA']   := Qry.FieldByName('TABELA').AsString;
          RSet.FieldValuesByName['IDTABELA'] := Qry.FieldByName('IDTABELA').AsInteger;
          RSet.Add;
          Qry.Next;
      end;
    Finally
      FreeAndNil(Qry);
    End;
end;

function TExportados.Materializar: Boolean;
var
  RSExportados   : TWtsRecordSet;
  v              : Variant;
begin
   Result         := False;
   RSExportados   := nil;

   if (not CheckTableExists) Then
   Begin
       frmMain.SetFormStatus(screenCargaInicial, True);

       // Carrega no recordset os dados do Arquivo/Base Dados Sync.dat
       // LoadOnRecordSet(RSExportados);

       RSExportados := TwtsRecordset.CreateFromStream(TMemoryStream.Create);
       Try
         RSExportados.Transaction := 'BMSYNC.CONTROLE.REG_EXPORTADO';
         wtsCall('BMSYNC.CONTROLE.MATERIALIZAR', ['EXPORTADOS', 'TABLENAME'], [RSExportados.Data, fConfigs.TableMaterializada], v);
         Result := True;
       Finally
         FreeAndNil(RSExportados);
       End;

       frmMain.SetFormStatus(screenDefault, True);
   end;
end;

function TExportados.CheckTableExists: Boolean;
var
  v:Variant;
begin
  wtsCall('BMSYNC.CONTROLE.MATEXISTS',['TABLENAME'],[fConfigs.TableMaterializada],v);

  Result := VarToBool(v[0]);
end;

constructor TExportados.Create(pai:PExport);
begin
    Self.Pai        := Pointer(Pai);
    inherited Create;
end;

destructor TExportados.Destroy;
begin
    if Assigned(fArqDataset) then
       FreeAndNil(fArqDataset);

    inherited;
end;

procedure ClearList(Lst:TStringList);
var
  i:Integer;
begin
    if Assigned(Lst) then
    begin
        for i:=0 To Pred(Lst.Count) Do
          System.Dispose(Pointer(Lst.Objects[i]));

        While Lst.Count > 0 Do
          Lst.Delete(0);
    end;
end;

procedure TExport.SetConfigs(AConfigs: TConfigs);
begin
    // Ao Atribuir na "Exportacao", Repassar as configurações para a Classe "Exportados"
    Self.fConfigs             := AConfigs;
    Self.fExportados.fConfigs := AConfigs;
end;


procedure TExport.LoadExportMethodConfig;
var
  ArqExport, ArqFilho:TIniFile;
  x:Integer;
  str:String;
begin
    if not FileExists(sAppPath + 'BMSyncExp.rdo') Then
       raise Exception.Create('Arquivo BMSyncExp.rdo não foi encontrado.');
    Configs := GetIniConfigs;
    
    ArqExport := TIniFile.Create(sAppPath + 'BMSyncExp.rdo');
    Try
      x := 1;
      While ArqExport.SectionExists('ITEM-'+ IntToStr(x)) Do
      Begin
          SetLength(ExportMethods, x);
          ExportMethods[x-1].NameArq                := ArqExport.ReadString('ITEM-'+ IntToStr(x), 'NAMEARQ', '');
          if (Configs.Versao = '5') and (ArqExport.ValueExists('ITEM-'+ IntToStr(x),'METHODEXPORT5')) then
             ExportMethods[x-1].MethodExport        := ArqExport.ReadString('ITEM-'+ IntToStr(x), 'METHODEXPORT5', '')
          else
          if (Configs.Versao = '2006') and (ArqExport.ValueExists('ITEM-'+ IntToStr(x), 'METHODEXPORT2006')) then
             ExportMethods[x-1].MethodExport        := ArqExport.ReadString('ITEM-'+ IntToStr(x), 'METHODEXPORT2006', '')
          else
             ExportMethods[x-1].MethodExport        := ArqExport.ReadString('ITEM-'+ IntToStr(x), 'METHODEXPORT', '');
          ExportMethods[x-1].Prioridade             := ArqExport.ReadInteger('ITEM-'+ IntToStr(x),'PRIORIDADE', 0);
          ExportMethods[x-1].TypeStruct             := ArqExport.ReadInteger('ITEM-'+ IntToStr(x),'TYPESTRUCT', 0);
          ExportMethods[x-1].TriggerControl         := ArqExport.ReadBool(   'ITEM-'+ IntToStr(x),'TRIGGERCONTROL', False);
          ExportMethods[x-1].TriggerFieldTabela     := ArqExport.ReadString( 'ITEM-'+ IntToStr(x),'TRIGGER_FIELD_TABELA', '');
          ExportMethods[x-1].TriggerFieldID         := ArqExport.ReadString( 'ITEM-'+ IntToStr(x),'TRIGGER_FIELD_ID', '');
          ExportMethods[x-1].LastUpdateControl      := ArqExport.ReadBool(   'ITEM-'+ IntToStr(x),'LASTUPDATECONTROL', False);

          str := ArqExport.ReadString('ITEM-'+ IntToStr(x),'FILHO', '');
          if str <> '' Then
          begin
              New(ExportMethods[x-1].Filho);
              ArqFilho := TIniFile.Create(sAppPath + 'BMSyncExp.rdo');
              Try
                 if not ArqExport.SectionExists('FILHO-'+ str) then
                    raise Exception.Create('[FILHO-'+str+'] não foi encontrado no arquivo BMSyncExp.rdo');

                 ExportMethods[x-1].Filho^.NameArq         := ArqFilho.ReadString('FILHO-'+ str, 'NAMEARQ', '');
                 if (Configs.Versao = '5') and (ArqExport.ValueExists('FILHO-'+ IntToStr(x),'METHODEXPORT5')) then
                    ExportMethods[x-1].Filho^.MethodExport    := ArqFilho.ReadString('FILHO-'+ str, 'METHODEXPORT5', '')
                 else
                 if (Configs.Versao = '2006') and (ArqExport.ValueExists('FILHO-'+ IntToStr(x),'METHODEXPORT2006')) then
                    ExportMethods[x-1].Filho^.MethodExport    := ArqFilho.ReadString('FILHO-'+ str, 'METHODEXPORT2006', '')                 
                 else
                    ExportMethods[x-1].Filho^.MethodExport    := ArqFilho.ReadString('FILHO-'+ str,'METHODEXPORT', '');
                    
                 ExportMethods[x-1].Filho^.Prioridade      := ArqFilho.ReadInteger('FILHO-'+ str,'PRIORIDADE', 0);
                 ExportMethods[x-1].Filho^.TypeStruct      := ArqFilho.ReadInteger('FILHO-'+ str,'TYPESTRUCT', 0);
                 ExportMethods[x-1].Filho^.FieldsPaixFilho := CarregarCamposPaixFilho(ArqFilho.ReadString('FILHO-'+ str, 'Campos_PAIxFILHO', ''));
              finally
                FreeAndNil(ArqFilho);
              end;
          end;
          inc(x);
      end;
    Finally
      FreeAndNil(ArqExport);
    End;
end;


procedure TExport.ProcessaExportacao;
var
  x, y        : Integer;
  rs          : TWtsRecordset;
  XMLConverter: TWtsXmlConvert;
  Arqs        : TStringList;
  rsExportados,
  rsFilho,
  rsFilho_Child1: TWtsRecordSet;
  ChildName,
  sFieldPai,
  sFieldPai2,
  sFieldName  : String;
  rsCaixas    : TWtsRecordSet;
  rsConsCaixas: TWtsRecordSet;
  NamePastaZip: String;
  DirPastaZip : String;
  v           : Variant;
  ZipFile     : TAbZipper;
  pathErr     : String;
  InicioConsulta : Cardinal;
  sCurrentMethodExport:String;

  Procedure AddToArqs(l:TStringList);
  var i:Integer;
  Begin
       For i:=0 To Pred(l.Count) do
          Arqs.Add(l[i]);
       FreeAndNil(l);
  End;
begin
    Arqs                     := TStringList.Create;
    rsExportados             := TwtsRecordset.CreateFromStream(TMemoryStream.Create);
    rsExportados.Transaction := 'BMSYNC.CONTROLE.REG_EXPORTADO';
    NamePastaZip             := prefixExp + FormatDateTime('yyyymmddhhnnss', Now());
    DirPastaZip              := Configs.DirGravacao + NamePastaZip + '\';

    pathErr  := Configs.DirGravacao + _pastaErros;
    ForceDirectories(PathErr);

    rsCaixas             := TwtsRecordset.CreateFromStream(TMemoryStream.Create);
    rsCaixas.Transaction := 'BMSYNC.CAIXAS.REGISTRO_DIARIO';
    Try
      Try
        For x:= 0 To High(ExportMethods) Do
        Begin
            sCurrentMethodExport := ExportMethods[x].MethodExport;

            if (sCurrentMethodExport <> '') Then
            Begin
                FLog.AddLog(LogMinimun, Informacao, 'Iniciando Consulta Exportação ('+ ExportMethods[x].NameArq +')', Self.LogDir, Self.LogName,
                            FormatDateTime('dd/mm/yyyy hh:nn:ss',Now()));

                InicioConsulta := GetTickCount;

                if ExportMethods[x].TriggerControl Then
                   wtsCallEx(ExportMethods[x].MethodExport, ['TABLENAME'], [fConfigs.TableMaterializada], rs)
                Else
                if ExportMethods[x].LastUpdateControl Then
                   wtsCallEx(ExportMethods[x].MethodExport, ['DATA_LASTEXP'], [Self.DataHoraLastExportacao], rs)
                else
                   raise Exception.Create('Tipo da exportação de "'+ ExportMethods[x].NameArq +'" não foi detectado.');

                FLog.AddLog(LogMinimun, Informacao, 'Finalizado Consulta ('+ ExportMethods[x].NameArq +')', Self.LogDir, Self.LogName,
                            FormatDateTime('dd/mm/yyyy hh:nn:ss',Now()) + ' - Tempo Consulta: '+ tempoResumido(MSecsToDateTime(GetTickCount - InicioConsulta)));

                Try
                    if not rs.Eof Then
                    Begin
                        ChildName := '';

                        if Assigned(ExportMethods[x].Filho) Then
                        begin
                           // Verifica se o Filho acessa subrecordset do Pai e cria o Recordset
                           For y:=Low(ExportMethods[x].Filho.FieldsPaixFilho) to High(ExportMethods[x].Filho.FieldsPaixFilho) Do
                           begin
                               if Pos('.', ExportMethods[x].Filho.FieldsPaixFilho[y].FieldPai) > 0 Then
                               begin
                                   ChildName := Copy(ExportMethods[x].Filho.FieldsPaixFilho[y].FieldPai,1,Pos('.', ExportMethods[x].Filho.FieldsPaixFilho[y].FieldPai)-1);
                                   Break;
                               end;
                           end;

                           rsFilho := TWtsRecordset.CreateFromStream(TMemoryStream.Create);
                           rsFilho.Transaction := ExportMethods[x].Filho.MethodExport;
                        end;

                        if not DirectoryExists(DirPastaZip) Then
                           ForceDirectories(DirPastaZip);

                        // Atribui o GUID no recordSet para exportar e gravar no Banco
                        While Not rs.Eof Do
                        Begin
                            If (rs.IndexOfField('GUID') > -1) And (VarToStr(rs.FieldValuesByName['GUID']) = '') Then
                            Begin
                               rs.FieldValuesByName['GUID'] := 'BM'+GenerateGuid;
                               rs.Update;
                            End;

                            // Adiciona Caixa na Lista, caso ainda não esteja
                            if (rs.IndexOfField('REGISTRO_DIARIO') > -1) And (VarToStr(rs.FieldValuesByName['REGISTRO_DIARIO']) <> '') Then
                               if not rsCaixas.Locate(['REGISTRO_DIARIO'],[rs.FieldValuesByName['REGISTRO_DIARIO']]) Then
                               begin
                                  rsCaixas.New;
                                  rsCaixas.FieldValuesByName['REGISTRO_DIARIO']  := rs.FieldValuesByName['REGISTRO_DIARIO'];
                                  rsCaixas.Add;
                               end;

                            rs.Next;
                        End;

                        XMLConverter := TWtsXmlConvert.Create;
                        Try
                          XMLConverter.OutPutDirectory := DirPastaZip;
                          AddToArqs( XMLConverter.RecordSetToXml(rs, ExportMethods[x].NameArq, ExportMethods[x].NameArq, ExportMethods[x].Prioridade, ExportMethods[x].TypeStruct) );

                          rs.First;
                          While not rs.Eof Do
                          Begin
                              if ExportMethods[x].TriggerControl Then
                              Begin
                                  rsExportados.New;
                                  rsExportados.FieldValuesByName['TABELA']   := rs.FieldValuesByName['TABLENAME'];
                                  rsExportados.FieldValuesByName['IDTABELA'] := rs.FieldValuesByName['IDTABELA'];
                                  If rs.IndexOfField('GUID') > -1 Then
                                     rsExportados.FieldValuesByName['GUID']     := rs.FieldValuesByName['GUID'];
                                  rsExportados.Add;
                              end;

                              if Assigned(rsFilho) and (rsFilho <> nil) Then
                              Begin
                                  Try
                                     if ChildName <> '' then
                                       rsFilho_Child1 := rs.CreateFieldRecordset(ChildName);

                                     Try
                                       While (not Assigned(rsFilho_Child1)) or (not rsFilho_Child1.Eof) Do
                                       begin
                                           rsFilho.New;
                                           For y:=Low(ExportMethods[x].Filho.FieldsPaixFilho) to High(ExportMethods[x].Filho.FieldsPaixFilho) Do
                                           begin
                                              sFieldPai  := ExportMethods[x].Filho.FieldsPaixFilho[y].FieldPai;
                                              sFieldName := ExportMethods[x].Filho.FieldsPaixFilho[y].FieldFilho;

                                              if CountChar(sFieldPai, '"') >= 2 Then
                                              begin
                                                  rsFilho.FieldValuesByName[sFieldName] := StringReplace(sFieldPai,'"','',[rfReplaceAll]);
                                              end else
                                              if Pos('.', sFieldPai) > 0 Then
                                              begin
                                                  sFieldPai2 := Copy(sFieldPai,Pos('.', sFieldPai)+1,MaxInt);
                                                  rsFilho.FieldValuesByName[sFieldName] := rsFilho_child1.FieldValuesByName[sFieldPai2];
                                              end else
                                              begin
                                                  rsFilho.FieldValuesByName[sFieldName] := rs.FieldValuesByName[sFieldPai];
                                              end;
                                           end;
                                           rsFilho.Add;

                                           if Assigned(rsFilho_Child1) Then
                                              rsFilho_Child1.Next
                                           else
                                              Break;
                                       end;
                                     Finally
                                       FreeAndNil(rsFilho_Child1);
                                     End;
                                  Except
                                    On E : Exception Do
                                    Begin
                                        e.message := 'Erro ao processar FILHO.' +#13+'ERROR: ' + e.message + #13#13 + 'Verifique a configuração no arquivo BMSyncExp.rdo';
                                        raise;
                                    end;
                                  End;
                              end;

                              rs.Next;
                          end;

                          if Assigned(rsFilho) Then
                          Begin
                              Try
                                if rsFilho.RecordCount > 0 Then
                                   AddToArqs( XMLConverter.RecordSetToXml(rsFilho, ExportMethods[x].Filho.NameArq, ExportMethods[x].Filho.NameArq, ExportMethods[x].Filho.Prioridade, ExportMethods[x].Filho.TypeStruct) );
                              Finally
                                FreeAndNil(rsFilho);
                              End;
                          End;
                        Finally
                          FreeAndNil(XMLConverter);
                        End;
                    end;
                Finally
                  FreeAndNil(rs);
                  FreeAndNil(rsFilho);
                End;
            end;
        end;

        // Exporta arquivo de CAIXAS
        if rsCaixas.RecordCount > 0 Then
        Begin
            rsCaixas.First;
            wtsCallEx('BMSYNC.CAIXAS.BUSCA',['CAIXAS'],[rsCaixas.Data], rsConsCaixas);
            if not rsConsCaixas.Eof Then
            begin
               XMLConverter := TWtsXmlConvert.Create;
               Try
                 XMLConverter.OutPutDirectory := DirPastaZip;
                 AddToArqs( XMLConverter.RecordSetToXml(rsConsCaixas, 'CAIXAS', 'CAIXAS', 99, Output_TypeStruct) );
               Finally
                 FreeAndNil(XMLConverter);
               End;
            end;
        End;

        If (Arqs.Count > 0) Then
        Begin
            If (not rsExportados.Eof) Then
            Begin
                rsExportados.First;
                wtsCall('BMSYNC.CONTROLE.ClearBATCH', ['TABLENAME','EXPORTADOS'], [fConfigs.TableMaterializada, rsExportados.Data], v);
            End;

            ZipFile := TAbZipper.Create( Nil );
            Try
               ZipFile.CompressionMethodToUse := smBestMethod;
               ZipFile.FileName := DirPastaZip + NamePastaZip+'.zip';
               ZipFile.StoreOptions := [soStripDrive, soStripPath, soRemoveDots, soRecurse, soFreshen, soReplace];
               ZipFile.AddFiles( DirPastaZip + '*.xml', faAnyFile);
               ZipFile.Save;
            Finally
               ZipFile.Free;
            End;

            For X:=0 to Arqs.Count -1 Do
               DeleteFile(PChar(DirPastaZip + Arqs.Strings[x]));

            MoveFile(PChar(DirPastaZip + NamePastaZip + '.zip'), PChar(Configs.DirGravacao + NamePastaZip + '.zip'));
            RemoveDir(DirPastaZip);
        end;
      Except
        On E : Exception Do
        Begin
            FLog.AddLog(LogMinimun, Erro, 'Erro exportando', pathErr, NamePastaZip, 'MethodExport: '+ sCurrentMethodExport +#13#10+
                                                            'Error: '+ e.message);

            For X:=0 to Arqs.Count -1 Do
               DeleteFile(PChar(DirPastaZip + Arqs.Strings[x]));

            if DirectoryExists(DirPastaZip) Then
               RemoveDir(DirPastaZip);
        End;
      End;
    Finally
      FreeAndNil(Arqs);
      FreeAndNil(rsExportados);
      FreeAndNil(rsCaixas);
      FreeAndNil(rsConsCaixas);
    End;
end;

procedure TExportados.DeleteReg(Tabela: String; IDTabela: Integer);
var
  Qry : TIBQuery;
begin
    InitializeQuery(Qry);
    Try
      if glb_IBTransaction.Active then
         glb_IBTransaction.Active := False;
         
      glb_IBTransaction.StartTransaction;
      Try
        Qry.SQL.Add('DELETE FROM REGS WHERE TABELA=:TABELA AND IDTABELA=:IDTABELA');
        Qry.ParamByName('TABELA').AsString    := TABELA;
        Qry.ParamByName('IDTABELA').AsInteger := IDTABELA;
        Qry.ExecSQL;

        glb_IBTransaction.Commit;
      except
        glb_IBTransaction.Rollback;
        raise;
      end;
      glb_IBTransaction.Active := False;
    finally
      FreeAndNil(Qry);
    end;
end;

procedure TExportados.DeleteEmLote(var ArrayDeletar: ArrayOfRecordExp);
var
  rsDeletar:TWTsRecordset;
  v:Variant;
  x:Integer;
  TempRecord:TRecordExp;
begin
    rsDeletar             := TwtsRecordset.CreateFromStream(TMemoryStream.Create);
    rsDeletar.Transaction := 'BMSYNC.CONTROLE.REG_EXPORTADO';
    Try
      For x:= 0 To High(ArrayDeletar) Do
      Begin
          TempRecord.ID       := ArrayDeletar[x].ID;
          TempRecord.IDTabela := ArrayDeletar[x].IDTabela;
          TempRecord.Tabela   := ArrayDeletar[x].Tabela;

          DeleteReg(TempRecord.Tabela, TempRecord.IDTabela);

          rsDeletar.New;
          rsDeletar.FieldValuesByName['ID']       := TempRecord.ID;
          rsDeletar.FieldValuesByName['TABELA']   := TempRecord.Tabela;
          rsDeletar.FieldValuesByName['IDTABELA'] := TempRecord.IDTabela;
          rsDeletar.Add;
      end;

      GetArqAsDataSet(True);
      if rsDeletar.RecordCount > 0 Then
         wtsCall('BMSYNC.CONTROLE.DELETEBATCH', ['TABLENAME','DELETADOS'], [fConfigs.TableMaterializada, rsDeletar.Data], v);
    Finally
      FreeAndNil(rsDeletar);
    End;
end;

procedure TExport.AtualizaGUIDCaixas;
var
  rs:TWtsRecordset;
  rsCaixas:TWtsRecordset;
  v:Variant;
begin
    // Exporta arquivo de CAIXAS
    wtsCallEx('BMSYNC.CAIXAS.GUID_NULL',[''],[], rs);
    Try
      if not rs.Eof Then
      begin
         rsCaixas             := TwtsRecordset.CreateFromStream(TMemoryStream.Create);
         rsCaixas.Transaction := 'BMSYNC.CAIXAS.REGISTRO_DIARIO';

         While Not rs.Eof Do
         Begin
             rsCaixas.New;
             rsCaixas.FieldValuesByName['REGISTRO_DIARIO'] := rs.FieldValuesByName['REGISTRO_DIARIO'];
             rsCaixas.FieldValuesByName['GUID']            := 'BM'+GenerateGuid;
             rsCaixas.Add;
             
             rs.Next;
         End;
         rs.First;

         wtsCall('BMSYNC.CAIXAS.ATUALIZAGUIDCAIXAS',['CAIXAS'],[rsCaixas.Data],v);
      End;
    Finally
      FreeAndNil(rs);
      FreeAndNil(rsCaixas);
    End;
end;

function TExport.CarregarCamposPaixFilho(TextoList: String):ArrOfFieldPai_FieldFilho;
var
  i:Integer;
  Texto:String;
  Item:String;
  IndexDelimitador:Integer;
  IndexSub:Integer;
const
  Delimitador = ';';
  SubDelimitador = '|';
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

       If not((Item[1]='(') And (Item[Length(Item)]=')')) Then
          raise Exception.Create('Parenteses não encontrado em CarregarRedirecionamentos');
       Item := Copy(Item,2, Length(Item)-2 ); // Remove parenteses no inicio e no fim.

       IndexSub := Pos(SubDelimitador, Item);
       If IndexSub = 0 Then
          raise Exception.Create('SubDelimitador não encontrado em CarregarRedirecionamentos');

       SetLength(Result, i+1);
       Result[i].FieldPai   := Copy(Item, 1, IndexSub-1);
       Result[i].FieldFilho := Copy(Item, IndexSub+1, MaxInt);
       Inc(i);
    Until Pos(Delimitador, Texto) = 0;
end;

function TExport.GetLastExp: TDateTime;
Var
  IniFile:TIniFile;
  Dia:Word;
  Mes:Word;
  Ano:Word;
  Hora:Word;
  Min:Word;
  Seg:Word;
begin
    IniFile := TIniFile.Create(sIniName);
    Try
       Ano := IniFile.ReadInteger('LASTEXP', 'ANO' , 0);
       Mes := IniFile.ReadInteger('LASTEXP', 'MES' , 0);
       Dia := IniFile.ReadInteger('LASTEXP', 'DIA' , 0);
       Hora:= IniFile.ReadInteger('LASTEXP', 'HORA', 0);
       Min := IniFile.ReadInteger('LASTEXP', 'MIN' , 0);
       Seg := IniFile.ReadInteger('LASTEXP', 'SEG' , 0);
       Result := EncodeDate(Ano, Mes, Dia) + EncodeTime(Hora, Min, Seg, 0);
    Finally
       FreeAndNil(IniFile);
    End;
end;

function TExportados.GetArqAsList: TStringList;
var
  Qry         : TIBQuery;
  PInput      : PRecordExp;
begin
    Result := TStringList.Create;
    Qry    := GetArqAsDataset;

    while not Qry.Eof Do
    begin
        New(PInput);
        PInput.ID         := Qry.FieldByName('ID').AsInteger;
        PInput.Tabela     := Qry.FieldByName('TABELA').AsString;
        PInput.IDTabela   := Qry.FieldByName('IDTABELA').AsInteger;
        Result.AddObject(Key(PInput.Tabela, PInput.IDTabela), Pointer(PInput));

        Qry.Next;
    end;
end;

function TExportados.GetArqAsDataset(ReConsultar:Boolean = False): TIBQuery;
var
  Created:Boolean;
begin
    Created := False;
    if (not Assigned(fArqDataset)) or (fArqDataset = nil) then
    begin
        FreeAndNil(fArqDataset);
        InitializeQuery(fArqDataset);
        Created := True;
    end;

    if Created or ReConsultar then
    begin
        fArqDataset.SQL.Clear;;
        fArqDataset.SQL.Add('SELECT ID, TABELA, IDTABELA FROM REGS');
        fArqDataset.Open;
    End;

    Result := fArqDataset;
end;

procedure TExportados.SetGenerator(GenId: Integer);
var
  Qry : TIBQuery;
begin
    InitializeQuery(Qry);
    Try
      if glb_IBTransaction.Active then
         glb_IBTransaction.Active := False;
         
      glb_IBTransaction.StartTransaction;
      try
        Qry.SQL.Add('SET GENERATOR GENERATOR_ID_REGS TO '+ IntToStr(GenID));
        Qry.ExecSQL;
        glb_IBTransaction.Commit;
      except
        glb_IBTransaction.Rollback;
        raise;
      end;
    Finally
      FreeAndNil(Qry);
    end;
end;

procedure TExportados.SetGeneratorMaxId;
var
  Qry : TIBQuery;
begin
    InitializeQuery(Qry);
    Try
      try
        Qry.SQL.Add('SELECT MAX(ID) AS MAXID FROM REGS');
        Qry.Open;
        SetGenerator(Qry.FieldByName('MAXID').AsInteger);
      except
        glb_IBTransaction.Rollback;
        raise;
      end;
    Finally
      FreeAndNil(Qry);
    end;
end;

procedure TExport.CheckTriggers;
var
  x, y  : Integer;
  Qry, Qry2 : TIBQuery;
  S     : String;
begin
    InitializeQuery(Qry, glb_MILLENNIUM_DATABASE);
    try
      Qry.SQL.Add('SELECT RDB$GENERATOR_NAME FROM RDB$GENERATORS ');
      Qry.SQL.Add('WHERE RDB$SYSTEM_FLAG IS DISTINCT FROM 1 AND RDB$GENERATOR_NAME="'+ sDefaultGeneratorName+'"');
      Qry.Open;

      if Qry.Eof then
      begin
        if glb_MILLENNIUM_Transaction.Active then
           glb_MILLENNIUM_Transaction.Active := False;

        glb_MILLENNIUM_Transaction.StartTransaction;
        try
          Qry.SQL.Clear;
          Qry.SQL.Add('CREATE SEQUENCE '+ sDefaultGeneratorName);
          Qry.ExecSQL;
          glb_MILLENNIUM_Transaction.Commit;
        except
          glb_MILLENNIUM_Transaction.Rollback;
          raise;
        end;

        Qry.SQL.Clear;
        Qry.SQL.Add('SELECT MAX(IDFAB) MAXID FROM '+ fConfigs.TableMaterializada);
        Qry.Open;

        X := 0;
        if not Qry.Eof Then
           X := Qry.FieldByName('MAXID').AsInteger;

        if glb_MILLENNIUM_Transaction.Active then
           glb_MILLENNIUM_Transaction.Active := False;

        glb_MILLENNIUM_Transaction.StartTransaction;
        try
          Qry.SQL.Clear;
          Qry.SQL.Add('ALTER SEQUENCE '+ sDefaultGeneratorName +' RESTART WITH '+ IntToStr(x) +';');
          Qry.ExecSQL;
          glb_MILLENNIUM_Transaction.Commit;
        except
          glb_MILLENNIUM_Transaction.Rollback;
          raise;
        end;
      end;

      // Consulta todas as Triggers para usar Locate
      Qry.SQL.Clear;
      Qry.SQL.Add('SELECT TRIM(TG.RDB$TRIGGER_NAME) as TRIG_NAME FROM RDB$TRIGGERS TG ');
      Qry.Open;

      Try
        For x:= 0 To High(ExportMethods) Do
        Begin
            if ExportMethods[x].TriggerControl then
            begin
                For y:=0 to 2 Do
                Begin
                    case y of
                      0 : S := _TriggerAlter;
                      1 : S := _TriggerInsert;
                      2 : S := _TriggerDelete;
                    End;

                    if not Qry.Locate('TRIG_NAME', 'EI_'+ ExportMethods[x].TriggerFieldTabela + '_' + IntToStr(y), [loCaseInsensitive]) Then
                    begin
                        InitializeQuery(Qry2, glb_MILLENNIUM_DATABASE);

                        try
                          Qry2.SQL.Add('CREATE OR ALTER TRIGGER EI_'+ ExportMethods[x].TriggerFieldTabela  + '_' + IntToStr(y) + ' FOR '+ ExportMethods[x].TriggerFieldTabela );
                          Qry2.SQL.Add('ACTIVE AFTER '+ S);
                          Qry2.SQL.Add('AS ');
                          Qry2.SQL.Add('  declare variable vIDFAB INTEGER; ');
                          Qry2.SQL.Add('begin ');
                          Qry2.SQL.Add('   Insert Into '+ fConfigs.TableMaterializada +' (IDFAB, TABELA, IDTABELA, TIPO) ');
                          Qry2.SQL.Add('   Values (GEN_ID('+sDefaultGeneratorName+', 1),');
                          Qry2.SQL.Add('            "'  + ExportMethods[x].TriggerFieldTabela + '", ');
                          if S = _TriggerAlter then
                          begin
                              Qry2.SQL.Add('           NEW.'+ ExportMethods[x].TriggerFieldID + ', ');
                              Qry2.SQL.Add('               "U");');
                          end else
                          if S = _TriggerInsert then
                          begin
                              Qry2.SQL.Add('           NEW.'+ ExportMethods[x].TriggerFieldID + ', ');
                              Qry2.SQL.Add('               "I");');
                          end else
                          if S = _TriggerDelete then
                          begin
                              Qry2.SQL.Add('           OLD.'+ ExportMethods[x].TriggerFieldID + ', ');
                              Qry2.SQL.Add('               "D");');
                          end;

                          Qry2.SQL.Add('end; ');
                          Qry2.ExecSQL;
                        finally
                          FreeAndNil(Qry2);
                        end;
                    end;
                End;
            end;
        End;
        glb_MILLENNIUM_Transaction.Commit;
      except
        glb_MILLENNIUM_Transaction.Rollback;
        raise;
      end;
    finally
      FreeAndNil(Qry);
    end;
end;

end.

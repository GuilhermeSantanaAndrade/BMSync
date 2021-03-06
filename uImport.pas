unit uImport;

interface

uses Windows, Messages, Dialogs, SysUtils, Classes, Forms, MyFuncs, MD5,
     wtsClient, wtsStream, Declarations, uConfig, IniFiles, WtsXmlConvert, FileCtrl,
     AbUnzper, AbZipper, AbBase, AbZipTyp, AbArcTyp, AbBrowse, AbZBrows, ResourceLock,
     XpDOM, Scanner, uLog;

type
  TypeImportacao = (typInsercao, typAlteracao);

  RRedirecionamento = record
    De   : String;
    Para : String;
  end;
  ArrOfRedirecionamento = Array of RRedirecionamento;

    TArquivo=class
    private
      fFileName:String;
      fMethodInclusao:String;
      fMethodAlteracao:String;

      fMethodConsulta:String;
      fCampoDeConsulta:String;
      fCamposDeAlteracao:ArrayofString;

      fPrioridade:Integer;
      fChave:String;
      fSectionImport:String;
      fDateExp:TDateTime;

      RecordSetOfXML:TWtsRecordSet;
      Redirecionamentos:ArrOfRedirecionamento;
      ListForeignKeys:TStringList;

      function RedirecionarNome(var NomeCampo: String; AlterarSeEncontrar:Boolean=False ): Boolean;
    public
      FullFileName:String;
      Dir:String;

      destructor Destroy; override;

      property FileName:String read fFileName write fFileName;
  end;

  TProcessFile=class
    private
      fConfigs:TConfigs;
      ZipName :String;
      fLog:TLog;
      fTypeOfCurrentExp:TypeImportacao;
      procedure PopularMetodoImportacao(Xml:TArquivo ; rsMethodImportacao: TWtsRecordset);
      Function  getCampo(RecordSetOfXML:TWtsRecordSet ; XML:TArquivo ; NomeCampo:String):Variant;
      Function  getCampoRecordSet(RecordSetPai:TwtsRecordset; XML : TArquivo ; NomeCampo:String ):String;
      procedure Processar(Tipo : TypeImportacao ; Xml: TArquivo ; var rsMethodImportacao : TWtsRecordset);
      function  CarregarRedirecionamentos(TextoList : String ):ArrOfRedirecionamento;
      function  CarregarForeignKeys(TextoList : String ):TStringList;
    public
      procedure Execute;

      property  Configs:TConfigs read fConfigs write fConfigs;
      property  Log:TLog         read fLog write fLog;
  end;

  TImport=class
    private
      fConfigs:TConfigs;
      fLog:TLog;
    public
      procedure   ProcessaImportacao;
      constructor Create;
      destructor  Destroy;override;

      property  Configs:TConfigs read fConfigs write fConfigs;
  end;

  procedure AplicarTratamentos_Saidas(Typ:TypeImportacao ; var rsMethodImportacao:TWtsRecordset);
  procedure AplicarTratamentos_Entradas(Typ:TypeImportacao ; var rsMethodImportacao:TWtsRecordset);

var
  ArquivosZip : TStringList;
  Lock  : TezResourceLock;
  nFiles: Integer;

implementation

constructor TImport.Create;
begin
    fLog := TLog.Create(nil);
    fLog.DefaultDirectoryOutput := ExtractFilePath(ParamStr(0));
end;

destructor TImport.Destroy;
begin
  inherited;
  FreeAndNil(fLog);
end;

procedure TImport.ProcessaImportacao;
var
  x          : Integer;
  sr         : TSearchRec;
  Processador: TProcessFile;
begin
     x := FindFirst( fConfigs.DirLeitura + '*.zip' ,faArchive , sr );
     Try
        While x = 0 do
        begin
             Lock.Lock;
             Try
                ArquivosZip.AddObject(fConfigs.DirLeitura + sr.Name, Pointer(0));
                nFiles := ArquivosZip.Count;
             Finally
                Lock.UnLock;
             End;
             x := FindNext(sr);
        End;
     Finally
        FindClose( sr );
     End;

     //TO-DO: Listar na Tela Pacotes em importa��o.

     Processador := TProcessFile.Create;
     Processador.Log := fLog;
     Processador.Execute;
end;

{ TProcessFile }

procedure OrdenarPorPrioridade(var ListaXMLs : TStringList );
Var
  ListaOrdenada:TStringList;
  PrioridadesUtilizadas:Array of Integer;
  i, x, j, old : Integer;
  Prioridade:Integer;

  function ExistePrioridadeNoArray(iValue:Integer):boolean;
  var u : integer;
  begin
      Result := False;
      For u:=0 To High(PrioridadesUtilizadas) Do
      Begin
          if PrioridadesUtilizadas[u] = iValue Then
          Begin
              Result := True;
              Break;
          End;
      end;
  end;
Begin
    Try
      x := 0;
      SetLength(PrioridadesUtilizadas, x);
      For i:=0 To Pred(ListaXMLs.Count) Do
      Begin
          Prioridade := TArquivo(ListaXMLs.Objects[i]).fPrioridade;
          if not ExistePrioridadeNoArray(Prioridade) Then
          Begin
             Inc(x);
             SetLength(PrioridadesUtilizadas, x);
             PrioridadesUtilizadas[x-1] := Prioridade;
          End;
      end;

      If Length(PrioridadesUtilizadas) > 1 Then
      Begin
          for I := Low(PrioridadesUtilizadas) to (High(PrioridadesUtilizadas)-1) do
          begin
              for J := I+1 to High(PrioridadesUtilizadas) do
              begin
                   if PrioridadesUtilizadas[I] < PrioridadesUtilizadas[J] then
                   begin
                       old                      := PrioridadesUtilizadas[I];
                       PrioridadesUtilizadas[I] := PrioridadesUtilizadas[J];
                       PrioridadesUtilizadas[J] := old
                   end;
              end;
          end;

          ListaOrdenada := TStringList.Create;
          For I := Low(PrioridadesUtilizadas) to High(PrioridadesUtilizadas) do
          begin
              For j:=0 To Pred(ListaXMLs.Count) Do
              Begin
                  if TArquivo(ListaXMLs.Objects[j]).fPrioridade = PrioridadesUtilizadas[i] Then
                     ListaOrdenada.AddObject( TArquivo(ListaXMLs.Objects[j]).FullFileName, Pointer( TArquivo(ListaXMLs.Objects[j]) ));
              End;
          end;
          ListaXMLs.Free;
          ListaXMLs := Pointer(ListaOrdenada);
      End;
    Except
      On E : Exception Do
      Begin
          raise Exception.Create('Erro ao Ordenar Arquivos XML. Message: '+ e.message);
      End;
    End;
end;

procedure TProcessFile.Execute;
var
  pathTemp, pathOk, pathErr : String;
  UnzipFile   : TAbUnZipper;
  ListaXMLs   : TStringList;
  ImportINI   : TIniFile;
  Converter   : TWtsXmlConvert;
  i, x, iPos  : Integer;
  sPart1,
  sPart2,
  sPart3,
  CampoRecordset, RefRecordSet:String;
  XML         : TArquivo;
  ok          : boolean;
  rsClientConsulta : TwtsClientRecordset;
  rsMethodAlteracao: TWtsRecordset;
  rsMethodInclusao : TWtsRecordset;
  rsChild          : TwtsRecordset;

  function ZipDescompact(pathTemp, ZipName:String):TStringList;
  Var
    y          : Integer;
    ArquivoXML : TArquivo;
    st         : TFileStream;
    DomXml     : TXpObjModel;
    AuxStream  : String;
  begin
      Result := TStringList.Create;
      Lock.Lock;
      Try
         UnzipFile := TAbUnZipper.Create( Nil );
         Try
            UnzipFile.ExtractOptions := [eoCreateDirs];
            UnzipFile.FileName       := ZipName;
            UnzipFile.BaseDirectory  := PathTemp;
            UnzipFile.ExtractFiles('*.*');

            For y:=0 to UnzipFile.Count -1 do
            Begin
                ArquivoXML              := TArquivo.Create;
                ArquivoXML.Dir          := PathTemp;
                ArquivoXML.FileName     := UnzipFile.Items[y].FileName;
                ArquivoXML.FullFileName := PathTemp + UnzipFile.Items[y].FileName;

                // Rotina para extrair informa��es do cabe�alho
                st := TFileStream.Create( ArquivoXML.FullFileName, fmOpenRead );
                Try
                   SetLength(AuxStream, 2048);
                   SetLength(AuxStream, st.Read(AuxStream[1], 2048));
                Finally
                   st.Free;
                End;
                AuxStream := Copy(AuxStream, 1, Pos( '>' , AuxStream ) -1) + '/>';

                DomXml := TXpObjModel.Create( Nil );
                Try
                  DomXml.LoadMemory(AuxStream[1],Length(AuxStream));
                  ArquivoXML.fPrioridade       := StrToIntDef(DomXml.Document.DocumentElement.GetAttribute('PRIORIDADE'),0);
                  ArquivoXML.fChave            := DomXml.Document.DocumentElement.GetAttribute('CHAVE');
                  ArquivoXML.fSectionImport    := UpperCase(DomXml.Document.DocumentElement.GetAttribute('SECTIONIMPORT'));

                  If ArquivoXML.fSectionImport <> 'CAIXAS' Then
                  Begin
//                      if not ImportINI.SectionExists(ArquivoXML.fSectionImport) then
//                         raise Exception.Create('Erro em BMSyncImp.rdo. Se��o n�o encontrada: "'+ ArquivoXML.fSectionImport +'"');
                      ArquivoXML.fDateExp          := ImportINI.ReadDateTime(ArquivoXML.fSectionImport, 'DATE', Now);
                      ArquivoXML.fMethodInclusao   := ImportINI.ReadString(ArquivoXML.fSectionImport,'1_METHODINCLUSAO',  'NULL');
                      ArquivoXML.fMethodAlteracao  := ImportINI.ReadString(ArquivoXML.fSectionImport,'2_METHODALTERACAO', 'NULL');
                      ArquivoXML.fCamposDeAlteracao:= StringToArray(ImportINI.ReadString(ArquivoXML.fSectionImport,'2_CAMPODEALTERACAO',''));
                      ArquivoXML.fMethodConsulta   := ImportINI.ReadString(ArquivoXML.fSectionImport,'3_METHODCONSULTA',  'NULL');
                      ArquivoXML.fCampoDeConsulta  := ImportINI.ReadString(ArquivoXML.fSectionImport,'3_CAMPODEBUSCA',    'NULL');
                      ArquivoXML.Redirecionamentos := CarregarRedirecionamentos(ImportINI.ReadString(ArquivoXML.fSectionImport,'RedirecionamentosDeCampos', ''));
                      ArquivoXML.ListForeignKeys   := CarregarForeignKeys(ImportINI.ReadString(ArquivoXML.fSectionImport,'ForeignKeys', ''));

//                      if (IsNull(ArquivoXML.fMethodInclusao)) or
//                         ((NotNull(ArquivoXML.fMethodAlteracao)) and (IsNull(ArquivoXML.fMethodConsulta))) then
//                         raise Exception.Create('Erro em BMSyncImp.rdo. Se��o "'+ ArquivoXML.fSectionImport +'" Configura��o incorreta.');
                  End;
                Finally
                   DomXml.Free;
                End;

                Result.AddObject(ArquivoXML.FullFileName ,Pointer(ArquivoXML));
            End;
         Finally
            UnzipFile.Free;
         End;
         Result := Result;
      Finally
         Lock.Unlock;
      End;
  end;

  procedure ProcessaCaixas(Xml : TArquivo);
  Var
    Filial, numeroConta, Conta, DataAbertura, DataFechamento:Variant;
    v:Variant;
    rs, rsCaixas:TWtsRecordset;
    d1, d2 :Double;
  Begin
      if Xml.fSectionImport = 'CAIXAS' then
      begin
          While not Xml.RecordSetOfXML.Eof Do
          Begin
              Filial := getCampo(Xml.RecordSetOfXML, Xml, 'COD_FILIAL');

              if VarToStr(Filial) = '' Then
                 raise Exception.Create('Filial "'+ VarToStr(Filial) +'" n�o cadastrada.');

              numeroConta := XML.RecordSetOfXML.FieldValuesByName['NUMCONTA'];

              if VarToStr(numeroConta) = '' Then
                 raise Exception.Create('NUMCONTA n�o pode ser nulo.');

              wtsCall('BMSYNC.CAIXAS.PROCURACONTA', ['NUMCONTA','FILIAL'], [numeroConta, Filial], v);
              Conta := v[0];

              if (VarToStr(Conta) <> '') then
              begin
                  DataAbertura := XML.RecordSetOfXML.FieldValuesByName['DATAH_ABERTURA'];
                  wtsCallEx('BMSYNC.CAIXAS.LISTACAIXADIA', ['CONTA','DATA', 'GUID'], [Conta, DataAbertura, XML.RecordSetOfXML.FieldValuesByName['GUID']], rs);
                  Try
                    if not rs.Eof Then
                    Begin
                        if VarToStr(XML.RecordSetOfXML.FieldValuesByName['GUID']) = '' then
                           raise Exception.Create('GUID da Conta no arquivo XML est� nulo.');

                        if VarToStr(rs.FieldValuesByName['GUID']) <> VarToStr(XML.RecordSetOfXML.FieldValuesByName['GUID']) then
                        begin
                           rsCaixas := TwtsRecordset.CreateFromStream(TMemoryStream.Create);
                           Try
                             rsCaixas.Transaction := 'BMSYNC.CAIXAS.REGISTRO_DIARIO';
                             rsCaixas.New;
                             rsCaixas.FieldValuesByName['REGISTRO_DIARIO'] := XML.RecordSetOfXML.FieldValuesByName['REGISTRO_DIARIO'];
                             rsCaixas.FieldValuesByName['GUID']            := VarToStr(XML.RecordSetOfXML.FieldValuesByName['GUID']);
                             rsCaixas.Add;

                             wtsCall('BMSYNC.CAIXAS.ATUALIZAGUIDCAIXAS',['CAIXAS'],[rsCaixas.Data],v);
                           Finally
                             FreeAndNil(rsCaixas);
                           End;
                        end;

                        d1 := VarToDouble(rs.FieldValuesByName['DATAH_FECHAMENTO']);
                        d2 := VarToDouble(XML.RecordSetOfXML.FieldValuesByName['DATAH_FECHAMENTO']);

                        If (VarToStr(rs.FieldValuesByName['VALOR_ABERTURA']) <> VarToStr(XML.RecordSetOfXML.FieldValuesByName['VALOR_ABERTURA'])) or
                           ( d1 <> d2 )  Then
                        Begin
                            wtsCall('BMSync.CAIXAS.Atualiza',
                               ['REGISTRO_DIARIO','DATAH_FECHAMENTO','VALOR_ABERTURA','VALOR_FECHAMENTO'],
                               [rs.FieldValuesByName['REGISTRO_DIARIO'],
                                XML.RecordSetOfXML.FieldValuesByName['DATAH_FECHAMENTO'],
                                XML.RecordSetOfXML.FieldValuesByName['VALOR_ABERTURA'],
                                XML.RecordSetOfXML.FieldValuesByName['VALOR_FECHAMENTO'] ], v);
                        end;
                    end else
                    begin
                        DataFechamento := Null;
                        If VarToStr(XML.RecordSetOfXML.FieldValuesByName['DATAH_FECHAMENTO']) <> '' Then
                           DataFechamento := XML.RecordSetOfXML.FieldValuesByName['DATAH_FECHAMENTO'];

                        wtsCall('BMSync.CAIXAS.IncluiDiario',
                               ['FILIAL','CONTA','DATAH_ABERTURA','DATAH_FECHAMENTO',
                                'VALOR_ABERTURA','VALOR_CAIXA','VALOR_FECHAMENTO','GUID'],
                                [Filial,
                                 Conta,
                                 DataAbertura,
                                 DataFechamento,
                                 XML.RecordSetOfXML.FieldValuesByName['VALOR_ABERTURA'],
                                 XML.RecordSetOfXML.FieldValuesByName['VALOR_CAIXA'],
                                 XML.RecordSetOfXML.FieldValuesByName['VALOR_FECHAMENTO'],
                                 XML.RecordSetOfXML.FieldValuesByName['GUID']], v);
                    end;
                  Finally
                    FreeAndNil(rs);
                  End;
              end;

              Xml.RecordSetOfXML.Next;
          end;
      end;
  end;

  procedure ConsultaSeJaExiste(var rsClientBusca:TwtsClientRecordset ; var AXML:TArquivo);
  Var
    rsBusca : TwtsRecordset;
    NameFieldBusca : String;
    ValueFieldBusca: Variant;
    Scanner : TScanner;
    y : integer;
  begin
      If Assigned(rsClientBusca) Then
         FreeAndNil(rsClientBusca);

      rsBusca := TwtsRecordset.CreateFromStreamEx( TMemoryStream.Create , rdInput);
      Try
        rsBusca.Transaction := AXML.fMethodConsulta ;
        Scanner             := TScanner.Create;
        Scanner.AdditionalChars := '_';
        Try
           Scanner.AnalyzeStr(AXML.fCampoDeConsulta);

           For y:=0 To Pred(Scanner.Count) do
             If Scanner.Token[y].Token in [ttIdentifier] Then
             Begin
                  // Extrai do .rdo o Campo a utilizar como Busca
                  NameFieldBusca := Scanner.TextI(y);

                  // Extrai do XML Valor a buscar
                  ValueFieldBusca := getCampo(AXml.RecordSetOfXML, AXml,  NameFieldBusca);
                  rsBusca.FieldValuesByName[NameFieldBusca] := ValueFieldBusca;
             End;
        Finally
           Scanner.Free;
        End;

        rsBusca.Add;
        rsClientBusca               := TwtsClientRecordset.Create;
        rsClientBusca.ShowErrors    := True;
        rsClientBusca.Transaction   := XML.fMethodConsulta;
        rsClientBusca.InRecordBlobs := True;
        rsClientBusca.Refresh(rsBusca);
      Finally
        FreeAndNil(rsBusca);
      End;
  end;

  procedure prcExcept(E:Exception);
  begin
      FLog.AddLog(LogMinimun, Erro, 'Erro importando', pathErr, ExtractFileName(ZipName), e.message);
      SendMessage( Application.Handle , WM_CheckErros, 0, 0);

      ForceDirectories(pathErr);
      DeleteFile(PathErr + ExtractFileName(ZipName));
      MoveFile( PChar(ZipName), PChar(PathErr + ExtractFileName(ZipName)));

      ClearDirectory(pathTemp);
      RemoveDir(pathTemp);
  end;
begin
    ImportINI  := TIniFile.Create(sAppPath + 'BMSyncImp.rdo');
    Try
      While ArquivosZip.Count > 0 Do
      Begin
        Try
          Lock.Lock;
          Try
             If ArquivosZip.Count>0 Then
             Begin
                 ZipName := ArquivosZip[0];
                 ArquivosZip.Delete(0);
             End Else
             Begin
                 Lock.UnLock;
                 Exit;
             End;
          Finally
             Lock.UnLock;
          End;

          Try
             pathTemp := ChangeFileExt(ZipName,'') + '\';
             pathOk   := ExtractFilePath(ZipName) + _pastaProcessados;
             pathErr  := ExtractFilePath(ZipName) + _pastaErros;
             ForceDirectories(PathTemp);
             ForceDirectories(PathOk);
             ForceDirectories(PathErr);

             ListaXMLs := ZipDescompact(pathTemp, ZipName);
             OrdenarPorPrioridade(ListaXMLs);

             Converter := TWtsXmlConvert.Create;
             Try
               For i:=0 To Pred(ListaXMLs.Count) Do
               Begin
                 Try
                   Try
                     // Variavel XML apenas aponta para o ponteiro do TArquivo, para deixar o c�digo mais limpo
                     XML                := TArquivo(ListaXMLs.Objects[i]);

                     if not ImportINI.SectionExists(XML.fSectionImport) then
                        raise Exception.Create('Erro em BMSyncImp.rdo. Se��o n�o encontrada: "'+ XML.fSectionImport +'"');

                     if (IsNull(XML.fMethodInclusao)) or
                        ((NotNull(XML.fMethodAlteracao)) and (IsNull(XML.fMethodConsulta))) then
                        raise Exception.Create('Erro em BMSyncImp.rdo. Se��o "'+ XML.fSectionImport +'" Configura��o incorreta.');

                     XML.RecordSetOfXml := Converter.XmlToRecordSet(XML.FullFileName);

                     // Verifica se existem dados no XML
                     ok := (XML.RecordSetOfXml.RecordCount >= 1);

                     If not Ok Then
                     Begin
                         // Loopa todos os campos do XML, verificando se h� dados
                         For x:=0 To Pred(XML.RecordSetOfXml.FieldCount) do
                         Begin
                             If VarToStr(XML.RecordSetOfXml.FieldValues[x]) <> '' Then
                             Begin
                                 ok := True;
                                 Break;
                             End;
                         End;
                     End;

                     if ok then
                     begin
                         While Not XML.RecordSetOfXml.Eof Do
                         Begin
                             If XML.fSectionImport = 'CAIXAS' Then
                                ProcessaCaixas(XML)
                             Else
                             Begin
                                 If (NotNull(XML.fMethodConsulta)) Then
                                 Begin
                                     ConsultaSeJaExiste(rsClientConsulta, XML);
                                     Try
                                       if rsClientConsulta.RecordCount > 0 Then
                                       Begin
                                           // (Existe) Altera��o
                                           rsMethodAlteracao             := TwtsRecordset.CreateFromStream( TMemoryStream.Create );
                                           rsMethodAlteracao.Transaction := XML.fMethodAlteracao;
                                           rsMethodAlteracao.New;

                                           For x:= Low(XML.fCamposDeAlteracao) To High(XML.fCamposDeAlteracao) Do
                                           Begin
                                               // Campos para Altera��o
                                               iPos   := Pos('.', XML.fCamposDeAlteracao[x]);
                                               sPart1 := Copy(XML.fCamposDeAlteracao[x],     1, iPos-1);
                                               sPart2 := Copy(XML.fCamposDeAlteracao[x],iPos+1, MaxInt);

                                               CampoRecordSet := sPart2;
                                               RefRecordSet   := sPart1;

                                               if (iPos > 0) and
                                                  (rsMethodAlteracao.IndexOfField(sPart1) > -1) then
                                               begin
                                                  iPos   := Pos('.', sPart2);
                                                  if iPos > 0 then
                                                  begin
                                                      sPart2 := Copy(sPart2, 1, iPos-1);
                                                      sPart3 := Copy(sPart2, iPos+1, MaxInt);
                                                      CampoRecordSet := sPart3;
                                                      RefRecordSet   := sPart2;
                                                  end;

                                                  rsChild := rsMethodAlteracao.CreateFieldRecordset(sPart1);
                                                  try
                                                    If rsChild.IndexOfField(CampoRecordSet) > -1 Then
                                                    begin
                                                       rsChild.New;
                                                       rsChild.FieldValuesByName[CampoRecordSet] := rsClientConsulta.FieldValuesByName[sPart2];
                                                       rsChild.Add;
                                                       rsMethodAlteracao.FieldValuesByName[RefRecordSet] := rsChild.Data;
                                                    end;
                                                  finally
                                                    FreeAndNil(rsChild);
                                                  end;
                                               end else
                                               If rsMethodAlteracao.IndexOfField(XML.fCamposDeAlteracao[x]) > -1 Then
                                                  rsMethodAlteracao.FieldValuesByName[XML.fCamposDeAlteracao[x]] := rsClientConsulta.FieldValuesByName[XML.fCamposDeAlteracao[x]];
                                           End;
                                           rsMethodAlteracao.Add;

                                           fTypeOfCurrentExp := TypAlteracao;
                                           Processar(TypAlteracao, XML, rsMethodAlteracao);
                                       end Else
                                       Begin
                                           // (Ainda n�o existe) Inclus�o
                                           If NotNull(XML.fMethodInclusao) Then
                                           Begin
                                               rsMethodInclusao             := TwtsRecordset.CreateFromStream( TMemoryStream.Create );
                                               rsMethodInclusao.Transaction := XML.fMethodInclusao;

                                               fTypeOfCurrentExp := TypInsercao;
                                               Processar(TypInsercao, XML, rsMethodInclusao);
                                           End;
                                       end;
                                     Finally
                                       If Assigned(rsClientConsulta) Then
                                          FreeAndNil(rsClientConsulta);
                                     End;
                                 end else
                                 Begin
                                     // N�o h� MetodoConsulta ent�o assume uma Inclus�o
                                     If NotNull(XML.fMethodInclusao) Then
                                     Begin
                                         rsMethodInclusao             := TwtsRecordset.CreateFromStream( TMemoryStream.Create );
                                         rsMethodInclusao.Transaction := XML.fMethodInclusao;

                                         fTypeOfCurrentExp := TypInsercao;
                                         Processar(TypInsercao, XML, rsMethodInclusao);
                                     End;
                                 end;
                             End;

                             XML.RecordSetOfXml.Next;
                         end;
                     end;
                     //Break;
                   Finally
                     If Assigned(rsMethodInclusao) Then
                        FreeAndNil(rsMethodInclusao);

                     If Assigned(rsMethodAlteracao) Then
                        FreeAndNil(rsMethodAlteracao);
                   End;
                 except
                   on E : Exception do
                   begin
                       prcExcept(E);
                   end;
                 end;
               end;

               ForceDirectories(PathOk);
               DeleteFile(PathOk + ExtractFileName(ZipName));
               MoveFile( PChar(ZipName), PChar(PathOk + ExtractFileName(ZipName)));

               ClearDirectory(pathTemp);

               RemoveDir(pathTemp);
             Finally
               FreeAndNil(Converter);
             End;
          Except
             On E : Exception Do
             Begin
                 prcExcept(E);
             End;
          End;
        Finally
          if Assigned(ListaXMLs) Then
          Begin
             while ListaXMLs.Count > 0 Do
             begin
                ListaXMLs.Objects[0].Free;
                ListaXMLs.Delete(0);
             end;
             ListaXMLs.Free;
          End;
        End;
      end;
    Finally
      If Assigned(ImportINI) Then
           ImportINI.Free;

        Self.Free;
    end
end;

procedure TProcessFile.PopularMetodoImportacao(Xml : TArquivo ; rsMethodImportacao: TWtsRecordset);
Var
   x : integer;
   s : String;
   sFieldName : String;
   iFieldSize : Integer;
   varAux     : Variant;
begin
    // Nessa procedure, ocorrer� um Looping em todos os campos do M�todo de Importa��o(rsMethodImportacao),
    //e para cada campo, busca um correspondente no XML(RecordSetOfXML)

    // Inicializa valores Default do m�todo
    SetToDefault(rsMethodImportacao);

    For x:=0 to rsMethodImportacao.FieldCount -1 Do
    Begin
        sFieldName := rsMethodImportacao.FieldDefs[x].Name;
        iFieldSize := rsMethodImportacao.FieldDefs[x].Size;
        
        try
//          If Not NotNull( rsMethodImportacao.FieldValues[x] ) Then
          Begin
              if (rsMethodImportacao.FieldDefs[x].Format = '+') And (VarToStr(rsMethodImportacao.FieldValuesByName[sFieldName]) <> '') then
              begin
                // Quando j� preencheu pelo "CampoAltera��o" n�o tentar preencher novamente
              end else
              begin
                Case rsMethodImportacao.FieldDefs[x].Format Of
                  'R' : varAux := getCampoRecordSet( rsMethodImportacao, XML, sFieldName);
                  'I' : Continue;
                  'A' : If (iFieldSize = 0) or
                               (VarToStr(getCampo(Xml.RecordSetOfXML, Xml, sFieldName)) = '') Then
                                varAux := getCampo(Xml.RecordSetOfXML, Xml, sFieldName)
                            Else
                                varAux := Copy(getCampo(Xml.RecordSetOfXML, Xml, sFieldName), 1, iFieldSize);
                Else
                        varAux := getCampo(Xml.RecordSetOfXML, Xml, sFieldName);
                End;
              end;

              if IsNull(varAux) and NotNull(rsMethodImportacao.FieldValuesByName[sFieldName]) then
                 Continue {N�o sobrepor no recordset Destino valor Nulo caso haja valor por Deulfat}
              else
                 rsMethodImportacao.FieldValuesByName[sFieldName] := varAux;
          End;
        except
          on E:Exception do
          begin                        // * * *  EXCEPT * * *  //
              if (iFieldSize > 0) then
              begin
                  try
                     S := VarToStr(getCampo(Xml.RecordSetOfXML, Xml , rsMethodImportacao.FieldDefs[x].Name))
                  except
                     S := '(erro lendo valor do campo)';
                  end
              end
              else
                 S := '(blob)';

              E.Message := 'Erro importando campo de '+rsMethodImportacao.Transaction + ':'#13#10+
                           'Nome='  + rsMethodImportacao.FieldDefs[x].Name +#13#10+
                           'Valor=' + s +#13#10+
                           '**** '  + E.Message+ ' ****' + #13#10;
              
              raise;
          end;
        end;
    End;
end;

procedure TProcessFile.Processar(Tipo : TypeImportacao ; Xml: TArquivo ; var rsMethodImportacao: TWtsRecordset);
var
  RSet : TWtsClientRecordset;
  iTentativa : Integer;
  iCountDeadLocks:Integer;
begin
    iCountDeadLocks := 0;

    If (Not Assigned(rsMethodImportacao)) or (rsMethodImportacao.Transaction = '') Then
       raise Exception.Create('Erro na procedure Processar. rsMethodImportacao n�o foi parametrizado.');

    if Tipo = typInsercao Then
       rsMethodImportacao.New;

    PopularMetodoImportacao( Xml , rsMethodImportacao );

    if Tipo = typInsercao Then
       rsMethodImportacao.Add
    Else
       rsMethodImportacao.Update;
    // A partir daqui o rsMethodImportacao est� preenchido com os dados j� tratados do XML

    If XML.fSectionImport = 'SAIDAS' Then
       AplicarTratamentos_Saidas(Tipo, rsMethodImportacao)
    Else
    If XML.fSectionImport = 'ENTRADAS' Then
       AplicarTratamentos_Entradas(Tipo, rsMethodImportacao);

    RSet := TwtsClientRecordset.Create;
    Try
      RSet.ShowErrors    := True;
      RSet.Transaction   := rsMethodImportacao.Transaction;
      RSet.InRecordBlobs := True;
      iTentativa := 0;
      repeat
          Try
            Inc(iTentativa);
            RSet.Refresh(rsMethodImportacao); // Dispara M�todo da Importacao
            //FLog.AddLog(LogMinimun, Sucesso, 'Registro importado', VarToStr(rsMethodImportacao.FieldValuesByName['GUID']));
            Break;
          except
            on e:Exception do
            begin
                If (Pos('DEADLOCK', UpperCase(e.Message)) > 0) or
                   ((Pos('DEAD', UpperCase(e.Message)) > 0) and (Pos('LOCK', UpperCase(e.Message)) > 0)) Then
                Begin
                   Dec(iTentativa);
                   Inc(iCountDeadLocks);
                End;

                If (iTentativa > 2) or (iCountDeadLocks > 20) Then
                   Raise Exception.Create(e.message);
                Sleep(50);
            end;
          End;
      Until False;
    Finally
      FreeAndNil(RSet);
      rsMethodImportacao.Clear;
    End;
end;

function TProcessFile.getCampo(RecordSetOfXML:TWtsRecordSet ; XML:TArquivo ; NomeCampo: String): Variant;
var
  r, rsPai, rsFieldRSet:TwtsRecordSet;
  x:Integer;
begin
   OutputDebugString(PChar(NomeCampo));
    // getCampo retorna o valor de um campo (param: NomeCampo) do arquivo XML (RecordSetOfXML) recebendo os devidos tratamentos pertinentes
    // TO-DO: Adicionar tratamentos conforme necessidade
    Try
      Try
        // Caso exista REDIRECIONAMENTO de nomes, aqui a vari�vel NomeCampo sofrer� altera��o no valor
        XML.RedirecionarNome(NomeCampo, True);

        // Caso o campo seja ForeignKey, concatena com prefixo FK_
        if XML.ListForeignKeys.Find(NomeCampo, x) And (RecordSetOfXml.IndexOfField('FK_' + NomeCampo) > -1) Then
          NomeCampo := 'FK_' + NomeCampo;

        rsPai := XML.RecordSetOfXML;

        If ((NomeCampo='COD_FILIAL') or  (NomeCampo='FK_FILIAL')) and
           (VarToStr(RecordSetOfXml.FieldValuesByName[NomeCampo]) <> '') Then
        Begin
           wtsCallEx('MILLENIUM.FILIAIS.PROCURA',['COD_FILIAL','ORDEM'],[RecordSetOfXml.FieldValuesByName[NomeCampo], 0],r);
           If not r.Eof Then
           Begin
              Result := r.FieldValuesByName['FILIAL'];
              FreeAndNil(r);
              Exit;
           End;
        end Else
        If ((NomeCampo='COD_FORNECEDOR') or  (NomeCampo='FK_FORNECEDOR')) and
           (VarToStr(RecordSetOfXml.FieldValuesByName[NomeCampo]) <> '') Then
        Begin
           wtsCallEx('MILLENIUM.FORNECEDORES.PROCURA',['COD_FORNECEDOR','ORDEM'],[RecordSetOfXml.FieldValuesByName[NomeCampo], 0],r);
           If not r.Eof Then
           Begin
              Result := r.FieldValuesByName['FORNECEDOR'];
              FreeAndNil(r);
              Exit;
           End;
        end Else
        If (NomeCampo='FK_CONDICOES_PGTO') and
           (VarToStr(RecordSetOfXml.FieldValuesByName[NomeCampo]) <> '') Then
        Begin
           wtsCallEx('MILLENIUM.CONDICOES_PGTO.LISTATODOS',['CODIGO'],[RecordSetOfXml.FieldValuesByName[NomeCampo]],r);
           If not r.Eof Then
           Begin
              Result := r.FieldValuesByName['CONDICOES_PGTO'];
              FreeAndNil(r);
              Exit;
           End;
        end Else
//        If (NomeCampo='FK_TABELA') and
//           (VarToStr(RecordSetOfXml.FieldValuesByName[NomeCampo]) <> '') Then
//        Begin
//           wtsCallEx('MILLENIUM.TABELAS_PRECO.CONSULTA_CONVERSAO',['COD_TPRECO'],[RecordSetOfXml.FieldValuesByName[NomeCampo]],r);
//           If not r.Eof Then
//           Begin
//              Result := r.FieldValuesByName['TABELA'];
//              FreeAndNil(r);
//              Exit;
//           End;
//        end Else
        If (NomeCampo='EVENTO') and (VarToStr(RecordSetOfXml.FieldValuesByName[NomeCampo]) <> '') Then
        Begin
{           If (rsPai.IndexOfField('CFG_EVENTO') > -1) And (VarToStr(rsPai.FieldValuesByName['CFG_EVENTO']) <> '') Then
           Begin
               rsFieldRSet := rsPai.CreateFieldRecordset('CFG_EVENTO');
               try
                 If not rsFieldRSet.Eof then
                 Begin
                     wtsCallEx('MILLENIUM.EVENTOS.CONSULTA',['EVENTO'],[RecordSetOfXml.FieldValuesByName[NomeCampo]],r);
                     If not r.Eof Then
                     Begin
                         For x:=0 To Pred(r.FieldCount) do
                         Begin
                             If (r.FieldDefs[x].Format<>'R') And (VarToStr(r.FieldValues[x]) <> VarToStr(rsFieldRSet.FieldValues[x])) Then
                             Begin
                                 raise Exception.Create('Detectado diferen�a nas "CONFIGURA��ES DO EVENTO" no ato da exporta��o para as "CONFIGURA��ES ATUAIS" ('+ r.FieldDefs[x].Name +')');
                             End;
                         End;
                     end else
                         raise Exception.Create('Evento (Cod. Interno: '+ RecordSetOfXml.FieldValuesByName[NomeCampo] +')n�o existe.');
                 end;
               finally
                 rsFieldRSet.Free;
                 FreeAndNil(r);
               End;
           end;}
        end else
        If (NomeCampo='TAMANHO') and (VarToStr(RecordSetOfXml.FieldValuesByName[NomeCampo]) = '') Then
        Begin
           Result := 'U';
           Exit;
        end Else
        If ((NomeCampo='NOME') or (NomeCampo='RAZAO')) and (VarToStr(RecordSetOfXml.FieldValuesByName[NomeCampo])='') Then
        Begin
           Result := '.';
           Exit;
        End;

        // Se Campo Existe e n�o caiu em nenhum tratamento espec�fico, ent�o retorna da mesma forma que ele veio do arquivo 
        If RecordSetOfXml.IndexOfField(NomeCampo) >= 0 Then
           Result := RecordSetOfXml.FieldValuesByName[NomeCampo]
        Else
           Result := Null;
      Except
        //Result := Null;
        raise;
      End;
    Finally
      If Assigned(r) And (r <> nil) Then
         FreeAndNil(r);
    End;
end;

function TProcessFile.getCampoRecordSet(RecordSetPai: TwtsRecordset; XML:TArquivo ;NomeCampo: String): String;
Var
  rsFilhoOfXML: TWtsRecordSet;
  rsFilho     : TWtsRecordSet;
  ok          : Boolean;
  x           : Integer;
  Value       : Variant;
begin
    // getCampoRecordSet Navega por todo um campo(param: NomeCampo) do tipo RecordSet, tratando Campo a Campo e retornando seu valor tratado
    Result       := '';
    If (XML.RecordSetOfXML.IndexOfField(NomeCampo) = -1)  Then
       Exit;

    // TEMPOR�RIO: Melhorar essa valida��o. A valida��o certa n�o � se � Record, mas o XML.RecordSetOfXML
    // deve ser atualizado corretamente quando � um subrecordset acima do 3o n�vel
    if (XML.RecordSetOfXML.FieldDefs[XML.RecordSetOfXML.IndexOfField(NomeCampo)].Format <> 'R' )then
       Exit;

    rsFilho      := RecordSetPai.CreateFieldRecordset(NomeCampo);
    rsFilhoOfXML := XML.RecordSetOfXML.CreateFieldRecordset(NomeCampo);
    Try
      SetToDefault(rsFilho);
      While not rsFilhoOfXML.Eof Do
      Begin
          Ok := True;

          If Ok Then
          Begin
              if not((rsFilhoOfXML.RecNo = 0) and not rsFilho.Eof )then
                 rsFilho.New;
                 
              For x:=0 to rsFilho.FieldCount -1 Do
              Begin
                  Case rsFilho.FieldDefs[x].Format Of
                    'R' : Begin
                              rsFilho.FieldValuesByName[rsFilho.FieldDefs[x].Name] := getCampoRecordSet(rsFilho, XML, rsFilho.FieldDefs[x].Name );
                              Continue;
                          End;
                    'I' : Continue;
                    '+' : Begin // Ignorar pois os contadores ser�o colocados pelo Metodo de Inclus�o.
//                              if not ((UpperCase(XML.fSectionImport) = 'CLIENTES') and (fTypeOfCurrentExp = TypAlteracao)) then
                                 Continue; // Exceto nesse caso
                          end;
                  end;

                  Value := getCampo(rsFilhoOfXML, XML, rsFilho.FieldDefs[x].Name );
                  rsFilho.FieldValuesByName[rsFilho.FieldDefs[x].Name] := Value;
              End;

              if (rsFilhoOfXML.RecNo = 0) and not rsFilho.Eof then
                 rsFilho.Update
              else
                 rsFilho.Add;
          End;

          rsFilhoOfXML.Next;
      End;
      Result := rsFilho.Data;
    Finally
      FreeAndNil(rsFilho);
      FreeAndNil(rsFilhoOfXML);
    End;
end;

function TProcessFile.CarregarRedirecionamentos(TextoList: String):ArrOfRedirecionamento;
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
          raise Exception.Create('Parenteses n�o encontrado em CarregarRedirecionamentos');
       Item := Copy(Item,2, Length(Item)-2 ); // Remove parenteses no inicio e no fim.

       IndexSub := Pos(SubDelimitador, Item);
       If IndexSub = 0 Then
          raise Exception.Create('SubDelimitador n�o encontrado em CarregarRedirecionamentos');

       SetLength(Result, i+1);
       Result[i].De   := Copy(Item, 1, IndexSub-1);
       Result[i].Para := Copy(Item, IndexSub+1, MaxInt);
       Inc(i);
    Until Pos(Delimitador, Texto) = 0;
end;

destructor TArquivo.Destroy;
begin
    FreeAndNil(RecordSetOfXML);
    FreeAndNil(ListForeignKeys);
    inherited;
end;

function TArquivo.RedirecionarNome(var NomeCampo: String; AlterarSeEncontrar:Boolean=False ): Boolean;
var
  x:Integer;
begin
    Result := False;

    For x:=0 To High(Redirecionamentos) Do
    Begin
        If UpperCase(Redirecionamentos[x].De) = UpperCase(NomeCampo) Then
        Begin
            NomeCampo := Redirecionamentos[x].Para;
            Result := True;
        end;
    end;
end;

procedure AplicarTratamentos_Entradas(Typ: TypeImportacao; var rsMethodImportacao: TWtsRecordset);
begin

end;

procedure AplicarTratamentos_Saidas(Typ: TypeImportacao; var rsMethodImportacao: TWtsRecordset);
begin
    rsMethodImportacao.FieldValuesByName['GERA_EXCEPTION'] := 'F';
    rsMethodImportacao.Update;

    Case Typ Of
      typInsercao:
      Begin

      end;
      typAlteracao:
      Begin
      
      end;
    End;
end;

function TProcessFile.CarregarForeignKeys(TextoList: String): TStringList;
Var
  Scanner : TScanner;
  y       : Integer;
begin
    Result        := TStringList.Create;
    Result.Sorted := True;

    Scanner       := TScanner.Create;
    Scanner.AdditionalChars := '_';
    Try
       Scanner.AnalyzeStr(TextoList);
       For y:=0 To Pred(Scanner.Count) do
         If Scanner.Token[y].Token in [ttIdentifier] Then
         Begin
             Result.Add(UpperCase(Scanner.TextI(y)));
         End;
    Finally
       Scanner.Free;
    End;
end;

initialization
  ArquivosZip := TStringList.Create;
  Lock        := TezResourceLock.Create;

finalization
  FreeAndNil(ArquivosZip);
  FreeAndNil(Lock);

end.

unit WtsXmlConvert;

interface

Uses WtsClient, WtsStream, XpBase, XpParser, XpDOM, UFunc, Classes, wtsintf,
     SysUtils, {UExp,} uuEnc, IniFiles, Declarations;

Type
   TWtsRecordSetXmlInform = Record
     RecordSet:TwtsRecordset;     
     Part,
     PartMax:Integer;
     AppVersion,
     SectionImport,
     KeyValue:String;
     DateExp:TDateTime;
   End;

   TWtsXmlConvert = Class
   Private
    FOutPutDirectory: String;
    FAppVersion:string;
    FSectionImport:String;
    FPart, FPartMax:String;
    FKeyValue:String;
    FConfMethods:ArrayExportConfigs;
     Procedure GenElemAtributes( Elem:TXpElement; RecordSet:TwtsRecordset );
     Procedure ReadElemChilds( Elem:TXpElement;Var RecordSet:TWtsRecordSet );
     Procedure AddAtribute(Elem:TXpElement; AtributeName,AtributeValue:String );
    procedure SetOutPutDirectory(const Value: String);
   Public
//     Procedure RecordSetToXml(RecordSet: TwtsRecordset; XmlArq:String; SectionImport:String );
     Function RecordSetToXml(RecordSet: TwtsRecordset; XmlArq:String; SectionImport:String ; Prioridade:Integer=0; TypeStruct:Integer=0):TStringList;
     Function XmlToRecordSet( XmlArq:String ):TWtsRecordSet;
     Property OutPutDirectory:String read FOutPutDirectory write SetOutPutDirectory;
     property ConfMethods:ArrayExportConfigs read FConfMethods write FConfMethods;
   End;

implementation

uses windows;

{ TExpProd }

procedure TWtsXmlConvert.AddAtribute(Elem: TXpElement; AtributeName,
  AtributeValue: String);
begin
  If NotNull( AtributeName ) And NotNull( AtributeValue )  Then
    Elem.SetAttribute( AtributeName , AtributeValue );
end;

procedure TWtsXmlConvert.GenElemAtributes( Elem:TXpElement; RecordSet:TwtsRecordset );
Var RecordAux:TwtsRecordset;
    Blob,BEnc:TMemoryStream;
    ElemAux, ElemAux2:TXpElement;
    x, y:integer;
    BlobAux:String;
    AtributeName, S, sSectionImport:String;
    AtributeValue:Variant;
begin
  For x:=0 to RecordSet.FieldCount -1 Do
    Begin
         With RecordSet.FieldDefs[x] Do
         Try
              Case Format Of
                'A':Begin
                      // Por enquanto, exportar Blob igual String
                      If Size > 0 Then
                        Begin
                          AtributeName  := Name;
                          AtributeValue := RecordSet.FieldValuesByName[Name];
                        End
                      Else
                        Begin
                          Blob := TMemoryStream.Create;
                          Try
                            RecordSet.CreateBlobStream( Name , TStream(Blob) , bmRead );
                            If Assigned( Blob )  Then
                              Begin
                                If Blob.Size > 0 Then
                                Begin
                                    ElemAux := Elem.CreateChildElement( Name );
                                    SetLength(BlobAux,Blob.Size);
                                    Blob.Read(BlobAux[1],Blob.Size);
                                    ElemAux.CreateChildText(  BlobAux );
                                End;
                              End;
                          Finally
                            Blob.Free;
                          End;
                        End;
                    End;
                'I':Begin
                         Blob := nil;
                         RecordSet.CreateBlobStream( Name , TStream(Blob) , bmRead );
                         If Assigned( Blob )  Then
                         Begin
                              BEnc := TMemoryStream.Create;
                              Try
                                 Blob.Position := 0;
                                 ElemAux := Elem.CreateChildElement( Name );
                                 _UUEncode(Blob, BEnc, uuBase64, nil);
                                 BEnc.Position := 0;
                                 SetLength(BlobAux,BEnc.Size);
                                 BEnc.Read(BlobAux[1],BEnc.Size);
                                 ElemAux.CreateChildText( BlobAux );
                              Finally
                                 Blob.Free;
                                 Benc.Free;
                              End;
                         End;
                    End;
                'R':Begin
//                      if flVisible in RecordSet.FieldDefs[x].Flags then
//                      Begin
                           RecordAux := RecordSet.CreateFieldRecordset( Name );
                           if not RecordAux.EOF Then
                           Begin
                               If UpperCase(Copy(Name,1,7)) = 'EXPORT_' Then
                               Begin
                                   S          := UpperCase(StringReplace(Name,'_','.', [rfReplaceAll]));
                                   sSectionImport := '';
                                   For y:=0 to High(FConfMethods) Do
                                   begin
                                       If UpperCase(ConfMethods[y].MethodExport) = S then
                                           sSectionImport := ConfMethods[y].MethodExport;
                                   end;

                                   ElemAux2 := Elem.CreateChildElement(S);
                                   AddAtribute( ElemAux2 , 'APPVERSION', FAppVersion );
                                   AddAtribute( ElemAux2 , 'VERSION'   , 'ATUALIZAR VERSAO"' );
                                   AddAtribute( ElemAux2 , 'SECTIONIMPORT', sSectionImport );
                                   AddAtribute( ElemAux2 , 'PART'      , FPart );
                                   AddAtribute( ElemAux2 , 'PARTMAX'   , FPartMax );
                                   AddAtribute( ElemAux2 , 'KEYVALUE'  , FKeyValue);
                                   AddAtribute( ElemAux2 , 'DATE'      , FormatDateTime( 'DD/MM/YYYY', Now ));
                               end;
                           End;

                           While not RecordAux.Eof do
                           Begin
                               If UpperCase(Copy(Name ,1,7)) = 'EXPORT_' Then
                                  ElemAux := ElemAux2.CreateChildElement('ROW')
                               else
                                  ElemAux := Elem.CreateChildElement( Name );

                               GenElemAtributes( ElemAux , RecordAux );
                               RecordAux.Next;
                           End;
                           RecordAux.Free;
//                      End;
                    End;
                'B':Begin
                      AtributeName  := Name;
                      AtributeValue := BooltoStr( CheckBool( RecordSet.FieldValuesByName[Name] ) );
                    End;
                '+','D','N','M','H':Begin
                                  AtributeName  := Name;
                                  AtributeValue := RecordSet.FieldValuesByName[Name];
                                End;
              End;
         Except
           AtributeName  := Name;
           AtributeValue := unassigned;
           // Do notting in case of abnormal field exception
         End;
         AddAtribute( Elem , AtributeName, VarToStr( AtributeValue ) );
    End;
end;

Procedure TWtsXmlConvert.ReadElemChilds(Elem: TXpElement; var RecordSet: TWtsRecordSet);
Var x,y:Integer;
    Valor:Variant;
    RecordAux:TwtsRecordset;
    Blob,BEnc:TMemoryStream;
    BlobAux:String;
begin
  RecordSet.New;
  For x:=0 To RecordSet.FieldCount -1 Do
    Begin
      With RecordSet.FieldDefs[x] Do
        Case Format Of
          'A':Begin
                If Size > 0 Then
                  Begin
                    Valor := Trim(Elem.GetAttribute( Name ));
                    If Notnull( Valor ) Then
                      RecordSet.FieldValuesByName[ Name ] := Valor;
                  End
                Else
                  Begin
                    For y := 0 to Elem.ChildNodes.Length -1 Do
                      If Elem.ChildNodes.Item( y ).NodeName = Name Then
                        Begin
                          Blob := TMemoryStream.Create;
                          Try
                            BlobAux := Elem.ChildNodes.Item( y ).ChildNodes.Item( 0 ).NodeValue;
                            Blob.Write( BlobAux[1] , Length( BlobAux ) );
                            RecordSet.FieldValuesByName[name] := IUnknown( TStreamAdapter.Create( Blob ));
                            Blob.Free;
                            Break;
                          Except
                            Blob.Free;
                            Break;
                          End;
                        End;
                  End;
              End;
          'I':begin
                   For y := 0 to Elem.ChildNodes.Length -1 Do
                       If Elem.ChildNodes.Item( y ).NodeName = Name Then
                       Begin
                            Blob := TMemoryStream.Create;
                            BEnc := TMemoryStream.Create;
                            Try
                               BlobAux := Elem.ChildNodes.Item( y ).ChildNodes.Item( 0 ).NodeValue;
                               BEnc.Write( BlobAux[1] , Length( BlobAux ) );
                               BEnc.Position := 0;
                               _UUDecode(BEnc,Blob,uuBase64,nil);
                               Blob.Position := 0;
                               RecordSet.FieldValuesByName[name] := IUnknown( TStreamAdapter.Create( Blob ));
                               Break;
                            Finally
                               Blob.Free;
                               BEnc.Free;
                            End;
                       End;
              end;
          'R':Begin
                For y := 0 to Elem.ChildNodes.Length -1 Do
                  If Elem.ChildNodes.Item( y ).NodeName = Name Then
                    Begin
                      If Not Assigned( RecordAux ) Then
                        RecordAux := RecordSet.CreateFieldRecordset( Name );
                      ReadElemChilds( Elem.ChildNodes.Item( y ) As TXpElement , RecordAux );
                    End;
                If Assigned( RecordAux ) Then
                  Begin
                    RecordSet.FieldValuesByName[ Name ] := RecordAux.Data;
                    RecordAux.Free;
                    RecordAux := nil;
                  End;
              End;
          'B':Begin
                Valor := Elem.GetAttribute( Name );
                If Notnull( Valor ) Then
                  RecordSet.FieldValuesByName[ Name ] := StrtoBool( Valor )
                Else
                  RecordSet.FieldValuesByName[ Name ] := False;
              End;
          '+','D','N','M','H':Begin
                            Valor := Elem.GetAttribute( Name );
                            If Notnull( Valor ) Then
                              RecordSet.FieldValuesByName[ Name ] := Valor;
                          End;
        End;
    End;
  RecordSet.Add;
End;

Function TWtsXmlConvert.RecordSetToXml(RecordSet: TwtsRecordset; XmlArq:String; SectionImport:String ; Prioridade:Integer=0; TypeStruct:Integer=0):TStringList;
Var aBuffer,NodeName,KeyValue,Part,PartMax, Quebra:String;
    Elem:TXpElement;
    Node:TXpNode;
    DomXml:TXpObjModel;

    function Part_Max : String;
    Var
       p, r : integer;
    Begin
         If ( RecordSet.IndexOfField('QUEBRA')>=0 ) and not RecordSet.EOF Then
         Begin
              p := 1;
              r := 0;
              Quebra := VarToStr(RecordSet.FieldValuesByName['QUEBRA']);
              While not RecordSet.Eof do
              Begin
                   if ( Quebra <> VarToStr(RecordSet.FieldValuesByName['QUEBRA']) ) or ( r > 500 ) then
                   Begin
                        Inc(p);
                        r := 0;
                        Quebra := VarToStr(RecordSet.FieldValuesByName['QUEBRA']);
                   End Else
                      Inc(r);
                   RecordSet.Next;
              End;
              Result := IntToStr(p);
              RecordSet.First;
         End
         Else
             Result := IntToStr( ( RecordSet.RecordCount div 500 ) + 1 );
    End;

    procedure GeraCab;
//    Var
//       RecordAux : TwtsRecordSet;
//       Elem2:TXpElement;
    Begin
{         if RecordSet.IndexOfField( Cabecalho ) >=0 then
         Begin
              Elem2 := DomXml.Document.CreateElement(  'ROW'  );
              Try
                AddAtribute( Elem2 , 'ID' , Cabecalho  );
                RecordAux := Recordset.CreateFieldRecordset( Cabecalho );
                While not RecordAux.Eof do
                Begin
                     ElemAux := Elem2.CreateChildElement( Cabecalho );
                     GenElemAtributes( ElemAux , RecordAux );
                     RecordAux.Next;
                End;
                Node.AppendChild( Elem2 );
              Finally
                Elem2.Release;
              End;
              RecordAux.Free;
         End;
}         
    End;

begin
  If Not Assigned( RecordSet ) Then
    Raise Exception.Create( 'RecordSet Nulo' );

  Result := TStringList.Create;
  Randomize;
  KeyValue := IntToStr( Random( MaxInt ) );
  //PartMax := IntToStr( ( RecordSet.RecordCount div 500 ) + 1 );
  PartMax := Part_Max;
  
  If StrToInt( PartMax ) < 10 Then
    PartMax := '0' + PartMax;

  Part    := '01';
  NodeName := RecordSet.Transaction;
  RecordSet.First;
  
  if RecordSet.IndexOfField( 'QUEBRA' ) >= 0 then
     Quebra := RecordSet.FieldValuesByName['QUEBRA'];

  FSectionImport := SectionImport;
  FPart          := Part;
  FPartMax       := PartMax;
  FKeyValue      := KeyValue + '-' + Part;

  While Not RecordSet.Eof Do
    Begin
      aBuffer := '<' + NodeName + ' SECTIONIMPORT="' + SectionImport + '" PART="' + Part + '" PARTMAX="' + PartMax + '" KEYVALUE="' + FKeyValue + '" PRIORIDADE="' + IntToStr(Prioridade)+ '" TYPESTRUCT="' + IntToStr(TypeStruct)  + '" DATE="'+ FormatDateTime( 'DD/MM/YYYY', Now ) + '" ></' + NodeName + '>';

      DomXml  := TXpObjModel.Create( Nil );
      try
          DomXml.LoadMemory( aBuffer[1] , Length(aBuffer) );
          Node := DomXml.Document.DocumentElement;

          While Not RecordSet.Eof Do
            Begin
              Elem := DomXml.Document.CreateElement(  'ROW'  );
              try
                  AddAtribute( Elem , 'ID' , IntToStr( RecordSet.RecNo + 1 )  );
                  GenElemAtributes( Elem , RecordSet );
                  RecordSet.Next;
                  Node.AppendChild( Elem );
              finally
              Elem.Release;
              end;

              If ( ( RecordSet.RecNo mod 500 ) = 0 ) or ( ( RecordSet.IndexOfField( 'QUEBRA') >= 0 ) and ( Quebra <> VarToStr(RecordSet.FieldValuesByName['QUEBRA']) ) ) Then
              Begin
                   if RecordSet.IndexOfField( 'QUEBRA') >= 0 then
                      Quebra := RecordSet.FieldValuesByName['QUEBRA'];
                   Break;
              End;
            End;

          While FileExists( OutPutDirectory + XmlArq + Part + '-' + PartMax + '.xml' ) do
                Part := IntToStr( StrToInt( Part ) + 1 );

//          if Assigned( ImpExp ) then
//             ImpExp.Log := 'Gerando arquivo ' + OutPutDirectory + XmlArq + Part + '-' + PartMax + '.xml';

          Result.Add(XmlArq + Part + '-' + PartMax + '.xml');

          DomXml.SaveToFile( OutPutDirectory + XmlArq + Part + '-' + PartMax + '.xml' );

//          if Assigned( ImpExp ) then
//             ImpExp.Log := 'Arquivo gerado ' + OutPutDirectory + XmlArq + Part + '-' + PartMax + '.xml';

      finally
      DomXml.Free;
      end;
      
      Part := IntToStr( StrToInt( Part ) + 1 );
      If StrToInt( Part ) < 10 Then Part := '0' + Part;
    End;
end;

procedure TWtsXmlConvert.SetOutPutDirectory(const Value: String);
begin
  FOutPutDirectory := Value;
end;

Function TWtsXmlConvert.XmlToRecordSet( XmlArq:String ): TWtsRecordSet;
Var FileStream:TFileStream;
    DomXml:TXpObjModel;
    x:integer;
    Elem:TXpElement;
    ST:Longword;
    rd:TwtsRecordsetDirection;
Begin
  FileStream := TFileStream.Create( XmlArq , fmOpenRead or fmShareDenyWrite );
  DomXml := TXpObjModel.Create( Nil );
  Try
    st := GetTickCount;
    DomXml.LoadStream( FileStream );
    OutputDebugString(PChar('xml load time:'+IntToStr(GetTickCount-st)));
  Finally
    FileStream.Free;
  End;

  if StrToIntDef(DomXml.Document.DocumentElement.GetAttribute('TYPESTRUCT'),0) = 0 then
     rd := rdOutput
  else
     rd := rdInput;

  Result     := TwtsRecordset.CreateFromStreamEx( TMemoryStream.Create , rd );
  Result.InRecordBlobs := True;
  Result.Transaction := DomXml.Document.DocumentElement.NodeName;
  For x := 0 to DomXml.Document.DocumentElement.ChildNodes.Length -1 Do
  Begin
       Elem := (DomXml.Document.DocumentElement.ChildNodes.Item( x ) as TXpElement);
       ReadElemChilds(  Elem  , Result );
  End;
  Result.First;
  DomXml.Free;
end;

end.

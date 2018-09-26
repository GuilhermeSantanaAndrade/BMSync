unit Visualizador;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Grids, PalGrid, LinkList, ExtCtrls, uExport, MyFuncs, StdCtrls,
  wtsMethodFrame;

type
  TfrmVisualizador = class(TForm)
    pnl1: TPanel;
    LinkList1: TLinkList;
    PalGrid1: TPalGrid;
    pnl2: TPanel;
    lbl1: TLabel;
    cboBuscar: TFlatComboBox;
    lbl3: TLabel;
    edtDado: TFlatEdit;
    btn1: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure LinkList1Links0Click(Sender: TObject);
    procedure btn1Click(Sender: TObject);
    procedure cboStatusChange(Sender: TObject);
  private
    fExportados:TExportados;
    Lst:TStringList;
    procedure AtualizarGrid;
  public
    class procedure Execute;
    destructor destroy; override;
  end;

implementation

{$R *.DFM}

procedure TfrmVisualizador.FormCreate(Sender: TObject);
begin
    fExportados := TExportados.Create(nil);
    cboBuscar.ItemIndex := 0;
end;

procedure TfrmVisualizador.FormDestroy(Sender: TObject);
begin
   If Assigned(fExportados) Then
      FreeAndNil(fExportados);
end;

class procedure TfrmVisualizador.Execute;
Var
  frmVisualizador:TfrmVisualizador;
begin
     frmVisualizador := TfrmVisualizador.Create(Application);
     Try
       With frmVisualizador Do
       Begin
           AtualizarGrid;

           ShowModal;
       End;
     Finally
       FreeAndNil(frmVisualizador);
     End;
end;

procedure TfrmVisualizador.LinkList1Links0Click(Sender: TObject);
begin
    Close;
end;

procedure TfrmVisualizador.btn1Click(Sender: TObject);
Var
  StrBusca:String;
  x:Integer;
  ok:Boolean;
begin
    if edtDado.Text <> '' Then
    Begin
        ok           := False;
        StrBusca     := UpperCase(edtDado.Text);
        edtDado.Text := '';
        For x:= 1 To palGrid1.RowCount Do
        Begin
            If UpperCase(PalGrid1.Cells[cboBuscar.ItemIndex, x]) = StrBusca Then
            Begin
                PalGrid1.Row := x;
                PalGrid1.Col := cboBuscar.ItemIndex;
                ok           := True;
                Break;
            End;   
        End;

        If not OK Then
           ShowMessage('não encontrado');
    end;
end;

procedure TfrmVisualizador.AtualizarGrid;
Var
  x, RowCount:Integer;
begin
    Lst := fExportados.GetArqAsList;

    For x:= 1 To Pred(PalGrid1.RowCount) Do
       PalGrid1.Rows[x].Clear;

    PalGrid1.ColCount  := 5;

    PalGrid1.Cells[0,0]   := 'ID';
    PalGrid1.Cells[1,0]   := 'Tabela';
    PalGrid1.Cells[2,0]   := 'IdTabela';
    PalGrid1.ColWidths[0] := 60;
    PalGrid1.ColWidths[1] := 100;
    PalGrid1.ColWidths[2] := 60;

    RowCount := 0;
    For x:=0 To Pred(Lst.Count) Do
    Begin
        PalGrid1.Cells[0,RowCount+1] := IntToStr(PRecordExp(Lst.Objects[x])^.ID);
        PalGrid1.Cells[1,RowCount+1] := PRecordExp(Lst.Objects[x])^.Tabela;
        PalGrid1.Cells[2,RowCount+1] := IntToStr(PRecordExp(Lst.Objects[x])^.IDTabela);
        Inc(RowCount);
    end;

    If RowCount = 0 Then
       PalGrid1.RowCount := 2
    else
       PalGrid1.RowCount := RowCount+PalGrid1.FixedRows;
end;

procedure TfrmVisualizador.cboStatusChange(Sender: TObject);
begin
    If Self.Active Then
    Begin
        AtualizarGrid;
    end;
end;

destructor TfrmVisualizador.destroy;
begin
  ClearList(Lst);
  inherited;
end;

end.

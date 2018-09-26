unit uSenha;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, wtsMethodFrame, MyFuncs;

type
  TfrmSenha = class(TForm)
    Digitado: TFlatEdit;
    lbl1: TLabel;
    procedure DigitadoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    { Private declarations }
  public
    class function Execute:Boolean;
  end;

Const
  SenhaCorreta = '1234';

implementation

{$R *.DFM}

Class function TfrmSenha.Execute: Boolean;
Var
  frm:TfrmSenha;
  Resultado:Integer;
begin
    frm := TfrmSenha.Create(Application);
    Try
      With frm Do
      Begin
          Resultado := ShowModal;
          Result := (Resultado = mrOK);
      End;
    Finally
      FreeAndNil(frm);
    End;
end;

procedure TfrmSenha.DigitadoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    Case Key Of
      VK_RETURN: ModalResult := IIF(Digitado.Text = SenhaCorreta, mrOK, mrCancel);
      VK_ESCAPE: ModalResult := mrCancel;
    End;
end;

end.

object frmVisualizador: TfrmVisualizador
  Left = 284
  Top = 181
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  Caption = 'Arquivo Binário'
  ClientHeight = 344
  ClientWidth = 433
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object pnl1: TPanel
    Left = 0
    Top = 88
    Width = 433
    Height = 256
    Align = alClient
    TabOrder = 0
    object LinkList1: TLinkList
      Left = 1
      Top = 230
      Width = 431
      Height = 25
      Links = <
        item
          Caption = 'OK'
          ShortCut = 0
          OnClick = LinkList1Links0Click
        end>
      LinksSpacing = 2
      ShortCutPos = scpLeft
      ShowtCutColor = clRed
      List = False
      AutoSize = False
      Margin = 2
      TabOrder = 0
      Align = alBottom
    end
    object PalGrid1: TPalGrid
      Left = 1
      Top = 1
      Width = 431
      Height = 229
      Align = alClient
      ColCount = 3
      DefaultDrawing = False
      FixedCols = 0
      RowCount = 2
      TabOrder = 1
      KeyCol = -1
    end
  end
  object pnl2: TPanel
    Left = 0
    Top = 0
    Width = 433
    Height = 88
    Align = alTop
    Color = 16250871
    TabOrder = 1
    object lbl1: TLabel
      Left = 8
      Top = 4
      Width = 51
      Height = 13
      Caption = 'Buscar por'
    end
    object lbl3: TLabel
      Left = 8
      Top = 44
      Width = 82
      Height = 13
      Caption = 'Dado para busca'
    end
    object cboBuscar: TFlatComboBox
      Left = 8
      Top = 18
      Width = 145
      Height = 21
      Style = csDropDownList
      ItemHeight = 13
      TabOrder = 0
      Items.Strings = (
        'ID'
        'TABELA'
        'IDTABELA'
        'INDEXOFARQ')
    end
    object edtDado: TFlatEdit
      Left = 8
      Top = 58
      Width = 145
      Height = 21
      TabOrder = 1
      
    end
    object btn1: TButton
      Left = 159
      Top = 57
      Width = 95
      Height = 22
      Caption = 'Procurar'
      TabOrder = 2
      OnClick = btn1Click
    end
  end
end

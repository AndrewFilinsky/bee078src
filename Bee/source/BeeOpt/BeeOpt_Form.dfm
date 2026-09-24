object MainForm: TMainForm
  Left = 316
  Top = 127
  VertScrollBar.Color = clScrollBar
  VertScrollBar.ParentColor = False
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'Bee optimizer'
  ClientHeight = 213
  ClientWidth = 292
  Color = clBtnFace
  Constraints.MaxHeight = 241
  Constraints.MaxWidth = 300
  Constraints.MinHeight = 240
  Constraints.MinWidth = 300
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  Icon.Data = {
    0000010001002020100000000000E80200001600000028000000200000004000
    0000010004000000000080020000000000000000000000000000000000000000
    0000000080000080000000808000800000008000800080800000C0C0C0008080
    80000000FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF000000
    3000000030000000000000000000000030000000300000000000000000000003
    33000003330000000000000000000333B3330333B333000000000000000033BB
    BBB333BBBBB333000000000000003BBBBBBB3BBBBBBB30000000000000003BBB
    BBBB3BBBBBBB30000000000000003BBBBBBB3BBBBBBB300000000000000033BB
    BBB333BBBBB333000000000000000333B333B333B333B3330000000000000003
    33BBBBB333BBBBB333000000000000003BBBBBBB3BBBBBBB3000000000000000
    3BBBBBBB3BBBBBBB30000000000000003BBBBBBB3BBBBBBB3000000000000003
    33BBBBB333BBBBB33300000000000333B333B333B333B33300000000000033BB
    BBB333BBBBB333000000000000003BBBBBBB3BBBBBBB30000000000000003BBB
    BBBB3BBBBBBB30000000000000003BBBBBBB3BBBBBBB300000000000000033BB
    BBB333BBBBB333000003330000030333B333B333B333B3330333B33303330003
    33BBBBB333BBBBB333BBBBB3330000003BBBBBBB3BBBBBBB3BBBBBBB30000000
    3BBBBBBB3BBBBBBB3BBBBBBB300000003BBBBBBB3BBBBBBB3BBBBBBB30000003
    33BBBBB333BBBBB333BBBBB3330003330333B3330333B3330333B33303333300
    0003330000033300000333000003300000003000000030000000300000003000
    000030000000300000003000000030000000300000003000000030000000F7F7
    FFFFF7F7FFFFE3E3FFFF8080FFFF00003FFF00007FFF00007FFF00007FFF0000
    3FFF80000FFFE00003FFF00007FFF00007FFF00007FFE00003FF80000FFF0000
    3FFF00007FFF00007FFF00007FFF00003E3E80000808E0000003F0000007F000
    0007F0000007E0000003880808083E3E3E3E7F7F7F7F7F7F7F7F7F7F7F7F}
  OldCreateOrder = False
  Position = poDefault
  Scaled = False
  ShowHint = True
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 16
  object PageControl: TPageControl
    Left = 0
    Top = 0
    Width = 292
    Height = 188
    ActivePage = TabSheet1
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'MS Sans Serif'
    Font.Style = []
    ParentFont = False
    TabOrder = 0
    object TabSheet1: TTabSheet
      Caption = 'Progress...'
      object Label_Extension: TLabel
        Left = 17
        Top = 5
        Width = 158
        Height = 16
        Caption = 'Optimization of Extensions:'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'MS Sans Serif'
        Font.Style = []
        ParentFont = False
      end
      object Label_ExtensionValue: TLabel
        Left = 199
        Top = 5
        Width = 9
        Height = 16
        Caption = '...'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'MS Sans Serif'
        Font.Style = []
        ParentFont = False
      end
      object Label_VariantsEstimated: TLabel
        Left = 34
        Top = 28
        Width = 141
        Height = 16
        Caption = 'Variants was estimated:'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'MS Sans Serif'
        Font.Style = []
        ParentFont = False
      end
      object Label_Level: TLabel
        Left = 56
        Top = 62
        Width = 119
        Height = 16
        Caption = 'Compression Level:'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'MS Sans Serif'
        Font.Style = []
        ParentFont = False
      end
      object Label_VariantsEstimatedValue: TLabel
        Left = 199
        Top = 28
        Width = 19
        Height = 16
        Caption = '?%'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'MS Sans Serif'
        Font.Style = []
        ParentFont = False
      end
      object Label_LevelValue: TLabel
        Left = 199
        Top = 62
        Width = 37
        Height = 16
        Caption = '? (?%)'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'MS Sans Serif'
        Font.Style = []
        ParentFont = False
      end
      object Label_PercentOfImprovements: TLabel
        Left = 24
        Top = 45
        Width = 151
        Height = 16
        Caption = 'Percent of Improvements:'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'MS Sans Serif'
        Font.Style = []
        ParentFont = False
      end
      object Label_PercentOfImprovementsValue: TLabel
        Left = 199
        Top = 45
        Width = 43
        Height = 16
        Caption = '0.000%'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'MS Sans Serif'
        Font.Style = []
        ParentFont = False
      end
      object Label_SampleSize: TLabel
        Left = 50
        Top = 116
        Width = 125
        Height = 16
        Caption = 'Size of Sample Files:'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'MS Sans Serif'
        Font.Style = []
        ParentFont = False
      end
      object Label_SampleSizeValue: TLabel
        Left = 199
        Top = 117
        Width = 7
        Height = 16
        Caption = '?'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'MS Sans Serif'
        Font.Style = []
        ParentFont = False
      end
      object Label_PackedSize: TLabel
        Left = 37
        Top = 135
        Width = 138
        Height = 16
        Caption = 'Current Size of Packed:'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'MS Sans Serif'
        Font.Style = []
        ParentFont = False
      end
      object Label_PackedSizeValue: TLabel
        Left = 199
        Top = 135
        Width = 7
        Height = 16
        Caption = '?'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'MS Sans Serif'
        Font.Style = []
        ParentFont = False
      end
      object Label_DictionaryLevel: TLabel
        Left = 76
        Top = 88
        Width = 99
        Height = 16
        Caption = 'Dictionary Level:'
      end
      object Label_DictionaryLevelValue: TLabel
        Left = 199
        Top = 88
        Width = 7
        Height = 16
        Caption = '?'
      end
    end
    object TabSheet3: TTabSheet
      Caption = 'About'
      ImageIndex = 2
      object Label_About: TLabel
        Left = 4
        Top = 4
        Width = 265
        Height = 144
        Caption = 
          'BeeOpt 0.7.7.f (C) 1999-2005 Andrew Filinsky'#13#10'Freeware version, ' +
          'Feb 2005'#13#10#13#10'This program calculates parameters for Bee 0.7.7 arc' +
          'hiver utility, then better compression ratio will be available b' +
          'y using them. '#13#10#13#10'Please, send constructed *.ini and *.dat files' +
          #13#10'to e-mail: filinsky@mail.ru'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'MS Sans Serif'
        Font.Style = []
        ParentFont = False
        WordWrap = True
      end
    end
  end
  object StatusBar: TStatusBar
    Left = 0
    Top = 188
    Width = 292
    Height = 25
    AutoHint = True
    Anchors = []
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'MS Sans Serif'
    Font.Style = []
    Panels = <
      item
        Alignment = taRightJustify
        Text = 'Initialization... '
        Width = 100
      end>
    SimplePanel = False
    UseSystemFont = False
  end
  object RxTrayIcon1: TRxTrayIcon
    Hint = '??% complete...'
    Icon.Data = {
      0000010001001010100000000000280100001600000028000000100000002000
      00000100040000000000C0000000000000000000000000000000000000000000
      0000000080000080000000808000800000008000800080800000C0C0C0008080
      80000000FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF000033
      00033BBB33000000333BBBBBBB33000003BBBBBBBBB3000003BBBBBBBBB30000
      03BBBBBBBBB3000003BBBBBBBBB30000333BBBBBBB330033BBB33BBB330033BB
      BBBBB33300003BBBBBBBBB3000003BBBBBBBBB3000003BBBBBBBBB3000003BBB
      BBBBBB30000033BBBBBBB33300000033BBB3300033000000333000000033CE03
      0000F0000000F8000000F8000000F8000000F8000000F0000000C0030000000F
      0000001F0000001F0000001F0000001F0000000F0000C0730000F1FC0000}
    Interval = 0
    OnClick = RxTrayIcon1Click
  end
end

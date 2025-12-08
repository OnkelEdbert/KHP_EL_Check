; G_Section.pbi
; --------------------------------------------
; IGES Global Section Parser (nach Spec)
; --------------------------------------------
; Verwendet die Liste G_Section.s(), die in IGS_Import.pbi
; befüllt wird (jede Zeile = 80 Zeichen, Spalte 73 = 'G').

Structure G_Sec
  ParamDelim.s      ; Zeichen für Parameter-Trennung (Standard: ",")
  RecordDelim.s     ; Zeichen für Record-Ende (Standard: ";")

  ProductIdSender.s ; Produkt-ID vom Sender (Feld 3)
  FileName.s        ; Dateiname (Feld 4)
  SystemId.s        ; System-ID (Feld 5)
  PreprocVersion.s  ; Preprocessor-Version (Feld 6)

  IntegerBits.i
  MaxPow10Single.i
  MaxDigitsSingle.i
  MaxPow10Double.i
  MaxDigitsDouble.i

  ProductIdReceiver.s

  Scale.d           ; Model Space Scale (Feld 13)
  UnitFlag.i        ; Einheiten-Flag (Feld 14)
  UnitName.s        ; Einheitenname (Hollerith, Feld 15)

  LineWeightGrad.i
  MaxLineWeight.d

  DateTime.s        ; Erstellungsdatum (Feld 18)
  Resolution.d      ; Min. intended resolution (Feld 19)
  MaxCoord.d        ; Approx. max coordinate value (Feld 20)

  Author.s          ; Autor (Feld 21)
  Company.s         ; Firma (Feld 22)

  IGESVersion.i     ; IGES-Version (Feld 23)
  DraftingStandard.i; Drafting Standard (Feld 24)
EndStructure

Global GlobalG.G_Sec

;---------------------------------
; Hilfsfunktion: Hollerith-String
; z.B. "4HSLOT" -> "SLOT"
;      "1H,"    -> ","
;---------------------------------
Procedure.s IGES_DecodeHollerith(field.s)
  Protected posH.i, lenStr.i, numStr.s, result.s

  field = Trim(field)
  If field = ""
    ProcedureReturn ""
  EndIf

  posH = FindString(field, "H", 1)
  If posH <= 1
    ; Kein gültiges Hollerith -> einfach zurückgeben
    ProcedureReturn field
  EndIf

  numStr = Trim(Left(field, posH - 1))
  lenStr = Val(numStr)
  If lenStr <= 0
    ProcedureReturn ""
  EndIf

  ; Sicherstellen, dass genug Zeichen da sind
  If Len(field) < posH + lenStr
    lenStr = Len(field) - posH
  EndIf

  result = Mid(field, posH + 1, lenStr)
  ProcedureReturn result
EndProcedure

;---------------------------------
; Param-Splitter (wie in P_Section)
;---------------------------------
; Achtung: delimiter / recordEnd können leer sein,
; dann nehmen wir die IGES-Defaults "," / ";"
Procedure.i IGES_SplitParams(paramString.s, delimiter.s, recordEnd.s, Array out.s(1))
  Protected s.s, part.s, pos.i, count.i
  Protected delim.s, rec.s

  delim = delimiter : If delim = "" : delim = "," : EndIf
  rec   = recordEnd : If rec   = "" : rec   = ";" : EndIf

  s = ReplaceString(paramString, rec, "") ; Record-Ende entfernen
  count = -1

  While s <> ""
    pos = FindString(s, delim, 1)
    If pos = 0
      part = s
      s = ""
    Else
      part = Left(s, pos - 1)
      s = Mid(s, pos + Len(delim))
    EndIf

    count + 1
    ReDim out(count)
    out(count) = Trim(part)
  Wend

  ProcedureReturn count + 1
EndProcedure

;---------------------------------
; G-Section zu einem String
;---------------------------------
Procedure.s IGES_GetGlobalRaw()
  Protected line.s, text72.s, raw.s

  raw = ""

  If ListSize(G_Section()) = 0
    ProcedureReturn ""
  EndIf

  ResetList(G_Section())
  While NextElement(G_Section())
    line = G_Section()
    If Len(line) < 80
      line + Space(80 - Len(line))
    EndIf
    text72 = Left(line, 72) ; Spalten 1-72
    raw + text72
  Wend

  ProcedureReturn raw
EndProcedure

;---------------------------------
; Global Section parsen
;---------------------------------
Procedure Parse_G_Section()
  Protected raw.s
  Protected paramCount.i, i.i
  Dim params.s(0)

  ; Defaultwerte setzen
  GlobalG\ParamDelim = ","
  GlobalG\RecordDelim = ";"
  GlobalG\Scale = 1.0
  GlobalG\Resolution = 0.0
  GlobalG\MaxCoord = 0.0

  raw = IGES_GetGlobalRaw()
  If raw = ""
    ProcedureReturn
  EndIf

  ; G-Section wird immer mit den Default-Delimitern geschrieben
  ; (laut Spec: falls 1/2 nicht explizit gesetzt, sind sie "," / ";").
  paramCount = IGES_SplitParams(raw, ",", ";", params())
  If paramCount <= 0
    ProcedureReturn
  EndIf

  ; Index = ParameterNr - 1 (Feld 1 => params(0), Feld 2 => params(1), ...)
  ; 1: Parameter Delimiter (Hollerith)
  If paramCount > 0 And params(0) <> ""
    GlobalG\ParamDelim = Left(IGES_DecodeHollerith(params(0)), 1)
  EndIf

  ; 2: Record Delimiter (Hollerith)
  If paramCount > 1 And params(1) <> ""
    GlobalG\RecordDelim = Left(IGES_DecodeHollerith(params(1)), 1)
  EndIf

  ; 3: Product ID from Sender
  If paramCount > 2
    GlobalG\ProductIdSender = IGES_DecodeHollerith(params(2))
  EndIf

  ; 4: File Name
  If paramCount > 3
    GlobalG\FileName = IGES_DecodeHollerith(params(3))
  EndIf

  ; 5: System Identification
  If paramCount > 4
    GlobalG\SystemId = IGES_DecodeHollerith(params(4))
  EndIf

  ; 6: Preprocessor Version
  If paramCount > 5
    GlobalG\PreprocVersion = IGES_DecodeHollerith(params(5))
  EndIf

  ; 7-11: Integer / Float Range Info
  If paramCount > 6
    GlobalG\IntegerBits = Val(params(6))
  EndIf
  If paramCount > 7
    GlobalG\MaxPow10Single = Val(params(7))
  EndIf
  If paramCount > 8
    GlobalG\MaxDigitsSingle = Val(params(8))
  EndIf
  If paramCount > 9
    GlobalG\MaxPow10Double = Val(params(9))
  EndIf
  If paramCount > 10
    GlobalG\MaxDigitsDouble = Val(params(10))
  EndIf

  ; 12: Product ID for Receiver
  If paramCount > 11
    GlobalG\ProductIdReceiver = IGES_DecodeHollerith(params(11))
  EndIf

  ; 13: Model Space Scale
  If paramCount > 12 And params(12) <> ""
    GlobalG\Scale = ValD(params(12))
  EndIf

  ; 14: Unit Flag
  If paramCount > 13
    GlobalG\UnitFlag = Val(params(13))
  EndIf

  ; 15: Unit Name (Hollerith)
  If paramCount > 14
    GlobalG\UnitName = IGES_DecodeHollerith(params(14))
  EndIf

  ; 16: Max Number of Line Weights
  If paramCount > 15
    GlobalG\LineWeightGrad = Val(params(15))
  EndIf

  ; 17: Max Line Width
  If paramCount > 16 And params(16) <> ""
    GlobalG\MaxLineWeight = ValD(params(16))
  EndIf

  ; 18: File Creation Date/Time
  If paramCount > 17
    GlobalG\DateTime = IGES_DecodeHollerith(params(17))
  EndIf

  ; 19: Min Resolution
  If paramCount > 18 And params(18) <> ""
    GlobalG\Resolution = ValD(params(18))
  EndIf

  ; 20: Approx. Max Coord
  If paramCount > 19 And params(19) <> ""
    GlobalG\MaxCoord = ValD(params(19))
  EndIf

  ; 21: Author Name
  If paramCount > 20
    GlobalG\Author = IGES_DecodeHollerith(params(20))
  EndIf

  ; 22: Company Name
  If paramCount > 21
    GlobalG\Company = IGES_DecodeHollerith(params(21))
  EndIf

  ; 23: IGES Version
  If paramCount > 22
    GlobalG\IGESVersion = Val(params(22))
  EndIf

  ; 24: Drafting Standard
  If paramCount > 23
    GlobalG\DraftingStandard = Val(params(23))
  EndIf
EndProcedure

Procedure Debug_G_Section()
  Debug "---- G-Section Debug ----"
  Debug "ParamDelim='" + GlobalG\ParamDelim + "'  RecordDelim='" + GlobalG\RecordDelim + "'"
  Debug "Scale=" + StrD(GlobalG\Scale) + "  UnitFlag=" + Str(GlobalG\UnitFlag) + "  UnitName='" + GlobalG\UnitName + "'"
  Debug "Resolution=" + StrD(GlobalG\Resolution) + "  MaxCoord=" + StrD(GlobalG\MaxCoord)
  Debug "Author='" + GlobalG\Author + "'  Company='" + GlobalG\Company + "'"
  Debug "FileName='" + GlobalG\FileName + "'"
  Debug "IGESVersion=" + Str(GlobalG\IGESVersion) + "  DraftingStandard=" + Str(GlobalG\DraftingStandard)
  Debug "---------------------------"
EndProcedure

; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 287
; FirstLine = 240
; Folding = -
; EnableXP
; DPIAware
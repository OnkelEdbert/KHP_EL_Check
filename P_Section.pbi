; P_Section.pbi
; --------------------------------------------
; IGES Parameter Data (P-Section) Grundparser
; --------------------------------------------
; Verwendet die Liste P_Section.s(), die in IGS_Import.pbi
; befuellt wird:
;   - jede P-Zeile = genau eine 80-Zeichen-Zeile
;   - Spalte 73 = 'P'
;   - Spalten 74-80 = Parameter-Sequenznummer
;
; Layout der P-Zeilen (ASCII-Form, Fixed Format):
;   Spalten  1-64 : Parameterdaten (EntityType + Parameter, durch Delimiter getrennt)
;   Spalte     65 : (unbenutzt / Blank)
;   Spalten 66-72 : DE-Pointer (Sequence Number der ersten D-Zeile dieser Entity)
;   Spalte     73 : 'P'
;   Spalten 74-80 : Parameter-Sequenznummer (PD-Sequence)

;--------------------------
; Hilfsstruktur P-Zeile
;--------------------------

Structure P_Line
  Seq.i      ; Parameter-Sequenznummer (Spalten 74-80)
  DEPtr.i    ; Directory-Entry-Pointer (Spalten 66-72, = SeqNo aus DirList())
  Text.s     ; Parameterdaten (Spalten 1-64, getrimmt)
EndStructure

Global NewMap PTable.P_Line()   ; Key = Str(Seq)

;--------------------------
; Lokale Hilfsfunktion:
; Integer-Feld lesen
;--------------------------

Procedure.i IGS_ParseIntField_P(line.s, startPos.i, fieldLen.i)
  Protected txt.s

  If Len(line) < startPos + fieldLen - 1
    line + Space(startPos + fieldLen - 1 - Len(line))
  EndIf

  txt = Trim(Mid(line, startPos, fieldLen))

  If txt = ""
    ProcedureReturn 0
  EndIf

  ProcedureReturn Val(txt)
EndProcedure

;------------------------------------
; P-Section in PTable() einlesen
;------------------------------------

Procedure Build_P_Table()
  Protected line.s, seq.i, deptr.i, text.s, key.s

  ClearMap(PTable())

  If ListSize(P_Section()) = 0
    ProcedureReturn
  EndIf

  ResetList(P_Section())

  While NextElement(P_Section())
    line = P_Section()

    ; Sicherheit: auf 80 Zeichen auffuellen
    If Len(line) < 80
      line + Space(80 - Len(line))
    EndIf

    ; Spalten 1-64 : Parameter-Text
    text  = RTrim(Left(line, 64))

    ; Spalten 66-72 : DE-Pointer
    deptr = IGS_ParseIntField_P(line, 66, 7)

    ; Spalten 74-80 : Parameter-Sequenznummer
    seq   = IGS_ParseIntField_P(line, 74, 7)

    key = Str(seq)

    If AddMapElement(PTable(), key)
      PTable()\Seq   = seq
      PTable()\DEPtr = deptr
      PTable()\Text  = text
    EndIf
  Wend
EndProcedure

;------------------------------------
; Basis-Debug fuer die P-Section
;------------------------------------

Procedure Debug_P_Section_Basic()
  Protected countP.i, n.i

  countP = ListSize(P_Section())

  Debug "---- P-Section Debug ----"
  Debug "P-Zeilen roh: " + Str(countP)
  Debug "PTable-Eintraege: " + Str(MapSize(PTable()))
  Debug " (erste 10 Eintraege) "

  n = 0
  ForEach PTable()
    Debug "PSeq=" + Str(PTable()\Seq) + "  DEPtr=" + Str(PTable()\DEPtr) +
          "  Text='" + PTable()\Text + "'"
    n + 1
    If n >= 10
      Break
    EndIf
  Next

  Debug "-------------------------"
EndProcedure

Procedure Debug_P_Section_Type142()
  Protected p.s

  Debug "---- P-Section: Type 142 ----"

  ForEach PTable()
    p = PTable()\Text

    ; Prüfe ob die Zeile mit "142," beginnt
    If Left(p, 4) = "142,"
      Debug "PSeq=" + Str(PTable()\Seq) + "  DEPtr=" + Str(PTable()\DEPtr) +
            "  Text='" + p + "'"
    EndIf
  Next

  Debug "--------------------------------"
EndProcedure


;---------------------------------------------------
; Test: erste Entity vom Typ 110 und Parameter parsen
;---------------------------------------------------
Procedure Debug_First_Type110_Params()
  Protected pSeq.i, lineCount.i, i.i, key.s, combined.s
  Protected paramCount.i, n.i
  Dim params.s(0)

  Debug "---- Test: erste Entity vom Typ 110 ----"

  ForEach DirList()
    If DirList()\Type = 110
      pSeq      = DirList()\PDPtr
      lineCount = DirList()\ParamLineCount

      Debug "Directory-Entry: SeqNo=" + Str(DirList()\SeqNo) +
            "  PDPtr=" + Str(pSeq) +
            "  ParamLines=" + Str(lineCount)

      combined = ""

      For i = 0 To lineCount - 1
        key = Str(pSeq + i)
        If FindMapElement(PTable(), key)
          Debug "  PSeq " + key + " (DEPtr=" + Str(PTable()\DEPtr) + "): " + PTable()\Text
          combined + Trim(PTable()\Text)
        Else
          Debug "  PSeq " + key + " NICHT gefunden!"
        EndIf
      Next

      Debug "Kombinierte Parameterzeile: " + combined

      ; Jetzt Parameter wirklich splitten
      paramCount = IGES_SplitParams(combined, GlobalG\ParamDelim, GlobalG\RecordDelim, params())
      Debug "Param-Anzahl: " + Str(paramCount)

      For n = 0 To paramCount - 1
        Debug "  Param[" + Str(n) + "] = '" + params(n) + "'"
      Next

      ; Erwartung fuer Typ 110: 7 Parameter
      If paramCount = 7 And params(0) = "110"
        Debug "OK: Type 110 hat 7 Parameter (EntityType + 2 Punkte)."
      Else
        Debug "ACHTUNG: Unerwartete Param-Anzahl fuer Type 110!"
      EndIf

      Debug "-------------------------------------"
      Break
    EndIf
  Next
EndProcedure

; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 111
; FirstLine = 91
; Folding = -
; EnableXP
; DPIAware
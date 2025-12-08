; D_Section.pbi
; --------------------------------------------
; IGES Directory (D-Section) Parser nach Spec
; --------------------------------------------
; Verwendet die Liste D_Section.s(), die in IGS_Import.pbi
; befuellt wird:
;   - jede D-Zeile = genau eine 80-Zeichen-Zeile
;   - Spalte 73 = 'D'
;   - Spalten 74-80 = Sequenznummer

; Struktur nach IGES-Spec:
; D1 (erste Zeile, Felder jeweils 8 Zeichen):
;   1: Entity Type Number
;   2: Parameter Data Pointer (erste P-Zeile)
;   3: Structure / Group
;   4: Line Font Pattern
;   5: Level
;   6: View
;   7: Transformation Matrix Pointer
;   8: Label Display Pointer
;
; D2 (zweite Zeile):
;   1: Entity Status Number
;   2: Line Weight Number
;   3: Color Number
;   4: Parameter Line Count
;   5: Form Number
;   6: Reserved
;   7: Reserved
;   8: Entity Label (String, max. 8 Zeichen)
;   9: Entity Subscript Number (in Praxis in 65-72)

Structure D_Sec
  SeqNo.i            ; Sequenznummer der 1. D-Zeile (Spalte 74-80)
  Type.i             ; Entity Type Number
  PDPtr.i            ; Parameter Data Pointer (erste P-Zeile)
  StructureID.i      ; Structure / Group
  LineFont.i         ; Line font pattern
  Level.i            ; Level (Layer)
  View.i             ; View pointer
  TransMatrixPtr.i   ; Transformationsmatrix-Pointer
  LabelDispPtr.i     ; Label-Display-Pointer

  Status.i           ; Entity Status Number
  LineWeight.i       ; Line Weight Number
  Color.i            ; Color Number
  ParamLineCount.i   ; Anzahl P-Zeilen fuer diese Entity
  Form.i             ; Form Number
  Reserved1.i        ; Reserved
  Reserved2.i        ; Reserved
  EntLabel.s         ; Entity Label (max. 8 Zeichen)
  EntSubscript.i     ; Subscript (falls benutzt)
EndStructure

Global NewList DirList.D_Sec()

; -------------------------------------------------
; Hilfsfunktionen zum Lesen von Feldern (8 Zeichen)
; -------------------------------------------------

Procedure.i IGS_ParseIntField(line.s, startPos.i, fieldLen.i)
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

Procedure.s IGS_ParseStrField(line.s, startPos.i, fieldLen.i)
  Protected txt.s

  If Len(line) < startPos + fieldLen - 1
    line + Space(startPos + fieldLen - 1 - Len(line))
  EndIf

  txt = Trim(Mid(line, startPos, fieldLen))
  ProcedureReturn txt
EndProcedure

; --------------------------------------------
; Hauptparser fuer die D-Section
; --------------------------------------------

Procedure Parse_D_Section()
  Protected line1.s, line2.s
  Protected seq1.i, seq2.i
  Protected entry.D_Sec

  ClearList(DirList())

  ; Falls keine D-Zeilen vorhanden sind, gibt es auch kein Directory
  If ListSize(D_Section()) = 0
    ProcedureReturn
  EndIf

  ResetList(D_Section())

  ; Jede Entity belegt immer 2 D-Zeilen (D1 + D2)
  While NextElement(D_Section())
    line1 = D_Section()

    ; Zweite D-Zeile holen – wenn die fehlt, ist die Datei kaputt
    If NextElement(D_Section()) = 0
      ; unvollstaendiger D-Eintrag -> wir brechen sauber ab
      Break
    EndIf

    line2 = D_Section()

    ; Sicherheit: auf 80 Zeichen auffuellen
    If Len(line1) < 80
      line1 + Space(80 - Len(line1))
    EndIf
    If Len(line2) < 80
      line2 + Space(80 - Len(line2))
    EndIf

    ; Sequenznummern (Spalte 74-80)
    seq1 = IGS_ParseIntField(line1, 74, 7)
    seq2 = IGS_ParseIntField(line2, 74, 7)
    ; Optional: man koennte hier pruefen, ob seq2 = seq1 + 1 ist

    ; Directory-Eintrag fuellen
    entry\SeqNo          = seq1

    ; D1 – erste Zeile
    entry\Type           = IGS_ParseIntField(line1,  1, 8)  ; Feld 1
    entry\PDPtr          = IGS_ParseIntField(line1,  9, 8)  ; Feld 2
    entry\StructureID    = IGS_ParseIntField(line1, 17, 8)  ; Feld 3
    entry\LineFont       = IGS_ParseIntField(line1, 25, 8)  ; Feld 4
    entry\Level          = IGS_ParseIntField(line1, 33, 8)  ; Feld 5
    entry\View           = IGS_ParseIntField(line1, 41, 8)  ; Feld 6
    entry\TransMatrixPtr = IGS_ParseIntField(line1, 49, 8)  ; Feld 7
    entry\LabelDispPtr   = IGS_ParseIntField(line1, 57, 8)  ; Feld 8

    ; D2 – zweite Zeile
    entry\Status         = IGS_ParseIntField(line2,  1, 8)  ; Feld 1
    entry\LineWeight     = IGS_ParseIntField(line2,  9, 8)  ; Feld 2
    entry\Color          = IGS_ParseIntField(line2, 17, 8)  ; Feld 3
    entry\ParamLineCount = IGS_ParseIntField(line2, 25, 8)  ; Feld 4
    entry\Form           = IGS_ParseIntField(line2, 33, 8)  ; Feld 5
    entry\Reserved1      = IGS_ParseIntField(line2, 41, 8)  ; Feld 6
    entry\Reserved2      = IGS_ParseIntField(line2, 49, 8)  ; Feld 7
    entry\EntLabel       = IGS_ParseStrField(line2, 57, 8)  ; Feld 8 (Label)
    entry\EntSubscript   = IGS_ParseIntField(line2, 65, 8)  ; Subscript (meist 0)

    ; In Liste uebernehmen
    AddElement(DirList())
    DirList() = entry
  Wend
EndProcedure

; IDE Options etc. kannst du unten bei Bedarf noch dranhaengen

; --- Debug Zeugs ----

Procedure Debug_D_Section()
  Protected countDLines.i, countDir.i

  countDLines = ListSize(D_Section())
  countDir    = ListSize(DirList())

  Debug "---- D-Section Debug ----"
  Debug "D-Zeilen roh: " + Str(countDLines)
  Debug "Dir-Eintraege: " + Str(countDir)
  If countDLines > 0
    Debug "Erwartet: Dir-Eintraege = D-Zeilen / 2 -> " + Str(countDLines / 2)
  EndIf

  ForEach DirList()
    Debug "SeqNo=" + Str(DirList()\SeqNo) + 
          "  Type=" + Str(DirList()\Type) + 
          "  PDPtr=" + Str(DirList()\PDPtr) + 
          "  Level=" + Str(DirList()\Level) + 
          "  Color=" + Str(DirList()\Color) + 
          "  ParamLines=" + Str(DirList()\ParamLineCount) + 
          "  Form=" + Str(DirList()\Form) + 
          "  Label='" + DirList()\EntLabel + "'" 
  Next

  Debug "--------------------------"
EndProcedure

; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 190
; FirstLine = 28
; Folding = w
; EnableXP
; DPIAware
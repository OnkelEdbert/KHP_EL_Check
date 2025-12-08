; IGES_Line110.pbi
; --------------------------------------------
; Parser für IGES-Entity Type 110 (Line)
; nutzt:
;   - DirList()          : Directory-Einträge (D-Section)
;   - PTable()           : Parameterdaten (P-Section)
;   - GlobalG.G_Sec      : G-Section (Scale, Delimiter)
;   - IGES_GetParamStringForDir(*dir.D_Sec)
;   - IGES_SplitParams()
; --------------------------------------------

;--- Strukturen ---

Structure IGES_Point
  x.d
  y.d
  z.d
EndStructure

Structure IGES_Line110
  StartPt.IGES_Point
  EndPt.IGES_Point
  Level.i      ; aus D-Section
  Color.i      ; aus D-Section
  SeqNo.i      ; Directory-SeqNo (zum Zurückverfolgen)
EndStructure

Global NewList Line110_List.IGES_Line110()

; Liefert den zusammengebauten Parameter-String für einen Directory-Eintrag
; (berücksichtigt PDPtr + ParamLineCount + PTable + GlobalG Delimiter)

Procedure.s IGES_GetParamStringForDir(*dir.D_Sec)
  Protected pSeq.i, lineCount.i, i.i
  Protected key.s, combined.s

  Protected result.s

  If *dir = 0
    ProcedureReturn ""
  EndIf

  pSeq      = *dir\PDPtr
  lineCount = *dir\ParamLineCount

  If lineCount <= 0 Or pSeq <= 0
    ProcedureReturn ""
  EndIf

  combined = ""

  For i = 0 To lineCount - 1
    key = Str(pSeq + i)
    If FindMapElement(PTable(), key)
      combined + Trim(PTable()\Text)
    Else
      Debug "WARN: IGES_GetParamStringForDir - PSeq " + key + " nicht gefunden (SeqNo=" + Str(*dir\SeqNo) + ")"
    EndIf
  Next

  ProcedureReturn combined
EndProcedure

;--- Parser für EINEN Directory-Eintrag vom Typ 110 ---

Procedure.i IGES_ParseLine110(*dir.D_Sec, *outLine.IGES_Line110)
  Protected combined.s
  Protected paramCount.i
  Protected scale.d
  Protected i.i
  
  Dim params.s(0)

  If *dir = 0 Or *outLine = 0
    ProcedureReturn #False
  EndIf
  
  If *dir\Type <> 110
    ProcedureReturn #False
  EndIf
  
  ; kombinierten Parameterstring aus P-Section holen
  combined = IGES_GetParamStringForDir(*dir)
  If combined = ""
    Debug "WARN: IGES_ParseLine110 - kein ParamString für SeqNo=" + Str(*dir\SeqNo)
    ProcedureReturn #False
  EndIf
  
  ; in einzelne Parameter zerlegen (mit G-Section-Delimiter)
  paramCount = IGES_SplitParams(combined, GlobalG\ParamDelim, GlobalG\RecordDelim, params())
  If paramCount < 7
    Debug "WARN: IGES_ParseLine110 - zu wenige Parameter (" + Str(paramCount) + ") für SeqNo=" + Str(*dir\SeqNo)
    ProcedureReturn #False
  EndIf
  
  ; Sicherheit: erster Wert muss 110 sein
  If Val(params(0)) <> 110
    Debug "WARN: IGES_ParseLine110 - Param[0] ist nicht 110 bei SeqNo=" + Str(*dir\SeqNo)
    ProcedureReturn #False
  EndIf
  
  ; Scale aus G-Section
  scale = GlobalG\Scale
  If scale = 0.0
    scale = 1.0
  EndIf
  
  ; Startpunkt
  *outLine\StartPt\x = ValD(params(1)) * scale
  *outLine\StartPt\y = ValD(params(2)) * scale
  *outLine\StartPt\z = ValD(params(3)) * scale
  
  ; Endpunkt
  *outLine\EndPt\x   = ValD(params(4)) * scale
  *outLine\EndPt\y   = ValD(params(5)) * scale
  *outLine\EndPt\z   = ValD(params(6)) * scale
  
  ; Meta-Infos aus D-Section
  *outLine\Level     = *dir\Level
  *outLine\Color     = *dir\Color
  *outLine\SeqNo     = *dir\SeqNo
  
  ProcedureReturn #True
EndProcedure


;--- Liste aller Type-110-Linien aus dem Directory aufbauen ---

Procedure X_Build_Line110_List()
  Protected tmpLine.IGES_Line110
  
  ClearList(Line110_List())
  
  ForEach DirList()
    If DirList()\Type = 110
      If IGES_ParseLine110(@DirList(), @tmpLine)
        AddElement(Line110_List())
        Line110_List() = tmpLine
      EndIf
    EndIf
  Next
EndProcedure

;--- Liste aller Type-110-Linien aus dem Directory aufbauen ---
Procedure Build_Line110_List()
  Protected tmpLine.IGES_Line110
  Protected statusStr.s
  Protected blank.i, subord.i, useFlag.i, hier.i
  
  ClearList(Line110_List())
  
  ForEach DirList()
    If DirList()\Type = 110
      
      If IGES_ParseLine110(@DirList(), @tmpLine)
        AddElement(Line110_List())
        Line110_List() = tmpLine
      EndIf
      
    EndIf
  Next
EndProcedure


;--- Debug-Ausgabe (optional) ---

Procedure Debug_Line110_List(MaxLines.i = 5)
  Protected count.i = 0
  
  Debug "---- Line110 Debug ----"
  Debug "Anzahl Linien (Type 110): " + Str(ListSize(Line110_List()))
  
  ForEach Line110_List()
    Debug "SeqNo=" + Str(Line110_List()\SeqNo) + 
          "  Level=" + Str(Line110_List()\Level) + 
          "  Color=" + Str(Line110_List()\Color)
    Debug "  Start: (" + StrD(Line110_List()\StartPt\x) + ", " + StrD(Line110_List()\StartPt\y) + ", " + StrD(Line110_List()\StartPt\z) + ")"
    Debug "  End:   (" + StrD(Line110_List()\EndPt\x)   + ", " + StrD(Line110_List()\EndPt\y)   + ", " + StrD(Line110_List()\EndPt\z)   + ")"
    
    count + 1
    If count >= MaxLines
      Break
    EndIf
  Next
  
  Debug "------------------------"
EndProcedure

; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 152
; FirstLine = 41
; Folding = 9
; EnableXP
; DPIAware
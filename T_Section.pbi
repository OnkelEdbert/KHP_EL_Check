; T_Section.pbi
; --------------

Procedure Debug_T_Section()
  Protected line.s, txt72.s

  Debug "---- T-Section (Terminate) ----"
  Debug "T-Zeilen roh: " + Str(ListSize(T_Section()))

  If ListSize(T_Section()) = 0
    Debug "(leer)"
    Debug "-------------------------------"
    ProcedureReturn
  EndIf

  ResetList(T_Section())
  While NextElement(T_Section())
    line = T_Section()
    If Len(line) < 80
      line + Space(80 - Len(line))
    EndIf
    txt72 = Left(line, 72)
    Debug txt72
  Wend

  Debug "-------------------------------"
EndProcedure

Procedure Debug_T_Section_CheckCounts()
  Debug "---- IGES Section-Zählcheck ----"
  Debug "S-Zeilen: " + Str(ListSize(S_Section()))
  Debug "G-Zeilen: " + Str(ListSize(G_Section()))
  Debug "D-Zeilen: " + Str(ListSize(D_Section()))
  Debug "P-Zeilen: " + Str(ListSize(P_Section()))
  Debug "T-Zeilen: " + Str(ListSize(T_Section()))
  Debug "--------------------------------"
EndProcedure

; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 3
; Folding = -
; EnableXP
; DPIAware
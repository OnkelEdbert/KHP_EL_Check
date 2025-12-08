; S_Section.pbi
; --------------

Procedure Debug_S_Section()
  Protected txt.s

  Debug "---- S-Section (Start) ----"
  Debug "S-Zeilen roh: " + Str(ListSize(S_Section()))

  If ListSize(S_Section()) = 0
    Debug "(leer)"
    Debug "---------------------------"
    ProcedureReturn
  EndIf

  ResetList(S_Section())
  While NextElement(S_Section())
    txt = S_Section()
    If Len(txt) > 72
      txt = Left(txt, 72)
    EndIf
    Debug txt
  Wend

  Debug "---------------------------"
EndProcedure

; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 3
; Folding = -
; EnableXP
; DPIAware
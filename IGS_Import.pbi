XIncludeFile "S_Section.pbi"
XIncludeFile "G_Section.pbi"
XIncludeFile "D_Section.pbi"
XIncludeFile "P_Section.pbi"
XIncludeFile "T_Section.pbi"

Global NewList S_Section.s()
Global NewList G_Section.s()
Global NewList D_Section.s()
Global NewList P_Section.s()
Global NewList T_Section.s()

Procedure LoadIGES_Lines(Filename.s)
  
  Protected IGSFile.i
  Protected line.s, n.i

  ; ---------- Datei einlesen & S/G/D/P/T trennen ----------
  IGSFile = ReadFile(#PB_Any, Filename)
  If IGSFile = 0
    ProcedureReturn #False
  EndIf

  While Eof(IGSFile) = 0
    line = ReadString(IGSFile, #PB_Ascii)
    Select  Mid(line, 73, 1) ; S/G/D/P/T
      Case "S"
        AddElement(S_Section())
        S_Section() = line
      Case "G"
        AddElement(G_Section())
        G_Section() = line
      Case "D"
        AddElement(D_Section())
        D_Section() = line
      Case "P"
        AddElement(P_Section())
        P_Section() = line
      Case "T"
        AddElement(T_Section())
        T_Section() = line
    EndSelect
  Wend
  CloseFile(IGSFile)
   
EndProcedure



; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 24
; Folding = -
; EnableXP
; DPIAware
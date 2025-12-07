Structure IGES_Line
  x1.f : y1.f : z1.f
  x2.f : y2.f : z2.f
EndStructure
Global NewList IGESLines.IGES_Line()

Structure IGS_Columns
  Section.s     ; "S","G","D","P","T"
  Dataline.s    ; Spalte 1-72
  Number.i      ; Sequenznummer (Spalte 74-80)
EndStructure
Global NewList IGSData.IGS_Columns()

Structure D_Sec
  EntityType.i  ; Feld 1
  ParamPtr.i    ; Feld 2 (Pointer in P-Sektion)
  Level.i       ; Feld 5
  SeqNo.i       ; Directory-Seq (unser Number)
EndStructure
Global NewList DirList.D_Sec()

Structure ParamBlock
  Coordinates.s ; alles nach dem EntityType (ohne führende "110,")
  EntityType.i
  ParamPtr.i    ; entspricht dem "xxP" rechter Rand (wir nehmen nur die Zahl)
EndStructure
Global NewList IGSCoords.ParamBlock()


Procedure LoadIGES_Lines(Filename.s)
  
  Protected IGSFile.i
  Protected line.s, n.i
  Protected Section.s
  
  Protected Coordinates.s = ""
  Protected curPtr.i = -1       ; aktueller "67P"-Pointer als Zahl
  Protected newPtr.i
  Protected posn.i
  Protected level.i
  
  Protected x1.f, y1.f, z1.f
  Protected x2.f, y2.f, z2.f
  
  ClearList(IGSData())
  ClearList(DirList())
  ClearList(IGSCoords())
  
  ; ---------- Datei einlesen & S/G/D/P/T trennen ----------
  IGSFile = ReadFile(#PB_Any, Filename)
  If IGSFile = 0
    ProcedureReturn #False
  EndIf

  While Eof(IGSFile) = 0
    line = ReadString(IGSFile, #PB_Ascii)
    
    AddElement(IGSData())
    IGSData()\Section  = Mid(line, 73, 1)       ; S/G/D/P/T
    IGSData()\Dataline = Left(line, 72)         ; Nutzdaten
    IGSData()\Number   = Val(Mid(line, 74, 8))  ; Sequenznummer
  Wend
  
  CloseFile(IGSFile)
  
  
  ; ---------- Directory-Einträge (D-Sektion) auswerten ----------
  ; Felder sind 8-stellig gepackt: 1:EntityType, 2:ParamPtr, 5:Level
  ForEach IGSData()
    If IGSData()\Section = "D"
      
      AddElement(DirList())
      DirList()\SeqNo      = IGSData()\Number
      DirList()\EntityType = Val(Left(IGSData()\Dataline, 8))
      DirList()\ParamPtr = Val(Trim(Mid(IGSData()\Dataline,  9, 8)))  ; Feld 2
      DirList()\Level    = Val(Trim(Mid(IGSData()\Dataline, 33, 8)))  ; Feld 5
    EndIf
  Next
  
  
  ; ---------- Parameterblöcke (P-Sektion) sammeln ----------
  ResetList(IGSData())
  ForEach IGSData()
    If IGSData()\Section = "P"
      
      ; rechts in Spalte 65-72 steht bei ZW3D sowas wie "  67P   "
      newPtr = Val(Mid(IGSData()\Dataline, 65, 8))  ; "67P" -> 67
      
      If curPtr = -1
        ; erster Block
        curPtr     = newPtr
        Coordinates = Trim(Left(IGSData()\Dataline, 64))
      ElseIf newPtr = curPtr
        ; Fortsetzung desselben Parameter-Blocks
        Coordinates + Trim(Left(IGSData()\Dataline, 64))
      Else
        ; ----- alter Block ist fertig, neuen anfangen -----
        If Coordinates <> ""
          AddElement(IGSCoords())
          
          Coordinates = RemoveString(Coordinates, " ")
          Coordinates = RemoveString(Coordinates, ";")
          
          posn = FindString(Coordinates, ",")
          IGSCoords()\EntityType  = Val(Left(Coordinates, posn - 1))
          IGSCoords()\Coordinates = Mid(Coordinates, posn + 1)
          IGSCoords()\ParamPtr    = curPtr
        EndIf
        
        ; neuen Block starten
        curPtr      = newPtr
        Coordinates = Trim(Left(IGSData()\Dataline, 64))
      EndIf
      
    EndIf
  Next
  
  ; letzten Block noch flushen
  If Coordinates <> ""
    AddElement(IGSCoords())
    
    Coordinates = RemoveString(Coordinates, " ")
    Coordinates = RemoveString(Coordinates, ";")
    
    posn = FindString(Coordinates, ",")
    IGSCoords()\EntityType  = Val(Left(Coordinates, posn - 1))
    IGSCoords()\Coordinates = Mid(Coordinates, posn + 1)
    IGSCoords()\ParamPtr    = curPtr
  EndIf
  
  
  ; ---------- IGESLines aus 110ern auf "guten" Levels bauen ----------
  ClearList(IGESLines())
  
  ForEach IGSCoords()
    If IGSCoords()\EntityType = 110
      
      ; passenden Directory-Eintrag suchen (über ParamPtr)
      level = 0
      
      ForEach DirList()
        If DirList()\ParamPtr = IGSCoords()\ParamPtr
          level = DirList()\Level
          Break
        EndIf
      Next
      
      ; HIER: Level-Filter einbauen, wenn du z.B. 2D-Zeug loswerden willst
      ; z.B. nur Level 0 oder 1:
      ; If level <> 0 : Continue : EndIf
      
      x1 = ValF(StringField(IGSCoords()\Coordinates, 1, ","))
      y1 = ValF(StringField(IGSCoords()\Coordinates, 2, ","))
      z1 = ValF(StringField(IGSCoords()\Coordinates, 3, ","))
      x2 = ValF(StringField(IGSCoords()\Coordinates, 4, ","))
      y2 = ValF(StringField(IGSCoords()\Coordinates, 5, ","))
      z2 = ValF(StringField(IGSCoords()\Coordinates, 6, ","))
      
      AddElement(IGESLines())
      IGESLines()\x1 = x1
      IGESLines()\y1 = y1
      IGESLines()\z1 = z1
      IGESLines()\x2 = x2
      IGESLines()\y2 = y2
      IGESLines()\z2 = z2
    EndIf
  Next
  
  ProcedureReturn #True
  
EndProcedure

; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 149
; FirstLine = 115
; Folding = -
; EnableXP
; DPIAware
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
  SeqNo.i          ; Sequenznummer der 1. D-Zeile (Number)
  Type.i           ; Entity-Typ (z.B. 110, 126, 128, 142, 144, 102, ...)
  PDPtr.i          ; Parameter-Data-Pointer (Startzeile in "P")
  StructureID.i    ; Feld 3 (Struktur-ID / Gruppeninfo)
  LineFont.i       ; Feld 4
  Level.i          ; Feld 5 (Layer / Level)
  View.i           ; Feld 6 (View-Pointer)
  TransMatrixPtr.i ; Feld 7 (Transformationsmatrix-Pointer)
  LabelDispPtr.i   ; Feld 8 (Label-Display-Pointer)
EndStructure
Global NewList DirList.D_Sec()

Structure ParamBlock
  Coordinates.s ; alles nach dem EntityType (ohne führende "110,")
  EntityType.i
  ParamPtr.i    ; entspricht dem "xxP" rechter Rand (wir nehmen nur die Zahl)
EndStructure
Global NewList IGSCoords.ParamBlock()

Structure IGES_Link
  FromType.i   ; z.B. 144, 142, 102
  FromPtr.i    ; ParamPtr der Quell-Entität (z.B. 635)
  ToType.i     ; z.B. 128, 102, 126
  ToPtr.i      ; ParamPtr der Ziel-Entität
EndStructure
Global NewList IGSLinks.IGES_Link()

Structure SurfaceEdgeRef
  PDPtr.i    ; Verweis auf Parameter-Data-Pointer (Feld 2 in D-Sektion)
EndStructure
Global NewList SurfaceEdge110.SurfaceEdgeRef()

Global NewMap SurfaceCurve.i()   ; Key = Str(ParamPtr), Value = 1
Global NewMap VisitMark.i()      ; für Rekursion (FromType:FromPtr schon besucht?)

Procedure.i IsSurfaceEdge110(PDPtr.i)
  ForEach SurfaceEdge110()
    If SurfaceEdge110()\PDPtr = PDPtr
      ProcedureReturn #True
    EndIf
  Next
  ProcedureReturn #False
EndProcedure

Procedure MarkSurfaceLinks(fromType.i, fromPtr.i)
  Protected key.s = Str(fromType) + ":" + Str(fromPtr)
  
  ; Schon besucht? -> Abbruch
  If FindMapElement(VisitMark(), key)
    ProcedureReturn
  EndIf
  VisitMark(key) = 1
  
  ForEach IGSLinks()
    If IGSLinks()\FromType = fromType And IGSLinks()\FromPtr = fromPtr
      
      ; Alles, was als "Kante" interessant ist, markieren
      Select IGSLinks()\ToType
        Case 102, 126, 110, 128, 142
          SurfaceCurve(Str(IGSLinks()\ToPtr)) = 1
      EndSelect
      
      ; Und weiter runter laufen
      MarkSurfaceLinks(IGSLinks()\ToType, IGSLinks()\ToPtr)
    EndIf
  Next
EndProcedure

Procedure BuildSurfaceCurveMap()

  ClearMap(SurfaceCurve())
  ClearMap(VisitMark())
  
  ; Von allen Flächen-Einträgen (144, evtl. 143) starten
  ForEach IGSCoords()
    Select IGSCoords()\EntityType
      Case 144, 143  ; Trimmed / Bounded Surface
        MarkSurfaceLinks(IGSCoords()\EntityType, IGSCoords()\ParamPtr)
    EndSelect
  Next
  
EndProcedure

Procedure.i FindDirTypeForPDPtr(pdPtr.i)
  ForEach DirList()
    ; Nur die "echten" D-Zeilen (Type > 0) verwenden
    If DirList()\PDPtr = pdPtr And DirList()\Type > 0
      ProcedureReturn DirList()\Type
    EndIf
  Next
  ProcedureReturn 0
EndProcedure

Procedure BuildIGES_Links()

  Protected coord.s
  Protected fields.i, i.i
  Protected val.i
  Protected t.i
  
  ClearList(IGSLinks())
  
  ; --- 1) 102 = Composite Curve: 102 -> (Kinder) ---
  ForEach IGSCoords()
    If IGSCoords()\EntityType = 102
      
      coord  = IGSCoords()\Coordinates
      fields = CountString(coord, ",") + 1
      
      ; Feld 1 = Anzahl der Segmente
      Protected segCount.i = Val(StringField(coord, 1, ","))
      If segCount > fields - 1
        segCount = fields - 1
      EndIf
      
      For i = 1 To segCount
        val = Val(StringField(coord, i + 1, ",")) ; Zeiger auf Kurve (meist 126)
        If val > 0
          t = FindDirTypeForPDPtr(val)
          If t > 0
            AddElement(IGSLinks())
            IGSLinks()\FromType = 102
            IGSLinks()\FromPtr  = IGSCoords()\ParamPtr
            IGSLinks()\ToType   = t
            IGSLinks()\ToPtr    = val
          EndIf
        EndIf
      Next i
      
    EndIf
  Next
  
  ; --- 2) 142 + 144: alles, was die so referenzieren ---
  ForEach IGSCoords()
    Select IGSCoords()\EntityType
      Case 142, 144
        coord  = IGSCoords()\Coordinates
        fields = CountString(coord, ",") + 1
        
        For i = 1 To fields
          val = Val(StringField(coord, i, ","))
          If val <= 0
            Continue
          EndIf
          
          t = FindDirTypeForPDPtr(val)
          If t > 0
            AddElement(IGSLinks())
            IGSLinks()\FromType = IGSCoords()\EntityType   ; 142 oder 144
            IGSLinks()\FromPtr  = IGSCoords()\ParamPtr
            IGSLinks()\ToType   = t
            IGSLinks()\ToPtr    = val
          EndIf
        Next i
    EndSelect
  Next
  
  ; --- Debug-Ausgabe zum Gucken, was ZW3D tut ---
;   ForEach IGSLinks()
;     Debug "Link: " + Str(IGSLinks()\FromType) + "(" + Str(IGSLinks()\FromPtr) + ") -> " + 
;           Str(IGSLinks()\ToType)  + "(" + Str(IGSLinks()\ToPtr)  + ")"
;   Next

EndProcedure

Procedure X_BuildSurfaceEdgeList()
  Protected surfSeq.i, curveSeqA.i, curveSeqB.i
  Protected curveType.i, curvePDPtr.i
  Protected nSegs.i, i.i, childSeq.i, childPDPtr.i
  
  ClearList(SurfaceEdge110())
  
  ; Über alle Parameterblöcke laufen
  ForEach IGSCoords()
    If IGSCoords()\EntityType = 142
      ; 142-Parameter: grob "0,SurfaceDE,CurveDE_A,CurveDE_B,irgendwas"
      ; Wir nehmen Feld 2 als Fläche, 3+4 als Kurvenzeiger.
      surfSeq   = Val(StringField(IGSCoords()\Coordinates, 2, ","))
      curveSeqA = Val(StringField(IGSCoords()\Coordinates, 3, ","))
      curveSeqB = Val(StringField(IGSCoords()\Coordinates, 4, ","))
      
      ; 1) check: referenzierte Fläche muss eine 128er Surface sein
      Protected isSurface128.i = #False
      
      ForEach DirList()
        If DirList()\SeqNo = surfSeq And DirList()\Type = 128
          isSurface128 = #True
          Break
        EndIf
      Next
      
      If isSurface128 = #False
        Continue
      EndIf
      
      ; 2) beide Kurvenzeiger (A & B) abarbeiten
      For i = 0 To 1
        If i = 0
          childSeq = curveSeqA
        Else
          childSeq = curveSeqB
        EndIf
        
        If childSeq = 0
          Continue
        EndIf
        
        curveType  = 0
        curvePDPtr = 0
        
        ; Directory-Eintrag zur Kurve holen
        ForEach DirList()
          If DirList()\SeqNo = childSeq
            curveType  = DirList()\Type
            curvePDPtr = DirList()\PDPtr
            Break
          EndIf
        Next
        
        Select curveType
          
          ; --- direkter 110er (Linie) ---
          Case 110
            If IsSurfaceEdge110(curvePDPtr) = #False
              AddElement(SurfaceEdge110())
              SurfaceEdge110()\PDPtr = curvePDPtr
            EndIf
          
          ; --- 102 = zusammengesetzte Kurve: enthält Zeiger auf 110er ---
          Case 102
            ForEach IGSCoords()
              If IGSCoords()\ParamPtr = curvePDPtr And IGSCoords()\EntityType = 102
                nSegs = Val(StringField(IGSCoords()\Coordinates, 1, ","))
                For i = 1 To nSegs
                  childSeq = Val(StringField(IGSCoords()\Coordinates, i + 1, ","))
                  
                  ; Sub-Entity im Directory suchen
                  ForEach DirList()
                    If DirList()\SeqNo = childSeq And DirList()\Type = 110
                      childPDPtr = DirList()\PDPtr
                      
                      If IsSurfaceEdge110(childPDPtr) = #False
                        AddElement(SurfaceEdge110())
                        SurfaceEdge110()\PDPtr = childPDPtr
                      EndIf
                      
                      Break
                    EndIf
                  Next
                  
                Next
                Break   ; passender 102-Block gefunden
              EndIf
            Next
          
          ; andere Typen (126 usw.) lassen wir hier erstmal weg
          
        EndSelect
        
      Next i
    EndIf
  Next
EndProcedure

Procedure BuildSurfaceEdgeList()
  Protected surfType.i, surfSeq.i, outerCC.i, innerCC.i, sense.i
  Protected ccSeq.i, ccType.i, ccPDPtr.i
  Protected nSegs.i, i.i, segSeq.i, segPDPtr.i, seg.i
  
  ClearList(SurfaceEdge110())
  
  ; Über alle Parameterblöcke laufen (auf der P-Sektion)
  ForEach IGSCoords()
    
    ; === 142: Curve On Parametric Surface ===
    If IGSCoords()\EntityType = 142
      
      ; ---------------------------------------------
      ; 142-Parameterstruktur nach IGES-Spec
      ; 1 = SurfaceType
      ; 2 = Surface Pointer (SeqNo der 128er Fläche)
      ; 3 = Outer Boundary (SeqNo 102/110)
      ; 4 = Inner Boundary (optional)
      ; 5 = Orientation / Sense
      ; ---------------------------------------------
      
      surfType = Val(StringField(IGSCoords()\Coordinates, 1, ","))
      surfSeq  = Val(StringField(IGSCoords()\Coordinates, 2, ",")) ; WICHTIG: Feld 2 !!!
      outerCC  = Val(StringField(IGSCoords()\Coordinates, 3, ","))
      innerCC  = Val(StringField(IGSCoords()\Coordinates, 4, ","))
      sense    = Val(StringField(IGSCoords()\Coordinates, 5, ","))
      
      ; ---------------------------------------------
      ; Prüfen: referenzierte Fläche muss eine 128 sein
      ; ---------------------------------------------
      Protected isSurface128.i = #False
      
      ForEach DirList()
        If DirList()\SeqNo = surfSeq And DirList()\Type = 128
          isSurface128 = #True
          Break
        EndIf
      Next
      
      ; Wenn keine echte Surface, dann ist das 2D-Kram → überspringen
      If isSurface128 = #False
        Continue
      EndIf
      
      ; ---------------------------------------------
      ; Outer + Inner Boundary abarbeiten
      ; ---------------------------------------------
      For i = 0 To 1
        
        If i = 0
          ccSeq = outerCC
        Else
          ccSeq = innerCC
        EndIf
        
        If ccSeq = 0
          Continue
        EndIf
        
        ; Directory-Daten zur Boundary-Kurve holen
        ccType  = 0
        ccPDPtr = 0
        
        ForEach DirList()
          If DirList()\SeqNo = ccSeq
            ccType  = DirList()\Type
            ccPDPtr = DirList()\PDPtr
            Break
          EndIf
        Next
        
        ; ---------------------------------------------
        ; Fall A: Boundary ist direkt eine 110-Linie
        ; ---------------------------------------------
        If ccType = 110
          If IsSurfaceEdge110(ccPDPtr) = #False
            AddElement(SurfaceEdge110())
            SurfaceEdge110()\PDPtr = ccPDPtr
          EndIf
          Continue
        EndIf
        
        ; ---------------------------------------------
        ; Fall B: Boundary ist eine 102 Composite Curve
        ; → enthält mehrere Segmente (meist 110er)
        ; ---------------------------------------------
        If ccType = 102
          
          ; passenden Parameterblock (102) suchen
          ForEach IGSCoords()
            If IGSCoords()\ParamPtr = ccPDPtr And IGSCoords()\EntityType = 102
              
              nSegs = Val(StringField(IGSCoords()\Coordinates, 1, ","))
              
              For seg = 1 To nSegs
                segSeq = Val(StringField(IGSCoords()\Coordinates, seg + 1, ",")) ; Segmente
                
                ; Directory nach Segment suchen
                ForEach DirList()
                  If DirList()\SeqNo = segSeq
                    If DirList()\Type = 110
                      
                      segPDPtr = DirList()\PDPtr
                      
                      If IsSurfaceEdge110(segPDPtr) = #False
                        AddElement(SurfaceEdge110())
                        SurfaceEdge110()\PDPtr = segPDPtr
                      EndIf
                      
                    EndIf
                    Break
                  EndIf
                Next
                
              Next seg
              
              Break   ; passenden 102er gefunden
            EndIf
          Next
          
        EndIf
        
      Next i  ; Ende Boundary A/B
      
    EndIf ; 142
    
  Next ; IGSCoords()
  
EndProcedure


Procedure BuildIGES_Directory()
  
  ClearList(DirList())
  ResetList(IGSData())
  
  Protected *d1.IGS_Columns
  Protected *d2.IGS_Columns
  
  While NextElement(IGSData())
    If IGSData()\Section = "D"
      
      ; erste D-Zeile merken
      *d1 = @IGSData()
      
      ; zweite D-Zeile holen (Status etc.)
      If NextElement(IGSData()) = 0
        Break ; Datei kaputt: zweite D-Zeile fehlt
      EndIf
      *d2 = @IGSData()
      
      ; neuen Directory-Eintrag anlegen
      AddElement(DirList())
      DirList()\SeqNo = *d1\Number
      
      ; alle Felder sind 8-Zeichen-Blöcke in der ersten D-Zeile
      DirList()\Type           = Val(Mid(*d1\Dataline,  1, 8))  ; Feld 1
      DirList()\PDPtr          = Val(Mid(*d1\Dataline,  9, 8))  ; Feld 2
      DirList()\StructureID    = Val(Mid(*d1\Dataline, 17, 8))  ; Feld 3
      DirList()\LineFont       = Val(Mid(*d1\Dataline, 25, 8))  ; Feld 4
      DirList()\Level          = Val(Mid(*d1\Dataline, 33, 8))  ; Feld 5
      DirList()\View           = Val(Mid(*d1\Dataline, 41, 8))  ; Feld 6
      DirList()\TransMatrixPtr = Val(Mid(*d1\Dataline, 49, 8))  ; Feld 7
      DirList()\LabelDispPtr   = Val(Mid(*d1\Dataline, 57, 8))  ; Feld 8

      ; *d2 könntest du später für Status, Farbe, Form etc. auswerten
    EndIf
  Wend
  
EndProcedure

Procedure IGS_Parameter()
  
  ; ---------- Parameterblöcke (P-Sektion) sammeln ----------
  
  Protected Coordinates.s = ""
  Protected curPtr.i = -1       ; aktueller "67P"-Pointer als Zahl
  Protected newPtr.i
  Protected posn.i
  
  ClearList(IGSCoords())
  
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
  
EndProcedure

Procedure DebugSurfaceCurves()
  ForEach IGSCoords()
    If IGSCoords()\EntityType = 126 Or IGSCoords()\EntityType = 102 Or IGSCoords()\EntityType = 110
      
      If FindMapElement(SurfaceCurve(), Str(IGSCoords()\ParamPtr))
        Debug "Surface-Kurve: Typ " + Str(IGSCoords()\EntityType) + "  PDPtr=" + Str(IGSCoords()\ParamPtr)
      Else
        Debug "NICHT Surface: Typ " + Str(IGSCoords()\EntityType) + "  PDPtr=" + Str(IGSCoords()\ParamPtr)
      EndIf
      
    EndIf
  Next
EndProcedure

Procedure BuildSurfaceLinesFrom110()
  Protected x1.f, y1.f, z1.f
  Protected x2.f, y2.f, z2.f
  
  ClearList(IGESLines())
  
  ForEach IGSCoords()
    If IGSCoords()\EntityType = 110
      
      ; Nur Kanten verwenden, die an einer 128-Surface hängen
      If IsSurfaceEdge110(IGSCoords()\ParamPtr) = #False
        Continue
      EndIf
      
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
EndProcedure

Procedure LoadIGES_Lines(Filename.s)
  
  Protected IGSFile.i
  Protected line.s, n.i
  Protected Section.s
  
  ClearList(IGSData())

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
  
  BuildIGES_Directory()
  IGS_Parameter()
  
  BuildIGES_Links()
  BuildSurfaceCurveMap()
  ;DebugSurfaceCurves()
  
  BuildSurfaceEdgeList()      ; 142/102/110 verknüpfen
  BuildSurfaceLinesFrom110()  ; IGESLines() mit sauberen 3D-Kanten füllen
  
  If  ListSize(IGESLines())
    ProcedureReturn #True
  Else
    Debug "No 110 Lines found"
    ProcedureReturn #False
  EndIf  
  
EndProcedure

; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 281
; FirstLine = 51
; Folding = Ua5
; EnableXP
; DPIAware
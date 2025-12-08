; IGES_144_Trimmed_Surface.pbi
; --------------------------------------------------
; IGES Entity Type 144: Trimmed Surface
; --------------------------------------------------
; Verwendet:
;   - GlobalG           (aus G_Section.pbi)
;   - DirList()        (aus D_Section.pbi)
;   - PTable()         (aus P_Section.pbi)
;   - IGES_SplitParams (aus P_Section.pbi)
;
; Ziel:
;   - Alle Entities vom Typ 144 in eine saubere
;     Struktur-Liste einlesen (TrimmedSurfaces()).
;   - Parameter werden nach IGES-Spec ungefähr
;     benannt, aber noch nicht „tief“ interpretiert.
; --------------------------------------------------

Structure IGES_144
  SeqNo.i           ; Directory Sequence Number (D-Section)
  SurfDE.i          ; Pointer auf zugrunde liegende Flaeche (z.B. Typ 128 / 143)
  OuterFlag.i       ; Flag laut Spec (z.B. 0/1 fuer Aussenrand-Interpretation)
  NumInner.i        ; Anzahl innerer Ränder
  OuterCurveDE.i    ; DE-Nummer der "Curve on Parametric Surface" (Type 142) fuer Aussenrand
  FirstInnerDE.i    ; Erste innere Boundary-Entity (Type 142), falls vorhanden
  LastInnerDE.i     ; Letzte innere Boundary-Entity (Type 142), falls vorhanden
EndStructure

Global NewList TrimmedSurfaces.IGES_144()

;---------------------------------------------------
; Hilfsfunktion: Param-Zeilen einer Entity (144)
; zu einem String zusammenbauen
;---------------------------------------------------
Procedure.s IGES_CombineParams_ForDirEntry_144(*dir.D_Sec)
  Protected combined.s
  Protected pSeq.i, lineCount.i, i.i
  Protected key.s

  combined   = ""
  pSeq       = *dir\PDPtr
  lineCount  = *dir\ParamLineCount

  For i = 0 To lineCount - 1
    key = Str(pSeq + i)
    If FindMapElement(PTable(), key)
      combined + Trim(PTable()\Text)
    Else
      ; Falls eine P-Zeile fehlt, brechen wir vorsichtshalber ab
      ; und geben das bis dahin Gesammelte zurück.
      Break
    EndIf
  Next

  ProcedureReturn combined
EndProcedure

;---------------------------------------------------
; Parser: alle Type-144 Entities einsammeln
;---------------------------------------------------
Procedure Parse_144_TrimmedSurfaces()
  Protected combined.s
  Protected paramCount.i
  Protected n.i
  Dim params.s(0)

  ClearList(TrimmedSurfaces())

  If ListSize(DirList()) = 0 Or MapSize(PTable()) = 0
    ProcedureReturn
  EndIf

  ResetList(DirList())

  ForEach DirList()
    If DirList()\Type = 144

      ; Parameterzeilen (P-Section) zusammenbauen
      combined = IGES_CombineParams_ForDirEntry_144(@DirList())

      If combined = ""
        Continue
      EndIf

      ; In Parameter zerlegen
      paramCount = IGES_SplitParams(combined, GlobalG\ParamDelim, GlobalG\RecordDelim, params())
      If paramCount < 2
        Continue
      EndIf

      ; Sicherheitscheck: EntityType in Param[0]
      If params(0) <> "144"
        ; Irgendwas krumm – wir loggen das nur mal
        Debug "WARNUNG: Param[0] <> 144 bei DirSeq " + Str(DirList()\SeqNo)
        Continue
      EndIf

      ; Neuen Eintrag anlegen
      AddElement(TrimmedSurfaces())
      TrimmedSurfaces()\SeqNo = DirList()\SeqNo

      ; Die ersten Parameter nach IGES-Doc (vereinfacht):
      ;   P1 = SurfDE
      ;   P2 = OuterFlag
      ;   P3 = NumInner
      ;   P4 = OuterCurveDE (meist Type 142)
      ;   P5 = FirstInnerDE (optional)
      ;   P6 = LastInnerDE  (optional / bei mehreren)
      ;
      ; Alles erstmal "roh" übernehmen – die genaue
      ; Interpretation / Verwendung machen wir später
      ; im Flächenbau.

      If paramCount > 1
        TrimmedSurfaces()\SurfDE = Val(params(1))
      EndIf

      If paramCount > 2
        TrimmedSurfaces()\OuterFlag = Val(params(2))
      EndIf

      If paramCount > 3
        TrimmedSurfaces()\NumInner = Val(params(3))
      EndIf

      If paramCount > 4
        TrimmedSurfaces()\OuterCurveDE = Val(params(4))
      EndIf

      If paramCount > 5
        TrimmedSurfaces()\FirstInnerDE = Val(params(5))
      EndIf

      If paramCount > 6
        TrimmedSurfaces()\LastInnerDE = Val(params(6))
      EndIf

    EndIf
  Next

EndProcedure

;---------------------------------------------------
; Debug-Ausgabe fuer Trimmed Surfaces
;---------------------------------------------------
Procedure Debug_144_TrimmedSurfaces()
  Protected count.i

  count = ListSize(TrimmedSurfaces())

  Debug "---- Trimmed Surfaces (Type 144) ----"
  Debug "Anzahl: " + Str(count)

  ForEach TrimmedSurfaces()
    Debug "TrimmedSurface SeqNo=" + Str(TrimmedSurfaces()\SeqNo) + 
          "  SurfDE="          + Str(TrimmedSurfaces()\SurfDE) + 
          "  OuterFlag="       + Str(TrimmedSurfaces()\OuterFlag) + 
          "  NumInner="        + Str(TrimmedSurfaces()\NumInner) + 
          "  OuterCurveDE="    + Str(TrimmedSurfaces()\OuterCurveDE) + 
          "  FirstInnerDE="    + Str(TrimmedSurfaces()\FirstInnerDE) + 
          "  LastInnerDE="     + Str(TrimmedSurfaces()\LastInnerDE)
  Next

  Debug "-------------------------------------"
EndProcedure

; IDE Options = PureBasic 6.20 (Windows - x64)
; EnableXP
; DPIAware

; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 168
; FirstLine = 1
; Folding = 5
; EnableXP
; DPIAware
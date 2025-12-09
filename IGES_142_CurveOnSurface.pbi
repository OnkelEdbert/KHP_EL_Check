; IGES_142_CurveOnSurface.pbi
; --------------------------------------------------
; IGES Entity Type 142: Curve on a Parametric Surface
; --------------------------------------------------
; Verwendet:
; - GlobalG (aus G_Section.pbi)
; - DirList() (aus D_Section.pbi)
; - PTable() (aus P_Section.pbi)
; - IGES_GetParamStringForDir() (aus IGES_Line110.pbi)
; - IGES_SplitParams() (aus G_Section.pbi)
;
; Nach NASA-IGES Spec (Section 4.11.4) hat Type 142:
;   createType  : Erzeugungsart
;   surface     : DE-Pointer auf die Flaeche
;   psCurve     : DE-Pointer auf Parameterraum-Kurve G(t)
;   msCurve     : DE-Pointer auf 3D-Kurve C(t)
;   pref        : Preferred representation (0..3)
;
; Im IGES-Parameterstring:
;   params(0) = "142"
;   params(1) = createType
;   params(2) = surface (SurfDE)
;   params(3) = psCurve  (Param-Kurve in (u,v))
;   params(4) = msCurve  (3D-Kurve)
;   params(5) = pref
; --------------------------------------------------

Structure IGES_142
  SeqNo.i        ; Directory Sequenznummer (D-Section)
  CreateType.i   ; Erzeugungsart (0..3)
  SurfDE.i       ; DE der Flaeche S(u,v)
  PsCurveDE.i    ; DE der Param-Kurve G(t) im (u,v)-Raum
  MsCurveDE.i    ; DE der 3D-Kurve C(t) im Modellraum
  Pref.i         ; Preferred-Flag (0..3)
EndStructure

Global NewList CurveOnSurface142.IGES_142()

Structure IGES_SurfaceEdge110
  SurfDE.i      ; zugehoerige Flaeche (128/144 -> SurfDE)
  Curve142Seq.i ; referenzierte 142-SeqNo
  CurveDE.i     ; DE der 3D-Kurve (110 oder Teil aus 102)
  IsOuter.i     ; #True = Rand, #False = Loch
EndStructure

Global NewList SurfaceEdges110.IGES_SurfaceEdge110()

Structure IGES_Point3D
  x.d
  y.d
  z.d
EndStructure

Structure IGES_SurfaceEdgePoint
  SurfDE.i        ; zugehoerige Flaeche
  Curve142Seq.i   ; zugehoerige 142-Kurve
  CurveDE.i       ; DE der Linie (110)
  SegmentIndex.i  ; Laufindex fuer zusammengesetzte Kanten (0,1,2,...)
  PointIndex.i    ; 0 = Startpunkt, 1 = Endpunkt
  x.d
  y.d
  z.d
  IsOuter.i       ; wie beim Edge: #True/#False
EndStructure

Global NewList SurfaceEdgePoints.IGES_SurfaceEdgePoint()


;---------------------------------------------------
; Directory-Eintrag ueber SeqNo finden
;---------------------------------------------------
Procedure.i IGES_FindDirBySeq(seq.i)
  If ListSize(DirList()) = 0
    ProcedureReturn 0
  EndIf

  ResetList(DirList())
  ForEach DirList()
    If DirList()\SeqNo = seq
      ProcedureReturn @DirList()
    EndIf
  Next

  ProcedureReturn 0
EndProcedure

;---------------------------------------------------
; Parser fuer EINEN Directory-Eintrag vom Typ 142
;---------------------------------------------------
Procedure.i Parse_IGES_142(*dir.D_Sec, *out.IGES_142)
  Protected combined.s
  Protected paramCount.i
  Dim params.s(0)

  If *dir = 0 Or *out = 0
    ProcedureReturn #False
  EndIf

  If *dir\Type <> 142
    ProcedureReturn #False
  EndIf

  ; Parameterstring aus P-Section holen
  combined = IGES_GetParamStringForDir(*dir)
  If combined = ""
    Debug "WARN: Type 142 kein ParamString bei SeqNo=" + Str(*dir\SeqNo)
    ProcedureReturn #False
  EndIf

  ; In einzelne Parameter zerlegen
  paramCount = IGES_SplitParams(combined, GlobalG\ParamDelim, GlobalG\RecordDelim, params())
  If paramCount < 6
    Debug "WARN: Type 142 zu wenige Parameter (" + Str(paramCount) + ") bei SeqNo=" + Str(*dir\SeqNo)
    ProcedureReturn #False
  EndIf

  ; Sicherheitscheck: erster Wert sollte 142 sein
  If Val(params(0)) <> 142
    Debug "WARN: Type 142 - Param[0] ist nicht 142 bei SeqNo=" + Str(*dir\SeqNo)
    ; Wir machen trotzdem weiter, nur Log-Hinweis
  EndIf

  ; Felder nach NASA-IGES "Database Information" mappen
  *out\SeqNo      = *dir\SeqNo
  *out\CreateType = Val(params(1))
  *out\SurfDE     = Val(params(2))
  *out\PsCurveDE  = Val(params(3))
  *out\MsCurveDE  = Val(params(4))
  *out\Pref       = Val(params(5))

  ProcedureReturn #True
EndProcedure

;---------------------------------------------------
; Gesamtliste aller Type-142-Entitaeten aufbauen
;---------------------------------------------------
Procedure Build_142_List()
  Protected tmp.IGES_142

  ClearList(CurveOnSurface142())

  If ListSize(DirList()) = 0 Or MapSize(PTable()) = 0
    ProcedureReturn
  EndIf

  ResetList(DirList())
  ForEach DirList()
    If DirList()\Type = 142
      If Parse_IGES_142(@DirList(), @tmp)
        AddElement(CurveOnSurface142())
        CurveOnSurface142() = tmp
      EndIf
    EndIf
  Next
EndProcedure

;---------------------------------------------------
; Lookup-Hilfe: 142-Entity per SeqNo finden
;---------------------------------------------------
Procedure.i IGES_142_FindBySeq(seq.i)
  ForEach CurveOnSurface142()
    If CurveOnSurface142()\SeqNo = seq
      ProcedureReturn @CurveOnSurface142()
    EndIf
  Next
  ProcedureReturn 0
EndProcedure

;---------------------------------------------------
; Modell-Kurve(n) einer 142-Entity aufloesen
; - Fuellt eine Liste mit DE-Nummern von 3D-Kurven
; - Unterstuetzt derzeit:
;     - Typ 110 (Line)
;     - Typ 102 (Composite Curve -> Liste von DEs)
;---------------------------------------------------
Procedure.i IGES_142_GetModelCurveDEs(*c.IGES_142, List outDEs.i())
  Protected *dir.D_Sec
  Protected combined.s
  Protected paramCount.i
  Protected i.i, n.i
  Dim params.s(0)

  ClearList(outDEs())

  If *c = 0
    ProcedureReturn 0
  EndIf

  ; Directory-Eintrag der Modell-Kurve holen
  *dir = IGES_FindDirBySeq(*c\MsCurveDE)
  If *dir = 0
    Debug "WARN: IGES_142_GetModelCurveDEs: MsCurveDE " + Str(*c\MsCurveDE) + " nicht im Directory gefunden."
    ProcedureReturn 0
  EndIf

  Select *dir\Type
    Case 110
      ; einfache Linie, direkt uebernehmen
      AddElement(outDEs())
      outDEs() = *c\MsCurveDE
      ProcedureReturn 1

    Case 102
      ; Composite Curve -> Parameterstring parsen
      combined = IGES_GetParamStringForDir(*dir)
      If combined = ""
        Debug "WARN: Type 102 ohne ParamString, SeqNo=" + Str(*dir\SeqNo)
        ProcedureReturn 0
      EndIf

      paramCount = IGES_SplitParams(combined, GlobalG\ParamDelim, GlobalG\RecordDelim, params())
      If paramCount < 3
        Debug "WARN: Type 102 zu wenige Parameter (" + Str(paramCount) + ") bei SeqNo=" + Str(*dir\SeqNo)
        ProcedureReturn 0
      EndIf

      ; params(0) sollte 102 sein
      If Val(params(0)) <> 102
        Debug "WARN: Type 102 - Param[0] ist nicht 102 bei SeqNo=" + Str(*dir\SeqNo)
      EndIf

      n = Val(params(1))  ; Anzahl Teilkurven
      If paramCount < 2 + n
        Debug "WARN: Type 102 - ParamCount < erwarteter Anzahl bei SeqNo=" + Str(*dir\SeqNo)
        n = paramCount - 2
      EndIf

      For i = 0 To n - 1
        AddElement(outDEs())
        outDEs() = Val(params(2 + i))
      Next

      ProcedureReturn ListSize(outDEs())
      
    Case 100
      ; TODO: Type 100 (Circular Arc) spaeter geometrisch parsen
      AddElement(outDEs())
      outDEs() = *c\MsCurveDE
      ProcedureReturn 1
      
    Default
      ; Noch nicht unterstuetzter Kurventyp
      Debug "INFO: IGES_142_GetModelCurveDEs: MsCurveDE=" + Str(*c\MsCurveDE) + " ist Typ " + Str(*dir\Type) + " (noch nicht behandelt)."
  EndSelect

  ProcedureReturn ListSize(outDEs())
EndProcedure

;---------------------------------------------------
; Debug: reine 142-Liste
;---------------------------------------------------
Procedure Debug_142_List()
  Debug "---- CurveOnSurface (Type 142) ----"
  Debug "Anzahl: " + Str(ListSize(CurveOnSurface142()))

  ForEach CurveOnSurface142()
    Debug "SeqNo=" + Str(CurveOnSurface142()\SeqNo) +
          " CreateType=" + Str(CurveOnSurface142()\CreateType) +
          " SurfDE=" + Str(CurveOnSurface142()\SurfDE) +
          " PsCurveDE=" + Str(CurveOnSurface142()\PsCurveDE) +
          " MsCurveDE=" + Str(CurveOnSurface142()\MsCurveDE) +
          " Pref=" + Str(CurveOnSurface142()\Pref)
  Next

  Debug "-----------------------------------"
EndProcedure

;---------------------------------------------------
; Debug: 144-TrimmedSurfaces inkl. zugehoeriger 142er
; -> hier werden die Kurven "auf der Flaeche greifbar"
;---------------------------------------------------

Procedure Debug_144_With_142()
  Protected *c.IGES_142
  Protected *cs.IGES_142

  Debug "---- Trimmed Surfaces + CurveOnSurface (144 + 142) ----"

  ForEach TrimmedSurfaces()
    Debug "144 SeqNo=" + Str(TrimmedSurfaces()\SeqNo) +
          " SurfDE=" + Str(TrimmedSurfaces()\SurfDE) +
          " NumInner=" + Str(TrimmedSurfaces()\NumInner) +
          " OuterCurveDE=" + Str(TrimmedSurfaces()\OuterCurveDE) +
          " FirstInnerDE=" + Str(TrimmedSurfaces()\FirstInnerDE) +
          " LastInnerDE=" + Str(TrimmedSurfaces()\LastInnerDE)

    ;--- Outer 142 ---
    If TrimmedSurfaces()\OuterCurveDE <> 0
      *c = IGES_142_FindBySeq(TrimmedSurfaces()\OuterCurveDE)
      If *c
        Debug "  Outer 142: SeqNo=" + Str(*c\SeqNo) +
              " SurfDE=" + Str(*c\SurfDE) +
              " PsCurveDE=" + Str(*c\PsCurveDE) +
              " MsCurveDE=" + Str(*c\MsCurveDE) +
              " Pref=" + Str(*c\Pref)
      Else
        Debug "  Outer 142: SeqNo=" + Str(TrimmedSurfaces()\OuterCurveDE) + " NICHT gefunden!"
      EndIf
    EndIf

    ;--- Innere 142-Kurven ---
    If TrimmedSurfaces()\NumInner > 0
      ForEach CurveOnSurface142()

        ; 1) Nur Kurven, die auf DERSELBEN Flaeche liegen
        If CurveOnSurface142()\SurfDE <> TrimmedSurfaces()\SurfDE
          Continue
        EndIf

        ; 2) Outer haben wir schon ausgegeben
        If CurveOnSurface142()\SeqNo = TrimmedSurfaces()\OuterCurveDE
          Continue
        EndIf

        ; 3) Untere Grenze (FirstInnerDE, falls > 0)
        If TrimmedSurfaces()\FirstInnerDE > 0
          If CurveOnSurface142()\SeqNo < TrimmedSurfaces()\FirstInnerDE
            Continue
          EndIf
        EndIf

        ; 4) Obere Grenze (LastInnerDE, falls > 0)
        If TrimmedSurfaces()\LastInnerDE > 0
          If CurveOnSurface142()\SeqNo > TrimmedSurfaces()\LastInnerDE
            Continue
          EndIf
        EndIf

        ; -> Wenn wir hier sind, ist es eine gueltige innere Kurve
        Debug "  Inner 142: SeqNo=" + Str(CurveOnSurface142()\SeqNo) +
              " SurfDE=" + Str(CurveOnSurface142()\SurfDE) +
              " PsCurveDE=" + Str(CurveOnSurface142()\PsCurveDE) +
              " MsCurveDE=" + Str(CurveOnSurface142()\MsCurveDE) +
              " Pref=" + Str(CurveOnSurface142()\Pref)
      Next
    EndIf
  Next

  Debug "--------------------------------------------------------"
EndProcedure


;---------------------------------------------------
; Aus 144 + 142 -> SurfaceEdges110 bauen
;---------------------------------------------------
Procedure Build_SurfaceEdges110_From_Trimmed()
  Protected *c.IGES_142
  Protected numSegs.i
  Protected *dir.D_Sec
  Protected surfDE.i
  Protected innerSeq.i
  Protected NewList curveDEs.i()

  ClearList(SurfaceEdges110())

  If ListSize(TrimmedSurfaces()) = 0 Or ListSize(CurveOnSurface142()) = 0
    ProcedureReturn
  EndIf

  ForEach TrimmedSurfaces()
    surfDE = TrimmedSurfaces()\SurfDE

    ;------------------------
    ; 1) Outer-Edge
    ;------------------------
    If TrimmedSurfaces()\OuterCurveDE <> 0
      *c = IGES_142_FindBySeq(TrimmedSurfaces()\OuterCurveDE)
      If *c
        numSegs = IGES_142_GetModelCurveDEs(*c, curveDEs())
        If numSegs > 0
          ForEach curveDEs()
            AddElement(SurfaceEdges110())
            SurfaceEdges110()\SurfDE      = surfDE
            SurfaceEdges110()\Curve142Seq = *c\SeqNo
            SurfaceEdges110()\CurveDE     = curveDEs()
            SurfaceEdges110()\IsOuter     = #True
          Next
        Else
          Debug "WARN: Outer 142 SeqNo=" + Str(*c\SeqNo) + " liefert keine Modell-Kurven."
        EndIf
      Else
        Debug "WARN: OuterCurveDE=" + Str(TrimmedSurfaces()\OuterCurveDE) + " nicht als 142 gefunden."
      EndIf
    EndIf

    ;------------------------
    ; 2) Inner-Edges
    ;------------------------
    If TrimmedSurfaces()\NumInner > 0
      ForEach CurveOnSurface142()

        ; gleiche Flaeche?
        If CurveOnSurface142()\SurfDE <> surfDE
          Continue
        EndIf

        ; nicht der Outer
        If CurveOnSurface142()\SeqNo = TrimmedSurfaces()\OuterCurveDE
          Continue
        EndIf

        ; First/LastInnerDE-Bereich pruefen
        If TrimmedSurfaces()\FirstInnerDE > 0
          If CurveOnSurface142()\SeqNo < TrimmedSurfaces()\FirstInnerDE
            Continue
          EndIf
        EndIf

        If TrimmedSurfaces()\LastInnerDE > 0
          If CurveOnSurface142()\SeqNo > TrimmedSurfaces()\LastInnerDE
            Continue
          EndIf
        EndIf

        ; -> Das ist eine gueltige innere 142-Kurve
        numSegs = IGES_142_GetModelCurveDEs(@CurveOnSurface142(), curveDEs())
        If numSegs > 0
          ForEach curveDEs()
            AddElement(SurfaceEdges110())
            SurfaceEdges110()\SurfDE      = surfDE
            SurfaceEdges110()\Curve142Seq = CurveOnSurface142()\SeqNo
            SurfaceEdges110()\CurveDE     = curveDEs()
            SurfaceEdges110()\IsOuter     = #False
          Next
        Else
          Debug "WARN: Inner 142 SeqNo=" + Str(CurveOnSurface142()\SeqNo) + " liefert keine Modell-Kurven."
        EndIf

      Next  ; CurveOnSurface142
    EndIf

  Next  ; TrimmedSurfaces
EndProcedure

Procedure Debug_SurfaceEdges110()
  Debug "---- SurfaceEdges110 (aus 144 + 142) ----"
  Debug "Anzahl: " + Str(ListSize(SurfaceEdges110()))

  ForEach SurfaceEdges110()
    Debug "SurfDE=" + Str(SurfaceEdges110()\SurfDE) +
          "  Curve142Seq=" + Str(SurfaceEdges110()\Curve142Seq) +
          "  CurveDE=" + Str(SurfaceEdges110()\CurveDE) +
          "  IsOuter=" + Str(SurfaceEdges110()\IsOuter)
  Next

  Debug "-----------------------------------------"
EndProcedure

;---------------------------------------------------
; Type 100 (Circular Arc) - Punktliste samplen
;  Param-Schema:
;    params(0) = 100
;    params(1) = ZT
;    params(2) = X1 (Center)
;    params(3) = Y1 (Center)
;    params(4) = X2 (Start)
;    params(5) = Y2 (Start)
;    params(6) = X3 (End)
;    params(7) = Y3 (End)
;  -> schreibt eine Liste von 3D-Punkten in outPts()
;---------------------------------------------------
Procedure.i IGES_100_SamplePointsForDE(de.i, List outPts.IGES_Point3D())
  Protected *dir.D_Sec
  Protected combined.s
  Protected paramCount.i
  Protected i.i, steps.i
  Protected zt.d, cx.d, cy.d, sx.d, sy.d, ex.d, ey.d
  Protected r.d, dx.d, dy.d
  Protected aStart.d, aEnd.d, aSpan.d, t.d, x.d, y.d

  Dim params.s(0)
  ClearList(outPts())

  *dir = IGES_FindDirBySeq(de)
  If *dir = 0
    Debug "WARN: IGES_100_SamplePointsForDE: DE " + Str(de) + " nicht im Directory gefunden."
    ProcedureReturn #False
  EndIf

  If *dir\Type <> 100
    Debug "WARN: IGES_100_SamplePointsForDE: DE " + Str(de) + " ist Typ " + Str(*dir\Type) + " (nicht 100)."
    ProcedureReturn #False
  EndIf

  combined = IGES_GetParamStringForDir(*dir)
  If combined = ""
    Debug "WARN: IGES_100_SamplePointsForDE: DE " + Str(de) + " kein ParamString."
    ProcedureReturn #False
  EndIf

  paramCount = IGES_SplitParams(combined, GlobalG\ParamDelim, GlobalG\RecordDelim, params())
  If paramCount < 8
    Debug "WARN: IGES_100_SamplePointsForDE: DE " + Str(de) + " hat nur " + Str(paramCount) + " Parameter."
    ProcedureReturn #False
  EndIf

  ; Optional: erster Wert pruefen
  If Val(params(0)) <> 100
    Debug "WARN: IGES_100_SamplePointsForDE: Param[0] != 100 bei DE " + Str(de)
  EndIf

  zt = ValD(params(1))
  cx = ValD(params(2))
  cy = ValD(params(3))
  sx = ValD(params(4))
  sy = ValD(params(5))
  ex = ValD(params(6))
  ey = ValD(params(7))

  ; Radius aus Startpunkt
  dx = sx - cx : dy = sy - cy
  r  = Sqr(dx * dx + dy * dy)
  If r <= 0.0
    Debug "WARN: IGES_100_SamplePointsForDE: DE " + Str(de) + " Radius=0."
    ProcedureReturn #False
  EndIf

  ; Winkel Start/End gegen den Uhrzeigersinn
  aStart = ATan2(sy - cy, sx - cx)
  aEnd   = ATan2(ey - cy, ex - cx)

  If aEnd <= aStart
    aEnd + 2.0 * #PI
  EndIf

  aSpan = aEnd - aStart

  ; Segmente: ca. 10 Grad pro Segment, mind. 4
  steps = Int(aSpan / (#PI / 18.0)) + 1
  If steps < 4
    steps = 4
  EndIf

  For i = 0 To steps
    t = aStart + aSpan * i / steps
    x = cx + r * Cos(t)
    y = cy + r * Sin(t)

    AddElement(outPts())
    outPts()\x = x
    outPts()\y = y
    outPts()\z = zt
  Next

  ProcedureReturn ListSize(outPts())
EndProcedure

;---------------------------------------------------
; Type 110 (Line) - Punkte aus Param-String holen
;  Param-Schema (IGES 110):
;    params(0) = 110
;    params(1) = X1
;    params(2) = Y1
;    params(3) = Z1
;    params(4) = X2
;    params(5) = Y2
;    params(6) = Z2
;---------------------------------------------------
Procedure.i IGES_110_GetPointsForDE(de.i, *p1.IGES_Point3D, *p2.IGES_Point3D)
  Protected *dir.D_Sec
  Protected combined.s
  Protected paramCount.i
  Dim params.s(0)

  If *p1 = 0 Or *p2 = 0
    ProcedureReturn #False
  EndIf

  *dir = IGES_FindDirBySeq(de)
  If *dir = 0
    Debug "WARN: IGES_110_GetPointsForDE: DE " + Str(de) + " nicht im Directory gefunden."
    ProcedureReturn #False
  EndIf

  If *dir\Type <> 110
    Debug "WARN: IGES_110_GetPointsForDE: DE " + Str(de) + " ist Typ " + Str(*dir\Type) + " (nicht 110)."
    ProcedureReturn #False
  EndIf

  combined = IGES_GetParamStringForDir(*dir)
  If combined = ""
    Debug "WARN: IGES_110_GetPointsForDE: DE " + Str(de) + " kein ParamString."
    ProcedureReturn #False
  EndIf

  paramCount = IGES_SplitParams(combined, GlobalG\ParamDelim, GlobalG\RecordDelim, params())
  If paramCount < 7
    Debug "WARN: IGES_110_GetPointsForDE: DE " + Str(de) + " hat nur " + Str(paramCount) + " Parameter."
    ProcedureReturn #False
  EndIf

  ; Optional: erster Wert pruefen
  If Val(params(0)) <> 110
    Debug "WARN: IGES_110_GetPointsForDE: Param[0] != 110 bei DE " + Str(de)
  EndIf

  *p1\x = ValD(params(1))
  *p1\y = ValD(params(2))
  *p1\z = ValD(params(3))

  *p2\x = ValD(params(4))
  *p2\y = ValD(params(5))
  *p2\z = ValD(params(6))

  ProcedureReturn #True
EndProcedure
    
;---------------------------------------------------
; Aus SurfaceEdges110 -> konkrete Punktliste
;   - erwartet: SurfaceEdges110 bereits aufgebaut
;   - fuellt:   SurfaceEdgePoints (2 Punkte pro Edge)
;---------------------------------------------------
Procedure X_Build_SurfaceEdgePoints()
  Protected p1.IGES_Point3D
  Protected p2.IGES_Point3D
  Protected segIndex.i
  Protected lastKey.s
  Protected key.s

  ClearList(SurfaceEdgePoints())

  If ListSize(SurfaceEdges110()) = 0
    ProcedureReturn
  EndIf

  ; Wir bauen einen einfachen SegmentIndex pro (SurfDE, Curve142Seq)
  lastKey = ""

  ForEach SurfaceEdges110()

    key = Str(SurfaceEdges110()\SurfDE) + "_" + Str(SurfaceEdges110()\Curve142Seq)
    If key <> lastKey
      segIndex = 0
      lastKey  = key
    Else
      segIndex + 1
    EndIf

    ; Nur Typ 110 behandeln (100/126 usw. kommen spaeter)
    If IGES_110_GetPointsForDE(SurfaceEdges110()\CurveDE, @p1, @p2)

      ; Startpunkt
      AddElement(SurfaceEdgePoints())
      SurfaceEdgePoints()\SurfDE        = SurfaceEdges110()\SurfDE
      SurfaceEdgePoints()\Curve142Seq   = SurfaceEdges110()\Curve142Seq
      SurfaceEdgePoints()\CurveDE       = SurfaceEdges110()\CurveDE
      SurfaceEdgePoints()\SegmentIndex  = segIndex
      SurfaceEdgePoints()\PointIndex    = 0
      SurfaceEdgePoints()\x             = p1\x
      SurfaceEdgePoints()\y             = p1\y
      SurfaceEdgePoints()\z             = p1\z
      SurfaceEdgePoints()\IsOuter       = SurfaceEdges110()\IsOuter

      ; Endpunkt
      AddElement(SurfaceEdgePoints())
      SurfaceEdgePoints()\SurfDE        = SurfaceEdges110()\SurfDE
      SurfaceEdgePoints()\Curve142Seq   = SurfaceEdges110()\Curve142Seq
      SurfaceEdgePoints()\CurveDE       = SurfaceEdges110()\CurveDE
      SurfaceEdgePoints()\SegmentIndex  = segIndex
      SurfaceEdgePoints()\PointIndex    = 1
      SurfaceEdgePoints()\x             = p2\x
      SurfaceEdgePoints()\y             = p2\y
      SurfaceEdgePoints()\z             = p2\z
      SurfaceEdgePoints()\IsOuter       = SurfaceEdges110()\IsOuter

    Else
      ; Kein 110er oder Fehler -> ignorieren (z.B. Typ 100 spaeter)
      ;Debug "INFO: Build_SurfaceEdgePoints: CurveDE=" + Str(SurfaceEdges110()\CurveDE) + " liefert keine 110-Punkte."
    EndIf

  Next
EndProcedure

Procedure Build_SurfaceEdgePoints()
  Protected p1.IGES_Point3D
  Protected p2.IGES_Point3D
  Protected segIndex.i
  Protected lastKey.s, key.s

  Protected *dir.D_Sec
  Protected lastX.d, lastY.d, lastZ.d
  Protected firstPointSet.i

  ClearList(SurfaceEdgePoints())

  If ListSize(SurfaceEdges110()) = 0
    ProcedureReturn
  EndIf

  ResetList(SurfaceEdges110())
  ForEach SurfaceEdges110()

    key = Str(SurfaceEdges110()\SurfDE) + "_" + Str(SurfaceEdges110()\Curve142Seq)
    If key <> lastKey
      segIndex = 0
      lastKey  = key
    Else
      segIndex + 1
    EndIf

    *dir = IGES_FindDirBySeq(SurfaceEdges110()\CurveDE)
    If *dir = 0
      Continue
    EndIf

    Select *dir\Type

      ;-----------------------------------
      ; 110 = Gerade Linie (wie bisher)
      ;-----------------------------------
      Case 110
        If IGES_110_GetPointsForDE(SurfaceEdges110()\CurveDE, @p1, @p2)

          ; Startpunkt
          AddElement(SurfaceEdgePoints())
          SurfaceEdgePoints()\SurfDE        = SurfaceEdges110()\SurfDE
          SurfaceEdgePoints()\Curve142Seq   = SurfaceEdges110()\Curve142Seq
          SurfaceEdgePoints()\CurveDE       = SurfaceEdges110()\CurveDE
          SurfaceEdgePoints()\SegmentIndex  = segIndex
          SurfaceEdgePoints()\PointIndex    = 0
          SurfaceEdgePoints()\x             = p1\x
          SurfaceEdgePoints()\y             = p1\y
          SurfaceEdgePoints()\z             = p1\z
          SurfaceEdgePoints()\IsOuter       = SurfaceEdges110()\IsOuter

          ; Endpunkt
          AddElement(SurfaceEdgePoints())
          SurfaceEdgePoints()\SurfDE        = SurfaceEdges110()\SurfDE
          SurfaceEdgePoints()\Curve142Seq   = SurfaceEdges110()\Curve142Seq
          SurfaceEdgePoints()\CurveDE       = SurfaceEdges110()\CurveDE
          SurfaceEdgePoints()\SegmentIndex  = segIndex
          SurfaceEdgePoints()\PointIndex    = 1
          SurfaceEdgePoints()\x             = p2\x
          SurfaceEdgePoints()\y             = p2\y
          SurfaceEdgePoints()\z             = p2\z
          SurfaceEdgePoints()\IsOuter       = SurfaceEdges110()\IsOuter

        EndIf

      ;-----------------------------------
      ; 100 = Circular Arc -> Polyline
      ;-----------------------------------
      Case 100
        Protected NewList arcPts.IGES_Point3D()

        If IGES_100_SamplePointsForDE(SurfaceEdges110()\CurveDE, arcPts())
          firstPointSet = #False

          ResetList(arcPts())
          While NextElement(arcPts())
            If firstPointSet = #False
              ; ersten Punkt merken, noch kein Segment
              lastX = arcPts()\x
              lastY = arcPts()\y
              lastZ = arcPts()\z
              firstPointSet = #True
            Else
              ; Segment von last -> aktueller Punkt
              p1\x = lastX : p1\y = lastY : p1\z = lastZ
              p2\x = arcPts()\x
              p2\y = arcPts()\y
              p2\z = arcPts()\z

              ; Startpunkt
              AddElement(SurfaceEdgePoints())
              SurfaceEdgePoints()\SurfDE        = SurfaceEdges110()\SurfDE
              SurfaceEdgePoints()\Curve142Seq   = SurfaceEdges110()\Curve142Seq
              SurfaceEdgePoints()\CurveDE       = SurfaceEdges110()\CurveDE
              SurfaceEdgePoints()\SegmentIndex  = segIndex
              SurfaceEdgePoints()\PointIndex    = 0
              SurfaceEdgePoints()\x             = p1\x
              SurfaceEdgePoints()\y             = p1\y
              SurfaceEdgePoints()\z             = p1\z
              SurfaceEdgePoints()\IsOuter       = SurfaceEdges110()\IsOuter

              ; Endpunkt
              AddElement(SurfaceEdgePoints())
              SurfaceEdgePoints()\SurfDE        = SurfaceEdges110()\SurfDE
              SurfaceEdgePoints()\Curve142Seq   = SurfaceEdges110()\Curve142Seq
              SurfaceEdgePoints()\CurveDE       = SurfaceEdges110()\CurveDE
              SurfaceEdgePoints()\SegmentIndex  = segIndex
              SurfaceEdgePoints()\PointIndex    = 1
              SurfaceEdgePoints()\x             = p2\x
              SurfaceEdgePoints()\y             = p2\y
              SurfaceEdgePoints()\z             = p2\z
              SurfaceEdgePoints()\IsOuter       = SurfaceEdges110()\IsOuter

              ; aktuellen Punkt als "last" merken
              lastX = p2\x
              lastY = p2\y
              lastZ = p2\z
            EndIf
          Wend
        EndIf

      Default
        ; z.B. spaeter andere Kurventypen
        ; Debug "INFO: Build_SurfaceEdgePoints: CurveDE=" + Str(SurfaceEdges110()\CurveDE) + " Typ " + Str(*dir\Type) + " (noch nicht umgesetzt)"
    EndSelect

  Next
EndProcedure

Procedure Debug_SurfaceEdgePoints()
  Debug "---- SurfaceEdgePoints (aus 110) ----"
  Debug "Anzahl: " + Str(ListSize(SurfaceEdgePoints()))

  ForEach SurfaceEdgePoints()
    Debug "SurfDE=" + Str(SurfaceEdgePoints()\SurfDE) +
          "  Curve142Seq=" + Str(SurfaceEdgePoints()\Curve142Seq) +
          "  CurveDE=" + Str(SurfaceEdgePoints()\CurveDE) +
          "  Seg=" + Str(SurfaceEdgePoints()\SegmentIndex) +
          "  Pt=" + Str(SurfaceEdgePoints()\PointIndex) +
          "  IsOuter=" + Str(SurfaceEdgePoints()\IsOuter) +
          "  P=(" + StrD(SurfaceEdgePoints()\x, 3) + "," +
                     StrD(SurfaceEdgePoints()\y, 3) + "," +
                     StrD(SurfaceEdgePoints()\z, 3) + ")"
  Next

  Debug "-------------------------------------"
EndProcedure

;---------------------------------------------------
; Alle Punkte fuer eine Flaeche und Outer/Inner
;   surfDE  - DE der Flaeche (wie in TrimmedSurfaces()\SurfDE)
;   isOuter - #True = Rand, #False = Loch
;   outPts  - Rueckgabe-Liste mit 3D-Punkten
;---------------------------------------------------
Procedure Get_SurfaceEdgePointsForSurface(surfDE.i, isOuter.i, List outPts.IGES_Point3D())
  ClearList(outPts())

  ForEach SurfaceEdgePoints()
    If SurfaceEdgePoints()\SurfDE  = surfDE And
       SurfaceEdgePoints()\IsOuter = isOuter

      AddElement(outPts())
      outPts()\x = SurfaceEdgePoints()\x
      outPts()\y = SurfaceEdgePoints()\y
      outPts()\z = SurfaceEdgePoints()\z
    EndIf
  Next
EndProcedure



; IDE Options = PureBasic 6.20 (Windows - x64)
; EnableXP
; DPIAware

; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 546
; FirstLine = 122
; Folding = gAk
; EnableXP
; DPIAware
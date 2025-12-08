; IGES Type 102 – Composite Curve
; ===============================

Structure IGES_102
  SeqNo.i
  NumSegments.i
EndStructure
Global NewList Curve102.IGES_102()

Structure Curve102Segment
  ParentSeqNo.i   ; Sequenznummer der 102-Entität
  ChildDE.i       ; DE-Nummer des Segments
EndStructure
Global NewList Curve102_Segments.Curve102Segment()

Procedure Parse_IGES_102(*dir.D_Sec)
  Protected combined.s
  Protected count.i, numSeg.i, i.i
  Dim params.s(0)

  If *dir = 0 Or *dir\Type <> 102
    ProcedureReturn #False
  EndIf

  combined = IGES_GetParamStringForDir(*dir)
  If combined = ""
    Debug "WARN: Type 102 kein ParamString bei SeqNo=" + Str(*dir\SeqNo)
    ProcedureReturn #False
  EndIf

  count = IGES_SplitParams(combined, GlobalG\ParamDelim, GlobalG\RecordDelim, params())
  If count < 2
    Debug "WARN: Type 102 zu wenige Parameter!"
    ProcedureReturn #False
  EndIf

  numSeg = Val(params(1))

  ; Composite Curve registrieren
  AddElement(Curve102())
  Curve102()\SeqNo       = *dir\SeqNo
  Curve102()\NumSegments = numSeg

  ; Segmente als einzelne Listeneinträge
  For i = 0 To numSeg - 1
    AddElement(Curve102_Segments())
    Curve102_Segments()\ParentSeqNo = *dir\SeqNo
    Curve102_Segments()\ChildDE     = Val(params(2 + i))
  Next

  ProcedureReturn #True
EndProcedure

Procedure Build_102_List()
  ClearList(Curve102())
  
  ForEach DirList()
    If DirList()\Type = 102
      Parse_IGES_102(@DirList())
    EndIf
  Next
EndProcedure


Procedure Debug_102_List()
  Debug "---- Composite Curves (Type 102) ----"

  ForEach Curve102()
    Debug "CompositeCurve SeqNo=" + Str(Curve102()\SeqNo) +
          "  Segmente=" + Str(Curve102()\NumSegments)

    Debug "  Children:"
    ForEach Curve102_Segments()
      If Curve102_Segments()\ParentSeqNo = Curve102()\SeqNo
        Debug "    DE = " + Str(Curve102_Segments()\ChildDE)
      EndIf
    Next
  Next

  Debug "-------------------------------------"
EndProcedure



; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 13
; FirstLine = 36
; Folding = -
; EnableXP
; DPIAware
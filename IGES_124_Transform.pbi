; IGES_124_Transform.pbi
; --------------------------------------------
; Parser für IGES-Entity Type 124 (Transformationsmatrix)
; und Helper zum Anwenden auf IGES_Point
; --------------------------------------------

Structure IGES_Transform124
  SeqNo.i
  ; 3x3-Matrix
  m11.d : m12.d : m13.d
  m21.d : m22.d : m23.d
  m31.d : m32.d : m33.d
  ; Translation
  tx.d  : ty.d  : tz.d
EndStructure

; Key = Str(SeqNo) aus DirList()
Global NewMap Transform124.IGES_Transform124()

; Hilfsfunktion: Param-String für einen Directory-Eintrag holen
; (wie bei Line110, aber lokal hier)
Procedure.s IGES_124_GetParamString(*dir.D_Sec)
  Protected pSeq.i, lineCount.i, i.i
  Protected key.s, combined.s

  If *dir = 0
    ProcedureReturn ""
  EndIf

  pSeq      = *dir\PDPtr
  lineCount = *dir\ParamLineCount

  If pSeq <= 0 Or lineCount <= 0
    ProcedureReturn ""
  EndIf

  combined = ""

  For i = 0 To lineCount - 1
    key = Str(pSeq + i)
    If FindMapElement(PTable(), key)
      combined + Trim(PTable()\Text)
    Else
      Debug "WARN: IGES_124_GetParamString - PSeq " + key + " nicht gefunden (SeqNo=" + Str(*dir\SeqNo) + ")"
    EndIf
  Next

  ProcedureReturn combined
EndProcedure

; Alle Type-124-Matrizen in eine Map einlesen
Procedure Build_Transform124_Map()
  Protected combined.s
  Protected paramCount.i, i.i
  Protected key.s

  Dim params.s(0)

  ClearMap(Transform124())

  ForEach DirList()
    If DirList()\Type = 124

      combined = IGES_124_GetParamString(@DirList())
      If combined = ""
        Debug "WARN: Build_Transform124_Map - keine Paramdaten für 124, SeqNo=" + Str(DirList()\SeqNo)
      Else
        paramCount = IGES_SplitParams(combined, GlobalG\ParamDelim, GlobalG\RecordDelim, params())

        If paramCount < 13
          Debug "WARN: Build_Transform124_Map - zu wenige Parameter (" + Str(paramCount) + ") für 124, SeqNo=" + Str(DirList()\SeqNo)
        ElseIf Val(params(0)) <> 124
          Debug "WARN: Build_Transform124_Map - Param[0] ist nicht 124 bei SeqNo=" + Str(DirList()\SeqNo)
        Else
          key = Str(DirList()\SeqNo)

          If AddMapElement(Transform124(), key)
            Transform124()\SeqNo = DirList()\SeqNo

            ; IGES 124: 124, a11,a12,a13,a14, a21,a22,a23,a24, a31,a32,a33,a34
            Transform124()\m11 = ValD(params(1))
            Transform124()\m12 = ValD(params(2))
            Transform124()\m13 = ValD(params(3))
            Transform124()\tx  = ValD(params(4))

            Transform124()\m21 = ValD(params(5))
            Transform124()\m22 = ValD(params(6))
            Transform124()\m23 = ValD(params(7))
            Transform124()\ty  = ValD(params(8))

            Transform124()\m31 = ValD(params(9))
            Transform124()\m32 = ValD(params(10))
            Transform124()\m33 = ValD(params(11))
            Transform124()\tz  = ValD(params(12))
          EndIf
        EndIf
      EndIf

    EndIf
  Next
EndProcedure

; Punkt mit Transformationsmatrix (SeqNo aus D-Section) transformieren
Procedure IGES_ApplyTransformToPoint(*pt.IGES_Point, transSeqNo.i)
  Protected key.s
  Protected x.d, y.d, z.d

  If *pt = 0 Or transSeqNo <= 0
    ProcedureReturn
  EndIf

  key = Str(transSeqNo)
  If FindMapElement(Transform124(), key) = 0
    ProcedureReturn
  EndIf

  x = *pt\x
  y = *pt\y
  z = *pt\z

  *pt\x = Transform124()\m11 * x + Transform124()\m12 * y + Transform124()\m13 * z + Transform124()\tx
  *pt\y = Transform124()\m21 * x + Transform124()\m22 * y + Transform124()\m23 * z + Transform124()\ty
  *pt\z = Transform124()\m31 * x + Transform124()\m32 * y + Transform124()\m33 * z + Transform124()\tz
EndProcedure

; Optional: Debug
Procedure Debug_Transform124_Map()
  Debug "---- Transform124 Map ----"
  ForEach Transform124()
    Debug "SeqNo=" + Str(Transform124()\SeqNo) +
          "  tx=" + StrD(Transform124()\tx) +
          "  ty=" + StrD(Transform124()\ty) +
          "  tz=" + StrD(Transform124()\tz)
  Next
  Debug "--------------------------"
EndProcedure

; IDE Options = PureBasic 6.20 (Windows - x64)
; EnableXP
; DPIAware

; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 140
; Folding = w
; EnableXP
; DPIAware
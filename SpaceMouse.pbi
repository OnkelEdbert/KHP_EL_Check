;{ --- 3D Mouse Structure ---
#RIDEV_INPUTSINK = $00000100
#RID_INPUT       = $10000003
#WM_INPUT        = $00FF
#INPUT_MOUSE = 0
#MOUSEEVENTF_MOVE = $0001
#MOUSEEVENTF_RIGHTDOWN = $0008
#MOUSEEVENTF_RIGHTUP   = $0010
#MOUSEEVENTF_WHEEL = $0800
#KEYEVENTF_KEYUP = $0002

Structure RAWINPUT_HID
  header.RAWINPUTHEADER
  dwSizeHID.l
  dwCount.l
  bRawData.b[0] ; flexible Länge
EndStructure

Structure RAWINPUT_MOUSE
  header.RAWINPUTHEADER
  usFlags.w
  ulButtons.l
  usButtonFlags.w
  usButtonData.w
  ulRawButtons.l
  lLastX.l
  lLastY.l
  ulExtraInformation.l
EndStructure

; --- SpaceMouse Zustand (wird im Callback gefüllt) ---
Structure SpaceMouseState
  tx.f      ; Translation X
  ty.f      ; Translation Y
  tz.f      ; Translation Z
  rx.f      ; Rotation X
  ry.f      ; Rotation Y
  rz.f      ; Rotation Z
  buttons.l ; Bitmaske der Knöpfe
EndStructure
Global SpaceMouse.SpaceMouseState
;}

Procedure.i Register_SpaceMouse(hwnd.i)
  
  Protected rid.RAWINPUTDEVICE
  rid\usUsagePage = 1          ; Generic Desktop Controls
  rid\usUsage     = 8          ; Multi-axis Controller (SpaceMouse)
  rid\dwFlags     = #RIDEV_INPUTSINK
  rid\hwndTarget  = hwnd
  ProcedureReturn RegisterRawInputDevices_(@rid, 1, SizeOf(RAWINPUTDEVICE))
  
EndProcedure

Procedure SpM_WindowCallback(hwnd, uMsg, wParam, lParam)
  
  Protected i.i, j.i
  Protected offset, rawSize, count, size
  Protected *hid.RAWINPUT_HID, *hdr.RAWINPUTHEADER, *rawData 
  Protected tx.w, ty.w, tz.w, rx.w, ry.w, rz.w
  
  Select uMsg
    Case #WM_INPUT
      rawSize = 0
      GetRawInputData_(lParam, #RID_INPUT, 0, @rawSize, SizeOf(RAWINPUTHEADER))
      If rawSize > 0
        *rawData = AllocateMemory(rawSize)
        If *rawData
          If GetRawInputData_(lParam, #RID_INPUT, *rawData, @rawSize, SizeOf(RAWINPUTHEADER)) = rawSize
            *hdr.RAWINPUTHEADER = *rawData
            If *hdr\dwType = 2 ; HID-Gerät
              *hid.RAWINPUT_HID = *rawData
              size = *hid\dwSizeHID
              count = *hid\dwCount
              For i = 0 To count - 1
                offset = i * size               
                Select *hid\bRawData[offset] ; Byte 0 ? VecType
                  Case 1                     ; Translation (X, Y, Z)
                    tx = PeekW(@*hid\bRawData[offset + 1])
                    ty = PeekW(@*hid\bRawData[offset + 3])
                    tz = PeekW(@*hid\bRawData[offset + 5])
                    ; In Floats umrechnen + grob normieren (SpaceMouse ca. -350..+350)
                    SpaceMouse\tx = tx / 350.0
                    SpaceMouse\ty = ty / 350.0
                    SpaceMouse\tz = tz / 350.0
                    ;Debug SpaceMouse\rx
                  Case 2 ; Rotation (Rx, Ry, Rz)
                    rx = PeekW(@*hid\bRawData[offset + 1])
                    ry = PeekW(@*hid\bRawData[offset + 3])
                    rz = PeekW(@*hid\bRawData[offset + 5])
                    SpaceMouse\rx = rx / 350.0
                    SpaceMouse\ry = ry / 350.0
                    SpaceMouse\rz = rz / 350.0
                  Case 3 ; Buttons
                    SpaceMouse\buttons = *hid\bRawData[offset + 1]
                EndSelect
              Next
            EndIf
          EndIf
          FreeMemory(*rawData)
        EndIf
      EndIf
  EndSelect
  
  ProcedureReturn #PB_ProcessPureBasicEvents
  
EndProcedure
; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 53
; Folding = 6
; EnableXP
; DPIAware
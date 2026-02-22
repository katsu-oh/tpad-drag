#Requires AutoHotkey v2 64-bit

ListLines(False)
;-----------------------------------------------------------------------------
;@Ahk2Exe-SetFileVersion 1.0.0.0
;@Ahk2Exe-SetDescription Touchpad Utility "TouchpaDRAGger"
;@Ahk2Exe-SetProductName TouchpaDRAGger
;@Ahk2Exe-SetProductVersion 1.0.0.0
;@Ahk2Exe-SetCopyright Katsuo`, 2026
;@Ahk2Exe-SetOrigFilename TpadDrag.exe
;-----------------------------------------------------------------------------
#NoTrayIcon
#SingleInstance Force
Persistent
KeyHistory(0)
SendMode("Event")
SetMouseDelay(-1)
CoordMode("Mouse", "Screen")
Critical(5)

#DllLoad "hid"

BeforePreparsed := True
PrevTickCount := A_TickCount

Device := Buffer(8 + A_PtrSize, 0)
NumPut("UShort",0x0D, "UShort",0x05, "UInt",0x00000100, "Ptr",A_ScriptHwnd, Device)
DllCall("RegisterRawInputDevices", "Ptr",Device, "UInt",1, "UInt",8 + A_PtrSize)

OnMessage(0x00FF, OnTouch)
Exit

;-----------------------------------------------------------------------------

OnTouch(wParam, lParam, msg, hwnd) {
    ThisTickCount := A_TickCount

    Global BeforePreparsed
    Global Preparsed
    Global PrevTickCount
    Global StartX
    Global StartY
    Global Completed

    RawInputSize := 0
    DllCall("GetRawInputData", "Ptr",lParam, "UInt",0x10000003, "Ptr",0,        "UInt*",&RawInputSize, "UInt",8 + A_PtrSize * 2)
    RawInput := Buffer(RawInputSize, 0)
    DllCall("GetRawInputData", "Ptr",lParam, "UInt",0x10000003, "Ptr",RawInput, "UInt*",&RawInputSize, "UInt",8 + A_PtrSize * 2)

    If (BeforePreparsed) {
        hDevice := NumGet(RawInput, 8, "Ptr")
        PreparsedSize := 0
        DllCall("GetRawInputDeviceInfo", "Ptr",hDevice, "UInt",0x20000005, "Ptr",0,         "UInt*",&PreparsedSize)
        Preparsed := Buffer(PreparsedSize, 0)
        BeforePreparsed
     := DllCall("GetRawInputDeviceInfo", "Ptr",hDevice, "UInt",0x20000005, "Ptr",Preparsed, "UInt*",&PreparsedSize) <= 0
    }

    ContactCount := 0
    DllCall("hid\HidP_GetUsageValue", "Int",0x00, "UShort",0x0D, "UShort",0, "UShort",0x54, "UInt*",&ContactCount, "Ptr",Preparsed
                                    , "Ptr",RawInput.Ptr + 16 + A_PtrSize * 2, "UInt",RawInputSize - (16 + A_PtrSize * 2))

    If (ContactCount = 4) {
        Caps := Buffer(64, 0)
        DllCall("hid\HidP_GetCaps", "Ptr",Preparsed, "Ptr",Caps)

        ValueCapsLength := NumGet(Caps, 48, "UShort")
        ValueCaps := Buffer(ValueCapsLength * 72, 0)
        DllCall("hid\HidP_GetValueCaps", "Int",0x00, "Ptr",ValueCaps, "UShort*",&ValueCapsLength, "Ptr",Preparsed)

        SumX := 0
        SumY := 0
        Offset := 0
        Loop (ValueCapsLength) {
            UsagePage := NumGet(ValueCaps, Offset + 0,  "UShort")
            Usage     := NumGet(ValueCaps, Offset + 56, "UShort")
            If (UsagePage = 0x01) {
                If (Usage = 0x30) {
                    Link := NumGet(ValueCaps, Offset + 6, "UShort")
                    X := 2 ** 30
                    DllCall("hid\HidP_GetUsageValue", "Int",0x00, "UShort",UsagePage, "UShort",Link, "UShort",Usage, "UInt*",&X, "Ptr",Preparsed
                                                    , "Ptr",RawInput.Ptr + 16 + A_PtrSize * 2, "UInt",RawInputSize - (16 + A_PtrSize * 2))
                    SumX += X
                    MaxX := NumGet(ValueCaps, Offset + 44, "Int") 
                    If (X = 2 ** 30) Or (MaxX = 0) {
                        Return
                    }
                } Else If (Usage = 0x31) {
                    Link := NumGet(ValueCaps, Offset + 6, "UShort")
                    Y := 2 ** 30
                    DllCall("hid\HidP_GetUsageValue", "Int",0x00, "UShort",UsagePage, "UShort",Link, "UShort",Usage, "UInt*",&Y, "Ptr",Preparsed
                                                    , "Ptr",RawInput.Ptr + 16 + A_PtrSize * 2, "UInt",RawInputSize - (16 + A_PtrSize * 2))
                    SumY += Y
                    MaxY := NumGet(ValueCaps, Offset + 44, "Int") 
                    If (Y = 2 ** 30) Or (MaxY = 0) {
                        Return
                    }
                }
            }
            Offset += 72
        }

        X := SumX / ContactCount
        Y := SumY / ContactCount

        If (TickCountDiff(ThisTickCount, PrevTickCount) >= 62) {
            StartX := X
            StartY := Y
            Completed := False
        } Else If (!Completed) {
            DX := MaxX * 0.1
            DY := MaxY * 0.1

            If (X >= StartX + DX) {
                Completed := True
                If (GetKeyState("LButton", "P")) {
                    SendInput("{Blind}{LButton Up}")
                } Else {
                    If (!GetKeyState("RButton", "P")) {
                        SendInput("{Blind}{RButton Down}")
                    }
                }
            } Else If (X <= StartX - DX) {
                Completed := True
                If (GetKeyState("RButton", "P")) {
                    SendInput("{Blind}{RButton Up}")
                } Else {
                    If (!GetKeyState("LButton", "P")) {
                        SendInput("{Blind}{LButton Down}")
                    }
                }
            } Else If (Y >= StartY + DY) {
                Completed := True
            } Else If (Y <= StartY - DY) {
                Completed := True
            }
        }

        PrevTickCount := ThisTickCount
    }    
}

;-----------------------------------------------------------------------------

TickCountDiff(After, Before) {
    If (Before - After >= 2 ** 31) {
        Return(After - Before + 2 ** 32)
    } Else {
        Return(After - Before)
    }
}

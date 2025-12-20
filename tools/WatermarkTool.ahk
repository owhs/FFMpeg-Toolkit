
/*
    FFmpeg Watermark & Overlay Tool (AHK v2)
    ----------------------------------------
    Robust multi-layer watermarking system.
    Features:
    - Text and Image layers.
    - Live GUI Preview with Scrubbing/Seeking.
    - True Aspect Ratio rendering.
    - Timeline (Fade In/Out, Start/End).
    - Variable support (%time%, %name%, etc).
    - Layer Reordering.
    - Scrollable Layer List (Uses new Utils Class).
*/


#Include ..\lib\utils.ahk
WatermarkTool() {
    global AppName := "FFMpeg: Watermarker"
    
    ; ==============================================================================
    ; DATA MODELS
    ; ==============================================================================
    global Layers := []        ; Array of Layer Objects
    global SelectedIndex := 0  ; Currently selected layer index
    global RefFramePath := ""  ; Path to extracted reference frame
    global VideoDims := {w: 1920, h: 1080} ; Source dimensions
    global VideoDur := 0       ; Source duration in seconds
    global SeekPos := 20       ; Current Seek %
    global VideoMeta := {Name: "Unknown", Size: "0 MB", Duration: "00:00:00", Res: "0x0"}
    
    ; GUI Element References
    global LayerListObj := ""   ; The ScrollableList Instance
    global PreviewCtrls := []   ; Array to hold the "Live" AHK controls on the preview
    global HitTargets := []     ; Array of objects defining click areas
    global PropControls := {}   ; Map of property editor controls
    global GrpTitle := ""       ; Reference to the properties title text
    
    ; State Flags
    global SuspendPropUpdates := false 
    global HandCursorHwnds := Map() ; Map of Hwnd -> CursorType ("Hand" or "Move")
    
    ; Layout State
    global PreviewRect := {x:0, y:0, w:0, h:0} 

    global fontOptions
    
    
    ; ==============================================================================
    ; GUI CREATION
    ; ==============================================================================
    myGui := Gui("-Resize -MaximizeBox", AppName)
    myGui.SetFont("s9 c" Theme.Text, "Segoe UI")
    myGui.BackColor := Theme.Bg

    InitWindowUtils(myGui)
    
    ; Setup Safe Closing
    myGui.OnCloseCheck := CleanupAndExit
    myGui.OnEvent("Close", (*) => TryCloseWindow(myGui))
    myGui.OnEvent("DropFiles", HandleDropFiles)
    
    OnMessage(0x20, HandleSetCursor) ; SetCursor

    ; Layout Constants
    GuiWidth  := 1100 
    GuiHeight := 800  
    
    ; --- LEFT PANEL: INPUT & LAYERS ---
    xLeft := 15
    yTop  := 15
    wLeft := 280
    
    ; 1. Input Source
    myGui.SetFont("w600")
    myGui.Add("Text", Format("x{} y{} w200 h20", xLeft, yTop), "1. Input Source")
    myGui.SetFont("w400")
    
    edtInput := AddFlatEdit(myGui, Format("x{} y{} w210 h24 ReadOnly vInputFile", xLeft, yTop+25))
    SexyButton(myGui, xLeft+215, yTop+24, 65, 26, "Browse", SelectInput)
    
    ; 2. Layer Manager
    yLayers := yTop + 75
    myGui.SetFont("w600")
    myGui.Add("Text", Format("x{} y{} w150 h20", xLeft, yLayers), "2. Layers")
    myGui.SetFont("w400")
    
    btnAddText := SexyButton(myGui, xLeft+150, yLayers-2, 60, 24, "+ Text", (*) => AddLayer("Text"))
    btnAddImg  := SexyButton(myGui, xLeft+215, yLayers-2, 65, 24, "+ Image", (*) => AddLayer("Image"))
    
    yList := yLayers + 25
    hList := 590
    
    ; --- SCROLLABLE LIST IMPLEMENTATION ---
    ; Using the Utils class "ScrollableList"
    LayerListObj := ScrollableList(myGui, xLeft, yList, wLeft, hList, 40, RenderLayerRow, SelectLayer)
    
    ; Layer Management Buttons (Below List)
    yLayerBtns := yList + hList + 10
    btnW := (wLeft - 15) / 4
    
    SexyButton(myGui, xLeft, yLayerBtns, btnW, 26, "▲", (*) => MoveLayer(-1))
    SexyButton(myGui, xLeft+btnW+5, yLayerBtns, btnW, 26, "▼", (*) => MoveLayer(1))
    SexyButton(myGui, xLeft+(btnW*2)+10, yLayerBtns, btnW, 26, "Dup", DuplicateLayer)
    SexyButton(myGui, xLeft+(btnW*3)+15, yLayerBtns, btnW, 26, "Del", (*) => DeleteLayer(SelectedIndex)).SetTextColour("FF5555")

    ; --- RIGHT PANEL: PREVIEW & PROPERTIES ---
    xRight := xLeft + wLeft + 20
    wRight := GuiWidth - xRight - 15
    
    ; 3. Live Preview
    myGui.SetFont("w600")
    myGui.Add("Text", Format("x{} y{} w200 h20", xRight, yTop), "3. Live Preview")
    myGui.SetFont("w400")
    
    wPrev := wRight
    hPrev := 340 
    yPrev := yTop + 25
    
    ; Canvas Stage
    picPreviewBg := myGui.Add("Text", Format("x{} y{} w{} h{} Background{}", xRight, yPrev, wPrev, hPrev, "000000"), "")
    picPreviewBg.OnEvent("Click", OnCanvasClick) 
    
    picRef := myGui.Add("Picture", Format("x{} y{} w{} h{} Background000000 -Border vRefFrame", xRight, yPrev, wPrev, hPrev), "")
    picRef.OnEvent("Click", OnCanvasClick) 
    
    txtLoading := myGui.Add("Text", Format("x{} y{} w{} h30 BackgroundTrans Center c888888 +0x200 Hidden", xRight, yPrev + (hPrev/2) - 15, wPrev), "Loading Preview Frame...")
    
    ; Scrubbing
    yTime := yPrev + hPrev + 5
    myGui.Add("Text", Format("x{} y{} w40 h24 +0x200 c888888", xRight, yTime), "Seek:")
    
    sldSeek := myGui.Add("Slider", Format("x{} y{} w{} h24 vSeekPos Range0-100 ToolTip", xRight+45, yTime, wPrev-160), 20)
    sldSeek.OnEvent("Change", OnSeekChange)
    
    txtTimeCode := myGui.Add("Text", Format("x{} y{} w110 h24 +0x200 Right c888888", xRight+wPrev-110, yTime), "0% (0s)")
    
    ; 4. Properties Panel
    yProp := yTime + 35
    hProp := 282
    
    ; GroupBox Border
    borderCol := Theme.Border
    myGui.Add("Text", Format("x{} y{} w{} h1 Background{}", xRight, yProp+10, wPrev, borderCol), "") ; Top
    myGui.Add("Text", Format("x{} y{} w{} h1 Background{}", xRight, yProp+hProp, wPrev, borderCol), "") ; Bottom
    myGui.Add("Text", Format("x{} y{} w1 h{} Background{}", xRight, yProp+10, hProp-10, borderCol), "") ; Left
    myGui.Add("Text", Format("x{} y{} w1 h{} Background{}", xRight+wPrev-1, yProp+10, hProp-10, borderCol), "") ; Right
    
    myGui.Add("Text", Format("x{} y{} w20 h20 Background{}", xRight+10, yProp, Theme.Bg), "") 
    GrpTitle := myGui.Add("Text", Format("x{} y{} w150 h20 c{} Background{}", xRight+15, yProp, Theme.Accent, Theme.Bg), "Properties")
    
    ; --- Controls Container ---
    yP := yProp + 30
    xP := xRight + 20
    wCol := (wPrev - 60) / 2
    xCol2 := xP + wCol + 20
    
    ; === CONTENT SECTION ===
    myGui.SetFont("s9 w600 c" Theme.Accent)
    myGui.Add("Text", Format("x{} y{} w{} h20", xP, yP, wPrev-50), "Content Configuration")
    myGui.SetFont("s9 w400 c" Theme.Text)
    yP += 25
    
    ; Row 1: Content Input
    lblContent := myGui.Add("Text", Format("x{} y{} w50 h24 +0x200", xP, yP), "Value:")
    
    ; Text input is wider
    edtContent := AddFlatEdit(myGui, Format("x{} y{} w{} h24 vPropContent", xP+55, yP, wPrev - 200))
    edtContent.OnEvent("Change", UpdateActiveLayer)
    
    ; Browse button (for Image)
    btnContentBrowse := SexyButton(myGui, xRight+wPrev-115, yP-1, 80, 26, "Pick File", PickLayerFile)
    
    ; Variables Menu (for Text)
    btnVars := SexyButton(myGui, xRight+wPrev-115, yP-1, 80, 26, "Vars ▼", ShowVarsMenu)
    
    PropControls.ContentLabel := lblContent
    PropControls.Content := edtContent
    PropControls.ContentBrowse := btnContentBrowse
    PropControls.VarsBtn := btnVars
    
    yP += 35
    
    ; === 2-COLUMN LAYOUT START ===
    yStartCols := yP
    
    ; --- COLUMN 1: APPEARANCE ---
    myGui.SetFont("s9 w600 c" Theme.Accent)
    myGui.Add("Text", Format("x{} y{} w{} h20", xP, yP, wCol), "Appearance")
    myGui.SetFont("s9 w400 c" Theme.Text)
    yP += 25
    
    ; Font
    lblFont := myGui.Add("Text", Format("x{} y{} w40 h24 +0x200", xP, yP), "Font:")
    ddlFont := DarkDropdown(myGui, xP+45, yP, wCol-50, fontOptions, "PropFont", UpdateActiveLayer)
    PropControls.FontLabel := lblFont
    PropControls.Font := ddlFont
    yP += 32
    
    ; Size & Opacity
    lblSize := myGui.Add("Text", Format("x{} y{} w40 h24 +0x200", xP, yP), "Size:")
    sldSize := myGui.Add("Slider", Format("x{} y{} w{} h24 vPropSize Range1-200 ToolTip", xP+45, yP, wCol-50), 20)
    sldSize.OnEvent("Change", UpdateActiveLayer)
    PropControls.SizeLabel := lblSize
    PropControls.Size := sldSize
    yP += 32
    
    myGui.Add("Text", Format("x{} y{} w45 h24 +0x200", xP, yP), "Alpha:")
    sldOp := myGui.Add("Slider", Format("x{} y{} w{} h24 vPropOpacity Range0-100 ToolTip", xP+45, yP, wCol-50), 100)
    sldOp.OnEvent("Change", UpdateActiveLayer)
    PropControls.Opacity := sldOp
    yP += 32
    
    ; Colors (Text Only)
    lblColor := myGui.Add("Text", Format("x{} y{} w40 h24 +0x200", xP, yP), "Color:")
    edtColor := AddFlatEdit(myGui, Format("x{} y{} w70 h24 vPropColor ReadOnly", xP+45, yP))
    btnColor := SexyButton(myGui, xP+120, yP-1, 50, 26, "Pick", PickLayerColor)
    
    PropControls.ColorLabel := lblColor
    PropControls.Color := edtColor
    PropControls.ColorBtn := btnColor
    yP += 35
    
    ; Background Box (Text Only)
    chkBg := myGui.Add("Checkbox", Format("x{} y{} w120 h24 vPropHasBg", xP, yP), "Backdrop Box")
    chkBg.OnEvent("Click", UpdateActiveLayer)
    SetDarkControl(chkBg)
    
    edtBgColor := AddFlatEdit(myGui, Format("x{} y{} w60 h24 vPropBgColor ReadOnly", xP+125, yP))
    btnBgColor := SexyButton(myGui, xP+190, yP-1, 40, 26, "Set", PickLayerBgColor)
    
    lblBgOp := myGui.Add("Text", Format("x{} y{} w30 h24 +0x200", xP+235, yP), "Op:")
    edtBgOp := AddFlatEdit(myGui, Format("x{} y{} w30 h24 vPropBgOpacity", xP+265, yP))
    edtBgOp.OnEvent("Change", UpdateActiveLayer)

    PropControls.HasBg := chkBg
    PropControls.BgColor := edtBgColor
    PropControls.BgColorBtn := btnBgColor
    PropControls.BgOpLabel := lblBgOp
    PropControls.BgOpacity := edtBgOp
    
    
    ; --- COLUMN 2: POSITION & TIMING ---
    yP := yStartCols
    xP := xCol2
    
    myGui.SetFont("s9 w600 c" Theme.Accent)
    myGui.Add("Text", Format("x{} y{} w{} h20", xP, yP, wCol), "Position && Timing")
    myGui.SetFont("s9 w400 c" Theme.Text)
    yP += 25
    
    ; Position Sliders
    myGui.Add("Text", Format("x{} y{} w40 h24 +0x200", xP, yP), "Pos X:")
    sldX := myGui.Add("Slider", Format("x{} y{} w{} h24 vPropX Range0-100 ToolTip", xP+45, yP, wCol-50), 50)
    sldX.OnEvent("Change", UpdateActiveLayer)
    PropControls.X := sldX
    yP += 32
    
    myGui.Add("Text", Format("x{} y{} w40 h24 +0x200", xP, yP), "Pos Y:")
    sldY := myGui.Add("Slider", Format("x{} y{} w{} h24 vPropY Range0-100 ToolTip", xP+45, yP, wCol-50), 50)
    sldY.OnEvent("Change", UpdateActiveLayer)
    PropControls.Y := sldY
    yP += 32
    
    ; Timing Start/End
    myGui.Add("Text", Format("x{} y{} w40 h24 +0x200", xP, yP), "Show:")
    edtStart := AddFlatEdit(myGui, Format("x{} y{} w60 h24 vPropStart", xP+45, yP)) 
    edtStart.OnEvent("Change", UpdateActiveLayer)
    
    myGui.Add("Text", Format("x{} y{} w20 h24 +0x200 Center", xP+110, yP), "to")
    edtEnd := AddFlatEdit(myGui, Format("x{} y{} w60 h24 vPropEnd", xP+135, yP))
    edtEnd.OnEvent("Change", UpdateActiveLayer)
    
    myGui.Add("Text", Format("x{} y{} w30 h24 +0x200", xP+200, yP), "sec")

    PropControls.Start := edtStart
    PropControls.End := edtEnd
    yP += 32
    
    ; Fades
    myGui.Add("Text", Format("x{} y{} w40 h24 +0x200", xP, yP), "Fade:")
    
    myGui.Add("Text", Format("x{} y{} w20 h24 +0x200 c888888", xP+45, yP), "In:")
    edtFadeIn := AddFlatEdit(myGui, Format("x{} y{} w40 h24 vPropFadeIn", xP+65, yP))
    edtFadeIn.OnEvent("Change", UpdateActiveLayer)

    myGui.Add("Text", Format("x{} y{} w25 h24 +0x200 c888888", xP+115, yP), "Out:")
    edtFadeOut := AddFlatEdit(myGui, Format("x{} y{} w40 h24 vPropFadeOut", xP+140, yP))
    edtFadeOut.OnEvent("Change", UpdateActiveLayer)
    
    PropControls.FadeIn := edtFadeIn
    PropControls.FadeOut := edtFadeOut
    
    
    ; --- FOOTER ---
    yF := GuiHeight - 50
    myGui.Add("Text", Format("x0 y{} w{} h50 Background{}", yF, GuiWidth, Theme.DarkPanel), "")
    
    SexyButton(myGui, 10, yF+10, 80, 30, "Save Preset", SavePreset)
    SexyButton(myGui, 100, yF+10, 80, 30, "Load Preset", LoadPreset)
    
    SexyButton(myGui, GuiWidth-270, yF+10, 120, 30, "Preview (3s)", PreviewRender)
    SexyButton(myGui, GuiWidth-140, yF+10, 120, 30, "Render Video", StartRender)
    
    sb := myGui.Add("Text", Format("x200 y{} w{} h50 BackgroundTrans c888888 +0x200", yF, 400), "Ready.")

    myGui.Show(Format("w{} h{}", GuiWidth, GuiHeight))
    
    UpdatePropPanel()
    
    ; ==============================================================================
    ; SCROLLABLE LIST ROW RENDERER
    ; ==============================================================================
    RenderLayerRow(guiObj, index, item, isSelected, y, w, h, existingCtrls) {
        bgColor := isSelected ? Theme.Accent : Theme.Button
        txtColor := isSelected ? Theme.Panel : Theme.Text
        
        ; Create Controls if they don't exist
        if (!existingCtrls) {
            ctrls := Map()
            
            ; Background
            bg := guiObj.Add("Text", Format("x{} y{} w{} h{} Background{}", 5, y, w, h, bgColor), "")
            ctrls["bg"] := bg
            
            ; Icon
            icon := (item.Type == "Text") ? "T" : "I"
            t1 := guiObj.Add("Text", Format("x{} y{} w30 h{} BackgroundTrans c{} +0x200 Center", 5, y, h, txtColor), icon)
            t1.SetFont("w600")
            ctrls["icon"] := t1
            
            ; Label
            t2 := guiObj.Add("Text", Format("x{} y{} w{} h{} BackgroundTrans c{} +0x200", 40, y, w-40, h, txtColor), "")
            t2.SetFont("w600")
            ctrls["label"] := t2
            
            ; Setup Cursor Handling for these controls
            HandCursorHwnds[bg.Hwnd] := "Hand"
            HandCursorHwnds[t1.Hwnd] := "Hand"
            HandCursorHwnds[t2.Hwnd] := "Hand"
            
            existingCtrls := ctrls
        } 
        
        ; Update Properties
        dispText := (item.Content == "") ? "(Empty)" : item.Content
        if StrLen(dispText) > 28
            dispText := SubStr(dispText, 1, 25) "..."
            
        ; Background
        existingCtrls["bg"].Move(5, y, w, h)
        existingCtrls["bg"].Opt("Background" bgColor)
        existingCtrls["bg"].Visible := true
        
        ; Icon
        existingCtrls["icon"].Move(5, y, 30, h)
        existingCtrls["icon"].Opt("c" txtColor)
        existingCtrls["icon"].Visible := true
        
        ; Label
        existingCtrls["label"].Move(40, y, w-40, h)
        existingCtrls["label"].Value := "  " dispText
        existingCtrls["label"].Opt("c" txtColor)
        existingCtrls["label"].Visible := true
        
        return existingCtrls
    }

    ; ==============================================================================
    ; ROBUST DRAGGING (ANTI-GHOSTING)
    ; ==============================================================================
    
    OnCanvasClick(ctrl, *) {
        CoordMode "Mouse", "Client"
        MouseGetPos(&mX, &mY)
        
        foundIdx := 0
        foundCtrl := ""
        foundDims := {}
        
        Loop HitTargets.Length {
            i := HitTargets.Length - A_Index + 1
            t := HitTargets[i]
            if (mX >= t.x && mX <= (t.x + t.w) && mY >= t.y && mY <= (t.y + t.h)) {
                foundIdx := t.idx
                foundCtrl := t.ctrl
                foundDims := {w: t.w, h: t.h}
                break
            }
        }
        
        if (foundIdx > 0 && foundCtrl) {
            OnLayerDrag(foundCtrl, foundIdx, foundDims)
        }
    }

    OnLayerDrag(ctrl, idx, dims) {
        SelectLayer(idx)

        CoordMode "Mouse", "Client"
        MouseGetPos(&startX, &startY)
        ctrl.GetPos(&startPxX, &startPxY)
        
        if (PreviewRect.w <= 0)
            return
            
        layer := Layers[idx]
        trackW := PreviewRect.w - dims.w + 10
        trackH := PreviewRect.h - dims.h + 5
        if (trackW <= 0) 
            trackW := 1
        if (trackH <= 0) 
            trackH := 1

        RECT := Buffer(16, 0)
        NumPut("Int", PreviewRect.x, RECT, 0)
        NumPut("Int", PreviewRect.y, RECT, 4)
        NumPut("Int", PreviewRect.x + PreviewRect.w, RECT, 8)
        NumPut("Int", PreviewRect.y + PreviewRect.h, RECT, 12)

        while GetKeyState("LButton", "P") {
            MouseGetPos(&currX, &currY)
            deltaX := currX - startX
            deltaY := currY - startY
            
            if (deltaX == 0 && deltaY == 0) {
                Sleep(10)
                continue
            }
            
            newPxX := Max(PreviewRect.x, Min(PreviewRect.x + trackW, startPxX + deltaX))
            newPxY := Max(PreviewRect.y, Min(PreviewRect.y + trackH, startPxY + deltaY))
            
            newPctX := ((newPxX - PreviewRect.x) / trackW) * 100
            newPctY := ((newPxY - PreviewRect.y) / trackH) * 100
            
            layer.X := newPctX
            layer.Y := newPctY
            
            SuspendPropUpdates := true
            PropControls.X.Value := newPctX
            PropControls.Y.Value := newPctY
            SuspendPropUpdates := false
            
            ; 1. Move the control
            try ctrl.Move(newPxX, newPxY)
            
            ; 2. Invalidate rect to prevent ghosting
            DllCall("User32\InvalidateRect", "Ptr", myGui.Hwnd, "Ptr", RECT.Ptr, "Int", 1)
            
            Sleep(15) 
        }
        
        ; Refresh after drag to ensure clean state
        RefreshLivePreview()
    }
    
    HandleSetCursor(wParam, lParam, msg, hwnd) {
        if (HandCursorHwnds.Has(hwnd)) {
             type := HandCursorHwnds[hwnd]
             cursorId := (type == "Move") ? 32646 : 32649 ; 32646 = SizeAll (Move), 32649 = Hand
             DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", cursorId, "Ptr")) 
             return true
        }
        
        ; Allow ScrollableList to handle its own cursors inside (via MouseMove usually or default arrow)
        
        ; FIX: Wrap Hwnd access in try-catch to prevent "Gui has no window" error during close
        try {
            if (winId := 0, MouseGetPos(,, &winId), winId == myGui.Hwnd && HitTargets.Length > 0) {
                CoordMode "Mouse", "Client"
                MouseGetPos(&mX, &mY)
                
                if (mX >= PreviewRect.x && mX <= (PreviewRect.x + PreviewRect.w) && mY >= PreviewRect.y && mY <= (PreviewRect.y + PreviewRect.h)) {
                    Loop HitTargets.Length {
                        i := HitTargets.Length - A_Index + 1
                        t := HitTargets[i]
                        if (mX >= t.x && mX <= (t.x + t.w) && mY >= t.y && mY <= (t.y + t.h)) {
                            DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32646, "Ptr")) ; SizeAll
                            return true
                        }
                    }
                }
            }
        } catch {
            ; Window likely destroyed
        }
        return false
    }

    ; ==============================================================================
    ; LAYER MANAGEMENT
    ; ==============================================================================
    
    AddLayer(type) {
        newLayer := {}
        newLayer.Type := type
        newLayer.X := 50
        newLayer.Y := 50
        newLayer.Opacity := 100
        newLayer.Visible := true
        newLayer.BlendMode := "Normal"
        newLayer.StartTime := 0
        newLayer.EndTime := (VideoDur > 0) ? VideoDur : 9999
        newLayer.FadeIn := 0
        newLayer.FadeOut := 0
        
        if (type == "Text") {
            newLayer.Content := "Watermark"
            newLayer.Color := "FFFFFF"
            newLayer.Size := 40 
            newLayer.Font := "Arial"
            newLayer.HasBg := false
            newLayer.BgColor := "000000"
            newLayer.BgOpacity := 50
        } else {
            newLayer.Content := ""
            newLayer.Size := 100
        }
        
        Layers.Push(newLayer)
        SelectedIndex := Layers.Length
        
        LayerListObj.SetItems(Layers)
        LayerListObj.Select(SelectedIndex)
        LayerListObj.EnsureVisible(SelectedIndex)
        
        UpdatePropPanel()
        RefreshLivePreview()
        
        ; Focus trap is inside list, call its method if exposed or rely on click
        ; LayerListObj.FocusTrap.Focus() handled in class on click
    }
    
    DeleteLayer(index) {
        if (index > 0 && index <= Layers.Length) {
            Layers.RemoveAt(index)
            if (SelectedIndex >= index)
                SelectedIndex := Max(1, SelectedIndex - 1)
            if (Layers.Length == 0)
                SelectedIndex := 0
            
            LayerListObj.SetItems(Layers)
            LayerListObj.Select(SelectedIndex)
            
            UpdatePropPanel()
            RefreshLivePreview()
        }
    }
    
    DuplicateLayer(*) {
        if (SelectedIndex == 0)
            return
        
        orig := Layers[SelectedIndex]
        clone := {}
        
        ; Shallow copy props
        for k, v in orig.OwnProps()
            clone.%k% := v
            
        ; Offset position slightly so user sees it
        clone.X := Min(100, clone.X + 2)
        clone.Y := Min(100, clone.Y + 2)
        
        Layers.InsertAt(SelectedIndex + 1, clone)
        SelectedIndex += 1
        
        LayerListObj.SetItems(Layers)
        LayerListObj.Select(SelectedIndex)
        LayerListObj.EnsureVisible(SelectedIndex)
        
        UpdatePropPanel()
        RefreshLivePreview()
    }
    
    MoveLayer(dir) {
        if (SelectedIndex == 0)
            return
        newIdx := SelectedIndex + dir
        if (newIdx < 1 || newIdx > Layers.Length)
            return
            
        ; Swap
        tmp := Layers[SelectedIndex]
        Layers[SelectedIndex] := Layers[newIdx]
        Layers[newIdx] := tmp
        
        SelectedIndex := newIdx
        
        LayerListObj.SetItems(Layers)
        LayerListObj.Select(SelectedIndex)
        LayerListObj.EnsureVisible(SelectedIndex)
        
        RefreshLivePreview()
    }
    
    SelectLayer(index) {
        global SelectedIndex
        SelectedIndex := index
        UpdatePropPanel()
    }

    UpdatePropPanel() {
        SuspendPropUpdates := true 
        
        SetVis(c, show) {
            if (c == "")
				return
            try {
                if HasProp(c, "SetVisible") 
                    c.SetVisible(show)
                else 
                    c.Visible := show
            }
        }
        
        for k, c in PropControls.OwnProps() {
            SetVis(c, false)
        }
        
        if (SelectedIndex == 0) {
            GrpTitle.Text := "Properties (No Selection)"
            SuspendPropUpdates := false 
            return
        }
        
        layer := Layers[SelectedIndex]
        GrpTitle.Text := "Properties: " layer.Type " Layer " SelectedIndex
        
        SetVis(PropControls.ContentLabel, true)
        SetVis(PropControls.Content, true)
        if (myGui.FocusedCtrl != PropControls.Content)
             PropControls.Content.Value := layer.Content
             
        SetVis(PropControls.X, true)
        PropControls.X.Value := layer.X
        SetVis(PropControls.Y, true)
        PropControls.Y.Value := layer.Y
        SetVis(PropControls.SizeLabel, true)
        SetVis(PropControls.Size, true)
        PropControls.Size.Value := layer.Size
        SetVis(PropControls.Opacity, true)
        PropControls.Opacity.Value := layer.Opacity
        
        SetVis(PropControls.Start, true)
        if (myGui.FocusedCtrl != PropControls.Start)
            PropControls.Start.Value := layer.HasProp("StartTime") ? layer.StartTime : 0
            
        SetVis(PropControls.End, true)
        if (myGui.FocusedCtrl != PropControls.End)
            PropControls.End.Value := layer.HasProp("EndTime") ? layer.EndTime : VideoDur

        SetVis(PropControls.FadeIn, true)
        if (myGui.FocusedCtrl != PropControls.FadeIn)
            PropControls.FadeIn.Value := layer.HasProp("FadeIn") ? layer.FadeIn : 0
            
        SetVis(PropControls.FadeOut, true)
        if (myGui.FocusedCtrl != PropControls.FadeOut)
            PropControls.FadeOut.Value := layer.HasProp("FadeOut") ? layer.FadeOut : 0

        if (layer.Type == "Image") {
            SetVis(PropControls.ContentBrowse, true)
            PropControls.ContentLabel.Text := "File:"
            PropControls.SizeLabel.Text := "Scale %:"
        } else {
            SetVis(PropControls.VarsBtn, true)
            PropControls.ContentLabel.Text := "Text:"
            PropControls.SizeLabel.Text := "Font Size:"
            
            SetVis(PropControls.ColorLabel, true)
            SetVis(PropControls.Color, true)
            PropControls.Color.Value := layer.Color
            SetVis(PropControls.ColorBtn, true)
            SetVis(PropControls.FontLabel, true)
            SetVis(PropControls.Font, true)
            PropControls.Font.Text := layer.Font

            SetVis(PropControls.HasBg, true)
            PropControls.HasBg.Value := layer.HasProp("HasBg") ? layer.HasBg : 0
            
            if (layer.HasProp("HasBg") && layer.HasBg) {
                SetVis(PropControls.BgColor, true)
                PropControls.BgColor.Value := layer.HasProp("BgColor") ? layer.BgColor : "000000"
                SetVis(PropControls.BgColorBtn, true)
                SetVis(PropControls.BgOpLabel, true)
                SetVis(PropControls.BgOpacity, true)
                PropControls.BgOpacity.Value := layer.HasProp("BgOpacity") ? layer.BgOpacity : 50
            }
        }
        
        SuspendPropUpdates := false
    }
    
    UpdateActiveLayer(ctrlObj := "", *) {
        if (SelectedIndex == 0 || SuspendPropUpdates)
            return
            
        layer := Layers[SelectedIndex]
        
        ; Sanitize & Update
        layer.Content := PropControls.Content.Value
        layer.X := PropControls.X.Value
        layer.Y := PropControls.Y.Value
        layer.Size := PropControls.Size.Value
        layer.Opacity := PropControls.Opacity.Value
        
        ; Numeric sanitization
        layer.StartTime := IsNumber(PropControls.Start.Value) ? Float(PropControls.Start.Value) : 0
        layer.EndTime := IsNumber(PropControls.End.Value) ? Float(PropControls.End.Value) : VideoDur
        layer.FadeIn := IsNumber(PropControls.FadeIn.Value) ? Float(PropControls.FadeIn.Value) : 0
        layer.FadeOut := IsNumber(PropControls.FadeOut.Value) ? Float(PropControls.FadeOut.Value) : 0

        if (layer.Type == "Text") {
            layer.Font := PropControls.Font.Text
            layer.HasBg := PropControls.HasBg.Value
            layer.BgColor := PropControls.BgColor.Value
            layer.BgOpacity := IsNumber(PropControls.BgOpacity.Value) ? Integer(PropControls.BgOpacity.Value) : 50
        }
        
        if (IsObject(ctrlObj) && ctrlObj.Name == "PropHasBg") {
            UpdatePropPanel()
        }
        
        ; Update list visual if content changed
        if (ctrlObj == PropControls.Content) {
            ; Update specific row text in list
            LayerListObj.RefreshRow(SelectedIndex)
        }
        
        SetTimer(RefreshLivePreview, -100)
    }
    
    PickLayerFile(*) {
        if (SelectedIndex == 0)
            return
        path := FileSelect(1, , "Select Overlay Image", "Images (*.png; *.jpg; *.jpeg; *.bmp; *.gif)")
        if path {
            PropControls.Content.Value := path
            UpdateActiveLayer({Name: ""})
        }
    }
    
    PickLayerColor(*) {
        if (SelectedIndex == 0)
            return
        RunColorPicker(PropControls.Color, myGui.Hwnd)
        Layers[SelectedIndex].Color := PropControls.Color.Value
        RefreshLivePreview()
    }

    PickLayerBgColor(*) {
        if (SelectedIndex == 0)
            return
        RunColorPicker(PropControls.BgColor, myGui.Hwnd)
        Layers[SelectedIndex].BgColor := PropControls.BgColor.Value
        RefreshLivePreview()
    }
    
    ShowVarsMenu(*) {
        m := Menu()
        m.Add("File Name (%name%)", (*) => InsertVar("%name%"))
        m.Add("File Size (%size%)", (*) => InsertVar("%size%"))
        m.Add("Resolution (%res%)", (*) => InsertVar("%res%"))
        m.Add("Timecode (%time%)", (*) => InsertVar("%time%"))
        m.Add("Frame Number (%frame%)", (*) => InsertVar("%frame%"))
        m.Show()
    }
    
    InsertVar(varTxt) {
        if (SelectedIndex == 0)
            return
        EditPaste(varTxt, PropControls.Content.Hwnd)
        UpdateActiveLayer({Name:""})
    }

    ; ==============================================================================
    ; LOGIC & RENDERING
    ; ==============================================================================
    
    SelectInput(*) {
        path := FileSelect(1, , "Select Input Video", "Video (*.mp4; *.mkv; *.webm; *.avi; *.mov; *.jpg; *.png)")
        if path 
            LoadSource(path)
    }

    HandleDropFiles(guiObj, ctrlObj, fileArray, x, y) {
        if (fileArray.Length > 0)
            LoadSource(fileArray[1])
    }
    
    LoadSource(path) {
        edtInput.Value := path
        
        VideoDims := GetVideoDimensions(path)
        VideoDur := GetVideoDuration(path)
        
        SplitPath(path, , , , &nameNoExt)
        try sizeMB := Format("{:.2f} MB", FileGetSize(path)/1024/1024)
        catch 
            sizeMB := "0 MB"
            
        VideoMeta := {Name: nameNoExt, Size: sizeMB, Res: VideoDims.w "x" VideoDims.h, Duration: FormatSeconds(VideoDur)}
        
        SeekPos := 20
        sldSeek.Value := 20
        txtTimeCode.Text := Format("20% ({:.1f}s)", VideoDur * 0.2)
        
        ExtractFrame()
    }
    
    OnSeekChange(*) {
        SetTimer(DoSeek, -300) 
    }
    
    DoSeek() {
        SeekPos := sldSeek.Value
        dur := (VideoDur > 0 ? VideoDur : 600)
        time := dur * (SeekPos / 100)
        txtTimeCode.Text := Format("{}% ({:.1f}s)", SeekPos, time)
        ExtractFrame()
    }
    
    ExtractFrame() {
        if (edtInput.Value == "")
            return
            
        txtLoading.Visible := true
        sb.Text := " Extracting Preview Frame..."
        
        dur := (VideoDur > 0) ? VideoDur : 600
        seekSec := dur * (SeekPos / 100)
        
        RefFramePath := A_Temp "\watermark_ref_" A_TickCount ".jpg"
        
        cmd := ["-ss", Format("{:.2f}", seekSec), "-i", Format('"{1}"', edtInput.Value)]
        
        try {
            Sleep(10) 
            FFWrapper.GeneratePreview(cmd, RefFramePath)
            if FileExist(RefFramePath) {
                VideoDims := GetImageDimensions(RefFramePath)
            }
        } 
        
        txtLoading.Visible := false
        sb.Text := " Ready."
        UpdatePreviewImage()
        RefreshLivePreview()
    }
    
    GetImageDimensions(imgPath) {
        g := Gui()
        p := g.Add("Picture", "Hidden", imgPath)
        p.GetPos(,, &w, &h)
        g.Destroy()
        return {w: w, h: h}
    }
    
    UpdatePreviewImage() {
        if !FileExist(RefFramePath) {
            picRef.Visible := false
            return
        }
        
        canvasW := 605 
        canvasH := 340 
        
        ratioVid := VideoDims.w / VideoDims.h
        ratioCanvas := canvasW / canvasH
        
        renderW := 0, renderH := 0
        if (ratioVid > ratioCanvas) {
            renderW := canvasW
            renderH := canvasW / ratioVid
        } else {
            renderH := canvasH
            renderW := canvasH * ratioVid
        }
        
        finalX := xRight + (canvasW - renderW) / 2
        finalY := yPrev + (canvasH - renderH) / 2
        
        PreviewRect := {x: finalX, y: finalY, w: renderW, h: renderH}
        
        picRef.Visible := true
        picRef.Move(finalX, finalY, renderW, renderH)
        picRef.Value := RefFramePath
    }
    
    RefreshLivePreview() {
        for ctrl in PreviewCtrls {
            try {
                if (HandCursorHwnds.Has(ctrl.Hwnd))
                    HandCursorHwnds.Delete(ctrl.Hwnd)
                ctrl.Visible := false 
                DllCall("DestroyWindow", "Ptr", ctrl.Hwnd)
            }
        }
        PreviewCtrls := []
        HitTargets := []
        
        if (picRef.Visible) {
             DllCall("RedrawWindow", "Ptr", picRef.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0105)
        } else {
             DllCall("RedrawWindow", "Ptr", picPreviewBg.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0105)
        }
        
        if (PreviewRect.w == 0)
            return
            
        scale := PreviewRect.w / VideoDims.w
        
        dur := (VideoDur > 0) ? VideoDur : 600
        currTime := dur * (SeekPos / 100)
        
        Loop Layers.Length {
            i := A_Index
            layer := Layers[i]
            if (!layer.Visible)
                continue
            
            startTime := layer.HasProp("StartTime") ? layer.StartTime : 0
            endTime := layer.HasProp("EndTime") ? layer.EndTime : 99999
            
            if (currTime < startTime || currTime > endTime)
                continue 
                
            fadeIn := layer.HasProp("FadeIn") ? layer.FadeIn : 0
            fadeOut := layer.HasProp("FadeOut") ? layer.FadeOut : 0
            
            alphaFactor := 1.0
            if (fadeIn > 0 && currTime < startTime + fadeIn) {
                alphaFactor := (currTime - startTime) / fadeIn
            } else if (fadeOut > 0 && currTime > endTime - fadeOut) {
                alphaFactor := (endTime - currTime) / fadeOut
            }
            alphaFactor := Max(0, Min(1, alphaFactor))
            
            baseOp := layer.Opacity / 100.0
            finalOpVal := Integer(255 * baseOp * alphaFactor)
            
            if (layer.Type == "Text") {
                scaledPx := layer.Size * scale
                ahkPt := Integer(Max(6, scaledPx * 0.75))
                
                fontOpts := Format("s{} c{}", ahkPt, layer.Color)
                fontName := layer.Font ? layer.Font : "Arial"
                myGui.SetFont(fontOpts, fontName)
                
                ; Variable Resolution for Preview
                dispText := layer.Content
                dispText := StrReplace(dispText, "%name%", VideoMeta.Name)
                dispText := StrReplace(dispText, "%size%", VideoMeta.Size)
                dispText := StrReplace(dispText, "%res%", VideoMeta.Res)
                dispText := StrReplace(dispText, "%time%", FormatSeconds(currTime))
                dispText := StrReplace(dispText, "%frame%", "000")
                
                measureCtl := myGui.Add("Text", "x-2000 y-2000", dispText)
                measureCtl.GetPos(,, &txtW, &txtH)
                DllCall("DestroyWindow", "Ptr", measureCtl.Hwnd)
                
                pad := 5
                finalW := txtW + (pad*2)
                finalH := txtH + (pad*2)
                
                availW := PreviewRect.w - finalW
                availH := PreviewRect.h - finalH
                posX := PreviewRect.x + (availW * (layer.X / 100))
                posY := PreviewRect.y + (availH * (layer.Y / 100))
                
                HitTargets.Push({idx: i, x: posX, y: posY, w: finalW, h: finalH, ctrl: ""})
                
                if (layer.HasProp("HasBg") && layer.HasBg) {
                    bgHex := (layer.HasProp("BgColor") && layer.BgColor != "") ? layer.BgColor : "000000"
                    bgOp := layer.HasProp("BgOpacity") ? layer.BgOpacity : 50
                    bgCtl := myGui.Add("Text", Format("x{} y{} w{} h{} Background{} +E0x20", posX, posY, finalW, finalH, bgHex), "")
                    
                    finalBgOp := Integer(255 * (bgOp/100.0) * alphaFactor)
                    try WinSetTransparent(finalBgOp, bgCtl.Hwnd)
                    
                    PreviewCtrls.Push(bgCtl)
                    HandCursorHwnds[bgCtl.Hwnd] := "Move"
                    if (HitTargets[HitTargets.Length].ctrl == "")
                        HitTargets[HitTargets.Length].ctrl := bgCtl
                }
                
                ctl := myGui.Add("Text", Format("x{} y{} w{} h{} BackgroundFF00FF", posX+pad, posY+pad, txtW, txtH), dispText) 
                
                try WinSetTransparent(finalOpVal, ctl.Hwnd)
                DllCall("SetWindowPos", "Ptr", ctl.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x3)
                
                PreviewCtrls.Push(ctl)
                HandCursorHwnds[ctl.Hwnd] := "Move"
                
                if (HitTargets[HitTargets.Length].ctrl == "")
                     HitTargets[HitTargets.Length].ctrl := ctl
                else 
                     HitTargets[HitTargets.Length].ctrl := ctl 
                
                myGui.SetFont("s9 c" Theme.Text, "Segoe UI")
                
            } else if (layer.Type == "Image") {
                if FileExist(layer.Content) {
                    try {
                        ctl := myGui.Add("Picture", Format("x-2000 y-2000 BackgroundFF00FF +E0x20"), layer.Content)
                        ctl.GetPos(,, &imgW, &imgH)
                        
                        scaleFactor := (layer.Size / 100) * scale
                        newW := imgW * scaleFactor
                        newH := imgH * scaleFactor
                        
                        availW := PreviewRect.w - newW
                        availH := PreviewRect.h - newH
                        posX := PreviewRect.x + (availW * (layer.X / 100))
                        posY := PreviewRect.y + (availH * (layer.Y / 100))
                        
                        ctl.Move(posX, posY, newW, newH)
                        
                        try WinSetTransparent(finalOpVal, ctl.Hwnd)
                        
                        HitTargets.Push({idx: i, x: posX, y: posY, w: newW, h: newH, ctrl: ctl})
                        PreviewCtrls.Push(ctl)
                        HandCursorHwnds[ctl.Hwnd] := "Move"
                    }
                }
            }
        }
        if (txtLoading.Visible)
            txtLoading.Redraw()
    }
    
    GetVideoDimensions(path) {
        tempLog := A_Temp "\dims.txt"
        probe := FindFFprobe()
        
        cmd := Format('"{1}" -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "{2}" > "{3}"', probe, path, tempLog)
        RunWait(A_ComSpec " /c " cmd, , "Hide")
        w := 1920, h := 1080
        if FileExist(tempLog) {
            str := FileRead(tempLog)
            FileDelete(tempLog)
            if RegExMatch(str, "(\d+)x(\d+)", &m) {
                w := Integer(m[1])
                h := Integer(m[2])
            }
        }
        
        tempLogRot := A_Temp "\rot.txt"
        cmdRot := Format('"{1}" -v error -select_streams v:0 -show_entries stream_tags=rotate -of default=noprint_wrappers=1:nokey=1 "{2}" > "{3}"', probe, path, tempLogRot)
        try RunWait(A_ComSpec " /c " cmdRot, , "Hide")
        
        if FileExist(tempLogRot) {
            rotStr := FileRead(tempLogRot)
            try FileDelete(tempLogRot)
            if IsNumber(Trim(rotStr)) {
                r := Abs(Integer(Trim(rotStr)))
                if (r == 90 || r == 270) {
                    tmp := w
                    w := h
                    h := tmp
                }
            }
        }
        return {w: w, h: h}
    }
    
    GetVideoDuration(path) {
        if !FileExist(path)
            return 3600

        ffprobeCmd := "ffprobe"
        if InStr(FFWrapper.ffmpegPath, "\") {
            SplitPath(FFWrapper.ffmpegPath, , &dir)
            if FileExist(dir "\ffprobe.exe")
                ffprobeCmd := Format('"{1}"', dir "\ffprobe.exe")
        }
        
        probeOut := A_Temp "\dur_out_" A_TickCount ".txt"
        safeProbe := StrReplace(ffprobeCmd, '"', '')
        safeFile := StrReplace(path, '"', '')
        
        cmd := Format('{1} /s /c " "{2}" -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "{3}" > "{4}" "', A_ComSpec, safeProbe, safeFile, probeOut)
        try RunWait(cmd, , "Hide")
        
        dur := 0
        if FileExist(probeOut) {
            val := FileRead(probeOut)
            try FileDelete(probeOut)
            if IsNumber(Trim(val))
                dur := Float(Trim(val))
        }
        
        if (dur <= 0) {
             ff := FFWrapper.ffmpegPath
             logFile := A_Temp "\dur_fallback_" A_TickCount ".txt"
             try FileDelete(logFile)
             safeFF := StrReplace(ff, '"', '')
             cmd2 := Format('{1} /s /c " "{2}" -hide_banner -i "{3}" 2> "{4}" "', A_ComSpec, safeFF, safeFile, logFile)
             try RunWait(cmd2, , "Hide")
             if FileExist(logFile) {
                content := FileRead(logFile)
                FileDelete(logFile)
                if RegExMatch(content, "Duration:\s+(\d+):(\d+):(\d+(?:\.\d+)?)", &m) {
                    dur := (m[1]*3600) + (m[2]*60) + Float(m[3])
                }
             }
        }
        return dur > 0 ? dur : 3600
    }

    FindFFprobe() {
        ff := FFWrapper.ffmpegPath
        if (ff != "" && FileExist(ff)) {
             SplitPath(ff,, &dir)
             if FileExist(dir "\ffprobe.exe")
                 return dir "\ffprobe.exe"
        }
        if FileExist(A_ScriptDir "\ffprobe.exe")
            return A_ScriptDir "\ffprobe.exe"
        return "ffprobe"
    }

    ; ==============================================================================
    ; RENDER BUILDER
    ; ==============================================================================
    
    BuildFilterChain(inputFile, layers, timeOffset := 0) {
        inputs := ["-i", Format('"{1}"', inputFile)]
        filterParts := []
        
        filterParts.Push("[0:v]scale=trunc(iw*sar/2)*2:ih,setsar=1,format=rgba[base]")
        lastLabel := "base"
        
        imgInputIdx := 1
        
        Loop layers.Length {
            i := A_Index
            L := layers[i]
            if (!L.Visible)
                continue
            
            relStart := L.StartTime - timeOffset
            relEnd   := L.EndTime - timeOffset
            
            if (L.Type == "Text") {
                txt := L.Content
                
                ; Variables Replacement for FFmpeg syntax
                ; Perform replacements FIRST before escaping characters
                txt := StrReplace(txt, "%name%", VideoMeta.Name)
                txt := StrReplace(txt, "%size%", VideoMeta.Size)
                txt := StrReplace(txt, "%res%", VideoMeta.Res)
                
                ; Time/Frame variables map to FFmpeg functions
                txt := StrReplace(txt, "%time%", "%{pts:hms}")
                txt := StrReplace(txt, "%frame%", "%{n}")
                
                ; Now sanitize characters (including colons inside variables like pts:hms)
                txt := StrReplace(txt, ":", "\:")
                txt := StrReplace(txt, "'", "") 
                
                color := (L.Color != "") ? "0x" L.Color : "0xFFFFFF"
                
                posX := Format("(w-text_w)*{:.2f}", L.X/100)
                posY := Format("(h-text_h)*{:.2f}", L.Y/100)
                
                fontFile := GetFontFile(L.Font)
                safeFont := StrReplace(fontFile, "\", "/")
                safeFont := StrReplace(safeFont, ":", "\:")

                boxOpts := ""
                if (L.HasProp("HasBg") && L.HasBg) {
                    bgHex := (L.HasProp("BgColor") && L.BgColor != "") ? L.BgColor : "000000"
                    bgOp := L.HasProp("BgOpacity") ? L.BgOpacity : 50
                    boxOpts := Format(":box=1:boxborderw=5:boxcolor=0x{1}@{2}", bgHex, bgOp/100.0)
                }
                
                st := relStart
                end := relEnd
                fin := L.FadeIn
                fout := L.FadeOut
                op := L.Opacity / 100.0
                
                alphaExpr := Format("if(lt(t,{1}),0,if(lt(t,{1}+{2}),(t-{1})/{2}*{3},if(lt(t,{4}-{5}),{3},if(lt(t,{4}),{3}*({4}-t)/{5},0))))", st, (fin>0?fin:0.01), op, end, (fout>0?fout:0.01))
                
                drawCmd := Format("drawtext=fontfile='{1}':text='{2}':fontsize={3}:fontcolor={4}:x={5}:y={6}:alpha='{7}'{8}", safeFont, txt, L.Size, color, posX, posY, alphaExpr, boxOpts)
                
                nextLabel := "v" i
                filterParts.Push(Format("[{1}]{2}[{3}]", lastLabel, drawCmd, nextLabel))
                lastLabel := nextLabel

            } else if (L.Type == "Image") {
                if !FileExist(L.Content)
                    continue
                    
                inputs.Push("-i", Format('"{1}"', L.Content))
                rawImgLabel := Format("{}:v", imgInputIdx)
                imgInputIdx++
                
                scaledLabel := "s" i
                factor := L.Size / 100.0
                filterParts.Push(Format("[{1}]scale=iw*{2}:-1,format=rgba[{3}]", rawImgLabel, factor, scaledLabel))
                
                processedLabel := "proc" i
                fcmds := ""
                if (L.FadeIn > 0)
                    fcmds .= Format(",fade=t=in:st={1}:d={2}:alpha=1", relStart, L.FadeIn)
                if (L.FadeOut > 0)
                    fcmds .= Format(",fade=t=out:st={1}:d={2}:alpha=1", relEnd - L.FadeOut, L.FadeOut)
                
                opVal := L.Opacity / 100.0
                filterParts.Push(Format("[{1}]colorchannelmixer=aa={2}{3}[{4}]", scaledLabel, opVal, fcmds, processedLabel))
                
                posX := Format("(main_w-overlay_w)*{:.2f}", L.X/100)
                posY := Format("(main_h-overlay_h)*{:.2f}", L.Y/100)
                
                nextLabel := "v" i
                enableCmd := Format(":enable='between(t,{1},{2})'", relStart, relEnd)
                filterParts.Push(Format("[{1}][{2}]overlay=x={3}:y={4}{5}[{6}]", lastLabel, processedLabel, posX, posY, enableCmd, nextLabel))
                lastLabel := nextLabel
            }
        }
        return {inputs: inputs, filter: filterParts, lastLabel: lastLabel}
    }

    PreviewRender(*) {
        inputFile := edtInput.Value
        if (inputFile == "")
            return customDialog({message: "No input file selected."}, darkPreset)
            
        outPath := A_Temp "\preview_clip.mp4"
        try FileDelete(outPath)
            
        dur := (VideoDur > 0) ? VideoDur : 10
        startSec := Max(0, dur * (SeekPos / 100))
        
        data := BuildFilterChain(inputFile, Layers, startSec)
        
        inputs := ["-ss", Format("{:.2f}", startSec)]
        for inp in data.inputs
            inputs.Push(inp)
            
        fullFilter := ""
        for part in data.filter
            fullFilter .= (A_Index > 1 ? ";" : "") . part
            
        cmdArgs := ["-y"]
        for inp in inputs
            cmdArgs.Push(inp)
            
        cmdArgs.Push("-t", "3") 
            
        if (fullFilter != "") {
            cmdArgs.Push("-filter_complex", Format('"{1}"', fullFilter))
            cmdArgs.Push("-map", "[" data.lastLabel "]")
            cmdArgs.Push("-map", "0:a?")
            cmdArgs.Push("-c:v", "libx264", "-crf", "23", "-pix_fmt", "yuv420p", "-c:a", "copy")
        } else {
            cmdArgs.Push("-c", "copy")
        }
        
        sb.Text := " Rendering Preview..."
        OnFinish(success, result) {
            if success {
                sb.Text := " Done."
                Run(result) 
            } else {
                sb.Text := " Preview Error."
                customDialog({title:"Error", detail:result}, errorPreset)
            }
        }
        FFWrapper.Run(cmdArgs, outPath, (p,t) => (sb.Text := t), OnFinish)
    }

    StartRender(*) {
        inputFile := edtInput.Value
        if (inputFile == "")
            return customDialog({message: "No input file selected."}, darkPreset)
            
        SplitPath(inputFile, , &dir, , &nameNoExt)
        outPath := FileSelect("S", dir "\" nameNoExt "_marked.mp4", "Save Video", "Video (*.mp4)")
        if !outPath
            return
        if !RegExMatch(outPath, "\.mp4$")
            outPath .= ".mp4"
            
        data := BuildFilterChain(inputFile, Layers)
        
        fullFilter := ""
        for part in data.filter
            fullFilter .= (A_Index > 1 ? ";" : "") . part
            
        cmdArgs := ["-y"]
        for inp in data.inputs
            cmdArgs.Push(inp)
            
        if (fullFilter != "") {
            cmdArgs.Push("-filter_complex", Format('"{1}"', fullFilter))
            cmdArgs.Push("-map", "[" data.lastLabel "]")
            cmdArgs.Push("-map", "0:a?")
            cmdArgs.Push("-c:v", "libx264", "-crf", "23", "-pix_fmt", "yuv420p", "-c:a", "copy")
        } else {
            cmdArgs.Push("-c", "copy")
        }
        
        sb.Text := " Rendering..."
        OnFinish(success, result) {
            if success {
                sb.Text := " Done."
                if MsgBox("Done! Open file?", "Success", "YesNo") == "Yes"
                    Run("explorer.exe /select,`"" result "`"")
            } else {
                sb.Text := " Error."
                customDialog({title:"Error", detail:result}, errorPreset)
            }
        }
        FFWrapper.Run(cmdArgs, outPath, (p,t) => (sb.Text := t), OnFinish)
    }
    
    ; ==============================================================================
    ; PRESETS
    ; ==============================================================================
    
    SavePreset(*) {
        path := FileSelect("S", "Watermark.ini", "Save Preset", "Settings (*.ini)")
        if !path 
            return
        try FileDelete(path)
        IniWrite(Layers.Length, path, "Meta", "Count")
        Loop Layers.Length {
            l := Layers[A_Index]
            sec := "Layer" A_Index
            IniWrite(l.Type, path, sec, "Type")
            IniWrite(l.Content, path, sec, "Content")
            IniWrite(l.X, path, sec, "X")
            IniWrite(l.Y, path, sec, "Y")
            IniWrite(l.Size, path, sec, "Size")
            IniWrite(l.Opacity, path, sec, "Opacity")
            IniWrite(l.HasProp("BlendMode") ? l.BlendMode : "Normal", path, sec, "BlendMode")
            IniWrite(l.HasProp("StartTime") ? l.StartTime : 0, path, sec, "StartTime")
            IniWrite(l.HasProp("EndTime") ? l.EndTime : 9999, path, sec, "EndTime")
            IniWrite(l.HasProp("FadeIn") ? l.FadeIn : 0, path, sec, "FadeIn")
            IniWrite(l.HasProp("FadeOut") ? l.FadeOut : 0, path, sec, "FadeOut")
            
            if (l.Type == "Text") {
                IniWrite(l.Color, path, sec, "Color")
                IniWrite(l.Font, path, sec, "Font")
                IniWrite(l.HasProp("HasBg") ? l.HasBg : 0, path, sec, "HasBg")
                IniWrite(l.HasProp("BgColor") ? l.BgColor : "000000", path, sec, "BgColor")
                IniWrite(l.HasProp("BgOpacity") ? l.BgOpacity : 50, path, sec, "BgOpacity")
            }
        }
        sb.Text := " Preset Saved."
    }
    
    LoadPreset(*) {
        path := FileSelect(1, , "Load Preset", "Settings (*.ini)")
        if !path 
            return
        try {
            cnt := Integer(IniRead(path, "Meta", "Count", "0"))
            if (cnt == 0)
				return
            Layers := []
            Loop cnt {
                sec := "Layer" A_Index
                l := {}
                l.Type := IniRead(path, sec, "Type")
                l.Content := IniRead(path, sec, "Content")
                l.X := Float(IniRead(path, sec, "X"))
                l.Y := Float(IniRead(path, sec, "Y"))
                l.Size := Integer(IniRead(path, sec, "Size"))
                l.Opacity := Integer(IniRead(path, sec, "Opacity"))
                l.BlendMode := IniRead(path, sec, "BlendMode", "Normal")
                l.StartTime := Float(IniRead(path, sec, "StartTime", "0"))
                l.EndTime := Float(IniRead(path, sec, "EndTime", "9999"))
                l.FadeIn := Float(IniRead(path, sec, "FadeIn", "0"))
                l.FadeOut := Float(IniRead(path, sec, "FadeOut", "0"))
                l.Visible := true
                
                if (l.Type == "Text") {
                     l.Color := IniRead(path, sec, "Color", "FFFFFF")
                     l.Font := IniRead(path, sec, "Font", "Arial")
                     l.HasBg := Integer(IniRead(path, sec, "HasBg", "0"))
                     l.BgColor := IniRead(path, sec, "BgColor", "000000")
                     l.BgOpacity := Integer(IniRead(path, sec, "BgOpacity", "50"))
                }
                Layers.Push(l)
            }
            SelectedIndex := Layers.Length > 0 ? 1 : 0
            
            LayerListObj.SetItems(Layers)
            LayerListObj.Select(SelectedIndex)
            
            UpdatePropPanel()
            RefreshLivePreview()
            sb.Text := " Preset Loaded."
        } catch as e {
            customDialog({message:"Error loading preset: " e.Message}, errorPreset)
        }
    }

    CleanupAndExit() {
        ; Unregister message handler to prevent stuck cursor
        OnMessage(0x20, HandleSetCursor, 0)
        
        ; Clear persistent cursor maps to prevent interference with next run
        HandCursorHwnds := Map()
        
        if (RefFramePath && FileExist(RefFramePath))
            try FileDelete(RefFramePath)
            
        ; Important: Return true so TryCloseWindow knows it's safe to destroy
        return true
    }
}

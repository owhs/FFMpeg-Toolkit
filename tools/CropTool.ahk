
/*
    FFmpeg Visual Crop Tool (AHK v2)
    --------------------------------
    Visually crop video with aspect ratio locking and output padding support.
*/

#Include ..\lib\utils.ahk

CropTool() {
    global AppName := "FFMpeg: Crop Tool"
    
    ; State Variables
    global VideoFile := ""
    global VideoDims := {w: 1920, h: 1080}
    global VideoDur := 0
    global RefFramePath := ""
    global SeekPos := 10
    
    ; Crop Geometry (In Video Pixels)
    global CropRect := {x: 0, y: 0, w: 1920, h: 1080}
    
    ; Visualizer State
    global CanvasRect := {x: 0, y: 0, w: 0, h: 0} ; Where the image is drawn on GUI
    global DrawScale := 1.0 ; Ratio: GUI / Video
    global DragMode := "" ; "Move", "ResizeTL", "ResizeTR", "ResizeBL", "ResizeBR", "Draw"
    global DragStart := {mx: 0, my: 0, cx: 0, cy: 0, cw: 0, ch: 0}
    
    ; UI References
    global OverlayCtrls := {} ; Map of GUI Controls for the box
    global PropCtrls := {} ; Map of edit boxes
    
    ; ==============================================================================
    ; GUI SETUP
    ; ==============================================================================
    myGui := Gui("-Resize -MaximizeBox", AppName)
    myGui.SetFont("s9 c" Theme.Text, "Segoe UI")
    myGui.BackColor := Theme.Bg

    InitWindowUtils(myGui)
    myGui.OnEvent("Close", (*) => CleanupAndExit())
    myGui.OnEvent("DropFiles", HandleDropFiles)
    
    ; OnMessage for cursor changes and dragging
    OnMessage(0x200, OnCropMouseMove) ; Mouse Move
    OnMessage(0x201, OnCropMouseDown) ; LButton Down

    ; Layout
    GuiWidth := 900
    GuiHeight := 680 ; Increased height for new options
    
    xLeft := 15
    yTop := 15
    wLeft := 250
    
    ; --- LEFT PANEL: CONTROLS ---
    
    ; Input
    myGui.SetFont("w600")
    myGui.Add("Text", Format("x{} y{} w{} h20", xLeft, yTop, wLeft), "1. Input Video")
    myGui.SetFont("w400")
    
    edtInput := AddFlatEdit(myGui, Format("x{} y{} w{} h24 ReadOnly vInputFile", xLeft, yTop+25, wLeft-70))
    SexyButton(myGui, xLeft+wLeft-65, yTop+24, 65, 26, "Browse", SelectInput)
    
    ; Geometry
    yGeo := yTop + 70
    myGui.SetFont("w600")
    myGui.Add("Text", Format("x{} y{} w{} h20", xLeft, yGeo, wLeft), "2. Crop Geometry")
    myGui.SetFont("w400")
    
    yP := yGeo + 25
    ; Coordinates Grid
    myGui.Add("Text", Format("x{} y{} w15 h24 +0x200", xLeft, yP), "X:")
    PropCtrls.X := AddFlatEdit(myGui, Format("x{} y{} w40 h24 Number", xLeft+20, yP))
    PropCtrls.X.OnEvent("Change", UpdateFromEdits)
    
    myGui.Add("Text", Format("x{} y{} w15 h24 +0x200", xLeft+70, yP), "Y:")
    PropCtrls.Y := AddFlatEdit(myGui, Format("x{} y{} w40 h24 Number", xLeft+90, yP))
    PropCtrls.Y.OnEvent("Change", UpdateFromEdits)
    
    yP += 32
    myGui.Add("Text", Format("x{} y{} w15 h24 +0x200", xLeft, yP), "W:")
    PropCtrls.W := AddFlatEdit(myGui, Format("x{} y{} w40 h24 Number", xLeft+20, yP))
    PropCtrls.W.OnEvent("Change", UpdateFromEdits)
    
    myGui.Add("Text", Format("x{} y{} w15 h24 +0x200", xLeft+70, yP), "H:")
    PropCtrls.H := AddFlatEdit(myGui, Format("x{} y{} w40 h24 Number", xLeft+90, yP))
    PropCtrls.H.OnEvent("Change", UpdateFromEdits)
    
    SexyButton(myGui, xLeft+150, yP-1, 80, 26, "Center", CenterCrop)
    
    ; Aspect Ratio
    yP += 35
    myGui.Add("Text", Format("x{} y{} w50 h24 +0x200", xLeft, yP), "Ratio:")
    ddlRatio := DarkDropdown(myGui, xLeft+50, yP, 180, ["Free", "16:9", "4:3", "1:1 (Square)", "9:16 (Vertical)", "Custom..."], "AspectMode", OnRatioChange)
    
    ; Output Mode
    yOut := yP + 45
    myGui.SetFont("w600")
    myGui.Add("Text", Format("x{} y{} w{} h20", xLeft, yOut, wLeft), "3. Layout Options")
    myGui.SetFont("w400")
    
    yP := yOut + 25
    myGui.Add("Text", Format("x{} y{} w60 h24 +0x200", xLeft, yP), "Size:")
    ddlOutMode := DarkDropdown(myGui, xLeft+60, yP, 170, ["Crop Only (Change Size)", "Fit to 1920x1080", "Fit to 1280x720", "Fit to 1080x1920", "Fit to Original Size"], "OutMode", TogglePadOpts)
    
    yP += 35
    ; Padding Options (Hidden for Crop Only)
    PropCtrls.PadGrp := []
    
    ; Fill Mode (New)
    txtFill := myGui.Add("Text", Format("x{} y{} w60 h24 +0x200", xLeft, yP), "Fill:")
    PropCtrls.PadGrp.Push(txtFill)
    
    ddlFillMode := DarkDropdown(myGui, xLeft+60, yP, 170, ["Solid Color", "Blurred Background"], "FillMode", TogglePadOpts)
    PropCtrls.PadGrp.Push(ddlFillMode)
    
    yP += 35
    
    ; Group: Color (Visible if Solid Color)
    PropCtrls.ColorGrp := []
    txtAlign := myGui.Add("Text", Format("x{} y{} w60 h24 +0x200", xLeft, yP), "Align:")
    PropCtrls.ColorGrp.Push(txtAlign)
    
    ddlAlign := DarkDropdown(myGui, xLeft+60, yP, 170, ["Center", "Top-Left", "Top-Right", "Bottom-Left", "Bottom-Right"], "PadAlign")
    PropCtrls.ColorGrp.Push(ddlAlign)
    
    yP += 35
    txtColor := myGui.Add("Text", Format("x{} y{} w60 h24 +0x200", xLeft, yP-35+35), "Color:") ; Correct Y logic manually
    PropCtrls.ColorGrp.Push(txtColor)
    
    edtColor := AddFlatEdit(myGui, Format("x{} y{} w70 h24 ReadOnly vPadColor", xLeft+60, yP), "000000")
    PropCtrls.ColorGrp.Push(edtColor)
    
    btnPick := SexyButton(myGui, xLeft+140, yP-1, 50, 26, "Pick", (*) => RunColorPicker(edtColor, myGui.Hwnd))
    PropCtrls.ColorGrp.Push(btnPick)
    
    ; Group: Blur (Visible if Blurred Background)
    ; Reposition Y to match Color group area for swapping
    yBlur := yP - 35
    PropCtrls.BlurGrp := []
    txtBlur := myGui.Add("Text", Format("x{} y{} w60 h24 +0x200 Hidden", xLeft, yBlur), "Blur:")
    PropCtrls.BlurGrp.Push(txtBlur)
    
    sldBlur := myGui.Add("Slider", Format("x{} y{} w170 h24 vBlurStrength Range1-50 ToolTip Hidden", xLeft+60, yBlur), 20)
    PropCtrls.BlurGrp.Push(sldBlur)
    
    txtBlurInfo := myGui.Add("Text", Format("x{} y{} w200 h24 c888888 Hidden", xLeft+60, yBlur+25), "(1 = Light, 50 = Heavy)")
    PropCtrls.BlurGrp.Push(txtBlurInfo)
    
    ; Toggle visibility initially
    TogglePadOpts()
    
    ; --- 4. EXPORT SETTINGS ---
    yExport := yP + 45
    myGui.SetFont("w600")
    myGui.Add("Text", Format("x{} y{} w{} h20", xLeft, yExport, wLeft), "4. Export Settings")
    myGui.SetFont("w400")

    yP := yExport + 25
    myGui.Add("Text", Format("x{} y{} w60 h24 +0x200", xLeft, yP), "Format:")
    ddlExportFmt := DarkDropdown(myGui, xLeft+60, yP, 170, ["MP4 (H.264)", "MKV (H.264)", "WebM (VP9)", "GIF (Animated)", "ProRes (MOV)"], "ExportFormat", ToggleExportOpts)
    
    yP += 35
    myGui.Add("Text", Format("x{} y{} w60 h24 +0x200", xLeft, yP), "FPS:")
    ddlExportFPS := DarkDropdown(myGui, xLeft+60, yP, 170, ["Same as Source", "60", "50", "30", "24", "15", "12", "10", "6"], "ExportFPS")

    yP += 35
    
    ; --- Dynamic Export Groups (Quality vs Dithering) ---
    PropCtrls.QualGrp := []
    PropCtrls.GifGrp := []

    ; Video Quality Group
    tQual := myGui.Add("Text", Format("x{} y{} w60 h24 +0x200", xLeft, yP), "Quality:")
    PropCtrls.QualGrp.Push(tQual)
    
    ddlExportQual := DarkDropdown(myGui, xLeft+60, yP, 170, ["High (CRF 17)", "Medium (CRF 23)", "Low (CRF 28)"], "ExportQuality", , 2)
    PropCtrls.QualGrp.Push(ddlExportQual)

    ; GIF Dithering Group (Hidden by default)
    tDither := myGui.Add("Text", Format("x{} y{} w60 h24 +0x200 Hidden", xLeft, yP), "Dither:")
    PropCtrls.GifGrp.Push(tDither)
    
    ddlGifDither := DarkDropdown(myGui, xLeft+60, yP, 170, ["Sierra2_4a (Default)", "Floyd_Steinberg", "Bayer", "Heckbert", "None"], "GifDither")
    ddlGifDither.SetVisible(false)
    PropCtrls.GifGrp.Push(ddlGifDither)


    ; --- RIGHT PANEL: PREVIEW ---
    xRight := xLeft + wLeft + 20
    wRight := GuiWidth - xRight - 15
    hRight := 400
    
    myGui.SetFont("w600")
    myGui.Add("Text", Format("x{} y{} w200 h20", xRight, yTop), "Visual Preview")
    myGui.SetFont("w400")
    
    ; Canvas Container
    picBg := myGui.Add("Text", Format("x{} y{} w{} h{} Background000000", xRight, yTop+25, wRight, hRight), "")
    picRef := myGui.Add("Picture", Format("x{} y{} w{} h{} Background000000 -Border Hidden", xRight, yTop+25, wRight, hRight), "")
    
    ; --- OVERLAY CONTROLS ---
    ; We create 4 border lines (Cyan) and 4 corner handles (White squares)
    ; They are hidden initially
    borderCol := "00FFFF"
    
    ovTop := myGui.Add("Text", Format("x0 y0 w0 h2 Background{} Hidden", borderCol), "")
    ovBot := myGui.Add("Text", Format("x0 y0 w0 h2 Background{} Hidden", borderCol), "")
    ovLeft := myGui.Add("Text", Format("x0 y0 w2 h0 Background{} Hidden", borderCol), "")
    ovRight := myGui.Add("Text", Format("x0 y0 w2 h0 Background{} Hidden", borderCol), "")
    
    OverlayCtrls.Lines := [ovTop, ovBot, ovLeft, ovRight]
    OverlayCtrls.Handles := []
    
    Loop 4 {
        ; 1=TL, 2=TR, 3=BL, 4=BR
        h := myGui.Add("Text", "x0 y0 w10 h10 BackgroundFFFFFF Hidden", "")
        OverlayCtrls.Handles.Push(h)
    }
    
    ; --- FOOTER ---
    yFooter := GuiHeight - 50
    myGui.Add("Text", Format("x0 y{} w{} h50 Background{}", yFooter, GuiWidth, Theme.DarkPanel), "")
    
    ; Seek Slider
    ySeek := yTop + 25 + hRight + 10
    myGui.Add("Text", Format("x{} y{} w40 h24 +0x200 c888888", xRight, ySeek), "Seek:")
    sldSeek := myGui.Add("Slider", Format("x{} y{} w{} h24 vSeekPos Range0-100 ToolTip", xRight+45, ySeek, wRight-120), 10)
    sldSeek.OnEvent("Change", OnSeekChange)
    txtTime := myGui.Add("Text", Format("x{} y{} w60 h24 +0x200 Right c888888", xRight+wRight-60, ySeek), "00:00")
    
    ; Buttons
    SexyButton(myGui, GuiWidth-270, yFooter+10, 120, 30, "Preview (3s)", PreviewRender)
    expBtn := SexyButton(myGui, GuiWidth-140, yFooter+10, 120, 30, "Export Video", StartExport)
    expBtn.Beautify()

    btnCancel := SexyButton(myGui, GuiWidth-140, yFooter+10, 120, 30, "Cancel", CancelConversion)
    btnCancel.Visible := false
    btnCancel.setBorders([Theme.AltAccent,Theme.AltAccent,Theme.AltAccent,Theme.AltAccent])
    btnCancel.SetTextColour(Theme.AltAccent)
    
    sb := myGui.Add("Text", Format("x20 y{} w400 h50 BackgroundTrans c888888 +0x200", yFooter), "Ready.")
    
    ; Progress Bar (Top of Footer)
    progressBar := myGui.Add("Progress", Format("x0 y{} w{} h3 c{} Background{}", yFooter, GuiWidth, Theme.Accent, Theme.DarkPanel, "Range0-100 vMyProgress"), 0)


    myGui.Show(Format("w{} h{}", GuiWidth, GuiHeight))
    
    ; ==============================================================================
    ; LOGIC
    ; ==============================================================================
    
    CleanupAndExit() {
        if (RefFramePath && FileExist(RefFramePath))
            try FileDelete(RefFramePath)
        myGui.Destroy()
    }
    
    TogglePadOpts(*) {
        mode := ddlOutMode.Text
        fill := ddlFillMode.Text
        
        isCropOnly := InStr(mode, "Crop Only")
        isBlur := (fill == "Blurred Background")
        
        ; Main Pad Group (Fill Mode dropdown etc)
        for c in PropCtrls.PadGrp {
            try (HasProp(c, "SetVisible") ? c.SetVisible(!isCropOnly) : c.Visible := !isCropOnly)
        }
        
        ; Color Group
        showColor := (!isCropOnly && !isBlur)
        for c in PropCtrls.ColorGrp {
            try (HasProp(c, "SetVisible") ? c.SetVisible(showColor) : c.Visible := showColor)
        }
        
        ; Blur Group
        showBlur := (!isCropOnly && isBlur)
        for c in PropCtrls.BlurGrp {
            try (HasProp(c, "SetVisible") ? c.SetVisible(showBlur) : c.Visible := showBlur)
        }
    }

    ToggleExportOpts(*) {
        isGif := InStr(ddlExportFmt.Text, "GIF")
        
        for c in PropCtrls.QualGrp
             try (HasProp(c, "SetVisible") ? c.SetVisible(!isGif) : c.Visible := !isGif)
             
        for c in PropCtrls.GifGrp
             try (HasProp(c, "SetVisible") ? c.SetVisible(isGif) : c.Visible := isGif)
    }
    
    SelectInput(*) {
        path := FileSelect(1, , "Select Video", "Video (*.mp4; *.mov; *.mkv; *.avi; *.webm)")
        if path 
            LoadVideo(path)
    }
    
    HandleDropFiles(guiObj, ctrlObj, fileArray, x, y) {
        if (fileArray.Length > 0)
            LoadVideo(fileArray[1])
    }
    
    LoadVideo(path) {
        edtInput.Value := path
        VideoFile := path
        
        sb.Text := "Probing..."
        VideoDims := GetVideoDimensions(path)
        VideoDur := GetVideoDuration(path)
        
        ; Reset Crop to Full
        CropRect := {x: 0, y: 0, w: VideoDims.w, h: VideoDims.h}
        UpdateEditCtrls()
        
        ExtractFrame()
    }
    
    OnSeekChange(*) {
        SetTimer(ExtractFrame, -200)
    }
    
    ExtractFrame() {
        if (VideoFile == "")
            return
            
        SeekPos := sldSeek.Value
        time := (VideoDur > 0 ? VideoDur : 10) * (SeekPos / 100)
        txtTime.Text := FormatSeconds(time)
        
        sb.Text := "Loading Frame..."
        RefFramePath := A_Temp "\crop_ref_" A_TickCount ".jpg"
        
        cmd := ["-ss", Format("{:.2f}", time), "-i", Format('"{1}"', VideoFile), "-frames:v", "1", "-q:v", "2"]
        
        try {
            FFWrapper.GeneratePreview(cmd, RefFramePath)
            if FileExist(RefFramePath) {
                picRef.Value := RefFramePath
                picRef.Visible := true
                UpdateCanvasMetrics()
                DrawOverlay()
                sb.Text := "Ready."
            }
        }
    }
    
    UpdateCanvasMetrics() {
        ; Use background container for available space
        picBg.GetPos(&bx, &by, &bw, &bh)
        
        if (VideoDims.w == 0 || VideoDims.h == 0)
            return
            
        ratioVid := VideoDims.w / VideoDims.h
        ratioBox := bw / bh
        
        drawW := 0, drawH := 0
        
        if (ratioVid > ratioBox) {
            ; Fit to Width
            drawW := bw
            drawH := bw / ratioVid
        } else {
            ; Fit to Height
            drawH := bh
            drawW := bh * ratioVid
        }
        
        offX := (bw - drawW) / 2
        offY := (bh - drawH) / 2
        
        finalX := bx + offX
        finalY := by + offY
        
        ; Resize Picture Control to match exact image area
        ; This ensures AHK fills it perfectly and alignment matches
        picRef.Move(finalX, finalY, drawW, drawH)
        
        CanvasRect := {x: finalX, y: finalY, w: drawW, h: drawH}
        DrawScale := drawW / VideoDims.w
    }
    
    DrawOverlay() {
        if (CanvasRect.w == 0)
            return
            
        ; Convert CropRect (Video Pixels) to GUI Pixels
        gx := CanvasRect.x + (CropRect.x * DrawScale)
        gy := CanvasRect.y + (CropRect.y * DrawScale)
        gw := CropRect.w * DrawScale
        gh := CropRect.h * DrawScale
        
        ; Clamp visual to canvas (floating point errors)
        ; Not strictly necessary if CropRect is managed well
        
        ; Draw Lines
        OverlayCtrls.Lines[1].Move(gx, gy, gw, 2) ; Top
        OverlayCtrls.Lines[2].Move(gx, gy+gh, gw, 2) ; Bot
        OverlayCtrls.Lines[3].Move(gx, gy, 2, gh) ; Left
        OverlayCtrls.Lines[4].Move(gx+gw, gy, 2, gh+2) ; Right
        
        ; Draw Handles (10x10)
        hw := 10
        offset := hw / 2
        
        OverlayCtrls.Handles[1].Move(gx - offset, gy - offset, hw, hw) ; TL
        OverlayCtrls.Handles[2].Move(gx + gw - offset, gy - offset, hw, hw) ; TR
        OverlayCtrls.Handles[3].Move(gx - offset, gy + gh - offset, hw, hw) ; BL
        OverlayCtrls.Handles[4].Move(gx + gw - offset, gy + gh - offset, hw, hw) ; BR
        
        for c in OverlayCtrls.Lines
            c.Visible := true
        for c in OverlayCtrls.Handles
            c.Visible := true
    }
    
    UpdateFromEdits(*) {
        CropRect.x := Integer(PropCtrls.X.Value)
        CropRect.y := Integer(PropCtrls.Y.Value)
        CropRect.w := Integer(PropCtrls.W.Value)
        CropRect.h := Integer(PropCtrls.H.Value)
        DrawOverlay()
    }
    
    UpdateEditCtrls() {
        PropCtrls.X.Value := Round(CropRect.x)
        PropCtrls.Y.Value := Round(CropRect.y)
        PropCtrls.W.Value := Round(CropRect.w)
        PropCtrls.H.Value := Round(CropRect.h)
    }
    
    CenterCrop(*) {
        ; Center current WH in Video
        CropRect.x := (VideoDims.w - CropRect.w) / 2
        CropRect.y := (VideoDims.h - CropRect.h) / 2
        ClampRect()
        UpdateEditCtrls()
        DrawOverlay()
    }
    
    OnRatioChange(*) {
        mode := ddlRatio.Text
        if (mode == "Free" || mode == "Custom...")
            return
            
        ratio := 1.0
        if (mode == "16:9")
            ratio := 16/9
        else if (mode == "4:3")
            ratio := 4/3
        else if (mode == "1:1 (Square)")
            ratio := 1
        else if (mode == "9:16 (Vertical)")
            ratio := 9/16
            
        ; Adjust Height to match Width based on Ratio
        newH := CropRect.w / ratio
        
        ; If new Height fits, apply
        if (CropRect.y + newH <= VideoDims.h) {
            CropRect.h := newH
        } else {
            ; Fit width instead
            newW := CropRect.h * ratio
            CropRect.w := newW
        }
        
        UpdateEditCtrls()
        DrawOverlay()
    }
    
    ; --- MOUSE INTERACTION ---
    
    OnCropMouseMove(wParam, lParam, msg, hwnd) {
        if (CanvasRect.w == 0)
            return
            
        MouseGetPos(,,, &hCtrl, 2)
        
        ; Identify cursor
        cursor := 32512 ; Arrow
        
        ; Check Handles
        isHandle := false
        try Loop 4 {
            if (hCtrl == OverlayCtrls.Handles[A_Index].Hwnd) {
                isHandle := true
                ; TL/BR = NWSE (32642), TR/BL = NESW (32643)
                if (A_Index == 1 || A_Index == 4)
                    cursor := 32642
                else
                    cursor := 32643
            }
        }
        
        if (!isHandle) {
            ; Check if inside box
            MouseGetPos(&mx, &my)
            gx := CanvasRect.x + (CropRect.x * DrawScale)
            gy := CanvasRect.y + (CropRect.y * DrawScale)
            gw := CropRect.w * DrawScale
            gh := CropRect.h * DrawScale
            
            if (mx > gx && mx < gx+gw && my > gy && my < gy+gh) {
                cursor := 32646 ; SizeAll (Move)
            }
        }
        
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", cursor, "Ptr"))
    }
    
    OnCropMouseDown(wParam, lParam, msg, hwnd) {
        if (CanvasRect.w == 0)
            return
            
        MouseGetPos(&mx, &my, , &hCtrl, 2)
        
        DragMode := ""
        
        ; Check Handles
        try Loop 4 {
            if (hCtrl == OverlayCtrls.Handles[A_Index].Hwnd) {
                DragMode := (A_Index==1)?"ResizeTL" : (A_Index==2)?"ResizeTR" : (A_Index==3)?"ResizeBL" : "ResizeBR"
                break
            }
        }
        
        if (DragMode == "") {
            ; Check Inside
            gx := CanvasRect.x + (CropRect.x * DrawScale)
            gy := CanvasRect.y + (CropRect.y * DrawScale)
            gw := CropRect.w * DrawScale
            gh := CropRect.h * DrawScale
            
            if (mx > gx && mx < gx+gw && my > gy && my < gy+gh) {
                DragMode := "Move"
            }
        }
        
        if (DragMode != "") {
            DragStart := {mx: mx, my: my, cx: CropRect.x, cy: CropRect.y, cw: CropRect.w, ch: CropRect.h}
            SetTimer(HandleDrag, 15)
        }
    }
    
    HandleDrag() {
        if !GetKeyState("LButton", "P") {
            SetTimer(HandleDrag, 0)
            UpdateEditCtrls() ; Final sync
            return
        }
        
        MouseGetPos(&currX, &currY)
        deltaX := (currX - DragStart.mx) / DrawScale
        deltaY := (currY - DragStart.my) / DrawScale
        
        ratioLocked := (ddlRatio.Text != "Free" && ddlRatio.Text != "Custom...")
        targetRatio := 0
        if (ratioLocked)
            targetRatio := DragStart.cw / DragStart.ch ; Use ratio at start of drag to avoid drift
            
        newRect := {x: DragStart.cx, y: DragStart.cy, w: DragStart.cw, h: DragStart.ch}
        
        if (DragMode == "Move") {
            newRect.x += deltaX
            newRect.y += deltaY
        } 
        else if (DragMode == "ResizeBR") {
            newRect.w += deltaX
            if (ratioLocked) {
                newRect.h := newRect.w / targetRatio
                ; Bounds Check with Ratio
                if (newRect.x + newRect.w > VideoDims.w) {
                    newRect.w := VideoDims.w - newRect.x
                    newRect.h := newRect.w / targetRatio
                }
                if (newRect.y + newRect.h > VideoDims.h) {
                    newRect.h := VideoDims.h - newRect.y
                    newRect.w := newRect.h * targetRatio
                }
            } else {
                newRect.h += deltaY
            }
        } 
        else if (DragMode == "ResizeBL") {
            newRect.x += deltaX
            newRect.w -= deltaX
            if (ratioLocked) {
                newRect.h := newRect.w / targetRatio
                ; Bounds Check (Left and Bottom)
                if (newRect.x < 0) {
                    newRect.x := 0
                    newRect.w := (DragStart.cx + DragStart.cw) ; Max width from 0 to right edge
                    newRect.h := newRect.w / targetRatio
                }
                if (newRect.y + newRect.h > VideoDims.h) {
                    newRect.h := VideoDims.h - newRect.y
                    newRect.w := newRect.h * targetRatio
                    newRect.x := (DragStart.cx + DragStart.cw) - newRect.w ; Adjust X to maintain right edge
                }
            } else {
                newRect.h += deltaY
            }
        }
        else if (DragMode == "ResizeTR") {
            newRect.y += deltaY
            newRect.h -= deltaY
            newRect.w += deltaX
            if (ratioLocked) {
                newRect.h := newRect.w / targetRatio
                newRect.y := (DragStart.cy + DragStart.ch) - newRect.h ; Bottom anchor
                
                ; Bounds Check (Top and Right)
                if (newRect.x + newRect.w > VideoDims.w) {
                    newRect.w := VideoDims.w - newRect.x
                    newRect.h := newRect.w / targetRatio
                    newRect.y := (DragStart.cy + DragStart.ch) - newRect.h
                }
                if (newRect.y < 0) {
                    newRect.y := 0
                    newRect.h := (DragStart.cy + DragStart.ch)
                    newRect.w := newRect.h * targetRatio
                }
            }
        }
        else if (DragMode == "ResizeTL") {
            newRect.x += deltaX
            newRect.y += deltaY
            newRect.w -= deltaX
            newRect.h -= deltaY
            if (ratioLocked) {
                newRect.h := newRect.w / targetRatio
                newRect.y := (DragStart.cy + DragStart.ch) - newRect.h ; Bottom anchor
                
                ; Bounds Check (Top and Left)
                if (newRect.x < 0) {
                    newRect.x := 0
                    newRect.w := (DragStart.cx + DragStart.cw)
                    newRect.h := newRect.w / targetRatio
                    newRect.y := (DragStart.cy + DragStart.ch) - newRect.h
                }
                if (newRect.y < 0) {
                    newRect.y := 0
                    newRect.h := (DragStart.cy + DragStart.ch)
                    newRect.w := newRect.h * targetRatio
                    newRect.x := (DragStart.cx + DragStart.cw) - newRect.w
                }
            }
        }
        
        ; Universal Constraints
        if (newRect.w < 10)
             newRect.w := 10
        if (newRect.h < 10)
             newRect.h := 10
            
        ; Standard Bound check (for non-ratio or move modes)
        if (DragMode == "Move" || !ratioLocked) {
            if (newRect.x < 0)
                 newRect.x := 0
            if (newRect.y < 0)
                 newRect.y := 0
            if (newRect.x + newRect.w > VideoDims.w) {
                if (DragMode == "Move")
                     newRect.x := VideoDims.w - newRect.w
                else 
                    newRect.w := VideoDims.w - newRect.x
            }
            if (newRect.y + newRect.h > VideoDims.h) {
                if (DragMode == "Move")
                     newRect.y := VideoDims.h - newRect.h
                else
                     newRect.h := VideoDims.h - newRect.y
            }
        }
        
        CropRect := newRect
        DrawOverlay()
        
        ; Live update numbers
        PropCtrls.X.Value := Round(CropRect.x)
        PropCtrls.Y.Value := Round(CropRect.y)
        PropCtrls.W.Value := Round(CropRect.w)
        PropCtrls.H.Value := Round(CropRect.h)
    }
    
    ClampRect() {
        if (CropRect.x < 0)
             CropRect.x := 0
        if (CropRect.y < 0)
             CropRect.y := 0
        if (CropRect.x + CropRect.w > VideoDims.w)
             CropRect.x := VideoDims.w - CropRect.w
        if (CropRect.y + CropRect.h > VideoDims.h)
             CropRect.y := VideoDims.h - CropRect.h
    }
    
    ; ==============================================================================
    ; UTILS
    ; ==============================================================================
    GetVideoDimensions(path) {
        ; Use FFWrapper Probe if available for cleaner logic
        try {
            info := FFWrapper.Probe(path)
            if (info.HasOwnProp("streams")) {
                for s in info.streams {
                    if (s.Has("codec_type") && s["codec_type"] == "video") {
                        w := s.Has("width") ? Integer(s["width"]) : 1920
                        h := s.Has("height") ? Integer(s["height"]) : 1080
                        return {w: w, h: h}
                    }
                }
            }
        }
        return {w: 1920, h: 1080}
    }
    
    GetVideoDuration(path) {
        try {
            info := FFWrapper.Probe(path)
            if (info.HasOwnProp("format") && info.format.Has("duration"))
                return Float(info.format["duration"])
        }
        return 0
    }
    
    ; ==============================================================================
    ; EXPORT
    ; ==============================================================================
    
    PreviewRender(*) {
        if (VideoFile == "")
            return customDialog({message: "No input."}, darkPreset)
            
        sb.Text := "Generating Preview..."
        outPath := A_Temp "\crop_prev.mp4"
        try FileDelete(outPath)
        
        time := (VideoDur > 0 ? VideoDur : 10) * (SeekPos / 100)
        
        filterData := BuildFilterConfig()
        
        cmd := ["-y", "-ss", Format("{:.2f}", time), "-t", "3", "-i", Format('"{1}"', VideoFile)]
        
        if (filterData.isComplex) {
            cmd.Push("-filter_complex", Format('"{1}"', filterData.filter))
            cmd.Push("-map", "[outv]", "-map", "0:a?")
        } else {
            cmd.Push("-vf", filterData.filter)
            cmd.Push("-an")
        }
        
        cmd.Push("-c:v", "libx264", "-crf", "23")
        
        FFWrapper.Run(cmd, outPath, (p,t) => "", (s,r) => (s ? Run(outPath) : (sb.Text := "Preview Failed.", MsgBox(r))))
    }
    
    StartExport(*) {
        saved := myGui.Submit(0)
        if (VideoFile == "")
            return customDialog({message: "No input."}, darkPreset)
            
        SplitPath(VideoFile, , &dir, , &nameNoExt)
        
        ; Determine extension
        ext := "mp4"
        if InStr(saved.ExportFormat, "MKV")
            ext := "mkv"
        else if InStr(saved.ExportFormat, "WebM")
            ext := "webm"
        else if InStr(saved.ExportFormat, "GIF")
            ext := "gif"
        else if InStr(saved.ExportFormat, "MOV")
            ext := "mov"
            
        outPath := FileSelect("S", dir "\" nameNoExt "_cropped." ext, "Save Video", "Video (*." ext ")")
        if !outPath
            return
            
        if !RegExMatch(outPath, "\." ext "$")
            outPath .= "." ext
            
        filterData := BuildFilterConfig()
        
        cmd := ["-y", "-i", Format('"{1}"', VideoFile)]
        
        ; FPS Handling
        if (saved.ExportFPS != "Same as Source") {
            cmd.Push("-r", saved.ExportFPS)
        }
        
        if (ext == "gif") {
            ; GIF specific complex filter logic
            ; Dither Mapping
            ditherMode := "sierra2_4a"
            switch saved.GifDither {
                case "Floyd_Steinberg": ditherMode := "floyd_steinberg"
                case "Bayer": ditherMode := "bayer:bayer_scale=1"
                case "Heckbert": ditherMode := "heckbert"
                case "None": ditherMode := "none"
            }
            
            baseFilter := filterData.filter
            gifFilter := ""
            
            if (filterData.isComplex) {
                ; Complex filter ends with [outv]
                ; Append palettegen logic to [outv]
                gifFilter := baseFilter ";[outv]split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse=dither=" ditherMode
                cmd.Push("-filter_complex", Format('"{1}"', gifFilter))
            } else {
                ; Simple filter string
                gifFilter := baseFilter ",split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse=dither=" ditherMode
                cmd.Push("-vf", Format('"{1}"', gifFilter))
            }
        } 
        else {
            if (filterData.isComplex) {
                cmd.Push("-filter_complex", Format('"{1}"', filterData.filter))
                cmd.Push("-map", "[outv]", "-map", "0:a?")
            } else {
                cmd.Push("-vf", filterData.filter)
                cmd.Push("-c:a", "copy")
            }
            
            ; Video Encoder Settings
            if (ext == "webm") {
                cmd.Push("-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "30")
            } else if (ext == "mov" && InStr(saved.ExportFormat, "ProRes")) {
                cmd.Push("-c:v", "prores_ks", "-profile:v", "3")
            } else {
                ; H.264 (MP4/MKV)
                cmd.Push("-c:v", "libx264", "-pix_fmt", "yuv420p")
                
                crf := 23
                if InStr(saved.ExportQuality, "High")
                    crf := 17
                else if InStr(saved.ExportQuality, "Low")
                    crf := 28
                cmd.Push("-crf", crf)
            }
        }
        
        expBtn.Visible := false
        btnCancel.Visible := true

        sb.Text := "Exporting..."
        progressBar.Value := 0

        
        ; Callback for Progress
        OnProgress(percent, text) {
            if (sb.Text != "Cancelling..."){
                progressBar.Value := percent
                sb.Text := text
            }
        }
        
        ; Callback for Finish
        OnFinish(success, result) {
        
            btnCancel.Visible := false
            expBtn.Visible := true
            
            if (success) {
                progressBar.Value := 100
                sb.Text := " Complete!"
                if MsgBox("Conversion Complete!`nSaved to: " result, "Success", "YesNo") == "Yes"
                    Run("explorer.exe /select,`"" result "`"")
            } else {
                sb.Text := (InStr(result, "Cancelled") ? " Cancelled." : " Failed.")
                if !InStr(result, "Cancelled")
                    ShowErrorLog(result)
            }
        }

        FFWrapper.Run(cmd, outPath, OnProgress, OnFinish)
    }
    
    ResetButtons() {
        btnCancel.Visible := false
        expBtn.Visible := true
        btnCancel.SetText("Cancel")
    }


    CancelConversion(*) {
        FFWrapper.Stop()
        sb.Text := "Cancelling..."
        btnCancel.SetText("Cancelling...")
        
        SetTimer(ResetButtons, -1000)
    }
    
    ShowErrorLog(logContent) {

        customDialog({title:"FFmpeg Error Log",message:"FFmpeg Failed!`nFull log output:",detail: logContent}, criticalErrorDetailPreset)
        
    }
    BuildFilterConfig() {
        ; Crop syntax: crop=w:h:x:y
        cx := Round(CropRect.x)
        cy := Round(CropRect.y)
        cw := Round(CropRect.w)
        ch := Round(CropRect.h)
        
        filter := Format("crop={1}:{2}:{3}:{4}", cw, ch, cx, cy)
        isComplex := false
        
        outMode := ddlOutMode.Text
        if (!InStr(outMode, "Crop Only")) {
            ; Pad logic
            tw := 1920, th := 1080
            if InStr(outMode, "1280") { 
                tw := 1280, th := 720 
            }
            if InStr(outMode, "Vertical") { 
                tw := 1080, th := 1920 
            }
            if InStr(outMode, "Original") { 
                tw := VideoDims.w, th := VideoDims.h 
            }
            
            fillMode := ddlFillMode.Text
            
            if (fillMode == "Blurred Background") {
                isComplex := true
                blurStr := sldBlur.Value
                ; Create a complex filter chain
                ; 1. Crop input [c]
                ; 2. Split [c] to [fg] and [bg]
                ; 3. Scale [bg] to fill target (increase), crop to target, blur
                ; 4. Scale [fg] to fit target (decrease)
                ; 5. Overlay fg on bg
                
                filter := Format("[0:v]crop={1}:{2}:{3}:{4}[c];[c]split[bg][fg];[bg]scale={5}:{6}:force_original_aspect_ratio=increase,crop={5}:{6},boxblur=luma_radius={7}:luma_power=1[bgblur];[fg]scale={5}:{6}:force_original_aspect_ratio=decrease[fgsc];[bgblur][fgsc]overlay=(W-w)/2:(H-h)/2[outv]", cw, ch, cx, cy, tw, th, blurStr)
                
            } else {
                ; Solid Color Pad
                align := ddlAlign.Text
                px := "(ow-iw)/2"
                py := "(oh-ih)/2"
                
                if (align == "Top-Left") {
                    px := "0", py := "0" 
                    }
                if (align == "Top-Right") { 
                    px := "ow-iw", py := "0" 
                    }
                if (align == "Bottom-Left") { 
                    px := "0", py := "oh-ih" 
                    }
                if (align == "Bottom-Right") { 
                    px := "ow-iw", py := "oh-ih" 
                }
                
                col := "0x" edtColor.Value
                filter .= Format(",scale={1}:{2}:force_original_aspect_ratio=decrease,pad={1}:{2}:{3}:{4}:{5}", tw, th, px, py, col)
            }
        }
        return {filter: filter, isComplex: isComplex}
    }
}

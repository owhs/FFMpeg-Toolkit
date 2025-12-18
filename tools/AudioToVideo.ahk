

/*
    Simple Audio to Video Converter (AHK v2) - Compact Grid Layout (Fixed)
    ----------------------------------------
    Wraps FFmpeg to convert audio files into video.
*/
#Requires AutoHotkey v2.0

#Include ..\lib\utils.ahk
AudioToVideo(){
    global AppName := "FFMpeg: Audio to Video"

    ; ==============================================================================
    ; GUI CREATION & GRID SYSTEM
    ; ==============================================================================
    myGui := Gui("-Resize -MaximizeBox", AppName)
    myGui.SetFont("s9 c" Theme.Text, "Segoe UI")
    myGui.BackColor := Theme.Bg

    ; Init Utils
    InitWindowUtils(myGui)
    
    myGui.FFJob := FFWrapper
    myGui.OnEvent("Close", (*) => TryCloseWindow(myGui))
    myGui.OnEvent("DropFiles", HandleDropFiles)

    ; --- GRID LAYOUT CONSTANTS ---
    GuiWidth      := 540
    yContentStart := 44   ; Where tab content begins
    RowH          := 32   ; Height of one "Logical Row" (includes gap)
    CtrlH         := 24   ; Height of actual input controls
    BtnH          := 24   ; Height of inline buttons

    ; Columns (X Coordinates)
    xLabel  := 15
    xInput  := 80
    wInput  := 340        ; Wider inputs
    xBtn    := 430
    wBtn    := 95

    ; ==============================================================================
    ; TAB NAVIGATION
    ; ==============================================================================
    myGui.Add("Text", Format("x0 y0 w{} h40 Background{}", GuiWidth, Theme.DarkPanel), "")
    Tabs := TabManager(myGui, Theme, OnTabChanged)

    ; Wider, shorter tab buttons
    tW := GuiWidth / 3
    Tabs.Add("1. Audio Source", 0,    0, tW, 40, "Audio")
    Tabs.Add("2. Visual Style", tW,   0, tW, 40, "Visual")
    Tabs.Add("3. Output Settings", tW*2, 0, tW, 40, "Output")

    ; ==============================================================================
    ; TAB 1: AUDIO SOURCE
    ; ==============================================================================
    currY := yContentStart + 11

    ; Row 1: File Selection
    AddTabControl("Audio", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Audio:")
    edtAudio := AddTabControl("Audio", "Edit", Format("x{} y{} w{} h{} ReadOnly vAudioFile", xInput, currY, wInput, CtrlH))
    SexyButton(myGui, xBtn, currY-1, wBtn, BtnH+2, "Browse...", SelectAudio).RegisterToTab(Tabs, "Audio")



    ; Row 2: Quality
    currY += RowH+4
    AddTabControl("Audio", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Quality:")
    ddlQuality := DarkDropdown(myGui, xInput, currY, wInput, ["128 kbps (Low)", "192 kbps (Standard)", "320 kbps (High Quality)", "Copy (Lossless/Fast)"], "AudioQuality", , 4)
    ddlQuality.RegisterToTab(Tabs, "Audio")

    ; Row 3: Divider
    currY += RowH + 5
    ;Tabs.Register("Audio", myGui.Add("Text", Format("x{} y{} w{} h1 Background{}", xLabel, currY, GuiWidth-(xLabel*2), Theme.Panel), ""))
    currY += 10

    ; Row 4: Trim (All on one line)
    chkTrim := myGui.Add("Checkbox", Format("x{} y{} w90 h{} vEnableTrim c{} Background{}", xInput, currY, CtrlH, Theme.Text, Theme.Bg), "Cut Segment")
    SetDarkControl(chkTrim)
    Tabs.Register("Audio", chkTrim)

    AddTabControl("Audio", "Text", Format("x225 y{} w35 h{}", currY+4, CtrlH), "Start:")
    edtTrimStart := AddTabControl("Audio", "Edit", Format("x265 y{} w60 h{} vTrimStart", currY, CtrlH), "00:00:00")

    AddTabControl("Audio", "Text", Format("x335 y{} w20 h{}", currY+4, CtrlH), "to")
    edtTrimEnd := AddTabControl("Audio", "Edit", Format("x355 y{} w60 h{} vTrimEnd", currY, CtrlH), "00:00:15")


    ; ==============================================================================
    ; TAB 2: VISUAL STYLE
    ; ==============================================================================

    yContentStart := 44
    currY := yContentStart + 10

    ; Row 1: Mode
    AddTabControl("Visual", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Mode:")
    ddlMode := DarkDropdown(myGui, xInput, currY, 444, ["Image File", "Solid Color", "Text on Color"], "VisualMode", UpdateVisualControls)
    ddlMode.RegisterToTab(Tabs, "Visual")

    currY += RowH + 5 ; Gap before dynamic area

    ; -- DYNAMIC GROUPS START AT SAME Y --
    dynY := currY

    ; [GROUP 1] IMAGE MODE
    txtImgPath := AddTabControl("Visual", "Text", Format("x{} y{} w60 h{}", xLabel, dynY+3, CtrlH), "Image:")
    edtImage   := AddTabControl("Visual", "Edit", Format("x{} y{} w{} h{} ReadOnly vImageFile", xInput, dynY, wInput, CtrlH))
    btnImage   := SexyButton(myGui, xBtn, dynY-1, wBtn, BtnH+2, "Browse", SelectImage)
    btnImage.RegisterToTab(Tabs, "Visual")

    ; Image Fit Mode (Updated with Margin)
    yFit := dynY + RowH + 5
    txtFitMode := AddTabControl("Visual", "Text", Format("x{} y{} w60 h{}", xLabel, yFit+3, CtrlH), "Fit Mode:")
    
    ; Reduced dropdown width to fit margin
    ddlFitMode := DarkDropdown(myGui, xInput, yFit, 150, ["Fit (Bars)", "Fill (Crop)", "Blurred Fit (Blurred BG)", "Stretch (Distort)"], "ImgFitMode", UpdateVisualControls)
    ddlFitMode.RegisterToTab(Tabs, "Visual")
    
    ; Margin Controls
    txtMargin := AddTabControl("Visual", "Text", Format("x235 y{} w45 h{}", yFit+3, CtrlH), "Margin:")
    edtMargin := AddTabControl("Visual", "Edit", Format("x280 y{} w35 h{} vImgMargin Number", yFit, CtrlH), "0")
    txtPx     := AddTabControl("Visual", "Text", Format("x317 y{} w20 h{} +0x200 c888888", yFit, CtrlH), "px")
    
    ; Blur Amount Slider
    txtBlur := AddTabControl("Visual", "Text", Format("x345 y{} w30 h{}", yFit+3, CtrlH), "Blur:")
    sldBlur := myGui.Add("Slider", Format("x380 y{} w140 h{} vImgBlur Range1-50 ToolTip", yFit, CtrlH), 20)
    Tabs.Register("Visual", sldBlur)

    ; [GROUP 2] COLOR / BARS MODE
    ; In "Image File" mode, if Fit (Bars) is selected, we use the same color picker
    txtColor := AddTabControl("Visual", "Text", Format("x{} y{} w60 h{}", xLabel, dynY+RowH*2+10, CtrlH), "Color:")
    ddlColor := DarkDropdown(myGui, xInput, dynY+RowH*2+7, 200, ["Black", "White", "Blue", "Red", "Green", "Custom..."], "ColorSelect", UpdateVisualControls)
    ddlColor.RegisterToTab(Tabs, "Visual")

    txtHex := AddTabControl("Visual", "Text", Format("x300 y{} w30 h{}", dynY+RowH*2+10, CtrlH), "Hex:")
    edtHex := AddFlatEdit(myGui, Format("x{} y{} w70 h{} vCustomHex", 335, dynY+RowH*2+7, CtrlH), "000000")
    btnPick := SexyButton(myGui, 415, dynY+RowH*2+6, 60, BtnH+2, "Pick", (*) => RunColorPicker(edtHex, myGui.Hwnd))
    btnPick.RegisterToTab(Tabs, "Visual")
    Tabs.Register("Visual", edtHex)

    ; [GROUP 3] TEXT MODE (Occupies 2 rows)
    ; Row A: Font & Position
    txtFont := AddTabControl("Visual", "Text", Format("x{} y{} w60 h{}", xLabel, dynY+3, CtrlH), "Font:")
    ddlFont := DarkDropdown(myGui, xInput, dynY, 190, ["Arial", "Calibri", "Courier New", "Impact", "Segoe UI"], "FontSelect")
    ddlFont.RegisterToTab(Tabs, "Visual")
    ddlFont.SetVisible(false)

    txtTextPos := AddTabControl("Visual", "Text", Format("x290 y{} w30 h{}", dynY+3, CtrlH), "Pos:")
    ddlTextPos := DarkDropdown(myGui, 325, dynY, 198, ["Center", "Top Left", "Top Right", "Bottom Left", "Bottom Right"], "TextPosition")
    ddlTextPos.RegisterToTab(Tabs, "Visual")
    ddlTextPos.SetVisible(false)

    ; Row B: The Text
    yText := dynY + RowH + 5
    txtText := AddTabControl("Visual", "Text", Format("x{} y{} w60 h{}", xLabel, yText, CtrlH), "Text:")
    edtText := AddTabControl("Visual", "Edit", Format("x{} y{} w{} r3 vTextContent Hidden Multi WantReturn -VScroll", xInput, yText, 444), "My Audio Track`nArtist Name")

    ; -- FADE SECTION (Bottom of Tab) --
    yFade := dynY + (RowH * 3) + 18

    ; Line 1: Checkbox | Type | Time | Dur
    chkFade := myGui.Add("Checkbox", Format("x{} y{} w80 h{} vEnableFade c{} Background{}", xLabel+65, yFade, CtrlH, Theme.Text, Theme.Bg), "Fade Out")
    SetDarkControl(chkFade) 
    Tabs.Register("Visual", chkFade)

    txtFadeType := AddTabControl("Visual", "Text", Format("x225 y{} w35 h{}", yFade+4, CtrlH), "Type:")
    ddlFadeType := DarkDropdown(myGui, 265, yFade-1, 90, ["To Black", "To Color", "To Image"], "FadeType", UpdateVisualControls)
    ddlFadeType.RegisterToTab(Tabs, "Visual")

    txtFadeAt := AddTabControl("Visual", "Text", Format("x365 y{} w20 h{}", yFade+3, CtrlH), "At:")
    edtFadeTime := AddTabControl("Visual", "Edit", Format("x385 y{} w35 h{} vFadeSeconds Number", yFade, CtrlH), "10")

    txtFadeDur := AddTabControl("Visual", "Text", Format("x427 y{} w30 h{}", yFade+3, CtrlH), "Dur:")
    edtFadeDur := AddTabControl("Visual", "Edit", Format("x455 y{} w35 h{} vFadeDuration Number", yFade, CtrlH), "2")
    txtFadeS := AddTabControl("Visual", "Text", Format("x495 y{} w10 h{}", yFade+3, CtrlH), "s")

    ; Line 2: Optional Targets (Color/Image)
    yFade2 := yFade + RowH

    ; Color Target
    txtFadeColHex := AddTabControl("Visual", "Text", Format("x{} y{} w35 h{}", xInput, yFade2+3, CtrlH), "Hex:")
    edtFadeColHex := AddTabControl("Visual", "Edit", Format("x{} y{} w60 h{} vFadeColorHex Hidden", xInput+40, yFade2, CtrlH), "FFFFFF")
    btnFadeColPick := SexyButton(myGui, xInput+110, yFade2-1, 50, BtnH+2, "Pick", (*) => RunColorPicker(edtFadeColHex, myGui.Hwnd))
    btnFadeColPick.RegisterToTab(Tabs, "Visual")
    btnFadeColPick.Visible := false

    ; Image Target
    txtFadeImg := AddTabControl("Visual", "Text", Format("x{} y{} w65 h{}", xLabel, yFade2+3, CtrlH), "End Img:")
    edtFadeImg := AddTabControl("Visual", "Edit", Format("x{} y{} w330 h{} vFadeImgFile ReadOnly Hidden", xInput-5, yFade2, CtrlH), "")
    btnFadeImgBrowse := SexyButton(myGui, xBtn, yFade2-1, wBtn, BtnH+2, "Browse", SelectFadeImage)
    btnFadeImgBrowse.RegisterToTab(Tabs, "Visual")
    btnFadeImgBrowse.Visible := false

    ; ==============================================================================
    ; TAB 3: OUTPUT
    ; ==============================================================================

    currY := yContentStart + 10

    AddTabControl("Output", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Format:")
    ddlFormat := DarkDropdown(myGui, xInput, currY, wInput+104, ["MP4", "WebM"], "OutFormat")
    ddlFormat.RegisterToTab(Tabs, "Output")

    currY += RowH+5
    AddTabControl("Output", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Size:")
    ddlRes := DarkDropdown(myGui, xInput, currY, wInput+104, ["Same as Source", "1280x720 (HD)", "1920x1080 (FHD)", "1080x1080 (Square)", "1080x1920 (Vertical)"], "ResOption",, 3)
    ddlRes.RegisterToTab(Tabs, "Output")

    currY += RowH+5
    AddTabControl("Output", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "FPS:")
    ddlFPS := DarkDropdown(myGui, xInput, currY, wInput+104, ["1 fps", "2 fps", "5 fps", "24 fps", "30 fps", "60 fps"], "FpsOption")
    ddlFPS.RegisterToTab(Tabs, "Output")


    ; ==============================================================================
    ; FOOTER (COMPACT)
    ; ==============================================================================
    yFooter := 275 ; Adjusted for new image settings

    myGui.Add("Text", Format("x0 y{} w{} h65 Background{}", yFooter-3, GuiWidth, Theme.DarkPanel), "")

    ; Left side: Save/Load (Smaller buttons)
    SexyButton(myGui, 10, yFooter+5, 100, 30, "Save", SaveTemplate)
    SexyButton(myGui, 120, yFooter+5, 100, 30, "Load", LoadTemplate)

    ; Right side: Actions
    SexyButton(myGui, 290, yFooter+5, 110, 30, "Preview", GeneratePreview)
    btnCreate := SexyButton(myGui, 410, yFooter+5, 120, 30, "Create Video", StartConversion)
    btnCancel := SexyButton(myGui, 410, yFooter+5, 120, 30, "Cancel", CancelConversion)
    btnCancel.Visible := false
    btnCreate.Beautify()
    ;btnCancel.Beautify(Theme.AltAccent)
    btnCancel.setBorders([Theme.AltAccent,Theme.AltAccent,Theme.AltAccent,Theme.AltAccent])
    btnCancel.SetTextColour(Theme.AltAccent)


    yStatus := yFooter + 38
    progressBar := myGui.Add("Progress", Format("x0 y{} w{} h3 c{} Background{}", yStatus, GuiWidth, Theme.Accent, Theme.DarkPanel, "Range0-100 vMyProgress"), 0)

    myGui.SetFont("s8 c" Theme.Text, "Fixedsys")
    sb := myGui.Add("Text", Format("x0 y{} w{} h20 c{} Background{} +0x200 Center vStatusText", yStatus+3, GuiWidth, Theme.Accent, Theme.StatusBg), "Idle")
    myGui.SetFont("s10 c" Theme.Text, "Segoe UI")

    Tabs.Switch("Audio")
    myGui.Show(Format("w{} h{}", GuiWidth, yStatus + 23))

    ; ==============================================================================
    ; GUI HELPERS
    ; ==============================================================================
    AddTabControl(tabName, ctrlType, options, text := "") {
        if (ctrlType == "Edit")
            c := AddFlatEdit(myGui, options, text)
        else
            c := myGui.Add(ctrlType, options " Background" Theme.Bg, text)
        Tabs.Register(tabName, c)
        return c
    }

    OnTabChanged(newTabName) {
        if (newTabName == "Visual")
            UpdateVisualControls()
    }

    UpdateVisualControls(*) {
        if (Tabs.Current != "Visual")
            return

        mode := ddlMode.Text
        fitMode := ddlFitMode.Text
        
        ; Define groups (References to global control variables)
        grpImage := [txtImgPath, edtImage, btnImage, txtFitMode, ddlFitMode, txtMargin, edtMargin, txtPx]
        grpBlur  := [txtBlur, sldBlur]
        grpColor := [txtColor, ddlColor]
        grpHex     := [txtHex, edtHex, btnPick]
        grpText  := [txtText, edtText, txtFont, ddlFont, txtTextPos, ddlTextPos]
        grpFadeColor := [txtFadeColHex, edtFadeColHex, btnFadeColPick]
        grpFadeImg   := [txtFadeImg, edtFadeImg, btnFadeImgBrowse]
        
        ; Helper to toggle visibility
        SetVis(list, show) {
            for c in list
                try (HasProp(c,"SetVisible") ? c.SetVisible(show) : c.Visible := show)
        }

        if (mode == "Image File") {
            SetVis(grpImage, true)
            SetVis(grpText, false)
            SetVis(grpBlur, (fitMode == "Blurred Fit (Blurred BG)"))
            
            ; Show color picker if "Fit (Bars)" is selected OR if "Solid Color" is mode
            showColor := (fitMode == "Fit (Bars)")
            SetVis(grpColor, showColor)
            SetVis(grpHex, showColor && ddlColor.Text == "Custom...")
            
            fadeMode := ddlFadeType.Text
            SetVis(grpFadeColor, (fadeMode == "To Color"))
            SetVis(grpFadeImg, (fadeMode == "To Image"))
        } else {
            SetVis(grpImage, false)
            SetVis(grpBlur, false)
            SetVis(grpFadeColor, false)
            SetVis(grpFadeImg, false)
            
            SetVis(grpColor, (mode == "Solid Color"))
            SetVis(grpHex, (mode == "Solid Color" && ddlColor.Text == "Custom..."))
            SetVis(grpText, (mode == "Text on Color"))
        }
    }

    ; ==============================================================================
    ; APPLICATION SPECIFIC FFmpeg LOGIC
    ; ==============================================================================

    SelectAudio(*) {
        path := FileSelect(1, , "Select Audio", "Audio (*.mp3; *.wav; *.aac; *.m4a; *.ogg; *.flac)")
        if path 
            edtAudio.Value := path
    }

    SelectImage(*) {
        path := FileSelect(1, , "Select Image", "Images (*.jpg; *.jpeg; *.png; *.bmp; *.gif)")
        if path
            edtImage.Value := path
    }

    SelectFadeImage(*) {
        path := FileSelect(1, , "Select Image To Fade To", "Images (*.jpg; *.jpeg; *.png; *.bmp; *.gif)")
        if path
            edtFadeImg.Value := path
    }

    HandleDropFiles(guiObj, ctrlObj, fileArray, x, y) {
        for i, filePath in fileArray {
            SplitPath(filePath, , , &ext)
            ext := StrLower(ext)
            if (ext = "mp3" || ext = "wav" || ext = "aac" || ext = "m4a" || ext = "ogg" || ext = "flac") {
                edtAudio.Value := filePath
                Tabs.Switch("Audio")
            } else if (ext = "jpg" || ext = "jpeg" || ext = "png" || ext = "bmp" || ext = "gif") {
                edtImage.Value := filePath
                ddlMode.Text := "Image File"
                Tabs.Switch("Visual")
            }
        }
    }

    ; ------------------------------------------------------------------------------
    ; COMMAND BUILDER
    ; ------------------------------------------------------------------------------
    BuildFFmpegInputs(saved, isPreview) {
        cmdArgs := []
        
        ; --- Helper: Resolution & FPS ---
        fpsVal := "5"
        if RegExMatch(saved.FpsOption, "^\d+", &m)
            fpsVal := m[0]
            
        ; Parse Resolution Container
        contW := 1280
        contH := 720
        
        if (saved.ResOption != "Same as Source") {
            if RegExMatch(saved.ResOption, "(\d+)x(\d+)", &m) {
                contW := Integer(m[1]), contH := Integer(m[2])
                if (Mod(contW, 2))
                    contW--
                if (Mod(contH, 2))
                    contH--
            }
        }
        
        contResString := contW "x" contH
        
        ; Parse Margin & Inner Resolution
        margin := 0
        if (saved.HasProp("ImgMargin") && IsNumber(saved.ImgMargin))
            margin := Integer(saved.ImgMargin)
            
        innerW := contW - (margin * 2)
        innerH := contH - (margin * 2)
        if (innerW < 2)
            innerW := 2
        if (innerH < 2)
            innerH := 2
        
        innerResString := innerW "x" innerH
        
        ; Scaling Function Helper (Updated for Margin logic)
        GetScaleStr(cRes, iRes, mode, barColor := "black", blur := 20) {
            ; FFmpeg scale/pad logic. 
            ; iRes = Inner Box (Image scales to fit this).
            ; cRes = Container Box (Final output size).
            ; Pad logic uses (ow-iw)/2 which centers inner in outer.
            
            cRes := StrReplace(cRes, "x", ":")
            iRes := StrReplace(iRes, "x", ":")
            
            if (mode == "Fit (Bars)") {
                return "scale=" iRes ":force_original_aspect_ratio=decrease,pad=" cRes ":(ow-iw)/2:(oh-ih)/2:color=" barColor
            } else if (mode == "Fill (Crop)") {
                ; Fill the inner box, then pad to container
                return "scale=" iRes ":force_original_aspect_ratio=increase,crop=" iRes ",pad=" cRes ":(ow-iw)/2:(oh-ih)/2:color=" barColor
            } else if (mode == "Blurred Fit (Blurred BG)") {
                ; Background fills CONTAINER. Foreground fits INNER.
                ; [v1] is BG. Scale to cRes, crop to cRes.
                ; [v2] is FG. Scale to iRes (decrease).
                ; Overlay centers [v2] on [v1].
                return "split[v1][v2];[v1]scale=" cRes ":force_original_aspect_ratio=increase,crop=" cRes ",boxblur=" blur "[bg];[v2]scale=" iRes ":force_original_aspect_ratio=decrease[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2"
            } else { ; Stretch
                return "scale=" iRes ",pad=" cRes ":(ow-iw)/2:(oh-ih)/2:color=" barColor
            }
        }

        ; --- 1. Visual Inputs ---
        isComplexFade := (saved.VisualMode == "Image File" && saved.EnableFade && saved.FadeType == "To Image" && !isPreview)
        filterChain := ""

        if (saved.VisualMode == "Image File") {
            cmdArgs.Push("-loop", "1", "-framerate", fpsVal)
            cmdArgs.Push("-i", Format('"{1}"', saved.ImageFile))
            
            ; Determine Bar Color
            barCol := saved.ColorSelect
            if (barCol == "Custom...")
                barCol := "0x" saved.CustomHex
                
            fitMode := saved.ImgFitMode
            scaleFilter := GetScaleStr(contResString, innerResString, fitMode, barCol, saved.ImgBlur)
            
            if (isComplexFade) {
                cmdArgs.Push("-loop", "1", "-framerate", fpsVal)
                cmdArgs.Push("-i", Format('"{1}"', saved.FadeImgFile))
                
                filterChain := "[0:v]" scaleFilter "[base];"
                filterChain .= "[1:v]" scaleFilter ",format=yuva420p,fade=t=in:st=" saved.FadeSeconds ":d=" saved.FadeDuration ":alpha=1[over];"
                filterChain .= "[base][over]overlay"
            } else {
                filterChain := scaleFilter
                if (saved.EnableFade && !isPreview) {
                    fColor := (saved.FadeType == "To Color") ? "0x" saved.FadeColorHex : "black"
                    filterChain .= ",fade=t=out:st=" . saved.FadeSeconds . ":d=" . saved.FadeDuration . ":color=" fColor
                }
            }
        } else {
            ; Solid Color / Text
            colorName := saved.ColorSelect
            if (colorName == "Custom...")
                colorName := "#" saved.CustomHex
            if !RegExMatch(colorName, "^[A-Za-z]+$") && !InStr(colorName, "0x") && !InStr(colorName, "#")
                colorName := "0x" . colorName
                
            cmdArgs.Push("-f", "lavfi")
            cmdArgs.Push("-i", "color=c=" . colorName . ":s=" . contResString . ":r=" . fpsVal)
        }

        ; --- 2. Audio Inputs (Skip for Preview) ---
        if (!isPreview) {
            if (saved.EnableTrim)
                cmdArgs.Push("-ss", saved.TrimStart, "-to", saved.TrimEnd)
            cmdArgs.Push("-i", Format('"{1}"', saved.AudioFile))
        }

        ; --- 3. Text Overlay ---
        if (saved.VisualMode == "Text on Color" && saved.TextContent != "") {
            textFile := A_Temp "\overlay_text.txt"
            FileDelete(textFile)
            FileAppend(StrReplace(saved.TextContent, "`r", ""), textFile, "UTF-8")
            
            safeTextPath := StrReplace(StrReplace(textFile, "\", "/"), ":", "\:")
            safeFontPath := StrReplace(StrReplace(GetFontFile(saved.FontSelect), "\", "/"), ":", "\:")
            
            Switch saved.TextPosition {
                Case "Top Left":      pos := "x=50:y=50"
                Case "Top Right":     pos := "x=w-text_w-50:y=50"
                Case "Bottom Left":   pos := "x=50:y=h-text_h-50"
                Case "Bottom Right":  pos := "x=w-text_w-50:y=h-text_h-50"
                Default:              pos := "x=(w-text_w)/2:y=(h-text_h)/2" 
            }
            
            drawText := "drawtext=textfile='" safeTextPath "':fontfile='" safeFontPath "':fontcolor=white:fontsize=56:" pos ":text_align=center"
            filterChain := (filterChain != "") ? filterChain "," drawText : drawText
        }

        if (filterChain != "")
            cmdArgs.Push(isComplexFade ? "-filter_complex" : "-vf", Format('"{1}"', filterChain))
            
        return cmdArgs
    }

    ; ------------------------------------------------------------------------------
    ; ACTIONS
    ; ------------------------------------------------------------------------------
    GeneratePreview(*) {
        saved := myGui.Submit(0)
        if (saved.VisualMode == "Image File" && saved.ImageFile == ""){
            Tabs.Switch("Visual")
            return customDialog({message: "Please select an image first"}, darkPreset)
        }
            
        sb.Text := " Generating Preview..."
        previewFile := A_Temp "\preview_" A_TickCount ".jpg"
        
        cmdArgs := BuildFFmpegInputs(saved, true)
        
        try {
            FFWrapper.GeneratePreview(cmdArgs, previewFile)
            sb.Text := " Preview generated."
            Run(previewFile)
        } catch as e {
        
            customDialog({title:"Error",message:"Preview Failed",detail: e.Message}, errorPreset)
            sb.Text := " Preview failed."
            ;customDialog({title:"Error",message: e.Message}, darkPreset)
        }
    }

    StartConversion(*) {
        saved := myGui.Submit(0)
        
        if (saved.AudioFile == "") {
            Tabs.Switch("Audio")
            return customDialog({message: "Please select an audio file first"}, darkPreset)
        }
        
        if (saved.VisualMode == "Image File" && saved.ImageFile == ""){
            Tabs.Switch("Visual")
            return customDialog({message: "Please select an image first"}, darkPreset)
        }
        
        ; Determine Output
        defaultExt := (saved.OutFormat == "MP4") ? "mp4" : "webm"
        SplitPath(saved.AudioFile, , &dir, , &nameNoExt)
        outputFile := FileSelect("S", dir "\" nameNoExt "_video." defaultExt, "Save Video As", "Video (*." defaultExt ")")
        if (outputFile == "")
            return
        if !RegExMatch(outputFile, "\." defaultExt "$")
            outputFile .= "." defaultExt

        ; Build Command Args
        cmdArgs := []
        cmdArgs.Push("-y")
        cmdArgs.Push(BuildFFmpegInputs(saved, false)*) ; Spread inputs

        ; Output Codecs
        if (saved.OutFormat == "MP4") {
            cmdArgs.Push("-c:v", "libx264", "-tune", "stillimage", "-pix_fmt", "yuv420p")
            if (saved.AudioQuality == "Copy (Lossless/Fast)")
                cmdArgs.Push("-c:a", "copy") 
            else {
                bitrate := InStr(saved.AudioQuality, "320") ? "320k" : InStr(saved.AudioQuality, "128") ? "128k" : "192k"
                cmdArgs.Push("-c:a", "aac", "-b:a", bitrate)
            }
        } else {
            cmdArgs.Push("-c:v", "libvpx-vp9")
            bitrate := InStr(saved.AudioQuality, "320") ? "320k" : InStr(saved.AudioQuality, "128") ? "128k" : "192k"
            cmdArgs.Push("-c:a", "libvorbis", "-b:a", bitrate)
        }
        
        cmdArgs.Push("-shortest")
        
        ; Setup UI for Running
        btnCreate.Visible := false
        
        btnCancel.Visible := true
        
        sb.Text := " Initializing..."
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
            btnCreate.Visible := true
            
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

        FFWrapper.Run(cmdArgs, outputFile, OnProgress, OnFinish)
    }

    ResetButtons() {
        btnCancel.Visible := false
        btnCreate.Visible := true
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
        
        ;errGui := Gui(, "FFmpeg Error Log")
        ;errGui.BackColor := Theme.Bg
        ;errGui.SetFont("c" Theme.Text)
        ;errGui.Add("Edit", "w600 h400 ReadOnly Background" Theme.Panel " c" Theme.Text, logContent)
        ;errGui.Show()
    }

    SaveTemplate(*) {
        path := FileSelect("S", "MySettings.ini", "Save Template", "Settings (*.ini)")
        if (!path)
            return
        saved := myGui.Submit(0)
        for k, v in saved.OwnProps()
            IniWrite(StrReplace(v, "`n", "||"), path, "Settings", k)
        sb.Text := " Settings Saved!"
    }

    LoadTemplate(*) {
        path := FileSelect(1, , "Load Template", "Settings (*.ini)")
        if (!path)
            return
        try {
            saved := myGui.Submit(0)
            for k, v in saved.OwnProps() {
                try {
                    val := IniRead(path, "Settings", k)
                    try {
                        ctrl := myGui[k]
                        if (ctrl.Type == "Checkbox")
                            ctrl.Value := Integer(val)
                        else 
                            ctrl.Value := StrReplace(val, "||", "`n")
                            
                        ; Handle Dropdowns specially (Custom Control Text property)
                        if (InStr(k, "AudioQuality") || InStr(k, "VisualMode") || InStr(k, "ResOption"))
                            try ddl%k%.Text := val ; Try to find variable by name if logic permits
                    }
                }
            }
            ; Specific reloads for Dropdowns (since we use custom wrappers)
            try ddlQuality.Text := IniRead(path, "Settings", "AudioQuality")
            try ddlMode.Text    := IniRead(path, "Settings", "VisualMode")
            try ddlFitMode.Text := IniRead(path, "Settings", "ImgFitMode")
            try ddlFadeType.Text := IniRead(path, "Settings", "FadeType")
            try ddlColor.Text   := IniRead(path, "Settings", "ColorSelect")
            try ddlFont.Text    := IniRead(path, "Settings", "FontSelect")
            try ddlTextPos.Text := IniRead(path, "Settings", "TextPosition")
            try ddlFormat.Text  := IniRead(path, "Settings", "OutFormat")
            try ddlRes.Text     := IniRead(path, "Settings", "ResOption")
            try ddlFPS.Text     := IniRead(path, "Settings", "FpsOption")
            
            Tabs.Switch(Tabs.Current)
            sb.Text := " Settings Loaded!"
        }
    }
}
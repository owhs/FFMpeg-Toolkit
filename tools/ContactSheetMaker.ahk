/*
    FFmpeg Contact Sheet & Thumbnail Maker (AHK v2)
    -----------------------------------------------
    Batch creates video contact sheets (grids), strips, or thumbnails.
    Features: Grid/Strip modes, Burst capture, Custom Layouts, Batch Queue.
    Updated: Uses customDialog for progress tracking.
*/
#Requires AutoHotkey v2.0

#Include ..\lib\utils.ahk
ContactSheetMaker(){
    global AppName := "FFMpeg: Contact Sheets"
    global FileQueue := [] ; Stores the list of files to process
    global BatchIdx := 1
    global BatchTotal := 0
    global BatchLog := ""
    global BatchSuccess := 0
    global BatchErrors := 0
    global LastProbeLog := "" ; Stores log for error debugging
    global ProgDlg := ""      ; Handle for the customDialog progress window

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
    GuiWidth      := 600
    yContentStart := 44   
    RowH          := 32   
    CtrlH         := 24   
    BtnH          := 24   

    ; Columns
    xLabel  := 15
    xInput  := 90
    wInput  := 400 
    xBtn    := 490
    wBtn    := 95

    ; ==============================================================================
    ; TAB NAVIGATION
    ; ==============================================================================
    myGui.Add("Text", Format("x0 y0 w{} h40 Background{}", GuiWidth, Theme.DarkPanel), "")
    Tabs := TabManager(myGui, Theme, OnTabChanged)

    tW := GuiWidth / 3
    Tabs.Add("1. Input Queue", 0,    0, tW, 40, "Input")
    Tabs.Add("2. Grid Layout", tW,   0, tW, 40, "Layout")
    Tabs.Add("3. Output Options", tW*2, 0, tW, 40, "Output")

    ; ==============================================================================
    ; TAB 1: INPUT QUEUE
    ; ==============================================================================
    currY := yContentStart + 10

    ; Queue List View
    AddTabControl("Input", "Text", Format("x{} y{} w{} h{}", xLabel, currY, GuiWidth-30, 20), "Batch Queue (Drag && Drop files here):")

    lvHeight := 220
    lv := myGui.Add("ListView", Format("x{} y{} w{} h{} Background{} c{} -Hdr -Multi", xLabel, currY+25, GuiWidth-30, lvHeight, Theme.Panel, Theme.Text), ["File Path"])
    SetDarkControl(lv)
    Tabs.Register("Input", lv)

    ; Queue Buttons
    btnY := currY + 25 + lvHeight + 10
    btnAdd   := SexyButton(myGui, xLabel, btnY, 120, 30, "Add Files...", SelectFiles)
    btnAdd.RegisterToTab(Tabs, "Input")

    btnClear := SexyButton(myGui, xLabel+130, btnY, 120, 30, "Clear Queue", ClearQueue)
    btnClear.RegisterToTab(Tabs, "Input")

    btnRemove := SexyButton(myGui, GuiWidth-135, btnY, 120, 30, "Remove Selected", RemoveSelected)
    btnRemove.RegisterToTab(Tabs, "Input")

    ; Scope / Limit Controls (Moved from Footer)
    scopeY := btnY + 40
    chkScope := myGui.Add("Checkbox", Format("x{} y{} w100 h{} vUseLimitScope c{} Background{}", xLabel, scopeY+3, CtrlH, Theme.Text, Theme.Bg), "Limit Scope:")
    SetDarkControl(chkScope)
    Tabs.Register("Input", chkScope)

    edtScope := AddTabControl("Input", "Edit", Format("x{} y{} w60 h{} vLimitDuration Number", xLabel+105, scopeY, CtrlH), "60")
    AddTabControl("Input", "Text", Format("x{} y{} w150 h{} +0x200 c888888", xLabel+170, scopeY, CtrlH), "seconds")

    ; Progress Window Option
    chkProgWin := myGui.Add("Checkbox", Format("x{} y{} w200 h{} vShowProgressWin Checked c{} Background{}", 380, scopeY+3, CtrlH, Theme.Text, Theme.Bg), "Show Progress Window")
    SetDarkControl(chkProgWin)
    Tabs.Register("Input", chkProgWin)


    ; ==============================================================================
    ; TAB 2: LAYOUT SETTINGS
    ; ==============================================================================
    currY := yContentStart + 15

    ; Mode Selection
    AddTabControl("Layout", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Mode:")
    ddlMode := DarkDropdown(myGui, xInput, currY, wInput+104, ["Grid (Contact Sheet)", "Horizontal Strip", "Vertical Strip", "Single Image (Thumbnail)"], "LayoutMode", UpdateLayoutUI)
    ddlMode.RegisterToTab(Tabs, "Layout")

    currY += RowH + 10

    ; --- DYNAMIC GRID CONTROLS ---

    ; Columns / Rows
    txtCols := AddTabControl("Layout", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Columns:")
    edtCols := AddTabControl("Layout", "Edit", Format("x{} y{} w60 h{} Number vGridCols", xInput, currY, CtrlH), "4")

    txtRows := AddTabControl("Layout", "Text", Format("x170 y{} w40 h{}", currY+3, CtrlH), "Rows:")
    edtRows := AddTabControl("Layout", "Edit", Format("x210 y{} w60 h{} Number vGridRows", currY, CtrlH), "4")

    ; Calculated Total
    txtTotalInfo := AddTabControl("Layout", "Text", Format("x290 y{} w200 h{} c888888 +0x200", currY, CtrlH), "= 16 Frames")

    ; Burst Mode
    currY += RowH + 5
    chkBurst := myGui.Add("Checkbox", Format("x{} y{} w120 h{} vEnableBurst c{} Background{}", xInput, currY, CtrlH, Theme.Text, Theme.Bg), "Burst Mode")
    SetDarkControl(chkBurst)
    Tabs.Register("Layout", chkBurst)
    chkBurst.OnEvent("Click", UpdateLayoutUI)

    txtBurstInt := AddTabControl("Layout", "Text", Format("x210 y{} w50 h{}", currY+3, CtrlH), "Interval:")
    edtBurstInt := AddTabControl("Layout", "Edit", Format("x265 y{} w50 h{} vBurstInterval", currY, CtrlH), "1.0")
    txtBurstS   := AddTabControl("Layout", "Text", Format("x320 y{} w20 h{}", currY+3, CtrlH), "s")

    ; Visual Style Group
    currY += RowH + 10
    AddTabControl("Layout", "Text", Format("x{} y{} w{} h1 Background{}", xLabel, currY-5, GuiWidth-(xLabel*2), Theme.Panel), "") ; Divider

    ; Tile Size & Sizing Mode
    AddTabControl("Layout", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Tile Size:")
    edtTileW := AddTabControl("Layout", "Edit", Format("x{} y{} w45 h{} Number vTileWidth", xInput, currY, CtrlH), "320")
    AddTabControl("Layout", "Text", Format("x140 y{} w10 h{}", currY+3, CtrlH), "x")
    edtTileH := AddTabControl("Layout", "Edit", Format("x155 y{} w45 h{} Number vTileHeight", currY, CtrlH), "180")

    AddTabControl("Layout", "Text", Format("x220 y{} w35 h{}", currY+3, CtrlH), "Fit:")
    ddlAspect := DarkDropdown(myGui, 260, currY, 130, ["Pad to Fit", "Crop to Fill", "Stretch (Distort)", "Original Ratio"], "AspectRatio")
    ddlAspect.RegisterToTab(Tabs, "Layout")

    currY += RowH + 5
    AddTabControl("Layout", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Padding:")
    edtPad := AddTabControl("Layout", "Edit", Format("x{} y{} w45 h{} Number vPadding", xInput, currY, CtrlH), "2")

    AddTabControl("Layout", "Text", Format("x220 y{} w60 h{}", currY+3, CtrlH), "Bg Color:")
    edtBgHex := AddTabControl("Layout", "Edit", Format("x280 y{} w70 h{} vBgColor", currY, CtrlH), "000000")
    btnPick := SexyButton(myGui, 360, currY-1, 60, BtnH+2, "Pick", (*) => RunColorPicker(edtBgHex, myGui.Hwnd))
    btnPick.RegisterToTab(Tabs, "Layout")

    ; --- NEW OPTIONS (Metadata/Timestamps) ---
    currY += RowH + 5
    chkHeader := myGui.Add("Checkbox", Format("x{} y{} w180 h{} vAddHeader c{} Background{}", xInput, currY, CtrlH, Theme.Text, Theme.Bg), "Add Header (Metadata)")
    SetDarkControl(chkHeader)
    Tabs.Register("Layout", chkHeader)

    chkTime := myGui.Add("Checkbox", Format("x{} y{} w180 h{} vAddTimestamp c{} Background{}", xInput+200, currY, CtrlH, Theme.Text, Theme.Bg), "Burn Timestamps")
    SetDarkControl(chkTime)
    Tabs.Register("Layout", chkTime)


    ; ==============================================================================
    ; TAB 3: OUTPUT OPTIONS
    ; ==============================================================================
    currY := yContentStart + 15

    ; Format
    AddTabControl("Output", "Text", Format("x{} y{} w70 h{}", xLabel, currY+3, CtrlH), "Format:")
    ddlFormat := DarkDropdown(myGui, xInput, currY, wInput+104, ["JPG (Image)", "PNG (Image)", "WEBP (Image)", "WEBM (Video Container)"], "OutFormat")
    ddlFormat.RegisterToTab(Tabs, "Output")

    currY += RowH + 5

    ; Dual Export
    chkDual := myGui.Add("Checkbox", Format("x{} y{} w300 h{} vDualExport c{} Background{}", xInput, currY, CtrlH, Theme.Text, Theme.Bg), "Also export single thumbnail (Main Frame)")
    SetDarkControl(chkDual)
    Tabs.Register("Output", chkDual)
    chkDual.OnEvent("Click", UpdateOutputUI)

    ; Thumbnail Settings (Dynamic)
    thumbY := currY + RowH
    txtThumbTime := AddTabControl("Output", "Text", Format("x{} y{} w40 h{}", xInput+20, thumbY+3, CtrlH), "At:")
    edtThumbTime := AddTabControl("Output", "Edit", Format("x{} y{} w60 h{} vThumbTime", xInput+55, thumbY, CtrlH), "20%")

    txtThumbName := AddTabControl("Output", "Text", Format("x{} y{} w50 h{}", xInput+130, thumbY+3, CtrlH), "Name:")
    edtThumbName := AddTabControl("Output", "Edit", Format("x{} y{} w200 h{} vThumbPattern", xInput+175, thumbY, CtrlH), "%original%_thumb")

    grpThumb := [txtThumbTime, edtThumbTime, txtThumbName, edtThumbName]

    currY += RowH + 10 + RowH ; Extra space for thumb settings
    AddTabControl("Output", "Text", Format("x{} y{} w{} h1 Background{}", xLabel, currY-5, GuiWidth-(xLabel*2), Theme.Panel), "")

    ; Output Folder
    AddTabControl("Output", "Text", Format("x{} y{} w70 h{}", xLabel, currY+3, CtrlH), "Folder:")
    edtOutDir := AddTabControl("Output", "Edit", Format("x{} y{} w335 h{} vOutputDir ReadOnly", xInput, currY, CtrlH), "Same as Input Source")
    btnDir := SexyButton(myGui, 435, currY-1, 90, BtnH+2, "Change", SelectOutDir)
    btnDir.RegisterToTab(Tabs, "Output")

    currY += RowH + 5
    chkSubDir := myGui.Add("Checkbox", Format("x{} y{} w300 h{} vCreateSubDir c{} Background{}", xInput, currY, CtrlH, Theme.Text, Theme.Bg), "Create folder for each file")
    SetDarkControl(chkSubDir)
    Tabs.Register("Output", chkSubDir)

    ; Naming Pattern
    currY += RowH + 15
    AddTabControl("Output", "Text", Format("x{} y{} w70 h{}", xLabel, currY+3, CtrlH), "Pattern:")
    edtPattern := AddTabControl("Output", "Edit", Format("x{} y{} w435 h{} vNamePattern", xInput, currY, CtrlH), "%original%_contact")

    currY += RowH
    AddTabControl("Output", "Text", Format("x{} y{} w435 h{} c888888", xInput, currY, CtrlH), "Variables: %original%, %date%, %time%")

    ; ==============================================================================
    ; FOOTER
    ; ==============================================================================
    yFooter := 400

    myGui.Add("Text", Format("x0 y{} w{} h65 Background{}", yFooter-3, GuiWidth, Theme.DarkPanel), "")

    ; Presets
    SexyButton(myGui, 10, yFooter+5, 80, 30, "Save", SavePreset)
    SexyButton(myGui, 100, yFooter+5, 80, 30, "Load", LoadPreset)

    ; Actions
    SexyButton(myGui, 390, yFooter+5, 90, 30, "Preview", GeneratePreview)
    btnCreate := SexyButton(myGui, 490, yFooter+5, 100, 30, "Batch", StartBatch)
    btnCreate.Beautify()
    btnCancel := SexyButton(myGui, 490, yFooter+5, 100, 30, "Cancel", CancelBatch)
    btnCancel.Visible := false
    btnCancel.setBorders([Theme.AltAccent,Theme.AltAccent,Theme.AltAccent,Theme.AltAccent])
    btnCancel.SetTextColour(Theme.AltAccent)

    ; Status Bar
    yStatus := yFooter + 38
    progressBar := myGui.Add("Progress", Format("x0 y{} w{} h3 c{} Background{}", yStatus, GuiWidth, Theme.Accent, Theme.DarkPanel, "Range0-100 vMyProgress"), 0)

    myGui.SetFont("s8 c" Theme.Text, "Fixedsys")
    sb := myGui.Add("Text", Format("x0 y{} w{} h20 c{} Background{} +0x200 Center vStatusText", yStatus+3, GuiWidth, Theme.Accent, Theme.StatusBg), "Idle - Queue Empty")

    Tabs.Switch("Input")
    UpdateOutputUI() ; Init visibility
    myGui.Show(Format("w{} h{}", GuiWidth, yStatus + 23))

    ; ==============================================================================
    ; GUI HELPERS & LOGIC
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
        if (newTabName == "Layout")
            UpdateLayoutUI()
        if (newTabName == "Output")
            UpdateOutputUI()
    }

    UpdateLayoutUI(*) {
        saved := myGui.Submit(0)
        mode := ddlMode.Text
        
        ; 1. Calculate Total Frames display
        cols := Integer(saved.GridCols)
        rows := Integer(saved.GridRows)
        
        if (mode == "Horizontal Strip") {
            edtCols.Enabled := true
            edtRows.Enabled := false
            edtRows.Value := 1
            txtTotalInfo.Text := "= " cols " Frames (Strip)"
        } else if (mode == "Vertical Strip") {
            edtCols.Enabled := false
            edtRows.Enabled := true
            edtCols.Value := 1
            txtTotalInfo.Text := "= " rows " Frames (Strip)"
        } else if (mode == "Single Image (Thumbnail)") {
            edtCols.Enabled := false
            edtRows.Enabled := false
            edtCols.Value := 1
            edtRows.Value := 1
            txtTotalInfo.Text := "= 1 Frame (Main)"
            chkBurst.Value := 0
            chkBurst.Enabled := false
        } else {
            ; Grid
            edtCols.Enabled := true
            edtRows.Enabled := true
            txtTotalInfo.Text := "= " (cols * rows) " Frames"
            chkBurst.Enabled := true
        }

        ; Burst UI
        isBurst := (chkBurst.Value && chkBurst.Enabled)
        txtBurstInt.Visible := isBurst
        edtBurstInt.Visible := isBurst
        txtBurstS.Visible   := isBurst
    }

    UpdateOutputUI(*) {
        saved := myGui.Submit(0)
        showThumb := (saved.DualExport)
        for c in grpThumb 
            c.Visible := showThumb
    }

    SelectOutDir(*) {
        dir := DirSelect()
        if dir
            edtOutDir.Value := dir
    }

    SelectFiles(*) {
        files := FileSelect("M", , "Select Video Files", "Videos (*.mp4; *.mkv; *.webm; *.avi; *.mov)")
        if (files.Length < 1)
            return
            
        for f in files {
            FileQueue.Push(f)
            lv.Add(, f)
        }
        sb.Text := " Queue: " FileQueue.Length " files."
    }

    ClearQueue(*) {
        global FileQueue ; REQUIRED: Access global var to reset it
        FileQueue := []
        lv.Delete()
        sb.Text := " Queue Cleared."
    }

    RemoveSelected(*) {
        row := lv.GetNext(0)
        if (row == 0) 
            return
        
        lv.Delete(row)
        FileQueue.RemoveAt(row)
        sb.Text := " Queue: " FileQueue.Length " files."
    }

    HandleDropFiles(guiObj, ctrlObj, fileArray, x, y) {
        for f in fileArray {
            SplitPath(f, , , &ext)
            if InStr("mp4,mkv,webm,avi,mov,flv,wmv", StrLower(ext)) {
                FileQueue.Push(f)
                lv.Add(, f)
            }
        }
        sb.Text := " Queue: " FileQueue.Length " files."
        Tabs.Switch("Input")
    }

    ; ==============================================================================
    ; PRESET SYSTEM
    ; ==============================================================================
    SavePreset(*) {
        path := FileSelect("S", "ContactSheet.ini", "Save Preset", "Settings (*.ini)")
        if (!path)
            return
        saved := myGui.Submit(0)
        
        for k, v in saved.OwnProps()
            IniWrite(StrReplace(v, "`n", "||"), path, "Settings", k)
        
        ; Dropdowns
        IniWrite(ddlMode.Text, path, "Settings", "LayoutMode")
        IniWrite(ddlFormat.Text, path, "Settings", "OutFormat")
        IniWrite(ddlAspect.Text, path, "Settings", "AspectRatio")
        
        sb.Text := " Preset Saved!"
    }

    LoadPreset(*) {
        path := FileSelect(1, , "Load Preset", "Settings (*.ini)")
        if (!path)
            return
        try {
            saved := myGui.Submit(0)
            for k, v in saved.OwnProps() {
                try {
                    val := IniRead(path, "Settings", k)
                    ctrl := myGui[k]
                    if (ctrl.Type == "Checkbox")
                        ctrl.Value := Integer(val)
                    else 
                        ctrl.Value := StrReplace(val, "||", "`n")
                }
            }
            try ddlMode.Text := IniRead(path, "Settings", "LayoutMode")
            try ddlFormat.Text := IniRead(path, "Settings", "OutFormat")
            try ddlAspect.Text := IniRead(path, "Settings", "AspectRatio")
            
            UpdateLayoutUI()
            UpdateOutputUI()
            sb.Text := " Preset Loaded!"
        }
    }

    ; ==============================================================================
    ; PROCESSING LOGIC (Engine)
    ; ==============================================================================

    GetDuration(file) {
        global LastProbeLog
        LastProbeLog := ">>> Probe Start: " file "`n"
        
        ; 1. Determine Correct Probe Command
        ffprobeCmd := ""
        if InStr(FFWrapper.ffmpegPath, "\") {
            SplitPath(FFWrapper.ffmpegPath, , &dir)
            checkPath := dir "\ffprobe.exe"
            if FileExist(checkPath)
                ffprobeCmd := Format('"{1}"', checkPath)
        } 
        if (ffprobeCmd == "")
            ffprobeCmd := "ffprobe" 
            
        LastProbeLog .= "Attempting Command: " ffprobeCmd "`n"

        ; 2. Run FFprobe
        probeOut := A_Temp "\ffprobe_out_" A_TickCount ".txt"
        probeErr := A_Temp "\ffprobe_err_" A_TickCount ".txt"
        try FileDelete(probeOut)
        try FileDelete(probeErr)
        
        cmd := Format('{1} -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "{2}" > "{3}" 2> "{4}"', ffprobeCmd, file, probeOut, probeErr)
        try RunWait(A_ComSpec ' /c "' cmd '"', , "Hide")
        
        if FileExist(probeOut) {
            val := FileRead(probeOut)
            LastProbeLog .= "FFprobe Output: " val "`n"
            FileDelete(probeOut)
            if IsNumber(Trim(val)) {
                if FileExist(probeErr)
                    FileDelete(probeErr)
                return Float(Trim(val))
            }
        }
        if FileExist(probeErr) {
            errVal := FileRead(probeErr)
            LastProbeLog .= "FFprobe Error Output: " errVal "`n"
            FileDelete(probeErr)
        }

        ; 3. Fallback to FFmpeg -i
        LastProbeLog .= "Method: FFmpeg -i Fallback`n"
        logFile := A_Temp "\dur_probe_" A_TickCount ".txt"
        try FileDelete(logFile)
        
        ffExe := FFWrapper.ffmpegPath
        if InStr(ffExe, " ") && !InStr(ffExe, '"')
            ffExe := '"' ffExe '"'
        cmd := Format('{1} -hide_banner -i "{2}" 2> "{3}"', ffExe, file, logFile)
        try RunWait(A_ComSpec ' /c "' cmd '"', , "Hide")
        
        dur := 0
        if FileExist(logFile) {
            content := FileRead(logFile)
            LastProbeLog .= "FFmpeg Log: " SubStr(content, -500) "`n"
            FileDelete(logFile)
            if RegExMatch(content, "Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)", &m) {
                dur := (m[1]*3600) + (m[2]*60) + Float(m[3])
            }
        } else {
            LastProbeLog .= "FFmpeg Log File not created. CMD was: " cmd "`n"
        }
        return dur
    }

    FormatDuration(s) {
        h := Floor(s / 3600)
        m := Floor(Mod(s, 3600) / 60)
        sec := Floor(Mod(s, 60))
        return Format("{:02}:{:02}:{:02}", h, m, sec)
    }

    GetScaleFilter(w, h, mode) {
        if (mode == "Pad to Fit")
            return Format("scale={1}:{2}:force_original_aspect_ratio=decrease,pad={1}:{2}:(ow-iw)/2:(oh-ih)/2", w, h)
        else if (mode == "Crop to Fill")
            return Format("scale={1}:{2}:force_original_aspect_ratio=increase,crop={1}:{2}", w, h)
        else if (mode == "Stretch (Distort)")
            return Format("scale={1}:{2}", w, h)
        else ; Original Ratio (Variable)
            return Format("scale={1}:-1", w)
    }

    TruncateText(txt, maxLen := 60) {
        if (StrLen(txt) > maxLen)
            return SubStr(txt, 1, maxLen-3) "..."
        return txt
    }

    SanitizeForFFmpeg(str) {
        str := StrReplace(str, ":", "\:") 
        str := StrReplace(str, "'", "")
        str := StrReplace(str, ",", "\,") 
        return str
    }

    ; --------------------------------------------------------------------------------
    ; FAST CAPTURE & STITCH ENGINE (v3.9)
    ; --------------------------------------------------------------------------------
    RunFastEngine(saved, inputFile, outputFile, metadataStr, metaInfoStr, overrideDuration, cachedDuration, isPreview, onStatusCallback) {
        global FFWrapper
        
        ; 1. Calculate Duration & Steps
        duration := (cachedDuration > 0) ? cachedDuration : GetDuration(inputFile)
        if (duration == 0) {
            if isPreview
                customDialog({title:"Probe Failed", message:"Duration 0", detail:LastProbeLog}, errorPreset)
            throw Error("Probe Failed (Handled)")
        }
        
        effDur := (overrideDuration > 0 && overrideDuration < duration) ? overrideDuration : duration
        
        ; Determine Count
        cols := Integer(saved.GridCols)
        rows := Integer(saved.GridRows)
        totalFrames := cols * rows
        
        if (saved.LayoutMode == "Single Image (Thumbnail)") {
            cols := 1, rows := 1, totalFrames := 1
        }
        
        step := 0
        if (saved.EnableBurst && saved.LayoutMode != "Single Image (Thumbnail)") {
            step := Float(saved.BurstInterval)
        } else {
            ; Use a safer duration buffer (0.5s instead of 0.1s) to avoid seeking past EOF
            safeDuration := effDur > 1 ? effDur - 0.5 : effDur * 0.90
            divisor := (totalFrames > 1) ? (totalFrames - 1) : 1
            step := safeDuration / divisor
        }
        
        ; 2. Prepare Temp Dir
        tempDir := A_Temp "\AHK_SheetMaker_" A_TickCount
        DirCreate(tempDir)
        
        ; 3. Capture Loop (Fast Seek)
        ; PRE-CALCULATE SIZES IN AHK
        tileW := Integer(saved.TileWidth)
        tileH := Integer(saved.TileHeight)
        
        ; Timestamp font size logic (h/20)
        tsFontSize := Max(12, Integer(tileH / 20))
        
        scaleF := GetScaleFilter(tileW, tileH, saved.AspectRatio)
        
        ; tsFilter is now constructed INSIDE loop
        
        fileList := "" 
        
        Loop totalFrames {
            if (FFWrapper.IsCancelled) {
                DirDelete(tempDir, true)
                return false 
            }
            
            frameIdx := A_Index
            timePos := (frameIdx - 1) * step
            
            if (timePos > duration - 0.2)
                timePos := duration - 0.5
            if (timePos < 0)
                timePos := 0
                
            pct := (frameIdx / totalFrames) * 100
            onStatusCallback.Call(pct, Format("Capturing Frame {}/{}", frameIdx, totalFrames))
            
            frameOut := Format("{1}\frame_{2:04}.jpg", tempDir, frameIdx)
            
            safeIn := inputFile
            if InStr(safeIn, " ") && !InStr(safeIn, '"')
                safeIn := '"' safeIn '"'
                
            ; Construct timestamp filter per frame (hardcoded string)
            tsFilter := ""
            if (saved.AddTimestamp) {
                tsString := FormatDuration(timePos)
                tsString := StrReplace(tsString, ":", "\:")
                tsFilter := Format(",drawtext=fontfile='C\:/Windows/Fonts/arial.ttf':text='{1}':x=(w-text_w)/2:y=h-text_h-5:fontsize={2}:fontcolor=white:box=1:boxcolor=black@0.6", tsString, tsFontSize)
            }
                
            vf := scaleF . tsFilter
            
            cmd := ["-ss", timePos, "-i", safeIn, "-q:v", "2", "-vf", vf]
            
            try {
                FFWrapper.GeneratePreview(cmd, frameOut)
                safePath := StrReplace(frameOut, "\", "/")
                fileList .= Format("file '{1}'`nduration 1`n", safePath)
            } catch as e {
                dummyCmd := ["-f", "lavfi", "-i", "color=c=black:s=" tileW "x" tileH]
                try FFWrapper.GeneratePreview(dummyCmd, frameOut)
                safePath := StrReplace(frameOut, "\", "/")
                fileList .= Format("file '{1}'`nduration 1`n", safePath)
            }
        }
        
        if (FFWrapper.IsCancelled) {
            DirDelete(tempDir, true)
            return false 
        }
        
        ; 4. Stitching
        onStatusCallback.Call(100, "Stitching Output...")
        
        isWebM := InStr(saved.OutFormat, "WEBM")
        
        listFile := tempDir "\list.txt"
        FileAppend(fileList, listFile, "UTF-8-RAW")
        
        ffExe := FFWrapper.ffmpegPath
        if InStr(ffExe, " ") && !InStr(ffExe, '"')
            ffExe := '"' ffExe '"'
            
        stitchArgs := "-y -f concat -safe 0 -i " '"' listFile '"'
        filterChain := ""
        
        ; PRE-CALCULATE HEADER SIZES
        ; Total width of grid
        totalW := cols * (tileW + Integer(saved.Padding))
        totalH := rows * (tileH + Integer(saved.Padding))
        
        ; Calculate Header Height & Font Sizes in AHK
        headerH := 0
        if (saved.AddHeader) {
            if (isWebM) {
                ; Video Mode (Single Frame Width)
                totalW := tileW 
                headerH := Max(60, Integer(totalW / 12 * 2.5))
                headFontSize := Max(16, Integer(totalW / 25))
                infoFontSize := Max(12, Integer(totalW / 35))
            } else {
                ; Image Mode (Full Grid Width)
                headerH := Max(60, Integer(totalW / 12))
                headFontSize := Max(14, Integer(totalW / 40))
                infoFontSize := Max(12, Integer(totalW / 55))
            }
        }

        if (isWebM) {
            ; Video Mode
            if (saved.AddHeader) {
                padVideo := Format("pad=iw:ih+{1}:0:{1}:{2}", headerH, "0x" saved.BgColor) 
                sName := SanitizeForFFmpeg(TruncateText(metadataStr, 60))
                sInfo := SanitizeForFFmpeg(metaInfoStr)
                
                drawName := Format(",drawtext=fontfile='C\:/Windows/Fonts/arial.ttf':text='{1}':x=10:y=10:fontsize={2}:fontcolor=white", sName, headFontSize)
                drawInfo := Format(",drawtext=fontfile='C\:/Windows/Fonts/arial.ttf':text='{1}':x=10:y={2}:fontsize={3}:fontcolor=silver", sInfo, headFontSize + 15, infoFontSize)
                filterChain := padVideo drawName drawInfo
            } else {
                filterChain := "null" 
            }
            
            stitchArgs .= " -r 1 -c:v libvpx-vp9 -b:v 0 -crf 30"
            
        } else {
            ; Image Mode (Tile)
            pad := Integer(saved.Padding)
            col := "0x" saved.BgColor
            
            tileExpr := Format("tile={1}x{2}:padding={3}:color={4}", cols, rows, pad, col)
            filterChain := tileExpr
            
            if (saved.AddHeader) {
                padImage := Format(",pad=iw:ih+{1}:0:{1}:{2}", headerH, col)
                sName := SanitizeForFFmpeg(TruncateText(metadataStr, 65))
                sInfo := SanitizeForFFmpeg(metaInfoStr)
                
                drawName := Format(",drawtext=fontfile='C\:/Windows/Fonts/arial.ttf':text='{1}':x=w/50:y=h/{2}:fontsize={3}:fontcolor=white", sName, 20, headFontSize)
                drawInfo := Format(",drawtext=fontfile='C\:/Windows/Fonts/arial.ttf':text='{1}':x=w/50:y=h/{2} + {3} + 5:fontsize={4}:fontcolor=silver", sInfo, 20, headFontSize, infoFontSize)
                filterChain .= padImage drawName drawInfo
            }
        }
        
        if (filterChain != "null")
            stitchArgs .= ' -vf "' filterChain '"'
        
        stitchArgs .= ' "' outputFile '"'
        fullCmd := ffExe " " stitchArgs
        
        stitchLog := A_Temp "\stitch_err_" A_TickCount ".txt"
        fullCmd .= " 2> " '"' stitchLog '"'
        
        try RunWait(A_ComSpec ' /c "' fullCmd '"', , "Hide")
        
        if !FileExist(outputFile) {
            logContent := "No Log Created."
            if FileExist(stitchLog) {
                logContent := FileRead(stitchLog)
                FileDelete(stitchLog)
            }
            ; DEBUG: DO NOT DELETE TEMP DIR ON ERROR for inspection
            ; DirDelete(tempDir, true) 
            
            errDetail := "CMD: " fullCmd "`n`nFFmpeg Log:`n" logContent
            throw Error(errDetail)
        }
        
        if FileExist(stitchLog)
            FileDelete(stitchLog)
            
        DirDelete(tempDir, true)
        return true
    }

    ; --------------------------------------------------------------------------------
    ; PREVIEW & BATCH HANDLERS
    ; --------------------------------------------------------------------------------

    GeneratePreview(*) {
        if (FileQueue.Length == 0)
            return customDialog({message: "Queue is empty."}, darkPreset)
        
        UpdateLayoutUI()
        saved := myGui.Submit(0) ; Capture settings AFTER UI update
        
        overrideDur := 0
        limitText := "Full Video"
        if (saved.UseLimitScope) {
            if IsNumber(saved.LimitDuration) {
                overrideDur := Float(saved.LimitDuration)
                limitText := "Limit: " overrideDur "s"
            }
        }
        
        sb.Text := Format(" Previewing ({1})...", limitText)
        
        inputFile := FileQueue[1]
        SplitPath(inputFile, , , , &inName) 
        ext := InStr(saved.OutFormat, "PNG") ? "png" : InStr(saved.OutFormat, "WEBM") ? "webm" : InStr(saved.OutFormat, "WEBP") ? "webp" : "jpg"
        previewFile := A_Temp "\preview_" A_TickCount "." ext
        
        ; Setup Progress Dialog (Dual bars: Bar 1 unused or constant, Bar 2 active)
        if (saved.ShowProgressWin) {
            progProps := {
                title: "Generating Preview...",
                progress: 0,
                progressText: "Overall",
                progress2: 0,
                progress2Text: TruncateText(inName, 50),
                progress2SubText: "Initializing...",
                buttons: ["&Stop"],
                waitForResponse: false,
                modal: false
            }
            global ProgDlg := customDialog(progProps, progressPreset)
        }

        try {
            dur := GetDuration(inputFile)
            metaStr := "Preview Filename.mp4"
            metaInfo := Format("Size: 124 MB | Duration: {1} | Res: 1920x1080", FormatDuration(dur))
            
            btnCreate.Enabled := false
            
            ; Status Callback
            OnStatus(pct, msg) {
                sb.Text := msg
                
                ; Check if User clicked Stop on the Custom Dialog
                if (saved.ShowProgressWin && ProgDlg && !WinExist(ProgDlg.gui.Hwnd)) {
                     FFWrapper.Stop() ; Trigger stop
                }

                if (saved.ShowProgressWin && ProgDlg && WinExist(ProgDlg.gui.Hwnd)) {
                    ProgDlg.Update.Call(100, "Previewing Single File", "", 1)
                    ProgDlg.Update.Call(pct, TruncateText(inName, 50), msg, 2)
                }
            }
            
            ; Run Fast Engine
            success := RunFastEngine(saved, inputFile, previewFile, metaStr, metaInfo, overrideDur, dur, true, OnStatus)
            
            btnCreate.Enabled := true
            
            ; Close Dialog if it exists
            if (saved.ShowProgressWin && ProgDlg && WinExist(ProgDlg.gui.Hwnd)) {
                ProgDlg.gui.Destroy()
                ProgDlg := ""
            }

            if success {
                sb.Text := " Preview Ready."
                Run(previewFile)
            } else {
                sb.Text := " Preview Cancelled."
            }
            
        } catch as e {
            btnCreate.Enabled := true
            if (saved.ShowProgressWin && ProgDlg && WinExist(ProgDlg.gui.Hwnd)) {
                ProgDlg.gui.Destroy()
                ProgDlg := ""
            }

            sb.Text := " Error."
            if (e.Message == "Probe Failed (Handled)")
                return 
                
            ; Show Stitching Error Detail if available
            customDialog({
                title: "Stitching Failed", 
                message: "FFmpeg failed to assemble the contact sheet.", 
                detail: e.Message,
                width: 600,
                height: 400,
                detailRows: 15
            }, errorPreset)
        }
    }

    ; ==============================================================================
    ; BATCH PROCESSING
    ; ==============================================================================

    StartBatch(*) {
        if (FileQueue.Length == 0)
            return customDialog({message: "Queue is empty."}, darkPreset)
            
        UpdateLayoutUI()
        saved := myGui.Submit(0) ; Capture settings AFTER UI update
        
        btnCreate.Visible := false
        btnCancel.Visible := true
        
        global BatchIdx := 1
        global BatchTotal := FileQueue.Length
        global BatchLog := "Batch Started: " FormatTime() "`n--------------------------------`n"
        global BatchErrors := 0
        global BatchSuccess := 0
        
        if (saved.ShowProgressWin) {
            progProps := {
                title: "Batch Processing",
                progress: 0,
                progressText: "Overall: 0/" BatchTotal,
                progress2: 0,
                progress2Text: "Waiting...",
                progress2SubText: "Initializing...",
                buttons: ["&Stop"],
                waitForResponse: false, 
                ownerHwnd: myGui.Hwnd
            }
            ; Theme matching color
            if (Theme.Accent != "")
                progProps.progressColor := Theme.Accent

            global ProgDlg := customDialog(progProps, progressPreset)
        }
        
        ProcessNextFile(saved)
    }

    ProcessNextFile(saved) {
        global BatchIdx, BatchTotal, BatchLog, BatchSuccess, BatchErrors
        global ProgDlg
        
        ; 1. Check for User Cancellation (Stop Button on Dialog)
        if (saved.ShowProgressWin && ProgDlg && !WinExist(ProgDlg.gui.Hwnd)) {
            CancelBatch()
            return
        }

        if (BatchIdx > BatchTotal || FFWrapper.IsCancelled) {
            FinishBatch()
            return
        }
        
        inputFile := FileQueue[BatchIdx]
        SplitPath(inputFile, , &inDir, &inExt, &inName)
        
        sb.Text := Format(" Processing {} of {}...", BatchIdx, BatchTotal)
        progressBar.Value := ((BatchIdx-1) / BatchTotal) * 100
        
        if (saved.ShowProgressWin && ProgDlg && WinExist(ProgDlg.gui.Hwnd)) {
            overallPct := ((BatchIdx-1) / BatchTotal) * 100
            ProgDlg.Update.Call(overallPct, Format("Overall: {}/{}", BatchIdx, BatchTotal), "", 1)
            ProgDlg.Update.Call(0, TruncateText(inName, 50), "Initializing...", 2)
        }
        
        outDir := (saved.OutputDir == "Same as Input Source") ? inDir : saved.OutputDir
        if (saved.CreateSubDir) {
            outDir .= "\" inName
            if !DirExist(outDir)
                DirCreate(outDir)
        }
        
        baseName := StrReplace(saved.NamePattern, "%original%", inName)
        baseName := StrReplace(baseName, "%date%", FormatTime(, "yyyyMMdd"))
        baseName := StrReplace(baseName, "%time%", FormatTime(, "HHmm"))
        
        ext := InStr(saved.OutFormat, "PNG") ? "png" : InStr(saved.OutFormat, "WEBM") ? "webm" : InStr(saved.OutFormat, "WEBP") ? "webp" : "jpg"
        outputFile := outDir "\" baseName "." ext
        
        overrideDur := 0
        if (saved.UseLimitScope && IsNumber(saved.LimitDuration)) {
            overrideDur := Float(saved.LimitDuration)
        }

        dur := 0
        try {
            if (saved.ShowProgressWin && ProgDlg && WinExist(ProgDlg.gui.Hwnd))
                ProgDlg.Update.Call(, , "Probing File...", 2)
                
            dur := GetDuration(inputFile)
        } catch as e {
            BatchErrors++
            BatchLog .= Format("[{1}/{2}] FAILED Probe: {3}`nError: {4}`n--------------------------------`n", BatchIdx, BatchTotal, inputFile, e.Message)
            BatchIdx++
            ProcessNextFile(saved)
            return
        }
        
        if (dur == 0) {
            BatchErrors++
            BatchLog .= Format("[{1}/{2}] FAILED Probe: {3}`nError: Duration 0 (Unknown)`n--------------------------------`n", BatchIdx, BatchTotal, inputFile)
            BatchIdx++
            ProcessNextFile(saved)
            return
        }

        try fSize := FileGetSize(inputFile) / 1024 / 1024
        catch
            fSize := 0
            
        metaName := Format("{1}.{2}", inName, inExt)
        metaInfo := Format("Size: {1:.2f} MB | Duration: {2}", fSize, FormatDuration(dur))
        
        try {
            ; Progress Callback
            OnBatchStatus(pct, msg) {
                sb.Text := msg
                progressBar.Value := ((BatchIdx-1) / BatchTotal) * 100 + (pct / BatchTotal)
                
                ; Check Cancellation again inside callback
                if (saved.ShowProgressWin && ProgDlg && !WinExist(ProgDlg.gui.Hwnd)) {
                    FFWrapper.Stop() ; Trigger FFmpeg stop
                }

                if (saved.ShowProgressWin && ProgDlg && WinExist(ProgDlg.gui.Hwnd)) {
                    ProgDlg.Update.Call(pct, , msg, 2)
                }
            }
            
            ; RUN FAST ENGINE
            success := RunFastEngine(saved, inputFile, outputFile, metaName, metaInfo, overrideDur, dur, false, OnBatchStatus)
            
            if (success) {
                BatchSuccess++
            } else {
                ; Cancelled or Failed
                if (FFWrapper.IsCancelled) {
                   FinishBatch()
                   return
                }
                BatchErrors++
                BatchLog .= Format("[{1}/{2}] FAILED Convert: {3}`nUnknown Error in Fast Engine`n--------------------------------`n", BatchIdx, BatchTotal, inputFile)
            }
            
            ; Dual Export (Thumbnail)
            if (success && saved.DualExport && saved.LayoutMode != "Single Image (Thumbnail)") {
                if (saved.ShowProgressWin && ProgDlg && WinExist(ProgDlg.gui.Hwnd))
                    ProgDlg.Update.Call(100, , "Generating Thumbnail...", 2)
                    
                thumbName := StrReplace(saved.ThumbPattern, "%original%", inName)
                thumbName := StrReplace(thumbName, "%date%", FormatTime(, "yyyyMMdd"))
                thumbFile := outDir "\" thumbName "." ext
                
                seekTime := 0
                tVal := StrReplace(saved.ThumbTime, "%", "")
                if InStr(saved.ThumbTime, "%")
                    seekTime := dur * (Float(tVal) / 100)
                else if RegExMatch(saved.ThumbTime, "^\d+(\.\d+)?$")
                    seekTime := Float(saved.ThumbTime)
                else
                    seekTime := saved.ThumbTime 

                w := Integer(saved.TileWidth)
                h := Integer(saved.TileHeight)
                scaleExpr := GetScaleFilter(w, h, saved.AspectRatio)

                thumbArgs := ["-y", "-ss", seekTime, "-i", Format('"{1}"', inputFile), "-frames:v", "1", "-vf", scaleExpr]
                
                try {
                    FFWrapper.GeneratePreview(thumbArgs, thumbFile)
                } catch as e {
                    BatchLog .= Format("    -> Thumbnail Failed: {1}`n", e.Message)
                }
            }
            
            BatchIdx++
            SetTimer(() => ProcessNextFile(saved), -10)
            
        } catch as e {
            if (e.Message != "Probe Failed (Handled)") {
                BatchErrors++
                BatchLog .= Format("[{1}/{2}] FAILED Engine: {3}`nError: {4}`n--------------------------------`n", BatchIdx, BatchTotal, inputFile, e.Message)
            }
            BatchIdx++
            SetTimer(() => ProcessNextFile(saved), -10)
        }
    }

    CancelBatch(*) {
        FFWrapper.Stop()
        sb.Text := " Cancelling..."
    }

    FinishBatch() {
        global BatchLog, BatchSuccess, BatchErrors, BatchTotal
        global ProgDlg
        
        ; Close Progress Dialog
        if (ProgDlg && WinExist(ProgDlg.gui.Hwnd)) {
            ProgDlg.gui.Destroy()
            ProgDlg := ""
        }
        
        progressBar.Value := 100
        sb.Text := " Batch Complete."
        btnCancel.Visible := false
        btnCreate.Visible := true
        
        title := "Batch Complete"
        icon := BatchErrors > 0 ? "⚠️" : "✅"
        color := BatchErrors > 0 ? "ffcc00" : Theme.Accent
        
        msg := Format("Processed {} files.`nSuccess: {}`nErrors: {}", BatchTotal, BatchSuccess, BatchErrors)
        
        btns := ["&OK"]
        if (BatchLog != "")
            btns.Push("&Save Log")
            
        result := customDialog({
            title: title,
            message: msg,
            detail: BatchLog,
            icon: icon,
            iconColor: color,
            buttons: btns,
            width: 600,
            height: 400,
            detailRows: 15
        }, darkPreset)
        
        if (result.value == "Save Log") {
            SaveLogFile()
        }
    }

    SaveLogFile() {
        path := FileSelect("S", "BatchLog.txt", "Save Log", "Text Files (*.txt)")
        if path {
            try FileAppend(BatchLog, path)
        }
    }
}
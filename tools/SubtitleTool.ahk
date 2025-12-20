/*
    FFmpeg Subtitle Tool (AHK v2)
    -----------------------------
    Tool 1: Convert/Extract - Convert subtitle formats or extract from video.
    Tool 2: Add Subtitles - Mux (Soft) or Burn-in (Hard) subtitles.
*/


#Include ..\lib\utils.ahk

SubtitleTool(){
    global AppName := "FFMpeg: Subtitle Tool"


    ; ==============================================================================
    ; GUI SETUP
    ; ==============================================================================
    myGui := Gui("-Resize -MaximizeBox", AppName)
    myGui.SetFont("s9 c" Theme.Text, "Segoe UI")
    myGui.BackColor := Theme.Bg

    InitWindowUtils(myGui)

    myGui.FFJob := FFWrapper
    myGui.OnEvent("Close", (*) => TryCloseWindow(myGui))
    myGui.OnEvent("DropFiles", HandleDropFiles)

    ; Layout Constants
    GuiWidth := 500
    RowH     := 32
    CtrlH    := 24
    BtnH     := 24
    xLabel   := 20
    xInput   := 90
    wInput   := 380

    ; ==============================================================================
    ; TABS
    ; ==============================================================================
    myGui.Add("Text", Format("x0 y0 w{} h40 Background{}", GuiWidth, Theme.DarkPanel), "")
    Tabs := TabManager(myGui, Theme, OnTabChanged)

    tW := GuiWidth / 2
    Tabs.Add("1. Convert / Extract", 0, 0, tW, 40, "Convert")
    Tabs.Add("2. Add to Video", tW, 0, tW, 40, "Add")


    ; ==============================================================================
    ; TAB 1: CONVERT / EXTRACT
    ; ==============================================================================
    yStart := 55
    currY  := yStart

    ; Input
    AddTabControl("Convert", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Input:")
    edtConvInput := AddTabControl("Convert", "Edit", Format("x{} y{} w{} h{} ReadOnly vConvInput", xInput, currY, wInput-95, CtrlH), "")
    btnConvBrowse := SexyButton(myGui, xInput+wInput-90, currY-1, 90, BtnH+2, "Browse...", SelectConvInput)
    btnConvBrowse.RegisterToTab(Tabs, "Convert")

    ; Operation Mode (Auto-detected usually, but explicit here)
    currY += RowH + 10
    AddTabControl("Convert", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Action:")
    ddlConvMode := DarkDropdown(myGui, xInput, currY, 200, ["Convert Subtitle Format", "Extract from Video"], "ConvMode")
    ddlConvMode.RegisterToTab(Tabs, "Convert")

    ; Format
    currY += RowH + 5
    AddTabControl("Convert", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "To Format:")
    ddlConvFmt := DarkDropdown(myGui, xInput, currY, 200, ["SRT (SubRip)", "VTT (WebVTT)", "ASS (Advanced)", "SSA (SubStation)", "LRC (Lyrics)", "SUB (MicroDVD)"], "ConvFormat")
    ddlConvFmt.RegisterToTab(Tabs, "Convert")

    txtConvNote := AddTabControl("Convert", "Text", Format("x{} y{} w{} h40 c888888 Background{}", xInput, currY+RowH+10, wInput, Theme.Bg), "Extract Note: Select 'Extract from Video' if input is MP4/MKV.`nFFmpeg will attempt to convert the first subtitle track found.")


    ; ==============================================================================
    ; TAB 2: ADD SUBTITLES
    ; ==============================================================================
    currY := yStart

    ; Video Input
    AddTabControl("Add", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Video:")
    edtAddVideo := AddTabControl("Add", "Edit", Format("x{} y{} w{} h{} ReadOnly vAddVideo", xInput, currY, wInput-95, CtrlH), "")
    btnAddVidBrowse := SexyButton(myGui, xInput+wInput-90, currY-1, 90, BtnH+2, "Browse...", SelectAddVideo)
    btnAddVidBrowse.RegisterToTab(Tabs, "Add")

    ; Subtitle Input
    currY += RowH + 5
    AddTabControl("Add", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Subtitle:")
    edtAddSub := AddTabControl("Add", "Edit", Format("x{} y{} w{} h{} ReadOnly vAddSub", xInput, currY, wInput-95, CtrlH), "")
    btnAddSubBrowse := SexyButton(myGui, xInput+wInput-90, currY-1, 90, BtnH+2, "Browse...", SelectAddSub)
    btnAddSubBrowse.RegisterToTab(Tabs, "Add")

    ; Mode
    currY += RowH + 10
    AddTabControl("Add", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Mode:")
    ddlAddMode := DarkDropdown(myGui, xInput, currY, 300, ["Soft Subtitles (Mux/Embed)", "Hard Subtitles (Burn-in)"], "AddMode")
    ddlAddMode.RegisterToTab(Tabs, "Add")

    ; Language Code (Soft subs only)
    currY += RowH + 5
    grpSoft := []
    tLang := myGui.Add("Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Lang:")
    grpSoft.Push(tLang)
    edtLang := AddFlatEdit(myGui, Format("x{} y{} w60 h{} vSubLang", xInput, currY, CtrlH), "eng")
    grpSoft.Push(edtLang)
    tLangHint := myGui.Add("Text", Format("x{} y{} w200 h{} c888888", xInput+70, currY+3, CtrlH), "(e.g., eng, jpn, spa)")
    grpSoft.Push(tLangHint)

    ; Register soft controls
    for c in grpSoft {
        Tabs.Register("Add", c)
        ; Visibility handled by OnTabChanged/Update logic if needed, currently always show
    }

    currY += RowH
    tAddNote := AddTabControl("Add", "Text", Format("x{} y{} w{} h60 c888888 Background{}", xLabel, currY, wInput, Theme.Bg), "Soft: Fast. Adds a track. Best for MKV (supports all) or MP4.`nHard: Slow. Burns text into pixels. Video re-encoded.`nNote: Hard subs uses the style defined in the subtitle file (ASS/SRT).")


    ; ==============================================================================
    ; FOOTER
    ; ==============================================================================
    yFooter := 260
    myGui.Add("Text", Format("x0 y{} w{} h65 Background{}", yFooter-3, GuiWidth, Theme.DarkPanel), "")

    btnProcess := SexyButton(myGui, 360, yFooter+10, 120, 35, "Process", StartProcess)
    btnProcess.Beautify()

    btnCancel := SexyButton(myGui, 360, yFooter+10, 120, 35, "Cancel", CancelProcess)
    btnCancel.Visible := false
    btnCancel.setBorders([Theme.AltAccent,Theme.AltAccent,Theme.AltAccent,Theme.AltAccent])
    btnCancel.SetTextColour(Theme.AltAccent)

    ; Status Bar
    yStatus := yFooter + 45
    progressBar := myGui.Add("Progress", Format("x0 y{} w{} h3 c{} Background{}", yStatus, GuiWidth, Theme.Accent, Theme.DarkPanel, "Range0-100 vMyProgress"), 0)

    myGui.SetFont("s8 c" Theme.Text, "Fixedsys")
    sb := myGui.Add("Text", Format("x0 y{} w{} h20 c{} Background{} +0x200 Center vStatusText", yStatus+3, GuiWidth, Theme.Accent, Theme.StatusBg), "Idle")

    ; Init Logic
    Tabs.Switch("Convert")
    myGui.Show(Format("w{} h{}", GuiWidth, yStatus+23))


    ; ==============================================================================
    ; HELPER FUNCTIONS
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
        if (newTabName == "Convert")
            btnProcess.SetText("Convert/Extract")
        else
            btnProcess.SetText("Add Subtitles")
    }

    SelectConvInput(*) {
        path := FileSelect(1, , "Select File", "Media (*.srt; *.vtt; *.ass; *.ssa; *.sub; *.mp4; *.mkv; *.avi)")
        if path {
            edtConvInput.Value := path
            SplitPath(path, , , &ext)
            if RegExMatch(ext, "i)^(mp4|mkv|avi|mov|webm)$")
                ddlConvMode.Text := "Extract from Video"
            else
                ddlConvMode.Text := "Convert Subtitle Format"
        }
    }

    SelectAddVideo(*) {
        path := FileSelect(1, , "Select Video", "Video (*.mp4; *.mkv; *.avi; *.mov; *.webm)")
        if path
            edtAddVideo.Value := path
    }

    SelectAddSub(*) {
        path := FileSelect(1, , "Select Subtitle", "Subtitles (*.srt; *.vtt; *.ass; *.ssa; *.sub)")
        if path
            edtAddSub.Value := path
    }

    HandleDropFiles(guiObj, ctrlObj, fileArray, x, y) {
        if (fileArray.Length == 0)
            return
        
        f := fileArray[1]
        SplitPath(f, , , &ext)
        isSub := RegExMatch(ext, "i)^(srt|vtt|ass|ssa|sub|lrc)$")
        
        if (Tabs.Current == "Convert") {
            edtConvInput.Value := f
            ddlConvMode.Text := isSub ? "Convert Subtitle Format" : "Extract from Video"
        } else {
            if (isSub)
                edtAddSub.Value := f
            else
                edtAddVideo.Value := f
        }
    }


    ; ==============================================================================
    ; PROCESS LOGIC
    ; ==============================================================================
    StartProcess(*) {
        if (Tabs.Current == "Convert")
            ProcessConvert()
        else
            ProcessAdd()
    }

    ProcessConvert() {
        saved := myGui.Submit(0)
        if (saved.ConvInput == "")
            return customDialog({message: "Select an input file."}, darkPreset)
            
        SplitPath(saved.ConvInput, , &dir, , &nameNoExt)
        
        outExt := "srt"
        if InStr(saved.ConvFormat, "VTT")
            outExt := "vtt"
        else if InStr(saved.ConvFormat, "ASS")
            outExt := "ass"
        else if InStr(saved.ConvFormat, "SSA")
            outExt := "ssa"
        else if InStr(saved.ConvFormat, "LRC")
            outExt := "lrc"
        else if InStr(saved.ConvFormat, "SUB")
            outExt := "sub"
            
        outPath := FileSelect("S", dir "\" nameNoExt "_converted." outExt, "Save Subtitle", "Subtitle (*." outExt ")")
        if !outPath
            return
            
        cmdArgs := []
        cmdArgs.Push("-y")
        cmdArgs.Push("-i", Format('"{1}"', saved.ConvInput))
        
        if (saved.ConvMode == "Extract from Video") {
            ; Extract first subtitle stream
            cmdArgs.Push("-map", "0:s:0")
        }
        
        ; FFmpeg handles subtitle conversion automatically based on extension
        ; but some formats require codecs
        if (outExt == "ass" || outExt == "ssa")
            cmdArgs.Push("-c:s", "ass")
        else if (outExt == "srt")
            cmdArgs.Push("-c:s", "srt")
        else if (outExt == "vtt")
            cmdArgs.Push("-c:s", "webvtt")
            
        ExecuteJob(cmdArgs, outPath)
    }

    ProcessAdd() {
        saved := myGui.Submit(0)
        if (saved.AddVideo == "" || saved.AddSub == "")
            return customDialog({message: "Select both video and subtitle files."}, darkPreset)
        
        SplitPath(saved.AddVideo, , &dir, , &nameNoExt)
        SplitPath(saved.AddVideo, , , &vidExt)
        
        isHard := InStr(saved.AddMode, "Hard")
        
        defaultExt := vidExt
        if (!isHard && vidExt == "mp4") {
            ; MP4 soft subs are strictly mov_text, sometimes better to output mkv
        }
        
        outPath := FileSelect("S", dir "\" nameNoExt "_subbed." defaultExt, "Save Output", "Video (*." defaultExt ")")
        if !outPath
            return
            
        cmdArgs := []
        cmdArgs.Push("-y")
        cmdArgs.Push("-i", Format('"{1}"', saved.AddVideo))
        
        if (isHard) {
            ; HARD BURN
            ; To avoid Windows path escaping hell with filters, copy sub to temp
            tempSub := A_Temp "\temp_sub_" A_TickCount ".srt" ; Force SRT for simplicity? No, copy original ext
            SplitPath(saved.AddSub, , , &subExt)
            tempSub := A_Temp "\temp_sub_" A_TickCount "." subExt
            
            try FileCopy(saved.AddSub, tempSub, 1)
            
            ; Convert Windows path to FFmpeg friendly path (Forward slashes, escape colons)
            ; Best way: Relative path if we could set CWD, but FFmpegJob runs absolute.
            ; Safe way: Use full path with forward slashes and escaped colon
            safeSubPath := StrReplace(tempSub, "\", "/")
            safeSubPath := StrReplace(safeSubPath, ":", "\:")
            
            ; Filter
            cmdArgs.Push("-vf", Format("subtitles='{1}'", safeSubPath))
            
            ; Re-encode Video (Required for Hardsubs)
            cmdArgs.Push("-c:v", "libx264", "-crf", "23", "-pix_fmt", "yuv420p")
            cmdArgs.Push("-c:a", "copy")
            
            ; Pass temp file to ExecuteJob for cleanup
            ExecuteJob(cmdArgs, outPath, tempSub)
            
        } else {
            ; SOFT MUX
            cmdArgs.Push("-i", Format('"{1}"', saved.AddSub))
            
            cmdArgs.Push("-map", "0")
            cmdArgs.Push("-map", "1")
            
            cmdArgs.Push("-c:v", "copy")
            cmdArgs.Push("-c:a", "copy")
            
            ; Subtitle Codec
            if (SubStr(outPath, -4) == ".mp4") {
                cmdArgs.Push("-c:s", "mov_text") ; MP4 standard
            } else {
                cmdArgs.Push("-c:s", "srt") ; MKV default
            }
            
            ; Metadata
            if (saved.SubLang != "")
                cmdArgs.Push("-metadata:s:s:0", "language=" saved.SubLang)
                
            ExecuteJob(cmdArgs, outPath)
        }
    }

    ExecuteJob(cmdArgs, outputFile, cleanupFile := "") {
        btnProcess.Visible := false
        btnCancel.Visible := true
        sb.Text := " Processing..."
        progressBar.Value := 0

        OnProgress(percent, text) {
            if (sb.Text != "Cancelling...") {
                progressBar.Value := percent
                sb.Text := text
            }
        }

        OnFinish(success, result) {
            btnCancel.Visible := false
            btnProcess.Visible := true
            
            if (cleanupFile && FileExist(cleanupFile))
                try FileDelete(cleanupFile)
            
            if (success) {
                progressBar.Value := 100
                sb.Text := " Done!"
                if MsgBox("Operation Complete!`nOpen output folder?", "Success", "YesNo") == "Yes" {
                    SplitPath(outputFile, , &oDir)
                    Run("explorer.exe `"" oDir "`"")
                }
            } else {
                sb.Text := " Failed."
                if !InStr(result, "Cancelled")
                    ShowErrorLog(result)
            }
        }

        FFWrapper.Run(cmdArgs, outputFile, OnProgress, OnFinish)
    }

    CancelProcess(*) {
        FFWrapper.Stop()
        sb.Text := "Cancelling..."
        btnCancel.SetText("Stopping...")
    }

    ShowErrorLog(logContent) {
        customDialog({title:"FFmpeg Error Log",message:"Process Failed!`nFull log output:",detail: logContent}, criticalErrorDetailPreset)
    }
}
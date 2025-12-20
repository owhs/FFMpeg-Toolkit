/*
    FFmpeg Universal Converter (AHK v2)
    -----------------------------------
    A general purpose wrapper using the existing lib/utils.ahk framework.
    Features: Resize, Speed (incl. Fit to Duration), Trim, Extract Frames, Preview Chunks, Presets.
*/


#Include ..\lib\utils.ahk
SimpleConverter(){
    global AppName := "FFMpeg: Universal Converter"

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
    yContentStart := 44   
    RowH          := 32   
    CtrlH         := 24   
    BtnH          := 24

    ; Columns
    xLabel  := 15
    xInput  := 80
    wInput  := 340 
    xBtn    := 430
    wBtn    := 95

    ; ==============================================================================
    ; TAB NAVIGATION
    ; ==============================================================================
    myGui.Add("Text", Format("x0 y0 w{} h40 Background{}", GuiWidth, Theme.DarkPanel), "")
    Tabs := TabManager(myGui, Theme, OnTabChanged)

    tW := GuiWidth / 3
    Tabs.Add("1. Video && Image", 0,    0, tW, 40, "Video")
    Tabs.Add("2. Audio && Quality", tW,   0, tW, 40, "Audio")
    Tabs.Add("3. Trim && Output", tW*2, 0, tW, 40, "Output")

    ; ==============================================================================
    ; HEADER (INPUT FILE) - Persistent across tabs logic via visibility
    ; ==============================================================================
    currY := yContentStart + 10
    myGui.Add("Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Input:")
    edtInput := AddFlatEdit(myGui, Format("x{} y{} w{} h{} ReadOnly vInputFile", xInput, currY, wInput, CtrlH))
    SexyButton(myGui, xBtn, currY-1, wBtn, BtnH+2, "Browse...", SelectInput)

    currY += RowH + 10
    yTabContent := currY ; Store Y where tab specific content starts

    ; ==============================================================================
    ; TAB 1: VIDEO TRANSFORM
    ; ==============================================================================
    currY := yTabContent

    ; Resolution
    AddTabControl("Video", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Scale:")
    ddlRes := DarkDropdown(myGui, xInput, currY, wInput+104, ["Original Resolution", "1920x1080 (1080p)", "1280x720 (720p)", "854x480 (480p)", "Scale Width to 1920", "Scale Width to 1280"], "VidScale")
    ddlRes.RegisterToTab(Tabs, "Video")

    ; Framerate
    currY += RowH + 5
    AddTabControl("Video", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "FPS:")
    ddlFPS := DarkDropdown(myGui, xInput, currY, 150, ["Original", "60", "30", "24", "15", "1"], "VidFPS")
    ddlFPS.RegisterToTab(Tabs, "Video")

    ; Speed / Custom Duration
    AddTabControl("Video", "Text", Format("x250 y{} w50 h{}", currY+3, CtrlH), "Speed:")
    ddlSpeed := DarkDropdown(myGui, 300, currY, 124, ["1.0x (Normal)", "0.5x (Slow)", "2.0x (Fast)", "4.0x (Hyper)", "Fit to Duration"], "VidSpeed", UpdateSpeedUI)
    ddlSpeed.RegisterToTab(Tabs, "Video")

    ; Target Duration Input (Hidden by default)
    txtTargetDur := AddTabControl("Video", "Text", Format("x240 y{} w60 h{}", currY+RowH+8, CtrlH), "Target(s):")
    edtTargetDur := AddTabControl("Video", "Edit", Format("x300 y{} w124 h{} vTargetSeconds Number Hidden", currY+RowH+5, CtrlH), "60")
    txtTargetDur.Visible := false

    ; Rotation / Flip
    currY += RowH + 5
    AddTabControl("Video", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Flip:")
    ddlFlip := DarkDropdown(myGui, xInput, currY, wInput+104, ["None", "Horizontal Flip", "Vertical Flip", "Rotate 90 CW", "Rotate 90 CCW"], "VidFlip")
    ddlFlip.RegisterToTab(Tabs, "Video")


    ; ==============================================================================
    ; TAB 2: AUDIO & QUALITY
    ; ==============================================================================
    currY := yTabContent

    ; Audio Codec
    AddTabControl("Audio", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Codec:")
    ddlACodec := DarkDropdown(myGui, xInput, currY, wInput+104, ["AAC (Standard)", "MP3", "Copy (No Transcode)", "Disable Audio"], "AudCodec")
    ddlACodec.RegisterToTab(Tabs, "Audio")

    ; Bitrate
    currY += RowH + 5
    AddTabControl("Audio", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Bitrate:")
    ddlABitrate := DarkDropdown(myGui, xInput, currY, 150, ["320k", "192k", "128k", "96k", "64k"], "AudBitrate")
    ddlABitrate.RegisterToTab(Tabs, "Audio")

    ; Volume
    AddTabControl("Audio", "Text", Format("x250 y{} w50 h{}", currY+3, CtrlH), "Volume:")
    ddlAVol := DarkDropdown(myGui, 300, currY, 124, ["100%", "50%", "150%", "200%"], "AudVol")
    ddlAVol.RegisterToTab(Tabs, "Audio")

    ; Video Quality (CRF)
    currY += RowH + 5
    AddTabControl("Audio", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "V-Qual:")
    ddlVQual := DarkDropdown(myGui, xInput, currY, wInput+104, ["Auto / Standard", "High Quality (CRF 18)", "Balanced (CRF 23)", "Low Size (CRF 28)"], "VidQuality")
    ddlVQual.RegisterToTab(Tabs, "Audio")

    ; ==============================================================================
    ; TAB 3: TRIM & OUTPUT
    ; ==============================================================================
    currY := yTabContent

    ; Output Format
    AddTabControl("Output", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Format:")
    ddlFormat := DarkDropdown(myGui, xInput, currY, wInput+104, ["MP4 (H.264)", "MKV", "WebM (VP9)", "AVI", "MP3 (Audio Only)", "WAV (Audio Only)", "GIF (Animated)", "JPG Sequence (Frames)"], "OutFormat")
    ddlFormat.RegisterToTab(Tabs, "Output")

    ; Trim Controls
    currY += RowH + 5
    AddTabControl("Output", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Trim:")
    chkTrim := myGui.Add("Checkbox", Format("x{} y{} w15 h{} vEnableTrim c{} Background{}", xInput, currY, CtrlH, Theme.Text, Theme.Bg), "")
    SetDarkControl(chkTrim)
    Tabs.Register("Output", chkTrim)

    AddTabControl("Output", "Text", Format("x100 y{} w35 h{}", currY+3, CtrlH), "Start:")
    edtStart := AddTabControl("Output", "Edit", Format("x140 y{} w60 h{} vTrimStart", currY, CtrlH), "00:00:00")

    AddTabControl("Output", "Text", Format("x210 y{} w25 h{}", currY+3, CtrlH), "End:")
    edtEnd := AddTabControl("Output", "Edit", Format("x240 y{} w60 h{} vTrimEnd", currY, CtrlH), "00:00:05")

    AddTabControl("Output", "Text", Format("x310 y{} w180 h{} c888888", currY+3, CtrlH), "(Leave End empty for full)")


    ; ==============================================================================
    ; FOOTER
    ; ==============================================================================
    yFooter := 215 

    myGui.Add("Text", Format("x0 y{} w{} h65 Background{}", yFooter-3, GuiWidth, Theme.DarkPanel), "")

    ; Preset Buttons
    SexyButton(myGui, 10, yFooter+5, 80, 30, "Save", SavePreset)
    SexyButton(myGui, 100, yFooter+5, 80, 30, "Load", LoadPreset)

    ; Preview Button (Runs a 5 second chunk)
    SexyButton(myGui, 280, yFooter+5, 120, 30, "Preview (5s)", GeneratePreviewChunk)

    ; Action Buttons
    btnCreate := SexyButton(myGui, 410, yFooter+5, 120, 30, "Convert", StartConversion)
    btnCreate.Beautify()
    btnCancel := SexyButton(myGui, 410, yFooter+5, 120, 30, "Cancel", CancelConversion)
    btnCancel.Visible := false
    btnCancel.setBorders([Theme.AltAccent,Theme.AltAccent,Theme.AltAccent,Theme.AltAccent])
    btnCancel.SetTextColour(Theme.AltAccent)

    ; Status Bar
    yStatus := yFooter + 38
    progressBar := myGui.Add("Progress", Format("x0 y{} w{} h3 c{} Background{}", yStatus, GuiWidth, Theme.Accent, Theme.DarkPanel, "Range0-100 vMyProgress"), 0)

    myGui.SetFont("s8 c" Theme.Text, "Fixedsys")
    sb := myGui.Add("Text", Format("x0 y{} w{} h20 c{} Background{} +0x200 Center vStatusText", yStatus+3, GuiWidth, Theme.Accent, Theme.StatusBg), "Idle")

    Tabs.Switch("Video")
    myGui.Show(Format("w{} h{}", GuiWidth, yStatus + 23))


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
        if (newTabName == "Video")
            UpdateSpeedUI()
    }

    UpdateSpeedUI(*) {
        isFit := (ddlSpeed.Text == "Fit to Duration")
        try {
            txtTargetDur.Visible := isFit
            edtTargetDur.Visible := isFit
        }
    }

    SelectInput(*) {
        path := FileSelect(1, , "Select Input Media", "Media (*.mp4; *.mkv; *.webm; *.avi; *.mov; *.mp3; *.wav; *.flac; *.jpg; *.png)")
        if path 
            edtInput.Value := path
    }

    HandleDropFiles(guiObj, ctrlObj, fileArray, x, y) {
        if fileArray.Length > 0
            edtInput.Value := fileArray[1]
    }

    ParseTime(timeStr) {
        if IsNumber(timeStr)
            return Float(timeStr)
        
        parts := StrSplit(timeStr, ":")
        secs := 0
        multiplier := 1
        
        Loop parts.Length {
            val := parts[parts.Length - A_Index + 1]
            secs += val * multiplier
            multiplier *= 60
        }
        return secs
    }

    GetMediaDuration(filePath) {
        if !FileExist(filePath)
            return 0
        
        ff := FFWrapper.ffmpegPath
        ; Run ffmpeg to get info
        shell := ComObject("WScript.Shell")
        ; We must use a file redirect because checking stderr from Exec is blocking/tricky in v2 simple scripts
        logFile := A_Temp "\dur_probe.txt"
        try FileDelete(logFile)
        
        cmd := Format('"{1}" -i "{2}" 2> "{3}"', ff, filePath, logFile)
        RunWait(A_ComSpec " /c " cmd, , "Hide")
        
        if !FileExist(logFile)
            return 0
            
        content := FileRead(logFile)
        FileDelete(logFile)
        
        if RegExMatch(content, "Duration:\s+(\d{2}):(\d{2}):(\d{2}\.\d+)", &m) {
            return (m[1]*3600) + (m[2]*60) + m[3]
        }
        return 0
    }

    GetSpeedFactor(saved) {
        speedFactor := 1.0
        
        if (saved.VidSpeed == "Fit to Duration") {
            sourceDur := 0
            if (saved.EnableTrim) {
                s := ParseTime(saved.TrimStart)
                e := (saved.TrimEnd == "") ? GetMediaDuration(saved.InputFile) : ParseTime(saved.TrimEnd)
                sourceDur := e - s
            } else {
                sourceDur := GetMediaDuration(saved.InputFile)
            }
            
            targetDur := Float(saved.TargetSeconds)
            if (sourceDur > 0 && targetDur > 0)
                speedFactor := sourceDur / targetDur
        } else if (saved.VidSpeed != "1.0x (Normal)") {
            speedFactor := (saved.VidSpeed == "0.5x (Slow)") ? 0.5 : (saved.VidSpeed == "2.0x (Fast)") ? 2.0 : 4.0
        }
        
        return speedFactor
    }

    ; ==============================================================================
    ; PRESET SYSTEM
    ; ==============================================================================

    SavePreset(*) {
        path := FileSelect("S", "MyPreset.ini", "Save Preset", "Settings (*.ini)")
        if (!path)
            return
        saved := myGui.Submit(0)
        
        ; We remove InputFile from the save data so presets are file-agnostic
        if saved.HasProp("InputFile")
            saved.DeleteProp("InputFile")
            
        for k, v in saved.OwnProps()
            IniWrite(StrReplace(v, "`n", "||"), path, "Settings", k)
            
        ; Explicitly save custom dropdowns as they might not be fully captured if logic varies
        IniWrite(ddlRes.Text, path, "Settings", "VidScale")
        IniWrite(ddlFPS.Text, path, "Settings", "VidFPS")
        IniWrite(ddlSpeed.Text, path, "Settings", "VidSpeed")
        IniWrite(ddlFlip.Text, path, "Settings", "VidFlip")
        IniWrite(ddlACodec.Text, path, "Settings", "AudCodec")
        IniWrite(ddlABitrate.Text, path, "Settings", "AudBitrate")
        IniWrite(ddlAVol.Text, path, "Settings", "AudVol")
        IniWrite(ddlVQual.Text, path, "Settings", "VidQuality")
        IniWrite(ddlFormat.Text, path, "Settings", "OutFormat")
        
        sb.Text := " Preset Saved!"
    }

    LoadPreset(*) {
        path := FileSelect(1, , "Load Preset", "Settings (*.ini)")
        if (!path)
            return
        
        try {
            saved := myGui.Submit(0)
            
            ; Load Standard Controls
            for k, v in saved.OwnProps() {
                if (k == "InputFile") ; Don't overwrite input file
                    continue
                    
                try {
                    val := IniRead(path, "Settings", k)
                    ctrl := myGui[k]
                    
                    if (ctrl.Type == "Checkbox")
                        ctrl.Value := Integer(val)
                    else 
                        ctrl.Value := StrReplace(val, "||", "`n")
                }
            }
            
            ; Load Dropdowns
            try ddlRes.Text      := IniRead(path, "Settings", "VidScale")
            try ddlFPS.Text      := IniRead(path, "Settings", "VidFPS")
            try ddlSpeed.Text    := IniRead(path, "Settings", "VidSpeed")
            try ddlFlip.Text     := IniRead(path, "Settings", "VidFlip")
            try ddlACodec.Text   := IniRead(path, "Settings", "AudCodec")
            try ddlABitrate.Text := IniRead(path, "Settings", "AudBitrate")
            try ddlAVol.Text     := IniRead(path, "Settings", "AudVol")
            try ddlVQual.Text    := IniRead(path, "Settings", "VidQuality")
            try ddlFormat.Text   := IniRead(path, "Settings", "OutFormat")
            
            UpdateSpeedUI()
            sb.Text := " Preset Loaded!"
        } catch {
            sb.Text := " Error Loading Preset."
        }
    }

    ; ==============================================================================
    ; FFmpeg LOGIC
    ; ==============================================================================

    BuildFFmpegArgs(saved, isPreview := false) {
        args := []
        filterChain := ""
        
        ; 1. Input
        if (saved.EnableTrim || isPreview) {
            args.Push("-ss", saved.TrimStart)
        }

        if (saved.InputFile == "")
            throw Error("No input file selected.")

        args.Push("-i", Format('"{1}"', saved.InputFile))

        ; 2. Duration (Preview Mode)
        if (isPreview) {
            args.Push("-t", "5")
        } else if (saved.EnableTrim && saved.TrimEnd != "") {
            args.Push("-to", saved.TrimEnd)
        }

        ; 3. Video Filters
        filters := []
        
        ; Scaling
        if (saved.VidScale != "Original Resolution") {
            if InStr(saved.VidScale, "1920x1080")
                filters.Push("scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2")
            else if InStr(saved.VidScale, "1280x720")
                filters.Push("scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2")
            else if InStr(saved.VidScale, "854x480")
                filters.Push("scale=854:480:force_original_aspect_ratio=decrease")
            else if InStr(saved.VidScale, "Width to 1920")
                filters.Push("scale=1920:-2")
            else if InStr(saved.VidScale, "Width to 1280")
                filters.Push("scale=1280:-2")
        }

        ; Speed Calculation (Reuse Logic)
        speedFactor := GetSpeedFactor(saved)

        if (speedFactor != 1.0) {
            ; SetPTS = (1/Speed) * PTS
            ; e.g. Speed 2.0x -> PTS * 0.5
            ptsMult := 1.0 / speedFactor
            filters.Push("setpts=" ptsMult "*PTS")
        }

        ; Flip/Rotate
        if (saved.VidFlip != "None") {
            switch saved.VidFlip {
                case "Horizontal Flip": filters.Push("hflip")
                case "Vertical Flip":   filters.Push("vflip")
                case "Rotate 90 CW":    filters.Push("transpose=1")
                case "Rotate 90 CCW":   filters.Push("transpose=2")
            }
        }

        if (filters.Length > 0) {
            filterStr := ""
            for f in filters
                filterStr .= (A_Index > 1 ? "," : "") . f
            args.Push("-vf", Format('"{1}"', filterStr))
        }

        ; 4. Video Properties
        if (saved.VidFPS != "Original")
            args.Push("-r", saved.VidFPS)

        ; 5. Audio Filters & Codec
        isAudioOnly := InStr(saved.OutFormat, "Audio Only")
        isImgSeq    := InStr(saved.OutFormat, "Sequence")
        isGif       := InStr(saved.OutFormat, "GIF")

        if (isImgSeq || isGif) {
            ; No audio for images
        } else {
            if (saved.AudCodec == "Disable Audio") {
                args.Push("-an")
            } else if (saved.AudCodec == "Copy (No Transcode)") {
                ; Can't copy if speed changed
                if (speedFactor != 1.0)
                    throw Error("Cannot use 'Copy' codec with Speed/Duration changes. Select AAC or MP3.")
                args.Push("-c:a", "copy")
            } else {
                ; Codec Selection
                if (saved.AudCodec == "MP3")
                    args.Push("-c:a", "libmp3lame")
                else if (saved.AudCodec == "AAC (Standard)")
                    args.Push("-c:a", "aac")
                
                ; Bitrate
                args.Push("-b:a", saved.AudBitrate)

                ; Audio Filters (Volume / Speed)
                afilters := []
                if (saved.AudVol != "100%") {
                    vol := StrReplace(saved.AudVol, "%", "")
                    afilters.Push("volume=" (vol/100))
                }
                
                if (speedFactor != 1.0) {
                    ; Audio tempo = speedFactor. 
                    ; atempo is limited to 0.5 to 2.0
                    ; We must chain filters for values outside this range
                    remaining := speedFactor
                    
                    while (remaining > 2.0) {
                        afilters.Push("atempo=2.0")
                        remaining /= 2.0
                    }
                    while (remaining < 0.5) {
                        afilters.Push("atempo=0.5")
                        remaining /= 0.5
                    }
                    ; Push remainder
                    afilters.Push("atempo=" remaining)
                }

                if (afilters.Length > 0) {
                    afStr := ""
                    for f in afilters
                        afStr .= (A_Index > 1 ? "," : "") . f
                    args.Push("-af", Format('"{1}"', afStr))
                }
            }
        }

        ; 6. Video Codec / Quality (Skip for Audio Only/Images)
        if (!isAudioOnly && !isImgSeq && !isGif) {
            if (saved.VidQuality != "Auto / Standard") {
                crf := InStr(saved.VidQuality, "18") ? 18 : InStr(saved.VidQuality, "28") ? 28 : 23
                args.Push("-crf", crf)
            }
            
            ; Output Specific Codecs
            if InStr(saved.OutFormat, "WebM")
                args.Push("-c:v", "libvpx-vp9", "-b:v", "0") ; Constrained quality
            else if InStr(saved.OutFormat, "MP4") || InStr(saved.OutFormat, "MKV")
                args.Push("-c:v", "libx264", "-pix_fmt", "yuv420p")
        }

        return args
    }

    ; ==============================================================================
    ; ACTIONS
    ; ==============================================================================

    GeneratePreviewChunk(*) {
        saved := myGui.Submit(0)
        try {
            if (saved.InputFile == "")
                throw Error("Select a file first.")

            sb.Text := " Generating 5s Preview..."
            
            ; Create a temp file with the correct extension based on settings
            ext := "mp4" ; Default
            if InStr(saved.OutFormat, "WebM") 
                ext := "webm"
            else if InStr(saved.OutFormat, "GIF")
                ext := "gif"
            else if InStr(saved.OutFormat, "MP3")
                ext := "mp3"
            
            previewFile := A_Temp "\preview_" A_TickCount "." ext
            
            ; Build args with isPreview=true
            cmdArgs := BuildFFmpegArgs(saved, true)
            
            ; Helper to run Preview
            RunPreviewJob(cmdArgs, previewFile)

        } catch as e {
            customDialog({title:"Error",message:e.Message}, errorPreset)
            sb.Text := " Preview Failed."
        }
    }

    RunPreviewJob(cmdArgs, outputFile) {
        btnCreate.Enabled := false
        
        OnPreviewFinish(success, result) {
            btnCreate.Enabled := true
            if success {
                sb.Text := " Preview Ready."
                Run(outputFile)
            } else {
                sb.Text := " Preview Error."
                ShowErrorLog(result)
            }
        }

        FFWrapper.Run(cmdArgs, outputFile, (p, t) => (sb.Text := "Generating Preview..."), OnPreviewFinish)
    }

    StartConversion(*) {
        saved := myGui.Submit(0)
        
        if (saved.InputFile == "") 
            return customDialog({message: "Please select an input file first"}, darkPreset)
        
        ; Determine Output Filename
        SplitPath(saved.InputFile, , &dir, , &nameNoExt)
        
        defaultExt := "mp4"
        if InStr(saved.OutFormat, "MKV") 
            defaultExt := "mkv"
        else if InStr(saved.OutFormat, "WebM")
            defaultExt := "webm"
        else if InStr(saved.OutFormat, "AVI")
            defaultExt := "avi"
        else if InStr(saved.OutFormat, "MP3")
            defaultExt := "mp3"
        else if InStr(saved.OutFormat, "WAV")
            defaultExt := "wav"
        else if InStr(saved.OutFormat, "GIF")
            defaultExt := "gif"
        else if InStr(saved.OutFormat, "Sequence")
            defaultExt := "jpg"

        ; If Image Sequence, logic changes slightly
        isSeq := InStr(saved.OutFormat, "Sequence")
        
        if (isSeq)
            saveName := nameNoExt "_%04d." defaultExt
        else
            saveName := nameNoExt "_converted." defaultExt

        outputFile := FileSelect("S", dir "\" saveName, "Save Output", "File (*." defaultExt ")")
        if (outputFile == "")
            return

        ; Ensure extension if user removed it (skip for sequence containing %)
        if (!isSeq && !RegExMatch(outputFile, "\." defaultExt "$"))
            outputFile .= "." defaultExt

        ; Calc Speed Factor for Progress Correction
        speedFactor := GetSpeedFactor(saved)

        ; Build Args
        try {
            cmdArgs := []
            cmdArgs.Push("-y") ; Overwrite
            args := BuildFFmpegArgs(saved, false)
            for a in args
                cmdArgs.Push(a)
        } catch as e {
            return customDialog({message: e.Message}, errorPreset)
        }

        ; UI State
        btnCreate.Visible := false
        btnCancel.Visible := true
        sb.Text := " Starting..."
        progressBar.Value := 0

        OnProgress(percent, text) {
            if (sb.Text != "Cancelling...") {
                
                ; Correct percentage for Speed changes (as lib assumes 1.0x input duration)
                ; If slow (0.5x), output is 2x longer. Lib reports 200% at end. We multiply by 0.5 -> 100%.
                ; If fast (2.0x), output is 0.5x length. Lib reports 50% at end. We multiply by 2.0 -> 100%.
                adjustedPct := percent * speedFactor
                progressBar.Value := adjustedPct
                
                if (speedFactor != 1.0) {
                    sb.Text := Format(" Converting: {:.1f}%", adjustedPct)
                } else {
                    sb.Text := text
                }
            }
        }

        OnFinish(success, result) {
            btnCancel.Visible := false
            btnCreate.Visible := true
            
            if (success) {
                progressBar.Value := 100
                sb.Text := " Conversion Complete!"
                if MsgBox("Done!`nOpen output folder?", "Success", "YesNo") == "Yes" {
                    if (isSeq)
                        Run("explorer.exe /select,`"" StrReplace(result, "%04d", "0001") "`"") ; Try to select first image
                    else
                        Run("explorer.exe /select,`"" result "`"")
                }
            } else {
                sb.Text := " Failed."
                if !InStr(result, "Cancelled")
                    ShowErrorLog(result)
            }
        }

        FFWrapper.Run(cmdArgs, outputFile, OnProgress, OnFinish)
    }

    CancelConversion(*) {
        FFWrapper.Stop()
        sb.Text := "Cancelling..."
        btnCancel.SetText("Stopping...")
        SetTimer(ResetButtons, -1000)
    }

    ResetButtons() {
        btnCancel.Visible := false
        btnCreate.Visible := true
        btnCancel.SetText("Cancel")
    }

    ShowErrorLog(logContent) {
        customDialog({title:"FFmpeg Error Log",message:"FFmpeg Failed!`nFull log output:",detail: logContent}, criticalErrorDetailPreset)
    }
}
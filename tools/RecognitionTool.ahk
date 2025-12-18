/*
    FFmpeg Recognition & Analysis Tool (AHK v2)
    -------------------------------------------
    Analyze media content for specific events.
    Features: Scene Detection, Silence Detection, Black Frames, Freeze Frames.
*/
#Requires AutoHotkey v2.0

#Include ..\lib\utils.ahk
RecognitionTool(){
    global AppName := "FFMpeg: Recognition Tool"
    
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
    GuiWidth := 540
    RowH     := 32
    CtrlH    := 24
    BtnH     := 24
    xLabel   := 20
    xInput   := 90
    wInput   := 420

    ; ==============================================================================
    ; HEADER: INPUT
    ; ==============================================================================
    myGui.Add("Text", Format("x0 y0 w{} h60 Background{}", GuiWidth, Theme.DarkPanel), "")

    yStart := 15
    currY  := yStart

    myGui.SetFont("w600")
    myGui.Add("Text", Format("x{} y{} w80 h{} Background{}", xLabel, currY+3, CtrlH, Theme.DarkPanel), "Input:")
    myGui.SetFont("w400")

    edtInput := AddFlatEdit(myGui, Format("x{} y{} w{} h{} ReadOnly vInputFile", xInput, currY, wInput-100, CtrlH), "")
    btnBrowse := SexyButton(myGui, xInput+wInput-95, currY-1, 95, BtnH+2, "Browse...", SelectInput)


    ; ==============================================================================
    ; TABS
    ; ==============================================================================
    yTabs := 50
    myGui.Add("Text", Format("x0 y{} w{} h40 Background{}", yTabs, GuiWidth, Theme.DarkPanel), "")
    Tabs := TabManager(myGui, Theme, OnTabChanged)

    tW := GuiWidth / 2
    Tabs.Add("1. Content Detection", 0, yTabs, tW, 40, "Detect")
    Tabs.Add("2. Output Options", tW, yTabs, tW, 40, "Output")

    ; ==============================================================================
    ; TAB 1: DETECTION MODES
    ; ==============================================================================
    yContent := yTabs + 55
    currY := yContent

    AddTabControl("Detect", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Mode:")
    ddlMode := DarkDropdown(myGui, xInput, currY, 250, ["Scene Detection (Cuts)", "Silence Detection (Audio)", "Black Frame Detection", "Freeze Frame Detection"], "DetectMode", UpdateUI)
    ddlMode.RegisterToTab(Tabs, "Detect")

    currY += RowH + 10

    ; -- Dynamic Groups --

    ; SCENE DETECT
    grpScene := []
    tSceneThresh := myGui.Add("Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "Threshold:")
    grpScene.Push(tSceneThresh)
    edtSceneThresh := AddFlatEdit(myGui, Format("x{} y{} w60 h{} vSceneThresh", xInput+20, currY, CtrlH), "0.3")
    grpScene.Push(edtSceneThresh)
    tSceneInfo := myGui.Add("Text", Format("x{} y{} w{} h{} c888888", xInput+90, currY+3, 250, CtrlH), "(0.0 - 1.0, Default: 0.3)")
    grpScene.Push(tSceneInfo)

    tSceneDesc := myGui.Add("Text", Format("x{} y{} w{} h{} c888888", xLabel, currY+RowH+5, wInput, 40), "Detects shot changes in video.`nLower threshold = More sensitive (detects smaller changes).")
    grpScene.Push(tSceneDesc)

    ; SILENCE DETECT
    grpSilence := []
    tSilLevel := myGui.Add("Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "Level (dB):")
    grpSilence.Push(tSilLevel)
    edtSilLevel := AddFlatEdit(myGui, Format("x{} y{} w60 h{} vSilLevel", xInput+20, currY, CtrlH), "-50dB")
    grpSilence.Push(edtSilLevel)

    tSilDur := myGui.Add("Text", Format("x{} y{} w80 h{}", xInput+100, currY+3, CtrlH), "Min Dur(s):")
    grpSilence.Push(tSilDur)
    edtSilDur := AddFlatEdit(myGui, Format("x{} y{} w60 h{} vSilDur", xInput+180, currY, CtrlH), "2")
    grpSilence.Push(edtSilDur)

    tSilDesc := myGui.Add("Text", Format("x{} y{} w{} h{} c888888", xLabel, currY+RowH+5, wInput, 40), "Finds audio segments quieter than the level for longer than duration.")
    grpSilence.Push(tSilDesc)

    ; BLACK DETECT
    grpBlack := []
    tBlackDur := myGui.Add("Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "Min Dur(s):")
    grpBlack.Push(tBlackDur)
    edtBlackDur := AddFlatEdit(myGui, Format("x{} y{} w60 h{} vBlackDur", xInput+20, currY, CtrlH), "2.0")
    grpBlack.Push(edtBlackDur)

    tBlackRatio := myGui.Add("Text", Format("x{} y{} w80 h{}", xInput+100, currY+3, CtrlH), "Pic Ratio:")
    grpBlack.Push(tBlackRatio)
    edtBlackRatio := AddFlatEdit(myGui, Format("x{} y{} w60 h{} vBlackRatio", xInput+180, currY, CtrlH), "0.98")
    grpBlack.Push(edtBlackRatio)

    tBlackDesc := myGui.Add("Text", Format("x{} y{} w{} h{} c888888", xLabel, currY+RowH+5, wInput, 40), "Finds segments that are black (transitions, commercials).`nRatio 1.0 = All black pixels.")
    grpBlack.Push(tBlackDesc)

    ; FREEZE DETECT
    grpFreeze := []
    tFreezeNoise := myGui.Add("Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "Noise Tol:")
    grpFreeze.Push(tFreezeNoise)
    edtFreezeNoise := AddFlatEdit(myGui, Format("x{} y{} w60 h{} vFreezeNoise", xInput+20, currY, CtrlH), "-60dB")
    grpFreeze.Push(edtFreezeNoise)

    tFreezeDur := myGui.Add("Text", Format("x{} y{} w80 h{}", xInput+100, currY+3, CtrlH), "Min Dur(s):")
    grpFreeze.Push(tFreezeDur)
    edtFreezeDur := AddFlatEdit(myGui, Format("x{} y{} w60 h{} vFreezeDur", xInput+180, currY, CtrlH), "2")
    grpFreeze.Push(edtFreezeDur)

    tFreezeDesc := myGui.Add("Text", Format("x{} y{} w{} h{} c888888", xLabel, currY+RowH+5, wInput, 40), "Finds segments where the video does not change.")
    grpFreeze.Push(tFreezeDesc)


    ; Register Groups
    for c in grpScene {
        Tabs.Register("Detect", c)
    }
    for c in grpSilence {
        Tabs.Register("Detect", c)
    }
    for c in grpBlack {
        Tabs.Register("Detect", c)
    }
    for c in grpFreeze {
        Tabs.Register("Detect", c)
    }


    ; ==============================================================================
    ; TAB 2: OUTPUT
    ; ==============================================================================
    currY := yContent

    AddTabControl("Output", "Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "Action:")
    ddlAction := DarkDropdown(myGui, xInput, currY, 250, ["Export Report (Text File)", "Split Video at Detection Points"], "OutAction", UpdateUI)
    ddlAction.RegisterToTab(Tabs, "Output")

    currY += RowH + 10
    chkScreens := myGui.Add("Checkbox", Format("x{} y{} w300 h{} vGenScreens c{} Background{}", xInput, currY, CtrlH, Theme.Text, Theme.Bg), "Generate Screenshots at Detection Points")
    SetDarkControl(chkScreens)
    Tabs.Register("Output", chkScreens)

    txtOutNote := AddTabControl("Output", "Text", Format("x{} y{} w{} h{} c888888", xLabel, currY+RowH+10, wInput, 60), "Report: Saves a .txt file with timestamps of all detected events.`nSplit: physically cuts the video (Smart Copy mode) at detected points.`nScreenshots: Saves a JPG for every detected event.")


    ; ==============================================================================
    ; FOOTER
    ; ==============================================================================
    yFooter := 300
    myGui.Add("Text", Format("x0 y{} w{} h65 Background{}", yFooter-3, GuiWidth, Theme.DarkPanel), "")

    btnProcess := SexyButton(myGui, 380, yFooter+10, 140, 35, "Start Analysis", StartProcess)
    btnProcess.Beautify()

    btnCancel := SexyButton(myGui, 380, yFooter+10, 140, 35, "Cancel", CancelProcess)
    btnCancel.Visible := false
    btnCancel.setBorders([Theme.AltAccent,Theme.AltAccent,Theme.AltAccent,Theme.AltAccent])
    btnCancel.SetTextColour(Theme.AltAccent)

    ; Status Bar
    yStatus := yFooter + 45
    progressBar := myGui.Add("Progress", Format("x0 y{} w{} h3 c{} Background{}", yStatus, GuiWidth, Theme.Accent, Theme.DarkPanel, "Range0-100 vMyProgress"), 0)

    myGui.SetFont("s8 c" Theme.Text, "Fixedsys")
    sb := myGui.Add("Text", Format("x0 y{} w{} h20 c{} Background{} +0x200 Center vStatusText", yStatus+3, GuiWidth, Theme.Accent, Theme.StatusBg), "Idle")

    ; Init
    UpdateUI()
    Tabs.Switch("Detect")
    myGui.Show(Format("w{} h{}", GuiWidth, yStatus+23))


    ; ==============================================================================
    ; LOGIC
    ; ==============================================================================

    AddTabControl(tabName, ctrlType, options, text := "") {
        if (ctrlType == "Edit")
            c := AddFlatEdit(myGui, options, text)
        else
            c := myGui.Add(ctrlType, options " Background" Theme.Bg, text)
        Tabs.Register(tabName, c)
        return c
    }

    OnTabChanged(newTab) {
        UpdateUI()
    }

    UpdateUI(*) {
        mode := ddlMode.Text
        
        ; Helper to toggle groups
        SetGrp := (grp, show) => ((show && Tabs.Current == "Detect") ? Vis(grp, 1) : Vis(grp, 0))
        Vis(grp, state) {
            for c in grp
                c.Visible := state
        }
        
        SetGrp(grpScene, mode == "Scene Detection (Cuts)")
        SetGrp(grpSilence, mode == "Silence Detection (Audio)")
        SetGrp(grpBlack, mode == "Black Frame Detection")
        SetGrp(grpFreeze, mode == "Freeze Frame Detection")
    }

    SelectInput(*) {
        path := FileSelect(1, , "Select Input Media", "Media (*.mp4; *.mkv; *.avi; *.mov; *.webm; *.mp3; *.wav)")
        if path
            edtInput.Value := path
    }

    HandleDropFiles(guiObj, ctrlObj, fileArray, x, y) {
        if (fileArray.Length > 0)
            edtInput.Value := fileArray[1]
    }

    StartProcess(*) {
        saved := myGui.Submit(0)
        if (saved.InputFile == "")
            return customDialog({message: "Select an input file."}, darkPreset)
            
        SplitPath(saved.InputFile, , &dir, , &nameNoExt)
        
        ; 1. Build Analysis Command
        ; We run FFmpeg and parse the log output to find timestamps
        filterStr := ""
        
        if (saved.DetectMode == "Scene Detection (Cuts)") {
            ; select='gt(scene,0.3)',showinfo
            filterStr := "select='gt(scene," saved.SceneThresh ")',showinfo"
        } 
        else if (saved.DetectMode == "Silence Detection (Audio)") {
            ; silencedetect=noise=-50dB:d=2
            filterStr := "silencedetect=noise=" saved.SilLevel ":d=" saved.SilDur
        }
        else if (saved.DetectMode == "Black Frame Detection") {
            ; blackdetect=d=2:pix_th=0.00
            filterStr := "blackdetect=d=" saved.BlackDur ":pic_th=" saved.BlackRatio
        }
        else if (saved.DetectMode == "Freeze Frame Detection") {
            ; freezedetect=n=-60dB:d=2
            filterStr := "freezedetect=n=" saved.FreezeNoise ":d=" saved.FreezeDur
        }
        
        logFile := A_Temp "\recognition_log_" A_TickCount ".txt"
        try FileDelete(logFile)
        
        cmdArgs := []
        cmdArgs.Push("-hide_banner")
        cmdArgs.Push("-i", Format('"{1}"', saved.InputFile))
        
        if (InStr(saved.DetectMode, "Silence")) {
            cmdArgs.Push("-af", Format('"{1}"', filterStr))
            cmdArgs.Push("-f", "null", "-") ; Audio filter, null output
        } else {
            cmdArgs.Push("-vf", Format('"{1}"', filterStr))
            cmdArgs.Push("-f", "null", "-") ; Video filter
        }
        
        ; We need to capture stderr to file manually here as wrapper does mostly progress
        ; But wrapper Run method does handle log capture if we ask it to via OnFinish?
        ; The wrapper deletes the log file usually. Let's use custom Run for analysis.
        
        ff := FFWrapper.ffmpegPath
        ; Construct raw command string for RunWait to ensure we keep the log
        rawCmd := Format('"{1}" {2} 2> "{3}"', ff, JoinArgs(cmdArgs), logFile)
        
        sb.Text := " Analyzing..."
        progressBar.Value := 50
        
        RunWait(A_ComSpec ' /c "' rawCmd '"', , "Hide")
        
        if !FileExist(logFile) {
            sb.Text := " Analysis Failed."
            return
        }
        
        ; 2. Parse Results
        logContent := FileRead(logFile)
        timestamps := ParseLog(logContent, saved.DetectMode)
        
        FileDelete(logFile)
        
        if (timestamps.Length == 0) {
            sb.Text := " No events found."
            customDialog({message: "Analysis finished but no events were detected with current settings."}, darkPreset)
            progressBar.Value := 0
            return
        }
        
        ; 3. Perform Action
        if (saved.OutAction == "Export Report (Text File)") {
            savePath := FileSelect("S", dir "\" nameNoExt "_report.txt", "Save Report", "Text (*.txt)")
            if (savePath) {
                f := FileOpen(savePath, "w")
                f.Write("Analysis Report for: " saved.InputFile "`n")
                f.Write("Mode: " saved.DetectMode "`n")
                f.Write("Events Detected: " timestamps.Length "`n`n")
                for ts in timestamps
                    f.Write(Format("{1} - {2}`n", FormatSeconds(ts.start), (ts.HasOwnProp("end") ? FormatSeconds(ts.end) : "Point")))
                f.Close()
                sb.Text := " Report Saved."
                Run(savePath)
            }
        } 
        else if (saved.OutAction == "Split Video at Detection Points") {
            ; Only support simple splitting for now (first 10 segments to avoid explosion?)
            ; Actually, creating a segment list is better.
            ; FFmpeg segment muxer requires regular intervals usually.
            ; For cuts detection, we need to generate specific commands.
            
            count := 0
            limit := 20 ; Safety limit
            
            sb.Text := " Splitting..."
            
            ; Loop through timestamps and cut
            ; Start from 0
            lastPos := 0
            for i, ts in timestamps {
                if (i > limit)
                    break
                    
                cutPoint := ts.start
                if (cutPoint <= lastPos)
                    continue
                    
                outFile := dir "\" nameNoExt "_scene" i ".mp4"
                
                ; Cut segment
                cutArgs := []
                cutArgs.Push("-y", "-ss", lastPos, "-to", cutPoint, "-i", Format('"{1}"', saved.InputFile), "-c", "copy", Format('"{1}"', outFile))
                
                RunWait(Format('"{1}" {2}', ff, JoinArgs(cutArgs)), , "Hide")
                lastPos := cutPoint
                count++
            }
            sb.Text := " Split Complete."
            customDialog({message: Format("Created {} segments in source folder.", count)}, darkPreset)
        }
        
        ; 4. Screenshots
        if (saved.GenScreens) {
            sb.Text := " Saving Screens..."
            imgDir := dir "\" nameNoExt "_screens"
            if !DirExist(imgDir)
                DirCreate(imgDir)
                
            limit := 20
            for i, ts in timestamps {
                if (i > limit)
                    break
                
                outFile := imgDir "\event_" i ".jpg"
                snapArgs := []
                snapArgs.Push("-y", "-ss", ts.start, "-i", Format('"{1}"', saved.InputFile), "-vframes", "1", "-q:v", "2", Format('"{1}"', outFile))
                
                RunWait(Format('"{1}" {2}', ff, JoinArgs(snapArgs)), , "Hide")
            }
            sb.Text := " Screenshots Saved."
        }
        
        progressBar.Value := 100
    }

    ParseLog(content, mode) {
        events := []
        
        if (mode == "Scene Detection (Cuts)") {
            ; Look for: pts_time:12.345
            pos := 1
            while (pos := RegExMatch(content, "pts_time:([\d\.]+)", &m, pos)) {
                time := Float(m[1])
                if (events.Length == 0 || time > events[events.Length].start + 0.5) ; Debounce
                    events.Push({start: time})
                pos += StrLen(m[0])
            }
        }
        else if (mode == "Silence Detection (Audio)") {
            ; silence_start: 12.5
            ; silence_end: 15.2
            pos := 1
            while (pos := RegExMatch(content, "silence_start:\s*([\d\.]+)", &mStart, pos)) {
                start := Float(mStart[1])
                end := 0
                
                ; Find corresponding end
                endPos := RegExMatch(content, "silence_end:\s*([\d\.]+)", &mEnd, pos)
                if (endPos)
                    end := Float(mEnd[1])
                
                events.Push({start: start, end: end})
                pos := endPos ? endPos : pos + 1
            }
        }
        else if (mode == "Black Frame Detection") {
            ; black_start:12.3 black_end:14.5
            pos := 1
            while (pos := RegExMatch(content, "black_start:([\d\.]+)", &mStart, pos)) {
                start := Float(mStart[1])
                end := 0
                endPos := RegExMatch(content, "black_end:([\d\.]+)", &mEnd, pos)
                if (endPos)
                    end := Float(mEnd[1])
                events.Push({start: start, end: end})
                pos := endPos ? endPos : pos + 1
            }
        }
        
        return events
    }

    JoinArgs(arr) {
        str := ""
        for a in arr
            str .= " " a
        return str
    }

    CancelProcess(*) {
        ; Placeholder
    }
}
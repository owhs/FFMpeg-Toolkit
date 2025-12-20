

/*
    FFmpeg Screen Recorder & Timelapse Tool (AHK v2)
    ------------------------------------------------
    Capture specific screen areas as video or timelapse image sequences.
    Features:
    - Area Selection (Click & Drag, Full Screen, Multi-Monitor)
    - Mouse Capture Toggle
    - Timelapse Mode (Capture images -> Auto-stitch)
    - Custom Frame Rates & Quality Options
    - Safe Recording (Records to MKV, remuxes to MP4)
    - Hotkey (F10) to Stop
*/

#Include ..\lib\utils.ahk
ScreenRecorder() {
    static RecorderState := "Idle" ; Idle, Recording, Stitching
    static RecordingPID := 0
    static TimelapseDir := ""
    static LogDir := A_Temp 
    
    ; Selection State variables
    static SelGui := "", RectGui := "", SelX := 0, SelY := 0
    
    local ToolTitle := "Screen Recorder"

    ; ==============================================================================
    ; GUI CREATION
    ; ==============================================================================
    myGui := Gui("-Resize -MaximizeBox", ToolTitle)
    myGui.SetFont("s9 c" Theme.Text, "Segoe UI")
    myGui.BackColor := Theme.Bg

    InitWindowUtils(myGui)
    
    ; Attach FFJob for standard protection (e.g. during stitching)
    myGui.FFJob := FFWrapper
    
    ; Attach Custom Check for Recording state
    myGui.OnCloseCheck := CloseRecorderCheck
    
    ; Use Safe Close
    myGui.OnEvent("Close", (*) => TryCloseWindow(myGui))

    GuiWidth := 500
    GuiHeight := 540

    ; --- HEADER ---
    myGui.Add("Text", Format("x0 y0 w{} h40 Background{}", GuiWidth, Theme.DarkPanel), "")
    myGui.SetFont("s12 w600")
    myGui.Add("Text", Format("x15 y0 w{} h40 +0x200 BackgroundTrans c{}", GuiWidth, Theme.Accent), "Screen Capture")
    myGui.SetFont("s9 w400")

    yStart := 55
    xLabel := 30
    xInput := 110
    CtrlH := 26

    ; --- AREA SELECTION ---
    AddGroup(myGui, yStart, "Capture Area", GuiWidth)
    y := yStart + 30

    ; Monitor Selection
    myGui.Add("Text", Format("x{} y{} w70 h{} +0x200", xLabel, y+3, CtrlH), "Source:")
    
    mons := ["Primary Monitor"]
    Loop MonitorGetCount()
        mons.Push("Monitor " A_Index)
    mons.Push("All Screens (Virtual)")
    
    ddlMon := DarkDropdown(myGui, xInput, y, 200, mons, "MonSelect", SelectMonitor)
    
    ; Draw Button
    btnSelect := SexyButton(myGui, xInput + 210, y, 100, 30, "Draw Area", StartDrawSelection)
    btnFull   := SexyButton(myGui, xInput + 210, y+40, 100, 26, "Full Screen", SetFullScreen)
    
    ; Coordinates Row (Compact)
    y += 40
    myGui.SetFont("s8")
    myGui.Add("Text", Format("x{} y{} w20 h{} +0x200", xLabel, y+3, CtrlH), "X:")
    edtX := AddFlatEdit(myGui, Format("x{} y{} w40 h{} Number vRecX", xLabel+20, y, CtrlH), "0")
    
    myGui.Add("Text", Format("x{} y{} w20 h{} +0x200", xLabel+70, y+3, CtrlH), "Y:")
    edtY := AddFlatEdit(myGui, Format("x{} y{} w40 h{} Number vRecY", xLabel+90, y, CtrlH), "0")
    
    myGui.Add("Text", Format("x{} y{} w20 h{} +0x200", xLabel+140, y+3, CtrlH), "W:")
    edtW := AddFlatEdit(myGui, Format("x{} y{} w40 h{} Number vRecW", xLabel+160, y, CtrlH), "1920")
    
    myGui.Add("Text", Format("x{} y{} w20 h{} +0x200", xLabel+210, y+3, CtrlH), "H:")
    edtH := AddFlatEdit(myGui, Format("x{} y{} w40 h{} Number vRecH", xLabel+230, y, CtrlH), "1080")
    myGui.SetFont("s9")

    ; --- SETTINGS ---
    y += 45
    AddGroup(myGui, y, "Settings", GuiWidth)
    y += 30

    myGui.Add("Text", Format("x{} y{} w70 h{} +0x200", xLabel, y+3, CtrlH), "Mode:")
    ddlMode := DarkDropdown(myGui, xInput, y, 150, ["Normal Video", "Timelapse"], "RecMode", UpdateUI)
    
    chkMouse := myGui.Add("Checkbox", Format("x290 y{} w150 h{} vCapMouse Checked c{} Background{}", y+3, CtrlH, Theme.Text, Theme.Bg), "Capture Mouse")
    SetDarkControl(chkMouse)

    y += 35
    ; Video Settings
    txtFPS := myGui.Add("Text", Format("x{} y{} w70 h{} +0x200", xLabel, y+3, CtrlH), "Rec FPS:")
    ddlFPS := DarkDropdown(myGui, xInput, y, 150, ["60", "30", "24", "15"], "RecFPS")
    
    ; Timelapse Settings (Hidden initially) - Row 1
    txtInt := myGui.Add("Text", Format("x{} y{} w70 h{} +0x200 Hidden", xLabel, y+3, CtrlH), "Capture:")
    
    ; Define input control
    edtTlInt := AddFlatEdit(myGui, Format("x{} y{} w40 h{} vTlInterval Hidden", xInput, y, CtrlH), "2")
    ddlTlUnit := DarkDropdown(myGui, xInput+45, y, 130, ["Seconds per Shot", "Shots per Second"], "TlUnit", UpdateCalc)
    
    ; Timelapse Output FPS - Row 1 (Right side)
    txtOutFPS := myGui.Add("Text", Format("x{} y{} w60 h{} +0x200 Hidden", xInput+185, y+3, CtrlH), "Play FPS:")
    ; Default to 30fps (Index 6 in list below)
    ddlOutFPS := DarkDropdown(myGui, xInput+245, y, 60, ["1", "5", "10", "15", "24", "30", "60"], "TlFPS", UpdateCalc, 6)
    
    y += 35
    ; Calculator Text - Row 2
    txtCalc := myGui.Add("Text", Format("x{} y{} w380 h20 c888888 +0x200 Hidden", xInput, y+5), "Calc: ...")
    
    ; Hook change event for calculator
    edtTlInt.OnEvent("Change", UpdateCalc)

    y += 45 
    ; Quality & Format
    myGui.Add("Text", Format("x{} y{} w70 h{} +0x200", xLabel, y+3, CtrlH), "Quality:")
    qualOpts := ["Lossless (CRF 0)", "Visually Lossless (CRF 17)", "High Quality (CRF 23)", "Balanced (CRF 28)", "Small Size (CRF 32)"]
    ddlQuality := DarkDropdown(myGui, xInput, y, 200, qualOpts, "RecQuality",,2)
    
    y += 35
    myGui.Add("Text", Format("x{} y{} w70 h{} +0x200", xLabel, y+3, CtrlH), "Format:")
    ddlFormat := DarkDropdown(myGui, xInput, y, 200, ["MP4", "MKV", "GIF", "Image Sequence"], "OutFormat")

    ; --- FOOTER ---
    yFooter := GuiHeight - 60
    myGui.Add("Text", Format("x0 y{} w{} h60 Background{}", yFooter, GuiWidth, Theme.DarkPanel), "")

    ; Status Bar
    sb := myGui.Add("Text", Format("x20 y{} w300 h20 c888888 +0x200 vStatusText BackgroundTrans", yFooter+20), "Ready to record.")
    
    ; Record Button
    btnRec := SexyButton(myGui, GuiWidth-140, yFooter+12, 120, 36, "Start Rec", ToggleRecording)
    btnRec.Beautify(Theme.AltAccent) ; Red button for recording

    myGui.Show(Format("w{} h{}", GuiWidth, GuiHeight))
    
    UpdateUI() ; Initialize visibility & calculator
    SelectMonitor() ; Initialize coords

    ; ==============================================================================
    ; HELPERS
    ; ==============================================================================
    
    AddGroup(guiObj, yPos, title, totalW) {
        guiObj.SetFont("s9 c" Theme.Accent)
        guiObj.Add("Text", Format("x20 y{} w{} h20", yPos, totalW), "--- " title " ---")
        guiObj.SetFont("s9 c" Theme.Text)
    }

    SelectMonitor(*) {
        choice := ddlMon.Text
        
        if (choice == "All Screens (Virtual)") {
            ; Virtual Screen
            edtX.Value := SysGet(76) ; SM_XVIRTUALSCREEN
            edtY.Value := SysGet(77) ; SM_YVIRTUALSCREEN
            edtW.Value := SysGet(78) ; SM_CXVIRTUALSCREEN
            edtH.Value := SysGet(79) ; SM_CYVIRTUALSCREEN
            sb.Text := "Area set to All Screens."
            return
        }
        
        monIdx := 1
        if RegExMatch(choice, "Monitor (\d+)", &m)
            monIdx := Integer(m[1])
        
        try {
            MonitorGet(monIdx, &L, &T, &R, &B)
            edtX.Value := L
            edtY.Value := T
            edtW.Value := R - L
            edtH.Value := B - T
            sb.Text := "Area set to " choice "."
        }
    }
    
    SetFullScreen(*) {
        SelectMonitor() ; Re-trigger monitor selection logic which sets full coords
    }

    UpdateUI(*) {
        mode := ddlMode.Text
        isTL := (mode == "Timelapse")
        
        txtFPS.Visible := !isTL
        ddlFPS.SetVisible(!isTL)
        
        txtInt.Visible := isTL
        edtTlInt.Visible := isTL
        ddlTlUnit.SetVisible(isTL)
        
        txtOutFPS.Visible := isTL
        ddlOutFPS.SetVisible(isTL)
        txtCalc.Visible := isTL
        
        if isTL
            UpdateCalc()
    }
    
    UpdateCalc(*) {
        ; Use DIRECT object values instead of Submit() to ensure reliability
        txtVal := edtTlInt.Value
		
        
        if (txtVal == "" || !IsNumber(txtVal)) {
            txtCalc.Text := "Calc: Waiting for input..."
            return
        }
            
        val := Float(txtVal)
        ;if (val <= 0) val := 1
        
		;	MsgBox "val " val
			
        ; Read from Dropdown Object Text directly
        unitStr := ddlTlUnit.Text
        isSecs := (unitStr == "Seconds per Shot")
        
        if (isSecs) {
            ; val is Seconds per 1 frame
            framesPerHour := 3600 / val
			;MsgBox "isSecs " framesPerHour
            desc := Format("1 shot every {}s", val)
        } else {
            ; val is Frames per 1 second
            framesPerHour := 3600 * val
			;MsgBox "not Secs " framesPerHour
            desc := Format("{} shots per sec", val)
        }
            
        fpsStr := ddlOutFPS.Text
        outFpsVal := Float(fpsStr != "" ? fpsStr : "30")
        if (outFpsVal <= 0)
            outFpsVal := 30
            
        vidSecs := framesPerHour / outFpsVal
        
        timeStr := ""
        if (vidSecs < 60)
            timeStr := Round(vidSecs, 1) " Secs"
        else if (vidSecs < 3600)
            timeStr := Round(vidSecs / 60, 1) " Mins"
        else 
            timeStr := Round(vidSecs / 3600, 1) " Hrs"
			
        txtCalc.Text := Format("{} | 1h Realtime ≈ {} Video", desc, timeStr)
    }

    ; --- DRAW SELECTION LOGIC ---
    StartDrawSelection(*) {
        ; Create a full-screen, dim overlay
        SelGui := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20") ; E0x20 = Click-through (initially off, but we want to catch clicks)
        SelGui.Opt("-E0x20") ; Ensure we catch clicks
        SelGui.BackColor := "000000"
        WinSetTransparent(100, SelGui) ; Dim screen
        SelGui.Show("x0 y0 w" A_ScreenWidth " h" A_ScreenHeight)
        
        ; Create a second GUI for the selection rectangle (Hollow box effect)
        RectGui := Gui("-Caption +AlwaysOnTop +ToolWindow +Owner" SelGui.Hwnd)
        RectGui.BackColor := Theme.Accent
        WinSetTransparent(100, RectGui)
        
        ; Bind mouse events
        OnMessage(0x201, OnSelDown) ; WM_LBUTTONDOWN
    }

    OnSelDown(wParam, lParam, msg, hwnd) {
        if (hwnd != SelGui.Hwnd)
            return
            
        MouseGetPos(&startX, &startY)
        SelX := startX
        SelY := startY
        
        ; Start tracking mouse move
        SetTimer(TrackMouse, 10)
        KeyWait("LButton")
        SetTimer(TrackMouse, 0)
        
        ; Cleanup
        MouseGetPos(&endX, &endY)
        ConfirmDraw(SelX, SelY, endX, endY)
    }

    TrackMouse() {
        MouseGetPos(&currX, &currY)
        x := Min(SelX, currX)
        y := Min(SelY, currY)
        w := Abs(currX - SelX)
        h := Abs(currY - SelY)
        
        if (RectGui)
            RectGui.Show(Format("x{} y{} w{} h{} NoActivate", x, y, w, h))
    }

    ConfirmDraw(x1, y1, x2, y2) {
        if (SelGui) {
            SelGui.Destroy()
            SelGui := ""
        }
        if (RectGui) {
            RectGui.Destroy()
            RectGui := ""
        }
        
        ; Cleanup OnMessage to prevent leaks/conflicts
        OnMessage(0x201, OnSelDown, 0)

        finalX := Min(x1, x2)
        finalY := Min(y1, y2)
        finalW := Abs(x2 - x1)
        finalH := Abs(y2 - y1)
        
        ; FFmpeg gdigrab requirements (even dimensions)
        if (Mod(finalW, 2) != 0)
            finalW -= 1
        if (Mod(finalH, 2) != 0)
            finalH -= 1
            
        if (finalW < 10 || finalH < 10) {
            sb.Text := "Selection too small."
            return
        }

        edtX.Value := finalX
        edtY.Value := finalY
        edtW.Value := finalW
        edtH.Value := finalH
        sb.Text := Format("Area Set: {}x{} at {},{}", finalW, finalH, finalX, finalY)
        
        ; Restore main window
        myGui.Opt("+AlwaysOnTop")
        myGui.Opt("-AlwaysOnTop")
        WinActivate(myGui.Hwnd)
    }

    ; Custom Check called by TryCloseWindow
    CloseRecorderCheck() {
        if (RecorderState != "Idle") {
            if (MsgBox("Recording in progress. Stop and save?", "Confirm", "YesNo") == "Yes") {
                StopRecording()
                return true ; Allowed to close
            } else {
                return false ; Cancel close
            }
        }
        return true ; Allowed to close
    }

    ; ==============================================================================
    ; RECORDING LOGIC
    ; ==============================================================================

    ToggleRecording(*) {
        if (RecorderState == "Idle")
            StartRecording()
        else
            StopRecording()
    }

    StartRecording() {
        saved := myGui.Submit(0)
        
        if (saved.RecW < 100 || saved.RecH < 100) {
            return customDialog({message:"Invalid Capture Area dimensions."}, darkPreset)
        }

        if (Mod(saved.RecW, 2) != 0)
            saved.RecW -= 1
        if (Mod(saved.RecH, 2) != 0)
            saved.RecH -= 1
            
        ; Note: GDIgrab can capture multiple monitors if coordinated correctly (using desktop), 
        ; but typically restricted to primary or virtual screen bounds.
        
        ext := (saved.OutFormat == "GIF") ? "gif" : (saved.OutFormat == "MKV" ? "mkv" : (saved.OutFormat == "Image Sequence" ? "jpg" : "mp4"))
        
        ; Default to Videos folder
        videoDir := EnvGet("USERPROFILE") "\Videos"
        if !DirExist(videoDir)
            videoDir := A_Desktop
            
        outFile := videoDir "\ScreenRec_" A_Now "." ext
        
        ; Setup for Timelapse or Image Sequence
        if (saved.RecMode == "Timelapse") {
            TimelapseDir := A_Temp "\Rec_TL_" A_TickCount
            DirCreate(TimelapseDir)
            outFile := TimelapseDir "\img_%04d.jpg"
        } else {
            ; Normal Video
            if (saved.OutFormat == "Image Sequence") {
                 ; For normal video but image sequence, allow folder selection
                 selDir := DirSelect("*" videoDir, 3, "Select Folder for Image Sequence")
                 if (!selDir) {
                     return
                 }
                 outFile := selDir "\img_%04d.jpg"
            } else {
                selFile := FileSelect("S", outFile, "Save Recording", "Video (*." ext ")")
                if (!selFile) {
                    return
                }
                outFile := selFile
                if !RegExMatch(outFile, "\." ext "$")
                    outFile .= "." ext
            }
        }

        actualRecFile := outFile
        if (ext == "mp4" && saved.RecMode != "Timelapse") {
            actualRecFile := StrReplace(outFile, ".mp4", "_partial.mkv")
        }

        ; --- BUILD COMMAND ---
        ff := FFWrapper.ffmpegPath
        
        ScreenRecorder.LogFile := A_Temp "\ScreenRec_Log.txt"
        try FileDelete(ScreenRecorder.LogFile)
        try FileAppend("--- Log Init ---`n", ScreenRecorder.LogFile)
        
        drawMouse := (saved.CapMouse) ? "1" : "0"
        
        cmdArgs := []
        cmdArgs.Push("-report", "-loglevel", "info")
        cmdArgs.Push("-f", "gdigrab")
        cmdArgs.Push("-draw_mouse", drawMouse)
        
        if (saved.RecMode == "Timelapse") {
            ; Use the input directly to avoid submit ambiguity
            val := Float(edtTlInt.Value)
            if (val <= 0) val := 1
            
            isSecs := (ddlTlUnit.Text == "Seconds per Shot")
            
            if (isSecs) {
                ; interval in seconds. FPS = 1 / interval
                fps := 1 / val
            } else {
                ; Frames per Second. FPS = val
                fps := val
            }
            
            cmdArgs.Push("-framerate", Format("{:.4f}", fps))
        } else {
            cmdArgs.Push("-framerate", saved.RecFPS)
        }
        
        cmdArgs.Push("-offset_x", saved.RecX)
        cmdArgs.Push("-offset_y", saved.RecY)
        cmdArgs.Push("-video_size", saved.RecW "x" saved.RecH)
        cmdArgs.Push("-i", "desktop")
        
        ; Encoding args
        if (saved.RecMode == "Timelapse" || saved.OutFormat == "Image Sequence") {
            cmdArgs.Push("-q:v", "2")
        } else {
            if (ext == "gif") {
                cmdArgs.Push("-vf", "fps=15,scale=flags=lanczos:w=iw:h=ih,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse")
            } else {
                ; Determine CRF based on Quality Selection
                crf := "0" ; Lossless
                if InStr(saved.RecQuality, "Visually")
                    crf := "17"
                else if InStr(saved.RecQuality, "High")
                    crf := "23"
                else if InStr(saved.RecQuality, "Balanced")
                    crf := "28"
                else if InStr(saved.RecQuality, "Small")
                    crf := "32"
                    
                cmdArgs.Push("-c:v", "libx264", "-preset", "ultrafast", "-crf", crf, "-pix_fmt", "yuv420p")
            }
        }
        
        cmdArgs.Push("-y", Format('"{1}"', actualRecFile))
        
        ; --- EXECUTE ---
        paramStr := ""
        for arg in cmdArgs
            paramStr .= " " arg
            
        cmdStr := Format('"{1}" {2} 2>> "{3}"', ff, paramStr, ScreenRecorder.LogFile)
        ScreenRecorder.LastCmd := cmdStr
        
        oldWD := A_WorkingDir
        SetWorkingDir(LogDir)
        
        try {
            Run('"' ff '"' paramStr, LogDir, "Hide", &pid)
            
            RecordingPID := pid
            RecorderState := "Recording"
            
            btnRec.SetText("STOP (F10)")
            btnRec.SetTextColour(Theme.Text) 
            ; Ensure full border styling
            btnRec.setBorders([Theme.Accent, Theme.Accent, Theme.Accent, Theme.Accent]) 
            
            sb.Text := "Recording... Press F10 to Stop."
            
            ; --- HOTKEY & TRAY ---
            try Hotkey "F10", StopRecording, "On"
            try TraySetIcon("shell32.dll", 264) ; Red record-like icon
            TrayTip "Screen Recorder", "Recording Started. Press F10 to Stop."
            
            ScreenRecorder.FinalFile := outFile
            ScreenRecorder.TempFile  := actualRecFile
            ScreenRecorder.IsTimelapse := (saved.RecMode == "Timelapse")
            ScreenRecorder.NeedsRemux := (ext == "mp4" && saved.RecMode != "Timelapse")
            ScreenRecorder.KeepFrames := (saved.OutFormat == "Image Sequence")
            ScreenRecorder.OutFPS := ddlOutFPS.Text
            
        } catch as e {
            customDialog({message: "Failed to start FFmpeg: " e.Message, detail: "Command:`n" '"' ff '"' paramStr}, errorPreset)
        }
        
        SetWorkingDir(oldWD)
    }

    StopRecording(*) {
        if (RecordingPID) {
            try Hotkey "F10", "Off"
            try TraySetIcon() ; Restore default icon
            
            if ProcessExist(RecordingPID)
                RunWait("taskkill /PID " RecordingPID, , "Hide")
            
            Loop 15 {
                if !ProcessExist(RecordingPID)
                    break
                Sleep(200)
            }
            
            if ProcessExist(RecordingPID)
                RunWait("taskkill /F /PID " RecordingPID, , "Hide")
                
            RecordingPID := 0
        }
        
        RecorderState := "Idle"
        btnRec.SetText("Start Rec")
        btnRec.Beautify(Theme.AltAccent)
        sb.Text := "Stopped."
        
        Sleep(500) 

        if (ScreenRecorder.IsTimelapse) {
            if (ScreenRecorder.KeepFrames) {
                ; Save just frames (Timelapse mode to Image Sequence)
                saveDir := DirSelect("", 3, "Select Folder to Save Frames")
                if (saveDir) {
                    DirMove(TimelapseDir, saveDir "\Timelapse_" A_TickCount)
                    sb.Text := "Frames Saved."
                    Run(saveDir)
                } else {
                    DirDelete(TimelapseDir, true)
                    sb.Text := "Frames Discarded."
                }
            } else {
                StitchTimelapse()
            }
        } else {
            ; Normal Video Mode
            if (ScreenRecorder.KeepFrames) {
                 ; Already saved to user selected folder directly via ffmpeg output
                 sb.Text := "Frames Saved."
                 return
            }
            
            finalPath := ScreenRecorder.FinalFile
            
            if (ScreenRecorder.NeedsRemux) {
                if !FileExist(ScreenRecorder.TempFile) {
                    logFile := GetLatestLogFile()
                    logContent := logFile ? FileRead(logFile) : "No log found."
                    
                    customDialog({
                        title: "Recording Failed", 
                        message: "Temp file not found.", 
                        detail: "Log:`n" logContent,
                        width: 600, detailRows: 15
                    }, errorPreset)
                    return
                }
            
                sb.Text := "Finalizing MP4..."
                
                remuxCmd := Format('"{1}" -y -i "{2}" -c copy "{3}"', FFWrapper.ffmpegPath, ScreenRecorder.TempFile, finalPath)
                
                remuxSuccess := false
                try {
                    RunWait(remuxCmd, , "Hide")
                    if FileExist(finalPath)
                        remuxSuccess := true
                } catch {
                    remuxSuccess := false
                }
                
                if (remuxSuccess) {
                    try FileDelete(ScreenRecorder.TempFile)
                } else {
                    sb.Text := "MP4 conversion failed. Saved as MKV."
                    fallbackPath := StrReplace(finalPath, ".mp4", ".mkv")
                    try FileMove(ScreenRecorder.TempFile, fallbackPath, 1)
                    finalPath := fallbackPath
                }
            }
            
            if FileExist(finalPath) {
                sb.Text := "Saved: " finalPath
                if MsgBox("Recording saved.`nOpen file?", "Success", "YesNo") == "Yes"
                    Run(finalPath)
            } else {
                logFile := GetLatestLogFile()
                logContent := logFile ? FileRead(logFile) : "No log found."
                customDialog({
                    title: "Recording Failed", 
                    message: "Output file missing.", 
                    detail: "Log:`n" logContent,
                    width: 600, detailRows: 15
                }, errorPreset)
            }
        }
    }
    
    GetLatestLogFile() {
        latestTime := 0
        latestFile := ""
        Loop Files, LogDir "\ffmpeg-*.log"
        {
            time := FileGetTime(A_LoopFileFullPath, "M")
            if (DateDiff(time, A_Now, "Seconds") > -60) {
                if (time > latestTime) {
                    latestTime := time
                    latestFile := A_LoopFileFullPath
                }
            }
        }
        return latestFile
    }

    StitchTimelapse() {
        sb.Text := "Stitching Timelapse..."
        RecorderState := "Stitching"
        
        saveFile := FileSelect("S", "Timelapse.mp4", "Save Timelapse Video", "MP4 (*.mp4)")
        if (!saveFile) {
            DirDelete(TimelapseDir, true)
            sb.Text := "Discarded."
            RecorderState := "Idle"
            return
        }
        
        if !RegExMatch(saveFile, "\.mp4$")
            saveFile .= ".mp4"
            
        inputPattern := TimelapseDir "\img_%04d.jpg"
        
        ; Read OutFPS from variable
        outFPS := ScreenRecorder.OutFPS ? ScreenRecorder.OutFPS : "30"
        
        stitchArgs := []
        stitchArgs.Push("-framerate", outFPS) 
        stitchArgs.Push("-i", Format('"{1}"', inputPattern))
        stitchArgs.Push("-c:v", "libx264", "-pix_fmt", "yuv420p")
        stitchArgs.Push("-y", Format('"{1}"', saveFile))
        
        OnStitchFinish(success, result) {
            try DirDelete(TimelapseDir, true)
            RecorderState := "Idle"
            sb.Text := success ? "Timelapse Created!" : "Stitch Failed."
            
            if (success && MsgBox("Timelapse created!`nOpen video?", "Success", "YesNo") == "Yes")
                Run(saveFile)
        }
        
        FFWrapper.Run(stitchArgs, saveFile, (p,t) => (sb.Text := "Stitching: " p "%"), OnStitchFinish)
    }
}

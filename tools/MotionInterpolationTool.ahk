/*
    FFmpeg Motion Interpolation Tool (AHK v2)
    -----------------------------------------
    Uses Optical Flow (minterpolate) to generate new frames.
    Capabilities:
    1. Smoothening: Convert 30fps to 60fps/120fps (Soap Opera Effect).
    2. Slow Motion: Generate intermediate frames for smooth slow-down.
    
    Note: 'minterpolate' is very CPU intensive.
*/
#Requires AutoHotkey v2.0

#Include ..\lib\utils.ahk
MotionInterpolationTool() {
    global AppName := "FFMpeg: Motion Interpolation"

    ; ==============================================================================
    ; GUI CREATION
    ; ==============================================================================
    myGui := Gui("-Resize -MaximizeBox", AppName)
    myGui.SetFont("s9 c" Theme.Text, "Segoe UI")
    myGui.BackColor := Theme.Bg

    InitWindowUtils(myGui)
    myGui.FFJob := FFWrapper
    myGui.OnEvent("Close", (*) => TryCloseWindow(myGui))
    myGui.OnEvent("DropFiles", HandleDropFiles)

    ; --- LAYOUT CONSTANTS ---
    GuiWidth      := 580
    yContentStart := 44 
    RowH          := 32 
    CtrlH         := 24 
    BtnH          := 24

    xLabel  := 15
    xInput  := 90
    wInput  := 380 
    xBtn    := 480
    wBtn    := 90

    ; ==============================================================================
    ; TAB NAVIGATION
    ; ==============================================================================
    myGui.Add("Text", Format("x0 y0 w{} h40 Background{}", GuiWidth, Theme.DarkPanel), "")
    Tabs := TabManager(myGui, Theme)

    tW := GuiWidth / 3
    Tabs.Add("1. Input & Target", 0,    0, tW, 40, "Input")
    Tabs.Add("2. Algorithm",      tW,   0, tW, 40, "Algo")
    Tabs.Add("3. Output",         tW*2, 0, tW, 40, "Output")

    ; ==============================================================================
    ; TAB 1: INPUT & TARGET
    ; ==============================================================================
    currY := yContentStart + 10

    ; Input
    AddTabControl("Input", "Text", Format("x{} y{} w70 h{}", xLabel, currY+3, CtrlH), "Input File:")
    edtInput := AddTabControl("Input", "Edit", Format("x{} y{} w{} h{} ReadOnly vInputFile", xInput, currY, wInput, CtrlH))
    btnBrowse := SexyButton(myGui, xBtn, currY-1, wBtn, BtnH+2, "Browse...", SelectInput)
    btnBrowse.RegisterToTab(Tabs, "Input")

    currY += RowH + 15
    
    ; Target FPS
    AddTabControl("Input", "Text", Format("x{} y{} w70 h{}", xLabel, currY+3, CtrlH), "Target FPS:")
    ddlFPS := DarkDropdown(myGui, xInput, currY, 160, ["60 FPS", "120 FPS", "144 FPS", "Double Source (2x)", "Same as Source"], "TargetFPS")
    ddlFPS.RegisterToTab(Tabs, "Input")

    ; Playback Speed
    AddTabControl("Input", "Text", Format("x270 y{} w50 h{}", currY+3, CtrlH), "Speed:")
    ddlSpeed := DarkDropdown(myGui, 320, currY, 150, ["1.0x (Realtime Smooth)", "0.5x (Slow Motion)", "0.25x (Super Slow)", "0.1x (Extreme)"], "PlaySpeed")
    ddlSpeed.RegisterToTab(Tabs, "Input")

    currY += RowH + 15
    
    ; Warning Text
    AddTabControl("Input", "Text", Format("x{} y{} w{} h60 c{}", xLabel, currY, GuiWidth-30, Theme.AltAccent), "⚠️ PERFORMANCE WARNING:`nMotion Interpolation (Optical Flow) is extremely CPU intensive.`nA 1-minute video can take 10-30 minutes to render depending on settings.`nUse 'Preview' to test settings before committing.")

    ; ==============================================================================
    ; TAB 2: ALGORITHM (minterpolate settings)
    ; ==============================================================================
    currY := yContentStart + 10

    ; Mode
    AddTabControl("Algo", "Text", Format("x{} y{} w70 h{}", xLabel, currY+3, CtrlH), "Mode:")
    ddlMode := DarkDropdown(myGui, xInput, currY, wInput, ["MCI (Motion Compensated - Optical Flow)", "Blend (Fade - Low Quality)"], "MiMode")
    ddlMode.RegisterToTab(Tabs, "Algo")

    currY += RowH + 10
    
    ; Motion Estimation (MCI Quality)
    AddTabControl("Algo", "Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "Estimation:")
    ddlEst := DarkDropdown(myGui, xInput, currY, wInput, ["Bidirectional (Better Quality)", "Bilateral (Faster)"], "MeMode")
    ddlEst.RegisterToTab(Tabs, "Algo")

    currY += RowH + 10

    ; Motion Compensation
    AddTabControl("Algo", "Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "Compensate:")
    ddlComp := DarkDropdown(myGui, xInput, currY, wInput, ["AOBMC (Adaptive Overlapped - Best)", "OBMC (Overlapped - Good)"], "McMode")
    ddlComp.RegisterToTab(Tabs, "Algo")

    currY += RowH + 15

    ; Scene Change Threshold
    AddTabControl("Algo", "Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "Scene Det:")
    sldScene := AddTabControl("Algo", "Slider", Format("x{} y{} w300 h{} vSceneThresh Range0-20 ToolTip", xInput, currY, CtrlH), 7)
    AddTabControl("Algo", "Text", Format("x400 y{} w150 h{} c888888", currY, CtrlH), "(Lower = More Sensitive)")

    ; ==============================================================================
    ; TAB 3: OUTPUT
    ; ==============================================================================
    currY := yContentStart + 10

    ; Codec
    AddTabControl("Output", "Text", Format("x{} y{} w70 h{}", xLabel, currY+3, CtrlH), "Codec:")
    ddlCodec := DarkDropdown(myGui, xInput, currY, wInput, ["H.264 (MP4) - Compatible", "H.265 (MP4) - Efficient", "ProRes (MOV) - Editing"], "OutCodec")
    ddlCodec.RegisterToTab(Tabs, "Output")

    currY += RowH + 10
    
    ; Quality
    AddTabControl("Output", "Text", Format("x{} y{} w70 h{}", xLabel, currY+3, CtrlH), "Quality:")
    ddlQual := DarkDropdown(myGui, xInput, currY, wInput, ["High (CRF 18)", "Medium (CRF 23)", "Low (CRF 28)"], "OutQuality")
    ddlQual.RegisterToTab(Tabs, "Output")

    ; ==============================================================================
    ; FOOTER
    ; ==============================================================================
    yFooter := 260

    myGui.Add("Text", Format("x0 y{} w{} h65 Background{}", yFooter-3, GuiWidth, Theme.DarkPanel), "")

    ; Presets
    SexyButton(myGui, 10, yFooter+5, 80, 30, "Save", SavePreset)
    SexyButton(myGui, 100, yFooter+5, 80, 30, "Load", LoadPreset)

    ; Preview (Short Chunk)
    SexyButton(myGui, 280, yFooter+5, 120, 30, "Preview (3s)", GeneratePreviewChunk)

    ; Action Buttons
    btnRun := SexyButton(myGui, 410, yFooter+5, 120, 30, "Render", StartRender)
    btnRun.Beautify()
    
    btnCancel := SexyButton(myGui, 410, yFooter+5, 120, 30, "Cancel", CancelRender)
    btnCancel.Visible := false
    btnCancel.setBorders([Theme.AltAccent,Theme.AltAccent,Theme.AltAccent,Theme.AltAccent])
    btnCancel.SetTextColour(Theme.AltAccent)

    ; Status Bar
    yStatus := yFooter + 38
    progressBar := myGui.Add("Progress", Format("x0 y{} w{} h3 c{} Background{}", yStatus, GuiWidth, Theme.Accent, Theme.DarkPanel, "Range0-100 vMyProgress"), 0)

    myGui.SetFont("s8 c" Theme.Text, "Fixedsys")
    sb := myGui.Add("Text", Format("x0 y{} w{} h20 c{} Background{} +0x200 Center vStatusText", yStatus+3, GuiWidth, Theme.Accent, Theme.StatusBg), "Ready")

    Tabs.Switch("Input")
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

    SelectInput(*) {
        path := FileSelect(1, , "Select Input Video", "Video (*.mp4; *.mkv; *.webm; *.avi; *.mov)")
        if path 
            edtInput.Value := path
    }

    HandleDropFiles(guiObj, ctrlObj, fileArray, x, y) {
        if fileArray.Length > 0
            edtInput.Value := fileArray[1]
    }

    ; ==============================================================================
    ; LOGIC ENGINE
    ; ==============================================================================
    
    GetSourceFPS(file) {
        ; Use ffprobe to get exact FPS
        tempLog := A_Temp "\fps_probe_" A_TickCount ".txt"
        ff := FFWrapper.ffmpegPath
        if InStr(ff, "\") {
             SplitPath(ff, , &dir)
             probe := dir "\ffprobe.exe"
        } else {
             probe := "ffprobe"
        }
        
        cmd := Format('"{1}" -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "{2}" > "{3}"', probe, file, tempLog)
        RunWait(A_ComSpec " /c " cmd, , "Hide")
        
        if FileExist(tempLog) {
            rateStr := FileRead(tempLog)
            FileDelete(tempLog)
            if InStr(rateStr, "/") {
                parts := StrSplit(rateStr, "/")
                if (parts.Length == 2 && parts[2] > 0)
                    return parts[1] / parts[2]
            } else if IsNumber(Trim(rateStr)) {
                return Float(Trim(rateStr))
            }
        }
        return 30.0 ; Default fallback
    }

    BuildFilterString(saved, srcFPS) {
        ; 1. Determine Target FPS
        targetFPS := 60
        if (saved.TargetFPS == "120 FPS")
            targetFPS := 120
        else if (saved.TargetFPS == "144 FPS")
            targetFPS := 144
        else if (saved.TargetFPS == "Double Source (2x)")
            targetFPS := srcFPS * 2
        else if (saved.TargetFPS == "Same as Source")
            targetFPS := srcFPS

        ; 2. Determine Speed Multiplier (for Slow Mo)
        speedMult := 1.0
        if InStr(saved.PlaySpeed, "0.5x")
            speedMult := 0.5
        else if InStr(saved.PlaySpeed, "0.25x")
            speedMult := 0.25
        else if InStr(saved.PlaySpeed, "0.1x")
            speedMult := 0.1

        ; 3. Construct minterpolate
        ; Format: minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:scd_threshold=5
        
        mode := InStr(saved.MiMode, "Blend") ? "blend" : "mci"
        me   := InStr(saved.MeMode, "Bilateral") ? "bilat" : "bidir"
        mc   := InStr(saved.McMode, "OBMC") ? "obmc" : "aobmc" ; Default AOBMC is simpler in syntax if 'obmc' selected specifically
        if InStr(saved.McMode, "AOBMC")
            mc := "aobmc"

        ; If slow motion, we interpolate to (Target / Speed) to get enough frames, 
        ; then slow down pts.
        ; Example: Src 30. Target 60. Speed 0.5.
        ; Result needs to be 60fps play rate, but content moves at half speed.
        ; We need 120 frames generated per second of input.
        
        interpFPS := targetFPS / speedMult
        
        filter := Format("minterpolate=fps={1}:mi_mode={2}:me_mode={3}:mc_mode={4}:scd_threshold={5}", interpFPS, mode, me, mc, saved.SceneThresh)
        
        ; 4. Apply Speed Change (PTS) if needed
        if (speedMult != 1.0) {
            ; setpts = (1/speed) * PTS
            ; e.g. 0.5x speed -> 2.0 * PTS (Times get larger, video slower)
            ptsFactor := 1.0 / speedMult
            filter .= Format(",setpts={1}*PTS", ptsFactor)
            
            ; Force output FPS back to target (since minterpolate set the stream to the high calc value)
            ; Use fps filter to reset container header without dropping frames (since we stretched PTS)
            ; Actually, minterpolate sets the stream properties. 
            ; If we generated 120fps (for 0.5x of 60fps), and we stretch PTS by 2, we effectively have frames for 60fps playback.
            ; We might need -r at output to enforce header.
        }

        return {filter: filter, outFPS: targetFPS}
    }

    ; ==============================================================================
    ; ACTIONS
    ; ==============================================================================

    GeneratePreviewChunk(*) {
        saved := myGui.Submit(0)
        if (saved.InputFile == "") 
            return customDialog({message: "Select an input file first."}, darkPreset)
        
        sb.Text := " Generating 3s Preview (Please Wait)..."
        
        try {
            srcFPS := GetSourceFPS(saved.InputFile)
            data := BuildFilterString(saved, srcFPS)
            
            previewFile := A_Temp "\interpol_prev_" A_TickCount ".mp4"
            
            ; -ss 10 (skip first 10s), -t 3 (3 seconds duration)
            ; We use 3 seconds because minterpolate is VERY slow.
            
            cmdArgs := ["-y", "-ss", "00:00:05", "-t", "3", "-i", Format('"{1}"', saved.InputFile)]
            cmdArgs.Push("-vf", Format('"{1}"', data.filter))
            cmdArgs.Push("-r", data.outFPS) ; Enforce output container FPS
            
            ; Use fast encoder for preview
            cmdArgs.Push("-c:v", "libx264", "-preset", "ultrafast", "-crf", "23")
            cmdArgs.Push("-an") ; No audio for preview
            
            OnPreviewFinish(success, result) {
                if success {
                    sb.Text := " Preview Ready."
                    Run(previewFile)
                } else {
                    sb.Text := " Preview Failed."
                    ShowErrorLog(result)
                }
            }

            FFWrapper.Run(cmdArgs, previewFile, (p, t) => (sb.Text := "Rendering Preview... " p "%"), OnPreviewFinish)

        } catch as e {
            sb.Text := " Error."
            customDialog({title:"Error", message:e.Message}, errorPreset)
        }
    }

    StartRender(*) {
        saved := myGui.Submit(0)
        if (saved.InputFile == "") 
            return customDialog({message: "Select an input file first."}, darkPreset)
            
        ; Output Path
        SplitPath(saved.InputFile, , &dir, , &nameNoExt)
        ext := InStr(saved.OutCodec, "MOV") ? "mov" : "mp4"
        outPath := FileSelect("S", dir "\" nameNoExt "_smooth." ext, "Save Video", "Video (*." ext ")")
        if !outPath
            return

        if !RegExMatch(outPath, "\." ext "$")
            outPath .= "." ext

        ; Build Command
        try {
            srcFPS := GetSourceFPS(saved.InputFile)
            data := BuildFilterString(saved, srcFPS)
            
            cmdArgs := ["-y", "-i", Format('"{1}"', saved.InputFile)]
            cmdArgs.Push("-vf", Format('"{1}"', data.filter))
            cmdArgs.Push("-r", data.outFPS)

            ; Codec settings
            if InStr(saved.OutCodec, "H.265")
                cmdArgs.Push("-c:v", "libx265", "-pix_fmt", "yuv420p")
            else if InStr(saved.OutCodec, "ProRes")
                cmdArgs.Push("-c:v", "prores_ks", "-profile:v", "3")
            else
                cmdArgs.Push("-c:v", "libx264", "-pix_fmt", "yuv420p")

            ; Quality
            if !InStr(saved.OutCodec, "ProRes") {
                crf := InStr(saved.OutQuality, "High") ? 18 : InStr(saved.OutQuality, "Medium") ? 23 : 28
                cmdArgs.Push("-crf", crf)
            }

            ; Audio
            if InStr(saved.PlaySpeed, "1.0x") {
                cmdArgs.Push("-c:a", "copy")
            } else {
                ; If slow mo, we must process audio or disable it
                ; Simple approach: Disable audio for slow motion to avoid complex atempo chaining
                ; Or stretch it. Let's stretch it.
                speedMult := 1.0
                if InStr(saved.PlaySpeed, "0.5x")
                    speedMult := 0.5
                else if InStr(saved.PlaySpeed, "0.25x")
                    speedMult := 0.25
                else if InStr(saved.PlaySpeed, "0.1x")
                    speedMult := 0.1
                
                if (speedMult != 1.0) {
                     ; atempo filter is limited 0.5 to 2.0. Chain for extreme slow mo.
                     ; Tempo = SpeedMult
                     aFilter := ""
                     cur := speedMult
                     while (cur < 0.5) {
                         aFilter .= (aFilter == "" ? "" : ",") "atempo=0.5"
                         cur /= 0.5
                     }
                     aFilter .= (aFilter == "" ? "" : ",") "atempo=" cur
                     cmdArgs.Push("-af", Format('"{1}"', aFilter))
                }
            }

            ; UI State
            btnRun.Visible := false
            btnCancel.Visible := true
            progressBar.Value := 0
            sb.Text := " Starting Render..."

            OnProgress(pct, text) {
                progressBar.Value := pct
                sb.Text := text
            }

            OnFinish(success, result) {
                btnRun.Visible := true
                btnCancel.Visible := false
                if success {
                    progressBar.Value := 100
                    sb.Text := " Render Complete!"
                    if MsgBox("Interpolation Complete!`nOpen file?", "Success", "YesNo") == "Yes"
                        Run("explorer.exe /select,`"" result "`"")
                } else {
                    sb.Text := " Failed."
                    if !InStr(result, "Cancelled")
                        ShowErrorLog(result)
                }
            }

            FFWrapper.Run(cmdArgs, outPath, OnProgress, OnFinish)

        } catch as e {
            customDialog({message: e.Message}, errorPreset)
        }
    }

    CancelRender(*) {
        FFWrapper.Stop()
        sb.Text := " Cancelling..."
    }

    ; ==============================================================================
    ; PRESETS
    ; ==============================================================================
    SavePreset(*) {
        path := FileSelect("S", "Motion.ini", "Save Preset", "Settings (*.ini)")
        if !path 
            return
        saved := myGui.Submit(0)
        for k, v in saved.OwnProps()
            IniWrite(v, path, "Settings", k)
        
        ; Manually save dropdown text where value might be ambiguous
        IniWrite(ddlFPS.Text, path, "Settings", "TargetFPS")
        IniWrite(ddlSpeed.Text, path, "Settings", "PlaySpeed")
        IniWrite(ddlMode.Text, path, "Settings", "MiMode")
        IniWrite(ddlEst.Text, path, "Settings", "MeMode")
        IniWrite(ddlComp.Text, path, "Settings", "McMode")
        IniWrite(ddlCodec.Text, path, "Settings", "OutCodec")
        IniWrite(ddlQual.Text, path, "Settings", "OutQuality")
        
        sb.Text := " Preset Saved."
    }

    LoadPreset(*) {
        path := FileSelect(1, , "Load Preset", "Settings (*.ini)")
        if !path 
            return
        saved := myGui.Submit(0)
        for k, v in saved.OwnProps() {
            try {
                val := IniRead(path, "Settings", k)
                if (myGui[k].Type == "Slider")
                    myGui[k].Value := Integer(val)
            }
        }
        
        try ddlFPS.Text := IniRead(path, "Settings", "TargetFPS")
        try ddlSpeed.Text := IniRead(path, "Settings", "PlaySpeed")
        try ddlMode.Text := IniRead(path, "Settings", "MiMode")
        try ddlEst.Text := IniRead(path, "Settings", "MeMode")
        try ddlComp.Text := IniRead(path, "Settings", "McMode")
        try ddlCodec.Text := IniRead(path, "Settings", "OutCodec")
        try ddlQual.Text := IniRead(path, "Settings", "OutQuality")
        
        sb.Text := " Preset Loaded."
    }

    ShowErrorLog(logContent) {
        customDialog({title:"FFmpeg Error Log",message:"Process Failed! Log:",detail: logContent}, criticalErrorDetailPreset)
    }
}
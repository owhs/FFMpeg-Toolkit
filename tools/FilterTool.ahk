
/*
    FFmpeg Basic Filter Tool (AHK v2)
    ---------------------------------
    Apply common video restoration and enhancement filters.
    Features: Deinterlace, Denoise, Sharpen, Color, Interlace Detection.
*/
#Requires AutoHotkey v2.0


#Include ..\lib\utils.ahk
FilterTool(){
    global AppName := "FFMpeg: Filter Tool"

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
    GuiWidth := 600
    RowH     := 32
    CtrlH    := 24
    BtnH     := 24
    xLabel   := 20
    xInput   := 100
    wInput   := 460

    ; ==============================================================================
    ; HEADER: INPUT
    ; ==============================================================================
    myGui.Add("Text", Format("x0 y0 w{} h90	 Background{}", GuiWidth, Theme.DarkPanel), "")

    yStart := 15
    currY  := yStart

    myGui.SetFont("w600")
    myGui.Add("Text", Format("x{} y{} w80 h{} Background{}", xLabel, currY+3, CtrlH, Theme.DarkPanel), "Input Video:")
    myGui.SetFont("w400")

    edtInput := AddFlatEdit(myGui, Format("x{} y{} w{} h{} ReadOnly vInputFile", xInput, currY, wInput-100, CtrlH), "")
    btnBrowse := SexyButton(myGui, xInput+wInput-95, currY-1, 95, BtnH+2, "Browse...", SelectInput)

    ; Analysis Button
    btnAnalyze := SexyButton(myGui, xInput, currY+RowH, 140, BtnH, "Detect Interlacing", RunAnalysis)
    txtAnalyze := myGui.Add("Text", Format("x{} y{} w300 h{} c888888 Background{}", xInput+150, currY+RowH+3, CtrlH, Theme.DarkPanel), "(Scans 5s to check for comb artifacts)")


    ; ==============================================================================
    ; TABS
    ; ==============================================================================
    yTabs := 80
    myGui.Add("Text", Format("x0 y{} w{} h40 Background{}", yTabs, GuiWidth, Theme.DarkPanel), "")
    Tabs := TabManager(myGui, Theme, OnTabChanged)

    tW := GuiWidth / 2
    Tabs.Add("1. Restoration", 0, yTabs, tW, 40, "Restore")
    Tabs.Add("2. Enhancement", tW, yTabs, tW, 40, "Enhance")

    ; ==============================================================================
    ; TAB 1: RESTORATION (Deinterlace, Denoise, etc.)
    ; ==============================================================================
    yContent := yTabs + 55
    currY := yContent

    ; --- DEINTERLACING ---
    AddTabControl("Restore", "Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "Deinterlace:")
    ddlDeint := DarkDropdown(myGui, xInput + 35, currY, 200, ["None", "YADIF (Standard)", "BWDIF (Best Quality)"], "FiltDeint")
    ddlDeint.RegisterToTab(Tabs, "Restore")

    currY += RowH
    ; Increased height for description to prevent overlap
    tDeintDesc := AddTabControl("Restore", "Text", Format("x{} y{} w{} h{} c888888", xInput + 35, currY+3, wInput, 40), "Removes horizontal comb lines from TV recordings. `n'BWDIF' is newer and generally sharper than 'YADIF'.")

    ; --- DETELECINE ---
    currY += 45 ; Manual gap for multi-line text
    chkTelecine := myGui.Add("Checkbox", Format("x{} y{} w110 h{} vFiltTelecine c{} Background{}", xLabel, currY, CtrlH, Theme.Text, Theme.Bg), "Inverse Telecine")
    SetDarkControl(chkTelecine)
    Tabs.Register("Restore", chkTelecine)

    tTeleDesc := AddTabControl("Restore", "Text", Format("x{} y{} w{} h{} c888888", xInput + 35, currY+4, wInput, 30), "Reverses 3:2 pulldown (Telecine). Useful for movies broadcast on TV.`nDo not use with Deinterlace.")

    ; --- DEBLOCK ---
    currY += 60 ; Manual gap
    chkDeblock := myGui.Add("Checkbox", Format("x{} y{} w110 h{} vFiltDeblock c{} Background{}", xLabel, currY, CtrlH, Theme.Text, Theme.Bg), "Deblock")
    SetDarkControl(chkDeblock)
    Tabs.Register("Restore", chkDeblock)

    tDeblockDesc := AddTabControl("Restore", "Text", Format("x{} y{} w{} h{} c888888", xInput + 35, currY+4, wInput, 30), "Smooths out blocky artifacts found in low-bitrate compressed videos.")

    ; --- DENOISE ---
    currY += 50
    AddTabControl("Restore", "Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "Denoise:")
    ddlDenoise := DarkDropdown(myGui, xInput + 35, currY, 200, ["None", "HQDN3D (Fast)", "NLMeans (High Quality - Slow)"], "FiltDenoise")
    ddlDenoise.RegisterToTab(Tabs, "Restore")

    currY += RowH
    tDenoiseDesc := AddTabControl("Restore", "Text", Format("x{} y{} w{} h{} c888888", xInput + 35, currY+3, wInput, 45), "HQDN3D: Spatial/Temporal smoother. Good for general noise.`nNLMeans: Non-Local Means. Excellent quality but very processing intensive.")


    ; ==============================================================================
    ; TAB 2: ENHANCEMENT (Sharpen, Color)
    ; ==============================================================================
    currY := yContent

    ; --- SHARPEN ---
    AddTabControl("Enhance", "Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "Sharpen:")
    ddlSharpen := DarkDropdown(myGui, xInput, currY, 200, ["None", "Unsharp Mask (Standard)", "CAS (Smart Sharpen)", "Laplacian (Edge Detect)"], "FiltSharpen")
    ddlSharpen.RegisterToTab(Tabs, "Enhance")

    ; Content Tuning (New Feature)
    AddTabControl("Enhance", "Text", Format("x320 y{} w60 h{}", currY+3, CtrlH), "Tuning:")
    ddlTuning := DarkDropdown(myGui, 380, currY, 150, ["General", "Film / Live Action", "Animation / Anime"], "FiltTuning")
    ddlTuning.RegisterToTab(Tabs, "Enhance")

    currY += RowH + 8
    
    ; Strength Slider (New)
    AddTabControl("Enhance", "Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "Strength:")
    sldSharpStr := AddTabControl("Enhance", "Slider", Format("x{} y{} w350 h{} vFiltSharpStr Range0-20 ToolTip", xInput, currY, CtrlH), 10) ; 0 to 2.0 (div by 10)
    txtSharpStr := AddTabControl("Enhance", "Text", Format("x{} y{} w50 h{} +0x200 c888888", xInput+360, currY, CtrlH), "1.0")
    
    sldSharpStr.OnEvent("Change", (*) => (txtSharpStr.Text := Format("{:.1f}", sldSharpStr.Value / 10)))

    currY += RowH
    tSharpDesc := AddTabControl("Enhance", "Text", Format("x{} y{} w{} h{} c888888", xInput, currY-5, wInput, 45), "Unsharp: Classic edge enhancement. CAS: Contrast Adaptive Sharpening.`nUse 'Strength' to control intensity (Default 1.0).")

    ; --- COLOR SPACE / EQ ---
    currY += 55
    AddTabControl("Enhance", "Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "Color EQ:")

    ; Contrast
    AddTabControl("Enhance", "Text", Format("x{} y{} w60 h{}", xInput, currY+3, CtrlH), "Contrast:")
    edtCont := AddTabControl("Enhance", "Edit", Format("x{} y{} w50 h{} vValContrast", xInput+60, currY, CtrlH), "1.0")

    ; Brightness
    AddTabControl("Enhance", "Text", Format("x{} y{} w60 h{}", xInput+120, currY+3, CtrlH), "Bright:")
    edtBright := AddTabControl("Enhance", "Edit", Format("x{} y{} w50 h{} vValBright", xInput+180, currY, CtrlH), "0.0")

    ; Saturation
    AddTabControl("Enhance", "Text", Format("x{} y{} w60 h{}", xInput+240, currY+3, CtrlH), "Sat:")
    edtSat := AddTabControl("Enhance", "Edit", Format("x{} y{} w50 h{} vValSat", xInput+300, currY, CtrlH), "1.0")

    currY += RowH
    tColorDesc := AddTabControl("Enhance", "Text", Format("x{} y{} w{} h{} c888888", xInput, currY-5, wInput, RowH), "Values: 1.0 = Default. >1.0 = Increase. <1.0 = Decrease.")

    ; --- EXTRAS ---
    currY += 45
    chkGray := myGui.Add("Checkbox", Format("x{} y{} w150 h{} vFiltGray c{} Background{}", xLabel, currY, CtrlH, Theme.Text, Theme.Bg), "Grayscale")
    SetDarkControl(chkGray)
    Tabs.Register("Enhance", chkGray)

    chkFlip := myGui.Add("Checkbox", Format("x{} y{} w150 h{} vFiltHFlip c{} Background{}", xLabel+120, currY, CtrlH, Theme.Text, Theme.Bg), "Mirror (H-Flip)")
    SetDarkControl(chkFlip)
    Tabs.Register("Enhance", chkFlip)


    ; ==============================================================================
    ; FOOTER
    ; ==============================================================================
    yFooter := 405
    myGui.Add("Text", Format("x0 y{} w{} h65 Background{}", yFooter-3, GuiWidth, Theme.DarkPanel), "")

    ; Preview
    btnPreview := SexyButton(myGui, 20, yFooter+10, 120, 35, "Preview (5s)", GeneratePreview)

    ; Export
    btnExport := SexyButton(myGui, 450, yFooter+10, 120, 35, "Export Video", StartExport)
    btnExport.Beautify()

    btnCancel := SexyButton(myGui, 450, yFooter+10, 120, 35, "Cancel", CancelProcess)
    btnCancel.Visible := false
    btnCancel.setBorders([Theme.AltAccent,Theme.AltAccent,Theme.AltAccent,Theme.AltAccent])
    btnCancel.SetTextColour(Theme.AltAccent)

    ; Status Bar
    yStatus := yFooter + 45
    progressBar := myGui.Add("Progress", Format("x0 y{} w{} h3 c{} Background{}", yStatus, GuiWidth, Theme.Accent, Theme.DarkPanel, "Range0-100 vMyProgress"), 0)

    myGui.SetFont("s8 c" Theme.Text, "Fixedsys")
    sb := myGui.Add("Text", Format("x0 y{} w{} h20 c{} Background{} +0x200 Center vStatusText", yStatus+3, GuiWidth, Theme.Accent, Theme.StatusBg), "Idle")

    ; Init
    Tabs.Switch("Restore")
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
        ; No special logic needed for now
    }

    SelectInput(*) {
        path := FileSelect(1, , "Select Input Video", "Video (*.mp4; *.mkv; *.avi; *.mov; *.webm)")
        if path
            edtInput.Value := path
    }

    HandleDropFiles(guiObj, ctrlObj, fileArray, x, y) {
        if (fileArray.Length > 0)
            edtInput.Value := fileArray[1]
    }

    RunAnalysis(*) {
        path := edtInput.Value
        if (path == "")
            return customDialog({message: "Please select an input file first."}, darkPreset)
            
        sb.Text := " Analyzing..."
        
        ; Run 'idet' filter on a small chunk from the middle (skip first 30s)
        ; idet requires processing frames. We'll verify 10 seconds.
        startPos := "30"
        
        logFile := A_Temp "\idet_log.txt"
        try FileDelete(logFile)
        
        ff := FFWrapper.ffmpegPath
        ; -f null - outputs nowhere, we just want the log
        cmd := Format('"{1}" -hide_banner -ss {2} -i "{3}" -t 5 -vf idet -f null - 2> "{4}"', ff, startPos, path, logFile)
        
        RunWait(A_ComSpec ' /c "' cmd '"', , "Hide")
        
        if !FileExist(logFile) {
            sb.Text := " Analysis Failed."
            return
        }
        
        logContent := FileRead(logFile)
        FileDelete(logFile)
        sb.Text := " Analysis Complete."
        
        ; Parse Output
        ; Expected: Multi frame detection: TFF: 50 BFF: 0 Progressive: 0 Undetermined: 0
        if RegExMatch(logContent, "Multi frame detection:.*TFF:\s*(\d+)\s*BFF:\s*(\d+)\s*Progressive:\s*(\d+)", &m) {
            tff := Integer(m[1])
            bff := Integer(m[2])
            prog := Integer(m[3])
            total := tff + bff + prog
            
            interlacedScore := (tff + bff)
            
            resultMsg := "Analysis Results (5 second scan):`n`n"
            resultMsg .= "Interlaced Frames: " interlacedScore "`n"
            resultMsg .= "Progressive Frames: " prog "`n`n"
            
            if (interlacedScore > prog)
                resultMsg .= "VERDICT: Likely Interlaced.`nRecommended: Enable 'Deinterlace' filter."
            else
                resultMsg .= "VERDICT: Likely Progressive.`nNo deinterlacing needed."
                
            customDialog({title:"Analysis Result", message:resultMsg}, darkPreset)
        } else {
            customDialog({message:"Could not determine video type from log."}, errorPreset)
        }
    }

    BuildFilterChain(saved) {
        filters := []
        
        ; 1. Restore
        if (saved.FiltTelecine)
            filters.Push("pullup")
            
        if (saved.FiltDeint != "None") {
            if InStr(saved.FiltDeint, "BWDIF")
                filters.Push("bwdif")
            else
                filters.Push("yadif")
        }
        
        if (saved.FiltDeblock)
            filters.Push("deblock=filter=hb:block=4")
            
        if (saved.FiltDenoise != "None") {
            if InStr(saved.FiltDenoise, "HQDN3D")
                filters.Push("hqdn3d=4.0:3.0:6.0:4.5") ; Standard light denoise
            else
                filters.Push("nlmeans=s=1.5") ; NLMeans (Slow but good)
        }
        
        ; 2. Enhance
        if (saved.FiltSharpen != "None") {
            
            ; Tuning Logic
            tuning := saved.FiltTuning
            strength := saved.FiltSharpStr / 10.0 ; 0.0 to 2.0
            
            if InStr(saved.FiltSharpen, "Unsharp") {
                ; Unsharp Mask Parameters: luma_msize_x:luma_msize_y:luma_amount:chroma_msize_x:chroma_msize_y:chroma_amount
                lumaAmt := strength
                if (tuning == "Animation / Anime")
                    filters.Push(Format("unsharp=3:3:{1}:3:3:0.0", lumaAmt * 1.5)) ; Tight, Stronger for lines
                else if (tuning == "Film / Live Action")
                    filters.Push(Format("unsharp=7:7:{1}:5:5:0.0", lumaAmt * 0.8)) ; Wider, Subtler for grain
                else
                    filters.Push(Format("unsharp=5:5:{1}:5:5:0.0", lumaAmt)) ; General
                    
            } else if InStr(saved.FiltSharpen, "CAS") {
                ; CAS Parameters: strength (0.0 - 1.0)
                casStr := Min(1.0, strength * 0.5) ; Scale approx.
                
                if (tuning == "Animation / Anime")
                    casStr := Min(1.0, casStr * 1.6)
                else if (tuning == "Film / Live Action")
                    casStr := Min(1.0, casStr * 0.6)
                
                filters.Push(Format("cas={1:.2f}", casStr))
                    
            } else if InStr(saved.FiltSharpen, "Laplacian") {
                filters.Push("smartblur=lr=1.0:ls=0:lt=-5")
            }
        }
        
        ; 3. Color
        eqParts := []
        if (saved.ValContrast != "1.0")
            eqParts.Push("contrast=" saved.ValContrast)
        if (saved.ValBright != "0.0")
            eqParts.Push("brightness=" saved.ValBright)
        if (saved.ValSat != "1.0")
            eqParts.Push("saturation=" saved.ValSat)
            
        if (eqParts.Length > 0) {
            eqStr := "eq="
            for i, p in eqParts
                eqStr .= (i > 1 ? ":" : "") . p
            filters.Push(eqStr)
        }
        
        ; 4. Extras
        if (saved.FiltGray)
            filters.Push("hue=s=0")
        if (saved.FiltHFlip)
            filters.Push("hflip")
            
        ; Build String
        vf := ""
        for i, f in filters
            vf .= (i > 1 ? "," : "") . f
            
        return vf
    }

    GeneratePreview(*) {
        saved := myGui.Submit(0)
        if (saved.InputFile == "")
            return customDialog({message: "Select an input file."}, darkPreset)
            
        vf := BuildFilterChain(saved)
        if (vf == "")
            return customDialog({message: "No filters selected! Nothing to preview."}, darkPreset)
            
        previewFile := A_Temp "\preview_" A_TickCount ".mp4"
        
        cmdArgs := []
        cmdArgs.Push("-y")
        cmdArgs.Push("-ss", "10") ; Skip 10s into video
        cmdArgs.Push("-t", "5")   ; 5 second preview
        cmdArgs.Push("-i", Format('"{1}"', saved.InputFile))
        
        cmdArgs.Push("-vf", Format('"{1}"', vf))
        
        ; Fast encode for preview
        cmdArgs.Push("-c:v", "libx264", "-preset", "ultrafast", "-crf", "23")
        cmdArgs.Push("-an") ; No audio for preview (faster)
        
        sb.Text := " Generating Preview..."
        
        OnPrevFinish(success, result) {
            sb.Text := " Idle"
            if (success)
                Run(previewFile)
            else
                ShowErrorLog(result)
        }
        
        FFWrapper.Run(cmdArgs, previewFile, (p,t) => "", OnPrevFinish)
    }

    StartExport(*) {
        saved := myGui.Submit(0)
        if (saved.InputFile == "")
            return customDialog({message: "Select an input file."}, darkPreset)
            
        vf := BuildFilterChain(saved)
        
        SplitPath(saved.InputFile, , &dir, , &nameNoExt)
        outPath := FileSelect("S", dir "\" nameNoExt "_filtered.mp4", "Save Video", "Video (*.mp4)")
        if !outPath
            return
            
        cmdArgs := []
        cmdArgs.Push("-y")
        cmdArgs.Push("-i", Format('"{1}"', saved.InputFile))
        
        if (vf != "")
            cmdArgs.Push("-vf", Format('"{1}"', vf))
            
        ; Encoding Settings (High Quality)
        cmdArgs.Push("-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p")
        cmdArgs.Push("-c:a", "copy") ; Copy audio
        
        ExecuteJob(cmdArgs, outPath)
    }

    ExecuteJob(cmdArgs, outputFile) {
        btnExport.Visible := false
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
            btnExport.Visible := true
            
            if (success) {
                progressBar.Value := 100
                sb.Text := " Done!"
                if MsgBox("Export Complete!`nOpen output folder?", "Success", "YesNo") == "Yes" {
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

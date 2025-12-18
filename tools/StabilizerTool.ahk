
/*
    FFmpeg Video Stabilizer (AHK v2)
    --------------------------------
    A "Magic Gimbal" for shaky footage.
    Uses libvidstab in a two-pass process:
    1. Detection (generates .trf vector data)
    2. Transform (applies smoothing and zoom)
    
    Features:
    - Real-time "Safe Zone" visualizer for Zoom/Crop.
    - Side-by-Side Preview generation.
    - Tripod vs Smoothing modes.
*/
#Requires AutoHotkey v2.0

#Include ..\lib\utils.ahk
StabilizerTool() {
    global AppName := "FFMpeg: Video Stabilizer"
    
    ; State Variables
    global CurrentTRF := ""        ; Path to the generated vector file
    global IsAnalyzed := false     ; Have we run pass 1?
    global PreviewImgPath := ""    ; Path to the static frame for visualization
    global OriginalDims := {w:0, h:0}
    global DisplayScale := 1.0     ; Ratio between actual video and GUI image
    global OverlayControls := []   ; Array to hold the 4 border controls

    ; ==============================================================================
    ; GUI CREATION
    ; ==============================================================================
    myGui := Gui("-Resize -MaximizeBox", AppName)
    myGui.SetFont("s9 c" Theme.Text, "Segoe UI")
    myGui.BackColor := Theme.Bg

    InitWindowUtils(myGui)
    
    ; Attach FFJob for active job protection
    myGui.FFJob := FFWrapper
    
    ; Attach Custom Cleanup callback
    myGui.OnCloseCheck := CleanupTempFiles
    
    ; Safe Close
    myGui.OnEvent("Close", (*) => TryCloseWindow(myGui))
    myGui.OnEvent("DropFiles", HandleDropFiles)

    ; --- GRID LAYOUT ---
    GuiWidth      := 620
    yContentStart := 44 
    RowH          := 32 
    CtrlH         := 24 
    BtnH          := 24  ; Fixed: Defined Button Height

    xLabel  := 15
    xInput  := 90
    wInput  := 400 
    xBtn    := 500
    wBtn    := 105

    ; ==============================================================================
    ; TAB NAVIGATION
    ; ==============================================================================
    myGui.Add("Text", Format("x0 y0 w{} h40 Background{}", GuiWidth, Theme.DarkPanel), "")
    Tabs := TabManager(myGui, Theme, OnTabChanged)

    tW := GuiWidth / 3
    Tabs.Add("1. Input & Mode", 0,    0, tW, 40, "Input")
    Tabs.Add("2. Visualizer",   tW,   0, tW, 40, "Visual")
    Tabs.Add("3. Output",       tW*2, 0, tW, 40, "Output")

    ; ==============================================================================
    ; TAB 1: INPUT & ANALYSIS
    ; ==============================================================================
    currY := yContentStart + 10
    
    ; Input File
    AddTabControl("Input", "Text", Format("x{} y{} w70 h{}", xLabel, currY+3, CtrlH), "Input Video:")
    edtInput := AddTabControl("Input", "Edit", Format("x{} y{} w{} h{} ReadOnly vInputFile", xInput, currY, wInput, CtrlH))
    btnBrowse := SexyButton(myGui, xBtn, currY-1, wBtn, BtnH+2, "Browse...", SelectInput)
    btnBrowse.RegisterToTab(Tabs, "Input")

    ; Analysis Status
    currY += RowH + 10
    AddTabControl("Input", "Text", Format("x{} y{} w70 h{}", xLabel, currY+3, CtrlH), "Status:")
    txtStatusIcon := AddTabControl("Input", "Text", Format("x{} y{} w20 h{} +0x200 c{}", xInput, currY, CtrlH, Theme.AltAccent), "⚠️")
    txtStatusText := AddTabControl("Input", "Text", Format("x{} y{} w300 h{} +0x200 c888888 vAnalysisStatus", xInput+25, currY, CtrlH), "Not Analyzed (Run Analysis Step first)")

    ; Divider
    currY += RowH + 10
    AddTabControl("Input", "Text", Format("x{} y{} w{} h1 Background{}", xLabel, currY, GuiWidth-(xLabel*2), Theme.Panel), "")
    currY += 15

    ; Stabilization Mode
    AddTabControl("Input", "Text", Format("x{} y{} w70 h{}", xLabel, currY+3, CtrlH), "Mode:")
    ddlMode := DarkDropdown(myGui, xInput, currY, 200, ["Smoothing (Handheld)", "Tripod (Locked)"], "StabMode", UpdateModeUI)
    ddlMode.RegisterToTab(Tabs, "Input")

    ; Advanced Sliders (Shakiness / Accuracy)
    currY += RowH + 15
    AddTabControl("Input", "Text", Format("x{} y{} w300 h{} c{}", xLabel, currY, CtrlH, Theme.Accent), "Detection Settings (How strict is the tracker?)")
    
    currY += RowH
    AddTabControl("Input", "Text", Format("x{} y{} w70 h{}", xLabel, currY, CtrlH), "Shakiness:")
    sldShake := AddTabControl("Input", "Slider", Format("x{} y{} w300 h{} vShakiness Range1-10 ToolTip", xInput, currY, CtrlH), 5)
    AddTabControl("Input", "Text", Format("x400 y{} w200 h{} c888888", currY, CtrlH), "(1=Little Shake, 10=Earthquake)")

    currY += RowH
    AddTabControl("Input", "Text", Format("x{} y{} w70 h{}", xLabel, currY, CtrlH), "Accuracy:")
    sldAcc := AddTabControl("Input", "Slider", Format("x{} y{} w300 h{} vAccuracy Range1-15 ToolTip", xInput, currY, CtrlH), 15)
    AddTabControl("Input", "Text", Format("x400 y{} w200 h{} c888888", currY, CtrlH), "(1=Low, 15=High Precision)")


    ; ==============================================================================
    ; TAB 2: VISUALIZER (The Sexy Part)
    ; ==============================================================================
    ; We need a canvas area. We will use a Picture control.
    ; On top of that, we will place 4 thin "Text" controls to act as the borders of our "Crop Box".

    yVisStart := yContentStart + 10
    
    ; Header / Controls
    AddTabControl("Visual", "Text", Format("x{} y{} w50 h{}", xLabel, yVisStart+3, CtrlH), "Zoom:")
    ; Using a slider that goes -10 to 10? No, standard zoom is usually just "How much to zoom in to hide borders"
    ; VidStab Zoom: 0 = No zoom (borders visible), >0 = Zoom in. Negative is zoom out.
    ; We'll use Percentage: 0% to 50%
    
    sldZoom := AddTabControl("Visual", "Slider", Format("x65 y{} w300 h{} vZoomAmount Range-50-50 ToolTip", yVisStart, CtrlH), 0)
    sldZoom.OnEvent("Change", UpdateVisualizerBox)

    AddTabControl("Visual", "Text", Format("x380 y{} w60 h{}", yVisStart+3, CtrlH), "Smooth:")
    sldSmooth := AddTabControl("Visual", "Slider", Format("x440 y{} w150 h{} vSmoothing Range0-100 ToolTip", yVisStart, CtrlH), 30)

    ; The Image Container
    yImg := yVisStart + 35
    wImg := 500
    hImg := 281 ; 16:9 approx
    xImg := (GuiWidth - wImg) / 2

    ; Placeholder Grey Box
    picPlaceholder := myGui.Add("Text", Format("x{} y{} w{} h{} Background{}", xImg, yImg, wImg, hImg, Theme.DarkPanel), "")
    Tabs.Register("Visual", picPlaceholder)
    
    ; The Actual Picture Control (Hidden initially)
    ; Removed +Scale as it's implied by w/h and causes error
    picFrame := myGui.Add("Picture", Format("x{} y{} w{} h{} -Border Hidden", xImg, yImg, wImg, hImg), "")
    Tabs.Register("Visual", picFrame)

    ; Overlay Borders (Top, Bottom, Left, Right) - Creating the "Red Box"
    ; We use Text controls with a Red background.
    borderCol := "FF0055" ; Nice Hot Pink/Red
    
    ovTop    := myGui.Add("Text", Format("x0 y0 w0 h2 Background{} Hidden", borderCol), "")
    ovBot    := myGui.Add("Text", Format("x0 y0 w0 h2 Background{} Hidden", borderCol), "")
    ovLeft   := myGui.Add("Text", Format("x0 y0 w2 h0 Background{} Hidden", borderCol), "")
    ovRight  := myGui.Add("Text", Format("x0 y0 w2 h0 Background{} Hidden", borderCol), "")
    
    OverlayControls := [ovTop, ovBot, ovLeft, ovRight]
    for c in OverlayControls
        Tabs.Register("Visual", c)

    ; Instructions inside Visualizer
    txtVisHint := AddTabControl("Visual", "Text", Format("x0 y{} w{} h20 Center c888888", yImg + hImg + 5, GuiWidth), "Red Box = Estimated Safe Area after Zooming")


    ; ==============================================================================
    ; TAB 3: OUTPUT
    ; ==============================================================================
    currY := yContentStart + 10

    AddTabControl("Output", "Text", Format("x{} y{} w70 h{}", xLabel, currY+3, CtrlH), "Codec:")
    ddlCodec := DarkDropdown(myGui, xInput, currY, wInput, ["H.264 (MP4) - Standard", "H.265 (MP4) - Efficient", "DNxHD (MOV) - Editing", "ProRes (MOV) - High Quality"], "OutCodec")
    ddlCodec.RegisterToTab(Tabs, "Output")

    currY += RowH + 10
    AddTabControl("Output", "Text", Format("x{} y{} w70 h{}", xLabel, currY+3, CtrlH), "Quality:")
    ddlQuality := DarkDropdown(myGui, xInput, currY, wInput, ["High (CRF 18)", "Medium (CRF 23)", "Low (CRF 28)"], "OutQuality", , 2)
    ddlQuality.RegisterToTab(Tabs, "Output")


    ; ==============================================================================
    ; FOOTER
    ; ==============================================================================
    yFooter := 400

    myGui.Add("Text", Format("x0 y{} w{} h65 Background{}", yFooter-3, GuiWidth, Theme.DarkPanel), "")

    ; Analysis Button (Left)
    btnAnalyze := SexyButton(myGui, 10, yFooter+5, 140, 30, "1. Run Analysis", RunAnalysis)
    
    ; Preview Buttons (Middle)
    SexyButton(myGui, 210, yFooter+5, 130, 30, "Compare (Split)", GenerateComparison)

    ; Render Button (Right)
    btnRender := SexyButton(myGui, GuiWidth-130, yFooter+5, 120, 30, "2. Stabilize", StartStabilization)
    btnRender.Beautify()
    btnRender.Enabled := false ; Disabled until analysis

    ; Status Bar
    yStatus := yFooter + 38
    progressBar := myGui.Add("Progress", Format("x0 y{} w{} h3 c{} Background{}", yStatus, GuiWidth, Theme.Accent, Theme.DarkPanel, "Range0-100 vMyProgress"), 0)

    myGui.SetFont("s8 c" Theme.Text, "Fixedsys")
    sb := myGui.Add("Text", Format("x0 y{} w{} h20 c{} Background{} +0x200 Center vStatusText", yStatus+3, GuiWidth, Theme.Accent, Theme.StatusBg), "Waiting for Input...")

    Tabs.Switch("Input")
    myGui.Show(Format("w{} h{}", GuiWidth, yStatus + 23))


    ; ==============================================================================
    ; LOGIC & FUNCTIONS
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
        ; Fixed: Added callback to ensure visualizer updates on tab switch
        if (newTab == "Visual") {
            UpdateVisualTabState() ; Fix visibility of placeholder vs frame
            UpdateVisualizerBox()
        }
    }
    
    UpdateVisualTabState() {
        ; Enforce mutual exclusion between placeholder and real frame
        ; because TabManager shows BOTH when switching tabs.
        hasImage := (PreviewImgPath != "" && FileExist(PreviewImgPath))
        
        try picPlaceholder.Visible := !hasImage
        try picFrame.Visible := hasImage
        
        ; Hide overlay boxes if no image
        if (!hasImage) {
            for c in OverlayControls
                try c.Visible := false
        }
    }

    SelectInput(*) {
        path := FileSelect(1, , "Select Video to Stabilize", "Video (*.mp4; *.mov; *.mkv; *.avi; *.webm)")
        if path {
            edtInput.Value := path
            ResetAnalysis()
            ; Auto-grab frame for visualizer
            ExtractVisualizerFrame(path)
        }
    }
    
    HandleDropFiles(guiObj, ctrlObj, fileArray, x, y) {
        if fileArray.Length > 0 {
            edtInput.Value := fileArray[1]
            ResetAnalysis()
            ExtractVisualizerFrame(fileArray[1])
        }
    }

    UpdateModeUI(*) {
        ; If Tripod mode is selected, smoothing slider usually effectively becomes "infinity" 
        ; but we'll leave controls enabled for user tweakability.
        if (ddlMode.Text == "Tripod (Locked)") {
            sldSmooth.Value := 100
            sldSmooth.Enabled := false
        } else {
            sldSmooth.Value := 30
            sldSmooth.Enabled := true
        }
    }

    ResetAnalysis() {
        global IsAnalyzed, CurrentTRF
        IsAnalyzed := false
        CurrentTRF := ""
        txtStatusIcon.Text := "⚠️"
        txtStatusIcon.Opt("c" Theme.AltAccent)
        txtStatusText.Text := "Not Analyzed (Run Analysis Step first)"
        btnRender.Enabled := false
        sb.Text := " Input Changed. Analysis Required."
    }

    ExtractVisualizerFrame(videoPath) {
        global PreviewImgPath, OriginalDims
        
        sb.Text := " Extracting Reference Frame..."
        
        ; 1. Get Dimensions
        OriginalDims := GetVideoDimensions(videoPath)
        
        ; 2. Extract Frame
        PreviewImgPath := A_Temp "\stab_ref_" A_TickCount ".jpg"
        
        ; Use FFmpeg to grab frame at 5 seconds or 10%
        cmd := ["-ss", "5", "-i", Format('"{1}"', videoPath), "-frames:v", "1", "-q:v", "2"]
        
        try {
            FFWrapper.GeneratePreview(cmd, PreviewImgPath)
            
            ; Load into Picture Control
            if FileExist(PreviewImgPath) {
                picFrame.Value := PreviewImgPath
                
                ; Calculate Scale for the Overlay Box
                ; The picture control is fixed size (wImg x hImg)
                ; It keeps aspect ratio. We need to know the *rendered* width/height inside the control.
                
                ; Simple approach: Fit OriginalDims into wImg/hImg box
                ratioW := 500 / OriginalDims.w
                ratioH := 281 / OriginalDims.h
                scale  := Min(ratioW, ratioH)
                
                finalW := OriginalDims.w * scale
                finalH := OriginalDims.h * scale
                
                ; Center offsets
                offX := (500 - finalW) / 2
                offY := (281 - finalH) / 2
                
                ; Store metrics for the slider update function
                ; Recalculate based on actual control centering
                picFrame.GetPos(&px, &py, &pw, &ph)
                picFrame.GuiProps := {x: px + offX, y: py + offY, w: finalW, h: finalH}
                
                ; Fix: Only show immediately if we are ALREADY on the visual tab
                if (Tabs.Current == "Visual") {
                    UpdateVisualTabState()
                    UpdateVisualizerBox()
                }
                
                sb.Text := " Reference Frame Loaded."
            }
        } catch {
            sb.Text := " Could not load frame."
        }
    }

    GetVideoDimensions(path) {
        ; Fixed: Use RunWait with Hide and Temp file to prevent CMD flashing
        tempFile := A_Temp "\vid_dims_" A_TickCount ".txt"
        cmd := Format('"{1}" /c ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "{2}" > "{3}"', A_ComSpec, path, tempFile)
        
        try RunWait(cmd, , "Hide")
        
        if FileExist(tempFile) {
            output := FileRead(tempFile)
            try FileDelete(tempFile)
            if RegExMatch(output, "(\d+)x(\d+)", &m)
                return {w: Integer(m[1]), h: Integer(m[2])}
        }
        return {w: 1920, h: 1080} ; Fallback
    }

    UpdateVisualizerBox(*) {
        if (!HasProp(picFrame, "GuiProps") || Tabs.Current != "Visual")
            return
            
        saved := myGui.Submit(0)
        zoomVal := saved.ZoomAmount ; Range -50 to 50
        
        ; In vidstabtransform, Zoom 0 means standard. 
        ; Positive zoom means zooming IN (cropping). 
        ; Negative zoom means zooming OUT (black borders).
        ; We want to visualize the "Safe Area" that remains visible.
        
        ; Logic: 
        ; If Zoom = 10 (percent), we lose 10% of the image.
        ; The "Red Box" should outline the INNER area that is KEPT.
        
        ; If Zoom is negative, we are effectively keeping MORE than the frame (adding borders), 
        ; so the box should be the full frame size (or even outside, but we clip to image).
        
        factor := 0
        if (zoomVal > 0)
            factor := zoomVal / 100
            
        ; Calculate margins to remove
        props := picFrame.GuiProps
        
        marginW := (props.w * factor) / 2
        marginH := (props.h * factor) / 2
        
        bx := props.x + marginW
        by := props.y + marginH
        bw := props.w - (marginW * 2)
        bh := props.h - (marginH * 2)
        
        ; Update Overlay Controls positions
        thick := 2
        
        ; Ensure visibility
        for c in OverlayControls
            c.Visible := true
            
        ; Top
        OverlayControls[1].Move(bx, by, bw, thick)
        ; Bottom
        OverlayControls[2].Move(bx, by + bh - thick, bw, thick)
        ; Left
        OverlayControls[3].Move(bx, by, thick, bh)
        ; Right
        OverlayControls[4].Move(bx + bw - thick, by, thick, bh)
    }
    
    ; ==============================================================================
    ; PROCESSING: PASS 1 (ANALYSIS)
    ; ==============================================================================
    RunAnalysis(*) {
        saved := myGui.Submit(0)
        if (saved.InputFile == "") 
            return customDialog({message: "Select an input video first."}, darkPreset)
            
        ; Setup Path for TRF
        CurrentTRF := A_Temp "\transform_" A_TickCount ".trf"
        
        ; Build Command
        ; vidstabdetect=stepsize=32:shakiness=5:accuracy=15:result="path.trf"
        ; Note: Windows path escaping in FFmpeg filters can be tricky. Forward slashes are safer.
        safeTRF := StrReplace(CurrentTRF, "\", "/")
        safeTRF := StrReplace(safeTRF, ":", "\:")
        
        filter := Format("vidstabdetect=stepsize=32:shakiness={1}:accuracy={2}:result='{3}'", saved.Shakiness, saved.Accuracy, safeTRF)
        
        if (saved.StabMode == "Tripod (Locked)")
            filter .= ":tripod=1"
        
        ; We remove the "-" output here because FFWrapper appends the output file argument.
        ; We use "NUL" as the dummy output because the null muxer doesn't create a physical file,
        ; causing FFWrapper's file detection to fail if we use a temp path.
        ; "NUL" exists virtually on Windows, ensuring FFWrapper reports success.
        cmdArgs := ["-y", "-i", Format('"{1}"', saved.InputFile), "-vf", filter, "-f", "null"]
        
        ; Run
        btnAnalyze.Enabled := false
        sb.Text := " Analyzing Motion Vectors..."
        progressBar.Value := 0
        
        OnAnalyzeProgress(pct, text) {
            progressBar.Value := pct
            sb.Text := " Analyzing: " Round(pct) "%"
        }
        
        OnAnalyzeFinish(success, result) {
            btnAnalyze.Enabled := true
            
            ; Explicitly check for TRF file existence because FFWrapper might return true 
            ; just because "NUL" exists, even if the filter failed.
            if (success && FileExist(CurrentTRF)) {
                IsAnalyzed := true
                btnRender.Enabled := true
                
                txtStatusIcon.Text := "✅"
                txtStatusIcon.Opt("c" Theme.Accent)
                txtStatusText.Text := "Analysis Complete. Ready to Stabilize."
                sb.Text := " Analysis Done."
                
                customDialog({title:"Analysis Complete", message:"Motion data collected.`nYou can now Preview or Stabilize."}, darkPreset)
            } else {
                sb.Text := " Analysis Failed."
                
                ; If the TRF is missing but FFmpeg reported success, it means the filter didn't run.
                if (success && !FileExist(CurrentTRF)) {
                    ShowErrorLog("FFmpeg exited successfully, but the .trf file was not created.`nThis usually indicates a path issue or filter syntax error.`nTRF Path attempted: " CurrentTRF)
                } else {
                    ShowErrorLog(result)
                }
            }
        }
        
        FFWrapper.Run(cmdArgs, "NUL", OnAnalyzeProgress, OnAnalyzeFinish)
    }

    ; ==============================================================================
    ; PROCESSING: PASS 2 (RENDER)
    ; ==============================================================================
    StartStabilization(*) {
        if (!IsAnalyzed || !FileExist(CurrentTRF))
            return customDialog({message: "Please run Analysis (Step 1) first."}, errorPreset)
            
        saved := myGui.Submit(0)
        
        ; Determine Output
        SplitPath(saved.InputFile, , &dir, , &nameNoExt)
        ext := InStr(saved.OutCodec, "MOV") ? "mov" : "mp4"
        outputFile := FileSelect("S", dir "\" nameNoExt "_stabilized." ext, "Save Video", "Video (*." ext ")")
        if !outputFile
            return
            
        ; FIX: Ensure extension is present if user typed filename manually
        if !RegExMatch(outputFile, "i)\." ext "$")
            outputFile .= "." ext
            
        ; Build Filter
        safeTRF := StrReplace(CurrentTRF, "\", "/")
        safeTRF := StrReplace(safeTRF, ":", "\:")
        
        ; Smoothing logic
        smooth := saved.Smoothing
        
        ; Zoom logic: vidstab uses different zoom definition than our visualizer?
        ; actually, vidstabtransform: zoom=0 is default (keep borders). zoom=5 is zoom in 5%.
        ; Our slider is -50 to 50.
        zoomArg := saved.ZoomAmount
        
        filter := Format("vidstabtransform=input='{1}':zoom={2}:smoothing={3}", safeTRF, zoomArg, smooth)
        
        if (saved.StabMode == "Tripod (Locked)")
            filter .= ":tripod=1"
            
        ; Codec Args
        cArgs := []
        if InStr(saved.OutCodec, "H.264")
            cArgs := ["-c:v", "libx264", "-pix_fmt", "yuv420p"]
        else if InStr(saved.OutCodec, "H.265")
            cArgs := ["-c:v", "libx265", "-pix_fmt", "yuv420p"]
        else if InStr(saved.OutCodec, "DNxHD")
            cArgs := ["-c:v", "dnxhd", "-profile:v", "dnxhd_hq", "-pix_fmt", "yuv422p"]
        else if InStr(saved.OutCodec, "ProRes")
            cArgs := ["-c:v", "prores_ks", "-profile:v", "3"]
            
        ; Quality (CRF) for x264/x265
        if (InStr(saved.OutCodec, "H.26")) {
            crf := InStr(saved.OutQuality, "High") ? 18 : InStr(saved.OutQuality, "Medium") ? 23 : 28
            cArgs.Push("-crf", crf)
        }
        
        ; Full Command
        cmdArgs := ["-y", "-i", Format('"{1}"', saved.InputFile), "-vf", filter]
        for a in cArgs 
            cmdArgs.Push(a)
        
        ; Audio Copy
        cmdArgs.Push("-c:a", "copy")
        
        ; RUN
        btnRender.Visible := false
        sb.Text := " Stabilizing..."
        progressBar.Value := 0
        
        OnStabProgress(pct, text) {
            progressBar.Value := pct
            sb.Text := text
        }
        
        OnStabFinish(success, result) {
            btnRender.Visible := true
            if success {
                progressBar.Value := 100
                sb.Text := " Done!"
                if MsgBox("Stabilization Complete!`nOpen file?", "Success", "YesNo") == "Yes"
                    Run("explorer.exe /select,`"" result "`"")
            } else {
                sb.Text := " Failed."
                if !InStr(result, "Cancelled")
                    ShowErrorLog(result)
            }
        }
        
        FFWrapper.Run(cmdArgs, outputFile, OnStabProgress, OnStabFinish)
    }

    ; ==============================================================================
    ; PREVIEW: SIDE BY SIDE
    ; ==============================================================================
    GenerateComparison(*) {
        if (!IsAnalyzed || !FileExist(CurrentTRF))
            return customDialog({message: "Please run Analysis (Step 1) first."}, errorPreset)
            
        saved := myGui.Submit(0)
        
        sb.Text := " Generating Comparison Preview..."
        progressBar.Value := 0 ; Reset
        previewFile := A_Temp "\stab_compare_" A_TickCount ".mp4"
        
        safeTRF := StrReplace(CurrentTRF, "\", "/")
        safeTRF := StrReplace(safeTRF, ":", "\:")
        
        ; Build Complex Filter
        ; [0:v]vidstabtransform=...[stab];[0:v][stab]hstack[outv]
        
        stabFilter := Format("vidstabtransform=input='{1}':zoom={2}:smoothing={3}", safeTRF, saved.ZoomAmount, saved.Smoothing)
        if (saved.StabMode == "Tripod (Locked)")
            stabFilter .= ":tripod=1"
            
        complex := Format("[0:v]split=2[orig][proc];[proc]{1}[stab];[orig][stab]hstack", stabFilter)
        
        ; Generate 5 second preview
        ; Changed preset from ultrafast to faster for better preview quality
        cmdArgs := ["-y", "-ss", "00:00:05", "-t", "5", "-i", Format('"{1}"', saved.InputFile), "-filter_complex", Format('"{1}"', complex), "-c:v", "libx264", "-crf", "23", "-preset", "faster"]
        
        OnCompProgress(pct, text) {
            progressBar.Value := pct
            sb.Text := " Compiling Preview: " Round(pct) "%"
        }
        
        OnCompFinish(success, result) {
            if success {
                sb.Text := " Preview Ready."
                progressBar.Value := 100
                Run(previewFile)
            } else {
                sb.Text := " Preview Failed."
                ShowErrorLog(result)
            }
        }

        try {
            FFWrapper.Run(cmdArgs, previewFile, OnCompProgress, OnCompFinish)
        } catch as e {
            customDialog({title:"Error", message:e.Message}, errorPreset)
        }
    }
    
    ; Called by OnCloseCheck in TryCloseWindow
    CleanupTempFiles() {
        
        if (CurrentTRF && FileExist(CurrentTRF))
            FileDelete(CurrentTRF)
        if (PreviewImgPath && FileExist(PreviewImgPath))
            FileDelete(PreviewImgPath)
            
        return true ; Allow close
    }
    
    ShowErrorLog(logContent) {
        customDialog({title:"FFmpeg Error Log",message:"Process Failed! Log:",detail: logContent}, criticalErrorDetailPreset)
    }
}

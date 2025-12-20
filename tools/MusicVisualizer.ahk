
/*
    FFmpeg Music Visualizer (AHK v2)
    --------------------------------
    Generates video visualizations from audio inputs using advanced FFmpeg filters.
    
    Features:
    - Multiple Visualizers: CQT, Spectrum, Waveform, Vectorscope.
    - Backgrounds: Solid Color (Image support removed for performance).
    - Compositing: Layout controls (opacity, positioning).
    - Advanced Audio Settings: Gain, Smoothing.
    - Post FX: Configurable chain of effects (Hue, Glitch, Mirror, Glow, Trails, Neon, etc).
*/

MusicVisualizer(){
    global AppName := "FFMpeg: Music Visualizer"

    ; ==============================================================================
    ; GUI CREATION & GRID SYSTEM
    ; ==============================================================================
    myGui := Gui("-Resize -MaximizeBox", AppName)
    myGui.SetFont("s9 c" Theme.Text, "Segoe UI")
    myGui.BackColor := Theme.Bg

    ; Init Utils
    InitWindowUtils(myGui)

    myGui.OnEvent("Close", (*) => myGui.Destroy())
    myGui.OnEvent("DropFiles", HandleDropFiles)

    ; --- LAYOUT CONSTANTS ---
    GuiWidth      := 620
    yContentStart := 44   
    RowH          := 32   
    CtrlH         := 24   
    BtnH          := 24

    ; Columns
    xLabel  := 15
    xInput  := 100
    wInput  := 390 
    xBtn    := 500
    wBtn    := 105

    ; ==============================================================================
    ; TAB NAVIGATION
    ; ==============================================================================
    myGui.Add("Text", Format("x0 y0 w{} h40 Background{}", GuiWidth, Theme.DarkPanel), "")
    Tabs := TabManager(myGui, Theme, OnTabChanged)

    tW := GuiWidth / 4
    Tabs.Add("1. Source", 0,    0, tW, 40, "Source")
    Tabs.Add("2. Visual", tW,   0, tW, 40, "Visual")
    Tabs.Add("3. Effects",tW*2, 0, tW, 40, "Effects")
    Tabs.Add("4. Output", tW*3, 0, tW, 40, "Output")

    ; ==============================================================================
    ; TAB 1: SOURCE & BACKGROUND
    ; ==============================================================================
    currY := yContentStart + 10

    ; --- Audio Source ---
    AddTabControl("Source", "Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "Audio File:")
    edtAudio := AddTabControl("Source", "Edit", Format("x{} y{} w{} h{} ReadOnly vAudioFile", xInput, currY, wInput, CtrlH))
    SexyButton(myGui, xBtn, currY-1, wBtn, BtnH+2, "Browse...", SelectAudio).RegisterToTab(Tabs, "Source")

    currY += RowH + 10
    
    ; --- Background Color ---
    tCol := myGui.Add("Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "BG Color:")
    Tabs.Register("Source", tCol)
    
    edtCol := AddFlatEdit(myGui, Format("x{} y{} w80 h{} vBgHex", xInput, currY, CtrlH), "000000")
    Tabs.Register("Source", edtCol)
    
    btnPick := SexyButton(myGui, xInput+90, currY-1, 60, BtnH+2, "Pick", (*) => RunColorPicker(edtCol, myGui.Hwnd))
    btnPick.RegisterToTab(Tabs, "Source")

    ; --- Audio Duration Trim ---
    currY += RowH + 15
    AddTabControl("Source", "Text", Format("x{} y{} w{} h1 Background{}", xLabel, currY, GuiWidth-(xLabel*2), Theme.Panel), "")
    currY += 10
    
    AddTabControl("Source", "Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "Duration:")
    ddlDur := DarkDropdown(myGui, xInput, currY, 150, ["Full Audio", "Trim Segment"], "DurMode", UpdateUI)
    ddlDur.RegisterToTab(Tabs, "Source")
    
    grpTrim := []
    tTrim := myGui.Add("Text", Format("x260 y{} w40 h{}", currY+3, CtrlH), "Start:")
    grpTrim.Push(tTrim)
    edtStart := AddFlatEdit(myGui, Format("x300 y{} w60 h{} vTrimStart", currY, CtrlH), "00:00:00")
    grpTrim.Push(edtStart)
    tTrimEnd := myGui.Add("Text", Format("x370 y{} w30 h{}", currY+3, CtrlH), "End:")
    grpTrim.Push(tTrimEnd)
    edtEnd := AddFlatEdit(myGui, Format("x400 y{} w60 h{} vTrimEnd", currY, CtrlH), "00:00:30")
    grpTrim.Push(edtEnd)
    
    for c in grpTrim
        Tabs.Register("Source", c)


    ; ==============================================================================
    ; TAB 2: VISUALIZER CONFIG
    ; ==============================================================================
    currY := yContentStart + 10

    ; Style Selection
    AddTabControl("Visual", "Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "Vis Style:")
    ; Friendly names mapped to internal algo in logic
    visTypes := ["Musical Spectrum (CQT)", "Frequency Bars (Simple)", "Waveform (Lines)", "Stereo Vectorscope (Circles)", "Scientific Spectrum (FFT)"]
    ddlAlgo := DarkDropdown(myGui, xInput, currY, 250, visTypes, "VisAlgo", UpdateUI)
    ddlAlgo.RegisterToTab(Tabs, "Visual")
    
    ; Description Box (Helpful context)
    currY += RowH + 5
    txtDesc := AddTabControl("Visual", "Text", Format("x{} y{} w{} h35 c888888", xInput, currY, wInput+80), "Description goes here...")
    
    currY += 40
    
    ; --- Appearance Group ---
    ; Label changes based on mode (Palette or Color)
    tColorLabel := AddTabControl("Visual", "Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "Palette:")
    
    ; Color Controls (Dynamic)
    grpVisColors := []
    
    ; Preset Dropdown (For Spectrum/CQT)
    ddlSchemes := DarkDropdown(myGui, xInput, currY, 180, ["Magma (Fire)", "Inferno (Dark Fire)", "Plasma (Purple/Orange)", "Viridis (Blue/Green)", "Rainbow"], "VisScheme")
    grpVisColors.Push(ddlSchemes)
    
    ; Single Color Picker (For Waves/Bars)
    edtVisHex := AddFlatEdit(myGui, Format("x{} y{} w80 h{} vVisHex", xInput, currY, CtrlH), "00FF00")
    grpVisColors.Push(edtVisHex)
    
    btnVisPick := SexyButton(myGui, xInput+90, currY-1, 60, BtnH+2, "Pick", (*) => RunColorPicker(edtVisHex, myGui.Hwnd))
    grpVisColors.Push(btnVisPick)
    
    for c in grpVisColors
        Tabs.Register("Visual", c)
        
    currY += RowH + 10
    
    ; --- Layout & Physics ---
    AddTabControl("Visual", "Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "Position:")
    ddlPos := DarkDropdown(myGui, xInput, currY, 120, ["Bottom", "Top", "Center", "Full Screen"], "VisPos", , 4) ; Default Full Screen
    ddlPos.RegisterToTab(Tabs, "Visual")
    
    AddTabControl("Visual", "Text", Format("x240 y{} w45 h{}", currY+3, CtrlH), "Height:")
    sldHeight := myGui.Add("Slider", Format("x290 y{} w120 h{} vVisHeight Range10-100 ToolTip", currY, CtrlH), 100) ; Default 100
    Tabs.Register("Visual", sldHeight)
    
    AddTabControl("Visual", "Text", Format("x430 y{} w50 h{}", currY+3, CtrlH), "Opacity:")
    sldOp := myGui.Add("Slider", Format("x480 y{} w100 h{} vVisOpacity Range10-100 ToolTip", currY, CtrlH), 100) ; Default 100
    Tabs.Register("Visual", sldOp)
    
    currY += RowH + 5
    
    ; --- Advanced Audio Processing ---
    AddTabControl("Visual", "Text", Format("x{} y{} w80 h{}", xLabel, currY+3, CtrlH), "Response:")
    ddlReact := DarkDropdown(myGui, xInput, currY, 150, ["Normal", "High Sensitivity (Boost)", "Smoothed (Less Jitter)"], "VisReact")
    ddlReact.RegisterToTab(Tabs, "Visual")
    
    tReactInfo := AddTabControl("Visual", "Text", Format("x{} y{} w250 h{} c888888 +0x200", xInput+160, currY+3, CtrlH), "(Adjusts how the visualizer reacts to sound)")


    ; ==============================================================================
    ; TAB 3: EFFECTS (POST FX)
    ; ==============================================================================
    currY := yContentStart + 10
    
    ; --- VISUALIZER EFFECTS (Layer Only) ---
    AddTabControl("Effects", "Text", Format("x{} y{} w200 h20 c{}", xLabel, currY, Theme.Accent), "Visualizer FX (Applies to Bars/Waves)")
    currY += 25
    
    ; 1. Hue Shift
    chkHue := myGui.Add("Checkbox", Format("x{} y{} w100 h{} vFxHue c{} Background{}", xLabel, currY, CtrlH, Theme.Text, Theme.Bg), "Hue Cycle")
    SetDarkControl(chkHue)
    Tabs.Register("Effects", chkHue)
    
    AddTabControl("Effects", "Text", Format("x140 y{} w45 h{}", currY+3, CtrlH), "Speed:")
    sldHue := myGui.Add("Slider", Format("x190 y{} w120 h{} vFxHueSpeed Range1-50 ToolTip", currY, CtrlH), 10)
    Tabs.Register("Effects", sldHue)
    
    ; 2. RGB Glitch
    currY += RowH + 5
    chkGlitch := myGui.Add("Checkbox", Format("x{} y{} w100 h{} vFxGlitch c{} Background{}", xLabel, currY, CtrlH, Theme.Text, Theme.Bg), "RGB Glitch")
    SetDarkControl(chkGlitch)
    Tabs.Register("Effects", chkGlitch)
    
    AddTabControl("Effects", "Text", Format("x140 y{} w45 h{}", currY+3, CtrlH), "Offset:")
    sldGlitch := myGui.Add("Slider", Format("x190 y{} w120 h{} vFxGlitchAmt Range1-20 ToolTip", currY, CtrlH), 5)
    Tabs.Register("Effects", sldGlitch)
    
    ; 3. Mirror
    currY += RowH + 5
    chkMirror := myGui.Add("Checkbox", Format("x{} y{} w100 h{} vFxMirror c{} Background{}", xLabel, currY, CtrlH, Theme.Text, Theme.Bg), "Mirroring")
    SetDarkControl(chkMirror)
    Tabs.Register("Effects", chkMirror)
    
    ddlMirror := DarkDropdown(myGui, 190, currY, 120, ["Left-Right", "Top-Bottom", "Quad (4-Way)"], "FxMirrorMode")
    ddlMirror.RegisterToTab(Tabs, "Effects")
    
    ; 4. Glow / Bloom (NEW)
    currY += RowH + 5
    chkGlow := myGui.Add("Checkbox", Format("x{} y{} w100 h{} vFxGlow c{} Background{}", xLabel, currY, CtrlH, Theme.Text, Theme.Bg), "Glow / Bloom")
    SetDarkControl(chkGlow)
    Tabs.Register("Effects", chkGlow)
    
    AddTabControl("Effects", "Text", Format("x140 y{} w45 h{}", currY+3, CtrlH), "Power:")
    sldGlow := myGui.Add("Slider", Format("x190 y{} w120 h{} vFxGlowAmt Range1-20 ToolTip", currY, CtrlH), 5)
    Tabs.Register("Effects", sldGlow)
    
    ; 5. Trails / Feedback (NEW)
    currY += RowH + 5
    chkTrails := myGui.Add("Checkbox", Format("x{} y{} w100 h{} vFxTrails c{} Background{}", xLabel, currY, CtrlH, Theme.Text, Theme.Bg), "Trails")
    SetDarkControl(chkTrails)
    Tabs.Register("Effects", chkTrails)
    
    AddTabControl("Effects", "Text", Format("x140 y{} w45 h{}", currY+3, CtrlH), "Decay:")
    sldTrails := myGui.Add("Slider", Format("x190 y{} w120 h{} vFxTrailsDecay Range1-99 ToolTip", currY, CtrlH), 70)
    Tabs.Register("Effects", sldTrails)
    
    ; 6. Neon Edges (NEW)
    currY += RowH + 5
    chkNeon := myGui.Add("Checkbox", Format("x{} y{} w150 h{} vFxNeon c{} Background{}", xLabel, currY, CtrlH, Theme.Text, Theme.Bg), "Neon Edges (Outline)")
    SetDarkControl(chkNeon)
    Tabs.Register("Effects", chkNeon)
    
    
    ; --- GLOBAL EFFECTS (Final Composition) ---
    currY += RowH + 20
    AddTabControl("Effects", "Text", Format("x{} y{} w200 h20 c{}", xLabel, currY, Theme.Accent), "Global FX (Applies to Final Video)")
    currY += 25
    
    ; 7. Pixelate
    chkPix := myGui.Add("Checkbox", Format("x{} y{} w100 h{} vFxPixel c{} Background{}", xLabel, currY, CtrlH, Theme.Text, Theme.Bg), "Pixelate")
    SetDarkControl(chkPix)
    Tabs.Register("Effects", chkPix)
    
    AddTabControl("Effects", "Text", Format("x140 y{} w45 h{}", currY+3, CtrlH), "Size:")
    sldPix := myGui.Add("Slider", Format("x190 y{} w120 h{} vFxPixelSize Range2-64 ToolTip", currY, CtrlH), 8)
    Tabs.Register("Effects", sldPix)
    
    ; 8. Vignette
    currY += RowH + 5
    chkVig := myGui.Add("Checkbox", Format("x{} y{} w100 h{} vFxVig c{} Background{}", xLabel, currY, CtrlH, Theme.Text, Theme.Bg), "Vignette")
    SetDarkControl(chkVig)
    Tabs.Register("Effects", chkVig)
    
    AddTabControl("Effects", "Text", Format("x140 y{} w45 h{}", currY+3, CtrlH), "Depth:")
    sldVig := myGui.Add("Slider", Format("x190 y{} w120 h{} vFxVigStr Range1-100 ToolTip", currY, CtrlH), 30)
    Tabs.Register("Effects", sldVig)
    
    ; 9. Film Grain
    currY += RowH + 5
    chkGrain := myGui.Add("Checkbox", Format("x{} y{} w100 h{} vFxGrain c{} Background{}", xLabel, currY, CtrlH, Theme.Text, Theme.Bg), "Film Grain")
    SetDarkControl(chkGrain)
    Tabs.Register("Effects", chkGrain)
    
    AddTabControl("Effects", "Text", Format("x140 y{} w45 h{}", currY+3, CtrlH), "Level:")
    sldGrain := myGui.Add("Slider", Format("x190 y{} w120 h{} vFxGrainStr Range1-50 ToolTip", currY, CtrlH), 10)
    Tabs.Register("Effects", sldGrain)


    ; ==============================================================================
    ; TAB 4: OUTPUT
    ; ==============================================================================
    currY := yContentStart + 10

    AddTabControl("Output", "Text", Format("x{} y{} w70 h{}", xLabel, currY+3, CtrlH), "Resolution:")
    ddlRes := DarkDropdown(myGui, xInput, currY, 200, ["1920x1080 (1080p)", "1280x720 (720p)", "3840x2160 (4K)", "1080x1080 (Square)", "1080x1920 (Vertical)"], "OutRes")
    ddlRes.RegisterToTab(Tabs, "Output")
    
    tFPS := AddTabControl("Output", "Text", Format("x310 y{} w40 h{}", currY+3, CtrlH), "FPS:")
    ddlFPS := DarkDropdown(myGui, 350, currY, 100, ["60", "30", "24"], "OutFPS")
    ddlFPS.RegisterToTab(Tabs, "Output")

    currY += RowH + 10
    
    AddTabControl("Output", "Text", Format("x{} y{} w70 h{}", xLabel, currY+3, CtrlH), "Format:")
    ddlFmt := DarkDropdown(myGui, xInput, currY, 200, ["MP4 (H.264 / AAC)", "MKV (H.264 / FLAC)", "WebM (VP9 / Vorbis)"], "OutFormat")
    ddlFmt.RegisterToTab(Tabs, "Output")

    currY += RowH + 5
    AddTabControl("Output", "Text", Format("x{} y{} w70 h{}", xLabel, currY+3, CtrlH), "Quality:")
    ddlQual := DarkDropdown(myGui, xInput, currY, 200, ["High (CRF 18)", "Balanced (CRF 23)", "Fast (CRF 28)"], "OutQuality", , 2)
    ddlQual.RegisterToTab(Tabs, "Output")


    ; ==============================================================================
    ; FOOTER
    ; ==============================================================================
    yFooter := 420 ; Raised significantly to fit new controls

    myGui.Add("Text", Format("x0 y{} w{} h65 Background{}", yFooter-3, GuiWidth, Theme.DarkPanel), "")

    SexyButton(myGui, 10, yFooter+5, 100, 30, "Save Preset", SavePreset)
    SexyButton(myGui, 120, yFooter+5, 100, 30, "Load Preset", LoadPreset)

    SexyButton(myGui, 350, yFooter+5, 100, 30, "Preview (5s)", PreviewRender)
    
    btnCreate := SexyButton(myGui, 460, yFooter+5, 140, 30, "Render Video", StartRender)
    btnCreate.Beautify()
    
    btnCancel := SexyButton(myGui, 460, yFooter+5, 140, 30, "Cancel", CancelRender)
    btnCancel.Visible := false
    btnCancel.setBorders([Theme.AltAccent,Theme.AltAccent,Theme.AltAccent,Theme.AltAccent])
    btnCancel.SetTextColour(Theme.AltAccent)

    ; Status Bar
    yStatus := yFooter + 38
    progressBar := myGui.Add("Progress", Format("x0 y{} w{} h3 c{} Background{}", yStatus, GuiWidth, Theme.Accent, Theme.DarkPanel, "Range0-100 vMyProgress"), 0)

    myGui.SetFont("s8 c" Theme.Text, "Fixedsys")
    sb := myGui.Add("Text", Format("x0 y{} w{} h20 c{} Background{} +0x200 Center vStatusText", yStatus+3, GuiWidth, Theme.Accent, Theme.StatusBg), "Idle")

    Tabs.Switch("Source")
    UpdateUI()
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
        UpdateUI()
    }

    SelectAudio(*) {
        path := FileSelect(1, , "Select Audio", "Audio (*.mp3; *.wav; *.flac; *.aac; *.m4a; *.ogg)")
        if path 
            edtAudio.Value := path
    }

    HandleDropFiles(guiObj, ctrlObj, fileArray, x, y) {
        if (fileArray.Length == 0)
            return
        
        f := fileArray[1]
        edtAudio.Value := f
    }

    UpdateUI(*) {
        ; 1. Trim UI
        isTrim := (ddlDur.Text == "Trim Segment")
        for c in grpTrim
            c.Visible := (isTrim && Tabs.Current == "Source")
            
        ; 3. Visualizer Type / Algo
        algo := ddlAlgo.Text
        
        desc := ""
        if InStr(algo, "Musical Spectrum")
            desc := "Displays musical notes (CQT). Best for music visualization. Uses smooth gradients."
        else if InStr(algo, "Frequency Bars")
            desc := "Classic bar graph. Shows loudness of different frequencies. Simple and clean."
        else if InStr(algo, "Waveform")
            desc := "Oscilloscope style line. Shows the raw sound wave shape."
        else if InStr(algo, "Stereo Vectorscope")
            desc := "Visualizes stereo balance (Left vs Right channels) in a XY plot."
        else if InStr(algo, "Scientific Spectrum")
            desc := "Detailed FFT frequency analysis. Shows raw frequency data."
            
        txtDesc.Text := desc
        
        ; Color Controls logic
        isSpectrum := (InStr(algo, "Spectrum") || InStr(algo, "CQT"))
        isLine     := (InStr(algo, "Waveform") || InStr(algo, "Vectorscope") || InStr(algo, "Bars"))
        
        showScheme := (isSpectrum && Tabs.Current == "Visual")
        showHex    := (isLine && Tabs.Current == "Visual")
        
        if (showScheme)
            tColorLabel.Text := "Palette:"
        else
            tColorLabel.Text := "Color:"
        
        ddlSchemes.SetVisible(showScheme)
        edtVisHex.Visible := showHex
        btnVisPick.Visible := showHex
    }

    ; ==============================================================================
    ; BUILD COMMAND
    ; ==============================================================================

    BuildCommand(saved, isPreview := false) {
        if (saved.AudioFile == "")
            throw Error("Select an audio file.")
            
        cmdArgs := ["-y"]
        
        ; --- INPUTS ---
        
        ; 1. Audio (Trim if needed)
        if (saved.DurMode == "Trim Segment" || isPreview) {
            start := (isPreview) ? "00:00:30" : saved.TrimStart
            cmdArgs.Push("-ss", start)
        }
        
        cmdArgs.Push("-i", Format('"{1}"', saved.AudioFile))
        
        if (isPreview) {
            cmdArgs.Push("-t", "5")
        } else if (saved.DurMode == "Trim Segment" && saved.TrimEnd != "") {
            cmdArgs.Push("-to", saved.TrimEnd)
        }
        
        ; --- RESOLUTION & FPS ---
        w := 1920, h := 1080
        if RegExMatch(saved.OutRes, "(\d+)x(\d+)", &m) {
            w := m[1], h := m[2]
        }
        fps := saved.OutFPS
        
        
        ; --- FILTER CHAIN ---
        fc := []
        
        ; A. Background Layer [bg]
        ; Solid Color BG
        col := "0x" saved.BgHex
        fc.Push(Format("color=c={1}:s={2}x{3}:r={4}[bg]", col, w, h, fps))
        
        ; B. Audio Processing [aud]
        ; Gain / Smoothing
        aFilters := "anull"
        if (saved.VisReact == "High Sensitivity (Boost)")
            aFilters := "volume=4.0"
        else if (saved.VisReact == "Smoothed (Less Jitter)")
            aFilters := "lowpass=f=1000" ; Simple smoothing
            
        fc.Push(Format("[0:a]{1}[aud]", aFilters))
        
        ; C. Visualizer Layer [vis]
        visW := w
        ; Fix for AHK v2 floating point issue: Force integer calculation for height
        visH := Integer((saved.VisHeight / 100.0) * h)
        ; Ensure even height for safety (optional but good practice)
        visH := (visH // 2) * 2
        
        visAlgo := saved.VisAlgo
        
        visCmd := ""
        
        ; Common Colors
        scheme := "magma"
        if InStr(saved.VisScheme, "Magma") 
            scheme := "magma"
        else if InStr(saved.VisScheme, "Fire") 
            scheme := "fire"
        else if InStr(saved.VisScheme, "Viridis") 
            scheme := "viridis"
        else if InStr(saved.VisScheme, "Plasma") 
            scheme := "plasma"
        else if InStr(saved.VisScheme, "Inferno") 
            scheme := "inferno"
        else if InStr(saved.VisScheme, "Rainbow") 
            scheme := "rainbow"
        else if InStr(saved.VisScheme, "Cool") 
            scheme := "cool"
            
        hex := "0x" saved.VisHex
        
        if InStr(visAlgo, "Musical Spectrum") {
            ; ShowCQT
            visCmd := Format("showcqt=s={1}x{2}:r={3}:text=0:axis=0:sono_h={2}:sono_g=1", visW, visH, fps)
            
        } else if InStr(visAlgo, "Scientific Spectrum") {
            ; ShowSpectrum
            visCmd := Format("showspectrum=s={1}x{2}:mode=separate:color={3}:scale=log:slide=scroll", visW, visH, scheme)
            
        } else if InStr(visAlgo, "Waveform") {
            ; ShowWaves
            visCmd := Format("showwaves=s={1}x{2}:r={3}:mode=line:colors={4}", visW, visH, fps, hex)
            
        } else if InStr(visAlgo, "Frequency Bars") {
            ; ShowFreqs
            visCmd := Format("showfreqs=s={1}x{2}:r={3}:mode=bar:ascale=log:colors={4}", visW, visH, fps, hex)
            
        } else if InStr(visAlgo, "Stereo Vectorscope") {
            ; Avectorscope (Needs square usually, but we force fit)
            ; Colors must be R, G, B ints
            hexStr := StrReplace(saved.VisHex, "0x", "")
            if (StrLen(hexStr) == 6) {
                R := Integer("0x" SubStr(hexStr, 1, 2))
                G := Integer("0x" SubStr(hexStr, 3, 2))
                B := Integer("0x" SubStr(hexStr, 5, 2))
                visCmd := Format("avectorscope=s={1}x{2}:r={3}:mirror=1:draw=line:rc={4}:gc={5}:bc={6}", visW, visW, fps, R, G, B)
            } else {
                visCmd := Format("avectorscope=s={1}x{2}:r={3}:mirror=1:draw=line:rc=20:gc=200:bc=20", visW, visW, fps) 
            }
        } 
        
        ; Opacity of Visualizer
        visOp := saved.VisOpacity / 100.0
        
        ; --- Layer FX (Applies to Visualizer only) ---
        layerFx := ""
        
        ; 1. Neon Edges (Structure change, do early)
        if (saved.FxNeon) {
            ; Edgedetect + Color mix
            layerFx .= ",edgedetect=mode=colormix:high=0"
        }
        
        ; 2. Hue Cycle
        if (saved.FxHue) {
            speed := saved.FxHueSpeed 
            layerFx .= Format(",hue=h={1}*t", speed)
        }
        
        ; 3. Glitch
        if (saved.FxGlitch) {
            offset := saved.FxGlitchAmt
            layerFx .= Format(",chromashift=cbh={1}:crh=-{1}", offset)
        }
        
        ; 4. Mirror
        if (saved.FxMirror) {
            mode := saved.FxMirrorMode
            if (mode == "Left-Right") {
                layerFx .= ",crop=iw/2:ih:0:0,split[L][R];[R]hflip[RR];[L][RR]hstack"
            } else if (mode == "Top-Bottom") {
                layerFx .= ",crop=iw:ih/2:0:0,split[T][B];[B]vflip[BB];[T][BB]vstack"
            } else if (mode == "Quad (4-Way)") {
                layerFx .= ",crop=iw/2:ih/2:0:0,split[TL][TR];[TR]hflip[TRF];[TL][TRF]hstack,split[TOP][BOT];[BOT]vflip[BOTF];[TOP][BOTF]vstack"
            }
        }
        
        ; 5. Trails (Temporal feedback)
        if (saved.FxTrails) {
            decay := saved.FxTrailsDecay / 100.0 ; 0.0 to 0.99
            ; lagfun filter creates trails
            layerFx .= Format(",lagfun=decay={1}:planes=7", decay)
        }
        
        ; 6. Glow / Bloom (Must happen after main chain)
        ; Logic: We apply base chain, then split. One path blurs/brightens, then blends back.
        ; Since layerFx is a linear chain string, we can't easily split inside it without
        ; confusing the `[aud]cmd[vis]` structure.
        ; Solution: Apply glow AFTER layerFx in the filter_complex construction below.
        
        ; Ensure format is rgba for transparency mixing + Layer FX
        baseVis := Format("[aud]{1}{2},format=rgba", visCmd, layerFx)
        
        if (saved.FxGlow) {
            ; Glow Implementation:
            ; [vis_raw]split[v_main][v_bloom];
            ; [v_bloom]scale=iw/2:ih/2:flags=neighbor,gblur=sigma=XX,scale=iw*2:ih*2:flags=neighbor[v_bloom_up];
            ; [v_main][v_bloom_up]blend=all_mode=screen:shortest=1,colorchannelmixer=aa=OPACITY
            
            str := saved.FxGlowAmt
            sigma := str ; blur strength
            
            baseVis .= "[vis_pre];[vis_pre]split[v_main][v_bloom];[v_bloom]scale=iw/2:ih/2:flags=neighbor,gblur=sigma=" sigma ",scale=iw*2:ih*2:flags=neighbor[v_bloom_up];[v_main][v_bloom_up]blend=all_mode=screen:shortest=1"
        }
        
        ; Final opacity mixer
        baseVis .= Format(",colorchannelmixer=aa={1}[vis]", visOp)
        
        fc.Push(baseVis)
        
        ; D. Composite [out]
        ; Calculate X/Y based on Position dropdown
        posX := "(W-w)/2" ; Center X
        posY := "(H-h)/2" ; Center Y
        
        if (saved.VisPos == "Bottom")
            posY := "H-h"
        else if (saved.VisPos == "Top")
            posY := "0"
        else if (saved.VisPos == "Full Screen") {
            posY := "(H-h)/2"
        }
        
        overlayCmd := Format("overlay=x={1}:y={2}", posX, posY)
        
        ; --- Global FX (Applies after composite) ---
        globalFx := ""
        
        if (saved.FxPixel) {
            size := saved.FxPixelSize
            globalFx .= Format(",scale=iw/{1}:ih/{1}:flags=neighbor,scale=iw*{1}:ih*{1}:flags=neighbor", size)
        }
        
        if (saved.FxVig) {
            str := saved.FxVigStr / 100.0 
            angle := (3.14159 / 4) * (1.5 - str)
            globalFx .= Format(",vignette=angle={1}", angle)
        }
        
        if (saved.FxGrain) {
            str := saved.FxGrainStr
            globalFx .= Format(",noise=c0s={1}:allf=t", str)
        }
        
        fc.Push(Format("[bg][vis]{1}{2}[outv]", overlayCmd, globalFx))
        
        ; --- ASSEMBLY ---
        cmdArgs.Push("-filter_complex", JoinFilters(fc))
        cmdArgs.Push("-map", "[outv]", "-map", "0:a")
        
        ; Encoder
        if InStr(saved.OutFormat, "WebM") {
            cmdArgs.Push("-c:v", "libvpx-vp9", "-b:v", "0", "-c:a", "libvorbis")
        } else if InStr(saved.OutFormat, "MKV") {
            cmdArgs.Push("-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "copy")
        } else {
            cmdArgs.Push("-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k")
        }
        
        ; CRF
        crf := 23
        if InStr(saved.OutQuality, "High")
            crf := 18
        else if InStr(saved.OutQuality, "Fast")
            crf := 28
        cmdArgs.Push("-crf", crf)
        
        ; Shortest (stops when audio stops)
        cmdArgs.Push("-shortest")
        
        return cmdArgs
    }
    
    JoinFilters(arr) {
        str := ""
        for s in arr
            str .= (str == "" ? "" : ";") . s
        return str
    }

    PreviewRender(*) {
        saved := myGui.Submit(0)
        try {
            cmdArgs := BuildCommand(saved, true)
            outPath := A_Temp "\vis_preview.mp4"
            try FileDelete(outPath)
            
            sb.Text := " Generating Preview..."
            
            OnPrevFinish(success, result) {
                if success {
                    sb.Text := " Done."
                    Run(outPath)
                } else {
                    sb.Text := " Error."
                    ShowErrorLog(result)
                }
            }
            
            FFWrapper.Run(cmdArgs, outPath, (p,t) => "", OnPrevFinish)
            
        } catch as e {
            customDialog({message:e.Message}, errorPreset)
        }
    }

    StartRender(*) {
        saved := myGui.Submit(0)
        try {
            cmdArgs := BuildCommand(saved, false)
            
            SplitPath(saved.AudioFile, , &dir, , &nameNoExt)
            ext := InStr(saved.OutFormat, "WebM") ? "webm" : InStr(saved.OutFormat, "MKV") ? "mkv" : "mp4"
            outPath := FileSelect("S", dir "\" nameNoExt "_visualizer." ext, "Save Video", "Video (*." ext ")")
            
            if !outPath
                return
            if !RegExMatch(outPath, "\." ext "$")
                outPath .= "." ext
                
            btnCreate.Visible := false
            btnCancel.Visible := true
            sb.Text := " Rendering..."
            progressBar.Value := 0
            
            OnProgress(pct, text) {
                progressBar.Value := pct
                sb.Text := text
            }
            
            OnFinish(success, result) {
                btnCancel.Visible := false
                btnCreate.Visible := true
                if success {
                    progressBar.Value := 100
                    sb.Text := " Complete!"
                    if MsgBox("Done! Open file?", "Success", "YesNo") == "Yes"
                        Run("explorer.exe /select,`"" result "`"")
                } else {
                    sb.Text := " Failed."
                    if !InStr(result, "Cancelled")
                        ShowErrorLog(result)
                }
            }
            
            FFWrapper.Run(cmdArgs, outPath, OnProgress, OnFinish)
            
        } catch as e {
            customDialog({message:e.Message}, errorPreset)
        }
    }

    CancelRender(*) {
        FFWrapper.Stop()
        sb.Text := " Cancelling..."
    }

    ShowErrorLog(logContent) {
        customDialog({title:"FFmpeg Error Log",message:"Process Failed! Log:",detail: logContent}, criticalErrorDetailPreset)
    }

    ; ==============================================================================
    ; PRESETS
    ; ==============================================================================
    SavePreset(*) {
        path := FileSelect("S", "Visualizer.ini", "Save Preset", "Settings (*.ini)")
        if !path 
            return
        saved := myGui.Submit(0)
        for k, v in saved.OwnProps()
            IniWrite(v, path, "Settings", k)
        
        ; Dropdowns
        IniWrite(ddlBgMode.Text, path, "Settings", "BgMode")
        IniWrite(ddlAnim.Text, path, "Settings", "BgAnim")
        IniWrite(ddlVisType.Text, path, "Settings", "VisType")
        IniWrite(ddlAlgo.Text, path, "Settings", "VisAlgo")
        IniWrite(ddlColorMode.Text, path, "Settings", "ColorMode")
        IniWrite(ddlSchemes.Text, path, "Settings", "VisScheme")
        IniWrite(ddlPos.Text, path, "Settings", "VisPos")
        IniWrite(ddlReact.Text, path, "Settings", "VisReact")
        IniWrite(ddlRes.Text, path, "Settings", "OutRes")
        IniWrite(ddlFPS.Text, path, "Settings", "OutFPS")
        IniWrite(ddlMirror.Text, path, "Settings", "FxMirrorMode")
        
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
                if (k != "AudioFile")
                    try myGui[k].Value := val
            }
        }
        try ddlBgMode.Text := IniRead(path, "Settings", "BgMode")
        try ddlAnim.Text := IniRead(path, "Settings", "BgAnim")
        try ddlVisType.Text := IniRead(path, "Settings", "VisType")
        try ddlAlgo.Text := IniRead(path, "Settings", "VisAlgo")
        try ddlColorMode.Text := IniRead(path, "Settings", "ColorMode")
        try ddlSchemes.Text := IniRead(path, "Settings", "VisScheme")
        try ddlPos.Text := IniRead(path, "Settings", "VisPos")
        try ddlReact.Text := IniRead(path, "Settings", "VisReact")
        try ddlRes.Text := IniRead(path, "Settings", "OutRes")
        try ddlFPS.Text := IniRead(path, "Settings", "OutFPS")
        try ddlMirror.Text := IniRead(path, "Settings", "FxMirrorMode")
        
        UpdateUI()
        sb.Text := " Preset Loaded."
    }
}

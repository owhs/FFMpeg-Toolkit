/*
    FFmpeg Audio Tool (AHK v2)
    --------------------------
    Tool 1: Extract Audio - Rip audio tracks from video files.
    Tool 2: Replace Audio - Swap, add, or remove audio tracks in a video.
*/
#Requires AutoHotkey v2.0


#Include ..\lib\utils.ahk

AudioTool(){
    global AppName := "FFMpeg: Audio Tool"
    global FFWrapper := ""

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
    Tabs.Add("1. Extract Audio", 0, 0, tW, 40, "Extract")
    Tabs.Add("2. Replace Audio", tW, 0, tW, 40, "Replace")


    ; ==============================================================================
    ; TAB 1: EXTRACT AUDIO
    ; ==============================================================================
    yStart := 55
    currY  := yStart

    ; Input
    AddTabControl("Extract", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Video:")
    edtExtInput := AddTabControl("Extract", "Edit", Format("x{} y{} w{} h{} ReadOnly vExtInput", xInput, currY, wInput-95, CtrlH), "")
    btnExtBrowse := SexyButton(myGui, xInput+wInput-90, currY-1, 90, BtnH+2, "Browse...", SelectExtInput)
    btnExtBrowse.RegisterToTab(Tabs, "Extract")

    ; Format
    currY += RowH + 10
    AddTabControl("Extract", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Format:")
    ddlExtFmt := DarkDropdown(myGui, xInput, currY, 180, ["Same as Source (Auto)", "MP3 (Universal)", "AAC (M4A)", "WAV (Lossless)", "FLAC (Lossless)", "OGG (Vorbis)"], "ExtFormat")
    ddlExtFmt.RegisterToTab(Tabs, "Extract")

    ; Quality
    currY += RowH + 5
    AddTabControl("Extract", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Quality:")
    ddlExtQual := DarkDropdown(myGui, xInput, currY, 180, ["320 kbps (High)", "192 kbps (Standard)", "128 kbps (Low)", "Copy (Stream Copy)"], "ExtQuality")
    ddlExtQual.RegisterToTab(Tabs, "Extract")

    txtExtNote := AddTabControl("Extract", "Text", Format("x{} y{} w{} h40 c888888 Background{}", xInput, currY+RowH+5, wInput, Theme.Bg), "Note: 'Copy' extracts the raw audio stream without re-encoding.`nUseful for fast extraction if format matches.")


    ; ==============================================================================
    ; TAB 2: REPLACE AUDIO
    ; ==============================================================================
    currY := yStart

    ; Video Input
    AddTabControl("Replace", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Video:")
    edtRepVideo := AddTabControl("Replace", "Edit", Format("x{} y{} w{} h{} ReadOnly vRepVideo", xInput, currY, wInput-95, CtrlH), "")
    btnRepVidBrowse := SexyButton(myGui, xInput+wInput-90, currY-1, 90, BtnH+2, "Browse...", SelectRepVideo)
    btnRepVidBrowse.RegisterToTab(Tabs, "Replace")

    ; Audio Input
    currY += RowH + 5
    txtRepAudio := AddTabControl("Replace", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Audio:")
    edtRepAudio := AddTabControl("Replace", "Edit", Format("x{} y{} w{} h{} ReadOnly vRepAudio", xInput, currY, wInput-95, CtrlH), "")
    btnRepAudBrowse := SexyButton(myGui, xInput+wInput-90, currY-1, 90, BtnH+2, "Pick...", SelectRepAudio)
    btnRepAudBrowse.RegisterToTab(Tabs, "Replace")

    ; Mode
    currY += RowH + 10
    AddTabControl("Replace", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Mode:")
    ddlRepMode := DarkDropdown(myGui, xInput, currY, 300, ["Replace Audio (Delete Original)", "Add Audio (Keep Original as Track 2)", "Remove Audio (Mute Video)"], "RepMode", UpdateRepUI)
    ddlRepMode.RegisterToTab(Tabs, "Replace")

    ; Options
    currY += RowH + 5
    chkShortest := myGui.Add("Checkbox", Format("x{} y{} w300 h{} vRepShortest c{} Background{}", xInput, currY, CtrlH, Theme.Text, Theme.Bg), "Cut Video to Shortest Stream")
    SetDarkControl(chkShortest)
    Tabs.Register("Replace", chkShortest)
    chkShortest.Value := 1 ; Default to true to prevent frozen video if audio is shorter

    currY += RowH
    tRepNote := AddTabControl("Replace", "Text", Format("x{} y{} w{} h40 c888888 Background{}", xLabel, currY, wInput, Theme.Bg), "Replace: Old audio is removed. New audio becomes default.`nAdd: Old audio is kept. New audio is added as a secondary track.")


    ; ==============================================================================
    ; FOOTER
    ; ==============================================================================
    yFooter := 245
    myGui.Add("Text", Format("x0 y{} w{} h65 Background{}", yFooter-3, GuiWidth, Theme.DarkPanel), "")

    btnProcess := SexyButton(myGui, 360, yFooter+10, 120, 35, "Start", StartProcess)
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
    Tabs.Switch("Extract")
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
        if (newTabName == "Extract")
            btnProcess.SetText("Extract Audio")
        else
            btnProcess.SetText("Process Video")
    }

    UpdateRepUI(*) {
        mode := ddlRepMode.Text
        isRemove := InStr(mode, "Remove")
        
        ; Hide/Show Audio input controls
        txtRepAudio.Visible := !isRemove
        edtRepAudio.Visible := !isRemove
        btnRepAudBrowse.Visible := !isRemove
        
        ; Also toggle "Shortest" checkbox as it's irrelevant for removal
        chkShortest.Visible := !isRemove
    }

    SelectExtInput(*) {
        path := FileSelect(1, , "Select Video", "Video (*.mp4; *.mkv; *.avi; *.mov; *.webm; *.flv)")
        if path
            edtExtInput.Value := path
    }

    SelectRepVideo(*) {
        path := FileSelect(1, , "Select Video", "Video (*.mp4; *.mkv; *.avi; *.mov; *.webm)")
        if path
            edtRepVideo.Value := path
    }

    SelectRepAudio(*) {
        path := FileSelect(1, , "Select Audio", "Audio (*.mp3; *.wav; *.aac; *.m4a; *.flac; *.ogg)")
        if path
            edtRepAudio.Value := path
    }

    HandleDropFiles(guiObj, ctrlObj, fileArray, x, y) {
        if (fileArray.Length == 0)
            return
        
        f := fileArray[1]
        
        if (Tabs.Current == "Extract") {
            edtExtInput.Value := f
        } else {
            ; Smart detection for Replace tab
            SplitPath(f, , , &ext)
            if RegExMatch(ext, "i)^(mp3|wav|aac|m4a|flac|ogg)$")
                edtRepAudio.Value := f
            else
                edtRepVideo.Value := f
        }
    }

    GetAudioCodecExt(filePath) {
        if !FileExist(filePath)
            return "mp3"
        ff := FFWrapper.ffmpegPath
        logFile := A_Temp "\audio_probe.txt"
        try FileDelete(logFile)
        cmd := Format('"{1}" -hide_banner -i "{2}" 2> "{3}"', ff, filePath, logFile)
        RunWait(A_ComSpec " /c " cmd, , "Hide")
        content := FileExist(logFile) ? FileRead(logFile) : ""
        try FileDelete(logFile)
        
        if RegExMatch(content, "Audio:\s+([a-zA-Z0-9_]+)", &m) {
            c := m[1]
            switch c {
                case "aac": return "m4a"
                case "mp3": return "mp3"
                case "ac3": return "ac3"
                case "flac": return "flac"
                case "vorbis": return "ogg"
                case "opus": return "opus"
            }
            if (InStr(c, "pcm")) 
                return "wav"
        }
        return "mka" ; Fallback container
    }


    ; ==============================================================================
    ; PROCESS LOGIC
    ; ==============================================================================
    StartProcess(*) {
        if (Tabs.Current == "Extract")
            ProcessExtract()
        else
            ProcessReplace()
    }

    ProcessExtract() {
        saved := myGui.Submit(0)
        if (saved.ExtInput == "")
            return customDialog({message: "Select a video file first."}, darkPreset)
            
        SplitPath(saved.ExtInput, , &dir, , &nameNoExt)
        
        ; Determine Extension
        outExt := "mp3" ; Default
        isAuto := InStr(saved.ExtFormat, "Same as Source")
        
        if (isAuto) {
            outExt := GetAudioCodecExt(saved.ExtInput)
        }
        else if InStr(saved.ExtFormat, "AAC")
            outExt := "m4a"
        else if InStr(saved.ExtFormat, "WAV")
            outExt := "wav"
        else if InStr(saved.ExtFormat, "FLAC")
            outExt := "flac"
        else if InStr(saved.ExtFormat, "OGG")
            outExt := "ogg"
            
        outPath := FileSelect("S", dir "\" nameNoExt "_audio." outExt, "Save Audio", "Audio (*." outExt ")")
        if !outPath
            return
            
        if !RegExMatch(outPath, "\." outExt "$")
            outPath .= "." outExt
            
        cmdArgs := []
        cmdArgs.Push("-y", "-i", Format('"{1}"', saved.ExtInput), "-vn") ; -vn disable video
        
        ; Quality / Codec settings
        isCopy := InStr(saved.ExtQuality, "Copy")
        
        if (isAuto || isCopy) {
            cmdArgs.Push("-c:a", "copy")
        } else {
            ; Set Codec
            switch outExt {
                case "mp3":  cmdArgs.Push("-c:a", "libmp3lame")
                case "m4a":  cmdArgs.Push("-c:a", "aac")
                case "wav":  cmdArgs.Push("-c:a", "pcm_s16le")
                case "flac": cmdArgs.Push("-c:a", "flac")
                case "ogg":  cmdArgs.Push("-c:a", "libvorbis")
            }
            
            ; Set Bitrate (Ignore for Lossless WAV/FLAC)
            if (outExt != "wav" && outExt != "flac") {
                bitrate := "192k"
                if InStr(saved.ExtQuality, "320")
                    bitrate := "320k"
                else if InStr(saved.ExtQuality, "128")
                    bitrate := "128k"
                cmdArgs.Push("-b:a", bitrate)
            }
        }
        
        ExecuteJob(cmdArgs, outPath)
    }

    ProcessReplace() {
        saved := myGui.Submit(0)
        isRemove := InStr(saved.RepMode, "Remove")
        
        if (saved.RepVideo == "")
            return customDialog({message: "Select a video file."}, darkPreset)
            
        if (!isRemove && saved.RepAudio == "")
            return customDialog({message: "Select an audio file."}, darkPreset)
            
        SplitPath(saved.RepVideo, , &dir, , &nameNoExt)
        SplitPath(saved.RepVideo, , , &vidExt)
        
        suffix := isRemove ? "_muted" : "_newaudio"
        outPath := FileSelect("S", dir "\" nameNoExt suffix "." vidExt, "Save Output Video", "Video (*." vidExt ")")
        if !outPath
            return
            
        cmdArgs := []
        cmdArgs.Push("-y")
        cmdArgs.Push("-i", Format('"{1}"', saved.RepVideo))
        
        if (isRemove) {
            ; Remove Audio Mode
            cmdArgs.Push("-c:v", "copy") ; Copy Video
            cmdArgs.Push("-an")          ; Remove Audio
        } 
        else {
            ; Replace / Add Mode
            cmdArgs.Push("-i", Format('"{1}"', saved.RepAudio))
            
            ; Mapping Logic
            if InStr(saved.RepMode, "Replace Audio") {
                ; Map Video from 0, Audio from 1
                cmdArgs.Push("-map", "0:v:0")
                cmdArgs.Push("-map", "1:a:0")
            } else {
                ; Add Audio (Keep all from 0, add 1)
                cmdArgs.Push("-map", "0")
                cmdArgs.Push("-map", "1:a:0")
            }
            
            ; Copy Video Stream (Fast)
            cmdArgs.Push("-c:v", "copy")
            
            ; Audio Encoding
            ; Usually safer to re-encode audio to AAC if container is MP4 to ensure compatibility
            if (vidExt = "mp4" || vidExt = "mov") {
                cmdArgs.Push("-c:a", "aac", "-b:a", "192k")
            } else {
                ; For MKV etc, we can try copying, but re-encoding is safer for sync
                cmdArgs.Push("-c:a", "aac", "-b:a", "192k") 
            }
            
            if (saved.RepShortest)
                cmdArgs.Push("-shortest")
        }
            
        ExecuteJob(cmdArgs, outPath)
    }

    ExecuteJob(cmdArgs, outputFile) {
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
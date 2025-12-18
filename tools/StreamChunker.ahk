/*
    FFmpeg Stream Chunker (AHK v2)
    ------------------------------
    A specialized tool for creating streamable video segments (HLS/DASH) 
    and stitching them back together.
    
    Modes:
    1. Split: Video -> M3U8/DASH Playlist + Chunks
    2. Join:  M3U8/DASH Playlist -> Single Video
*/
#Requires AutoHotkey v2.0

#Include ..\lib\utils.ahk

StreamChunker(){
    global AppName := "FFMpeg: Stream Chunker"


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
    ; HEADER: MODE SELECTION
    ; ==============================================================================
    myGui.Add("Text", Format("x0 y0 w{} h50 Background{}", GuiWidth, Theme.DarkPanel), "")
    myGui.SetFont("s11 w600")
    myGui.Add("Text", "x20 y12 w60 h30 Background" Theme.DarkPanel, "Mode:")
    myGui.SetFont("s9 w400")

    ; We use a dropdown to switch between Split and Join interfaces
    ddlMode := DarkDropdown(myGui, 80, 10, wInput, ["Split Video to Stream", "Join Stream to Video"], "AppMode", UpdateUI)

    ; ==============================================================================
    ; MAIN CONTENT AREA
    ; ==============================================================================
    yStart := 65
    currY  := yStart

    ; --- INPUT SELECTION ---
    txtInput := myGui.Add("Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Input:")
    edtInput := AddFlatEdit(myGui, Format("x{} y{} w{} h{} ReadOnly vInputFile", xInput, currY, wInput-100, CtrlH))
    btnBrowse := SexyButton(myGui, xInput+wInput-95, currY-1, 95, BtnH+2, "Browse...", SelectInput)

    ; --- SPLIT SETTINGS GROUP ---
    currY += RowH + 10
    grpSplit := []

    tSeg := myGui.Add("Text", Format("x{} y{} w70 h{}", xLabel, currY+3, CtrlH), "Chunk Time:")
    grpSplit.Push(tSeg)
    edtSegTime := AddFlatEdit(myGui, Format("x{} y{} w60 h{} Number vSegTime", xInput, currY, CtrlH), "10")
    grpSplit.Push(edtSegTime)
    tSec := myGui.Add("Text", Format("x{} y{} w40 h{}", xInput+65, currY+3, CtrlH), "sec")
    grpSplit.Push(tSec)

    tFmt := myGui.Add("Text", Format("x240 y{} w50 h{}", currY+3, CtrlH), "Format:")
    grpSplit.Push(tFmt)
    ddlSplitFmt := DarkDropdown(myGui, 290, currY, 180, ["HLS (.m3u8 + .ts)", "DASH (.mpd + .m4s)", "MP4 Segments (.mp4)"], "SplitFormat", UpdateUI)
    grpSplit.Push(ddlSplitFmt)

    ; Encryption Controls
    currY += RowH + 5
    chkEncrypt := myGui.Add("Checkbox", Format("x{} y{} w190 h{} vEnableEncrypt c{} Background{}", xInput, currY, CtrlH, Theme.Text, Theme.Bg), "Encrypt Segments (AES-128)")
    SetDarkControl(chkEncrypt)
    chkEncrypt.OnEvent("Click", UpdateUI)
    grpSplit.Push(chkEncrypt)

    tKeyUrl := myGui.Add("Text", Format("x{} y{} w50 h{}", xInput+200, currY+3, CtrlH), "Key URL:")
    grpSplit.Push(tKeyUrl)
    edtKeyUrl := AddFlatEdit(myGui, Format("x{} y{} w130 h{} vKeyUrl", xInput+250, currY, CtrlH), "")
    grpSplit.Push(edtKeyUrl)

    ; Re-encode
    currY += RowH + 5
    chkReEncode := myGui.Add("Checkbox", Format("x{} y{} w300 h{} vReEncode c{} Background{}", xInput, currY, CtrlH, Theme.Text, Theme.Bg), "Force Re-encode (Fix Compatibility)")
    SetDarkControl(chkReEncode)
    grpSplit.Push(chkReEncode)

    tNote := myGui.Add("Text", Format("x{} y{} w{} h40 c888888 Background{}", xInput, currY+RowH, wInput, Theme.Bg), "Note: Uncheck 'Force Re-encode' for instant splitting.`nEncryption is only available for HLS format.")
    grpSplit.Push(tNote)


    ; --- JOIN SETTINGS GROUP ---
    grpJoin := []
    ; (Join settings occupy the same Y space)
    yJoinStart := yStart + RowH + 10

    tJoinNote := myGui.Add("Text", Format("x{} y{} w{} h40 c888888 Background{}", xInput, yJoinStart, wInput, Theme.Bg), "Select the Playlist file (.m3u8 or .mpd) to auto-detect chunks.`nEnsure all chunk files are in the same folder.")
    grpJoin.Push(tJoinNote)


    ; ==============================================================================
    ; FOOTER
    ; ==============================================================================
    yFooter := 260 ; Shifted down slightly for extra options
    myGui.Add("Text", Format("x0 y{} w{} h65 Background{}", yFooter-3, GuiWidth, Theme.DarkPanel), "")

    btnAction := SexyButton(myGui, 370, yFooter+10, 110, 35, "Process", StartProcess)
    btnAction.Beautify()

    btnCancel := SexyButton(myGui, 370, yFooter+10, 110, 35, "Cancel", CancelProcess)
    btnCancel.Visible := false
    btnCancel.setBorders([Theme.AltAccent,Theme.AltAccent,Theme.AltAccent,Theme.AltAccent])
    btnCancel.SetTextColour(Theme.AltAccent)

    ; Status Bar
    yStatus := yFooter + 45
    progressBar := myGui.Add("Progress", Format("x0 y{} w{} h3 c{} Background{}", yStatus, GuiWidth, Theme.Accent, Theme.DarkPanel, "Range0-100 vMyProgress"), 0)

    myGui.SetFont("s8 c" Theme.Text, "Fixedsys")
    sb := myGui.Add("Text", Format("x0 y{} w{} h20 c{} Background{} +0x200 Center vStatusText", yStatus+3, GuiWidth, Theme.Accent, Theme.StatusBg), "Idle")

    ; Initial UI State
    UpdateUI()
    myGui.Show(Format("w{} h{}", GuiWidth, yStatus+23))


    ; ==============================================================================
    ; LOGIC
    ; ==============================================================================

    UpdateUI(*) {
        saved := myGui.Submit(0)
        mode := ddlMode.Text
        isSplit := (mode == "Split Video to Stream")
        
        ; Toggle Visibility
        for c in grpSplit
            try (HasProp(c,"SetVisible") ? c.SetVisible(isSplit) : c.Visible := isSplit)
            
        for c in grpJoin
            try (HasProp(c,"SetVisible") ? c.SetVisible(!isSplit) : c.Visible := !isSplit)
            
        btnAction.SetText(isSplit ? "Split Video" : "Join Video")
        
        ; Encryption Logic
        if (isSplit) {
            isHLS := InStr(ddlSplitFmt.Text, "HLS")
            
            ; Enable/Disable Checkbox based on format
            chkEncrypt.Enabled := isHLS
            if (!isHLS && chkEncrypt.Value)
                chkEncrypt.Value := 0
                
            ; Show URL field only if encrypted
            showUrl := (isHLS && chkEncrypt.Value)
            edtKeyUrl.Visible := showUrl
            tKeyUrl.Visible := showUrl
        }
    }

    SelectInput(*) {
        mode := ddlMode.Text
        if (mode == "Split Video to Stream") {
            path := FileSelect(1, , "Select Video to Split", "Video (*.mp4; *.mkv; *.avi; *.mov; *.webm)")
        } else {
            path := FileSelect(1, , "Select Playlist to Join", "Playlist (*.m3u8; *.mpd)")
        }
        
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
            return customDialog({message: "Please select an input file first."}, darkPreset)
            
        isSplit := (saved.AppMode == "Split Video to Stream")
        
        if (isSplit)
            RunSplit(saved)
        else
            RunJoin(saved)
    }

    RunSplit(saved) {
        SplitPath(saved.InputFile, , &dir, , &nameNoExt)
        
        ; Determine Output Format
        splitFmt := saved.SplitFormat
        
        if InStr(splitFmt, "HLS") {
            ext := "m3u8"
            playlistName := nameNoExt ".m3u8"
            segmentPattern := nameNoExt "_%03d.ts"
        } else if InStr(splitFmt, "DASH") {
            ext := "mpd"
            playlistName := nameNoExt ".mpd"
            segmentPattern := "" ; FFmpeg handles dash segments automatically
        } else {
            ext := "mp4"
            playlistName := "" ; No playlist
            segmentPattern := nameNoExt "_part%03d.mp4"
        }
        
        ; Output Selection (Folder or specific name)
        outPath := FileSelect("S", dir "\" playlistName, "Save Stream/Segments", "Stream (*." ext ")")
        if !outPath
            return
            
        SplitPath(outPath, &outFileName, &outDir, &outExt, &outNameNoExt)
        
        cmdArgs := []
        cmdArgs.Push("-y", "-i", Format('"{1}"', saved.InputFile))
        
        ; Encoding Options
        if (saved.ReEncode) {
            ; H.264 / AAC for maximum compatibility
            cmdArgs.Push("-c:v", "libx264", "-c:a", "aac", "-crf", "23", "-pix_fmt", "yuv420p")
            cmdArgs.Push("-preset", "fast") 
        } else {
            cmdArgs.Push("-c", "copy")
        }
        
        ; Muxer Options
        segTime := saved.SegTime
        tempFiles := [] ; Track files to delete later
        
        if InStr(splitFmt, "HLS") {
            ; HLS: -f hls -hls_time 10 -hls_list_size 0 (keep all)
            cmdArgs.Push("-f", "hls")
            cmdArgs.Push("-hls_time", segTime)
            cmdArgs.Push("-hls_list_size", "0")
            
            ; ENCRYPTION LOGIC
            if (saved.EnableEncrypt) {
                keyFileName := outNameNoExt ".key"
                keyFilePath := outDir "\" keyFileName
                keyInfoPath := outDir "\key_info_temp.txt"
                
                ; 1. Generate 16-byte Key
                buf := Buffer(16)
                Loop 16
                    NumPut("UChar", Random(0, 255), buf, A_Index - 1)
                
                fKey := FileOpen(keyFilePath, "w")
                fKey.RawWrite(buf)
                fKey.Close()
                
                ; 2. Create Key Info File
                ; Format: KeyURI \n KeyPath \n IV(Optional)
                
                ; If user left URL blank, assume it's in same folder as playlist
                userUrl := (saved.KeyUrl != "") ? saved.KeyUrl : keyFileName
                
                ; If user typed a path like "http://site.com/", append the filename
                if (SubStr(userUrl, -1) == "/")
                    userUrl .= keyFileName
                    
                fInfo := FileOpen(keyInfoPath, "w")
                fInfo.Write(userUrl "`n" keyFilePath)
                fInfo.Close()
                
                cmdArgs.Push("-hls_key_info_file", Format('"{1}"', keyInfoPath))
                tempFiles.Push(keyInfoPath) ; Mark for deletion
            }
            
            ; Segment filename logic
            segName := outDir "\" outNameNoExt "_%03d.ts"
            cmdArgs.Push("-hls_segment_filename", Format('"{1}"', segName))
        } 
        else if InStr(splitFmt, "DASH") {
            ; DASH: -f dash -seg_duration 10
            cmdArgs.Push("-f", "dash")
            cmdArgs.Push("-seg_duration", segTime)
            cmdArgs.Push("-init_seg_name", outNameNoExt "_init.$ext$")
            cmdArgs.Push("-media_seg_name", outNameNoExt "_chunk$Number$.$ext$")
        } 
        else {
            ; MP4 Segments
            cmdArgs.Push("-f", "segment")
            cmdArgs.Push("-segment_time", segTime)
            cmdArgs.Push("-reset_timestamps", "1")
            if !InStr(outPath, "%") {
                outPath := outDir "\" outNameNoExt "_%03d.mp4"
            }
        }
        
        ExecuteJob(cmdArgs, outPath, tempFiles)
    }

    RunJoin(saved) {
        SplitPath(saved.InputFile, , &dir, , &nameNoExt)
        
        outPath := FileSelect("S", dir "\" nameNoExt "_joined.mp4", "Save Joined Video", "Video (*.mp4; *.mkv)")
        if !outPath
            return
            
        cmdArgs := []
        cmdArgs.Push("-y")
        cmdArgs.Push("-allowed_extensions", "ALL")
        cmdArgs.Push("-protocol_whitelist", "file,http,https,tcp,tls,crypto")
        cmdArgs.Push("-i", Format('"{1}"', saved.InputFile))
        cmdArgs.Push("-c", "copy")
        cmdArgs.Push("-movflags", "+faststart")
        
        ExecuteJob(cmdArgs, outPath)
    }

    ExecuteJob(cmdArgs, outputFile, cleanupFiles := []) {
        ; UI State
        btnAction.Visible := false
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
            btnAction.Visible := true
            
            ; Clean up temp files (like key info)
            for f in cleanupFiles {
                if FileExist(f)
                    FileDelete(f)
            }
            
            if (success) {
                progressBar.Value := 100
                sb.Text := " Done!"
                
                msg := "Operation Complete!"
                if InStr(outputFile, "%") 
                    msg .= "`nSegments created in folder."
                else
                    msg .= "`nOutput: " outputFile
                    
                if MsgBox(msg "`nOpen folder?", "Success", "YesNo") == "Yes" {
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
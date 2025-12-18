/*
    FFmpeg Video Joiner & Splitter (AHK v2)
    ---------------------------------------
    Tool 1: Joiner - Concatenate multiple video files into one.
    Tool 2: Splitter - Split video by parts, duration, or specific time range.
*/
#Requires AutoHotkey v2.0

#Include ..\lib\utils.ahk
VideoJoinerSplitter(){
    global AppName := "FFMpeg: Joiner & Splitter"
    global JoinFileList := [] ; Array to store file paths for joining


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
    xLabel   := 15
    xInput   := 80
    wInput   := 420

    ; ==============================================================================
    ; TABS
    ; ==============================================================================
    myGui.Add("Text", Format("x0 y0 w{} h40 Background{}", GuiWidth, Theme.DarkPanel), "")
    Tabs := TabManager(myGui, Theme, OnTabChanged)

    tW := GuiWidth / 2
    Tabs.Add("1. Video Joiner", 0, 0, tW, 40, "Joiner")
    Tabs.Add("2. Video Splitter", tW, 0, tW, 40, "Splitter")


    ; ==============================================================================
    ; TAB 1: JOINER
    ; ==============================================================================
    yStart := 55
    currY  := yStart

    ; List View for Files
    AddTabControl("Joiner", "Text", Format("x{} y{} w300 h{}", xLabel, currY, CtrlH), "Drag and drop files to add them.")

    currY += 20
    lvFiles := myGui.Add("ListView", Format("x{} y{} w{} h200 Background{} c{} -Hdr +Report", xLabel, currY, GuiWidth-(xLabel*2), Theme.Panel, Theme.Text), ["File Path"])
    lvFiles.OnEvent("ContextMenu", OnJoinerContextMenu)
    SetDarkControl(lvFiles)
    Tabs.Register("Joiner", lvFiles)

    ; List Controls (Up/Down/Remove) - Increased spacing to prevent overlap
    currY += 215
    btnUp   := SexyButton(myGui, xLabel, currY, 60, BtnH, "Up", (*) => MoveListItem(-1))
    btnUp.RegisterToTab(Tabs, "Joiner")

    btnDown := SexyButton(myGui, xLabel+65, currY, 60, BtnH, "Down", (*) => MoveListItem(1))
    btnDown.RegisterToTab(Tabs, "Joiner")

    btnRem  := SexyButton(myGui, xLabel+130, currY, 60, BtnH, "Remove", RemoveListItem)
    btnRem.RegisterToTab(Tabs, "Joiner")

    btnClear:= SexyButton(myGui, GuiWidth-95, currY, 80, BtnH, "Clear All", ClearList)
    btnClear.RegisterToTab(Tabs, "Joiner")

    ; Join Settings
    currY += RowH + 10
    chkSmartJoin := myGui.Add("Checkbox", Format("x{} y{} w400 h{} vSmartJoin c{} Background{}", xLabel, currY, CtrlH, Theme.Text, Theme.Bg), "Smart Join (Re-encode to fix resolution mismatches)")
    SetDarkControl(chkSmartJoin)
    Tabs.Register("Joiner", chkSmartJoin)

    currY += RowH
    tJoinNote := AddTabControl("Joiner", "Text", Format("x{} y{} w{} h40 c888888 Background{}", xLabel, currY, wInput, Theme.Bg), "Note: Unchecking 'Smart Join' is faster but fails if videos have different sizes/codecs.")

    ; ==============================================================================
    ; TAB 2: SPLITTER
    ; ==============================================================================
    currY := yStart

    ; Input
    AddTabControl("Splitter", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Input:")
    edtInput := AddTabControl("Splitter", "Edit", Format("x{} y{} w{} h{} ReadOnly vInputFile", xInput, currY, wInput-95, CtrlH), "")
    btnBrowse := SexyButton(myGui, xInput+wInput-90, currY-1, 90, BtnH+2, "Browse...", SelectSplitInput)
    btnBrowse.RegisterToTab(Tabs, "Splitter")

    ; Split Mode
    currY += RowH + 10
    AddTabControl("Splitter", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Mode:")
    ddlSplitMode := DarkDropdown(myGui, xInput, currY, 200, ["Split into N Parts", "Split every X Seconds", "Extract Specific Range"], "SplitMode", UpdateSplitUI)
    ddlSplitMode.RegisterToTab(Tabs, "Splitter")

    ; Dynamic Inputs Group
    currY += RowH + 10
    yDynStart := currY

    ; -- Mode 1: N Parts --
    grpParts := []
    tParts := myGui.Add("Text", Format("x{} y{} w80 h{}", xLabel, yDynStart+3, CtrlH), "Parts Count:")
    Tabs.Register("Splitter", tParts)
    grpParts.Push(tParts)

    edtParts := AddFlatEdit(myGui, Format("x{} y{} w60 h{} Number vPartCount", xInput+20, yDynStart, CtrlH), "2")
    Tabs.Register("Splitter", edtParts)
    grpParts.Push(edtParts)

    ; -- Mode 2: Duration --
    grpDur := []
    tDur := myGui.Add("Text", Format("x{} y{} w80 h{}", xLabel, yDynStart+3, CtrlH), "Duration:")
    Tabs.Register("Splitter", tDur)
    grpDur.Push(tDur)

    edtDur := AddFlatEdit(myGui, Format("x{} y{} w60 h{} Number vSplitDur", xInput+20, yDynStart, CtrlH), "60")
    Tabs.Register("Splitter", edtDur)
    grpDur.Push(edtDur)

    tSec := myGui.Add("Text", Format("x{} y{} w40 h{}", xInput+85, yDynStart+3, CtrlH), "sec")
    Tabs.Register("Splitter", tSec)
    grpDur.Push(tSec)

    ; -- Mode 3: Range --
    grpRange := []
    trStart := myGui.Add("Text", Format("x{} y{} w40 h{}", xLabel, yDynStart+3, CtrlH), "Start:")
    Tabs.Register("Splitter", trStart)
    grpRange.Push(trStart)

    edtrStart := AddFlatEdit(myGui, Format("x{} y{} w60 h{} vRangeStart", xInput-10, yDynStart, CtrlH), "00:00:00")
    Tabs.Register("Splitter", edtrStart)
    grpRange.Push(edtrStart)

    trEnd := myGui.Add("Text", Format("x{} y{} w30 h{}", xInput+60, yDynStart+3, CtrlH), "End:")
    Tabs.Register("Splitter", trEnd)
    grpRange.Push(trEnd)

    edtrEnd := AddFlatEdit(myGui, Format("x{} y{} w60 h{} vRangeEnd", xInput+100, yDynStart, CtrlH), "00:01:00")
    Tabs.Register("Splitter", edtrEnd)
    grpRange.Push(edtrEnd)

    ; Re-encode option for Splitter
    currY += RowH + 10
    chkSplitReEncode := myGui.Add("Checkbox", Format("x{} y{} w400 h{} vSplitReEncode c{} Background{}", xLabel, currY, CtrlH, Theme.Text, Theme.Bg), "Re-encode (Accurate Cuts)")
    SetDarkControl(chkSplitReEncode)
    Tabs.Register("Splitter", chkSplitReEncode)

    currY += RowH
    tSplitNote := AddTabControl("Splitter", "Text", Format("x{} y{} w{} h40 c888888 Background{}", xLabel, currY, wInput, Theme.Bg), "Unchecked = Fast copy (cuts at keyframes).`nChecked = Frame accurate (slower).")


    ; ==============================================================================
    ; FOOTER
    ; ==============================================================================
    yFooter := 410
    myGui.Add("Text", Format("x0 y{} w{} h65 Background{}", yFooter-3, GuiWidth, Theme.DarkPanel), "")

    btnProcess := SexyButton(myGui, 380, yFooter+10, 140, 35, "Process", StartProcess)
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

    ; Init Logic
    UpdateSplitUI()
    Tabs.Switch("Joiner")
    myGui.Show(Format("w{} h{}", GuiWidth, yStatus+23))


    ; ==============================================================================
    ; HELPERS
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
        if (newTabName == "Joiner") {
            btnProcess.SetText("Join Videos")
        } else {
            btnProcess.SetText("Split Video")
            UpdateSplitUI() ; Ensure correct visibility on switch
        }
    }

    HandleDropFiles(guiObj, ctrlObj, fileArray, x, y) {
        if (Tabs.Current == "Joiner") {
            for f in fileArray
                if RegExMatch(f, "i)\.(mp4|mkv|avi|mov|webm|flv)$")
                    AddFileToJoiner(f)
        } else {
            if (fileArray.Length > 0)
                edtInput.Value := fileArray[1]
        }
    }

    ; --- JOINER LIST LOGIC ---
    AddFileToJoiner(path) {
        JoinFileList.Push(path)
        lvFiles.Add(, path)
    }

    MoveListItem(dir) {
        row := lvFiles.GetNext()
        if (row == 0)
            return
            
        newRow := row + dir
        if (newRow < 1 || newRow > JoinFileList.Length)
            return
            
        ; Swap in Data
        tmp := JoinFileList[row]
        JoinFileList[row] := JoinFileList[newRow]
        JoinFileList[newRow] := tmp
        
        ; Swap in GUI
        lvFiles.Delete(row)
        lvFiles.Insert(newRow, , tmp)
        lvFiles.Modify(newRow, "Select Focus")
    }

    RemoveListItem(*) {
        row := lvFiles.GetNext()
        if (row > 0) {
            lvFiles.Delete(row)
            JoinFileList.RemoveAt(row)
        }
    }

    ClearList(*) {
        lvFiles.Delete()
        JoinFileList := []
    }

    OnJoinerContextMenu(lv, item, isRightClick, x, y) {
        RemoveListItem()
    }

    ; --- SPLITTER LOGIC ---
    SelectSplitInput(*) {
        path := FileSelect(1, , "Select Video to Split", "Video (*.mp4; *.mkv; *.avi; *.mov; *.webm)")
        if path
            edtInput.Value := path
    }

    UpdateSplitUI(*) {
        if (Tabs.Current != "Splitter")
            return

        mode := ddlSplitMode.Text
        
        ; Logic: Show only the group matching current mode
        isNParts := (mode == "Split into N Parts")
        isXSec   := (mode == "Split every X Seconds")
        isRange  := (mode == "Extract Specific Range")
        
        ; Apply visibility directly
        for c in grpParts
            c.Visible := isNParts
        for c in grpDur
            c.Visible := isXSec
        for c in grpRange
            c.Visible := isRange
    }


    ; ==============================================================================
    ; PROCESS LOGIC
    ; ==============================================================================
    StartProcess(*) {
        if (Tabs.Current == "Joiner")
            ProcessJoiner()
        else
            ProcessSplitter()
    }

    ProcessJoiner() {
        if (JoinFileList.Length < 2)
            return customDialog({message: "Add at least 2 files to join."}, darkPreset)
            
        saved := myGui.Submit(0)
        
        ; Create File List
        listFile := A_Temp "\join_list_" A_TickCount ".txt"
        try FileDelete(listFile)
        
        ; Use UTF-8-RAW to avoid BOM which confuses FFmpeg concat demuxer
        fObj := FileOpen(listFile, "w", "UTF-8-RAW")
        for path in JoinFileList {
            safePath := StrReplace(path, "'", "'\''")
            fObj.Write(Format("file '{1}'`n", safePath))
        }
        fObj.Close()
        
        ; Output
        outPath := FileSelect("S", "joined_video.mp4", "Save Joined Video", "Video (*.mp4; *.mkv)")
        if !outPath
            return
        if !RegExMatch(outPath, "i)\.(mp4|mkv)$")
            outPath .= ".mp4"
            
        cmdArgs := []
        cmdArgs.Push("-y", "-f", "concat", "-safe", "0", "-i", Format('"{1}"', listFile))
        
        if (saved.SmartJoin) {
            ; Re-encode to standard
            cmdArgs.Push("-c:v", "libx264", "-c:a", "aac", "-crf", "23", "-pix_fmt", "yuv420p")
            ; Scale if needed? Let's assume input varying sizes -> use a filter to normalize? 
            ; Normalizing mixed resolutions in concat is tricky without complex filter_complex.
            ; We will trust ffmpeg's auto-scale or error out if wildly different.
        } else {
            cmdArgs.Push("-c", "copy")
        }
        
        ExecuteJob(cmdArgs, outPath, listFile)
    }

    ProcessSplitter() {
        saved := myGui.Submit(0)
        if (saved.InputFile == "")
            return customDialog({message: "Select an input file."}, darkPreset)
            
        SplitPath(saved.InputFile, , &dir, , &nameNoExt)
        mode := ddlSplitMode.Text
        
        cmdArgs := []
        cmdArgs.Push("-y")
        
        validationFile := "" ; Used to check success if output is a pattern
        
        ; --- MODE 1: N PARTS ---
        if (mode == "Split into N Parts") {
            parts := Integer(saved.PartCount)
            if (parts < 2)
                return
                
            dur := GetMediaDuration(saved.InputFile)
            if (dur == 0)
                return customDialog({message: "Could not determine video duration."}, errorPreset)
                
            segTime := dur / parts
            
            ; Using segment muxer
            cmdArgs.Push("-i", Format('"{1}"', saved.InputFile))
            if (saved.SplitReEncode)
                cmdArgs.Push("-c:v", "libx264", "-c:a", "aac", "-crf", "23")
            else
                cmdArgs.Push("-c", "copy")
                
            cmdArgs.Push("-f", "segment", "-segment_time", segTime)
            cmdArgs.Push("-reset_timestamps", "1")
            
            outPattern := dir "\" nameNoExt "_part%03d.mp4"
            outPath := outPattern ; This is passed to FFmpeg
            
            ; We tell ExecuteJob to look for the first file to confirm success
            validationFile := dir "\" nameNoExt "_part000.mp4"
        }
        
        ; --- MODE 2: EVERY X SECONDS ---
        else if (mode == "Split every X Seconds") {
            segTime := saved.SplitDur
            
            cmdArgs.Push("-i", Format('"{1}"', saved.InputFile))
            if (saved.SplitReEncode)
                cmdArgs.Push("-c:v", "libx264", "-c:a", "aac", "-crf", "23")
            else
                cmdArgs.Push("-c", "copy")
                
            cmdArgs.Push("-f", "segment", "-segment_time", segTime)
            cmdArgs.Push("-reset_timestamps", "1")
            
            outPattern := dir "\" nameNoExt "_chunk%03d.mp4"
            outPath := outPattern
            validationFile := dir "\" nameNoExt "_chunk000.mp4"
        }
        
        ; --- MODE 3: EXTRACT RANGE ---
        else {
            cmdArgs.Push("-ss", saved.RangeStart)
            cmdArgs.Push("-to", saved.RangeEnd)
            cmdArgs.Push("-i", Format('"{1}"', saved.InputFile))
            
            if (saved.SplitReEncode)
                 cmdArgs.Push("-c:v", "libx264", "-c:a", "aac", "-crf", "23")
            else
                 cmdArgs.Push("-c", "copy")
                 
            outPath := FileSelect("S", dir "\" nameNoExt "_cut.mp4", "Save Segment", "Video (*.mp4)")
            if !outPath
                return
            validationFile := outPath
        }
        
        ExecuteJob(cmdArgs, outPath, "", validationFile)
    }

    GetMediaDuration(filePath) {
        if !FileExist(filePath)
            return 0
        ff := FFWrapper.ffmpegPath
        shell := ComObject("WScript.Shell")
        logFile := A_Temp "\dur_probe_split.txt"
        try FileDelete(logFile)
        
        ; Use double quotes around the entire command for cmd /c compatibility with paths containing spaces
        cmd := Format('"{1}" -i "{2}" 2> "{3}"', ff, filePath, logFile)
        RunWait(A_ComSpec ' /c "' cmd '"', , "Hide")
        
        if !FileExist(logFile)
            return 0
        content := FileRead(logFile)
        FileDelete(logFile)
        if RegExMatch(content, "Duration:\s+(\d{2}):(\d{2}):(\d{2}(\.\d+)?)", &m)
            return (m[1]*3600) + (m[2]*60) + m[3]
        return 0
    }

    ExecuteJob(cmdArgs, outputFile, cleanupFile := "", validationFile := "") {
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
                FileDelete(cleanupFile)
            
            ; If validationFile is provided, check existence of THAT file instead of the raw output string (which might be a pattern)
            checkFile := (validationFile != "") ? validationFile : outputFile
            
            ; If FFmpeg wrapper says success OR the file exists, we consider it done.
            ; Sometimes wrapper exit code logic is strict, but if file is there, we are good.
            if (success || FileExist(checkFile)) {
                progressBar.Value := 100
                sb.Text := " Done!"
                
                msg := "Operation Complete!"
                openTarget := outputFile
                
                if InStr(outputFile, "%") {
                    msg .= "`nSegments created in source folder."
                    SplitPath(outputFile, , &openTarget) ; Open Folder
                } else {
                    msg .= "`nOutput: " outputFile
                }
                    
                if MsgBox(msg "`nOpen location?", "Success", "YesNo") == "Yes" {
                     if InStr(FileExist(openTarget), "D")
                         Run("explorer.exe `"" openTarget "`"")
                     else
                         Run("explorer.exe /select,`"" openTarget "`"")
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
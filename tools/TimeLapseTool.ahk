/*
    FFmpeg Time-lapse Creator (AHK v2)
    ----------------------------------
    Creates videos from sequences of images.
    Features: Folder/File selection, Sorting, Resizing, FPS control.
*/

#Include ..\lib\utils.ahk
TimeLapseTool(){
    global AppName := "FFMpeg: Time-lapse tool"


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
    GuiWidth := 520
    RowH     := 32
    CtrlH    := 24
    BtnH     := 24
    xLabel   := 20
    xInput   := 90
    wInput   := 400

    ; ==============================================================================
    ; TABS
    ; ==============================================================================
    myGui.Add("Text", Format("x0 y0 w{} h40 Background{}", GuiWidth, Theme.DarkPanel), "")
    Tabs := TabManager(myGui, Theme, OnTabChanged)

    tW := GuiWidth / 2
    Tabs.Add("1. Source Images", 0, 0, tW, 40, "Source")
    Tabs.Add("2. Output Settings", tW, 0, tW, 40, "Settings")

    ; ==============================================================================
    ; TAB 1: SOURCE
    ; ==============================================================================
    yStart := 55
    currY  := yStart

    ; Input Mode
    AddTabControl("Source", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Mode:")
    ddlInputMode := DarkDropdown(myGui, xInput, currY, 160, ["Select Folder", "Select Files"], "InputMode", UpdateSourceUI)
    ddlInputMode.RegisterToTab(Tabs, "Source")

    ; Path Display
    currY += RowH + 5
    AddTabControl("Source", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Path:")
    edtPath := AddTabControl("Source", "Edit", Format("x{} y{} w{} h{} ReadOnly vInputPath", xInput, currY, wInput-100, CtrlH), "")
    btnBrowse := SexyButton(myGui, xInput+wInput-95, currY-1, 95, BtnH+2, "Browse...", SelectSource)
    btnBrowse.RegisterToTab(Tabs, "Source")

    ; Stats Display
    currY += RowH + 5
    statBg := myGui.Add("Text", Format("x{} y{} w{} h{} Background{}", xInput, currY, wInput, CtrlH, Theme.Panel), "")
    statTxt := myGui.Add("Text", Format("x{} y{} w{} h{} Backgroundtrans c888888 +0x200 vStatText", xInput+5, currY, wInput-10, CtrlH), "No images selected.")
    Tabs.Register("Source", statBg)
    Tabs.Register("Source", statTxt)

    ; Sorting
    currY += RowH + 10
    AddTabControl("Source", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Sort By:")
    ddlSort := DarkDropdown(myGui, xInput, currY, 200, ["Name (A-Z)", "Name (Z-A)", "Date Modified (Oldest First)", "Date Modified (Newest First)"], "SortMode")
    ddlSort.RegisterToTab(Tabs, "Source")

    txtSortNote := AddTabControl("Source", "Text", Format("x{} y{} w{} h40 c888888 Background{}", xInput, currY+RowH+5, wInput, Theme.Bg), "Sorting is crucial for Time-lapses. Use 'Date Modified' if your file names reset or are unordered.")


    ; ==============================================================================
    ; TAB 2: SETTINGS
    ; ==============================================================================
    currY := yStart

    ; Framerate
    AddTabControl("Settings", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "FPS:")
    ddlFPS := DarkDropdown(myGui, xInput, currY, 200, ["60 fps (Smooth)", "30 fps (Standard)", "24 fps (Cinematic)", "10 fps (Stop Motion)", "1 fps (Slideshow)", "0.5 fps (Slow Slideshow)"], "TargetFPS")
    ddlFPS.RegisterToTab(Tabs, "Settings")

    ; Resolution
    currY += RowH + 5
    AddTabControl("Settings", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Resize:")
    ddlRes := DarkDropdown(myGui, xInput, currY, 200, ["Original Size", "3840x2160 (4K)", "1920x1080 (1080p)", "1280x720 (720p)", "1080x1920 (Vertical HD)", "1080x1080 (Square)"], "OutputRes")
    ddlRes.RegisterToTab(Tabs, "Settings")

    ; Format
    currY += RowH + 5
    AddTabControl("Settings", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Format:")
    ddlFmt := DarkDropdown(myGui, xInput, currY, 200, ["MP4 (H.264)", "WebM (VP9)", "GIF (Animated)", "ProRes (Editing)"], "OutputFmt")
    ddlFmt.RegisterToTab(Tabs, "Settings")

    ; Quality
    currY += RowH + 5
    AddTabControl("Settings", "Text", Format("x{} y{} w60 h{}", xLabel, currY+3, CtrlH), "Quality:")
    ddlQual := DarkDropdown(myGui, xInput, currY, 200, ["High (CRF 18)", "Medium (CRF 23)", "Low Size (CRF 28)"], "OutputQual")
    ddlQual.RegisterToTab(Tabs, "Settings")


    ; ==============================================================================
    ; FOOTER
    ; ==============================================================================
    yFooter := 250
    myGui.Add("Text", Format("x0 y{} w{} h65 Background{}", yFooter-3, GuiWidth, Theme.DarkPanel), "")

    btnCreate := SexyButton(myGui, 380, yFooter+10, 120, 35, "Create Video", StartProcess)
    btnCreate.Beautify()

    btnCancel := SexyButton(myGui, 380, yFooter+10, 120, 35, "Cancel", CancelProcess)
    btnCancel.Visible := false
    btnCancel.setBorders([Theme.AltAccent,Theme.AltAccent,Theme.AltAccent,Theme.AltAccent])
    btnCancel.SetTextColour(Theme.AltAccent)

    ; Status Bar
    yStatus := yFooter + 45
    progressBar := myGui.Add("Progress", Format("x0 y{} w{} h3 c{} Background{}", yStatus, GuiWidth, Theme.Accent, Theme.DarkPanel, "Range0-100 vMyProgress"), 0)

    myGui.SetFont("s8 c" Theme.Text, "Fixedsys")
    sb := myGui.Add("Text", Format("x0 y{} w{} h20 c{} Background{} +0x200 Center vStatusText", yStatus+3, GuiWidth, Theme.Accent, Theme.StatusBg), "Idle")

    ; Init
    Tabs.Switch("Source")
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

    ; ==============================================================================
    ; LOGIC
    ; ==============================================================================

    OnTabChanged(newTab) {
        if (newTab == "Settings" && edtPath.Value != "") {
            ; Update count if needed, logic is mostly in Source selection
        }
    }

    UpdateSourceUI(*) {
        ; Clear input when switching modes to avoid confusion
        edtPath.Value := ""
        statTxt.Text := "No images selected."
    }

    SelectSource(*) {
        mode := ddlInputMode.Text
        
        if (mode == "Select Folder") {
            sel := DirSelect(, , "Select Folder with Images")
            if (sel) {
                edtPath.Value := sel
                CountImagesInFolder(sel)
            }
        } else {
            sel := FileSelect("M", , "Select Images", "Images (*.jpg; *.jpeg; *.png; *.bmp; *.tif; *.tiff; *.webp)")
            if (sel) {
                ; FileSelect M returns Array if multiple, or String if one
                if IsObject(sel) {
                    edtPath.Value := "Multiple Files Selected"
                    statTxt.Text := Format("{} images selected.", sel.Length)
                    ; Store array globally for processing
                    global SelectedFilesArray := sel
                } else {
                    edtPath.Value := sel
                    statTxt.Text := "1 image selected."
                    global SelectedFilesArray := [sel]
                }
            }
        }
    }

    HandleDropFiles(guiObj, ctrlObj, fileArray, x, y) {
        if (fileArray.Length == 0)
            return

        firstFile := fileArray[1]
        attrib := FileGetAttrib(firstFile)
        
        if InStr(attrib, "D") {
            ; It's a folder
            ddlInputMode.Text := "Select Folder"
            edtPath.Value := firstFile
            CountImagesInFolder(firstFile)
        } else {
            ; Files
            ddlInputMode.Text := "Select Files"
            edtPath.Value := (fileArray.Length > 1) ? "Multiple Files Selected" : firstFile
            statTxt.Text := Format("{} images selected.", fileArray.Length)
            global SelectedFilesArray := fileArray
        }
        Tabs.Switch("Source")
    }

    CountImagesInFolder(dirPath) {
        count := 0
        Loop Files dirPath "\*.*" {
            if RegExMatch(A_LoopFileExt, "i)^(jpg|jpeg|png|bmp|tif|tiff|webp)$")
                count++
        }
        statTxt.Text := Format("Found {} images in folder.", count)
    }

    ; ==============================================================================
    ; PROCESSING
    ; ==============================================================================

    StartProcess(*) {
        saved := myGui.Submit(0)
        mode := ddlInputMode.Text
        
        ; 1. Gather File List
        imageList := []
        
        if (mode == "Select Folder") {
            if (saved.InputPath == "")
                return customDialog({message: "Please select a folder."}, darkPreset)
                
            Loop Files saved.InputPath "\*.*" {
                if RegExMatch(A_LoopFileExt, "i)^(jpg|jpeg|png|bmp|tif|tiff|webp)$") {
                    imageList.Push({path: A_LoopFilePath, time: FileGetTime(A_LoopFilePath, "M"), name: A_LoopFileName})
                }
            }
        } else {
            if (!IsSet(SelectedFilesArray) || SelectedFilesArray.Length == 0)
                 return customDialog({message: "Please select files."}, darkPreset)
                 
            for f in SelectedFilesArray {
                imageList.Push({path: f, time: FileGetTime(f, "M"), name: f}) ; Name might be full path here, acceptable for sort
            }
        }
        
        if (imageList.Length == 0)
            return customDialog({message: "No images found!"}, errorPreset)

        ; 2. Sort List
        SortImages(imageList, saved.SortMode)
        
        ; 3. Generate Concat File
        concatFile := A_Temp "\timelapse_list_" A_TickCount ".txt"
        try FileDelete(concatFile)
        
        ; Calculate Duration per frame based on FPS
        ; e.g. 30fps = 1/30 = 0.0333...
        fpsVal := 30
        if RegExMatch(saved.TargetFPS, "^([\d\.]+)", &m)
            fpsVal := Float(m[1])
            
        dur := 1.0 / fpsVal
        
        fObj := FileOpen(concatFile, "w", "UTF-8")
        for img in imageList {
            safePath := StrReplace(img.path, "'", "'\''") ; Escape single quotes for ffmpeg
            fObj.Write(Format("file '{1}'`nduration {2:.6f}`n", safePath, dur))
        }
        ; Repeat last frame to prevent cutoff
        if (imageList.Length > 0) {
            safePath := StrReplace(imageList[imageList.Length].path, "'", "'\''")
            fObj.Write(Format("file '{1}'`nduration {2:.6f}`n", safePath, dur))
        }
        fObj.Close()
        
        ; 4. Determine Output
        outExt := "mp4"
        if InStr(saved.OutputFmt, "GIF")
            outExt := "gif"
        else if InStr(saved.OutputFmt, "WebM")
            outExt := "webm"
        else if InStr(saved.OutputFmt, "ProRes")
            outExt := "mov"
            
        saveName := "timelapse." outExt
        outputFile := FileSelect("S", saveName, "Save Video", "Video (*." outExt ")")
        if !outputFile
            return
            
        if !RegExMatch(outputFile, "\." outExt "$")
            outputFile .= "." outExt
            
        ; 5. Build Command
        cmdArgs := []
        cmdArgs.Push("-y")
        cmdArgs.Push("-f", "concat", "-safe", "0", "-i", Format('"{1}"', concatFile))
        
        ; Filters (FPS enforcement + Scale)
        vf := "fps=" fpsVal
        
        if (saved.OutputRes != "Original Size") {
            resMap := Map(
                "3840x2160", "3840:2160",
                "1920x1080", "1920:1080",
                "1280x720", "1280:720",
                "1080x1920", "1080:1920",
                "1080x1080", "1080:1080"
            )
            ; Extract resolution key from string
            if RegExMatch(saved.OutputRes, "(\d+x\d+)", &rm) {
                scale := resMap.Has(rm[1]) ? resMap[rm[1]] : "1920:1080"
                ; Scale logic: fit within box, keep aspect ratio, pad with black
                vf .= ",scale=" scale ":force_original_aspect_ratio=decrease,pad=" scale ":(ow-iw)/2:(oh-ih)/2"
            }
        } else {
            ; Even if original size, ensure even dimensions for encoding (yuv420p requirement usually)
            vf .= ",scale=trunc(iw/2)*2:trunc(ih/2)*2"
        }
        
        cmdArgs.Push("-vf", Format('"{1}"', vf))
        
        ; Encoder Settings
        if (outExt == "gif") {
            ; GIF specific (generate palette for better quality)
            ; For simplicity in this wrapper, we use simple mapping or basic palette gen
            ; High quality GIF usually requires 2-pass (palettegen -> paletteuse). 
            ; We'll stick to a simple filter chain for single-pass roughly good quality
            cmdArgs.Pop() ; Remove prev vf
            vfGif := vf ",split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse"
            cmdArgs.Push("-vf", Format('"{1}"', vfGif))
        } 
        else if (outExt == "mov" && InStr(saved.OutputFmt, "ProRes")) {
            cmdArgs.Push("-c:v", "prores_ks", "-profile:v", "3")
        }
        else {
            ; MP4 / WebM
            if (outExt == "webm")
                cmdArgs.Push("-c:v", "libvpx-vp9", "-b:v", "0")
            else
                cmdArgs.Push("-c:v", "libx264", "-pix_fmt", "yuv420p")
                
            ; CRF
            crf := 23
            if InStr(saved.OutputQual, "High")
                crf := 18
            else if InStr(saved.OutputQual, "Low")
                crf := 28
            cmdArgs.Push("-crf", crf)
        }

        ; Execute
        ExecuteJob(cmdArgs, outputFile, concatFile)
    }

    ; Extending Array for Sorting (Monkey-patching or just helper)
    ; Since we can't easily monkey-patch, let's rewrite the SortImages function to be standalone
    ; Re-definition of SortImages to actually work in AHK v2 without prototypes
    SortImages(arr, mode) {
        str := ""
        delim := "`n"
        
        ; We need to pack the data into a sortable string
        ; Format: SortKey|Index
        for i, obj in arr {
            key := InStr(mode, "Name") ? obj.name : obj.time
            str .= key "|" i . delim
        }
        
        ; Determine Sort Options
        opts := ""
        if InStr(mode, "Date") || InStr(mode, "Numeric") ; Time is numeric-ish string
            opts .= " N" ; Numeric sort usually better for timestamps? No, timestamps are fixed length strings YYYYMMDD... String sort works.
            
        if InStr(mode, "Z-A") || InStr(mode, "Newest")
            opts .= " R" ; Reverse
            
        sortedStr := Sort(str, opts)
        
        newArr := []
        Loop Parse, sortedStr, "`n" {
            if (A_LoopField == "")
                continue
            parts := StrSplit(A_LoopField, "|")
            if (parts.Length >= 2) {
                oldIndex := Integer(parts[parts.Length]) ; Last part is index
                newArr.Push(arr[oldIndex])
            }
        }
        
        ; Swap contents
        arr.Length := 0
        for item in newArr
            arr.Push(item)
    }


    ExecuteJob(cmdArgs, outputFile, concatFile) {
        btnCreate.Visible := false
        btnCancel.Visible := true
        sb.Text := " Rendering..."
        progressBar.Value := 0

        OnProgress(percent, text) {
            if (sb.Text != "Cancelling...") {
                progressBar.Value := percent
                sb.Text := text
            }
        }

        OnFinish(success, result) {
            btnCancel.Visible := false
            btnCreate.Visible := true
            
            try FileDelete(concatFile)
            
            if (success) {
                progressBar.Value := 100
                sb.Text := " Done!"
                if MsgBox("Time-lapse Created!`nOpen output folder?", "Success", "YesNo") == "Yes" {
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
        customDialog({title:"FFmpeg Error Log",message:"Render Failed!`nFull log output:",detail: logContent}, criticalErrorDetailPreset)
    }
}
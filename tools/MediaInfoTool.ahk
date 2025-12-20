
/*
    FFmpeg Media Inspector (AHK v2)
    -------------------------------
    Analyzes media files using ffprobe and displays detailed metadata.
*/

#Include ..\lib\utils.ahk
MediaInfoTool() {
    global AppName := "FFMpeg: Media Inspector"
    
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

    GuiWidth := 600
    GuiHeight := 500

    ; --- HEADER ---
    myGui.Add("Text", Format("x0 y0 w{} h50 Background{}", GuiWidth, Theme.DarkPanel), "")
    
    ; Input
    myGui.SetFont("s9")
    myGui.Add("Text", Format("x15 y15 w40 h24 +0x200 Background{}", Theme.DarkPanel), "File:")
    edtInput := AddFlatEdit(myGui, "x60 y12 w420 h26 ReadOnly vInputFile")
    btnBrowse := SexyButton(myGui, 490, 11, 100, 28, "Browse...", SelectInput)

    ; --- TREE VIEW FOR METADATA ---
    yList := 60
    hList := GuiHeight - 90
    
    tv := myGui.Add("TreeView", Format("x15 y{} w{} h{} Background{} c{} -Lines", yList, GuiWidth-30, hList, Theme.Panel, Theme.Text))
    SetDarkControl(tv)

    ; --- STATUS BAR ---
    yStatus := GuiHeight - 25
    myGui.Add("Text", Format("x0 y{} w{} h25 Background{}", yStatus, GuiWidth, Theme.DarkPanel), "")
    sb := myGui.Add("Text", Format("x10 y{} w{} h25 +0x200 BackgroundTrans c888888", yStatus, GuiWidth-20), "Ready.")

    myGui.Show(Format("w{} h{}", GuiWidth, GuiHeight))

    ; ==============================================================================
    ; LOGIC
    ; ==============================================================================
    SelectInput(*) {
        path := FileSelect(1, , "Select Media File", "Media (*.mp4; *.mkv; *.avi; *.mov; *.webm; *.mp3; *.wav; *.flac; *.jpg; *.png)")
        if path {
            edtInput.Value := path
            AnalyzeFile(path)
        }
    }

    HandleDropFiles(guiObj, ctrlObj, fileArray, x, y) {
        if (fileArray.Length > 0) {
            edtInput.Value := fileArray[1]
            AnalyzeFile(fileArray[1])
        }
    }

    AnalyzeFile(filePath) {
        tv.Delete()
        sb.Text := "Probing file..."
        
        try {
            data := FFWrapper.Probe(filePath)
            sb.Text := "Done."
            
            PopulateTree(filePath, data)
        } catch as e {
            sb.Text := "Error."
            tv.Add("Error probing file: " e.Message)
        }
    }

    PopulateTree(filename, data) {
        root := tv.Add(filename, 0, "Expand")
        
        ; FORMAT INFO
        if (data.HasOwnProp("format")) {
            fmt := data.format
            
            ; Clean up basic stats
            dur := fmt.Has("duration") ? FormatSeconds(fmt["duration"]) : "N/A"
            sizeMB := fmt.Has("size") ? Format("{:.2f} MB", fmt["size"] / 1024 / 1024) : "N/A"
            bitrate := fmt.Has("bit_rate") ? Format("{:.0f} kbps", fmt["bit_rate"] / 1000) : "N/A"
            container := fmt.Has("format_long_name") ? fmt["format_long_name"] : (fmt.Has("format_name") ? fmt["format_name"] : "Unknown")
            
            fNode := tv.Add("General (Container)", root, "Expand")
            tv.Add("Format: " container, fNode)
            tv.Add("Duration: " dur, fNode)
            tv.Add("Size: " sizeMB, fNode)
            tv.Add("Bitrate: " bitrate, fNode)
            
            ; Add tags if any
            AddTags(fmt, fNode)
        }
        
        ; STREAMS
        if (data.HasOwnProp("streams")) {
            for i, s in data.streams {
                type := s.Has("codec_type") ? s["codec_type"] : "unknown"
                name := "Stream #" i " (" type ")"
                
                ; Add descriptive info to title if possible
                if (type == "video") {
                    res := (s.Has("width") && s.Has("height")) ? s["width"] "x" s["height"] : ""
                    codec := s.Has("codec_name") ? s["codec_name"] : ""
                    name := "Video #" i " [" codec " " res "]"
                } else if (type == "audio") {
                    codec := s.Has("codec_name") ? s["codec_name"] : ""
                    lang := (s.Has("tags") && s.Has("tags_language")) ? s["tags_language"] : "" ; specialized check below
                    name := "Audio #" i " [" codec "]"
                } else if (type == "subtitle") {
                    codec := s.Has("codec_name") ? s["codec_name"] : ""
                    name := "Subtitle #" i " [" codec "]"
                }
                
                sNode := tv.Add(name, root, "Expand")
                
                for k, v in s {
                    if (k == "tags") ; Tags are handled specially
                        continue 
                    tv.Add(k ": " v, sNode)
                }
                
                AddTags(s, sNode)
            }
        }
    }
    
    AddTags(obj, parentNode) {
        if (obj.Has("TAG:language")) {
             tv.Add("Language: " obj["TAG:language"], parentNode)
        }
        if (obj.Has("TAG:title")) {
             tv.Add("Title: " obj["TAG:title"], parentNode)
        }
        
        ; Generic tags dump if needed, but usually messy. 
        ; Probe returns tags as flat keys like "TAG:creation_time" due to our ffprobe command args.
        hasTags := false
        tagNode := 0
        
        for k, v in obj {
            if InStr(k, "TAG:") {
                if (!hasTags) {
                    tagNode := tv.Add("Metadata Tags", parentNode)
                    hasTags := true
                }
                cleanKey := SubStr(k, 5) ; Remove TAG:
                tv.Add(cleanKey ": " v, tagNode)
            }
        }
    }
}

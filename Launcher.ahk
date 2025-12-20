
/*
    FFmpeg Tool Suite Launcher (AHK v2)
    -----------------------------------
    Central hub to launch all tools in the suite.
    Organized by category with descriptions.
*/
#Requires AutoHotkey v2.0
#SingleInstance Off

; Import Helper Libraries
isGUI := true
#Include lib\utils.ahk



global FFWrapper := ""

; Initialize FFmpeg Wrapper
try {
    FFWrapper := FFmpegJob()
} catch as e {
    customDialog({
        title: "FFmpeg Missing",
        message: e.Message,
        noAltF4: true,
    }, errorPreset)
    ExitApp()
}


#Include tools\AudioTool.ahk
#Include tools\AudioToVideo.ahk
#Include tools\ContactSheetMaker.ahk
#Include tools\FilterTool.ahk
#Include tools\RecognitionTool.ahk
#Include tools\MotionInterpolationTool.ahk
#Include tools\SimpleConverter.ahk
#Include tools\StreamChunker.ahk
#Include tools\SubtitleTool.ahk
#Include tools\TimeLapseTool.ahk
#Include tools\VideoJoinerSplitter.ahk
#Include tools\StabilizerTool.ahk
#Include tools\ScreenRecorder.ahk
#Include tools\WatermarkTool.ahk
#Include tools\MediaInfoTool.ahk
#Include tools\CropTool.ahk
#Include tools\MusicVisualizer.ahk

global AppName := "FFMpeg Tool Suite"

; ==============================================================================
; TOOL DEFINITIONS
; ==============================================================================
; Define tools manually to allow for custom grouping, descriptions, and 
; compilation support (no reliance on Loop Files).

global ToolGroups := Map()

ToolGroups["Best"] := [
    {name: "Crop Tool",           file: "CropTool",           desc: "Visually crop video and optionally fit/pad to a new frame size."},
    {name: "Watermark Tool",      file: "WatermarkTool",         desc: "Add logos or text overlays to your videos."},
    {name: "Contact Sheets",      file: "ContactSheetMaker",  desc: "Generate thumbnail grids, preview strips, and burst captures."},
    {name: "Audio to Video",      file: "AudioToVideo",    desc: "Create video files from audio tracks using static images or solid colors."},
    {name: "Universal Converter", file: "SimpleConverter", desc: "Convert, resize, trim, change speed, and adjust quality for any video/audio."},
],
ToolGroups["Converters"] := [
    {name: "Universal Converter", file: "SimpleConverter", desc: "Convert, resize, trim, change speed, and adjust quality for any video/audio."},
    {name: "Joiner && Splitter",   file: "VideoJoinerSplitter",desc: "Merge multiple files or split videos by duration/parts."},
    {name: "Stream Chunker",      file: "StreamChunker",      desc: "Segment videos for HLS/DASH streaming protocols."}
]

ToolGroups["Editors"] := [
    {name: "Crop Tool",           file: "CropTool",           desc: "Visually crop video and optionally fit/pad to a new frame size."},
    {name: "Visual Filters",      file: "FilterTool",         desc: "Apply restoration filters: Denoise, Deinterlace, Sharpen, and Color adjustments."},
    {name: "Stabilizer Tool",      file: "StabilizerTool",         desc: "Video Stabilizer; applies smoothing and zoom."},
    {name: "Motion Interpolation",      file: "MotionInterpolationTool",        desc: "Smoothens video by generating new frames using Optical Flow."},
    {name: "Watermark Tool",      file: "WatermarkTool",         desc: "Add logos or text overlays to your videos."}
]

ToolGroups["Creators"] := [
    {name: "Music Visualizer",    file: "MusicVisualizer",  desc: "Turn audio into video with waveform and spectrum visualizations."},
    {name: "Screen Recorder",      file: "ScreenRecorder",         desc: "Screen Recorder && Timelapse Tool."},
    {name: "Time-Lapse Creator",  file: "TimeLapseTool",   desc: "Stitch image sequences into high-quality video files."},
    {name: "Audio to Video",      file: "AudioToVideo",    desc: "Create video files from audio tracks using static images or solid colors."},
    {name: "Contact Sheets",      file: "ContactSheetMaker",  desc: "Generate thumbnail grids, preview strips, and burst captures."}
]

ToolGroups["Utilities"] := [
    {name: "Media Inspector",     file: "MediaInfoTool",      desc: "Detailed metadata analysis of video, audio, and streams."},
    {name: "Audio Manager",       file: "AudioTool",          desc: "Extract, replace, or mix audio tracks within a video container."},
    {name: "Subtitle Manager",    file: "SubtitleTool",       desc: "Convert formats, extract tracks, or burn-in subtitles hardcoded."},
    {name: "Auto-Analysis",       file: "RecognitionTool",    desc: "Detect black frames, silence, freeze frames, and scene changes."}
]

; ==============================================================================
; CLI DIRECT LAUNCH
; ==============================================================================
if (A_Args.Length > 0) {
    toolArg := A_Args[1]
    
    ; Determine if valid tool request
    matched := false
    Switch toolArg, "Off" { ; Case-insensitive switch
        Case "AudioTool", "Audio":               AudioTool(), matched := true
        Case "AudioToVideo", "AudioVid":         AudioToVideo(), matched := true
        Case "ContactSheetMaker", "Contact":     ContactSheetMaker(), matched := true
        Case "FilterTool", "Filter":             FilterTool(), matched := true
        Case "RecognitionTool", "Recog":         RecognitionTool(), matched := true
        Case "SimpleConverter", "Converter":     SimpleConverter(), matched := true
        Case "MotionInterpolationTool", "Motion": MotionInterpolationTool(), matched := true
        Case "StreamChunker", "Stream":          StreamChunker(), matched := true
        Case "SubtitleTool", "Subtitle":         SubtitleTool(), matched := true
        Case "TimeLapseTool", "TimeLapse":       TimeLapseTool(), matched := true
        Case "VideoJoinerSplitter", "Joiner":    VideoJoinerSplitter(), matched := true
        Case "StabilizerTool", "Stabilizer":     StabilizerTool(), matched := true
        Case "ScreenRecorder", "Recorder":       ScreenRecorder(), matched := true
        Case "WatermarkTool", "Watermark":       WatermarkTool(), matched := true
        Case "MediaInfoTool", "MediaInfo":       MediaInfoTool(), matched := true
        Case "CropTool", "Crop":                 CropTool(), matched := true
        Case "MusicVisualizer", "Visualizer":    MusicVisualizer(), matched := true
    }
    
    if (matched)
        return ; Skip creating the main launcher GUI
}


LauncherGUI(){
    ; ==============================================================================
    ; GUI CREATION
    ; ==============================================================================
    myGui := Gui("-Resize -MaximizeBox", AppName)
    myGui.SetFont("s9 c" Theme.Text, "Segoe UI")
    myGui.BackColor := Theme.Bg

    InitWindowUtils(myGui)
    myGui.OnEvent("Close", (*) => myGui.Destroy())

    GuiWidth := 650
    GuiHeight := 360

    ; --- HEADER ---
    ;myGui.Add("Text", Format("x0 y0 w{} h50 Background{}", GuiWidth, Theme.DarkPanel), "")
    ;myGui.SetFont("s14 w600")
    ;myGui.Add("Text", Format("x20 y0 w{} h50 +0x200 BackgroundTrans c{}", GuiWidth, Theme.Accent), "FFmpeg Suite")
    myGui.SetFont("s9 w400")

    ; --- TABS ---
    Tabs := TabManager(myGui, Theme)

    tW := GuiWidth / 5
    Tabs.Add("Most Useful", 0,     0, tW, 40, "Best")
    Tabs.Add("Converters", tW,     0, tW, 40, "Converters")
    Tabs.Add("Editors",    tW*2,    0, tW, 40, "Editors")
    Tabs.Add("Creators",   tW*3,  0, tW, 40, "Creators")
    Tabs.Add("Utilities",  tW*4,  0, tW, 40, "Utilities")

    ; Render Groups
    RenderGroup("Best")
    RenderGroup("Converters")
    RenderGroup("Editors")
    RenderGroup("Creators")
    RenderGroup("Utilities")

    ; --- FOOTER ---
    yFooter := GuiHeight - 30
    myGui.Add("Text", Format("x0 y{} w{} h30 Background{}", yFooter, GuiWidth, Theme.DarkPanel), "")
    myGui.Add("Text", Format("x0 y{} w{} h30 BackgroundTrans c888888 Center +0x200", yFooter, GuiWidth), "v2.2 - Suite Launcher")

    Tabs.Switch("Best")
    myGui.Show(Format("w{} h{}", GuiWidth, GuiHeight))
    
    
    ; ==============================================================================
    ; RENDERING LOGIC
    ; ==============================================================================
    RenderGroup(groupName) {
        list := ToolGroups[groupName]
        currY := groupName=="Converters" ? 60 : 60 ; Start Y below tabs
        
        for tool in list {
            ; Button
            btn := SexyButton(myGui, 30, currY, 160, 36, tool.name, LaunchTool.Bind(tool.file))
            Tabs.Register(groupName, btn)
            
            ; Description
            txtDesc := myGui.Add("Text", Format("x210 y{} w500 h40 c888888 BackgroundTrans", currY+2), tool.desc)
            Tabs.Register(groupName, txtDesc)
            
            ; Divider line (subtle)
            div := myGui.Add("Text", Format("x30 y{} w680 h1 Background{}", currY+45, Theme.Panel), "")
            Tabs.Register(groupName, div)
            
            currY += 55
        }
    }
    
    return myGui
}

launcher := LauncherGUI()


LaunchTool(tool, *) {

    if (tool=="AudioTool")
        AudioTool()
    
    else if (tool=="AudioToVideo")
        AudioToVideo()
    
    else if (tool=="ContactSheetMaker")
        ContactSheetMaker()
    
    else if (tool=="FilterTool")
        FilterTool()
    
    else if (tool=="RecognitionTool")
        RecognitionTool()
    
    else if (tool=="SimpleConverter")
        SimpleConverter()
    
    else if (tool=="MotionInterpolationTool")
        MotionInterpolationTool()
    
    else if (tool=="StreamChunker")
        StreamChunker()
    
    else if (tool=="SubtitleTool")
        SubtitleTool()
    
    else if (tool=="TimeLapseTool")
        TimeLapseTool()
    
    else if (tool=="VideoJoinerSplitter")
        VideoJoinerSplitter()
    
    else if (tool=="StabilizerTool")
        StabilizerTool()
    
    else if (tool=="ScreenRecorder")
        ScreenRecorder()
    
    else if (tool=="WatermarkTool")
        WatermarkTool()

    else if (tool=="MediaInfoTool")
        MediaInfoTool()

    else if (tool=="CropTool")
        CropTool()

    else if (tool=="MusicVisualizer")
        MusicVisualizer()
        
}
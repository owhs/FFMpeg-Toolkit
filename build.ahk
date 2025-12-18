#Requires AutoHotkey v2.0

;#region        GUI
    global MyGui := Gui()

    ; --- GUI Configuration ---
    MyGui.Title := "MMpeg Toolkit Build Process"
    MyGui.SetFont("s10", "Segoe UI")
    MyGui.Opt("+AlwaysOnTop -SysMenu +ToolWindow +OwnDialogs") ; Always on top, no system menu, simple tool window style
    MyGui.OnEvent("Close", (*) => ExitApp())

    ; --- Add GUI Controls ---

    MyGui.Add("Text", "x10 y0", "Status:")
    global g_ChkClear   := MyGui.Add("Checkbox", "x20 yp+20 Disabled", "1. Clearing build directory")
    global g_ChkCompile := MyGui.Add("Checkbox", "x20 yp+20 Disabled", "2. Compilation")
    global g_ChkMove    := MyGui.Add("Checkbox", "x20 yp+20 Disabled", "3. Final move")
    global g_ChkShort    := MyGui.Add("Checkbox", "x20 yp+20 Disabled", "4. Make shortcuts")

    ; --- Display the GUI ---
    MyGui.Show("x10 y10 w250 NoActivate")

    Step_Clear() {
        g_ChkClear.Enabled := True      ; Enable the control
        g_ChkClear.Value := 1           ; Check the box (1=checked, 0=unchecked)
        g_ChkClear.Enabled := False     ; Disable it again
        ;Sleep 200
    }

    Step_Compile() {
        g_ChkCompile.Enabled := True
        g_ChkCompile.Value := 1
        g_ChkCompile.Enabled := False
        ;Sleep 200
    }

    Step_Move() {
        g_ChkMove.Enabled := True
        g_ChkMove.Value := 1
        g_ChkMove.Enabled := False
        ;Sleep 200
    }
    
    Step_Short() {
        g_ChkShort.Enabled := True
        g_ChkShort.Value := 1
        g_ChkShort.Enabled := False
        ;Sleep 200
    }
;#endregion

;#region        CONFIG
    scriptDir := A_ScriptDir
    buildDir := scriptDir . "\build"
    srcFile := scriptDir . "\launcher.ahk"
    exeName := "FFMpeg Toolkit.exe"
    tempExe := scriptDir . "\" . exeName
    finalExe := buildDir . "\tool\" . exeName
    ahk2exe := "C:\Apps\AHK\Ahk2Exe.exe"
    baseExe := EnvGet("ProgramFiles") . "\AutoHotkey\v2\AutoHotkey64.exe"
    upxPatcher := "C:\Apps\AHK\UPX-Patcher.exe"
;#endregion

;#region        CLEAR BUILD DIR
    Clear:
    if !DirExist(buildDir)
    {
        DirCreate(buildDir)
    }
    else
    {   
        Loop Files, buildDir . "\*", "F"
        {
            try {
                FileDelete(A_LoopFilePath)
            } catch Error as e {
                fail := MsgBox("Error deleting file:`n     " A_LoopFilePath "`n`nReason:`n     "  e.Message "`n`n The build will now exit.", "Build Failed!", "Iconx 0x5 0x40000")
                if (fail=="Retry")
                    goto Clear
                ExitApp
            }
        }
    }
    if !DirExist(buildDir . "\tool")
    {
        DirCreate(buildDir . "\tool")
    }
    Step_Clear()
;#endregion

;#region        COMPILE EXE [AHK2EXE]
    if !FileExist(ahk2exe)
    {
        MsgBox("ERROR: Missing Ahk2Exe.exe. Please place it in the parent directory.")
        ExitApp
    }
    if !FileExist(baseExe)
    {
        MsgBox("ERROR: Missing Base AutoHotkey64.exe. Please ensure AHK v2 is installed at:`n" . baseExe)
        ExitApp
    }
    cmd := Format('"{1}" /in "{2}" /out "{3}" /base "{4}"', ahk2exe, srcFile, tempExe, baseExe)
    RunWait(cmd,, "Hide")
    Step_Compile()
;#endregion


;#region        FINAL MOVE:
    if FileExist(tempExe)
    {
        FileMove(tempExe, finalExe, true) ; 
        Step_Move()
        
        FileCreateShortcut(finalExe,buildDir . "\Launcher.lnk",,"","")
        FileCreateShortcut(finalExe,buildDir . "\AudioTool.lnk",,"AudioTool","")
        FileCreateShortcut(finalExe,buildDir . "\AudioToVideo.lnk",,"AudioToVideo","")
        FileCreateShortcut(finalExe,buildDir . "\ContactSheetMaker.lnk",,"ContactSheetMaker","")
        FileCreateShortcut(finalExe,buildDir . "\FilterTool.lnk",,"FilterTool","")
        FileCreateShortcut(finalExe,buildDir . "\MediaInfoTool.lnk",,"MediaInfoTool","")
        FileCreateShortcut(finalExe,buildDir . "\MotionInterpolationTool.lnk",,"MotionInterpolationTool","")
        FileCreateShortcut(finalExe,buildDir . "\RecognitionTool.lnk",,"RecognitionTool","")
        FileCreateShortcut(finalExe,buildDir . "\ScreenRecorder.lnk",,"ScreenRecorder","")
        FileCreateShortcut(finalExe,buildDir . "\SimpleConverter.lnk",,"SimpleConverter","")
        FileCreateShortcut(finalExe,buildDir . "\StabilizerTool.lnk",,"StabilizerTool","")
        FileCreateShortcut(finalExe,buildDir . "\StreamChunker.lnk",,"StreamChunker","")
        FileCreateShortcut(finalExe,buildDir . "\SubtitleTool.lnk",,"SubtitleTool","")
        FileCreateShortcut(finalExe,buildDir . "\TimeLapseTool.lnk",,"TimeLapseTool","")
        FileCreateShortcut(finalExe,buildDir . "\VideoJoinerSplitter.lnk",,"VideoJoinerSplitter","")
        FileCreateShortcut(finalExe,buildDir . "\WatermarkTool.lnk",,"WatermarkTool","")
        FileCreateShortcut(finalExe,buildDir . "\CropTool.lnk",,"CropTool","")
        
        Step_Short()
        
        
        if false
            resp := MsgBox("Created file:`n" . 
                "     build/" exeName "`n`n" . 
                "The build process has finished.`n`n" . 
                "Would you like to run it now?", "Build complete", "YesNo 0x40")
        else resp := ""
        if(resp=="Yes")
            Run finalExe
        

    }
    else
    {
        MsgBox("❌ ERROR: Patching failed — exe lost!`n(Failed processing step or anti-virus?)")
    }
;#endregion


Sleep 500
ExitApp
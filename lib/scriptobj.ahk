/*
 * =============================================================================================== *
 * Author           : RaptorX   <graptorx@gmail.com>
 * Script Name      : Script Object
 * Script Version   : 1.0
 * Homepage         : 
 *
 * Creation Date    : September 03, 2011
 * Modification Date: October 05, 2012
 *
 * Description      :
 * ------------------
 * This is an object used to have a few common functions between scripts
 * Those are functions related to script information 
 *
 * -----------------------------------------------------------------------------------------------
 * License          :       Copyright ©2010-2012 RaptorX <GPLv3>
 *
 *          This program is free software: you can redistribute it and/or modify
 *          it under the terms of the GNU General Public License as published by
 *          the Free Software Foundation, either version 3 of  the  License,  or
 *          (at your option) any later version.
 *
 *          This program is distributed in the hope that it will be useful,
 *          but WITHOUT ANY WARRANTY; without even the implied warranty  of
 *          MERCHANTABILITY or FITNESS FOR A PARTICULAR  PURPOSE.  See  the
 *          GNU General Public License for more details.
 *
 *          You should have received a copy of the GNU General Public License
 *          along with this program.  If not, see <http://www.gnu.org/licenses/gpl-3.0.txt>
 * -----------------------------------------------------------------------------------------------
 *                                          Script Object
 * =============================================================================================== *
 */
 
;[General Variables]{
; Make SuperGlobal variables
global unused:=0, null:="",sec:=1000,min:=60*sec,hour:=60*min
;}

class scriptobj
{
    name        := ""
    version     := ""
    author      := ""
    email       := ""
    homepage    := ""
    crtdate     := ""
    moddate     := ""
    conf        := ""
    dbgFile     := ""
    dbg         := false
    sdbg        := false
    src         := false
    
    getparams(){
        global
        ; First we organize the parameters by priority [-sd, then -d , then everything else]
        ; I want to make sure that if i select to save a debug file, the debugging will be ON
        ; since the beginning because i use the debugging inside the next parameter checks as well.
        Loop, %0%
            param .= %a_index% .  a_space           ; param will contain the whole list of parameters

        if (InStr(param, "-h") || InStr(param, "--help")
        ||  InStr(param, "-?") || InStr(param, "/?")){
            script.debug("* ExitApp [0]", 2)
            Msgbox, 0x40
                  , % "Accepted Parameters"
                  , % "The script accepts the following parameters:`n`n"
                    . "-h    --help`tOpens this dialog.`n"
                    . "-v    --version`tOpens a dialog containing the current script version.`n"
                    . "-d    --debug`tStarts the script with debug ON.`n"
                    . "-sd  --save-debug`tStarts the script with debug ON but saves the info on the `n"
                    . "`t`tspecified txt file.`n"
                    . "-src  --source-code`tSaves a copy of the source code on the specified dir, specially `n"
                    . "`t`tuseful when the script is compiled and you want to see the source code."
            ExitApp
        }
        if (InStr(param, "-v") || InStr(param, "--version")){
            script.debug("* ExitApp [0]", 2)
            Msgbox, 0x40
                  , % "Version"
                  , % "Author: " script.author " <" script.email ">`n" "Version: " script.name " v" script.version "`t"
            ExitApp
        }
        if (InStr(param, "-d")
        ||  InStr(param, "--debug")){
            sparam := "-d "                         ; replace sparam with -d at the beginning.
        }
        if (InStr(param, "-sd")
        ||  InStr(param, "--save-debug")){
            RegexMatch(param,"-sd\s(\w+\.\w+)", df) ; replace sparam with -sd at the beginning
            sparam := "-sd " df1  a_space           ; also save the output file name next to it
        }
        Loop, Parse, param, %a_space%
        {
            if (a_loopfield = "-d" || a_loopfield = "-sd"
            ||  InStr(a_loopfield, ".txt")){        ; we already have those, so we just add the
                continue                            ; other parameters
            }
            sparam .= a_loopfield . a_space
        }
        sparam := RegexReplace(sparam, "\s+$")      ; Remove trailing spaces. Organizing is done

        Loop, Parse, sparam, %a_space%
        {
            if (script.sdbg && !script.dbgFile && (!a_loopfield || !InStr(a_loopfield,".txt")
            || InStr(a_loopfield,"-"))){
                script.dbg ? script.debug("* Error, debug file name not specified. ExitApp [1]", 2) : null
                Msgbox, 0x10
                      , % "Error"
                      , % "You must provide a name to a txt file to save the debug output.`n`n"
                        . "usage: " script.name " -sd file.txt"
                ExitApp
            }
            else if (script.sdbg){
                script.dbgFile ? "" : script.dbgFile := a_loopfield
                script.dbg ? script.debug("") : null
            }
            if (a_loopfield = "-d"
            ||  a_loopfield = "--debug"){
                script.dbg := true, script.debug("* " script.name " Debug ON`n* " script.name " [Start]`n* getparams() [Start]", 1)
            }
            if (a_loopfield = "-sd"
            ||  a_loopfield = "--save-debug"){
                script.sdbg := true, script.dbg := true
            }
            if (a_loopfield = "-src"
            ||  a_loopfield = "--source-code"){
                script.src := true
                script.dbg ? script.debug("* Copying source code") : null
                FileSelectFile, instloc, S16, % "source_" script.name
                              , % "Save source file to..."
                              , % "AutoHotkey Script (*.ahk)"
                if (!instloc){
                    script.dbg ? script.debug("* Canceled. ExitApp [1]", 2) : null
                    ExitApp
                }
                FileInstall,AHK-ToolKit.ahk, %instloc%
                if (!ErrorLevel){
                    script.dbg ? script.debug("* Source code successfully copied") : null
                    MsgBox, 0x40
                          , % "Source code copied"
                          , % "The source code was successfully copied"
                          , 10 ; 10s timeout
                }
                else
                {
                    script.dbg ? script.debug("* Error while copying the source code") : null
                    Msgbox, 0x10
                          , % "Error while copying"
                          , % "There was an error while copying the source code.`nPlease check that "
                            . "the file is not already present in the current directory and that "
                            . "you have write permissions on the current folder."
                    ExitApp
                }
            }
        }
        script.dbg ? script.debug("* " script.name " Debug OFF") : null
        if (script.sdbg && !script.dbgFile){                      ; needed in case -sd is the only parameter given
            script.dbg ? script.debug("* Error, debug file name not specified. ExitApp [1]", 2) : null
            Msgbox, 0x10
                  , % "Error"
                  , % "You must provide a name to a txt file to save the debug output.`n`n"
                    . "usage: " script.name " -sd file.txt"
            ExitApp
        }
        if (script.src = true){
            script.dbg ? script.debug("* ExitApp [0]", 2) : null
            ExitApp
        }
        script.dbg ? script.debug("* getparams() [End]") : null
        return
    }
    update(lversion, rfile="github", logurl=""){
        global script                       ; 本文件先于主脚本被 #include，主脚本里的 global script 对这里不可见，必须显式声明
        script.dbg ? script.debug("* update() [Start]", 1) : null
        
        if (a_thismenuitem = Tr("Check for Updates"))
            Progress, 50,,, % Tr("Updating...")

        ; 更新源 = 本项目仓库(script.repo)的 script.branch 分支（分支名区分大小写，本仓库默认分支为 Main）：
        ;  - 版本号：直接读取该分支上主脚本自身的 version 字段，只需维护一处，不再需要单独的 ver 文件/分支；
        ;  - 更新包：该分支的 zip 存档，解压后的根目录名为「仓库名-分支名」。
        ; 版本文件网址追加时间戳，避免 WinINet 缓存命中旧文件。
        logurl := rfile = "github" ? "https://raw.githubusercontent.com/" script.repo "/" script.branch
                                   . "/" script.name ".ahk?" a_now : logurl
        rfile  := rfile = "github" ? "https://github.com/" script.repo "/archive/refs/heads/" script.branch ".zip" : rfile
        script.dbg ? script.debug("* Version URL: " logurl "`n* Package URL: " rfile) : null

        ; 以「版本文件能否下载并解析出版本号」判断网络是否可用（原先 ping google.com，在国内网络下通常失败）
        UrlDownloadToFile, %logurl%, %a_temp%\logurl
        dlok := !ErrorLevel
        FileRead, vtext, %a_temp%\logurl
        FileDelete, %a_temp%\logurl
        RegExMatch(vtext, ",version\s*:\s*""v?([^""]+)""", Version)    ; 匹配脚本信息对象中的「,version : "x.y.z"」（不用 ^ 锚点：AHK 正则默认换行符是 CRLF，对 LF 文件不生效）
        if connected := (dlok && Version1 != "")
        {
            script.dbg ? script.debug("* Local Version: " lversion " Remote Version: " Version1) : null

            if (a_thismenuitem = Tr("Check for Updates"))
                Progress, 90
            
            if (Version1 > lversion){
                Progress, Off
                script.dbg ? script.debug("* There is a new update available") : null
                Msgbox, 0x40044
                      , % Tr("New Update Available")
                      , % Tr("There is a new update available for this application.`n"
                           . "Do you wish to upgrade to {1}?", "v" Version1)
                      , 10 ; 10s timeout
                IfMsgbox, Timeout
                {
                    script.dbg ? script.debug("* Update message timed out", 3) : null
                    return 1
                }
                IfMsgbox, No
                {
                    script.dbg ? script.debug("* Update aborted by user", 3) : null
                    return 2
                }
                script.dbg ? script.debug("* Downloading file to: " a_temp "\" script.name ".zip") : null
                if !Download(rfile, a_temp "\" script.name ".zip")
                {
                    script.dbg ? script.debug("* Download failed", 3) : null
                    Msgbox, 0x40030, % Tr("Update Check Failed"), % Tr("Unable to reach the update server.`nPlease check your network connection and try again.")
                    return 3
                }
                zipf := a_temp "\" script.name ".zip", dest := a_temp "\" script.name "-" script.branch
                FileRemoveDir, %dest%, 1                                    ; 清理上次遗留的解压目录，避免解压时弹出覆盖确认
                ; 解压：优先用系统自带的 tar.exe（Win10 1803+，同步解压）；没有 tar 的旧系统回退到 Shell.Application
                ; （CopyHere 可能异步完成，所以下面要等待并校验）。
                RunWait, % "tar -xf """ zipf """ -C """ a_temp """",, Hide UseErrorLevel
                if !FileExist(dest "\" script.name ".ahk")
                {
                    oShell := ComObjCreate("Shell.Application")
                    try oShell.NameSpace(a_temp).CopyHere(oShell.NameSpace(zipf).Items)
                    oShell := ""
                    Loop, 50                                                ; 最多等 5 s 让解压完成
                        if !FileExist(dest "\" script.name ".ahk")
                            Sleep, 100
                        else
                            break
                }
                if !FileExist(dest "\" script.name ".ahk")                  ; 校验解压结果，失败则中止，避免误报「安装完成」
                {
                    script.dbg ? script.debug("* Extraction failed", 3) : null
                    Msgbox, 0x40030, % Tr("Update Failed"), % Tr("The update package could not be extracted.")
                    return 3
                }

                ; FileCopy instead of FileMove so that file permissions are inherited correctly.
                Loop, %dest%, 1
                {
                    FileDelete, % a_loopfilelongpath "\" script.conf    ; 保留本机的 conf.xml，不被仓库中的同名文件覆盖
                    if (a_iscompiled){
                        FileAppend,
                        (Ltrim
                            echo off
                            PING 1.1.1.1 -n 1 -w 5000 >NUL
                            cd /d "%a_temp%"
                            xcopy /E /Y "%a_loopfilename%" "%a_scriptdir%"
                            rmdir /S /Q "%a_loopfilename%"
                            %comspec% /c "%a_scriptfullpath%"
                            del "%a_temp%\update.bat"
                        ),%a_temp%\update.bat
                        Run, %a_temp%\update.bat,,Hide
                    }
                    else
                    {
                        FileCopyDir, %a_loopfilelongpath%, %a_scriptdir%, 1
                        FileRemoveDir, % a_temp "/" a_loopfilename, 1
                    }
                }
                
                ; Clean
                FileDelete, % a_temp "/" script.name ".zip"
                FileRemoveDir, % a_temp "/Temporary Directory 1 for " script.name ".zip", 1
                
                Msgbox, 0x40040
                      , % Tr("Installation Complete")
                      , % Tr("The application will now restart.")

                if (a_iscompiled)
                    ExitApp
                else
                    Reload
            }
            else if (a_thismenuitem = Tr("Check for Updates"))
            {
                Progress, Off
                script.dbg ? (script.debug("* Script is up to date"), script.debug("* update() [End]", 2)) : null
                Msgbox, 0x40040
                      , % Tr("Script is up to date")
                      , % Tr("You are using the latest version of this script.`n"
                           . "Current version is v{1}", lversion)
                      , 10 ; 10s timeout

                IfMsgbox, Timeout
                {
                    script.dbg ? script.debug("* Update message timed out", 3) : null
                    return 1
                }
                return 0
            }
            else
            {
                script.dbg ? (script.debug("* Script is up to date"), script.debug("* update() [End]", 2)) : null
                return 0
            }
        }
        else
        {
            Progress, Off
            script.dbg ? (script.debug("* Connection Failed", 3), script.debug("* update() [End]", 2)) : null
            if (a_thismenuitem = Tr("Check for Updates"))       ; 启动时的静默检查不打扰用户，手动检查才提示
                Msgbox, 0x40030, % Tr("Update Check Failed"), % Tr("Unable to reach the update server.`nPlease check your network connection and try again.")
            return 3
        }
    }
    autostart(status){
        if status
        {
            RegWrite, REG_SZ, HKCU
                            , Software\Microsoft\Windows\CurrentVersion\Run
                            , % this.name
                            , %a_scriptfullpath%
        }
        else
        {
            RegDelete, HKCU
                     , Software\Microsoft\Windows\CurrentVersion\Run
                     , % this.name
        }
    }
    debug(msg,delimiter = false){
    
        static ft := true   ; First time

        t := delimiter = 1 ? msg := "* ------------------------------------------`n" msg
        t := delimiter = 2 ? msg := msg "`n* ------------------------------------------"
        t := delimiter = 3 ? msg := "* ------------------------------------------`n" msg
                                 .  "`n* ------------------------------------------"
        if (!script.dbgFile){
            script.sdbg && ft ? (msg := "* ------------------------------------------`n"
                                     .  "* " script.name " Debug ON`n* " script.name "[Start]`n"
                                     .  "* getparams() [Start]`n" msg, ft := 0)
            OutputDebug, %msg%
        }
        else if (script.dbgFile){
            ft ? (msg .= "* ------------------------------------------`n"
                      .  "* " script.name " Debug ON`n* " script.name
                      .  " [Start]`n* getparams() [Start]", ft := 0)
            FileAppend, %msg%`n, % script.dbgFile
        }
    }
}

; Based on code by Sean and SKAN @ http://www.autohotkey.com/forum/viewtopic.php?p=184468#184468
Download(url, file)
{
    global _cu
    static vt
    SplitPath file, dFile
    x:=(a_screenwidth/2)-(330/2), y:=(a_screenheight/2)-(52/2), VarSetCapacity(_cu, 100), VarSetCapacity(tn, 520)
    
    if !VarSetCapacity(vt)
    {
        VarSetCapacity(vt, A_PtrSize*11), nPar := "31132253353"
        Loop Parse, nPar
            NumPut(RegisterCallback("DL_Progress", "F", A_LoopField, A_Index-1), vt, A_PtrSize*(A_Index-1))
    }

    DllCall("shlwapi\PathCompactPathEx", "str", _cu, "str", url, "uint", 50, "uint", 0)
    Progress, Hide CWE0E0E0 CT000020 CB1111DD x%x% y%y% w330 h52 B1 FM8 FS8 WM700 WS700 ZH12 ZY3 C11,, %_cu%, % script.name, Tahoma
    
    if (0 = DllCall("urlmon\URLDownloadToCacheFile", "ptr", 0, "str", url, "str", tn, "uint", 260, "uint", 0x10, "ptr*", &vt))
        FileCopy %tn%, %file%, 1                    ; 1 = 覆盖：上次更新失败遗留的 zip 若不覆盖，之后每次下载都会失败
    else
        ErrorLevel := 1
    Progress Off
    return !ErrorLevel
}
DL_Progress( pthis, nP=0, nPMax=0, nSC=0, pST=0 )
{
    global _cu
    if A_EventInfo = 6
    {
        Progress Show
        Progress % P := 100*nP//nPMax, % "Downloading:     " Round(np/1024,1) " KB / " Round(npmax/1024) " KB    [ " P "`% ]", %_cu%
    }
    return 0
}
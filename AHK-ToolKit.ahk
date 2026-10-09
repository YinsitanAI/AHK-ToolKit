/*
 * =============================================================================================== *
 * @Author           : RaptorX <graptorx@gmail.com>
 * @Script Name      : AutoHotkey ToolKit (AHK-ToolKit)
 * @Script Version   : 0.9.0-161030
 * @Homepage         : http://www.autohotkey.com/forum/topic61379.html#376087
 *
 * @Creation Date    : July 11, 2010
 * @Modification Date: October 20, 2012
 *
 * @Description      :
 * -------------------
 * 精简版：保留「热键管理」「内置文件搜索(Everything)」以及个人化的鼠标/键盘手势层。
 *
 *  - 热键管理：通过界面添加「文件 / 文件夹」热键，修改后立即生效，无需重启脚本；
 *              高级选项支持窗口条件、左右修饰键、通配符、透传(~)、钩子($)、松开触发(UP)，
 *              以及「启动前插入按键」（用于避免 Shift 热键触发输入法中英文切换）。
 *  - 界面语言：支持 English / 中文，可在首选项中切换（切换后自动重新加载）。
 *  - DPI 适配：界面使用 AutoHotkey v1.1 原生 DPI 缩放，布局坐标均以 96 DPI 为基准书写。
 *
 * 已移除的模块：Code Detection、Command Helper、Live Code(含代码片段库)、Screen Tools、Hotstrings。
 *
 * -----------------------------------------------------------------------------------------------
 * @License          :       Copyright ©2010-2012 RaptorX <GPLv3>
 *
 *	This program is free software: you can redistribute it and/or modify it under the terms of
 *	the GNU General Public License as published by the Free Software Foundation,
 * 	either version 3 of  the  License,  or (at your option) any later version.
 *
 *          This program is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; WITHOUT EVEN THE IMPLIED WARRANTY  OF MERCHANTABILITY
 *	or FITNESS FOR A PARTICULAR  PURPOSE.  See  the GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License along with this program.
 *	If not, see <http://www.gnu.org/licenses/gpl-3.0.txt>
 * -----------------------------------------------------------------------------------------------
 *
 * [GUI Number Index]
 *
 * GUI 01 - First Time Run / AutoHotkey ToolKit [MAIN GUI]
 * GUI 02 - Add / Edit Hotkey
 * GUI 04 - Import Hotkeys
 * GUI 05 - Export Hotkeys
 * GUI 06 - Preferences
 * GUI 08 - About
 *
 * =============================================================================================== *
 */

;[Version check]{
; 需要 AutoHotkey v1.1.30+ 的 Unicode 版本：
; Func.Bind / Hotkey 函数对象(1.1.20+)、#MenuMaskKey(1.1.27+)、Link 控件、原生 DPI 缩放均依赖较新的 v1.1
if (A_AhkVersion < "1.1.30" || !A_IsUnicode)
{
    MsgBox, 0x10
          , % "Error / 错误"
          , % "This program requires AutoHotkey v1.1.30 or later (Unicode build).`n"
            . "本程序需要 AutoHotkey v1.1.30 及以上版本（Unicode 版）。`n`n"
            . "You can also use the compiled version. / 也可以直接使用编译后的版本。"
    ExitApp
}
;}

;[Includes]{
#include <klist>
#include <hkSwap>
#include <scriptobj>
;}

;[Directives]{
#NoEnv
#SingleInstance Force
#NoTrayIcon
; 指定「屏蔽 Win/Alt 单独松开时激活菜单」所用的遮罩键。
; 官方文档：未指定本指令时，AutoHotkey v1 默认用 Ctrl 作遮罩键 —— 本脚本有大量 Win/Alt 热键与鼠标手势，
; 每次这类热键松开 Win/Alt 时都会向系统注入一次 Ctrl 按下/弹起；若恰好与用户正在按下的 Ctrl+C 重叠，
; 应用会收到多余的 Ctrl 弹起，随后的 C 就变成了单独的字母 c。这里改用未分配的 vkE8，不再注入 Ctrl。
#MenuMaskKey vkE8
; #If 表达式只能由主线程求值，主线程繁忙时钩子会一直等待；系统自身的钩子超时(LowLevelHooksTimeout)默认仅 300 ms，
; 超时累计 11 次后钩子会被系统静默移除（表现为热键/手势突然失效，修饰键状态也可能错乱）。
; 把 #If 求值超时(默认 1000 ms)缩短到 100 ms，让 AutoHotkey 先于系统放弃，保证钩子不被摘除。
#IfTimeout 100
; ── 临时诊断（排查「Ctrl+C 变成字母 c」）：强制安装键盘钩子并加大按键历史，Win+F11 打开 KeyHistory。
;    KeyHistory 只在内存里、不写盘；它的 Type 列能区分按键来源：空=物理按键，a=别的程序注入，
;    i=本脚本自己注入。问题定位完后删掉这两行和末尾的 #F11 热键即可。
#InstallKeybdHook
#KeyHistory 500

; --
SendMode, Input
SetBatchLines, -1
SetTitleMatchMode, RegEx
CoordMode, Caret, Screen
CoordMode, Tooltip, Screen
SetWorkingDir, %A_ScriptDir%
OnExit, Exit
;}

;[Basic Script Info]{
global EveryThingPath:="D:\音速启动软件\Candy\Candy工具\文件操作软件\EveryThing"
global EveryThingDll="D:\音速启动软件\Candy\Candy工具\文件操作软件\EveryThing\Everything32.dll"						    ;软件运行计时所用全局变量
Gosub, EverythingStart
global DpiScale:=A_ScreenDPI/96                     ; 系统 DPI 缩放比例（鼠标手势层仍需使用）
global script := { base        : scriptobj
                  ,name        : "AHK-ToolKit"
                  ,version     : "0.10.0"
                  ,author      : "YinsitanAI"
                  ,email       : "yinsitanai0803@gmail.com"
                  ,homepage    : "https://github.com/YinsitanAI/AHK-ToolKit/"
                  ,crtdate     : "July 11, 2020"
                  ,moddate     : "October 06, 2026"
                  ,conf        : "conf.xml"
                  ,repo        : "YinsitanAI/AHK-ToolKit"   ; 更新源：GitHub 仓库 ...
                  ,branch      : "Main"}                    ; ... 及分支（区分大小写；本仓库默认分支为 Main，写成 main 会 404）
script.getparams()                                  ; 处理命令行参数（-h / -v / -d ...）
;}

;[User Configuration]{
; 配置文件对象：conf 为配置 DOM，xsl 为「缩进格式化」样式表
global conf := ComObjCreate("MSXML2.DOMDocument"), xsl := ComObjCreate("MSXML2.DOMDocument")
; MSXML 默认是异步加载，load() 会在文档尚未解析完成时就返回，随后立刻读节点会偶发失败，
; 原代码因此不得不到处重复 load()。这里统一改为同步加载，并明确使用 XPath 语法。
conf.async := xsl.async := False
conf.setProperty("SelectionLanguage", "XPath")

global Lang := DetectLang()                         ; 界面语言：en / zh（读取配置后再校正）
global UIFont := (Lang = "zh") ? "Microsoft YaHei UI" : "Segoe UI"
global editingHK := False, oldKey := ""             ; 「添加热键」对话框的编辑状态

style = ;{
(
<!-- Extracted from: http://www.dpawson.co.uk/xsl/sect2/pretty.html (v2) -->
<!-- Cdata info from: http://www.altova.com/forum/default.aspx?g=posts&t=1000002342 -->
<!-- Modified By RaptorX -->
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method="xml"
            indent="yes"
            encoding="UTF-8"/>

<xsl:template match="*">
   <xsl:copy>
      <xsl:copy-of select="@*" />
      <xsl:apply-templates />
   </xsl:copy>
</xsl:template>

<xsl:template match="comment()|processing-instruction()">
   <xsl:copy />
</xsl:template>
</xsl:stylesheet>
<!-- I have to keep the indentation here in this file as i want it to be on the XML file -->
)
;}

xsl.loadXML(style), style := ""
if !conf.load(script.conf)
{
    if FileExist(script.conf)
    {
        Msgbox, 0x14
              , % Tr("Error while reading the configuration file.")
              , % Tr("The configuration file is corrupt.`n"
                   . "Do you want to load the default configuration file?`n`n"
                   . "Note: `n"
                   . "You will lose any saved hotkeys and all other personal data by this operation.`n"
                   . "Choose No to abort the operation and try to recover the file manually.")

        IfMsgBox Yes
        {
            defConf(script.conf)

            Msgbox, 0x40
                  , % Tr("Operation Completed")
                  , % Tr("The default configuration file was successfully created. The script will reload.")

            Reload
            Pause       ; Fixes the problem of the Main Gui flashing because of being created before
                        ; the Reload is really performed.
        }
        IfMsgBox No
            ExitApp
    }
    else
        FirstRun()                                  ; 首次运行：向导保存后会生成并载入 conf.xml
}

; 以配置中的语言为准，并在版本号变化时同步配置文件中的版本
Lang := Cfg("Options/Startup/@lang", Lang)
UIFont := (Lang = "zh") ? "Microsoft YaHei UI" : "Segoe UI"
if (conf.documentElement.getAttribute("version") != script.version)
    conf.documentElement.setAttribute("version", script.version), SaveConf()
;}

;[Main]{
script.autostart(Cfg("Options/Startup/@sww"))
TrayMenu()
CreateGui()                 ; 先创建界面再检查更新，避免检查更新耗时导致窗口迟迟不出现
Cfg("Options/Startup/@cfu") ? script.update(script.version) : null
EmptyMem()                  ; [clean Memoery]
Return                      ; [End of Auto-Execute area]
;}

;[Labels]{
GuiHandler:         ;{
    GuiHandler()
return
;}

MenuHandler:        ;{
    MenuHandler()
return
;}

ListHandler:        ;{
    ListHandler()
return
;}

GuiSize:            ;{
    GuiSizeHandler()
return
;}

; 主窗口：关闭 / Esc / 主热键 统一为「显示 ⇄ 隐藏」切换
GuiClose:           ;{
GuiEscape:
MainToggle:
    ToggleMain()
return
;}

; 各对话框的关闭 / Esc
2GuiClose:          ;{
2GuiEscape:
    CloseDlg(2)
return
;}
4GuiClose:          ;{
4GuiEscape:
    CloseDlg(4)
return
;}
5GuiClose:          ;{
5GuiEscape:
    CloseDlg(5)
return
;}
6GuiClose:          ;{
6GuiEscape:
    CloseDlg(6)
return
;}
8GuiClose:          ;{
8GuiEscape:
    CloseDlg(8)
return
;}

; 托盘菜单
TrayReload:         ;{
    Reload
return
;}

TraySuspend:        ;{
    Menu, Tray, ToggleCheck, % Tr("Suspend Hotkeys")
    Suspend, Toggle
return
;}

TrayKeyHistory:     ;{
    KeyHistory
return
;}

TrayExit:           ;{
    ExitApp
return
;}

Exit:               ;{
    Gosub, EverythingStop                           ; 退出并释放 Everything（见 lib/FileSearch.ahk）
    ExitApp
;}
;}

;[Functions]{
; ---------------------------------------------------------------------------------------------
; 基础工具
; ---------------------------------------------------------------------------------------------
EmptyMem(){
	return, dllcall("psapi.dll\EmptyWorkingSet", "UInt", -1)
}

; 系统界面语言为中文时默认使用中文，否则使用英文
DetectLang(){
    return ((("0x" A_Language) & 0x3FF) = 4) ? "zh" : "en"
}

; 读取配置：path 为相对根节点 /AHK-Toolkit 的 XPath（如 "Options/Startup/@sww"），节点不存在时返回 def
Cfg(path, def := ""){
    node := conf.selectSingleNode("/AHK-Toolkit/" path)
    return IsObject(node) ? node.text : def
}

; 读取子节点文本，节点不存在时返回空串
Sub(node, tag){
    c := node.selectSingleNode(tag)
    return IsObject(c) ? c.text : ""
}

; 写入子节点文本（不存在则创建；value 为空则删除该子节点，保持配置文件整洁）
SetChild(node, tag, value){
    c := node.selectSingleNode(tag)
    if (value = "")
    {
        if IsObject(c)
            node.removeChild(c)
        return
    }
    if !IsObject(c)
        c := node.appendChild(conf.createElement(tag))
    c.text := value
}

; 按按键串查找热键节点（找不到返回空串）。
; AutoHotkey 的 = 比较不区分大小写，与「热键名不区分大小写」一致：#z 与 #Z 是同一个热键，不能重复添加；
; 同时避免了把按键串拼进 XPath 时单引号（'）需要转义的问题。
FindHK(key){
    for node in conf.selectNodes("/AHK-Toolkit/Hotkeys/hk")
        if (node.getAttribute("key") = key)
            return node
    return ""
}

; 保存配置：先套用 XSL 样式表整体缩进，再写盘，并重新载入以保证内存 DOM 与文件一致。
; 转换结果输出到一个独立的 DOM（原实现是「自己转换到自己」），并在转换结果为空时退回保存原 DOM，
; 保证任何情况下都不会把配置文件写成空文件。
SaveConf(){
    out := ComObjCreate("MSXML2.DOMDocument")
    out.async := False
    conf.transformNodeToObject(xsl, out)
    if (out.xml != "")
        out.save(script.conf)
    else
        conf.save(script.conf)
    if !conf.load(script.conf)
        MsgBox, 0x10
              , % Tr("Operation Failed")
              , % Tr("There was a problem while saving the settings.`nThe configuration file could not be reloaded.")
}

; 在下拉框中按「完整文本」选中某一项（ChooseString 只做前缀匹配，会误选 F1/F10 一类相近项）；找不到则选第 1 项
DDLSelect(n, ctrl, text){
    GuiControlGet, h, %n%:Hwnd, %ctrl%
    idx := DllCall("SendMessage", "Ptr", h, "UInt", 0x158, "Ptr", -1, "WStr", text, "Ptr")   ; CB_FINDSTRINGEXACT
    idx := (idx >= 0) ? idx + 1 : 1
    GuiControl, %n%: Choose, %ctrl%, %idx%
}

; 为单行编辑框设置灰色提示文字（系统原生 Cue Banner），替代原先靠消息钩子模拟的占位文字
SetCue(hEdit, text){
    DllCall("SendMessage", "Ptr", hEdit, "UInt", 0x1501, "Ptr", 1, "WStr", text, "Ptr")     ; EM_SETCUEBANNER
}

; ---------------------------------------------------------------------------------------------
; 界面语言：以英文原文为键，中文模式返回译文（缺失时回退原文）；{1} {2} 为占位符
; ---------------------------------------------------------------------------------------------
Tr(key, p1 := "", p2 := ""){
    global Lang
    static zh := ""
    if !IsObject(zh)
        zh := LoadZh()
    txt := (Lang = "zh" && zh.HasKey(key)) ? zh[key] : key
    return StrReplace(StrReplace(txt, "{1}", p1), "{2}", p2)
}

; 中文词条表：每行「英文原文|中文译文」
LoadZh(){
    d := {}
    zhtext =
    (LTrim
        Error while reading the configuration file.|读取配置文件时出错
        The configuration file is corrupt.`nDo you want to load the default configuration file?`n`nNote: `nYou will lose any saved hotkeys and all other personal data by this operation.`nChoose No to abort the operation and try to recover the file manually.|配置文件已损坏。`n是否加载默认配置文件？`n`n注意：`n此操作将丢失所有已保存的热键及其他个人数据。`n选择“否”可中止操作，您可以尝试手动修复该文件。
        Operation Completed|操作完成
        The default configuration file was successfully created. The script will reload.|默认配置文件已成功创建，脚本将重新加载。
        Suspend Hotkeys|暂停热键
        Key History|按键历史
        Operation Failed|操作失败
        There was a problem while saving the settings.`nThe configuration file could not be reloaded.|保存设置时出现问题。`n无法重新载入配置文件。
        This is the first time you are running {1}.`nYou can change these options at any time later in "Settings > Preferences".|这是您第一次运行 {1}。`n您可以随时在“设置 > 首选项”中修改这些选项。
        &Save|保存(&S)
        First Run|首次运行
        Startup|启动
        Start with Windows|随 Windows 启动
        Start minimized|启动后最小化到托盘
        Check for updates|启动时检查更新
        Language|语言
        Main GUI Hotkey|主窗口热键
        Show Main GUI|显示主窗口
        Reload|重新加载
        Exit|退出
        Import Hotkeys|导入热键
        Export Hotkeys|导出热键
        &New`t(Ctrl+N)|新建(&N)`t(Ctrl+N)
        Delete`t(DEL)|删除`t(DEL)
        Import/Export|导入/导出
        Always On Top|窗口置顶
        &Preferences`t(Ctrl+P)|首选项(&P)`t(Ctrl+P)
        Check for Updates|检查更新
        About|关于
        File|文件
        View|查看
        Settings|设置
        Help|帮助
        Type|类型
        Program Name|名称
        Hotkey|热键
        Program Path|路径
        Quick Search|快速搜索（名称或路径）
        &Add|添加(&A)
        &Close|关闭(&C)
        Hotkey Name|热键名称
        Hotkey Type|热键类型
        Folder|文件夹
        &Browse...|浏览(&B)...
        Select Hotkey|选择按键
        Advanced Options|高级选项
        Window conditions: comma delimited, case sensitive, regex allowed|窗口条件：多个标题以英文逗号分隔，区分大小写，支持正则表达式
        If window active list (e.g. Winamp, Notepad, Fire.*)|仅在这些窗口激活时生效（例如：Winamp, Notepad, Fire.*）
        If window NOT active list (e.g. Notepad++, Firefox)|在这些窗口激活时不生效（例如：Notepad++, Firefox）
        Left modifier only (<)|仅左侧修饰键 (<)
        Right modifier only (>)|仅右侧修饰键 (>)
        Wildcard (*)|通配符 (*)
        Pass-through (~)|保留按键原功能 (~)
        Install hook ($)|强制键盘钩子 ($)
        Fire on release (UP)|松开时触发 (UP)
        Insert key before launch|启动前插入按键
        Sent first as {Blind}{key}. Example: vkE8 stops Shift hotkeys from toggling the IME.|先以 {Blind}{按键} 的形式发送，例如 vkE8 可避免 Shift 热键触发输入法中英文切换。
        &Cancel|取消(&C)
        Add Hotkey|添加热键
        Import from|导入来源
        Include subfolders|包含子文件夹
        &Import|导入(&I)
        Target|目标
        Source File|来源文件
        &Accept|确认导入(&A)
        C&lear|清空(&L)
        Import|导入
        Export to|导出到
        &Export|导出(&E)
        Export|导出
        &OK|确定(&O)
        Preferences|首选项
        Author|作者
        Script Version|版本
        Creation Date|创建日期
        Modification Date|修改日期
        Homepage|主页
        License|许可证
        Error|错误
        The hotkey could not be registered:`n{1}|无法注册热键：`n{1}
        {1} Hotkeys currently active|当前已启用 {1} 个热键
        The file this hotkey is trying to access does not exist.|此热键要访问的文件不存在。
        Error while trying to create new Hotkey|创建热键时出错
        Please select the key that you want to use as a hotkey.|请选择要作为热键使用的按键。
        Please enter the file or folder path to launch.|请输入要启动的文件或文件夹路径。
        Left and right modifier cannot be checked together.|左侧与右侧修饰键不能同时勾选。
        A hotkey with this key already exists:`n{1}|已存在相同的热键（~ / $ 前缀不同或修饰键顺序不同也视为同一个热键）：`n{1}
        This hotkey is reserved by the program:`n{1}|该热键已被程序占用：`n{1}
        File Search|内置搜索
        Behavior|行为
        Double press: fire only when pressed twice within|双击触发：两次按键间隔不超过
        Only while holding|仅当按住
        If target is already running|目标已在运行时
        Run again|再次运行
        Do nothing|不处理
        Close it|关闭它
        Send keys|发送按键
        On a window title bar: move the window to the adjacent monitor|鼠标在窗口标题栏时：把窗口移到相邻显示器
        Program closed|程序已退出！
        Edit Hotkey|编辑热键
        {1} hotkeys found.|共找到 {1} 个热键。
        {1} hotkeys imported, {2} skipped (already exist).|已导入 {1} 个热键，跳过 {2} 个（按键已存在）。
        The file exists|文件已存在
        The filename that you selected appears already exist.`nDo you want to append to the existing file?|所选文件已存在。`n是否追加到现有文件末尾？
        {1} hotkeys exported.|已导出 {1} 个热键。
        Please select the file to launch.|请选择要启动的文件。
        Please select the folder to launch.|请选择要启动的文件夹。
        Select the folder|选择文件夹
        Select the file|选择文件
        Save File as...|另存为...
        Language changed. The program will reload to apply it.|语言已更改，程序将重新加载以使其生效。
        Updating...|正在检查更新...
        Update Check Failed|检查更新失败
        Unable to reach the update server.`nPlease check your network connection and try again.|无法连接更新服务器。`n请检查网络连接后重试。
        Update Failed|更新失败
        The update package could not be extracted.|无法解压更新包。
        New Update Available|发现新版本
        There is a new update available for this application.`nDo you wish to upgrade to {1}?|本程序有新版本可用。`n是否升级到 {1}？
        Installation Complete|安装完成
        The application will now restart.|程序现在将重新启动。
        Script is up to date|已是最新版本
        You are using the latest version of this script.`nCurrent version is v{1}|您正在使用最新版本。`n当前版本为 v{1}。
    )
    Loop, Parse, zhtext, `n, `r
    {
        p := InStr(A_LoopField, "|")
        if (p > 1)
            d[SubStr(A_LoopField, 1, p - 1)] := SubStr(A_LoopField, p + 1)
    }
    return d
}

; ---------------------------------------------------------------------------------------------
; 首次运行向导 / 托盘 / 菜单
; ---------------------------------------------------------------------------------------------
FirstRun(){
    global
    ; 向导默认值
    _frDone := False
    _sww := 1, _smm := 1, _cfu := 0, _lang := (Lang = "zh") ? 2 : 1
    _ctrl := 0, _alt := 0, _shift := 0, _win := 1, _mhk := "``"

    Gui, 1: +DelimiterSpace +LastFound
    _hwndFR := WinExist()
    Gui, 1: Font, s9, %UIFont%
    Gui, 1: Add, Text, x12 y12 w372
              , % Tr("This is the first time you are running {1}.`n"
                  . "You can change these options at any time later in ""Settings > Preferences"".", script.name)
    _y := PrefControls(1, 66)
    Gui, 1: Add, Button, % "x294 y" _y + 14 " w90 h28 Default vbtnFirstSave gGuiHandler", % Tr("&Save")

    GuiControlGet, _hddl, 1:Hwnd, _hkddl
    CaptureKeys(_hwndFR, _hddl)
    Gui, 1: Show, % "w396 h" _y + 56, % Tr("First Run")

    ; 等待用户点击「保存」（Sleep 期间仍会响应界面事件）。比原先的 Pause / 再次 Pause 方式更直观可靠
    while !_frDone
        Sleep, 50
}

; 绘制「启动 / 语言 / 主窗口热键」三组设置，首次运行向导与首选项窗口共用。
; n 为 GUI 编号，y 为起始纵坐标；控件初值取自全局变量 _sww _smm _cfu _lang _ctrl _alt _shift _win _mhk。
; 返回最后一组下沿的纵坐标。
PrefControls(n, y){
    global
    Gui, %n%: Add, GroupBox, % "x12 y" y " w372 h106", % Tr("Startup")
    Gui, %n%: Add, CheckBox, % "x28 y" y + 26 " v_sww Checked" (_sww ? 1 : 0), % Tr("Start with Windows")
    Gui, %n%: Add, CheckBox, % "x28 y" y + 50 " v_smm Checked" (_smm ? 1 : 0), % Tr("Start minimized")
    Gui, %n%: Add, CheckBox, % "x28 y" y + 74 " v_cfu Checked" (_cfu ? 1 : 0), % Tr("Check for updates")

    Gui, %n%: Add, GroupBox, % "x12 y" y + 116 " w372 h64", % Tr("Language")
    Gui, %n%: Add, DropDownList, % "x28 y" y + 140 " w200 AltSubmit v_lang Choose" _lang, English 中文

    Gui, %n%: Add, GroupBox, % "x12 y" y + 190 " w372 h66", % Tr("Main GUI Hotkey")
    Gui, %n%: Add, CheckBox, % "x28 y" y + 218 " v_ctrl Checked" (_ctrl ? 1 : 0), Ctrl
    Gui, %n%: Add, CheckBox, % "x80 y" y + 218 " v_alt Checked" (_alt ? 1 : 0), Alt
    Gui, %n%: Add, CheckBox, % "x130 y" y + 218 " v_shift Checked" (_shift ? 1 : 0), Shift
    Gui, %n%: Add, CheckBox, % "x190 y" y + 218 " v_win Checked" (_win ? 1 : 0), Win
    Gui, %n%: Add, DropDownList, % "x244 y" y + 214 " w128 R15 v_hkddl gGuiHandler", % "Default  " klist("all^", "mods")
    DDLSelect(n, "_hkddl", _mhk)
    return y + 256
}

; 首次运行向导：窗口激活时直接按键，即可在「主窗口热键」下拉框中选中该键。
; 注意：上下文必须限定在向导窗口本身（ahk_id），否则标题含 "First Run" 的其他窗口也会被吞键。
CaptureKeys(hWin, hDDL){
    lst := klist("all^", "mods msb kbd")            ; 排除修饰键、鼠标键与 Tab/Enter/Esc 等导航键，保证向导窗口仍可正常点击和键盘操作
    fn := Func("PickKey").Bind(hDDL)                ; 回调必须是单个变量中的函数对象（且被无参调用）
    Hotkey, IfWinActive, ahk_id %hWin%
    Loop, Parse, lst, %A_Space%
        Hotkey, % A_LoopField, % fn, UseErrorLevel
    Hotkey, IfWinActive
}

PickKey(hDDL){
    hk := A_ThisHotkey                              ; 回调不带参数，被按下的键从 A_ThisHotkey 取得
    idx := DllCall("SendMessage", "Ptr", hDDL, "UInt", 0x158, "Ptr", -1, "WStr", hk, "Ptr")    ; CB_FINDSTRINGEXACT
    if (idx >= 0)
        DllCall("SendMessage", "Ptr", hDDL, "UInt", 0x14E, "Ptr", idx, "Ptr", 0)               ; CB_SETCURSEL
}

TrayMenu(){
    Menu, Tray, Icon, res/AHK-TK.ico
    Menu, Tray, Tip, % script.name " v" script.version
    Menu, Tray, NoStandard
    Menu, Tray, Click, 1
    Menu, Tray, add, % Tr("Show Main GUI"), MainToggle
    Menu, Tray, Default, % Tr("Show Main GUI")
    Menu, Tray, add
    Menu, Tray, add, % Tr("Reload"), TrayReload
    Menu, Tray, add, % Tr("Suspend Hotkeys"), TraySuspend
    Menu, Tray, add, % Tr("Key History"), TrayKeyHistory      ; 排查「按键丢失 / 修饰键状态异常」时用来查看实际收到的按键事件
    Menu, Tray, add, % Tr("Exit"), TrayExit
}

MainMenu(){
    Menu, iexport, add, % Tr("Import Hotkeys"), MenuHandler
    Menu, iexport, add
    Menu, iexport, add, % Tr("Export Hotkeys"), MenuHandler

    Menu, File, add, % Tr("&New`t(Ctrl+N)"), MenuHandler
    Menu, File, add, % Tr("Delete`t(DEL)"), MenuHandler
    Menu, File, add
    Menu, File, add, % Tr("Import/Export"), :iexport
    Menu, File, add
    Menu, File, add, % Tr("Exit"), TrayExit

    Menu, View, add, % Tr("Always On Top"), MenuHandler
    if conf.documentElement.getAttribute("alwaysontop")
        Menu, View, check, % Tr("Always On Top")

    Menu, Settings, add, % Tr("&Preferences`t(Ctrl+P)"), MenuHandler

    Menu, Help, add, % Tr("Check for Updates"), MenuHandler
    Menu, Help, add
    Menu, Help, add, % Tr("About"), MenuHandler

    Menu, MainMenu, add, % Tr("File"), :File
    Menu, MainMenu, add, % Tr("View"), :View
    Menu, MainMenu, add, % Tr("Settings"), :Settings
    Menu, MainMenu, add, % Tr("Help"), :Help
}

; ---------------------------------------------------------------------------------------------
; 窗口创建（所有坐标均以 96 DPI 为基准，由 AutoHotkey 按系统 DPI 自动缩放）
; ---------------------------------------------------------------------------------------------
CreateGui(){
    global $hwnd1
    MainGui(), AddHKGui(), ImportGui(), ExportGui(), PreferencesGui(), AboutGui()
    MainWinHotkeys($hwnd1)
    MainHotkey("On")
    return
}

MainGui(){
    global
    _aot := conf.documentElement.getAttribute("alwaysontop") ? "+AlwaysOnTop" : "-AlwaysOnTop"
    Gui, 01: Default
    Gui, 01: +LastFound +Resize %_aot%
    $hwnd1 := WinExist()
    MainMenu()
    Gui, 01: Font, s9, %UIFont%
    Gui, 01: Menu, MainMenu

    ; 热键列表：第 5 列（原始按键串）宽度为 0，仅用于编辑 / 删除时精确定位配置节点。
    ; shkList 叠放在 hkList 之上，用于显示快速搜索的结果。
    _cols := Tr("Type") "|" Tr("Program Name") "|" Tr("Hotkey") "|" Tr("Program Path") "|Key"
    Gui, 01: Add, ListView, x12 y10 w800 h344 Grid AltSubmit +LV0x10020 gListHandler vhkList, %_cols%
    Gui, 01: Add, ListView, x12 y10 w800 h344 Grid AltSubmit +LV0x10020 gListHandler vshkList Hidden, %_cols%

    Gui, 01: Add, Edit, x12 y364 w260 vQShk gGuiHandler HWND$QShk
    SetCue($QShk, Tr("Quick Search"))
    Gui, 01: Add, Button, x624 y363 w90 h28 Default vbtnAdd gGuiHandler, % Tr("&Add")
    Gui, 01: Add, Button, x722 y363 w90 h28 vbtnClose gGuiHandler, % Tr("&Close")

    Gui, 01: Add, StatusBar
    SB_SetParts(430)                                ; 与其它 Gui 命令一样，宽度参数会被 AutoHotkey 自动按 DPI 缩放（实测验证）

    Load()
    _hide := Cfg("Options/Startup/@smm") ? "Hide" : ""
    Gui, 01: Show, w824 h420 %_hide%, AutoHotkey Toolkit
    Gui, 01: +MinSize                               ; 以初始大小作为最小尺寸（文档：不带数字的 +MinSize 即取当前大小），避免手动换算 DPI
    return
}

AddHKGui(){
    global
    Gui, 02: +Owner1 +LastFound -MinimizeBox +DelimiterSpace
    Gui, 02: Font, s9, %UIFont%

    ; 左列：名称 / 类型与路径 / 热键
    Gui, 02: Add, GroupBox, x14 y10 w380 h58, % Tr("Hotkey Name")
    Gui, 02: Add, Edit, x28 y34 w352 vhkName

    Gui, 02: Add, GroupBox, x14 y76 w380 h108, % Tr("Hotkey Type")
    Gui, 02: Add, Radio, x28 y100 Checked vhkType gGuiHandler, % Tr("File")
    Gui, 02: Add, Radio, x+20 yp vhkTypeB gGuiHandler, % Tr("Folder")
    Gui, 02: Add, Radio, x+20 yp vhkTypeC gGuiHandler, % Tr("File Search")       ; 内置搜索（原 !CapsLock::Gosub, FileSearchKey）
    Gui, 02: Add, Edit, x28 y130 w262 vhkPath
    Gui, 02: Add, Button, x298 y128 w84 h26 vbtnHkBrowse gGuiHandler, % Tr("&Browse...")

    Gui, 02: Add, GroupBox, x14 y192 w380 h74, % Tr("Select Hotkey")
    Gui, 02: Add, CheckBox, x28 y222 vhkctrl, Ctrl
    Gui, 02: Add, CheckBox, x80 y222 vhkalt, Alt
    Gui, 02: Add, CheckBox, x130 y222 vhkshift, Shift
    Gui, 02: Add, CheckBox, x190 y222 vhkwin, Win
    ; 按键列表包含修饰键（如 Alt），这样才能给「单独的 Alt」之类的修饰键设置热键（配合「双击」使用）
    Gui, 02: Add, DropDownList, x244 y218 w136 R15 vhkey, % "None  " klist("all^")

    ; 右列：高级选项
    Gui, 02: Add, GroupBox, x410 y10 w410 h256, % Tr("Advanced Options")
    Gui, 02: Add, Text, x424 y32 w384, % Tr("Window conditions: comma delimited, case sensitive, regex allowed")
    Gui, 02: Add, Edit, x424 y54 w384 vhkIfWin HWND$hkIfWin
    Gui, 02: Add, Edit, x424 y84 w384 vhkIfWinN HWND$hkIfWinN
    SetCue($hkIfWin, Tr("If window active list (e.g. Winamp, Notepad, Fire.*)"))
    SetCue($hkIfWinN, Tr("If window NOT active list (e.g. Notepad++, Firefox)"))

    Gui, 02: Add, CheckBox, x424 y122 w190 vhkLMod, % Tr("Left modifier only (<)")
    Gui, 02: Add, CheckBox, x+8 yp w190 vhkRMod, % Tr("Right modifier only (>)")
    Gui, 02: Add, CheckBox, x424 y146 w190 vhkWild, % Tr("Wildcard (*)")
    Gui, 02: Add, CheckBox, x+8 yp w190 vhkSend, % Tr("Pass-through (~)")
    Gui, 02: Add, CheckBox, x424 y170 w190 vhkHook, % Tr("Install hook ($)")
    Gui, 02: Add, CheckBox, x+8 yp w190 vhkfRel, % Tr("Fire on release (UP)")

    ; 插入按键：触发后先补发该按键，再启动目标（等价于 RunNoToggle：先发 {Blind}{vkE8} 再 Run）
    Gui, 02: Add, CheckBox, x424 y204 w200 vhkIns gGuiHandler, % Tr("Insert key before launch")
    Gui, 02: Add, Edit, x632 y200 w96 vhkInsKey, vkE8
    Gui, 02: Add, Text, x424 y230 w384 h30, % Tr("Sent first as {Blind}{key}. Example: vkE8 stops Shift hotkeys from toggling the IME.")

    ; 下排：行为选项（把原先要手写脚本才能实现的常见玩法做成界面选项）
    Gui, 02: +Delimiter|                            ; 上面的按键列表用空格分隔；之后的列表控件改回 | 分隔
    Gui, 02: Add, GroupBox, x14 y274 w806 h124, % Tr("Behavior")
    Gui, 02: Add, CheckBox, x28 y300 w310 vhkDbl gGuiHandler, % Tr("Double press: fire only when pressed twice within")
    Gui, 02: Add, Edit, x342 y296 w56 Number vhkDblMs, 300
    Gui, 02: Add, Text, x404 y301 w24, ms
    Gui, 02: Add, Text, x440 y301 w120, % Tr("Only while holding")
    Gui, 02: Add, ComboBox, x566 y296 w150 R8 Choose1 vhkHold, None|LButton|RButton|MButton|XButton1|XButton2|CapsLock|Space
    Gui, 02: Add, Text, x28 y336 w180, % Tr("If target is already running")
    Gui, 02: Add, DropDownList, x212 y332 w130 AltSubmit Choose1 vhkRun gGuiHandler
                              , % Tr("Run again") "|" Tr("Do nothing") "|" Tr("Close it") "|" Tr("Send keys")
    Gui, 02: Add, Edit, x352 y332 w150 vhkRunKeys, {Click}
    Gui, 02: Add, CheckBox, x28 y368 w780 vhkTitle, % Tr("On a window title bar: move the window to the adjacent monitor")

    Gui, 02: Add, Button, x642 y412 w84 h28 Default vbtnHkOK gGuiHandler, % Tr("&Add")
    Gui, 02: Add, Button, x734 y412 w84 h28 vbtnHkCancel gGuiHandler, % Tr("&Cancel")

    Gui, 02: Show, w834 h456 Hide, % Tr("Add Hotkey")
    return
}

ImportGui(){
    global
    Gui, 04: +Owner1 +LastFound -MinimizeBox
    Gui, 04: Font, s9, %UIFont%

    Gui, 04: Add, GroupBox, x12 y10 w756 h96, % Tr("Import from")
    Gui, 04: Add, Radio, x28 y36 Checked gGuiHandler vimType, % Tr("Folder")
    Gui, 04: Add, Radio, x+16 yp gGuiHandler vimTypeB, % Tr("File")
    Gui, 04: Add, CheckBox, x+40 yp Checked vimRecurse, % Tr("Include subfolders")
    Gui, 04: Add, Edit, x28 y66 w560 vimPath, %A_MyDocuments%
    Gui, 04: Add, Button, x596 y64 w80 h26 vbtnImBrowse gGuiHandler, % Tr("&Browse...")
    Gui, 04: Add, Button, x684 y64 w72 h26 vbtnImScan gGuiHandler, % Tr("&Import")

    Gui, 04: Add, ListView, x12 y118 w756 r12 Grid AltSubmit gListHandler vimList
                          , % Tr("Type") "|" Tr("Hotkey") "|" Tr("Target") "|" Tr("Source File")
    Gui, 04: Add, Button, x490 y+12 w90 h28 Default vbtnImAccept gGuiHandler, % Tr("&Accept")
    Gui, 04: Add, Button, x+8 yp w90 h28 vbtnImClear gGuiHandler, % Tr("C&lear")
    Gui, 04: Add, Button, x+8 yp w80 h28 vbtnImCancel gGuiHandler, % Tr("&Cancel")

    Gui, 04: Show, w780 Hide, % Tr("Import")
    return
}

ExportGui(){
    global
    Gui, 05: +Owner1 +LastFound -MinimizeBox
    Gui, 05: Font, s9, %UIFont%

    Gui, 05: Add, GroupBox, x12 y10 w476 h68, % Tr("Export to")
    Gui, 05: Add, Edit, x28 y34 w372 vexPath, % A_MyDocuments "\export_" SubStr(A_Now, 1, 8) ".ahk"
    Gui, 05: Add, Button, x408 y32 w72 h26 vbtnExBrowse gGuiHandler, % Tr("&Browse...")

    Gui, 05: Add, Button, x300 y92 w90 h28 Default vbtnExExport gGuiHandler, % Tr("&Export")
    Gui, 05: Add, Button, x398 y92 w90 h28 vbtnExCancel gGuiHandler, % Tr("&Cancel")

    Gui, 05: Show, w500 h134 Hide, % Tr("Export")
    return
}

PreferencesGui(){
    global
    Gui, 06: +Owner1 +LastFound -MinimizeBox -MaximizeBox +DelimiterSpace
    Gui, 06: Font, s9, %UIFont%

    LoadPrefVars()
    _y := PrefControls(6, 12)
    Gui, 06: Add, Button, % "x196 y" _y + 14 " w90 h28 Default vbtnPrefOK gGuiHandler", % Tr("&OK")
    Gui, 06: Add, Button, % "x294 y" _y + 14 " w90 h28 vbtnPrefClose gGuiHandler", % Tr("&Close")

    Gui, 06: Show, % "w396 h" _y + 56 " Hide", % Tr("Preferences")
    return
}

; 从配置读取「首选项」控件的初值
LoadPrefVars(){
    global
    _sww := Cfg("Options/Startup/@sww"), _smm := Cfg("Options/Startup/@smm"), _cfu := Cfg("Options/Startup/@cfu")
    _lang := (Cfg("Options/Startup/@lang", Lang) = "zh") ? 2 : 1
    _ctrl := Cfg("Options/MainKey/@ctrl"), _alt := Cfg("Options/MainKey/@alt")
    _shift := Cfg("Options/MainKey/@shift"), _win := Cfg("Options/MainKey/@win")
    _mhk := Cfg("Options/MainKey")
}

AboutGui(){
    global
    local rows, i, r, license
    Gui, 08: +Owner1 -MinimizeBox +LastFound
    Gui, 08: Color, White
    Gui, 08: Font, s9, %UIFont%

    Gui, 08: Add, Picture, x24 y16, res\img\AHK-TK_About.png

    rows := [ [Tr("Author"), script.author " <" script.email ">"]
            , [Tr("Script Version"), script.version]
            , [Tr("Creation Date"), script.crtdate]
            , [Tr("Modification Date"), script.moddate] ]
    for i, r in rows
    {
        Gui, 08: Add, Text, % "x24 y+" (i = 1 ? 18 : 6) " w120", % r[1]
        Gui, 08: Add, Text, x+0 yp w290, % r[2]
    }
    Gui, 08: Add, Text, x24 y+6 w120, % Tr("Homepage")
    Gui, 08: Add, Link, x+0 yp w290 r2, % "<a href=""" script.homepage """>" script.homepage "</a>"

    license := "Copyright ©2020-2026 " script.author " <GPLv3>`n`n"
             . "This program is free software: you can redistribute it and/or modify it "
             . "under the terms of the GNU General Public License as published by "
             . "the Free Software Foundation, either version 3 of the License, "
             . "or (at your option) any later version.`n`n"
             . "This program is distributed in the hope that it will be useful, "
             . "but WITHOUT ANY WARRANTY; without even the implied warranty of "
             . "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. "
             . "See the GNU General Public License for more details.`n`n"
             . "You should have received a copy of the GNU General Public License "
             . "along with this program."
    Gui, 08: Add, Text, x24 y+14 w404, % Tr("License")
    Gui, 08: Add, Edit, x24 y+6 w404 h132 ReadOnly -Tabstop, %license%
    Gui, 08: Add, Link, x24 y+8 w404
              , <a href="http://www.gnu.org/licenses/gpl-3.0.txt">http://www.gnu.org/licenses/gpl-3.0.txt</a>
    Gui, 08: Add, Button, x338 y+14 w90 h28 Default vbtnAboutClose gGuiHandler, % Tr("&Close")

    Gui, 08: Show, w452 Hide, % Tr("About")
    return
}

; ---------------------------------------------------------------------------------------------
; 窗口行为：显示切换 / 对话框开关 / 缩放 / 复位
; ---------------------------------------------------------------------------------------------
; 主窗口显示 ⇄ 隐藏。
; 热键呼出时若窗口可见但不在前台，则先置前而不是隐藏；点击托盘图标（非热键触发）则直接切换。
ToggleMain(){
    global $hwnd1
    if !$hwnd1                                      ; 主窗口尚未创建 = 仍在首次运行向导中：关闭向导即退出程序
        ExitApp
    visible := DllCall("IsWindowVisible", "Ptr", $hwnd1)
    if (visible && !WinActive("ahk_id " $hwnd1) && A_TimeSinceThisHotkey < 100 && A_TimeSinceThisHotkey != -1)
    {
        WinActivate, ahk_id %$hwnd1%
        return
    }
    if visible
        Gui, 01: Hide
    else
        Gui, 01: Show
}

; 打开对话框：先复位内容，再禁用主窗口并显示
OpenDlg(n){
    GuiReset(n)
    Gui, 01: +Disabled
    Gui, %n%: Show
}

; 关闭对话框：隐藏、恢复主窗口并复位对话框内容
CloseDlg(n){
    global $hwnd1
    Gui, %n%: Hide
    Gui, 01: -Disabled
    WinActivate, ahk_id %$hwnd1%
    GuiReset(n)
}

; 主窗口缩放。启用 DPI 缩放时，A_GuiWidth / A_GuiHeight 与 GuiControl Move 使用同一套「96 DPI 基准」坐标
; （官方文档：150% 缩放下把窗口拖到 200 像素宽，A_GuiWidth 返回 133），因此无需再手动换算。
GuiSizeHandler(){
    if (A_EventInfo = 1)                            ; 最小化 = 收起到托盘
    {
        Gui, 01: Hide
        return
    }
    w := A_GuiWidth, h := A_GuiHeight
    GuiControl, 01: Move, hkList, % "w" w - 24 " h" h - 76
    GuiControl, 01: Move, shkList, % "w" w - 24 " h" h - 76
    GuiControl, 01: Move, QShk, % "y" h - 56
    GuiControl, 01: Move, btnAdd, % "x" w - 200 " y" h - 57
    GuiControl, 01: Move, btnClose, % "x" w - 102 " y" h - 57
}

; 「添加 / 编辑热键」对话框：按各开关的当前状态启用 / 禁用依赖它们的控件
SyncDlg(){
    global
    local on
    Gui, 02: Submit, NoHide
    GuiControl, 02: Enable%hkIns%, hkInsKey                 ; 插入按键：勾选后才可改按键名
    GuiControl, 02: Enable%hkDbl%, hkDblMs                  ; 双击：勾选后才可改间隔
    on := (hkRun = 4)
    GuiControl, 02: Enable%on%, hkRunKeys                   ; 已在运行时「发送按键」：才需要填按键
    on := !hkTypeC
    GuiControl, 02: Enable%on%, hkPath                      ; 内置搜索不需要路径
    GuiControl, 02: Enable%on%, btnHkBrowse
}

; 各对话框复位到初始状态（打开前 / 关闭后调用）
GuiReset(n){
    global
    local i, c
    if (n = 2)                                      ; 添加 / 编辑热键
    {
        editingHK := False, oldKey := ""
        GuiControl, 02:, hkName
        GuiControl, 02:, hkType, 1
        GuiControl, 02:, hkPath
        for i, c in ["hkctrl", "hkalt", "hkshift", "hkwin", "hkLMod", "hkRMod", "hkWild", "hkSend", "hkHook", "hkfRel", "hkIns", "hkDbl", "hkTitle"]
            GuiControl, 02:, %c%, 0
        GuiControl, 02:, hkDblMs, 300
        DDLSelect(2, "hkHold", "None")
        GuiControl, 02: Choose, hkRun, 1
        GuiControl, 02:, hkRunKeys, {Click}
        DDLSelect(2, "hkey", "None")
        GuiControl, 02:, hkIfWin
        GuiControl, 02:, hkIfWinN
        GuiControl, 02:, hkInsKey, vkE8
        SyncDlg()
        GuiControl, 02:, btnHkOK, % Tr("&Add")
        Gui, 02: Show, Hide, % Tr("Add Hotkey")
    }
    else if (n = 4)                                 ; 导入
    {
        GuiControl, 04:, imType, 1
        GuiControl, 04:, imRecurse, 1
        GuiControl, 04: Enable, imRecurse
        GuiControl, 04:, imPath, %A_MyDocuments%
        Gui, 04: Default
        Gui, 04: ListView, imList
        LV_Delete()
        for i, c in [70, 150, 270, 240]             ; 空列表的初始列宽（会被自动按 DPI 缩放），避免英文表头 "Hotkey" 被截成 "Hot..."
            LV_ModifyCol(i, c)
        Gui, 01: Default
    }
    else if (n = 5)                                 ; 导出
        GuiControl, 05:, exPath, % A_MyDocuments "\export_" SubStr(A_Now, 1, 8) ".ahk"
    else if (n = 6)                                 ; 首选项：恢复为已保存的设置
    {
        LoadPrefVars()
        for i, c in ["_sww", "_smm", "_cfu", "_ctrl", "_alt", "_shift", "_win"]
            GuiControl, 06:, %c%, % %c% ? 1 : 0
        GuiControl, 06: Choose, _lang, %_lang%
        DDLSelect(6, "_hkddl", _mhk)
    }
}

; 主窗口内的快捷键（仅主窗口处于激活状态时有效）
MainWinHotkeys(hwnd){
    ; Hotkey 命令的回调只接受「单个变量」保存的函数对象，且触发时不带参数，所以先用 Bind 生成并存入变量
    fnNew := Func("OpenDlg").Bind(2), fnImport := Func("OpenDlg").Bind(4), fnPrefs := Func("OpenDlg").Bind(6)
    Hotkey, IfWinActive, ahk_id %hwnd%
    Hotkey, ^n, % fnNew                             ; Ctrl + N  新建热键
    Hotkey, ^i, % fnImport                          ; Ctrl + I  导入
    Hotkey, ^p, % fnPrefs                           ; Ctrl + P  首选项
    Hotkey, IfWinActive
}

; 主窗口热键的按键串（读取 conf 中的 MainKey；未配置返回空串）
MainKeyStr(){
    mk := conf.selectSingleNode("/AHK-Toolkit/Options/MainKey")
    if !IsObject(mk)
        return ""
    return (mk.getAttribute("ctrl") ? "^" : "") (mk.getAttribute("alt") ? "!" : "")
         . (mk.getAttribute("shift") ? "+" : "") (mk.getAttribute("win") ? "#" : "") mk.text
}

; 注册 / 注销「主窗口热键」
MainHotkey(state){
    key := MainKeyStr()
    if (key != "")
        Hotkey, % key, MainToggle, % state " UseErrorLevel"
}

; ---------------------------------------------------------------------------------------------
; 热键数据：加载 / 注册 / 保存 / 删除
; ---------------------------------------------------------------------------------------------
; 刷新热键列表；reg 为 True（启动时）时同时注册全部热键。
; 新增 / 编辑 / 删除之后只传 False：只刷新列表，其余热键保持原样不再重复注册——
; 每次都「全部重新注册」既慢，又会让与本次操作无关的热键被反复注销再注册，增加它们失效的机会。
Load(reg := True){
    global
    local node, bad := "", err
    Gui, 01: Default
    Gui, 01: ListView, hkList
    LV_Delete()
    GuiControl, 01: -Redraw, hkList
    for node in conf.selectNodes("/AHK-Toolkit/Hotkeys/hk")
    {
        if !IsHK(node)                              ; 旧版的 Script 型热键已不再支持，直接跳过
            continue
        AddRow(node)
        if reg
        {
            err := HkSet(node, "On")
            if (err != "")
                bad .= "`n" err
        }
    }
    AutoCols()
    GuiControl, 01: +Redraw, hkList
    FilterHK()
    UpdateSB()
    if (bad != "")
        MsgBox, 0x10, % Tr("Error"), % Tr("The hotkey could not be registered:`n{1}", bad)
}

; 只处理「文件 / 文件夹 / 内置搜索」三类热键（旧版的 Script 型已不再支持）
IsHK(node){
    t := node.getAttribute("type")
    return (t = "File" || t = "Folder" || t = "Search")
}

; 向当前 ListView 追加一行：类型 / 名称 / 热键 / 路径 / 原始按键串（隐藏列）
AddRow(node){
    key := node.getAttribute("key")
    t := node.getAttribute("type")
    LV_Add("", Tr(t = "Search" ? "File Search" : t), Sub(node, "name"), hkSwap(key, "long"), Sub(node, "path"), key)
}

AutoCols(){
    Loop, 4
        LV_ModifyCol(A_Index, "AutoHdr")
    LV_ModifyCol(5, 0)
}

; 快速搜索：按名称 / 路径过滤，命中结果放入覆盖在主列表之上的 shkList；搜索框为空时恢复主列表
FilterHK(){
    global
    local q, node
    GuiControlGet, q, 01:, QShk
    Gui, 01: Default
    if (q = "")
    {
        GuiControl, 01: Hide, shkList
        GuiControl, 01: Show, hkList
        return
    }
    Gui, 01: ListView, shkList
    LV_Delete()
    GuiControl, 01: -Redraw, shkList
    for node in conf.selectNodes("/AHK-Toolkit/Hotkeys/hk")
        if IsHK(node) && (InStr(Sub(node, "name"), q) || InStr(Sub(node, "path"), q))
            AddRow(node)
    AutoCols()
    GuiControl, 01: +Redraw, shkList
    GuiControl, 01: Hide, hkList
    GuiControl, 01: Show, shkList
}

UpdateSB(){
    Gui, 01: Default
    n := conf.selectNodes("/AHK-Toolkit/Hotkeys/hk").length
    SB_SetText("`t" Tr("{1} Hotkeys currently active", n), 1)
    SB_SetText("`tv" script.version, 2)
}

; 热键的「真实身份」。AutoHotkey 把仅 $ / ~ 前缀不同、或修饰符顺序不同的写法视为【同一个】热键：
; 后注册的会悄悄覆盖先注册的（先添加的那条从此失效），删除其中一条还会把两条一起关掉。
; 所以「是否重复」必须按身份比较：去掉 $ ~，把修饰符排序，不区分大小写（= 比较本身不区分大小写）。
HkId(key){
    local m, t, toks := "", p := 1
    RegExMatch(key, "O)^([$~*<>^!+#]*)(.*)$", m)
    while (p := RegExMatch(m[1], "O)\*|[<>]?[\^!+#]", t, p))
        toks .= t[0] "|", p += StrLen(t[0])
    Sort, toks, D|
    return toks m[2]
}

; 找出与 key 身份相同的已有热键，返回它的按键串（没有则返回空串）；ignoreKey 是正在编辑的旧按键串，不算冲突
HkConflict(key, ignoreKey := ""){
    local node, k, id := HkId(key)
    for node in conf.selectNodes("/AHK-Toolkit/Hotkeys/hk")
    {
        k := node.getAttribute("key")
        if (k != ignoreKey && HkId(k) = id)
            return k
    }
    return ""
}

; 注册(On) / 注销(Off) 一条热键，返回出错的按键名（成功返回空串）。
;  - 热键回调通过 Func.Bind 绑定 HkOpts 生成的参数对象，触发时无需再读 XML：
;    既更快（插入键能在修饰键仍被按住时立即发出），也避免了依赖 A_ThisHotkey 字符串去反查节点
;    （原实现会把热键里的 ~ 前缀去掉再比较，导致勾选「透传(~)」的热键永远找不到节点而无法运行）。
;  - 窗口条件 / 「按住某键」条件通过 Hotkey, IfWinActive / If 上下文实现。
HkSet(node, state){
    local key := node.getAttribute("key"), act := Sub(node, "ifwinactive"), nact := Sub(node, "ifwinnotactive")
    local hold := node.getAttribute("hold"), fn, err := "", i, c, ctxfn
    if (state = "On")
        fn := Func("HotkeyHandler").Bind(HkOpts(node, act, nact, hold))
    for i, c in HkContexts(act, nact, hold)
    {
        if (c[1] = "IfWinActive")
            Hotkey, IfWinActive, % c[2]
        else if (c[1] = "IfWinNotActive")
            Hotkey, IfWinNotActive, % c[2]
        else if (c[1] = "If")
        {
            ctxfn := c[2]                           ; Hotkey, If 的参数必须是「单个变量」中的函数对象
            Hotkey, If, % ctxfn
        }
        else
            Hotkey, IfWinActive                     ; 无条件：全局上下文
        if (state = "On")
        {
            Hotkey, % key, % fn, On UseErrorLevel
            if ErrorLevel
                err := key
        }
        else
            Hotkey, % key,, Off UseErrorLevel
    }
    Hotkey, IfWinActive                             ; 复位上下文，避免影响之后的 Hotkey 命令
    return err
}

; 汇总触发时需要的全部参数（Bind 之后与 XML 脱钩）
HkOpts(node, act, nact, hold){
    local o, m
    o := { type: node.getAttribute("type"), path: Sub(node, "path"), ins: node.getAttribute("inskey")
         , dbl: node.getAttribute("dbl"), run: node.getAttribute("running"), keys: node.getAttribute("runkeys")
         , tb: node.getAttribute("titlebar") }
    RegExMatch(node.getAttribute("key"), "O)^[$~*<>^!+#]*(.+?)( UP)?$", m)
    ; 旧配置里存的 vk07 自 Win10 1909 起被系统保留给 Game Bar（AHK 文档 #MenuMaskKey 一节），运行时换成未分配的 vkE8
    if (o.ins = "vk07")
        o.ins := "vkE8"
    o.bkey := m[1]                                  ; 去掉前缀和 UP 后的主键名，供「双击」用 KeyWait 检测（不能叫 base：那是 AHK 对象的保留属性）
    ; 上下文承载不了的窗口条件，改在触发时检查：设置了「按住某键」时上下文被占用（act、nact 都要查）；
    ; 「激活」和「非激活」同时设置时，上下文只承载「激活」，「非激活」在触发时查
    o.act  := hold ? act : ""
    o.nact := (hold || (act != "" && nact != "")) ? nact : ""
    return o
}

; 把窗口条件转换为 Hotkey 上下文列表：
;  - 「按住某键」：用函数对象做上下文（同一个键共用同一个对象，否则每次注册都会产生新的上下文变体）；
;  - 「激活」列表：每个标题各注册一份（任一窗口激活即触发）；
;  - 「非激活」列表：建立窗口组，用 IfWinNotActive ahk_group（所有窗口都不激活才触发）。
HkContexts(act, nact, hold := ""){
    local ctx := []
    if (hold != "")
        ctx.Push(["If", HoldCtx(hold)])
    else if (act != "")
    {
        Loop, Parse, act, `,, %A_Space%%A_Tab%
            if (A_LoopField != "")
                ctx.Push(["IfWinActive", A_LoopField])
    }
    else if (nact != "")
        ctx.Push(["IfWinNotActive", "ahk_group " WinGroup(nact)])
    if !ctx.MaxIndex()
        ctx.Push(["", ""])
    return ctx
}

; 「按住 key 时才生效」的上下文函数。Hotkey, If 会把「热键名」作为最后一个参数传入，这里用不到
HoldCtx(key){
    static fns := {}
    if !fns.HasKey(key)
        fns[key] := Func("HeldKey").Bind(key)
    return fns[key]
}
HeldKey(key, hk){
    return GetKeyState(key, "P")
}

; 为窗口标题列表建立（并缓存）窗口组，返回组名
WinGroup(list){
    static ids := {}, n := 0
    if !ids.HasKey(list)
    {
        n++
        ids[list] := "HKW" n
        Loop, Parse, list, `,, %A_Space%%A_Tab%
            if (A_LoopField != "")
                GroupAdd, % ids[list], %A_LoopField%
    }
    return ids[list]
}

; 热键触发入口。参数 o 由 HkOpts 生成。处理顺序：窗口条件 -> 插入键 -> 双击 -> 标题栏移屏 -> 内置搜索 -> 「已在运行」处理 -> 运行
HotkeyHandler(o){
    if (o.act != "" && !WinActive("ahk_group " WinGroup(o.act)))
        return
    if (o.nact != "" && WinActive("ahk_group " WinGroup(o.nact)))
        return
    ; 必须最先执行：趁修饰键（如 Shift）仍被按住时补发一个空键，让输入法不再把这次按键当作「单击 Shift」。
    ; {Blind} 保证不改变修饰键的当前状态。
    if (o.ins != "")
        SendInput, % "{Blind}{" o.ins "}"
    if (o.dbl > 0 && !DoublePress(o.bkey, o.dbl))
        return
    if (o.tb && TitleBarMove())
        return
    if (o.type = "Search")
    {
        SetTimer, FileSearchKey, -1                 ; 在独立线程里打开内置搜索（与原 !CapsLock::Gosub, FileSearchKey 等价）
        return
    }
    if (o.run != "" && (pid := RunningPID(o.path)))
    {
        if (o.run = "close")
        {
            Process, Close, %pid%
            ToolTip, % Tr("Program closed")
            Sleep, 300
            ToolTip
        }
        else if (o.run = "send")
        {
            WaitModsUp()
            Send, % o.keys
        }
        return                                      ; skip：什么都不做
    }
    try
        Run, % o.path
    catch
        MsgBox, 0x10
              , % Tr("Error")
              , % Tr("The file this hotkey is trying to access does not exist.") "`n" o.path
}

; 发送不带 {Blind} 的按键前，先等用户松开全部修饰键（每个最多等 1 秒，超时照常发送）。
; 不带 {Blind} 的 Send 遇到仍按着的修饰键，会先注入一个弹起、发完再注入按下来「还原」。
; 只要系统里还有别的程序装着低级键盘钩子（PasteJump 就有），AutoHotkey 官方文档说明 SendInput
; 就失去了「整组不可打断」的优势：用户的物理按键可能插进这串注入中间，注入的 Ctrl 弹起若落在
; 用户新按下的 Ctrl 之后，随后的 C 就成了字母 c。修饰键都已松开时 Send 无需释放/还原，竞态不存在。
WaitModsUp(timeout := 1){
    for i, k in ["Ctrl", "Alt", "Shift", "LWin", "RWin"]
        KeyWait, %k%, T%timeout%
}

; 双击检测：等第一次按键松开后，在 ms 毫秒内是否再次按下（等价于 KeyWait, key / KeyWait, key, D T0.x）
DoublePress(key, ms){
    KeyWait, %key%
    KeyWait, %key%, % "D T" ms / 1000
    return !ErrorLevel
}

; 鼠标位于窗口顶部标题栏区域（离窗口上沿 50 个 96DPI 像素以内）时，把窗口移到相邻显示器：
; 点在窗口左半边 -> Win+Shift+←，右半边 -> Win+Shift+→。已处理返回 True。
TitleBarMove(){
    local mx, my, id, title, w
    CoordMode, Mouse, Relative                      ; 坐标相对于鼠标下的窗口（物理像素，所以按 DPI 缩放判断区域）
    MouseGetPos, mx, my, id
    WinGetTitle, title, ahk_id %id%
    WinGetPos,,, w,, ahk_id %id%
    if (my > 0 && my < DpiScale * 50 && title != "Program Manager")
    {
        WaitModsUp()
        SendInput, % (mx < w / 2) ? "+#{Left}" : "+#{Right}"
        return True
    }
    return False
}

; 目标是否已在运行，返回 PID（未运行或无法判断返回 0）：
;  .exe 按进程名；.ahk 按「AutoHotkey 进程的命令行里含该脚本名」；其他类型（文档 / 图片 / 文件夹）无法判断。
RunningPID(path){
    static wmi
    local name, ext, p
    SplitPath, path, name,, ext
    if (ext = "exe")
    {
        Process, Exist, %name%
        return ErrorLevel
    }
    if (ext = "ahk")
    {
        try
        {
            if !wmi
                wmi := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")    ; 连接只建立一次，避免每次触发都新建
            for p in wmi.ExecQuery("SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name LIKE 'AutoHotkey%' OR Name='InternalAHK.exe'")
                if InStr(p.CommandLine, name)
                    return p.ProcessId
        }
    }
    return 0
}

; 写入 / 删除节点属性（value 为空则删除，保持配置文件整洁）
SetAttr(node, name, value){
    if (value = "")
        node.removeAttribute(name)
    else
        node.setAttribute(name, value)
}

; 保存「添加 / 编辑热键」对话框：校验 -> 注册 -> 写入 conf.xml -> 刷新。成功返回 True
SaveHK(){
    global
    local mk, mods, fullkey, ins, name, path, node, dup, err, i, r, type, runsel
    if (hkey = "None" || hkey = "")
    {
        MsgBox, 0x10, % Tr("Error while trying to create new Hotkey"), % Tr("Please select the key that you want to use as a hotkey.")
        return False
    }
    type := hkTypeC ? "Search" : hkTypeB ? "Folder" : "File"      ; 三个单选框各自带变量时，变量只是 0/1，不是序号
    path := (type = "Search") ? "" : Trim(hkPath)
    if (path = "" && type != "Search")
    {
        MsgBox, 0x10, % Tr("Error while trying to create new Hotkey"), % Tr("Please enter the file or folder path to launch.")
        return False
    }
    if (hkLMod && hkRMod)
    {
        MsgBox, 0x10, % Tr("Error while trying to create new Hotkey"), % Tr("Left and right modifier cannot be checked together.")
        return False
    }

    ; 左 / 右修饰键前缀（< >）只作用于其后紧跟的一个修饰符，因此必须加在每个已选修饰符之前
    mk := hkLMod ? "<" : hkRMod ? ">" : ""
    mods := (hkctrl ? mk "^" : "") (hkalt ? mk "!" : "") (hkshift ? mk "+" : "") (hkwin ? mk "#" : "")
    fullkey := (hkHook ? "$" : "") (hkSend ? "~" : "") (hkWild ? "*" : "") mods hkey (hkfRel ? " UP" : "")
    ins := hkIns ? Trim(hkInsKey, " `t{}") : ""
    if (hkIns && ins = "")
        ins := "vkE8"
    SplitPath, path,,,, name
    name := Trim(hkName) != "" ? Trim(hkName) : (type = "Search") ? Tr("File Search") : name

    ; 重复检查按「真实身份」而不是按字符串（见 HkId）；程序自己占用的热键也不能再分配
    dup := HkConflict(fullkey, editingHK ? oldKey : "")
    if (dup != "")
    {
        MsgBox, 0x10, % Tr("Error while trying to create new Hotkey"), % Tr("A hotkey with this key already exists:`n{1}", hkSwap(dup, "long"))
        return False
    }
    for i, r in ["^F12", "^CtrlBreak", "#F11", MainKeyStr()]
        if (HkId(r) = HkId(fullkey))
        {
            MsgBox, 0x10, % Tr("Error while trying to create new Hotkey"), % Tr("This hotkey is reserved by the program:`n{1}", hkSwap(r, "long"))
            return False
        }

    if editingHK
    {
        node := FindHK(oldKey)
        HkSet(node, "Off")                          ; 先注销旧按键（含旧的窗口条件），否则改键后旧按键仍然有效
    }
    else
        node := conf.selectSingleNode("/AHK-Toolkit/Hotkeys").appendChild(conf.createElement("hk"))

    runsel := hkRun                                 ; 「已在运行时」下拉框的序号：1 再次运行 / 2 不处理 / 3 关闭它 / 4 发送按键
    node.setAttribute("type", type)
    node.setAttribute("key", fullkey)
    SetAttr(node, "inskey", ins)
    SetAttr(node, "dbl", hkDbl ? ((hkDblMs > 0) ? hkDblMs : 300) : "")
    SetAttr(node, "hold", (hkHold = "None") ? "" : Trim(hkHold))
    SetAttr(node, "running", (runsel = 2) ? "skip" : (runsel = 3) ? "close" : (runsel = 4) ? "send" : "")
    SetAttr(node, "runkeys", (runsel = 4) ? (Trim(hkRunKeys) != "" ? Trim(hkRunKeys) : "{Click}") : "")
    SetAttr(node, "titlebar", hkTitle ? 1 : "")
    SetChild(node, "name", name), SetChild(node, "path", path)
    SetChild(node, "ifwinactive", Trim(hkIfWin)), SetChild(node, "ifwinnotactive", Trim(hkIfWinN))

    err := HkSet(node, "On")
    if (err != "")                                  ; 按键无效：丢弃内存中的修改，从磁盘恢复，并只把被注销的旧热键重新注册回来
    {
        MsgBox, 0x10, % Tr("Error"), % Tr("The hotkey could not be registered:`n{1}", err)
        HkSet(node, "Off")                          ; 清掉可能已部分注册的新按键
        conf.load(script.conf)
        if editingHK
            HkSet(FindHK(oldKey), "On")
        Load(False)
        return False
    }
    SaveConf()
    Load(False)                                     ; 只刷新列表；其他热键保持原样，不重复注册
    return True
}

; 双击列表条目：把节点内容回填到「添加热键」对话框进入编辑模式
EditHK(key){
    global
    local node, m, flags, t, v
    node := FindHK(key)
    if !IsObject(node)
        return
    GuiReset(2)
    editingHK := True, oldKey := key

    GuiControl, 02:, hkName, % Sub(node, "name")
    t := node.getAttribute("type")
    GuiControl, 02:, % (t = "Folder") ? "hkTypeB" : (t = "Search") ? "hkTypeC" : "hkType", 1
    GuiControl, 02:, hkPath, % Sub(node, "path")
    GuiControl, 02:, hkIfWin, % Sub(node, "ifwinactive")
    GuiControl, 02:, hkIfWinN, % Sub(node, "ifwinnotactive")

    ; 按键串 = 前缀符号 + 按键名 + 可选的 " UP" 后缀；用正则拆开还原各个选项
    ; （原先用 InStr 判断 " UP" 会把 #Up 这类按键名里的 "Up" 误判为「松开触发」）
    RegExMatch(key, "O)^([$~*<>^!+#]*)(.+?)( UP)?$", m)
    flags := m[1]
    GuiControl, 02:, hkHook, % InStr(flags, "$") ? 1 : 0
    GuiControl, 02:, hkSend, % InStr(flags, "~") ? 1 : 0
    GuiControl, 02:, hkWild, % InStr(flags, "*") ? 1 : 0
    GuiControl, 02:, hkLMod, % InStr(flags, "<") ? 1 : 0
    GuiControl, 02:, hkRMod, % InStr(flags, ">") ? 1 : 0
    GuiControl, 02:, hkctrl, % InStr(flags, "^") ? 1 : 0
    GuiControl, 02:, hkalt, % InStr(flags, "!") ? 1 : 0
    GuiControl, 02:, hkshift, % InStr(flags, "+") ? 1 : 0
    GuiControl, 02:, hkwin, % InStr(flags, "#") ? 1 : 0
    GuiControl, 02:, hkfRel, % (m[3] != "") ? 1 : 0
    DDLSelect(2, "hkey", m[2])

    if (node.getAttribute("inskey") != "")
    {
        GuiControl, 02:, hkIns, 1
        GuiControl, 02:, hkInsKey, % node.getAttribute("inskey")
    }
    ; 行为选项（属性缺省时保持 GuiReset 设置的默认值）
    if (node.getAttribute("dbl") != "")
    {
        GuiControl, 02:, hkDbl, 1
        GuiControl, 02:, hkDblMs, % node.getAttribute("dbl")
    }
    if (node.getAttribute("hold") != "")
        GuiControl, 02: Text, hkHold, % node.getAttribute("hold")          ; 组合框允许手输任意按键名
    v := node.getAttribute("running")
    GuiControl, 02: Choose, hkRun, % (v = "skip") ? 2 : (v = "close") ? 3 : (v = "send") ? 4 : 1
    if (node.getAttribute("runkeys") != "")
        GuiControl, 02:, hkRunKeys, % node.getAttribute("runkeys")
    GuiControl, 02:, hkTitle, % node.getAttribute("titlebar") ? 1 : 0
    SyncDlg()
    GuiControl, 02:, btnHkOK, % Tr("&Save")
    Gui, 01: +Disabled
    Gui, 02: Show, , % Tr("Edit Hotkey")
}

; 删除当前列表中选中的热键（支持多选）
DeleteSelected(){
    global
    local lv, keys, row, k, node, i
    GuiControlGet, lv, 01:Visible, shkList
    lv := lv ? "shkList" : "hkList"
    Gui, 01: Default
    Gui, 01: ListView, %lv%
    keys := [], row := 0
    while (row := LV_GetNext(row))
    {
        LV_GetText(k, row, 5)
        keys.Push(k)
    }
    if !keys.MaxIndex()
        return
    for i, k in keys
    {
        node := FindHK(k)
        if IsObject(node)
        {
            HkSet(node, "Off")
            node.parentNode.removeChild(node)
        }
    }
    SaveConf()
    Load(False)
}

; ---------------------------------------------------------------------------------------------
; 导入 / 导出
; ---------------------------------------------------------------------------------------------
; 扫描导入来源，把识别出的热键填入导入列表（尚未写入配置）
ImportScan(){
    global
    local n := 0
    Gui, 04: Default
    Gui, 04: ListView, imList
    LV_Delete()
    if (imType = 1)
    {
        Loop, Files, %imPath%\*.ahk, % imRecurse ? "FR" : "F"
            n += hotExtract(A_LoopFileLongPath)
    }
    else
    {
        Loop, Parse, imPath, |
            n += hotExtract(A_LoopField)
    }
    Loop, 4
        LV_ModifyCol(A_Index, "AutoHdr")
    Gui, 01: Default
    MsgBox, 0x40, % Tr("Import"), % Tr("{1} hotkeys found.", n)
}

; 从一个 .ahk 文件中提取「热键::Run, 路径」形式的单行热键并加入导入列表，返回提取数量
hotExtract(path){
    local n := 0, txt, m, cmd, q, type
    FileRead, txt, %path%
    Loop, Parse, txt, `n, `r
    {
        if !RegExMatch(A_LoopField, "iO)^\s*(?P<opt>[<>*~$]*)(?P<hk>[\w#!^+&]+?)(?P<up>\s+UP)?\s*::\s*Run(?:,\s*|\s+)(?P<cmd>[^;]+?)\s*(;.*)?$", m)
            continue
        cmd := m.cmd
        if RegExMatch(cmd, "O)^""(.*)""$", q)       ; 整体被引号包住时去掉引号
            cmd := q[1]
        type := InStr(FileExist(cmd), "D") ? "Folder" : "File"
        LV_Add("", Tr(type), m.opt m.hk (m.up != "" ? " UP" : ""), cmd, path)
        n++
    }
    return n
}

; 把导入列表中的热键写入配置（已存在的按键自动跳过）
ImportAccept(){
    global
    local cnt := 0, skipped := 0, t, k, p, node, name
    Gui, 04: Default
    Gui, 04: ListView, imList
    Loop % LV_GetCount()
    {
        LV_GetText(t, A_Index, 1), LV_GetText(k, A_Index, 2), LV_GetText(p, A_Index, 3)
        if (HkConflict(k) != "")                    ; 与已有热键「真实身份」相同的跳过
        {
            skipped++
            continue
        }
        node := conf.selectSingleNode("/AHK-Toolkit/Hotkeys").appendChild(conf.createElement("hk"))
        node.setAttribute("type", (t = Tr("Folder")) ? "Folder" : "File")
        node.setAttribute("key", k)
        SplitPath, p,,,, name
        SetChild(node, "name", name), SetChild(node, "path", p)
        HkSet(node, "On")
        cnt++
    }
    SaveConf()
    Gui, 01: Default
    Load(False)
    MsgBox, 0x40, % Tr("Import"), % Tr("{1} hotkeys imported, {2} skipped (already exist).", cnt, skipped)
}

; 导出全部热键为标准 .ahk 脚本（带窗口条件的热键用 #If 包裹）
DoExport(){
    global
    local out, node, key, path, ins, cond, block, n := 0
    if FileExist(exPath)
    {
        Msgbox, 0x124, % Tr("The file exists"), % Tr("The filename that you selected appears already exist.`nDo you want to append to the existing file?")
        IfMsgbox No
            return False
    }
    out := "; Hotkeys exported with AutoHotkey Toolkit v" script.version "`nSetTitleMatchMode, RegEx`n"
    for node in conf.selectNodes("/AHK-Toolkit/Hotkeys/hk")
    {
        if !IsHK(node)
            continue
        key := node.getAttribute("key"), path := Sub(node, "path"), ins := node.getAttribute("inskey")
        if (node.getAttribute("type") = "Search")   ; 内置搜索依赖本程序，无法导出为独立脚本
        {
            out .= "; " key ": built-in file search (not exported)`n"
            continue
        }
        if (node.getAttribute("dbl") != "" || node.getAttribute("hold") != "" || node.getAttribute("running") != "" || node.getAttribute("titlebar") != "")
            out .= "; NOTE: the behavior options (double press / hold key / already running / title bar) of " key " are not exported`n"
        block := key "::" ((ins != "") ? "`n    SendInput, {Blind}{" ins "}`n    Run, " path "`nreturn" : "Run, " path)
        cond := CondExpr(Sub(node, "ifwinactive"), Sub(node, "ifwinnotactive"))
        out .= (cond != "") ? "`n#If " cond "`n" block "`n#If`n" : block "`n"
        n++
    }
    FileAppend, % out, % exPath, UTF-8
    MsgBox, 0x40, % Tr("Export"), % Tr("{1} hotkeys exported.", n)
    return True
}

; 把窗口条件列表转成 #If 表达式：(任一「激活」窗口) 且 (所有「非激活」窗口均不激活)
CondExpr(act, nact){
    expr := ""
    Loop, Parse, act, `,, %A_Space%%A_Tab%
        if (A_LoopField != "")
            expr .= (expr = "" ? "" : " || ") "WinActive(""" A_LoopField """)"
    if (expr != "")
        expr := "(" expr ")"
    Loop, Parse, nact, `,, %A_Space%%A_Tab%
        if (A_LoopField != "")
            expr .= (expr = "" ? "" : " && ") "!WinActive(""" A_LoopField """)"
    return expr
}

; ---------------------------------------------------------------------------------------------
; 首选项
; ---------------------------------------------------------------------------------------------
; 保存「首次运行向导 / 首选项」中的设置（需先 Submit 取得 _sww _smm _cfu _lang _ctrl _alt _shift _win _hkddl）
StorePrefs(reg := True){
    global
    local st, mk
    MainHotkey("Off")                               ; 先注销旧的主热键
    if (_hkddl = "Default" || _hkddl = "")          ; 选择 Default = 恢复为 Win + `
        _ctrl := _alt := _shift := 0, _win := 1, _hkddl := "``"
    st := conf.selectSingleNode("/AHK-Toolkit/Options/Startup")
    st.setAttribute("sww", _sww ? 1 : 0), st.setAttribute("smm", _smm ? 1 : 0), st.setAttribute("cfu", _cfu ? 1 : 0)
    st.setAttribute("lang", (_lang = 2) ? "zh" : "en")
    mk := conf.selectSingleNode("/AHK-Toolkit/Options/MainKey")
    mk.setAttribute("ctrl", _ctrl ? 1 : 0), mk.setAttribute("alt", _alt ? 1 : 0)
    mk.setAttribute("shift", _shift ? 1 : 0), mk.setAttribute("win", _win ? 1 : 0)
    mk.text := _hkddl
    SaveConf()
    if reg
        MainHotkey("On")
}

; 「首选项」下拉框选择 Default 时，把修饰键与按键恢复为 Win + `
PrefHotkeyDDL(n){
    global _hkddl
    if (_hkddl != "Default")
        return
    GuiControl, %n%:, _ctrl, 0
    GuiControl, %n%:, _alt, 0
    GuiControl, %n%:, _shift, 0
    GuiControl, %n%:, _win, 1
    DDLSelect(n, "_hkddl", "``")
}

; 生成默认配置文件
defConf(path){
    FileDelete, %path%
    xml := "<?xml version=""1.0"" encoding=""UTF-8""?>`n"
         . "<AHK-Toolkit version=""" script.version """ alwaysontop=""0"">`n"
         . "    <Options>`n"
         . "        <Startup sww=""1"" smm=""1"" cfu=""0"" lang=""" Lang """/>`n"
         . "        <MainKey ctrl=""0"" alt=""0"" shift=""0"" win=""1"">``</MainKey>`n"
         . "    </Options>`n"
         . "    <Hotkeys/>`n"
         . "</AHK-Toolkit>"
    FileAppend, % xml, %path%, UTF-8
    return ErrorLevel
}

; ---------------------------------------------------------------------------------------------
; 事件处理
; ---------------------------------------------------------------------------------------------
GuiHandler(){
    global
    if !a_gui
        return
    Gui, %a_gui%: submit, Nohide

    if (a_guicontrol = "_hkddl")                    ; 首次运行向导 / 首选项共用
    {
        PrefHotkeyDDL(a_gui)
        return
    }

    ; AutoHotkey ToolKit Gui（也是首次运行向导所在的 GUI 1）
    if (a_gui = 1)
    {
        if (a_guicontrol = "btnFirstSave")          ; 首次运行向导：生成默认配置并写入所选设置
        {
            defConf(script.conf)
            conf.load(script.conf)
            StorePrefs(False)                       ; 主热键稍后随 CreateGui() 一并注册
            Gui, 1: Destroy
            _frDone := True                         ; 放行 FirstRun() 中的等待，继续启动
            return
        }
        if (a_guicontrol = "QShk")
            FilterHK()
        else if (a_guicontrol = "btnAdd")
            OpenDlg(2)
        else if (a_guicontrol = "btnClose")
            Gui, 01: Hide
        return
    }

    ; 添加 / 编辑热键
    if (a_gui = 2)
    {
        if a_guicontrol in hkIns,hkDbl,hkRun,hkType,hkTypeB,hkTypeC        ; 这些开关会影响其他控件是否可用
            SyncDlg()
        else if (a_guicontrol = "btnHkBrowse")
        {
            Gui, 02: +OwnDialogs
            if hkTypeB
                FileSelectFolder, _p, *%A_ProgramFiles%, 3, % Tr("Please select the folder to launch.")
            else
                FileSelectFile, _p, 3, %A_ProgramFiles%, % Tr("Please select the file to launch.")
            if (_p != "")
            {
                GuiControl, 02:, hkPath, %_p%
                if (Trim(hkName) = "")
                {
                    SplitPath, _p,,,, _n
                    GuiControl, 02:, hkName, %_n%
                }
            }
        }
        else if (a_guicontrol = "btnHkOK")
        {
            if SaveHK()
                CloseDlg(2)
        }
        else if (a_guicontrol = "btnHkCancel")
            CloseDlg(2)
        return
    }

    ; 导入
    if (a_gui = 4)
    {
        if (a_guicontrol = "imType" || a_guicontrol = "imTypeB")        ; 切换「文件夹 / 文件」
        {
            if (a_guicontrol = "imType")
                GuiControl, 04: Enable, imRecurse
            else
                GuiControl, 04: Disable, imRecurse
            GuiControl, 04:, imPath, %A_MyDocuments%
        }
        else if (a_guicontrol = "btnImBrowse")
        {
            Gui, 04: +OwnDialogs
            if (imType = 1)
                FileSelectFolder, _p, *%A_MyDocuments%, 3, % Tr("Select the folder")
            else
            {
                FileSelectFile, _f, M3, %A_MyDocuments%, % Tr("Select the file"), AutoHotkey (*.ahk)
                _p := ""
                if InStr(_f, "`n")                  ; 多选：第 1 行为目录，其后每行一个文件名
                {
                    Loop, Parse, _f, `n
                    {
                        if (A_Index = 1)
                            _dir := RTrim(A_LoopField, "\")
                        else
                            _p .= (_p = "" ? "" : "|") _dir "\" A_LoopField
                    }
                }
                else
                    _p := _f                        ; 只选了一个文件时返回完整路径
            }
            if (_p != "")
                GuiControl, 04:, imPath, %_p%
        }
        else if (a_guicontrol = "btnImScan")
            ImportScan()
        else if (a_guicontrol = "btnImAccept")
        {
            ImportAccept()
            CloseDlg(4)
        }
        else if (a_guicontrol = "btnImClear")
        {
            Gui, 04: Default
            Gui, 04: ListView, imList
            LV_Delete()
            Gui, 01: Default
        }
        else if (a_guicontrol = "btnImCancel")
            CloseDlg(4)
        return
    }

    ; 导出
    if (a_gui = 5)
    {
        if (a_guicontrol = "btnExBrowse")
        {
            Gui, 05: +OwnDialogs
            FileSelectFile, _f, S24, % A_MyDocuments "\export_" SubStr(A_Now, 1, 8) ".ahk", % Tr("Save File as..."), *.ahk; *.txt
            if (_f != "")
                GuiControl, 05:, exPath, %_f%
        }
        else if (a_guicontrol = "btnExExport")
        {
            if DoExport()
                CloseDlg(5)
        }
        else if (a_guicontrol = "btnExCancel")
            CloseDlg(5)
        return
    }

    ; 首选项
    if (a_gui = 6)
    {
        if (a_guicontrol = "btnPrefOK")
        {
            _oldLang := Lang
            StorePrefs()
            script.autostart(_sww)
            CloseDlg(6)
            if (Cfg("Options/Startup/@lang") != _oldLang)       ; 语言变化：重新加载以重建全部界面
            {
                MsgBox, 0x40, % Tr("Preferences"), % Tr("Language changed. The program will reload to apply it.")
                Reload
            }
        }
        else if (a_guicontrol = "btnPrefClose")
            CloseDlg(6)
        return
    }

    ; 关于
    if (a_gui = 8)
    {
        if (a_guicontrol = "btnAboutClose")
            CloseDlg(8)
        return
    }
}

MenuHandler(){
    global
    local item := A_ThisMenuItem
    if (item = Tr("&New`t(Ctrl+N)"))
        OpenDlg(2)
    else if (item = Tr("Delete`t(DEL)"))
        DeleteSelected()
    else if (item = Tr("Import Hotkeys"))
        OpenDlg(4)
    else if (item = Tr("Export Hotkeys"))
        OpenDlg(5)
    else if (item = Tr("Always On Top"))
    {
        Menu, View, ToggleCheck, %item%
        _aot := !conf.documentElement.getAttribute("alwaysontop")
        _opt := _aot ? "+AlwaysOnTop" : "-AlwaysOnTop"
        Gui, 01: %_opt%
        conf.documentElement.setAttribute("alwaysontop", _aot ? 1 : 0)
        SaveConf()
    }
    else if (item = Tr("&Preferences`t(Ctrl+P)"))
        OpenDlg(6)
    else if (item = Tr("Check for Updates"))
        script.update(script.version)
    else if (item = Tr("About"))
        OpenDlg(8)
}

ListHandler(){
    global
    local row, k, f

    if (a_guicontrol = "hkList" || a_guicontrol = "shkList")
    {
        Gui, 01: Default
        Gui, 01: ListView, %a_guicontrol%
        if (a_guievent = "DoubleClick")
        {
            row := A_EventInfo                      ; 被双击的行，空白处为 0
            if !row
                OpenDlg(2)
            else
            {
                LV_GetText(k, row, 5)
                EditHK(k)
            }
        }
        else if (a_guievent = "K" && A_EventInfo = 46)      ; Delete 键
            DeleteSelected()
        return
    }

    if (a_guicontrol = "imList")
    {
        Gui, 04: Default
        Gui, 04: ListView, imList
        if (a_guievent = "DoubleClick" && A_EventInfo)      ; 用记事本打开来源文件，方便核对
        {
            LV_GetText(f, A_EventInfo, 4)
            Run, notepad.exe "%f%",, UseErrorLevel
        }
        else if (a_guievent = "K" && A_EventInfo = 46)      ; Delete 键：从导入列表中剔除选中项
        {
            while (row := LV_GetNext())
                LV_Delete(row)
        }
        Gui, 01: Default
    }
}



^F12::Suspend, Toggle
^CtrlBreak::Reload
#F11::KeyHistory                    ; 临时诊断：Win+F11 查看最近 500 个按键事件（见文件开头 #KeyHistory）

; ---------------------------------------------------------------------------------------------
; 按键抖动过滤（防止 Ctrl+C 时 C 键抖动，多出字母 c 覆盖掉选中文字）
; ---------------------------------------------------------------------------------------------
; 开关老化 / 进灰后，按下或松开的瞬间触点会反复通断，系统收到「↓↑↓↑」。多出来的那次↓若落在
; Ctrl 已松开之后，就成了字母 c。这里只拦截「刚松开又按下」的那一次按下，两条规则：
;   1) 距该键上次松开不到 DebounceMs                          → 抖动（普通打字、按住 Ctrl 时的连击）
;   2) 上一下是 Ctrl+C，这一下没有 Ctrl，且距松开不到 ChordMs → 抖动（专治 Ctrl+C 后冒出来的 c）
; 只拦截、不补发：放行的是系统原生按键，输入法 / 长按连发 / 其他钩子程序都不受影响；
; 只看物理按键，KeePass 自动输入、文本扩展等程序注入的按键一律放行；
; 被拦下的按下，其配对的弹起由 AHK 一并吞掉，放行的按下其弹起必定放行，不会卡键；
; #If 求值超时（见文件开头 #IfTimeout）时按键照常放行。别的键也抖，照抄这两行即可，如 *v:: / *v up::
#If ChatterGuard()
*c::return
*c up::return
#If

ChatterGuard(){
    static DebounceMs := 30, ChordMs := 150         ; 阈值（毫秒），说明见上
    static freq := 0, lastUp := {}, held := {}, chord := {}
    if !freq
        DllCall("QueryPerformanceFrequency", "Int64*", freq)
    DllCall("QueryPerformanceCounter", "Int64*", now)   ; 高精度计时（A_TickCount 精度约 16 ms，不够用）
    k := RegExReplace(A_ThisHotkey, "i)^\*|\s+up$")
    p := GetKeyState(k, "P")                        ; 钩子在求值前已按本次事件更新物理状态：物理按下=1，弹起或程序注入=0
    if RegExMatch(A_ThisHotkey, "i)\sup$")
    {
        ; 按下时 AHK 也会预先查询一次 up 变体（此时 p=1），只有真正的物理弹起才记时间
        if (!p && held[k])
            lastUp[k] := now, held[k] := False
        return False
    }
    if !p                                           ; 程序注入的按下：不过滤
        return False
    held[k] := True
    ctrl := GetKeyState("Ctrl")
    if lastUp.HasKey(k)
    {
        dt := (now - lastUp[k]) * 1000 / freq       ; 距上次物理松开的毫秒数
        if (dt < DebounceMs || (chord[k] && !ctrl && dt < ChordMs))
            return True                             ; 抖动：拦截这次按下
    }
    chord[k] := ctrl                                ; 放行：记下这一下是否按着 Ctrl
    return False
}


#include <FileSearch>

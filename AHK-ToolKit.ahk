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
                  ,version     : "0.9.0-161030"
                  ,author      : "RaptorX"
                  ,email       : "graptorx@gmail.com"
                  ,homepage    : "http://www.autohotkey.com/forum/topic61379.html#376087"
                  ,crtdate     : "July 11, 2010"
                  ,moddate     : "October 20, 2012"
                  ,conf        : "conf.xml"}
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
        Sent first as {Blind}{key}. Example: vk07 stops Shift hotkeys from toggling the IME.|先以 {Blind}{按键} 的形式发送，例如 vk07 可避免 Shift 热键触发输入法中英文切换。
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
        A hotkey with this key already exists.|该按键的热键已存在。
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
    Gui, 02: Add, Radio, x28 y100 Checked vhkType, % Tr("File")
    Gui, 02: Add, Radio, x+24 yp vhkTypeB, % Tr("Folder")
    Gui, 02: Add, Edit, x28 y130 w262 vhkPath
    Gui, 02: Add, Button, x298 y128 w84 h26 vbtnHkBrowse gGuiHandler, % Tr("&Browse...")

    Gui, 02: Add, GroupBox, x14 y192 w380 h74, % Tr("Select Hotkey")
    Gui, 02: Add, CheckBox, x28 y222 vhkctrl, Ctrl
    Gui, 02: Add, CheckBox, x80 y222 vhkalt, Alt
    Gui, 02: Add, CheckBox, x130 y222 vhkshift, Shift
    Gui, 02: Add, CheckBox, x190 y222 vhkwin, Win
    Gui, 02: Add, DropDownList, x244 y218 w136 R15 vhkey, % "None  " klist("all^", "mods")

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

    ; 插入按键：触发后先补发该按键，再启动目标（等价于 RunNoToggle：先发 {Blind}{vk07} 再 Run）
    Gui, 02: Add, CheckBox, x424 y204 w200 vhkIns gGuiHandler, % Tr("Insert key before launch")
    Gui, 02: Add, Edit, x632 y200 w96 vhkInsKey, vk07
    Gui, 02: Add, Text, x424 y230 w384 h30, % Tr("Sent first as {Blind}{key}. Example: vk07 stops Shift hotkeys from toggling the IME.")

    Gui, 02: Add, Button, x642 y282 w84 h28 Default vbtnHkOK gGuiHandler, % Tr("&Add")
    Gui, 02: Add, Button, x734 y282 w84 h28 vbtnHkCancel gGuiHandler, % Tr("&Cancel")

    Gui, 02: Show, w834 h326 Hide, % Tr("Add Hotkey")
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

    license := "Copyright ©2010-2012 " script.author " <GPLv3>`n`n"
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
        for i, c in ["hkctrl", "hkalt", "hkshift", "hkwin", "hkLMod", "hkRMod", "hkWild", "hkSend", "hkHook", "hkfRel", "hkIns"]
            GuiControl, 02:, %c%, 0
        DDLSelect(2, "hkey", "None")
        GuiControl, 02:, hkIfWin
        GuiControl, 02:, hkIfWinN
        GuiControl, 02:, hkInsKey, vk07
        GuiControl, 02: Disable, hkInsKey
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

; 注册 / 注销「主窗口热键」（读取 conf 中的 MainKey）
MainHotkey(state){
    mk := conf.selectSingleNode("/AHK-Toolkit/Options/MainKey")
    if !IsObject(mk)
        return
    mods := (mk.getAttribute("ctrl") ? "^" : "") (mk.getAttribute("alt") ? "!" : "")
          . (mk.getAttribute("shift") ? "+" : "") (mk.getAttribute("win") ? "#" : "")
    Hotkey, % mods mk.text, MainToggle, % state " UseErrorLevel"
}

; ---------------------------------------------------------------------------------------------
; 热键数据：加载 / 注册 / 保存 / 删除
; ---------------------------------------------------------------------------------------------
; 读取 conf.xml：注册全部热键并刷新列表（新增、编辑、删除之后都调用本函数）
Load(){
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
        err := HkSet(node, "On")
        if (err != "")
            bad .= "`n" err
    }
    AutoCols()
    GuiControl, 01: +Redraw, hkList
    FilterHK()
    UpdateSB()
    if (bad != "")
        MsgBox, 0x10, % Tr("Error"), % Tr("The hotkey could not be registered:`n{1}", bad)
}

; 只处理「文件 / 文件夹」两类热键
IsHK(node){
    t := node.getAttribute("type")
    return (t = "File" || t = "Folder")
}

; 向当前 ListView 追加一行：类型 / 名称 / 热键 / 路径 / 原始按键串（隐藏列）
AddRow(node){
    key := node.getAttribute("key")
    LV_Add("", Tr(node.getAttribute("type")), Sub(node, "name"), hkSwap(key, "long"), Sub(node, "path"), key)
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

; 注册(On) / 注销(Off) 一条热键，返回出错的按键名（成功返回空串）。
;  - 热键回调通过 Func.Bind 直接绑定「路径 / 插入键 / 排除列表」，触发时无需再读 XML：
;    既更快（插入键能在修饰键仍被按住时立即发出），也避免了依赖 A_ThisHotkey 字符串去反查节点
;    （原实现会把热键里的 ~ 前缀去掉再比较，导致勾选「透传(~)」的热键永远找不到节点而无法运行）。
;  - 窗口条件通过 Hotkey, IfWinActive / IfWinNotActive 上下文实现。
HkSet(node, state){
    key  := node.getAttribute("key")
    ins  := node.getAttribute("inskey")
    act  := Sub(node, "ifwinactive"), nact := Sub(node, "ifwinnotactive")
    if (state = "On")
        fn := Func("HotkeyHandler").Bind(Sub(node, "path"), ins, (act != "" && nact != "") ? nact : "")
    err := ""
    for i, c in HkContexts(act, nact)
    {
        if (c[1] = "IfWinActive")
            Hotkey, IfWinActive, % c[2]
        else if (c[1] = "IfWinNotActive")
            Hotkey, IfWinNotActive, % c[2]
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

; 把窗口条件转换为 Hotkey 上下文列表：
;  - 「激活」列表：每个标题各注册一份（任一窗口激活即触发）；
;  - 「非激活」列表：建立窗口组，用 IfWinNotActive ahk_group（所有窗口都不激活才触发）；
;  - 两者同时设置时，上下文只能承载一类条件，「非激活」改为在触发时检查（见 HotkeyHandler）。
HkContexts(act, nact){
    ctx := []
    if (act != "")
    {
        Loop, Parse, act, `,, %A_Space%%A_Tab%
            if (A_LoopField != "")
                ctx.Push(["IfWinActive", A_LoopField])
    }
    else if (nact != "")
        ctx.Push(["IfWinNotActive", "ahk_group " NActGroup(nact)])
    if !ctx.MaxIndex()
        ctx.Push(["", ""])
    return ctx
}

; 为「非激活」标题列表建立（并缓存）窗口组，返回组名
NActGroup(nact){
    static ids := {}, n := 0
    if !ids.HasKey(nact)
    {
        n++
        ids[nact] := "HKN" n
        Loop, Parse, nact, `,, %A_Space%%A_Tab%
            if (A_LoopField != "")
                GroupAdd, % ids[nact], %A_LoopField%
    }
    return ids[nact]
}

; 热键触发入口。参数均由 HkSet 通过 Bind 预先绑定：目标路径、插入键、需在触发时检查的「非激活」列表。
HotkeyHandler(path, ins, nact){
    if (nact != "" && WinActive("ahk_group " NActGroup(nact)))
        return
    ; 必须最先执行：趁修饰键（如 Shift）仍被按住时补发一个空键，让输入法不再把这次按键当作「单击 Shift」。
    ; {Blind} 保证不改变修饰键的当前状态。
    if (ins != "")
        SendInput, % "{Blind}{" ins "}"
    try
        Run, % path
    catch
        MsgBox, 0x10
              , % Tr("Error")
              , % Tr("The file this hotkey is trying to access does not exist.") "`n" path
}

; 保存「添加 / 编辑热键」对话框：校验 -> 注册 -> 写入 conf.xml -> 刷新。成功返回 True
SaveHK(){
    global
    local mk, mods, fullkey, ins, name, path, node, dup, err
    if (hkey = "None" || hkey = "")
    {
        MsgBox, 0x10, % Tr("Error while trying to create new Hotkey"), % Tr("Please select the key that you want to use as a hotkey.")
        return False
    }
    path := Trim(hkPath)
    if (path = "")
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
        ins := "vk07"
    SplitPath, path,,,, name
    name := Trim(hkName) != "" ? Trim(hkName) : name

    dup := FindHK(fullkey)
    if (IsObject(dup) && !(editingHK && fullkey = oldKey))
    {
        MsgBox, 0x10, % Tr("Error while trying to create new Hotkey"), % Tr("A hotkey with this key already exists.")
        return False
    }

    if editingHK
    {
        node := FindHK(oldKey)
        HkSet(node, "Off")                          ; 先注销旧按键（含旧的窗口条件），否则改键后旧按键仍然有效
    }
    else
        node := conf.selectSingleNode("/AHK-Toolkit/Hotkeys").appendChild(conf.createElement("hk"))

    node.setAttribute("type", (hkType = 2) ? "Folder" : "File")
    node.setAttribute("key", fullkey)
    if (ins != "")
        node.setAttribute("inskey", ins)
    else
        node.removeAttribute("inskey")
    SetChild(node, "name", name), SetChild(node, "path", path)
    SetChild(node, "ifwinactive", Trim(hkIfWin)), SetChild(node, "ifwinnotactive", Trim(hkIfWinN))

    err := HkSet(node, "On")
    if (err != "")                                  ; 按键无效：丢弃内存中的修改，从磁盘恢复并重新注册
    {
        MsgBox, 0x10, % Tr("Error"), % Tr("The hotkey could not be registered:`n{1}", err)
        conf.load(script.conf)
        Load()
        return False
    }
    SaveConf()
    Load()
    return True
}

; 双击列表条目：把节点内容回填到「添加热键」对话框进入编辑模式
EditHK(key){
    global
    local node, m, flags
    node := FindHK(key)
    if !IsObject(node)
        return
    GuiReset(2)
    editingHK := True, oldKey := key

    GuiControl, 02:, hkName, % Sub(node, "name")
    GuiControl, 02:, % (node.getAttribute("type") = "Folder") ? "hkTypeB" : "hkType", 1
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
        GuiControl, 02: Enable, hkInsKey
    }
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
    Load()
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
        if IsObject(FindHK(k))
        {
            skipped++
            continue
        }
        node := conf.selectSingleNode("/AHK-Toolkit/Hotkeys").appendChild(conf.createElement("hk"))
        node.setAttribute("type", (t = Tr("Folder")) ? "Folder" : "File")
        node.setAttribute("key", k)
        SplitPath, p,,,, name
        SetChild(node, "name", name), SetChild(node, "path", p)
        cnt++
    }
    SaveConf()
    Gui, 01: Default
    Load()
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
        if (a_guicontrol = "hkIns")                 ; 勾选「插入按键」时才允许修改按键名
        {
            if hkIns
                GuiControl, 02: Enable, hkInsKey
            else
                GuiControl, 02: Disable, hkInsKey
        }
        else if (a_guicontrol = "btnHkBrowse")
        {
            Gui, 02: +OwnDialogs
            if (hkType = 1)
                FileSelectFile, _p, 3, %A_ProgramFiles%, % Tr("Please select the file to launch.")
            else
                FileSelectFolder, _p, *%A_ProgramFiles%, 3, % Tr("Please select the folder to launch.")
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
;}

;[Hotkeys/Hotstrings]{
^F12::Suspend, Toggle
^CtrlBreak::Reload




;Shift组合快捷键与输入法切换的冲突解决方案
;~ ===============================================================================================
;~ ===============================================================================================
+z::RunNoToggle("D:\音速启动软件\TC操作\桌面.ahk")
+y::RunNoToggle("D:\常用的绿色软件\英语软件.txt")
+x::RunNoToggle("D:\音速启动软件\TC操作\桌面文件.ahk")
+w::RunNoToggle("D:\音速启动软件\TC操作\激活TC.ahk")
+u::RunNoToggle("D:\音速启动软件\U盘操作\U盘.ahk")
+t::RunNoToggle("D:\zrks键盘图.png")
+s::RunNoToggle("D:\音速启动软件\完美删除\删除.ahk")
+r::RunNoToggle("D:\音速启动软件\TC操作\绿色软件.ahk")
+q::RunNoToggle("D:\音速启动软件\TC操作\我的电脑.ahk")
+p::RunNoToggle("D:\音速启动软件\TC操作\程序文件.ahk")
+o::RunNoToggle("D:\股票操作.png")
+m::RunNoToggle("D:\MarkText图.png")
+k::RunNoToggle("D:\快捷键图.jpg")
+h::RunNoToggle("D:\音速启动软件\TC操作\H盘.ahk")
+g::RunNoToggle("D:\音速启动软件\TC操作\G盘.ahk")
+f::RunNoToggle("D:\音速启动软件\TC操作\F盘.ahk")
+e::RunNoToggle("D:\音速启动软件\TC操作\E盘.ahk")
+d::RunNoToggle("D:\音速启动软件\TC操作\D盘.ahk")
+c::RunNoToggle("D:\音速启动软件\TC操作\C盘.ahk")
+b::RunNoToggle("D:\音速启动软件\TC操作\博士学习.ahk")
+CapsLock::RunNoToggle("D:\音速启动软件\Candy\Candy菜单\Candy菜单.ahk")



; 运行指定脚本，同时阻止 WindInput 把这次 Shift 当成单击（不切中英文、不弹气泡）
RunNoToggle(path)
{
    SendInput {Blind}{vk07}                        ; 必须最先执行：趁 Shift 还按着补发空键
    run,%path%
    if ErrorLevel
        MsgBox, 无法运行：`n%path%
}
;~ ===============================================================================================














;添加鼠标第三个和第四个按键快捷键 
;~ ===============================================================================================
;添加中键移动多个屏幕窗口，靠近左顶点左移，否则右移
XButton1 UP::
CoordMode, Mouse, Relative  
MouseGetPos,  xpos, ypos, id, control
WinGetTitle, Win_Title,Ahk_ID %id%    ;当前进程的标题
WinGetPos, X, Y, Width, Height, Ahk_ID %id%
if (ypos>0 and ypos<DpiScale*50 and Win_Title<>"Program Manager")                                         ;启动两屏幕换移窗口按键
{
    if (xpos>=0 and  xpos<Width/2)  ;左移动窗口
        Sendinput,+#{Left}
    if (xpos>=Width/2 and  xpos<=Width)  ;右移动窗口
        Sendinput,+#{Right}    
    ;~ Run,D:\音速启动软件\中键触发两屏幕移动窗口.ahk
    return
}
if Vstate = 1
{
    Vstate := 0
    return
}
NewPID := AHK_Name("Candy菜单.ahk")
if NewPID = 0
        Run, D:\音速启动软件\Candy\Candy菜单\Candy菜单.ahk
else
	Click
return

XButton2 UP::
IniRead, This_Key, D:\音速启动软件\Alt Tab\Alt_Tab_Settings.ini, Press_key,This_Hotkey
IniWrite, *, D:\音速启动软件\Alt Tab\Alt_Tab_Settings.ini, Press_key,This_Hotkey
if (This_Key = "XButton2")
    Bstate = 1
if Bstate = 1
{
   ;关闭亮度调节的所需的服务
    NVDisplayService:="NVDisplay.ContainerLocalSystem"
    PIDCloseString=sc STOP  %NVDisplayService%
	StdoutToVar_CreateProcess(PIDCloseString)
    Bstate := 0
    return
}
	RunWait, D:\音速启动软件\Alt Tab\Alt_Tab.ahk

return
return
;~ ~MButton & WheelUp::
    ;~ KeyWait, MButton, U
          ;~ Run, D:\音速启动软件\Alt Tab\Alt_Tab.exe
    ;~ ;msgbox, %statem%
 ;~ return

; 查找「命令行中包含指定脚本名」的 AutoHotkey 进程，返回 PID（未找到返回 0）。
; 优化：原实现每次调用都新建两次 WMI 连接、遍历进程的全部属性并对每个进程调用 WinGetTitle，
; 在鼠标侧键松开（XButton1 UP）等高频场景下会同步阻塞主线程数百毫秒到数秒，
; 期间键盘/鼠标钩子无法被及时处理，是造成「Ctrl 状态丢失 → Ctrl+C 变成输入 c」的风险点之一。
; 现在：WMI 连接只建立一次并缓存，只做一次带过滤条件的查询，只读取 PID 与命令行两个属性。
AHK_Name(A_Name:="")
{
	static psvc
	if !psvc
		psvc := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
	for pobj in psvc.ExecQuery("SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name='AutoHotkey.exe' OR Name='InternalAHK.exe'")
		if InStr(pobj.CommandLine, A_Name)
			return pobj.ProcessId
	return 0
}
return



;添加鼠标滚筒左右键按键快捷键 
;~ ===============================================================================================
~WheelLeft::
  IfGreater, key_pres, 2, return
  key_pres++
  If (key_pres=1)
      T1 :=A_TickCount
  If (key_pres=2)
      T2 :=A_TickCount
  IfEqual, key_pres, 1, SetTimer, KeypC, -250
return
KeypC:
  T:=T2-T1
  MouseGetPos, , , id, Control
  WinGetTitle, title, ahk_id %id%
  WinGetClass, class, ahk_id %id%
  If key_pres = 1
    {
      If (title="Program Manager" or  class= "#32769" )
          Run, D:\音速启动软件\Alt Tab\Alt_Tab.ahk
      Else
	  {
			WinMinimize, ahk_id %id%
			Old_id:=id
	  }
      ;~ msgbox,一次
    }
  Else If key_pres = 2
    {
      If (T>120)
        {
          If (title="Program Manager" or  class= "#32769" )
            {
			  WinGetTitle, title, ahk_id %Old_id%
              If(DllCall("IsIconic", UInt, Old_id))                     ; check if minimized
              { 
                DllCall("ShowWindow", UInt, Old_id, UInt, 9) ; 9=SW_RESTORE
              }
        }
      Else
        {
         If (class= "TscShellContainerClass" )                      ;~ 远程桌面窗口特殊处理
            Run,D:\音速启动软件\远程桌面\远程连接.ahk
         else
         {
            WinGet, wid_MinMax, MinMax, ahk_id %id%
            If wid_MinMax =1
              WinRestore, ahk_id %id%
            Else If wid_MinMax =0
              WinMaximize,ahk_id %id%
         }

          ;~ msgbox,两次
        }
    }
  Else
    {
      gosub,长按
    }
  }
Else If key_pres > 2
  {
    gosub,长按
  }
key_pres = 0
return

长按:
  If (title<>"Program Manager"or  class<> "#32769")
      WinClose,ahk_id %id%
 sleep,100
  ;~ MsgBox,长按
return
;~ ===============================================================================================



;鼠标滚筒调节屏幕亮度
; ===============================================================================================
#If GetKeyState("XButton2", "P") 
WheelDown:: 
NVDisplayService :="NVDisplay.ContainerLocalSystem"
ServiceState:=Service_State(NVDisplayService)
if (ServiceState=1)
{
    PIDStartString=sc START  %NVDisplayService%
	StdoutToVar_CreateProcess(PIDStartString)
    Process, Wait , NVDisplay.Container.exe,3
}
MoveBrightness(1)
Bstate:=1
Return

Wheelup:: 
NVDisplayService :="NVDisplay.ContainerLocalSystem"
ServiceState:=Service_State(NVDisplayService)
if (ServiceState=1)
{
    PIDStartString=sc START  %NVDisplayService%
	StdoutToVar_CreateProcess(PIDStartString)
    Process, Wait , NVDisplay.Container.exe,3
}
MoveBrightness(-1)
Bstate:=1
Return

LButton::
Run,D:\音速启动软件\逻辑鼠标驱动.ahk
Bstate:=1
Return

MoveBrightness(IndexMove)
{

	VarSetCapacity(SupportedBrightness, 256, 0)
	VarSetCapacity(SupportedBrightnessSize, 4, 0)
	VarSetCapacity(BrightnessSize, 4, 0)
	VarSetCapacity(Brightness, 3, 0)
	
	hLCD := DllCall("CreateFile"
	, Str, "\\.\LCD"
	, UInt, 0x80000000 | 0x40000000 ;Read | Write
	, UInt, 0x1 | 0x2  ; File Read | File Write
	, UInt, 0
	, UInt, 0x3        ; open any existing file
	, UInt, 0
	, UInt, 0)
	
	if hLCD != -1
	{
		DevVideo := 0x00000023, BuffMethod := 0, Fileacces := 0
		  NumPut(0x03, Brightness, 0, "UChar")      ; 0x01 = Set AC, 0x02 = Set DC, 0x03 = Set both
		  NumPut(0x00, Brightness, 1, "UChar")      ; The AC brightness level
		  NumPut(0x00, Brightness, 2, "UChar")      ; The DC brightness level
		DllCall("DeviceIoControl"
		  , UInt, hLCD
		  , UInt, (DevVideo<<16 | 0x126<<2 | BuffMethod<<14 | Fileacces) ; IOCTL_VIDEO_QUERY_DISPLAY_BRIGHTNESS
		  , UInt, 0
		  , UInt, 0
		  , UInt, &Brightness
		  , UInt, 3
		  , UInt, &BrightnessSize
		  , UInt, 0)
		
		DllCall("DeviceIoControl"
		  , UInt, hLCD
		  , UInt, (DevVideo<<16 | 0x125<<2 | BuffMethod<<14 | Fileacces) ; IOCTL_VIDEO_QUERY_SUPPORTED_BRIGHTNESS
		  , UInt, 0
		  , UInt, 0
		  , UInt, &SupportedBrightness
		  , UInt, 256
		  , UInt, &SupportedBrightnessSize
		  , UInt, 0)
		
		ACBrightness := NumGet(Brightness, 1, "UChar")
		ACIndex := 0
		DCBrightness := NumGet(Brightness, 2, "UChar")
		DCIndex := 0
		BufferSize := NumGet(SupportedBrightnessSize, 0, "UInt")
		MaxIndex := BufferSize-1

		Loop, %BufferSize%
		{
		ThisIndex := A_Index-1
		ThisBrightness := NumGet(SupportedBrightness, ThisIndex, "UChar")
		if ACBrightness = %ThisBrightness%
			ACIndex := ThisIndex
		if DCBrightness = %ThisBrightness%
			DCIndex := ThisIndex
		}
		
		if DCIndex >= %ACIndex%
		  BrightnessIndex := DCIndex
		else
		  BrightnessIndex := ACIndex

		BrightnessIndex += IndexMove
		
		if BrightnessIndex > %MaxIndex%
		   BrightnessIndex := MaxIndex
		   
		if BrightnessIndex < 0
		   BrightnessIndex := 0

		NewBrightness := NumGet(SupportedBrightness, BrightnessIndex, "UChar")
		
		NumPut(0x03, Brightness, 0, "UChar")               ; 0x01 = Set AC, 0x02 = Set DC, 0x03 = Set both
                NumPut(NewBrightness, Brightness, 1, "UChar")      ; The AC brightness level
                NumPut(NewBrightness, Brightness, 2, "UChar")      ; The DC brightness level
		
		DllCall("DeviceIoControl"
			, UInt, hLCD
			, UInt, (DevVideo<<16 | 0x127<<2 | BuffMethod<<14 | Fileacces) ; IOCTL_VIDEO_SET_DISPLAY_BRIGHTNESS
			, UInt, &Brightness
			, UInt, 3
			, UInt, 0
			, UInt, 0
			, UInt, 0
			, Uint, 0)
		DllCall("CloseHandle", UInt, hLCD)
	}
  }
  StdoutToVar_CreateProcess(sCmd, bStream="", sDir="", sInput="")
{
   bStream=   ; not implemented
   DllCall("CreatePipe","Ptr*",hStdInRd,"Ptr*",hStdInWr,"Uint",0,"Uint",0)
   DllCall("CreatePipe","Ptr*",hStdOutRd,"Ptr*",hStdOutWr,"Uint",0,"Uint",0)
   DllCall("SetHandleInformation","Ptr",hStdInRd,"Uint",1,"Uint",1)
   DllCall("SetHandleInformation","Ptr",hStdOutWr,"Uint",1,"Uint",1)
   if A_PtrSize=4
    {
      VarSetCapacity(pi, 16, 0)
      sisize:=VarSetCapacity(si,68,0)
      NumPut(sisize,    si,  0, "UInt")
      NumPut(0x100,     si, 44, "UInt")
      NumPut(hStdInRd , si, 56, "Ptr")
      NumPut(hStdOutWr, si, 60, "Ptr")
      NumPut(hStdOutWr, si, 64, "Ptr")
    }
   else if A_PtrSize=8
    {
      VarSetCapacity(pi, 24, 0)
      sisize:=VarSetCapacity(si,96,0)
      NumPut(sisize,    si,  0, "UInt")
      NumPut(0x100,     si, 60, "UInt")
      NumPut(hStdInRd , si, 80, "Ptr")
      NumPut(hStdOutWr, si, 88, "Ptr")
      NumPut(hStdOutWr, si, 96, "Ptr")
    }
     DllCall("CreateProcess", "Uint", 0, "Ptr", &sCmd, "Uint", 0, "Uint", 0, "Int", True, "Uint", 0x08000000, "Uint", 0, "Ptr", sDir ? &sDir : 0, "Ptr", &si, "Ptr", &pi)
     DllCall("CloseHandle","Ptr",NumGet(pi,0))
     DllCall("CloseHandle","Ptr",NumGet(pi,A_PtrSize))
     DllCall("CloseHandle","Ptr",hStdOutWr)
     DllCall("CloseHandle","Ptr",hStdInRd)
     If   sInput <>
      FileOpen(hStdInWr, "h", "UTF-8").Write(sInput)
    DllCall("CloseHandle","Ptr",hStdInWr)
    VarSetCapacity(sTemp,4095)
   nSize:=0
   loop
    {
      result:=DllCall("Kernel32.dll\ReadFile", "Uint", hStdOutRd,  "Ptr", &sTemp, "Uint", 4095,"UintP", nSize,"Uint", 0)
      if (result="0")
         break
      else
         sOutput:= sOutput . StrGet(&sTemp,nSize,"cp936")
    }
   DllCall("CloseHandle","Ptr",hStdOutRd)
   Return,sOutput
}


Service_State(ServiceName)
{ ; Return Values
; SERVICE_STOPPED (1) : The service is not running.
; SERVICE_START_PENDING (2) : The service is starting.
; SERVICE_STOP_PENDING (3) : The service is stopping.
; SERVICE_RUNNING (4) : The service is running.
; SERVICE_CONTINUE_PENDING (5) : The service continue is pending.
; SERVICE_PAUSE_PENDING (6) : The service pause is pending.
; SERVICE_PAUSED (7) : The service is paused.
    SCM_HANDLE := DllCall("advapi32\OpenSCManagerW"
                        , "Int", 0 ;NULL for local
                        , "Int", 0
                        , "UInt", 0x1) ;SC_MANAGER_CONNECT (0x0001)
                            
    if !(SC_HANDLE := DllCall("advapi32\OpenServiceW"
                            , "UInt", SCM_HANDLE
                            , "Str", ServiceName
                            , "UInt", 0x4)) ;SERVICE_QUERY_STATUS (0x0004)
        result := -4 ;Service Not Found
    VarSetCapacity(SC_STATUS, 28, 0) ;SERVICE_STATUS Struct
    if !result
        result := !DllCall("advapi32\QueryServiceStatus"
                         , "UInt", SC_HANDLE
                         , "UInt", &SC_STATUS)
                         ? False : NumGet(SC_STATUS, 4) ;-1 or dwCurrentState
    DllCall("advapi32\CloseServiceHandle", "UInt", SC_HANDLE)
    DllCall("advapi32\CloseServiceHandle", "UInt", SCM_HANDLE)
    return result
}
  
Return

#If 


;鼠标滚筒调节声音大小
; ===============================================================================================
#If GetKeyState("XButton1", "P") 
WheelDown:: 
SoundSet +1
Vstate:=1
Return

Wheelup:: 
SoundSet -1
Vstate:=1
Return

LButton::
Run,D:\音速启动软件\JRiver加播放列表.ahk
Vstate:=1
Return
#If 
; ===============================================================================================




; ===============================================================================================
;双击Ctrl键激活搜索
; ============================================================
;~ #InstallMouseHook            ; 让A_PriorKey能看见鼠标事件：Ctrl+点击/Ctrl+滚轮 也会被正确"作废"
;~ lastCtrlUp := 0              ; 必须初始化！且必须放在脚本顶部自动执行段，
                             ;~ ; 否则空串按字符串比较恒小于250 → 启动后第一次单击就误触发
;~ ~Ctrl up::
    ;~ if (A_PriorKey != "LControl" && A_PriorKey != "RControl")
    ;~ {                                   ; 按住期间按过其他键(如Ctrl+C) → 作废
        ;~ lastCtrlUp := 0
        ;~ return
    ;~ }
    ;~ if (A_TickCount - lastCtrlUp < 250) ; 两次抬起间隔250ms内 → 双击成立
    ;~ {
        ;~ lastCtrlUp := 0                 ; 清零，防三连击重复触发
        ;~ Gosub, FileSearchKey
    ;~ }
    ;~ else
        ;~ lastCtrlUp := A_TickCount
;~ return

; Ctrl + CapsLock 激活搜索
!CapsLock::Gosub, FileSearchKey
; ===============================================================================================




; ===============================================================================================
;双击Alt键切换输入法模式
Alt::
KeyWait, Alt
KeyWait, Alt, D, T0.10
If ErrorLevel <> 1
    run,D:\音速启动软件\自动输入\AutoInput.ahk

return
; ===============================================================================================



; ===============================================================================================
;双击CapsLock键快速查询翻译字典

;~CapsLock::
;If (A_priorHotkey = "~CapsLock" and A_TimeSincePriorHotkey < 120 and !AHK_Name("一键翻译.ahk"))
;{
;       run D:\常用的绿色软件\AutoHotKey\AutoHotkey.exe D:\音速启动软件\一键翻译\一键翻译.ahk 1
;}
;return

^`::
   run D:\常用的绿色软件\AutoHotKey\AutoHotkey.exe D:\音速启动软件\一键翻译\一键翻译.ahk 1
return




; ===============================================================================================

; ===============================================================================================
#If mm=1  ; !!! works on ALL next hotkeys,标志特殊情况
~RButton Up::
        SetKeyDelay,0
        Send {Escape}
        loop 5
        {
            Send {Escape}
            sleep,1
        }
     mm:=0
Return
#If 
;窗口缩小
#If GetKeyState("RButton", "P")  ; !!! works on ALL next hotkeys
WheelDown:: 
  SetTimer, MouseMoveWinEnable,off
  mm:=1        ; !!!标志特殊情况
  SetWinDelay,0
  CoordMode,Mouse
  MouseGetPos,KDE_X1,KDE_Y1,KDE_id
  WinGetTitle, WinTitle, ahk_id %KDE_id%
  if (WinTitle="Program Manager")
    return
  WinGet,KDE_Win,MinMax,ahk_id %KDE_id%
  If (KDE_Win=1)
  {
        ; --
        ;鼠标移动带动窗口移动开启
        WinRestore, ahk_id %KDE_id%
            ; Get the initial window position.
        WinGetPos,KDE_WinX1,KDE_WinY1,KDE_WinW,KDE_WinH,ahk_id %KDE_id%
        SetTimer, MouseMoveWinEnable, 1
  }

 If (KDE_Win=0)
 {
    WinMinimize, ahk_id %KDE_id%
    IniWrite,%KDE_id%, D:\飞速启动软件\Alt_Tab_Settings.ini, WinIDMsg,WinMinimizeID
 }
Return

; 鼠标移动带动窗口移动功能，在程序定义段由定时器启动该功能
 MouseMoveWinEnable:
    CoordMode,Mouse
    GetKeyState,KDE_Button,RButton,P ; Break if button has been released.
    If KDE_Button = U
    {
        SetTimer, MouseMoveWinEnable,off
        return
    }
    MouseGetPos,KDE_X2,KDE_Y2 ; Get the current mouse position.
    KDE_X2 -= KDE_X1 ; Obtain an offset from the initial mouse position.
    KDE_Y2 -= KDE_Y1
    KDE_WinX2 := (KDE_WinX1 + KDE_X2) ; Apply this offset to the window position.
    KDE_WinY2 := (KDE_WinY1 + KDE_Y2)
    WinMove,ahk_id %KDE_id%,,%KDE_WinX2%,%KDE_WinY2% ; Move the window to the new position.
 return


;窗口放大
Wheelup:: 
 SetTimer, MouseMoveWinEnable,off
  mm:=1 
  SetWinDelay,0
  CoordMode,Mouse
  MouseGetPos,KDE_X1,KDE_Y1,KDE_id
  WinGetTitle, WinTitle, ahk_id %KDE_id%
  if (WinTitle="Program Manager")
        IniRead, KDE_id, D:\飞速启动软件\Alt_Tab_Settings.ini, WinIDMsg, WinMinimizeID
  WinGet,KDE_Win,MinMax,ahk_id %KDE_id%
  if(KDE_Win=-1)
  {
        ;鼠标移动带动窗口移动开启
        WinRestore, ahk_id %KDE_id%
            ; Get the initial window position.
        WinGetPos,KDE_WinX1,KDE_WinY1,KDE_WinW,KDE_WinH,ahk_id %KDE_id%
        SetTimer, MouseMoveWinEnable, on
  }

  if(KDE_Win=0)
        WinMaximize ,ahk_id %KDE_id%
return


;窗口移动调整大小
MButton::
     mm:=1 
     SetWinDelay,0
     CoordMode,Mouse
     MouseGetPos,KDE_X1,KDE_Y1,KDE_id
     WinGetTitle, WinTitle, ahk_id %KDE_id%
     if (WinTitle<>"Program Manager")
     {
        WinRestore,ahk_id %KDE_id%
      ; Get the initial window position and size.int", &wp)
        If KDE_Win
            WinGetPos,KDE_WinX1,KDE_WinY1,KDE_WinW,KDE_WinH,ahk_id %KDE_id%
        WinGetPos,KDE_WinX2,KDE_WinY2,KDE_WinW1,KDE_WinH1,ahk_id %KDE_id%
        ; Define the window region the mouse is currently in.nd Left, Down and Right.
        If (KDE_X1 < KDE_WinX1 + KDE_WinW / 2)
            KDE_WinLeft := 1
        ; The four regions are Up and Left, Up and Right, Down a
        Else
            KDE_WinLeft := -1
        If (KDE_Y1 < KDE_WinY1 + KDE_WinH / 2)
            KDE_WinUp := 1
        Else
            KDE_WinUp := -1
        Loop
        {
            GetKeyState,KDE_Button,RButton,P ; Break if button has been released.
            If KDE_Button = U
                break
            MouseGetPos,KDE_X2,KDE_Y2 ; Get the current mouse position.
            ; Get the current window position and size.
            WinGetPos,KDE_WinX1,KDE_WinY1,KDE_WinW,KDE_WinH,ahk_id %KDE_id%
            KDE_X2 -= KDE_X1 ; Obtain an offset from the initial mouse position.
            KDE_Y2 -= KDE_Y1
            ; Then, act according to the defined region.
            WinMove,ahk_id %KDE_id%,, KDE_WinX1 + (KDE_WinLeft+1)/2*KDE_X2  ; X of resized window
                            , KDE_WinY1 +   (KDE_WinUp+1)/2*KDE_Y2  ; Y of resized window
                            , KDE_WinW  -     KDE_WinLeft  *KDE_X2  ; W of resized window
                            , KDE_WinH  -       KDE_WinUp  *KDE_Y2  ; H of resized window
            KDE_X1 := (KDE_X2 + KDE_X1) ; Reset the initial position for the next iteration.
            KDE_Y1 := (KDE_Y2 + KDE_Y1)
        }
     }
return


LButton::
  mm:=1        ; !!!标志特殊情况
  SetWinDelay,2
  CoordMode,Mouse
  MouseGetPos,KDE_X1,KDE_Y1,KDE_id
  WinGetTitle, WinTitle, ahk_id %KDE_id%
  if (WinTitle<>"Program Manager")
     WinMinimize,ahk_id %KDE_id%
return

#If 

 ; 激活翻译工具
#If GetKeyState("LButton", "P")  ; !!! works on ALL next hotkeys
RButton:: 
    TranslatePID := AHK_Name("一键翻译.ahk")
    if TranslatePID = 0
        Run, D:\音速启动软件\一键翻译\一键翻译.ahk
    else
    {
        Process, Close, %TranslatePID%
        tooltip,程序已退出！
        sleep,300
        tooltip
    }
return
#If 
; ===============================================================================================
;} 

; 个人化的窗口专用热键（保持原样）
#ifwinactive, .*Nikronius
pgDn::Send !{Space}n
#ifwinactive


/*
 * * * Compile_AHK SETTINGS BEGIN * * *
[AHK2EXE]
Exe_File=%In_Dir%\lib\AHK-ToolKit.exe
Alt_Bin=C:\Program Files\AutoHotkeyW\Compiler\AutoHotkeySC.bin
[VERSION]
Set_Version_Info=1
File_Version=0.9.0-161030
Inc_File_Version=0
Internal_Name=AHK-TK
Legal_Copyright=GNU General Public License 3.0
Original_Filename=AutoHotkey Toolkit.exe
Product_Name=AutoHotkey Toolkit
Product_Version=0.9.0-161030
[ICONS]
Icon_1=%In_Dir%\res\AHK-TK.ico
Icon_2=%In_Dir%\res\AHK-TK.ico
Icon_3=%In_Dir%\res\AHK-TK.ico
Icon_4=%In_Dir%\res\AHK-TK.ico
Icon_5=%In_Dir%\res\AHK-TK.ico
Icon_6=%In_Dir%\res\AHK-TK.ico
Icon_7=%In_Dir%\res\AHK-TK.ico

* * * Compile_AHK SETTINGS END * * *
*/

#include <FileSearch>

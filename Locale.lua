local _, ns = ...
local en = {
    theme="Theme accent", chooseColor="Choose color", useTheme="Use accent for cast fill",
    width="Width", height="Height", fontSize="Font size", tickWidth="Tick width (0 = off)",
    border="Border (0 = none)", fade="Fade time (s)", icon="Show spell icon", latency="Show latency zone",
    queue="Show spell queue zone", queueWindow="Queue window (ms)", queueColor="Queue zone color",
    latencyColor="Latency zone color", tickColor="Tick color", borderColor="Border color",
    x="X (pixels)", y="Y (pixels)", reset="Restore defaults", hint="Drag the bar to move it. Close to lock."
}
local tw = {
    theme="主題強調色", chooseColor="選擇顏色", useTheme="施法條使用主題色",
    width="寬度", height="高度", fontSize="字體大小", tickWidth="引導刻度（0 為關閉）",
    border="邊框（0 為關閉）", fade="淡出時間（秒）", icon="顯示技能圖標", latency="顯示延遲區域",
    queue="顯示施法佇列區域", queueWindow="施法佇列時間（毫秒）", queueColor="佇列區域顏色",
    latencyColor="延遲區域顏色", tickColor="刻度顏色", borderColor="邊框顏色",
    x="水平位置（像素）", y="垂直位置（像素）", reset="恢復預設", hint="拖動施法條移動位置；關閉視窗後鎖定。"
}
local cn = {
    theme="主题强调色", chooseColor="选择颜色", useTheme="施法条使用主题色",
    width="宽度", height="高度", fontSize="字体大小", tickWidth="引导刻度（0 为关闭）",
    border="边框（0 为关闭）", fade="淡出时间（秒）", icon="显示技能图标", latency="显示延迟区域",
    queue="显示施法队列区域", queueWindow="施法队列时间（毫秒）", queueColor="队列区域颜色",
    latencyColor="延迟区域颜色", tickColor="刻度颜色", borderColor="边框颜色",
    x="水平位置（像素）", y="垂直位置（像素）", reset="恢复默认", hint="拖动施法条移动位置；关闭窗口后锁定。"
}
local extra = {
    en = { appearance="Appearance", layout="Layout", behavior="Casting", subtitle="PERSONAL CAST BAR", description="Customize your cast bar", accentTitle="ACCENT COLOR", cardTitle="CARD & GLOW", geometryTitle="SIZE & POSITION", behaviorTitle="CASTING & INDICATORS", cardPadding="Card padding", iconScale="Icon scale", glowIntensity="Glow intensity", fillOpacity="Progress opacity", backgroundOpacity="Background opacity", showGlow="Show glow", pulseGlow="Pulse glow", about="Changes preview instantly. Drag the cast bar to move it.", presets="Presets", version="FOREVER EDITION", resetHint="Reset all settings and the game's spell queue window." },
    tw = { appearance="外觀主題", layout="尺寸與位置", behavior="施法行為", subtitle="個人施法條", description="打造專屬於你的施法條", accentTitle="主題強調色", cardTitle="卡片與光暈", geometryTitle="尺寸與位置", behaviorTitle="施法與指示", cardPadding="卡片內距", iconScale="圖標大小", glowIntensity="光暈強度", fillOpacity="進度透明度", backgroundOpacity="背景透明度", showGlow="顯示光暈", pulseGlow="光暈呼吸效果", about="修改立即預覽；拖動施法條可調整位置。", presets="預設色", version="永恆服專用", resetHint="重置所有設置及遊戲的施法佇列時間。" },
    cn = { appearance="外观主题", layout="尺寸与位置", behavior="施法行为", subtitle="个人施法条", description="打造专属于你的施法条", accentTitle="主题强调色", cardTitle="卡片与光晕", geometryTitle="尺寸与位置", behaviorTitle="施法与指示", cardPadding="卡片内距", iconScale="图标大小", glowIntensity="光晕强度", fillOpacity="进度透明度", backgroundOpacity="背景透明度", showGlow="显示光晕", pulseGlow="光晕呼吸效果", about="修改立即预览；拖动施法条可调整位置。", presets="预设色", version="永恒服专用", resetHint="重置所有设置及游戏的施法队列时间。" },
}
extra.en.opening = "Opening"
extra.tw.opening = "開啟中"
extra.cn.opening = "开启中"
extra.en.latencyPage = "Latency text"
extra.tw.latencyPage = "延遲文字"
extra.cn.latencyPage = "延迟文字"
extra.en.latencyTitle = "CAST LATENCY DISPLAY"
extra.tw.latencyTitle = "施法延遲顯示"
extra.cn.latencyTitle = "施法延迟显示"
extra.en.showLatencyText = "Show latency value"
extra.tw.showLatencyText = "顯示延遲數值"
extra.cn.showLatencyText = "显示延迟数值"
extra.en.latencyFontSize = "Latency font size"
extra.tw.latencyFontSize = "延遲字體大小"
extra.cn.latencyFontSize = "延迟字体大小"
extra.en.latencyTextColor = "Latency text color"
extra.tw.latencyTextColor = "延遲文字顏色"
extra.cn.latencyTextColor = "延迟文字颜色"
extra.en.latencyFont = "Shared font"
extra.tw.latencyFont = "共享字體"
extra.cn.latencyFont = "共享字体"
extra.en.defaultFont = "Game default"
extra.tw.defaultFont = "跟隨遊戲字體"
extra.cn.defaultFont = "跟随游戏字体"
extra.en.fontPath = "Or enter an in-game font path, then press Enter"
extra.tw.fontPath = "或輸入遊戲內字體路徑，按 Enter 套用"
extra.cn.fontPath = "或输入游戏内字体路径，按 Enter 应用"
extra.en.latencyHint = "Time from cast request to cast start (ms). -- means unavailable."
extra.tw.latencyHint = "施法延遲顯示在施法條旁，單位為毫秒。"
extra.cn.latencyHint = "施法延迟显示在施法条旁，单位为毫秒。"
local locale = GetLocale and GetLocale() or "enUS"
ns.L = locale == "zhTW" and tw or locale == "zhCN" and cn or en

local more = locale == "zhTW" and extra.tw or locale == "zhCN" and extra.cn or extra.en
for key, value in pairs(more) do ns.L[key] = value end

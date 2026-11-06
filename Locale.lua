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
local locale = GetLocale and GetLocale() or "enUS"
ns.L = locale == "zhTW" and tw or locale == "zhCN" and cn or en

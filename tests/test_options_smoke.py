from pathlib import Path
from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]

def test_options_open_navigate_and_close_with_mock_ui():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(r'''
        unpack = table.unpack; tinsert = table.insert
        UISpecialFrames = {}; SlashCmdList = {}; Enum = nil
        local frames = {}
        local methods = {}
        local mt = {__index = function(self,k) return methods[k] or function() end end}
        function CreateFrame(kind, name, parent, template)
            local f = setmetatable({shown=true,scripts={},kind=kind,name=name}, mt)
            frames[#frames+1] = f
            return f
        end
        function methods:CreateTexture() return CreateFrame('Texture') end
        function methods:CreateFontString() return CreateFrame('FontString') end
        function methods:GetThumbTexture() return CreateFrame('Texture') end
        function methods:SetScript(event, fn) self.scripts[event] = fn end
        function methods:HookScript(event, fn) self.scripts[event] = fn end
        function methods:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
        function methods:Show() self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
        function methods:SetShown(value) if value then self:Show() else self:Hide() end end
        function methods:IsShown() return self.shown end
        function methods:GetWidth() return 1000 end
        function methods:GetHeight() return 700 end
        function methods:GetStringWidth() return 50 end
        function methods:GetRight() return 0 end
        function methods:GetChecked() return false end
        function methods:SetText(v) self.text=v end
        UIParent=CreateFrame('UIParent'); Minimap=CreateFrame('Minimap'); GameTooltip=CreateFrame('Tooltip')
        local function noop() end
        local L=setmetatable({}, {__index=function(_,k) return k end})
        local cfg={width=240,height=21,fontSize=12,cardPadding=9,iconScale=1,glowIntensity=.95,fillOpacity=.22,backgroundOpacity=.96,fadeTime=1,tickWidth=1,borderSize=2,showIcon=true,showLatency=true,showQueue=true,showGlow=true,pulseGlow=true}
        local limits={}
        for _,k in ipairs({'width','height','fontSize','cardPadding','iconScale','glowIntensity','fillOpacity','backgroundOpacity','fadeTime','tickWidth'}) do limits[k]={1,100,1} end
        local bar=CreateFrame('Bar'); bar.px=1
        ns={L=L,CONFIG=cfg,LIMITS=limits,PALETTE={},COLOR_ALPHA={},GetBar=function() return bar end,
            IsDefault=function() return true end,GetQueueMs=function() return 400 end,
            GetPosition=function() return 0,0 end, GetBarShift=function() return 0 end,
            Range=function() return 1,100 end,SetUnlocked=noop,SetSetting=noop,SetPosition=noop,
            Redraw=noop,RestoreDefaults=noop,ColorUsable=function() return true end}
        NeonCastDB={config={}}
        function navigate()
            for _, f in ipairs(frames) do
                if f.kind == 'Button' and f.scripts.OnClick and not f.name then
                    -- Navigation buttons have the colored selection marker.
                    if f.marker then f.scripts.OnClick(f) end
                end
            end
        end
    ''')
    lua.execute((ROOT / 'Options.lua').read_text(encoding='utf-8-sig'), 'NeonCast', lua.globals().ns)
    lua.globals().ns.ToggleOptions()
    lua.globals().navigate()
    lua.globals().ns.ToggleOptions()

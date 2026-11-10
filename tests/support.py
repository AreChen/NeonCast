from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]

def addon(locale='enUS', saved=None, gamepad=False, runtime=LuaRuntime):
    lua = runtime(unpack_returned_tuples=True)
    lua.execute(r'''
        unpack = unpack or table.unpack
        tinsert = table.insert
        now = 10; combat = false; gamepad = false; frames = {}; ns = {}
        local methods = {}
        local function noop() end
        for _, key in ipairs({'SetOrientation','SetValueStep','SetObeyStepOnDrag','SetFontObject',
          'SetJustifyH','SetWordWrap','SetAutoFocus','SetMaxLetters','SetTexCoord','SetVertexColor',
          'SetColorTexture','SetGradient','SetBlendMode','SetClipsChildren','SetMovable','EnableMouse',
          'RegisterForDrag','RegisterForClicks','SetFrameStrata','SetClampedToScreen','StartMoving',
          'StopMovingOrSizing','SetLooping','SetFromAlpha','SetToAlpha','SetDuration','SetSmoothing',
          'SetOwner','AddLine','ClearFocus','SetHighlightTexture','SetTextureSliceMargins','SetTextureSliceMode'}) do
            methods[key] = noop
        end
        function CreateFrame(kind, name, parent, template)
            local f = setmetatable({kind=kind,name=name,parent=parent,shown=true,scripts={},events={},width=1,height=1,alpha=1,enabled=true}, {__index=methods})
            frames[#frames+1]=f
            if name then _G[name]=f end
            return f
        end
        function methods:CreateTexture() return CreateFrame('Texture',nil,self) end
        function methods:CreateFontString() return CreateFrame('FontString',nil,self) end
        function methods:CreateAnimationGroup() return CreateFrame('AnimationGroup',nil,self) end
        function methods:CreateAnimation() return CreateFrame('Animation',nil,self) end
        function methods:Play() self.playing=true end
        function methods:Stop() self.playing=false end
        function methods:IsPlaying() return self.playing end
        function methods:SetParent(p) self.parent=p end
        function methods:GetParent() return self.parent end
        function methods:IsObjectType(kind) return self.kind==kind end
        function methods:SetSize(w,h) self.width=w; self.height=h end
        function methods:SetWidth(w) self.width=w end
        function methods:SetHeight(h) self.height=h end
        function methods:GetWidth() return self.width end
        function methods:GetHeight() return self.height end
        function methods:GetSize() return self.width,self.height end
        function methods:SetScale(s) self.scale=s end
        function methods:GetEffectiveScale() return self.scale or (self.parent and self.parent:GetEffectiveScale()) or 1 end
        function methods:GetScale() return self.scale or 1 end
        function methods:SetPoint(...) self.point={...} end
        function methods:ClearAllPoints() self.point=nil end
        function methods:SetAllPoints(p) self.allPoints=p end
        function methods:GetRight() return 0 end
        function methods:GetCenter() return 500,350 end
        function methods:SetFrameLevel(n) self.level=n end
        function methods:GetFrameLevel() return self.level or 1 end
        function methods:SetAlpha(a) self.alpha=a end
        function methods:GetAlpha() return self.alpha end
        function methods:SetFontString(f) self.fontString=f end
        function methods:SetText(t) self.text=t;if self.fontString then self.fontString:SetText(t) end end
        function methods:GetText() return self.text or '' end
        function methods:SetFormattedText(fmt,...) self:SetText(string.format(fmt,...)) end
        function methods:GetStringWidth() return #self:GetText()*6 end
        function methods:GetStringHeight() return self.fontSize or 12 end
        function methods:SetFont(path,size,flags) self.font=path;self.fontSize=size;self.flags=flags;return true end
        function methods:GetFont() return self.font or 'Fonts/FRIZQT__.TTF',self.fontSize or 12,self.flags end
        function methods:GetTextColor() return 1,1,1 end
        function methods:SetTextColor(...) self.textColor={...} end
        function methods:SetTexture(t) self.texture=t end
        function methods:SetThumbTexture(t) self.thumb=CreateFrame('Texture',nil,self) end
        function methods:GetThumbTexture() return self.thumb end
        function methods:SetMinMaxValues(a,b) self.min=a;self.max=b end
        function methods:SetValue(v) self.value=v;if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v) end end
        function methods:GetValue() return self.value end
        function methods:Enable() self.enabled=true end
        function methods:Disable() self.enabled=false end
        function methods:IsEnabled() return self.enabled end
        function methods:Click() if self.enabled and self.scripts.OnClick then self.scripts.OnClick(self) end end
        function methods:SetScript(event,fn) self.scripts[event]=fn end
        function methods:GetScript(event) return self.scripts[event] end
        function methods:HookScript(event,fn)
            local old=self.scripts[event]
            self.scripts[event]=function(...) if old then old(...) end; fn(...) end
        end
        function methods:Hide() local changed=self.shown;self.shown=false;if changed and self.scripts.OnHide then self.scripts.OnHide(self) end end
        function methods:Show() local changed=not self.shown;self.shown=true;if changed and self.scripts.OnShow then self.scripts.OnShow(self) end end
        function methods:SetShown(on) if on then self:Show() else self:Hide() end end
        function methods:IsShown() return self.shown end
        function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
        function methods:RegisterEvent(event) self.events[event]=true end
        methods.RegisterUnitEvent=methods.RegisterEvent
        function methods:UnregisterAllEvents() self.events={} end
        function dispatch(event,...)
            local count=#frames
            for i=1,count do local f=frames[i];if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f,event,...) end end
        end
        function clickText(text)
            for _,f in ipairs(frames) do if f.kind=='Button' and f:GetText()==text and f:IsVisible() then f:Click();return true end end
            error('No visible button: '..text)
        end
        function findButton(text)
            for _,f in ipairs(frames) do if f.kind=='Button' and f:GetText()==text then return f end end
        end
        UIParent=CreateFrame('Frame');UIParent:SetSize(1280,720)
        Minimap=CreateFrame('Frame');Minimap:SetSize(140,140)
        GameTooltip=CreateFrame('Frame');GameFontHighlight=CreateFrame('FontString')
        UISpecialFrames={};SlashCmdList={};NeonCastDB={config={}}
        C_CVar={GetCVar=function() return tostring(queueWindow) end,SetCVar=function(_,value) queueWindow=value end}
        queueWindow=270
        function GetTime() return now end
        function GetTimePreciseSec() return now end
        function GetPhysicalScreenSize() return 1280,768 end
        function UnitGUID() return 'player-guid' end
        function UnitCastingInfo() if currentCast then return unpack(currentCast) end end
        function UnitChannelInfo() if currentChannel then return unpack(currentChannel) end end
        function GetLocale() return 'enUS' end
        function InCombatLockdown() return combat end
        InputUtil={IsGamepadUIEnabled=function() return gamepad end}
        C_Timer={After=function(_,f) f() end}
        C_Spell={GetSpellName=function(id) return 'Spell '..id end,GetSpellTexture=function() return 123 end,GetSpellDescription=function() return '' end}
        function hooksecurefunc() end
        navShown=0;navHidden=0
        GamepadMode={FrameControlsManager={FrameShown=function() navShown=navShown+1 end,FrameHidden=function() navHidden=navHidden+1 end}}
        function SmartNavigation_MarkFrameIgnored(f) f.ignored=true end
    ''')
    lua.globals().GetLocale = lambda: locale
    lua.globals().gamepad = gamepad
    if saved:
        lua.execute('NeonCastDB = '+saved)
    ns=lua.globals().ns
    for path in (ROOT/'NeonCast.toc').read_text().splitlines():
        if path.endswith('.lua'):
            lua.execute((ROOT/path).read_text(encoding='utf-8-sig'),'NeonCast',ns)
    lua.globals().dispatch('PLAYER_LOGIN')
    return lua, ns

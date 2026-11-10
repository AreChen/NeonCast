-- Shared visual tokens and native UI primitives. No external skin dependency.
local _, ns = ...
local T = {}
ns.Theme = T
T.colors = {
    panel = {0.025, 0.035, 0.062}, card = {0.045, 0.060, 0.092},
    inset = {0.018, 0.027, 0.045}, text = {0.90, 0.94, 1.00}, muted = {0.46, 0.55, 0.68},
}
T.presets = {
    {key='glacier', r=0.20, g=0.82, b=1.00},
    {key='amethyst', r=0.64, g=0.48, b=1.00},
    {key='jade', r=0.24, g=0.91, b=0.69},
    {key='ember', r=1.00, g=0.57, b=0.26},
    {key='rose', r=1.00, g=0.36, b=0.62},
}
local listeners = {}
function T.Accent() return (NeonCastDB and NeonCastDB.accent) or T.presets[1] end
function T.Observe(fn) listeners[#listeners+1] = fn; fn(T.Accent()) end
function T.Refresh() for _, fn in ipairs(listeners) do fn(T.Accent()) end end
function T.Gradient(texture, left, right)
    if CreateColor then
        local ok = pcall(texture.SetGradient, texture, 'HORIZONTAL', CreateColor(unpack(left)), CreateColor(unpack(right)))
        if ok then return end
    end
    texture:SetColorTexture(left[1],left[2],left[3],left[4] or 1)
end
function T.Texture(parent, layer, color, alpha, sublevel)
    local t = parent:CreateTexture(nil, layer or 'BACKGROUND', nil, sublevel)
    t:SetColorTexture(color[1],color[2],color[3],alpha or 1)
    return t
end
local function sliced(parent, asset, layer, sublevel)
    local t = parent:CreateTexture(nil,layer,nil,sublevel)
    t:SetAllPoints()
    t:SetTexture('Interface\\AddOns\\NeonCast\\Media\\' .. asset)
    if t.SetTextureSliceMargins then
        t:SetTextureSliceMargins(16,16,16,16)
        if t.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then t:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched) end
    end
    return t
end
function T.Surface(parent, color, alpha, edgeAlpha)
    local bg = sliced(parent,'NeonBack','BACKGROUND',-2)
    bg:SetVertexColor(color[1],color[2],color[3],alpha or 1)
    local edge = sliced(parent,'NeonRing','BORDER',0)
    T.Observe(function(c) edge:SetVertexColor(c.r,c.g,c.b,edgeAlpha or 0.12) end)
    return bg,edge
end
function T.Button(parent)
    local b = CreateFrame('Button',nil,parent)
    local bg, edge = T.Surface(b,{0.065,0.085,0.12},1,0.14)
    local text = b:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
    text:SetPoint('CENTER'); text:SetTextColor(unpack(T.colors.text))
    b:SetFontString(text)
    b.caption = text
    local hover = T.Texture(b,'HIGHLIGHT',{1,1,1},0.07); hover:SetAllPoints()
    local active = false
    function b.SetSelected(selected)
        active = selected
        local c = T.Accent()
        bg:SetVertexColor(active and c.r*0.15 or 0.065,active and c.g*0.15 or 0.085,active and c.b*0.15 or 0.12,1)
        edge:SetVertexColor(c.r,c.g,c.b,active and 0.7 or 0.14)
        text:SetTextColor(active and c.r or 0.9,active and c.g or 0.94,active and c.b or 1)
    end
    T.Observe(function() b.SetSelected(active) end)
    b:HookScript('OnEnable',function() text:SetAlpha(1) end)
    b:HookScript('OnDisable',function() text:SetAlpha(0.35) end)
    return b
end
function T.Focus(button)
    if button.neonFocus then return end
    local focus = sliced(button,'NeonRing','HIGHLIGHT',1)
    focus:ClearAllPoints(); focus:SetPoint('TOPLEFT',-2,2);focus:SetPoint('BOTTOMRIGHT',2,-2)
    T.Observe(function(c) focus:SetVertexColor(c.r,c.g,c.b,0.95) end)
    button.neonFocus = focus
end
function T.Sample(parent)
    local sample = CreateFrame('Frame',nil,parent)
    sample:SetSize(370,34);sample:SetPoint('BOTTOMLEFT',parent,'BOTTOMLEFT',36,18)
    T.Surface(sample,T.colors.inset,0.98,0.36)
    local icon = sample:CreateTexture(nil,'ARTWORK');icon:SetTexture('Interface\\Icons\\Spell_Fire_FlameBolt')
    icon:SetSize(24,24);icon:SetPoint('LEFT',7,0);icon:SetTexCoord(0.08,0.92,0.08,0.92)
    local fill=T.Texture(sample,'ARTWORK',{0.2,0.82,1},0.3)
    fill:SetPoint('TOPLEFT',sample,'TOPLEFT',38,-5);fill:SetPoint('BOTTOMLEFT',sample,'BOTTOMLEFT',38,5);fill:SetWidth(224)
    local edge=T.Texture(sample,'ARTWORK',{0.4,0.9,1},1)
    edge:SetPoint('TOPLEFT',fill,'TOPRIGHT',0,0);edge:SetPoint('BOTTOMLEFT',fill,'BOTTOMRIGHT',0,0);edge:SetWidth(2)
    local name=sample:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');name:SetPoint('LEFT',44,0);name:SetText(ns.L.previewSpell)
    local time=sample:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');time:SetPoint('RIGHT',-10,0);time:SetText('0.8')
    local response=sample:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');response:SetPoint('LEFT',sample,'RIGHT',12,0);response:SetText('52 ms')
    T.Observe(function(c)
        T.Gradient(fill,{c.r,c.g,c.b,0.12},{c.r,c.g,c.b,0.4})
        edge:SetColorTexture(c.r,c.g,c.b,0.95);response:SetTextColor(c.r,c.g,c.b)
    end)
    return sample
end

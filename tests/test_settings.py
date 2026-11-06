from pathlib import Path
from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]

def test_visual_settings_are_validated_saved_and_reset():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('''
        unpack=table.unpack
        local methods={}
        local mt={__index=function(_,key) return methods[key] or function() end end}
        function CreateFrame() return setmetatable({},mt) end
        UIParent=CreateFrame(); GameFontHighlight=CreateFrame()
        function methods:GetFont() return 'font',12 end
        function GetCVar() return '400' end
        function SetCVar() end
        NeonCastDB={config={}}
        ns={}
    ''')
    ns = lua.globals().ns
    lua.execute((ROOT / 'Data.lua').read_text(encoding='utf-8-sig'), 'NeonCast', ns)
    lua.execute((ROOT / 'Core.lua').read_text(encoding='utf-8-sig'), 'NeonCast', ns)
    ns.SetSetting('cardPadding', 100)
    assert ns.CONFIG.cardPadding == 22
    assert lua.globals().NeonCastDB.config.cardPadding == 22
    ns.SetSetting('iconScale', 0.1)
    assert ns.CONFIG.iconScale == 0.5
    ns.SetSetting('fillOpacity', 0.55)
    assert ns.CONFIG.fillOpacity == 0.55
    ns.SetSetting('showGlow', False)
    assert ns.CONFIG.showGlow is False
    lua.globals().NeonCastDB.accent = lua.table_from({'r': 1, 'g': 0, 'b': 0})
    ns.RestoreDefaults()
    assert ns.CONFIG.cardPadding == 9
    assert ns.CONFIG.showGlow is True
    assert lua.globals().NeonCastDB.accent is None

def test_custom_indicator_colors_are_saved_and_validated():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('''
        unpack=table.unpack
        local methods={}
        local mt={__index=function(_,key) return methods[key] or function() end end}
        function CreateFrame() return setmetatable({},mt) end
        UIParent=CreateFrame(); GameFontHighlight=CreateFrame()
        function methods:GetFont() return 'font',12 end
        function GetCVar() return '400' end
        function SetCVar() end
        NeonCastDB={config={}}; ns={}
    ''')
    ns = lua.globals().ns
    lua.execute((ROOT / 'Data.lua').read_text(encoding='utf-8-sig'), 'NeonCast', ns)
    lua.execute((ROOT / 'Core.lua').read_text(encoding='utf-8-sig'), 'NeonCast', ns)
    color = lua.table_from({'r': 0.2, 'g': 0.4, 'b': 0.7})
    ns.SetSetting('queueColor', color)
    assert lua.globals().NeonCastDB.config.queueColor.r == 0.2
    assert ns.GetPartColor('queueColor') == (0.2, 0.4, 0.7, 0.4)
    ns.SetSetting('queueColor', lua.table_from({'r': 2, 'g': 0, 'b': 0}))
    assert ns.CONFIG.queueColor.r == 0.2
    ns.RestoreDefaults()
    assert ns.CONFIG.queueColor == 'red'

def test_opening_spell_label_and_latency_options():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('''
        unpack=table.unpack
        local methods={}; local mt={__index=function(_,key) return methods[key] or function() end end}
        function CreateFrame() return setmetatable({},mt) end
        UIParent=CreateFrame(); GameFontHighlight=CreateFrame()
        function methods:GetFont() return 'font',12 end
        function GetCVar() return '400' end
        function SetCVar() end
        NeonCastDB={config={}}; ns={L={opening='Opening'}}
    ''')
    ns = lua.globals().ns
    lua.execute((ROOT / 'Data.lua').read_text(encoding='utf-8-sig'), 'NeonCast', ns)
    lua.execute((ROOT / 'Core.lua').read_text(encoding='utf-8-sig'), 'NeonCast', ns)
    assert ns.DisplayCastName('Opening - No Text', 22810) == 'Opening'
    assert ns.DisplayCastName('Fireball', 133) == 'Fireball'
    ns.SetSetting('showLatencyText', True)
    ns.SetSetting('latencyFontSize', 18)
    ns.SetSetting('latencyTextColor', lua.table_from({'r': 0.2, 'g': 0.5, 'b': 0.7}))
    assert lua.globals().NeonCastDB.config.showLatencyText is True
    assert lua.globals().NeonCastDB.config.latencyFontSize == 18
    assert ns.GetPartColor('latencyTextColor') == (0.2, 0.5, 0.7, 1)
    ns.SetLatencyFont('Interface\\\\AddOns\\\\Fonts\\\\MyFont.ttf')
    assert lua.globals().NeonCastDB.latencyFont == 'Interface\\\\AddOns\\\\Fonts\\\\MyFont.ttf'
    ns.RestoreDefaults()
    assert lua.globals().NeonCastDB.latencyFont is None

import pytest
from support import addon

@pytest.mark.parametrize('locale',['enUS','zhCN','zhTW','deDE'])
def test_all_locales_load_complete_panel_and_fallback(locale):
    lua, ns=addon(locale=locale)
    ns.ToggleOptions()
    if locale=='deDE':
        assert ns.L.layoutMode == 'Layout mode'
    else:
        base=ns.L
        assert ns.Locale.Has(locale)
        # Every supported locale supplies all English keys, not a silent partial translation.
        lua.execute('captured={}; local old=ns.Locale.Register;ns.Locale.Register=function(code,values) captured[code]=values end')
        from support import ROOT
        for code in ['enUS','zhCN','zhTW']:
            lua.execute((ROOT/f'Locales/{code}.lua').read_text(),'NeonCast',ns)
        packs=lua.globals().captured
        assert set(packs[locale].keys()) == set(packs.enUS.keys())
    ns.Locale.Activate('xxXX')
    assert ns.L.preview == 'Preview / move bar'
    assert ns.L.unknownFutureKey == 'unknownFutureKey'


def test_partial_translation_falls_back_per_key():
    lua, ns=addon()
    ns.Locale.Register('test',lua.table_from({'opening':'Custom opening'}))
    ns.Locale.Activate('test')
    assert ns.L.opening == 'Custom opening'
    assert ns.L.preview == 'Preview / move bar'


def test_translation_format_placeholders_match_english():
    import re
    from support import ROOT
    lua, ns=addon()
    lua.execute('captured={};ns.Locale.Register=function(code,values) captured[code]=values end')
    for code in ['enUS','zhCN','zhTW']:
        lua.execute((ROOT/f'Locales/{code}.lua').read_text(),'NeonCast',ns)
    packs=lua.globals().captured
    for code in ['zhCN','zhTW']:
        for key, value in packs.enUS.items():
            assert re.findall(r'%[sd]',value)==re.findall(r'%[sd]',packs[code][key]), (code,key)

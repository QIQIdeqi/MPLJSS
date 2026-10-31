"""Read saved assets in a fresh editor process, including drag-and-drop BP defaults."""
import json
from pathlib import Path
import unreal as u

root=Path(u.Paths.project_dir());data=json.loads((root/'ArtSource/PixelFX/manifest.json').read_text(encoding='utf-8'))
lib=u.EditorAssetLibrary;report={'effects':[],'materials':[]}
for e in data['effects']:
    for layer in e['layers']:
        tex=lib.load_asset('/Game/VFX/PixelFX/T_'+e['name']+'_'+layer);assert tex
        assert tex.blueprint_get_size_x()==e['size'][0]*e['columns']
        assert tex.blueprint_get_size_y()==e['size'][1]*e['rows']
        assert tex.get_editor_property('filter')==u.TextureFilter.TF_NEAREST
    bp=lib.load_asset('/Game/VFX/PixelFX/BP_PixelFX_'+e['name']);assert bp
    cdo=u.get_default_object(bp.generated_class())
    assert cdo.get_editor_property('effect')==getattr(u.PixelFX,e['name'].upper())
    cards=cdo.get_editor_property('cards');assert len(cards)==4
    for card in cards:
        assert card.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION
        assert card.get_editor_property('translucency_sort_priority')==0
    report['effects'].append({'name':e['name'],'atlas_count':len(e['layers']),'frames':e['count'],'preset_readback':True,'collision':'none','sort_priority':0})
for name,blend in [('Color',u.BlendMode.BLEND_TRANSLUCENT),('Light',u.BlendMode.BLEND_ADDITIVE)]:
    mat=lib.load_asset('/Game/VFX/PixelFX/M_PixelFX_'+name)
    assert mat.get_editor_property('blend_mode')==blend
    assert not mat.get_editor_property('disable_depth_test')
    report['materials'].append({'name':name,'depth_test':True,'blend':str(blend)})
report['result']='PASS'
(root/'Evidence/PixelFX/assets-readback.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
u.log('PIXELFX_ASSETS_READBACK_PASS')

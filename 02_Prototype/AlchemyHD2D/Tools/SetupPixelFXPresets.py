"""Create drag-and-drop Blueprint presets after the native PixelFX actor is built."""
import unreal as u
lib=u.EditorAssetLibrary;tools=u.AssetToolsHelpers.get_asset_tools()
parent=u.load_class(None,'/Script/AlchemyHD2D.PixelFXActor')
assert parent
for name,kind in [('Hit',u.PixelFX.HIT),('Poison',u.PixelFX.POISON),('Portal',u.PixelFX.PORTAL)]:
    path='/Game/VFX/PixelFX/BP_PixelFX_'+name
    if lib.does_asset_exist(path): bp=lib.load_asset(path)
    else:
        factory=u.BlueprintFactory();factory.set_editor_property('parent_class',parent)
        bp=tools.create_asset('BP_PixelFX_'+name,'/Game/VFX/PixelFX',u.Blueprint,factory)
    cdo=u.get_default_object(bp.generated_class());cdo.set_editor_property('effect',kind)
    u.BlueprintEditorLibrary.compile_blueprint(bp);lib.save_loaded_asset(bp)
    u.log('PIXELFX_PRESET_SAVED '+path)
u.log('PIXELFX_PRESETS_PASS')

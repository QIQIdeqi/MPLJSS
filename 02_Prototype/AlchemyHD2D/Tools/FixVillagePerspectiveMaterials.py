"""Material-only repair for the 60-degree village. Never load, rebuild or save a level."""
from pathlib import Path
from datetime import datetime,timezone,timedelta
import importlib,json,shutil,sys
import unreal as u

root=Path(u.Paths.project_dir()).resolve()
sys.path.insert(0,str(root/'Tools'))
import GreyfordAmbient as ambient
importlib.reload(ambient)
spec=json.loads((root/'Tools/GreyfordReference.json').read_text(encoding='utf-8'))
names=['Background']+[row['name'] for row in spec['layers']]+['Ambient_Waterwheel','Ambient_Creek','Ambient_ChimneySmoke']
backup=root/'ArtSource/VillagePerspective20261031'/datetime.now(timezone(timedelta(hours=8))).strftime('%Y%m%d_%H%M%S_%f')
backup.mkdir(parents=True,exist_ok=False)
manifest=[]
for name in names:
    asset='/Game/Greyford/Reference/M_'+name
    source=root/'Content/Greyford/Reference'/('M_'+name+'.uasset')
    assert u.EditorAssetLibrary.does_asset_exist(asset) and source.is_file(),f'Missing existing village material: {asset}'
    shutil.copy2(source,backup/source.name);manifest.append(asset)
(backup/'materials.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
original=u.EditorAssetLibrary.load_asset('/Game/Greyford/Reference/T_VillageReference')
clean=u.EditorAssetLibrary.load_asset('/Game/Greyford/Reference/T_VillageCleanPlate')
wheel=u.EditorAssetLibrary.load_asset('/Game/Greyford/Reference/T_Waterwheel')
assert original and clean and wheel,'Existing village textures must be available; this repair does not reimport textures.'
S=spec['centimeters_per_pixel']
ambient.reference_material('Background',S,original,clean,spec['clean_patch_rects'])
for row in spec['layers']:ambient.reference_material(S=S,original=original,clean=clean,rects=spec['clean_patch_rects'],**row)
ambient.animate(None,None,None,S,clean,wheel,materials_only=True)
u.log('VILLAGE_PERSPECTIVE_MATERIALS_PASS count='+str(len(names))+' backup='+str(backup)+' maps_saved=0 actors_spawned=0 textures_imported=0')

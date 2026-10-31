from pathlib import Path
from datetime import datetime
import shutil,unreal as u
root=Path(u.Paths.project_dir()).resolve()
backup=root/'ArtSource/VillagePerspective20261031'/('boss-sampling-'+datetime.now().strftime('%Y%m%d_%H%M%S'));backup.mkdir(parents=True)
source=root/'Content/ReferenceBattle/T_BossMeadow.uasset';shutil.copy2(source,backup/source.name)
tex=u.EditorAssetLibrary.load_asset('/Game/ReferenceBattle/T_BossMeadow');assert tex
tex.set_editor_property('address_x',u.TextureAddress.TA_MIRROR);tex.set_editor_property('address_y',u.TextureAddress.TA_MIRROR)
assert u.EditorAssetLibrary.save_loaded_asset(tex)
u.log('BOSS_MEADOW_SAMPLING_PASS mirrored_repeat_no_raster_changes backup='+str(backup))

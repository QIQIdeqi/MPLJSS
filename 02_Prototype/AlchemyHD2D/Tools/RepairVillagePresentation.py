from pathlib import Path
import runpy,unreal as u
root=Path(u.Paths.project_dir()).resolve()
runpy.run_path(str(root/'Tools/FixVillagePerspectiveMaterials.py'))
runpy.run_path(str(root/'Tools/InspectBossGround.py'))
u.log('VILLAGE_PRESENTATION_ASSETS_PASS')

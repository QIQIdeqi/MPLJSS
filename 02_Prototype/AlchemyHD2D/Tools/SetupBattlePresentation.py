"""Import retained heroine and create missing monster authoring assets serially."""
from pathlib import Path
import runpy
import unreal

tools = Path(__file__).resolve().parent
for filename in ('ImportRoseMage.py', 'SetupEnemyDefinitions.py'):
    runpy.run_path(str(tools / filename), run_name='__main__')
unreal.log('BATTLE_PRESENTATION_SETUP_PASS')

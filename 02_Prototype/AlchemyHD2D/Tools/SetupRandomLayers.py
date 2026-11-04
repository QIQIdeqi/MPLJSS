"""Add two editable presets without replacing existing authored designers or cells."""
import hashlib
import json
import shutil
from pathlib import Path
import unreal as u

root = Path(u.Paths.project_dir()).resolve()
out = root / 'Evidence/RandomLayers_20261104'
out.mkdir(parents=True, exist_ok=True)
levels = u.get_editor_subsystem(u.LevelEditorSubsystem)
actors = u.get_editor_subsystem(u.EditorActorSubsystem)
reports = []
import runpy
runpy.run_path(str(root/'Tools/CreateRandomGroundMaterial.py'))

def brush(name, ground, weight, size, half=(40,40), solid=False, interior=False):
    b = u.AlchemyTileBrush()
    b.set_editor_property('name', name)
    b.set_editor_property('texture', u.EditorAssetLibrary.load_asset('/Game/Greyford/Textures/T_GF_' + name))
    b.set_editor_property('material', u.EditorAssetLibrary.load_asset('/Game/Greyford/Materials/M_GF_' + name))
    assert b.get_editor_property('texture') and b.get_editor_property('material'), name
    b.set_editor_property('ground', ground)
    b.set_editor_property('random_weight', weight)
    b.set_editor_property('visual_size', u.Vector2D(*size))
    b.set_editor_property('collision_half_size', u.Vector2D(*half))
    b.set_editor_property('blocks_movement', solid)
    b.set_editor_property('boss_interior', interior)
    b.set_editor_property('foot_fraction', 488/512)
    b.set_editor_property('scale_range', u.Vector2D(.9,1.1) if not ground else u.Vector2D(1,1))
    return b

for boss, name in ((False,'Outskirts_Blockout'), (True,'Greyford_Boss')):
    package = '/Game/Greyford/Maps/' + name
    source = root / 'Content/Greyford/Maps' / (name + '.umap')
    backup = out / 'original' / source.name
    backup.parent.mkdir(parents=True, exist_ok=True)
    if not backup.exists():
        shutil.copy2(source, backup)
    assert levels.load_level(package)
    tagged = [a for a in actors.get_all_level_actors() if isinstance(a,u.AlchemyLevelDesigner) and 'AlchemyRandomStage' in [str(t) for t in a.tags]]
    assert len(tagged) <= 1, 'Multiple random stage presets'
    if tagged:
        reports.append({'map':package,'status':'existing preset preserved'})
        continue
    d = actors.spawn_actor_from_class(u.AlchemyLevelDesigner,u.Vector(0,0,0))
    d.set_actor_label('Alchemy_Random_Boss' if boss else 'Alchemy_Random_Normal')
    d.set_folder_path('Alchemy/RandomLayers')
    d.set_editor_property('tags',['AlchemyRandomStage'])
    d.set_editor_property('use_in_game',True)
    d.set_editor_property('camera_facing_objects',True)
    d.set_editor_property('ground_blend_material',u.EditorAssetLibrary.load_asset('/Game/Design/M_RandomGroundBlend'))
    d.set_editor_property('columns',14 if boss else 24)
    d.set_editor_property('rows',12 if boss else 18)
    d.set_editor_property('cell_size',400. if boss else 600.)
    d.set_editor_property('play_half_size',u.Vector2D(2800,2400) if boss else u.Vector2D(7200,5400))
    d.set_editor_property('boss_layout',boss)
    d.set_editor_property('seed',77 ^ 0x424F5353 if boss else 77)
    d.set_editor_property('object_density',.30 if boss else .24)
    d.set_editor_property('object_spacing',100.)
    d.set_editor_property('protected_path_half_width',300.)
    d.set_editor_property('protected_points',[u.Vector2D(x,y) for x,y in ((-900,0),(900,0),(0,-800),(0,800))] if boss else [u.Vector2D(x,y) for x,y in ((-6500,0),(6500,0),(0,-4700),(0,4700))])
    palette = [brush('Grass',True,78,(600,600)),brush('Dirt',True,20,(600,600)),brush('Stone',True,2,(600,600)),
               brush('Bush',False,6,(160,90) if boss else (180,130),(35,30),False,True),
               brush('Fence',False,2,(320,220),(150,35),True),
               brush('Crates',False,1,(200,180),(70,55),True)]
    if not boss:
        palette.append(brush('Oak',False,2,(500,620),(80,65),True))
    d.set_editor_property('palette',palette)
    for prop, asset in (('skill_table','DT_Skills'),('recipe_table','DT_Recipes'),('chain_table','DT_Chains'),('quality_table','DT_Quality')):
        d.set_editor_property(prop,u.EditorAssetLibrary.load_asset('/Game/Design/'+asset))
    assert d.generate_layers(3), d.get_editor_property('status')
    assert levels.save_current_level()
    cells=[a for a in actors.get_all_level_actors() if isinstance(a,u.AlchemyTileCell) and a.get_owner()==d]
    reports.append({'map':package,'actor':d.get_actor_label(),'ground':sum(a.get_editor_property('ground') for a in cells),'objects':sum(not a.get_editor_property('ground') for a in cells),'sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
(out/'setup.json').write_text(json.dumps(reports,indent=2)+'\n',encoding='utf-8')
u.log('RANDOM_LAYERS_SETUP_PASS')

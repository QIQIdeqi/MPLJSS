"""Create the missing enemy DT and a placeable configuration Blueprint; keep existing data."""
import csv
from pathlib import Path
import unreal as u

lib = u.EditorAssetLibrary
project = Path(u.Paths.project_dir()).resolve()
table_path = '/Game/Design/DT_Enemies'
blueprint_path = '/Game/Design/BP_EnemyDesigner'
parent = u.load_class(None, '/Script/AlchemyHD2D.AlchemyEnemyDesigner')
assert parent, 'Build the native enemy definitions before running this setup.'
checker = u.get_default_object(parent)
existed = lib.does_asset_exist(table_path)
assert checker.create_starter_table(), checker.get_editor_property('status')
table = lib.load_asset(table_path)
assert table
checker.set_editor_property('enemy_table', table)
assert checker.validate_enemies(), checker.get_editor_property('status')

if lib.does_asset_exist(blueprint_path):
    bp = lib.load_asset(blueprint_path)
else:
    factory = u.BlueprintFactory()
    factory.set_editor_property('parent_class', parent)
    bp = u.AssetToolsHelpers.get_asset_tools().create_asset(
        'BP_EnemyDesigner', '/Game/Design', u.Blueprint, factory)
assert bp
cdo = u.get_default_object(bp.generated_class())
if not cdo.get_editor_property('enemy_table'):
    cdo.set_editor_property('enemy_table', table)
assert cdo.validate_enemies(), cdo.get_editor_property('status')
u.BlueprintEditorLibrary.compile_blueprint(bp)
assert lib.save_loaded_asset(bp)

# Export the actual loaded table into evidence rather than overwriting the seed CSV.
readback = project / 'Evidence' / 'EnemyDefinitions' / 'DT_Enemies_readback.csv'
readback.parent.mkdir(parents=True, exist_ok=True)
assert u.DataTableFunctionLibrary.export_data_table_to_csv_file(table, str(readback))
with readback.open(encoding='utf-8-sig', newline='') as stream:
    rows = list(csv.DictReader(stream))
assert len(rows) >= 11
by_id = {int(row[next(iter(row))]): row for row in rows}
assert sorted(by_id) == list(range(len(rows)))
rows = [by_id[index] for index in range(len(rows))]
for index in range(11):
    assert int(rows[index]['Archetype']) == index
if not existed:
    with (project / 'Docs' / 'DesignerCSV' / 'DT_Enemies.csv').open(
            encoding='utf-8-sig', newline='') as stream:
        seed = list(csv.DictReader(stream))
    for index in range(11):
        for field in ('HP', 'Speed', 'ContactDamage', 'TunedHP', 'TunedContactDamage',
                      'TunedAreaDamage', 'TunedRangedDamage', 'CollisionRadius',
                      'AreaDamage', 'RangedDamage', 'EliteWeight'):
            assert abs(float(rows[index][field]) - float(seed[index][field])) < .0001, (index, field)
u.log('ENEMY_DEFINITIONS_SETUP_PASS rows=%d existing_preserved=%s blueprint=%s readback=%s' %
      (len(rows), existed, blueprint_path, readback))

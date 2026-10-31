"""Read saved quality tables and map bindings without saving or applying any gameplay asset."""
import csv
import hashlib
import json
from pathlib import Path
import unreal as u

project = Path(u.Paths.project_dir()).resolve()
output = project / 'Evidence/QualityCandidate_20261101/runtime-baseline'
output.mkdir(parents=True, exist_ok=True)

def fingerprints():
    files = sorted((project / 'Content').rglob('*.uasset')) + sorted((project / 'Content').rglob('*.umap')) + sorted((project / 'Saved').rglob('*.sav'))
    return {str(p.relative_to(project)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}

before = fingerprints()
default = '/Game/Design/DT_Quality.DT_Quality'
tables = {default}
bindings = []
maps = sorted((project / 'Content').rglob('*.umap'))
for file in maps:
    name = '/Game/' + file.relative_to(project / 'Content').with_suffix('').as_posix()
    world = u.EditorLoadingAndSavingUtils.load_map(name)
    assert world, name
    designers = []
    for actor in u.GameplayStatics.get_all_actors_of_class(world, u.AlchemyLevelDesigner):
        table = actor.get_editor_property('quality_table')
        path = table.get_path_name() if table else default
        tables.add(path)
        designers.append({'actor': actor.get_path_name(), 'level': actor.get_outer().get_path_name(),
                          'quality_table_property': table.get_path_name() if table else None,
                          'effective_if_selected_at_initial_load': path,
                          'use_in_game': actor.get_editor_property('use_in_game')})
    bindings.append({'map': name, 'loaded_designers': designers,
                     'fallback_if_no_designer_table': default})

exported = []
for index, path in enumerate(sorted(tables)):
    table = u.EditorAssetLibrary.load_asset(path)
    assert table, path
    file = output / ('DT_Quality.csv' if path == default else f'custom_{index:02d}.csv')
    assert u.DataTableFunctionLibrary.export_data_table_to_csv_file(table, str(file)), path
    with file.open(encoding='utf-8-sig', newline='') as stream:
        rows = list(csv.DictReader(stream))
    exported.append({'asset': path, 'csv': file.name, 'rows': rows,
                     'csv_sha256': hashlib.sha256(file.read_bytes()).hexdigest()})

after = fingerprints()
assert before == after, 'A saved Content asset/map or player save changed during read-only inspection.'
report = {'result': 'QUALITY_BASELINE_READONLY_PASS', 'maps': bindings, 'tables': exported,
          'content_and_save_files_unchanged': len(before),
          'player_save_files_unchanged': sum(name.endswith('.sav') for name in before),
          'selection_scope': 'LoadDesignConfig chooses the first loaded designer at BeginPlay, with DT_Quality fallback; switching Greyford stages changes Designer but does not reload RuntimeQuality. Map properties below are not proof of stage-time reload.'}
(output / 'bindings.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
(output / 'file-fingerprints.json').write_text(json.dumps(before, ensure_ascii=False, indent=2), encoding='utf-8')
u.log('QUALITY_BASELINE_READONLY_PASS ' + str(output))

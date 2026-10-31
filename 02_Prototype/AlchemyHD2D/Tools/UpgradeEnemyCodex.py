"""Migrate only untouched generic enemy labels; preserve author-edited runtime data."""
import csv
from datetime import datetime
import hashlib
import io
import json
from pathlib import Path
import shutil
import unreal as u

project = Path(u.Paths.project_dir()).resolve()
backup = project / 'Evidence/EnemyCodex_20261101' / datetime.now().strftime('%Y%m%d_%H%M%S_%f')
backup.mkdir(parents=True)
asset_path = '/Game/Design/DT_Enemies'
asset_file = project / 'Content/Design/DT_Enemies.uasset'
assert asset_file.is_file(), asset_file
shutil.copy2(asset_file, backup / asset_file.name)
lib = u.DataTableFunctionLibrary
table = u.EditorAssetLibrary.load_asset(asset_path)
assert table, asset_path
original_csv = backup / 'DT_Enemies_before.csv'
assert lib.export_data_table_to_csv_file(table, str(original_csv))
original_text = original_csv.read_text(encoding='utf-8-sig')
reader = csv.DictReader(io.StringIO(original_text))
fields = reader.fieldnames
assert fields and 'Name' in fields and 'CodexDescription' in fields, 'Compile the new native row schema before upgrading.'
original = list(reader)
key = fields[0]
assert len(original) >= 11
assert len({row[key] for row in original}) == len(original)
assert {str(i) for i in range(11)} <= {row[key] for row in original}
names = ['腐化鼠', '泥团怪', '游荡骷髅', '毒囊虫', '暗影猎犬', '游荡术徒', '石甲蛮徒', '腐化巨蜥', '蚀雾术士', '根须守卫']
expected = [dict(row) for row in original]
changed = []
for row in expected:
    row_id = int(row[key])
    generic = f'普通怪{row_id}' if row_id < 7 else f'精英怪{row_id}'
    if 0 <= row_id < 10 and row['Name'] == generic:
        row['Name'] = names[row_id]
        changed.append(row[key])
    # CodexDescription remains exactly as exported, including empty/custom descriptions.
buffer = io.StringIO(newline='')
writer = csv.DictWriter(buffer, fieldnames=fields, lineterminator='\n')
writer.writeheader()
writer.writerows(expected)
upgraded_text = buffer.getvalue()
(backup / 'DT_Enemies_proposed.csv').write_text(upgraded_text, encoding='utf-8')
try:
    assert lib.fill_data_table_from_csv_string(table, upgraded_text), 'CSV import failed.'
    readback = backup / 'DT_Enemies_after.csv'
    assert lib.export_data_table_to_csv_file(table, str(readback))
    with readback.open(encoding='utf-8-sig', newline='') as stream:
        actual_reader = csv.DictReader(stream)
        assert actual_reader.fieldnames == fields, 'Unexpected schema change.'
        actual = list(actual_reader)
    assert len(actual) == len(expected), 'Unexpected row-count change.'
    by_id = {row[key]: row for row in actual}
    assert len(by_id) == len(expected), 'Duplicate row IDs.'
    for row in expected:
        assert by_id.get(row[key]) == row, f'Unexpected field change in row {row[key]}.'
except Exception:
    lib.fill_data_table_from_csv_string(table, original_text)
    raise
assert u.EditorAssetLibrary.save_loaded_asset(table), 'Validated table could not be saved; original uasset is backed up.'
report = {'result': 'ENEMY_CODEX_UPGRADE_PASS', 'rows': len(expected), 'renamed_rows': changed,
          'preserved': 'All other fields and custom/empty descriptions; names are existing UI labels, not approved story species.',
          'original_asset_sha256': hashlib.sha256((backup / asset_file.name).read_bytes()).hexdigest()}
(backup / 'verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
u.log('ENEMY_CODEX_UPGRADE_PASS ' + str(backup))

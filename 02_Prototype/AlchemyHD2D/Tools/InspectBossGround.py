"""Read-only editor inspection of the Boss map and meadow material; saves diagnostics only."""
import json
from pathlib import Path
import unreal as u

root = Path(u.Paths.project_dir()).resolve()
output = root / 'Evidence' / 'VillagePresentation_20261031' / 'boss-ground-assets.json'
map_path = '/Game/Greyford/Maps/Greyford_Boss'
material_path = '/Game/ReferenceBattle/M_BossMeadow'
levels = u.get_editor_subsystem(u.LevelEditorSubsystem)
actors = u.get_editor_subsystem(u.EditorActorSubsystem)
assert levels.load_level(map_path), 'Cannot load existing Boss map for inspection.'


def path(obj):
    return obj.get_path_name() if obj else None


def vector(value):
    return [float(value.x), float(value.y), float(value.z)]


report = {
    'mode': 'read_only_assets_and_map_no_save_no_recompile',
    'map': map_path,
    'actors': [],
    'material': {'path': material_path},
    'diagnostic_errors': [],
}
for actor in actors.get_all_level_actors():
    if not isinstance(actor, u.StaticMeshActor):
        continue
    component = actor.static_mesh_component
    materials = [path(component.get_material(index)) for index in range(component.get_num_materials())]
    entry = {
        'label': actor.get_actor_label(),
        'name': actor.get_name(),
        'path': actor.get_path_name(),
        'tags': [str(tag) for tag in actor.tags],
        'location_cm': vector(actor.get_actor_location()),
        'scale': vector(actor.get_actor_scale3d()),
        'static_mesh': path(component.static_mesh),
        'materials': materials,
        'matches_current_runtime_ground_predicate_scale_x_ge_70': actor.get_actor_scale3d().x >= 70,
    }
    report['actors'].append(entry)
    u.log('BOSS_GROUND_ACTOR ' + json.dumps(entry, ensure_ascii=False))

material = u.EditorAssetLibrary.load_asset(material_path)
report['material']['exists'] = bool(material)
if material:
    info = report['material']
    info['class'] = material.get_class().get_name()
    for field in ('shading_model', 'blend_mode', 'material_domain', 'two_sided'):
        try:
            info[field] = str(material.get_editor_property(field))
        except Exception as error:
            report['diagnostic_errors'].append({'property': field, 'error': str(error)})
    info['expressions'] = []
    info['texture_sampler_mismatches'] = []
    for expression in u.MaterialEditingLibrary.get_material_expressions(material):
        entry = {'name': expression.get_name(), 'class': expression.get_class().get_name()}
        if isinstance(expression, u.MaterialExpressionTextureBase):
            texture = expression.get_editor_property('texture')
            sampler = str(expression.get_editor_property('sampler_type'))
            entry.update(texture=path(texture), sampler_type=sampler)
            if texture:
                srgb = bool(texture.get_editor_property('srgb'))
                compression = str(texture.get_editor_property('compression_settings'))
                entry.update(texture_srgb=srgb, texture_compression=compression)
                # This diagnostic concerns the ordinary color meadow texture, not normal/mask samplers.
                normalized = sampler.replace('_', '').replace(' ', '').upper()
                expected = 'Color' if srgb else 'LinearColor'
                actual = 'LinearColor' if 'LINEARCOLOR' in normalized else 'Color' if 'COLOR' in normalized else 'Other'
                entry.update(expected_color_sampler=expected, actual_color_sampler=actual,
                             color_sampler_matches_texture_srgb=actual == expected)
                if actual != expected:
                    info['texture_sampler_mismatches'].append({
                        'expression': expression.get_name(), 'texture': path(texture),
                        'actual': sampler, 'expected': expected, 'srgb': srgb,
                    })
        info['expressions'].append(entry)
    for label, value in [('emissive', u.MaterialProperty.MP_EMISSIVE_COLOR),
                         ('base_color', u.MaterialProperty.MP_BASE_COLOR)]:
        info[label + '_input_node'] = path(u.MaterialEditingLibrary.get_material_property_input_node(material, value))
    info['used_textures'] = [path(texture) for texture in u.MaterialEditingLibrary.get_material_used_textures(material)]
    u.log('BOSS_GROUND_MATERIAL ' + json.dumps(info, ensure_ascii=False))

output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
u.log('BOSS_GROUND_INSPECTION_DONE output=%s static_mesh_actors=%d' % (output, len(report['actors'])))

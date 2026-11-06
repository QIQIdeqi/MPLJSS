"""Isolated editor checks for GenerateLayers; run in a dedicated editor session.

Only dedicated /Game/Tests/RandomLayers_* maps are saved. Existing art is read-only;
no starter-table creation, production-map save, or skill-table edits occur.
Production Flow movement, navigation and camera checks belong to native tests.
"""
import hashlib
import json
from pathlib import Path
import traceback

import unreal as u


ROOT = Path(u.Paths.project_dir())
TEST_MAP = '/Game/Tests/RandomLayers_20261104'
OUTPUT = ROOT / 'Evidence/RandomLayers_20261106/editor-checks.json'
REPORT = {'result': 'FAIL', 'checks': [], 'samples': [],
          'test_map': TEST_MAP, 'production_assets_saved': False,
          'scope': 'editor generation, locking, failure preservation and test-map reload',
          'not_covered': ['production Flow movement/pathfinding/spawn/portal',
                          'native rendering, camera and gameplay feel']}
LEVELS = u.get_editor_subsystem(u.LevelEditorSubsystem)
ACTORS = u.get_editor_subsystem(u.EditorActorSubsystem)
LIB = u.EditorAssetLibrary


def check(name, passed, detail=None):
    passed = bool(passed)
    row = {'name': name, 'pass': passed}
    if detail is not None:
        row['detail'] = detail
    REPORT['checks'].append(row)
    u.log('RANDOM_LAYERS_EDITOR_CHECK %s %s' % (name, 'PASS' if passed else 'FAIL'))
    if not passed:
        raise AssertionError(name)


def prop(obj, name):
    return obj.get_editor_property(name)


def set_props(obj, **values):
    for name, value in values.items():
        obj.set_editor_property(name, value)


def asset_path(obj):
    return obj.get_path_name() if obj else None


def vector(value):
    names = ('x', 'y', 'z') if hasattr(value, 'z') else ('x', 'y')
    return tuple(round(float(getattr(value, name)), 5) for name in names)


def owned(designer, ground=None):
    return [a for a in ACTORS.get_all_level_actors()
            if isinstance(a, u.AlchemyTileCell) and a.get_owner() == designer
            and (ground is None or bool(prop(a, 'ground')) == ground)]


def cell_record(cell):
    rotation = cell.get_actor_rotation()
    return {'grid': [cell.grid_x, cell.grid_y], 'ground': bool(prop(cell, 'ground')),
            'brush': prop(cell, 'brush_name'), 'lock': bool(prop(cell, 'lock_random')),
            'location': vector(cell.get_actor_location()),
            'rotation': tuple(round(float(getattr(rotation, n)), 5)
                              for n in ('pitch', 'yaw', 'roll')),
            'scale': vector(cell.get_actor_scale3d()),
            'texture': asset_path(prop(cell, 'texture')),
            'material': asset_path(prop(cell, 'material_override')),
            'visual': vector(prop(cell, 'visual_size')),
            'half': vector(prop(cell, 'collision_half_size')),
            'blocks': bool(prop(cell, 'blocks_movement')),
            'foot': round(float(prop(cell, 'foot_fraction')), 5),
            'boss_interior': bool(prop(cell, 'boss_interior'))}


def signature(designer, ground=None):
    records = [cell_record(c) for c in owned(designer, ground)]
    return sorted(records, key=lambda row: (row['ground'], *row['grid']))


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode('utf-8')).hexdigest()


def palette(zero_ground=False):
    result = []
    for name, ground, blocks, interior, size, half in (
            ('Grass', True, False, False, (600, 600), (0, 0)),
            ('Dirt', True, False, False, (600, 600), (0, 0)),
            ('Oak', False, True, False, (260, 360), (45, 45)),
            ('Bush', False, False, True, (180, 140), (30, 30))):
        texture = LIB.load_asset('/Game/Greyford/Textures/T_GF_' + name)
        material = LIB.load_asset('/Game/Greyford/Materials/M_GF_' + name)
        check('read_existing_' + name, texture is not None and material is not None)
        brush = u.AlchemyTileBrush()
        set_props(brush, name=name, texture=texture, material=material,
                  ground=ground, random_weight=0.0 if ground and zero_ground else 1.0,
                  visual_size=u.Vector2D(*size), collision_half_size=u.Vector2D(*half),
                  blocks_movement=blocks, boss_interior=interior,
                  foot_fraction=.96, scale_range=u.Vector2D(1, 1),
                  yaw_range=u.Vector2D(0, 0))
        result.append(brush)
    return result


def generate(designer, mask, name):
    check(name, designer.generate_layers(mask), prop(designer, 'status'))


def failure_preserves(designer, mask, name):
    before = signature(designer)
    paths = sorted(c.get_path_name() for c in owned(designer))
    check(name + '_rejected', not designer.generate_layers(mask), prop(designer, 'status'))
    check(name + '_old_layout_and_instances_preserved',
          signature(designer) == before
          and sorted(c.get_path_name() for c in owned(designer)) == paths)


def new_designer(boss=False):
    d = ACTORS.spawn_actor_from_class(u.AlchemyLevelDesigner, u.Vector(0, 0, 0))
    check('spawn_' + ('boss' if boss else 'normal') + '_designer', d is not None)
    d.set_actor_label('RandomLayers_Boss' if boss else 'RandomLayers_Normal')
    set_props(d, columns=8 if boss else 4, rows=6 if boss else 3, cell_size=600.0,
              play_half_size=u.Vector2D(2400, 1800) if boss else u.Vector2D(1200, 900),
              seed=77, layer_mask=3, ground_seed_offset=0, object_seed_offset=0,
              ground_patch_size=1, object_density=.85, object_spacing=40.0,
              protected_points=[u.Vector2D(0, 0)], protected_path_half_width=100.0,
              boss_layout=boss, boss_half_size=u.Vector2D(1600, 1300),
              palette=palette())
    return d


def repeat_samples(designer, label):
    variants = []
    for seed in (77, 78, 79):
        designer.set_editor_property('seed', seed)
        generate(designer, 3, '%s_seed_%d_generated' % (label, seed))
        check('%s_seed_%d_both_layers_nonempty' % (label, seed),
              len(owned(designer, True)) == designer.columns * designer.rows
              and len(owned(designer, False)) > 0)
        before = signature(designer)
        generate(designer, 3, '%s_seed_%d_repeat_generated' % (label, seed))
        check('%s_seed_%d_reproducible' % (label, seed), signature(designer) == before)
        variants.append(digest(before))
        REPORT['samples'].append({'scene': label, 'seed': seed, 'signature': variants[-1],
                                  'ground': len(owned(designer, True)),
                                  'objects': len(owned(designer, False))})
        if label == 'boss':
            # Actual blocking footprints must not intersect the central 32x26m ellipse.
            clear = True
            for cell in owned(designer, False):
                if not prop(cell, 'blocks_movement') and prop(cell, 'boss_interior'):
                    continue
                p = cell.get_actor_location()
                half = prop(cell, 'collision_half_size')
                q = (max(0, abs(p.x) - half.x) / 1600) ** 2
                q += (max(0, abs(p.y) - half.y) / 1300) ** 2
                clear &= q > 1
            check('boss_seed_%d_central_ellipse_clear_of_blockers_and_tall_props' % seed, clear)
    check(label + '_sampled_seeds_vary', len(set(variants)) > 1)


def range_contracts():
    designer = new_designer()
    designer.set_actor_label('RandomLayers_Ranges')
    brushes = list(prop(designer, 'palette'))
    set_props(brushes[0], count_range=u.IntPoint(7, 7), density_range=u.Vector2D(.5, .75))
    set_props(brushes[1], density_range=u.Vector2D(.4, .5))
    set_props(brushes[2], count_range=u.IntPoint(2, 2), density_range=u.Vector2D(.15, .25))
    set_props(brushes[3], count_range=u.IntPoint(0, 0))
    set_props(designer, palette=brushes, object_density=0.0)
    generate(designer, 3, 'count_density_intersection_generated')
    counts = {name: 0 for name in ('Grass', 'Dirt', 'Oak', 'Bush')}
    for cell in owned(designer):
        counts[prop(cell, 'brush_name')] += 1
    check('count_density_caps_and_minima_apply_to_both_layers',
          counts == {'Grass': 7, 'Dirt': 5, 'Oak': 2, 'Bush': 0}, counts)
    before = signature(designer)
    generate(designer, 3, 'bounded_seed_repeat_generated')
    check('bounded_seed_reproducible', signature(designer) == before)

    locked = owned(designer, False)[0]
    set_props(locked, lock_random=True)
    generate(designer, 2, 'locked_prop_counts_toward_minimum')
    check('locked_prop_counts_toward_exact_total', len(owned(designer, False)) == 2 and locked in owned(designer))

    set_props(brushes[2], count_range=u.IntPoint(0, 0), density_range=u.Vector2D(-1, -1))
    set_props(designer, palette=brushes)
    failure_preserves(designer, 2, 'locked_prop_exceeds_configured_maximum')
    set_props(brushes[2], count_range=u.IntPoint(2, 2), allowed_grounds=['MissingGround'])
    set_props(designer, palette=brushes)
    failure_preserves(designer, 2, 'no_legal_sites_for_configured_minimum')
    set_props(brushes[2], allowed_grounds=[])
    set_props(brushes[0], density_range=u.Vector2D(0, .25))
    set_props(designer, palette=brushes)
    failure_preserves(designer, 1, 'count_and_density_conflict')
    set_props(brushes[0], density_range=u.Vector2D(.5, .75))
    set_props(designer, palette=brushes)
    generate(designer, 3, 'valid_ranges_recover')
    return signature(designer)


def render_contracts(designer, locked_ground):
    designer.set_editor_property('camera_facing_objects', True)
    designer.refresh_cells()
    foot_errors, normal_dots = [], []
    for cell in owned(designer, False):
        transform = prop(cell, 'image').get_world_transform()
        foot = transform.transform_location(
            u.Vector(0, 100 * (prop(cell, 'foot_fraction') - .5), 0))
        anchor = cell.get_actor_location()
        foot_errors.append(sum((getattr(foot, n) - getattr(anchor, n)) ** 2
                               for n in ('x', 'y', 'z')) ** .5)
        origin = transform.transform_location(u.Vector(0, 0, 0))
        tip = transform.transform_location(u.Vector(0, 0, 1))
        normal = [getattr(tip, n) - getattr(origin, n) for n in ('x', 'y', 'z')]
        length = sum(v * v for v in normal) ** .5
        # Opposite the fixed pitch=-60, yaw=90 camera's forward vector.
        normal_dots.append((-.5 * normal[1] + (3 ** .5 / 2) * normal[2])
                           / length if length > 0 else -1)
    check('camera_facing_configured_feet_match_actor_anchors',
          bool(foot_errors) and max(foot_errors) < .01,
          {'max_error_cm': max(foot_errors) if foot_errors else None})
    check('camera_facing_plane_normals_oppose_fixed60_camera',
          bool(normal_dots) and min(normal_dots) > .999,
          {'minimum_dot': min(normal_dots) if normal_dots else None})

    blend = LIB.load_asset('/Game/Design/M_RandomGroundBlend')
    custom = LIB.load_asset('/Game/Greyford/Materials/M_GF_Oak')
    check('read_existing_blend_and_custom_materials', blend is not None and custom is not None)
    check('custom_material_target_is_locked_ground',
          prop(locked_ground, 'ground') and prop(locked_ground, 'lock_random'))
    locked_ground.set_editor_property('material_override', custom)
    designer.set_editor_property('ground_blend_material', blend)
    designer.refresh_cells()
    standard = [c for c in owned(designer, True)
                if prop(c, 'material_override')
                and prop(c, 'material_override').get_name()
                in ('M_GF_Grass', 'M_GF_Dirt', 'M_GF_Stone')]
    check('standard_ground_uses_dynamic_blend_materials',
          bool(standard) and all(isinstance(prop(c, 'image').get_material(0),
                                           u.MaterialInstanceDynamic) for c in standard),
          {'standard_cells': len(standard)})
    check('locked_custom_ground_override_and_display_preserved',
          prop(locked_ground, 'material_override') == custom
          and prop(locked_ground, 'image').get_material(0) == custom)


def main():
    if LIB.does_asset_exist(TEST_MAP):
        check('load_isolated_map', LEVELS.load_level(TEST_MAP))
        for actor in ACTORS.get_all_level_actors():
            if isinstance(actor, (u.AlchemyTileCell, u.AlchemyLevelDesigner)):
                ACTORS.destroy_actor(actor)
    else:
        check('create_isolated_map', LEVELS.new_level(TEST_MAP))
    d = new_designer()
    repeat_samples(d, 'normal')

    objects = signature(d, False)
    ground = signature(d, True)
    d.set_editor_property('ground_seed_offset', 101)
    generate(d, 1, 'ground_only_generated')
    check('ground_only_preserves_object_layer', signature(d, False) == objects)
    check('ground_only_changes_ground_sample', signature(d, True) != ground)
    ground = signature(d, True)
    d.set_editor_property('object_seed_offset', 203)
    generate(d, 2, 'objects_only_generated')
    check('objects_only_preserves_ground_layer', signature(d, True) == ground)
    check('objects_only_changes_object_sample', signature(d, False) != objects)

    locked_ground = owned(d, True)[0]
    set_props(locked_ground, lock_random=True,
              material_override=LIB.load_asset('/Game/Greyford/Materials/M_GF_Dirt'))
    p = locked_ground.get_actor_location()
    locked_ground.set_actor_location(u.Vector(p.x + 11, p.y, p.z), False, False)
    locked_object = max(owned(d, False), key=lambda c:
                        c.get_actor_location().x ** 2 + c.get_actor_location().y ** 2)
    locked_object.set_editor_property('lock_random', True)
    locked_object.set_actor_scale3d(u.Vector(.95, .95, .95))
    ground_record, object_record = cell_record(locked_ground), cell_record(locked_object)
    set_props(d, ground_seed_offset=303, object_seed_offset=407)
    generate(d, 3, 'both_layers_rerolled_with_locks')
    check('edited_ground_lock_preserved', cell_record(locked_ground) == ground_record)
    check('edited_object_lock_preserved', cell_record(locked_object) == object_record)

    d.set_editor_property('palette', palette(zero_ground=True))
    failure_preserves(d, 1, 'zero_ground_weight')
    d.set_editor_property('palette', palette())
    old_x = locked_ground.grid_x
    locked_ground.set_editor_property('grid_x', d.columns)
    failure_preserves(d, 3, 'locked_cell_outside_grid')
    locked_ground.set_editor_property('grid_x', old_x)
    old_position = locked_object.get_actor_location()
    locked_object.set_actor_location(u.Vector(0, 0, 2), False, False)
    failure_preserves(d, 3, 'locked_object_inside_protected_origin')
    locked_object.set_actor_location(old_position, False, False)
    generate(d, 3, 'valid_configuration_recovers_after_failures')

    boss = new_designer(boss=True)
    repeat_samples(boss, 'boss')
    render_contracts(d, locked_ground)
    expected_ranges = range_contracts()
    expected = signature(d)
    check('save_test_map_only', LEVELS.save_current_level())
    # Switch only between dedicated test maps; never save or edit Research/Flow.
    reload_map = '/Game/Tests/RandomLayers_Reload_20261104'
    if LIB.does_asset_exist(reload_map):
        check('open_empty_reload_world', LEVELS.load_level(reload_map))
    else:
        check('open_empty_reload_world', LEVELS.new_level(reload_map))
    check('reload_saved_test_map', LEVELS.load_level(TEST_MAP))
    d = next(a for a in ACTORS.get_all_level_actors()
             if isinstance(a, u.AlchemyLevelDesigner) and a.get_actor_label() == 'RandomLayers_Normal')
    check('saved_layers_and_edited_locks_survive_reload', signature(d) == expected)
    check('saved_both_lock_types_exist',
          any(prop(c, 'lock_random') for c in owned(d, True))
          and any(prop(c, 'lock_random') for c in owned(d, False)))
    bounded = next(a for a in ACTORS.get_all_level_actors()
                   if isinstance(a, u.AlchemyLevelDesigner) and a.get_actor_label() == 'RandomLayers_Ranges')
    brushes = prop(bounded, 'palette')
    check('range_settings_and_placement_survive_reload',
          prop(brushes[0], 'count_range').x == 7 and prop(brushes[0], 'count_range').y == 7
          and vector(prop(brushes[0], 'density_range')) == (.5, .75)
          and signature(bounded) == expected_ranges)
    REPORT['result'] = 'PASS'


try:
    main()
except Exception:
    REPORT['error'] = traceback.format_exc()
    u.log_error('RANDOM_LAYERS_EDITOR_FAIL\n' + REPORT['error'])
    raise
finally:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(REPORT, ensure_ascii=False, indent=2), encoding='utf-8')
if REPORT['result'] == 'PASS':
    u.log('RANDOM_LAYERS_EDITOR_PASS')

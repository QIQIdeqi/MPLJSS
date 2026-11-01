import unreal as u
assert "-CollisionExportGuardTest" in u.SystemLibrary.get_command_line(), "Run this test through TestCollisionExportGuard.ps1 in its own Editor process."
import json,hashlib
from pathlib import Path
root=Path(u.Paths.project_dir()).resolve();out=root/'Evidence/CollisionExportGuard_20261101';source=root/'Tools/GreyfordReference.json'
levels=u.get_editor_subsystem(u.LevelEditorSubsystem);actors=u.get_editor_subsystem(u.EditorActorSubsystem)
checks=[];error=None
try:
 before=hashlib.sha256(source.read_bytes()).hexdigest()
 world=u.EditorLoadingAndSavingUtils.new_blank_map(False)
 assert world,'Transient editor world was not created'
 region=actors.spawn_actor_from_class(u.GreyfordReferenceRegion,u.Vector())
 assert region,'Temporary region was not created'
 context=levels.get_current_level().get_path_name()
 assert not context.startswith('/Game/Greyford/Maps/Village_Reference.')
 region.save_collision_layout();status=region.get_editor_property('editor_status')
 assert 'Village_Reference' in status and '未写入' in status,status
 assert hashlib.sha256(source.read_bytes()).hexdigest()==before,'Village source changed during rejection'
 checks.append({'name':'temporary_editor_level_export_rejected_without_source_write','result':'PASS','level':context,'status':status})
 assert levels.load_level('/Game/Greyford/Maps/Village_Reference')
 current=levels.get_current_level().get_path_name();regions=[a for a in actors.get_all_level_actors() if isinstance(a,u.GreyfordReferenceRegion)]
 assert current.startswith('/Game/Greyford/Maps/Village_Reference.') and regions
 checks.append({'name':'canonical_village_level_identity_and_regions_readonly','result':'PASS','level':current,'regions':len(regions),'export_invoked':False})
except Exception as exc:
 error=str(exc);u.log_error('COLLISION_EXPORT_GUARD_FAIL '+error)
finally:
 data={'result':'FAIL' if error else 'PASS','error':error,'checks':checks,'method':'Full Editor Python, native SaveCollisionLayout rejection on temporary world; canonical village loaded readonly, no valid export/save invoked.'}
 (out/'editor-checks.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 u.log('COLLISION_EXPORT_GUARD_'+data['result'])
 try:levels.load_level('/Game/Greyford/Maps/Greyford_Flow')
 finally:u.SystemLibrary.quit_editor()

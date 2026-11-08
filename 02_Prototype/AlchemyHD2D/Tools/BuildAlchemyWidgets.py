from pathlib import Path

import unreal as u

if not u.EditorAssetLibrary.does_asset_exist("/Game/UI/Alchemy/FF_AlchemyUI"):
    factory = u.FontFileImportFactory()
    factory.set_editor_property("batch_create_font_asset", u.BatchCreateFontAsset.NO)
    task = u.AssetImportTask()
    task.filename = str(Path(u.Paths.engine_content_dir()) / "Slate/Fonts/DroidSansFallback.ttf")
    task.destination_path = "/Game/UI/Alchemy"
    task.destination_name = "FF_AlchemyUI"
    task.automated = True
    task.save = True
    task.factory = factory
    u.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
    if not u.EditorAssetLibrary.does_asset_exist("/Game/UI/Alchemy/FF_AlchemyUI"):
        raise RuntimeError("Alchemy font face import failed")

if not u.AlchemyBrewWidget.build_designer_assets():
    raise RuntimeError("Alchemy Widget Blueprint generation failed")

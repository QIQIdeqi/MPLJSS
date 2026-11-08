"""Build the project's CPU furnace system and Epic UI sprite material in Unreal Editor."""
import unreal

if not unreal.AlchemyFurnaceFXLibrary.build_assets():
    raise RuntimeError('Furnace Niagara UI assets failed to build. See Unreal Output Log.')
unreal.log('ALCHEMY_FURNACE_NIAGARA_UI_PASS /Game/VFX/NS_AlchemyFurnaceUI')

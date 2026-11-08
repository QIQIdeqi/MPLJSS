using UnrealBuildTool;
public class AlchemyHD2D : ModuleRules {
    public AlchemyHD2D(ReadOnlyTargetRules Target) : base(Target) {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
        PublicDependencyModuleNames.AddRange(new[] {"Core","CoreUObject","Engine","InputCore","SlateCore","Slate","Niagara","AudioMixer","UMG"});
        PrivateDependencyModuleNames.AddRange(new[] {"Json","MovieScene","MovieSceneTracks"});
        if (Target.bBuildEditor) PrivateDependencyModuleNames.AddRange(new[] {"UnrealEd","NiagaraEditor","AssetRegistry","RenderCore","UMGEditor","KismetCompiler"});
    }
}

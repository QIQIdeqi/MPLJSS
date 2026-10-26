using UnrealBuildTool;
public class AlchemyHD2D : ModuleRules {
    public AlchemyHD2D(ReadOnlyTargetRules Target) : base(Target) {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
        PublicDependencyModuleNames.AddRange(new[] {"Core","CoreUObject","Engine","InputCore","SlateCore"});
    }
}

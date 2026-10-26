using UnrealBuildTool;
public class AlchemyHD2DTarget : TargetRules {
    public AlchemyHD2DTarget(TargetInfo Target) : base(Target) {
        Type = TargetType.Game; DefaultBuildSettings = BuildSettingsVersion.Latest;
        ExtraModuleNames.Add("AlchemyHD2D");
    }
}

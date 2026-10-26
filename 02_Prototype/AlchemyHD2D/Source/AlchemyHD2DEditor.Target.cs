using UnrealBuildTool;
public class AlchemyHD2DEditorTarget : TargetRules {
    public AlchemyHD2DEditorTarget(TargetInfo Target) : base(Target) {
        Type = TargetType.Editor; DefaultBuildSettings = BuildSettingsVersion.Latest;
        ExtraModuleNames.Add("AlchemyHD2D");
    }
}

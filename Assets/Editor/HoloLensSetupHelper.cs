#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

public static class HoloLensSetupHelper
{
    private const string MENU_PREFIX = "HoloLens/";

    [MenuItem(MENU_PREFIX + "1. Configure Project Settings for HoloLens 2", false, 1)]
    public static void ConfigureProjectForHoloLens()
    {
        bool confirm = EditorUtility.DisplayDialog(
            "Configure for HoloLens 2",
            "This will configure Player Settings, UWP target settings (ARM64, IL2CPP), " +
            "capabilities (Spatial Perception, etc.), and rendering settings for HoloLens 2.\n\n" +
            "Your models, shaders, and scene objects will NOT be touched.\n\nProceed?",
            "Yes, Configure",
            "Cancel"
        );

        if (!confirm) return;

        Debug.Log("[HoloLensSetup] Starting HoloLens 2 project configuration...");

        // 1. Color Space - HoloLens 2 requires Linear
        PlayerSettings.colorSpace = ColorSpace.Linear;
        Debug.Log("[HoloLensSetup] Set Color Space to Linear.");

        // 2. Stereo Rendering Path
        PlayerSettings.stereoRenderingPath = StereoRenderingPath.Instancing;
        Debug.Log("[HoloLensSetup] Set Stereo Rendering to Instancing.");

        // 3. Switch build target to Universal Windows Platform (WSA)
        BuildTarget currentTarget = EditorUserBuildSettings.activeBuildTarget;
        if (currentTarget != BuildTarget.WSAPlayer)
        {
            Debug.Log("[HoloLensSetup] Switching active platform to UWP (WSAPlayer)...");
            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.WSA, BuildTarget.WSAPlayer);
        }

        // 4. UWP Architecture & Target
        EditorUserBuildSettings.wsaArchitecture = "ARM64";
        EditorUserBuildSettings.wsaUWPBuildType = WSAUWPBuildType.D3D;
        EditorUserBuildSettings.wsaMinUWPSDK = "10.0.18362.0";
        Debug.Log("[HoloLensSetup] Configured UWP: Architecture=ARM64, BuildType=D3D.");

        // 5. Scripting Backend & API Compatibility
        PlayerSettings.SetScriptingBackend(BuildTargetGroup.WSA, ScriptingImplementation.IL2CPP);
        PlayerSettings.SetApiCompatibilityLevel(BuildTargetGroup.WSA, ApiCompatibilityLevel.NET_Standard);
        Debug.Log("[HoloLensSetup] Configured Scripting Backend to IL2CPP and .NET Standard.");

        // 6. Capabilities required by HoloLens 2
        PlayerSettings.WSA.SetCapability(PlayerSettings.WSACapability.SpatialPerception, true);
        PlayerSettings.WSA.SetCapability(PlayerSettings.WSACapability.InternetClient, true);
        PlayerSettings.WSA.SetCapability(PlayerSettings.WSACapability.GazeInput, true);
        PlayerSettings.WSA.SetCapability(PlayerSettings.WSACapability.WebCam, true);
        PlayerSettings.WSA.SetCapability(PlayerSettings.WSACapability.Microphone, true);
        Debug.Log("[HoloLensSetup] Enabled UWP Capabilities: SpatialPerception, InternetClient, GazeInput, WebCam, Microphone.");

        // Save settings to disk
        AssetDatabase.SaveAssets();

        EditorUtility.DisplayDialog(
            "Configuration Complete",
            "HoloLens 2 project settings configured successfully!\n\n" +
            "Summary:\n" +
            "• Platform: UWP (HoloLens)\n" +
            "• Architecture: ARM64\n" +
            "• Scripting: IL2CPP (.NET Standard 2.1)\n" +
            "• Rendering: Single Pass Instanced\n" +
            "• Capabilities: Spatial Perception, Gaze, Webcam, etc. enabled",
            "OK"
        );

        Debug.Log("[HoloLensSetup] ✅ Project settings configured successfully for HoloLens 2!");
    }
}
#endif

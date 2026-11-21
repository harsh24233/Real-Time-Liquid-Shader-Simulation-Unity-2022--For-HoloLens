#if UNITY_EDITOR
using System.IO;
using UnityEditor;
using UnityEngine;

/// <summary>
/// Editor utility to toggle fluid materials between URP Shader Graph and Native URP HLSL Shader,
/// and verify that all material colors and properties are valid and visible without breaking anything.
/// </summary>
public static class LiquidMaterialConverter
{
    private const string HLSL_SHADER_NAME = "Custom/LiquidShader";
    private const string SHADERGRAPH_NAME = "Shader Graphs/LiquidShaderGrapjh";

    [MenuItem("Tools/Liquid Shader & HoloLens/Switch All Materials to Native HLSL (HoloLens 2 Optimized)")]
    public static void SwitchToNativeHLSL()
    {
        Shader hlslShader = Shader.Find(HLSL_SHADER_NAME);
        if (hlslShader == null)
        {
            Debug.LogError($"[LiquidMaterialConverter] Could not find shader '{HLSL_SHADER_NAME}'. Please make sure Assets/Shaders/LiquidShader.shader exists and compiles.");
            return;
        }

        int count = SwitchMaterialsShader(hlslShader);
        Debug.Log($"<color=#00ff88><b>[LiquidMaterialConverter] Successfully switched {count} fluid materials to Native HLSL ('{HLSL_SHADER_NAME}'). HoloLens Single Pass Instanced enabled!</b></color>");
    }

    [MenuItem("Tools/Liquid Shader & HoloLens/Switch All Materials to Shader Graph")]
    public static void SwitchToShaderGraph()
    {
        Shader sgShader = Shader.Find(SHADERGRAPH_NAME);
        if (sgShader == null)
        {
            Debug.LogError($"[LiquidMaterialConverter] Could not find shader '{SHADERGRAPH_NAME}'. Please make sure LiquidShaderGrapjh.shadergraph has imported.");
            return;
        }

        int count = SwitchMaterialsShader(sgShader);
        Debug.Log($"<color=#00ff88><b>[LiquidMaterialConverter] Successfully switched {count} fluid materials to Shader Graph ('{SHADERGRAPH_NAME}').</b></color>");
    }

    [MenuItem("Tools/Liquid Shader & HoloLens/Verify & Fix All Material Colors")]
    public static void VerifyAndFixMaterialColors()
    {
        string[] matGuids = AssetDatabase.FindAssets("t:Material", new[] { "Assets" });
        int verified = 0;
        int fixedCount = 0;

        foreach (string guid in matGuids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            string fname = Path.GetFileName(path).ToLowerInvariant();

            // Skip glass and tutorial assets
            if (fname.Contains("glass") || fname.Contains("tutorial") || fname.Contains("readme"))
                continue;

            Material mat = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (mat == null) continue;

            bool isFluid = fname.Contains("fluid") || fname.Contains("water") || fname.Contains("honey") || fname.Contains("milk") || fname.Contains("oil");
            if (!isFluid) continue;

            verified++;
            bool modified = false;

            // Ensure main_color has visible alpha
            if (mat.HasProperty("_main_color"))
            {
                Color mc = mat.GetColor("_main_color");
                if (mc.a < 0.1f)
                {
                    mc.a = 0.9f;
                    mat.SetColor("_main_color", mc);
                    modified = true;
                }
            }

            // Ensure _BaseColor matches _main_color or _Color
            if (mat.HasProperty("_BaseColor") && mat.HasProperty("_main_color"))
            {
                Color bc = mat.GetColor("_BaseColor");
                Color mc = mat.GetColor("_main_color");
                if (bc == Color.white && mc != Color.white)
                {
                    mat.SetColor("_BaseColor", new Color(mc.r, mc.g, mc.b, 1f));
                    modified = true;
                }
            }

            if (modified)
            {
                EditorUtility.SetDirty(mat);
                fixedCount++;
            }
        }

        AssetDatabase.SaveAssets();
        Debug.Log($"<color=#00e5ff><b>[LiquidMaterialConverter] Verification complete: Checked {verified} fluid materials. Fixed/Optimized colors on {fixedCount} materials.</b></color>");
    }

    private static int SwitchMaterialsShader(Shader targetShader)
    {
        string[] matGuids = AssetDatabase.FindAssets("t:Material", new[] { "Assets" });
        int count = 0;

        foreach (string guid in matGuids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            string fname = Path.GetFileName(path).ToLowerInvariant();

            if (fname.Contains("glass") || fname.Contains("tutorial") || fname.Contains("readme"))
                continue;

            Material mat = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (mat == null) continue;

            bool isFluid = fname.Contains("fluid") || fname.Contains("water") || fname.Contains("honey") || fname.Contains("milk") || fname.Contains("oil");
            if (!isFluid) continue;

            // Cache properties before switching shader
            Color mainColor = mat.HasProperty("_main_color") ? mat.GetColor("_main_color") : Color.white;
            Color topColor = mat.HasProperty("_Color") ? mat.GetColor("_Color") : Color.white;
            float fillFloat = mat.HasProperty("_Float") ? mat.GetFloat("_Float") : 0.02f;
            float wobbleX = mat.HasProperty("_WobbleX") ? mat.GetFloat("_WobbleX") : 0f;
            float wobbleZ = mat.HasProperty("_WobbleZ") ? mat.GetFloat("_WobbleZ") : 0f;

            mat.shader = targetShader;

            // Re-apply properties
            if (mat.HasProperty("_main_color")) mat.SetColor("_main_color", mainColor);
            if (mat.HasProperty("_Color")) mat.SetColor("_Color", topColor);
            if (mat.HasProperty("_BaseColor")) mat.SetColor("_BaseColor", Color.white);
            if (mat.HasProperty("_Float")) mat.SetFloat("_Float", fillFloat);
            if (mat.HasProperty("_WobbleX")) mat.SetFloat("_WobbleX", wobbleX);
            if (mat.HasProperty("_WobbleZ")) mat.SetFloat("_WobbleZ", wobbleZ);

            EditorUtility.SetDirty(mat);
            count++;
        }

        AssetDatabase.SaveAssets();
        return count;
    }
}
#endif

Shader "Custom/LiquidShader"
{
    Properties
    {
        [Header(Fluid Body Settings)]
        [MainColor] _main_color ("Main Color (Fluid Body)", Color) = (0.82, 0.42, 0.04, 0.88)
        _Color ("Surface / Meniscus Color", Color) = (0.95, 0.6, 0.1, 1.0)
        _BaseColor ("Base Color Tint", Color) = (1, 1, 1, 1)

        [Header(Dynamics and Level)]
        _Float ("Fill Level (Cut Plane)", Float) = 0.02
        _WobbleX ("Wobble X", Float) = 0.0
        _WobbleZ ("Wobble Z", Float) = 0.0

        [Header(Fresnel Edge Highlight)]
        _FresnelPower ("Fresnel Power", Float) = 1.0
        _FresnelScale ("Fresnel Scale", Float) = 1.6

        [Header(Surface Properties)]
        _Smoothness ("Smoothness", Range(0, 1)) = 0.75
        _Metallic ("Metallic", Range(0, 1)) = 0.0
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull Mode", Float) = 0 // 0 = Off (Double-Sided)
    }

    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
            "IgnoreProjector" = "True"
        }

        LOD 300
        Cull [_Cull]
        ZWrite On
        ZTest LEqual

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float2 uv           : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float3 positionWS   : TEXCOORD0;
                float3 normalWS     : TEXCOORD1;
                float2 uv           : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _main_color;
                float4 _Color;
                float4 _BaseColor;
                float _Float;
                float _WobbleX;
                float _WobbleZ;
                float _FresnelPower;
                float _FresnelScale;
                float _Smoothness;
                float _Metallic;
                float _Cull;
            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);

                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;
                output.normalWS = normalInput.normalWS;
                output.uv = input.uv;

                return output;
            }

            half4 frag(Varyings input, FRONT_FACE_TYPE isFrontFace : FRONT_FACE_SEMANTIC) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // World-space center of container object (column 3 of model matrix)
                float3 objectCenterWS = float3(UNITY_MATRIX_M._14, UNITY_MATRIX_M._24, UNITY_MATRIX_M._34);
                float3 relPos = input.positionWS - objectCenterWS;

                // Rotate about X axis (1, 0, 0) by 90 deg: (relPos.x, -relPos.z, relPos.y)
                float3 rotX = float3(relPos.x, -relPos.z, relPos.y);

                // Rotate about Z axis (0, 0, 1) by 90 deg: (-relPos.y, relPos.x, relPos.z)
                float3 rotZ = float3(-relPos.y, relPos.x, relPos.z);

                // Add wobble transforms to relative position
                float3 effectivePos = relPos + (rotX * _WobbleZ) + (rotZ * _WobbleX);

                // Cut plane: discard fragments above fill height (_Float)
                clip(_Float - effectivePos.y);

                // Front face vs Back face coloring:
                // Back face (inside surface view from above): renders top meniscus color (_Color)
                // Front face (outer liquid surface): blends _main_color with _Color via Fresnel
                float3 normalWS = normalize(input.normalWS);
                float3 viewDirWS = normalize(GetWorldSpaceNormalizeViewDir(input.positionWS));
                float NdotV = saturate(dot(normalWS, viewDirWS));
                float fresnel = pow(1.0 - NdotV, _FresnelPower);

                float3 fluidBodyColor = lerp(_main_color.rgb, _Color.rgb, saturate(fresnel * _FresnelScale));
                float3 finalRgb = IS_FRONT_VFACE(isFrontFace, true, false) ? fluidBodyColor : _Color.rgb;

                finalRgb *= _BaseColor.rgb;

                return half4(finalRgb, 1.0);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vertShadow
            #pragma fragment fragShadow
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float3 positionWS   : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _main_color;
                float4 _Color;
                float4 _BaseColor;
                float _Float;
                float _WobbleX;
                float _WobbleZ;
                float _FresnelPower;
                float _FresnelScale;
                float _Smoothness;
                float _Metallic;
                float _Cull;
            CBUFFER_END

            Varyings vertShadow(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

                output.positionWS = positionWS;
                output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _MainLightPosition.xyz));

                #if UNITY_REVERSED_Z
                    output.positionCS.z = min(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    output.positionCS.z = max(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif

                return output;
            }

            half4 fragShadow(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float3 objectCenterWS = float3(UNITY_MATRIX_M._14, UNITY_MATRIX_M._24, UNITY_MATRIX_M._34);
                float3 relPos = input.positionWS - objectCenterWS;
                float3 rotX = float3(relPos.x, -relPos.z, relPos.y);
                float3 rotZ = float3(-relPos.y, relPos.x, relPos.z);
                float3 effectivePos = relPos + (rotX * _WobbleZ) + (rotZ * _WobbleX);

                clip(_Float - effectivePos.y);
                return 0;
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask R
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vertDepth
            #pragma fragment fragDepth
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float3 positionWS   : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _main_color;
                float4 _Color;
                float4 _BaseColor;
                float _Float;
                float _WobbleX;
                float _WobbleZ;
                float _FresnelPower;
                float _FresnelScale;
                float _Smoothness;
                float _Metallic;
                float _Cull;
            CBUFFER_END

            Varyings vertDepth(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS = TransformWorldToHClip(output.positionWS);
                return output;
            }

            half4 fragDepth(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float3 objectCenterWS = float3(UNITY_MATRIX_M._14, UNITY_MATRIX_M._24, UNITY_MATRIX_M._34);
                float3 relPos = input.positionWS - objectCenterWS;
                float3 rotX = float3(relPos.x, -relPos.z, relPos.y);
                float3 rotZ = float3(-relPos.y, relPos.x, relPos.z);
                float3 effectivePos = relPos + (rotX * _WobbleZ) + (rotZ * _WobbleX);

                clip(_Float - effectivePos.y);
                return 0;
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}

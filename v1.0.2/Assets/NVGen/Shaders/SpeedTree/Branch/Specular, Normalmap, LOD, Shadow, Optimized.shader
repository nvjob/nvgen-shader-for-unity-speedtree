// The basis of the shader. Copyright (c) 2016 Unity Technologies. MIT license (License 2016 Unity Technologies.txt)
// Copyright (c) 2018 NVJOB.pro. NVGen shader for SpeedTree. MIT license (License NVJOB.txt)



Shader "NVGen/SpeedTree/Branch/Specular, Normalmap, LOD, Shadow, Optimized" {
	


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	

Properties{
_MainTex("Base (RGB) Trans (A)", 2D) = "white" {}
_BumpMap("Normalmap", 2D) = "bump" {}
_Color("Main Color", Color) = (1,1,1,1)
[Toggle(EFFECT_HUE_VARIATION)]
_OnHueVariation("On Hue Variation", Float) = 0
_HueVariation("Hue Variation", Color) = (1.0,0.5,0.0,0.1)
_SpecColor("Specular Color", Color) = (0.5, 0.5, 0.5, 1)
_Shininess("Shininess", Range(0.03, 1)) = 0.078125
_IntensityNm("Intensity Normalmap", Range(0.1, 10)) = 1
[MaterialEnum(None,0, Leafy,1, Leafy Elasticity,2, Pine,3)] _WindBranchQuality("Wind Quality", Range(0, 3)) = 0
_WindPower("Wind Power", Range(0, 5)) = 1
_WindPowerSpeed("Wind Power Speed", Range(0, 2)) = 1
_BranchElasticity("Branch Elasticity", Range(0, 5)) = 1
_BranchElasticitySpeed("Branch Elasticity Speed", Range(0, 2)) = 1
[HideInInspector]_WindQuality("Wind Auto On", Float) = 1
}



//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



SubShader{
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

Tags { "Queue" = "Geometry" "IgnoreProjector" = "True" "RenderType" = "Opaque" "DisableBatching" = "LODFading" }

LOD 200
CGPROGRAM
#pragma surface surf BlinnPhong vertex:TreeShaderVert exclude_path:prepass nolightmap nodirlightmap nodynlightmap dithercrossfade nometa noforwardadd nolppv noshadowmask halfasview interpolateview novertexlights
#pragma target 3.0
#pragma instancing_options assumeuniformscaling maxcount:50
#pragma multi_compile_vertex LOD_FADE_PERCENTAGE
#pragma shader_feature EFFECT_HUE_VARIATION
#define ENABLE_WIND


///////////////////////////////////////////////////////////////////////////////////////////////////////////////


#include "BranchWind.cginc"

//----------------------------------------------

struct Input {
half3 interpolator1;
float2 uv_MainTex;
float2 uv_BumpMap;
};

//----------------------------------------------

sampler2D _MainTex, _BumpMap;
fixed4 _Color;
half _Shininess, _IntensityNm;

#ifdef EFFECT_HUE_VARIATION
#define HueVariationAmount interpolator1.z
half4 _HueVariation;
#endif

//----------------------------------------------

void TreeShaderVert(inout TreeShaderVB IN, out Input OUT) {
UNITY_INITIALIZE_OUTPUT(Input, OUT);

#ifdef EFFECT_HUE_VARIATION
float hueVariationAmount = frac(unity_ObjectToWorld[0].w + unity_ObjectToWorld[1].w + unity_ObjectToWorld[2].w);
hueVariationAmount += frac(IN.vertex.x + IN.normal.y + IN.normal.x) * 0.5 - 0.3;
OUT.HueVariationAmount = saturate(hueVariationAmount * _HueVariation.a);
#endif

OffsetTreeShaderVertex(IN, unity_LODFade.x);
}

//----------------------------------------------

void surf(Input IN, inout SurfaceOutput OUT) {
half4 diffuseColor = tex2D(_MainTex, IN.uv_MainTex);

#ifdef EFFECT_HUE_VARIATION
half3 shiftedColor = lerp(diffuseColor.rgb, _HueVariation.rgb, IN.HueVariationAmount);
half maxBase = max(diffuseColor.r, max(diffuseColor.g, diffuseColor.b));
half newMaxBase = max(shiftedColor.r, max(shiftedColor.g, shiftedColor.b));
maxBase /= newMaxBase;
maxBase = maxBase * 0.5f + 0.5f;
shiftedColor.rgb *= maxBase;
diffuseColor.rgb = saturate(shiftedColor);
#endif

OUT.Albedo = diffuseColor.rgb * _Color;
OUT.Gloss = diffuseColor.a;
OUT.Specular = _Shininess;

fixed3 normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
normal.x *= _IntensityNm;
normal.y *= _IntensityNm;
OUT.Normal = normalize(normal);

}

//----------------------------------------------
ENDCG



///////////////////////////////////////////////////////////////////////////////////////////////////////////////



Pass {
//----------------------------------------------

Tags { "LightMode" = "ShadowCaster" }

CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#pragma target 3.0
#pragma instancing_options assumeuniformscaling maxcount:50
#pragma multi_compile_instancing
#pragma multi_compile_shadowcaster
#define ENABLE_WIND
#include "UnityCG.cginc"
#include "BranchWind.cginc"

//----------------------------------------------

struct v2f {
V2F_SHADOW_CASTER;
UNITY_VERTEX_INPUT_INSTANCE_ID
UNITY_VERTEX_OUTPUT_STEREO
};

//----------------------------------------------

v2f vert(TreeShaderVB v) {
v2f o;
UNITY_SETUP_INSTANCE_ID(v);
UNITY_TRANSFER_INSTANCE_ID(v, o);
UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
OffsetTreeShaderVertex(v, 0);
TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
return o;
}

//----------------------------------------------

float4 frag(v2f i) : SV_Target {
UNITY_SETUP_INSTANCE_ID(i);
SHADOW_CASTER_FRAGMENT(i)
}

//----------------------------------------------
ENDCG
}


///////////////////////////////////////////////////////////////////////////////////////////////////////////////
}



//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Fallback "Legacy Shaders/VertexLit"
}

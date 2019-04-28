// The basis of the shader. Copyright (c) 2016 Unity Technologies. MIT license (License 2016 Unity Technologies.txt)
// Copyright (c) 2018 NVJOB.pro. NVGen shader for SpeedTree. MIT license (License NVJOB.txt)



Shader "NVGen/SpeedTree/Leaf/Specular, Normalmap, Reflection, OcclusionMap, LOD, Shadow, Optimized" {
	


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	

Properties {
[NoScaleOffset]_MainTex("Base (RGB) Trans (A)", 2D) = "white" {}
[NoScaleOffset]_BumpMap("Normalmap", 2D) = "bump" {}
[NoScaleOffset]_OcclusionMap("Occlusion Map", 2D) = "white" {}
[NoScaleOffset]_Cube("Reflection Cubemap", Cube) = "" {}
_Color ("Main Color", Color) = (1,1,1,1)
[Toggle(EFFECT_HUE_VARIATION)]
_OnHueVariation("On Hue Variation", Float) = 0
_HueVariation ("Hue Variation", Color) = (1.0,0.5,0.0,0.1)
_Cutoff ("Alpha Cutoff", Range(0,1)) = 0.333
_Shadow_Cutoff("Shadow Cutoff", Range(0,1)) = 0.333
_SpecColor("Specular Color", Color) = (0.5, 0.5, 0.5, 1)
_ReflectColor("Reflection Color", Color) = (1,1,1,0.5)
_Shininess("Shininess", Range(0.03, 1)) = 0.078125
_IntensityNm("Intensity Normalmap", Range(-10, 10)) = 1
_IntensityOc("Intensity Occlusion", Range(0.03, 10)) = 1
_IntensityRef("Intensity Reflection", Range(0, 20)) = 1
[MaterialEnum(Off,0, On,1)] _WindLeafOn ("Wind On", Range(0, 1)) = 0
_WindPower("Wind Power", Range(0, 5)) = 1
_WindPowerSpeed("Wind Power Speed", Range(0, 2)) = 1
_WindVibration("Wind Vibration", Range(0, 3)) = 0.5
_WindVibrationSpeed("Wind Vibration Speed", Range(0, 2)) = 0.5
[HideInInspector]_WindQuality("Wind Auto On", Float) = 1
}



//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



SubShader {
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
Tags{ "Queue" = "Transparent" "RenderType" = "TransparentCutout" "IgnoreProjector" = "True" "DisableBatching" = "LODFading" }

LOD 200
Cull [Off]
CGPROGRAM
#pragma surface surf BlinnPhong vertex:TreeShaderVert exclude_path:prepass nolightmap dithercrossfade nodirlightmap nodynlightmap nometa noforwardadd nolppv noshadowmask halfasview interpolateview novertexlights
#pragma target 3.0
#pragma instancing_options assumeuniformscaling maxcount:50
#pragma multi_compile_vertex LOD_FADE_PERCENTAGE
#pragma shader_feature EFFECT_HUE_VARIATION
#define ENABLE_WIND


///////////////////////////////////////////////////////////////////////////////////////////////////////////////


#include "LeafWind.cginc"

//----------------------------------------------

struct Input {
half3 interpolator1;
float3 worldRefl;
INTERNAL_DATA
};

//----------------------------------------------

fixed4 _Color, _ReflectColor;
#define mainTexUV interpolator1.xy
sampler2D _MainTex, _BumpMap, _OcclusionMap;
samplerCUBE _Cube;
fixed _Cutoff;
half _Shininess, _IntensityNm, _IntensityOc, _IntensityRef;

#ifdef EFFECT_HUE_VARIATION
#define HueVariationAmount interpolator1.z
half4 _HueVariation;
#endif

//----------------------------------------------

void TreeShaderVert(inout TreeShaderVB IN, out Input OUT) {
UNITY_INITIALIZE_OUTPUT(Input, OUT);
OUT.mainTexUV = IN.texcoord.xy;

#ifdef EFFECT_HUE_VARIATION
float hueVariationAmount = frac(unity_ObjectToWorld[0].w + unity_ObjectToWorld[1].w + unity_ObjectToWorld[2].w);
hueVariationAmount += frac(IN.vertex.x + IN.normal.y + IN.normal.x) * 0.5 - 0.3;
OUT.HueVariationAmount = saturate(hueVariationAmount * _HueVariation.a);
#endif

OffsetTreeShaderVertex(IN, unity_LODFade.x);
}

//----------------------------------------------

void surf(Input IN, inout SurfaceOutput OUT) {
half4 diffuseColor = tex2D(_MainTex, IN.mainTexUV);
OUT.Alpha = diffuseColor.a * _Color.a;
clip(OUT.Alpha - _Cutoff);
#ifdef EFFECT_HUE_VARIATION
half3 shiftedColor = lerp(diffuseColor.rgb, _HueVariation.rgb, IN.HueVariationAmount);
half maxBase = max(diffuseColor.r, max(diffuseColor.g, diffuseColor.b));
half newMaxBase = max(shiftedColor.r, max(shiftedColor.g, shiftedColor.b));
maxBase /= newMaxBase;
maxBase = maxBase * 0.5f + 0.5f;
shiftedColor.rgb *= maxBase;
diffuseColor.rgb = saturate(shiftedColor);
#endif

fixed3 normal = UnpackNormal(tex2D(_BumpMap, IN.mainTexUV));
normal.x *= _IntensityNm;
normal.y *= _IntensityNm;
OUT.Normal = normalize(normal);

half4 reflcol = texCUBE(_Cube, WorldReflectionVector(IN, OUT.Normal));
reflcol *= _IntensityRef;
reflcol *= diffuseColor.a;
OUT.Emission = reflcol.rgb * _ReflectColor.rgb;

fixed occcol = tex2D(_OcclusionMap, IN.mainTexUV).r;
occcol *= _IntensityOc;
diffuseColor *= occcol;
OUT.Albedo = diffuseColor.rgb * _Color;
OUT.Gloss = diffuseColor.a;
OUT.Specular = _Shininess;
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
#include "LeafWind.cginc"

//----------------------------------------------

sampler2D _MainTex;
fixed _Shadow_Cutoff;

//----------------------------------------------

struct v2f {
V2F_SHADOW_CASTER;
float2 uv : TEXCOORD1;
UNITY_VERTEX_INPUT_INSTANCE_ID
UNITY_VERTEX_OUTPUT_STEREO
};

//----------------------------------------------

v2f vert(TreeShaderVB v) {
v2f o;
UNITY_SETUP_INSTANCE_ID(v);
UNITY_TRANSFER_INSTANCE_ID(v, o);
UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
o.uv = v.texcoord.xy;
OffsetTreeShaderVertex(v, 0);
TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
return o;
}

//----------------------------------------------

float4 frag(v2f i) : SV_Target {
UNITY_SETUP_INSTANCE_ID(i);
clip(tex2D(_MainTex, i.uv).a - _Shadow_Cutoff);
SHADOW_CASTER_FRAGMENT(i)
}

//----------------------------------------------
ENDCG
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Fallback "Legacy Shaders/Transparent/Cutout/VertexLit"
}

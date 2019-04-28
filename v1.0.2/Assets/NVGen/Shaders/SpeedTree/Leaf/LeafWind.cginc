// The basis of the shader. Copyright (c) 2016 Unity Technologies. MIT license (License 2016 Unity Technologies.txt)
// Copyright (c) 2018 NVJOB.pro. NVGen shader for SpeedTree. MIT license (License NVJOB.txt)



struct TreeShaderVB {
float4 vertex       : POSITION;
float3 normal       : NORMAL;
float4 tangent		: TANGENT;
float4 texcoord     : TEXCOORD0;
float4 texcoord1    : TEXCOORD1;
float4 texcoord2    : TEXCOORD2;
float2 texcoord3    : TEXCOORD3;
half4 color         : COLOR;
UNITY_VERTEX_INPUT_INSTANCE_ID
};


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


CBUFFER_START(TreeShaderWind)
half4 _ST_WindVector, _ST_WindGlobal, _ST_WindBranchAdherences, _ST_WindLeaf1Ripple, _ST_WindLeaf2Ripple;
CBUFFER_END

uniform half _WindLeafOn, _WindPower, _WindPowerSpeed, _WindVibrationSpeed, _WindVibration, _WindEnabled;


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


half4 TrigApproximate(half4 vData) {
half4 cubSM = abs((frac(vData + 0.5) * 2.0) - 1.0);
cubSM *= cubSM * (3.0 - 2.0 * cubSM);
return (cubSM - 0.5) * 2.0;
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


half3 GlobalWind(half3 vPos, half3 vInstancePos, half3 vRotatedWindVector, half time) {
half fLength = 1.0;
fLength = length(vPos.xyz);
half fAdjust = max(vPos.y - (1.0 / _ST_WindGlobal.z) * 0.25, 0.0) * _ST_WindGlobal.z;
if (fAdjust != 0) fAdjust = pow(fAdjust, _ST_WindGlobal.w);
half4 vOscillations = TrigApproximate(half4(vInstancePos.x + time, vInstancePos.y + time * 0.8, 0.0, 0.0));
half fMoveAmount = _ST_WindGlobal.y * vOscillations.x + (vOscillations.y * vOscillations.y);
fMoveAmount += _ST_WindBranchAdherences.x / _ST_WindGlobal.z;
fMoveAmount *= fAdjust;
vPos.xz += vRotatedWindVector.xz * fMoveAmount;
vPos.xyz = normalize(vPos.xyz) * fLength;
return vPos;
}

///////////////////////////////////////////////////////////////////

half3 LeafRipple(half3 vPos, inout half3 vDirection, half fScale, half fPackedRippleDir, half fTime, half fAmount, half fTrigOffset) {
half fMoveAmount = fAmount * TrigApproximate((fTime + fTrigOffset) * _WindVibrationSpeed).x * _WindVibration;
vPos.xyz += (frac(fPackedRippleDir / half3(16.0, 1.0, 0.0625)) * 2.0 - 1.0) * fMoveAmount * fScale;
return vPos;
}

///////////////////////////////////////////////////////////////////

half3 LeafWind(bool bLeaf2, half3 vPos, inout half3 vDirection, half fScale, half3 vAnchor, half fPackedGrowthDir, half fPackedRippleDir, half fRippleTrigOffset, half3 vRotatedWindVector) {
vPos = LeafRipple(vPos, vDirection, fScale, fPackedRippleDir, (bLeaf2 ? _ST_WindLeaf2Ripple.x : _ST_WindLeaf1Ripple.x), (bLeaf2 ? _ST_WindLeaf2Ripple.y : _ST_WindLeaf1Ripple.y), fRippleTrigOffset);
return vPos;
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////v


void OffsetTreeShaderVertex(inout TreeShaderVB data, half lodValue) {
half windON = _WindLeafOn * _WindEnabled;
half3 finalPosition = data.vertex.xyz;
half3 rotatedWindVector;
if (windON <= 0) rotatedWindVector = half3(0.0f, 0.0f, 0.0f);
else rotatedWindVector = normalize(mul(_ST_WindVector.xyz, (half3x3)unity_ObjectToWorld)) * _WindPower;
finalPosition -= data.texcoord1.xyz;
if (data.color.a == 0) {
#ifdef LOD_FADE_PERCENTAGE
if (lodValue != 0) finalPosition *= lerp(1.0, data.texcoord1.w, lodValue);
#endif
finalPosition = mul(finalPosition.xyz, (half3x3)UNITY_MATRIX_IT_MV);
finalPosition = normalize(finalPosition) * length(finalPosition);
}
else {
#ifdef LOD_FADE_PERCENTAGE
if (lodValue != 0) finalPosition = lerp(finalPosition, half3(data.texcoord1.w, data.texcoord3.x, data.texcoord3.y), lodValue);
#endif
}
finalPosition = LeafWind(data.texcoord2.w > 0.0, finalPosition, data.normal, data.texcoord2.x, half3(0, 0, 0), data.texcoord2.y, data.texcoord2.z, data.texcoord1.x + data.texcoord1.y, rotatedWindVector);
finalPosition += data.texcoord1.xyz;
if (windON == 1) {
half3 treePos = half3(unity_ObjectToWorld[0].w, unity_ObjectToWorld[1].w, unity_ObjectToWorld[2].w);
finalPosition = GlobalWind(finalPosition, treePos, rotatedWindVector, _ST_WindGlobal.x * _WindPowerSpeed);
}
data.vertex.xyz = finalPosition;
}


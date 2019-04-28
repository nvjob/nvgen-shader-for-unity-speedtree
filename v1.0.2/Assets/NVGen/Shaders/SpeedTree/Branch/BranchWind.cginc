// The basis of the shader. Copyright (c) 2016 Unity Technologies. MIT license (License 2016 Unity Technologies.txt)
// Copyright (c) 2018 NVJOB.pro. NVGen shader for SpeedTree. MIT license (License NVJOB.txt)



struct TreeShaderVB {
float4 vertex       : POSITION;
float3 normal       : NORMAL;
float4 tangent		: TANGENT;
float4 texcoord     : TEXCOORD0;
float4 texcoord1    : TEXCOORD1;
half4 color         : COLOR;
UNITY_VERTEX_INPUT_INSTANCE_ID
};


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


CBUFFER_START(TreeShaderWind)
half4 _ST_WindVector, _ST_WindGlobal, _ST_WindBranch, _ST_WindBranchTwitch, _ST_WindBranchWhip, _ST_WindBranchAnchor, _ST_WindBranchAdherences, _ST_WindTurbulences, _ST_WindAnimation;
CBUFFER_END

uniform half _WindBranchQuality, _WindPower, _WindPowerSpeed, _BranchElasticity, _BranchElasticitySpeed, _WindEnabled;


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


half4 TrigApproximate(half4 vData) {
half4 cubSM = abs((frac(vData + 0.5) * 2.0) - 1.0);
cubSM *= cubSM * (3.0 - 2.0 * cubSM);
return (cubSM - 0.5) * 2.0;
}


///////////////////////////////////////////////////////////////////


half Oscillate(half vPos, half fTime, half fOffset, half fWeight, half fWhip, half fTwitch, half fTwitchFreqScale, inout half4 vOscillations, half3 vRotatedWindVector) {
half fOscillation = 1.0;
vOscillations = TrigApproximate(half4(fTime + fOffset, fTime * fTwitchFreqScale + fOffset, fTwitchFreqScale * 0.5 * (fTime + fOffset), 0.0));
half fBroadDetail = vOscillations.y * vOscillations.z;
half fTarget = 1.0;
half fAmount = fBroadDetail;
if (fBroadDetail < 0.0) {
fTarget = -fTarget;
fAmount = -fAmount;
}
fBroadDetail = lerp(fBroadDetail, fTarget, fAmount);
fBroadDetail = lerp(fBroadDetail, fTarget, fAmount);
fOscillation = fBroadDetail * fTwitch * (1.0 - _ST_WindVector.w) + vOscillations.x * (1.0 - fTwitch);
return fOscillation;
}

///////////////////////////////////////////////////////////////////

half Turbulence(half fTime, half fOffset, half fGlobalTime, half fTurbulence) {
half4 vOscillations = TrigApproximate(half4(fTime * 0.1 + fOffset, fGlobalTime * fTurbulence * 0.1 + fOffset, 0.0, 0.0));
return 1.0 - (vOscillations.x * vOscillations.y * vOscillations.x * vOscillations.y * fTurbulence);
}

///////////////////////////////////////////////////////////////////

half3 GlobalWind (half3 vPos, half3 vInstancePos, half3 vRotatedWindVector, half time) {
half fLength = 1.0;
fLength = length(vPos.xyz);
half fAdjust = max(vPos.y - (1.0 / _ST_WindGlobal.z) * 0.25, 0.0) * _ST_WindGlobal.z;
if (fAdjust != 0.0) fAdjust = pow(fAdjust, _ST_WindGlobal.w);
half4 vOscillations = TrigApproximate(half4(vInstancePos.x + time, vInstancePos.y + time * 0.8, 0.0, 0.0));
half fOsc = vOscillations.x + (vOscillations.y * vOscillations.y);
half fMoveAmount = _ST_WindGlobal.y * fOsc;
fMoveAmount += _ST_WindBranchAdherences.x / _ST_WindGlobal.z;
fMoveAmount *= fAdjust;
vPos.xz += vRotatedWindVector.xz * fMoveAmount;
vPos.xyz = normalize(vPos.xyz) * fLength;
return vPos;
}

///////////////////////////////////////////////////////////////////

half3 LeafyBranchWind(half3 vPos, half3 vInstancePos, half fWeight, half fOffset, half fTime, half fDistance, half fTwitch, half fTwitchScale, half fWhip, half3 vRotatedWindVector) {
half3 vWindVector = (frac(fOffset / half3(16.0, 1.0, 0.0625)) * 2.0 - 1.0);
vWindVector = vWindVector * fWeight;
fTime += vInstancePos.x + vInstancePos.y;
half4 vOscillations;
half fOsc = Oscillate(vPos, fTime * _BranchElasticitySpeed, fOffset, fWeight, fWhip, fTwitch, fTwitchScale, vOscillations, vRotatedWindVector) * _BranchElasticity;
vPos.xyz += vWindVector * fOsc * fDistance;
return vPos;
}

///////////////////////////////////////////////////////////////////

half3 PineBranchWind(half3 vPos, half3 vInstancePos, half fWeight, half fOffset, half fTime, half fDistance, half fTurbulence, half fAdherence, half fTwitch, half fTwitchScale, half fWhip, half3 vRotatedWindVector, half3 vRotatedBranchAnchor) {
half3 vWindVector = (frac(fOffset / half3(16.0, 1.0, 0.0625)) * 2.0 - 1.0);
vWindVector = vWindVector * fWeight;
fTime += vInstancePos.x + vInstancePos.y;
half4 vOscillations;
half fOsc = Oscillate(vPos, fTime * _BranchElasticitySpeed, fOffset, fWeight, fWhip, fTwitch, fTwitchScale, vOscillations, vRotatedWindVector) * _BranchElasticity;
vPos.xyz += vWindVector * fOsc * fDistance;
half fAdherenceScale = 1.0;
fAdherenceScale = Turbulence(fTime, fOffset, _ST_WindAnimation.x, fTurbulence);
half3 vWindAdherenceVector = vRotatedBranchAnchor - vPos.xyz;
vPos.xyz += vWindAdherenceVector * fAdherence * fAdherenceScale * fWeight;
return vPos;
}

///////////////////////////////////////////////////////////////////

half3 FinalBranchWind(bool isPineWind, half3 vPos, half3 vInstancePos, half4 vWindData, half3 vRotatedWindVector, half3 vRotatedBranchAnchor) {
if (isPineWind) vPos = PineBranchWind(vPos, vInstancePos, vWindData.x, vWindData.y, _ST_WindBranch.x, _ST_WindBranch.y, _ST_WindTurbulences.x, _ST_WindBranchAdherences.y, _ST_WindBranchTwitch.x, _ST_WindBranchTwitch.y, _ST_WindBranchWhip.x, vRotatedWindVector, vRotatedBranchAnchor);
else vPos = LeafyBranchWind(vPos, vInstancePos, vWindData.x, vWindData.y, _ST_WindBranch.x, _ST_WindBranch.y, _ST_WindBranchTwitch.x, _ST_WindBranchTwitch.y, _ST_WindBranchWhip.x, vRotatedWindVector);
return vPos;
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


void OffsetTreeShaderVertex(inout TreeShaderVB data, half lodValue) {
half windType = _WindBranchQuality * _WindEnabled;
half3 finalPosition = data.vertex.xyz;
half3 rotatedWindVector, rotatedBranchAnchor;

if (windType <= 0) {
rotatedWindVector = half3(0.0f, 0.0f, 0.0f);
rotatedBranchAnchor = half3(0.0f, 0.0f, 0.0f);
}
else {
rotatedWindVector = normalize(mul(_ST_WindVector.xyz, (half3x3)unity_ObjectToWorld)) * _WindPower;
rotatedBranchAnchor = normalize(mul(_ST_WindBranchAnchor.xyz, (half3x3)unity_ObjectToWorld)) * _ST_WindBranchAnchor.w;
}
#ifdef LOD_FADE_PERCENTAGE
if (lodValue != 0) finalPosition = lerp(finalPosition, data.texcoord1.xyz, lodValue);
#endif
half3 treePos = half3(unity_ObjectToWorld[0].w, unity_ObjectToWorld[1].w, unity_ObjectToWorld[2].w);
if (windType >= 2) finalPosition = FinalBranchWind(windType == 3, finalPosition, treePos, half4(data.texcoord.zw, 0, 0), rotatedWindVector, rotatedBranchAnchor);
if (windType > 0) finalPosition = GlobalWind(finalPosition, treePos, rotatedWindVector, _ST_WindGlobal.x * _WindPowerSpeed);

data.vertex.xyz = finalPosition;
}

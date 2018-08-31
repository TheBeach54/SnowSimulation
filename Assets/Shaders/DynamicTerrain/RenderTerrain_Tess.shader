// Upgrade NOTE: replaced 'UNITY_INSTANCE_ID' with 'UNITY_VERTEX_INPUT_INSTANCE_ID'

//-----------------------------------------------------//
//Written By César Creutz for Better Call Medic - 2016 //
//-----------------------------------------------------//


Shader "Beach/DynamicTerrain/RenderTerrain_Tess" {
	Properties{

		[Header(Top Material Settings)]
	[HDR]_Color("Color", Color) = (1,1,1,1)
		_MainTex("Top Albedo", 2D) = "white" {}
	_MGOE("Top Metal Gloss Occlusion Emissive", 2D) = "black" {}
	_NormalMap("Top NormalMap", 2D) = "bump" {}
	_FlattenTopNM("_FlattenTopNM", Range(0,1)) = 0

		[Header(Bottom Material Settings)]
	[HDR]_BotColor("Color", Color) = (1,1,1,1)
		_SecTex("Bottom Albedo", 2D) = "white" {}
	_SecMGOE("Bottom Metal Gloss Occlusion Emissive", 2D) = "white" {}
	_SecNormalMap("Bottom Normal Map", 2D) = "bump" {}
	_FlattenBotNM("_FlattenBotNM", Range(0,1)) = 0

		[Header(Global Settings)]
	[HDR]_EmiCol("Emissive Color (rgb)", Color) = (1,1,1,1)
		_EmiMul("Emissive Multiply", Range(0, 20)) = 0


		[Header(Displacement)]
	[HideInInspector]_DisplaceTex("Height Map", 2D) = "black" {}
	[HideInInspector]_SnowMaxHeight("Snow Max Height", Range(0.001,200)) = 1
		[HideInInspector]_DisplacementIntensity("Displacement Intensity", Float) = 1
		_SampleDist("Sample Distance for normal reconstruction", Vector) = (0.1,0.1,0.1,0.1)

			_Scale("_Scale", Float) = 1
		[Header(Tesselation)]
		_minDist("Min Distance", Float) = 1
		_maxDist("Max Distance", Float) = 1
		[Space]
		_MinTess("Min Tesselation", Range(1,19)) = 1
		_MaxTess("Max Tesselation" , Range(2,50)) = 5


	}


		SubShader{
		Tags{ "RenderType" = "Opaque" "DisableBatching" = "True" "SnowFloor" = "True" }
		LOD 200


		Pass{
		Name "DEFERRED"
		Tags{ "LightMode" = "Deferred" }

		CGPROGRAM

#pragma vertex vert
#pragma fragment frag
#pragma hull hull
#pragma domain domain

#pragma target 5.0
#pragma exclude_renderers nomrt
#pragma multi_compile_prepassfinal
#pragma skip_variants FOG_LINEAR FOG_EXP FOG_EXP2
#include "HLSLSupport.cginc"
#include "UnityShaderVariables.cginc"

#define UNITY_PASS_DEFERRED
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "UnityPBSLighting.cginc"

#define INTERNAL_DATA half3 internalSurfaceTtoW0; half3 internalSurfaceTtoW1; half3 internalSurfaceTtoW2;
#define WorldReflectionVector(data,normal) reflect (data.worldRefl, half3(dot(data.internalSurfaceTtoW0,normal), dot(data.internalSurfaceTtoW1,normal), dot(data.internalSurfaceTtoW2,normal)))
#define WorldNormalVector(data,normal) fixed3(dot(data.internalSurfaceTtoW0,normal), dot(data.internalSurfaceTtoW1,normal), dot(data.internalSurfaceTtoW2,normal))





		sampler2D	_MainTex, _MGOE, _NormalMap, _SecNormalMap;
		sampler2D _SecTex, _SecMGOE;
		sampler2D_float _DisplaceTex;
		float4 _DisplaceTex_TexelSize;
	half		_EmiMul, _Speed, _DisplacementIntensity;
	float4		_EmiCol,_Color, _BotColor;
	float3 _SampleDist;
	float  _MinTess, _MaxTess, _Distance , _minDist, _maxDist;
	float _FlattenTopNM, _FlattenBotNM;
	float _SnowMaxHeight;
	float _Scale;

	struct Input {
		float2 uv_MainTex;
	};

	struct VertInput
	{
		float4 vertex : POSITION;
		float3 normal : NORMAL;
		float3 tangent : TANGENT;
		float2 uv : TEXCOORD0;
		float2 uv2 : TEXCOORD1;
	};


	struct HullInput
	{
		float4 vertex : POSITION;
		float4 normal_tessFac : NORMAL; // store tessFactor in normal
		float3 tangent : TANGENT;
		float3 binormal : BINORMAL;
		float4 uv : TEXCOORD0;
	};


	struct DomainInput
	{
		float4 vertex : SV_POSITION;
		float3 normal : NORMAL;
		float3 tangent : TANGENT;
		float3 binormal : BINORMAL;
		float4 uv : TEXCOORD0;
	};



	struct FragInput {
		float4 pos : SV_POSITION;
		float4 pack0 : TEXCOORD0; // _MainTex
		float4 tSpace0 : TEXCOORD1;
		float4 tSpace1 : TEXCOORD2;
		float4 tSpace2 : TEXCOORD3;

		float4 lmap : TEXCOORD5;

		half3 sh : TEXCOORD6; // SH

		UNITY_VERTEX_INPUT_INSTANCE_ID
	};

	struct HullConstantOutput
	{
		float TessFactor[3] : SV_TESSFACTOR;
		float InsideTessFactor : SV_INSIDETESSFACTOR;
	};

	float4 _MainTex_ST;


	HullInput vert(VertInput v)
	{
		HullInput o;
		o.vertex = mul(unity_ObjectToWorld, v.vertex);
		o.normal_tessFac.xyz = normalize(mul((float3x3)unity_ObjectToWorld, v.normal.xyz));
		o.tangent = mul((float3x3)unity_ObjectToWorld, v.tangent.xyz);
		o.binormal = normalize(cross(o.normal_tessFac.xyz, o.tangent));
		o.uv.xy = v.uv;
		o.uv.zw = v.uv2;
		float4 objectOrigin = mul(unity_ObjectToWorld, float4(0.0, 0.0, 0.0, 1.0));
		float dist = smoothstep(max(distance(_WorldSpaceCameraPos, objectOrigin.rgb), _minDist + 0.01), _minDist, _maxDist);
		o.normal_tessFac.w = clamp(_MaxTess * (1 - dist), _MinTess, _MaxTess);
		return o;

	}


	HullConstantOutput hullConstant(InputPatch<HullInput, 3> i)
	{
		HullConstantOutput o;


		o.InsideTessFactor = o.TessFactor[0] = o.TessFactor[1] = o.TessFactor[2] = _MaxTess;




		return o;

	}

	[domain("tri")]
	[partitioning("fractional_odd")]
	[outputtopology("triangle_cw")]
	[patchconstantfunc("hullConstant")]
	[outputcontrolpoints(3)]
	DomainInput hull(InputPatch < HullInput, 3> i, uint uCPID : SV_OutputControlPointID)
	{
		DomainInput o;
		o.vertex = i[uCPID].vertex;
		o.normal = i[uCPID].normal_tessFac.xyz;
		o.tangent = i[uCPID].tangent;
		o.binormal = i[uCPID].binormal;
		o.uv = i[uCPID].uv;

		return o;
	}


	[domain("tri")]
	FragInput domain(HullConstantOutput constantData, const OutputPatch<DomainInput, 3> i, float3 bary : SV_DomainLocation)
	{
		FragInput o;
		UNITY_INITIALIZE_OUTPUT(FragInput, o);
		float3 position = bary.x * i[0].vertex + bary.y * i[1].vertex + bary.z * i[2].vertex;
		float3 normal = bary.x * i[0].normal + bary.y * i[1].normal + bary.z * i[2].normal;
		float3 binormal = bary.x * i[0].binormal + bary.y * i[1].binormal + bary.z * i[2].binormal;
		float3 tangent = bary.x * i[0].tangent + bary.y * i[1].tangent + bary.z * i[2].tangent;
		float4 uv = bary.x * i[0].uv + bary.y * i[1].uv + bary.z * i[2].uv;

		float displace = tex2Dlod(_DisplaceTex, float4(uv.x, uv.y, 0.0f, 0.0f)).x;

		position += normalize(float3(0, 1, 0)) * saturate(1 - displace) * (_SnowMaxHeight);

		
		float3 realoff = float3(-1 * _DisplaceTex_TexelSize.x * _SampleDist.x, 0, 1 * _DisplaceTex_TexelSize.y * _SampleDist.z);
		float h00 = saturate(tex2Dlod(_DisplaceTex, float4(uv.x + realoff.x, uv.y + realoff.x,0,2)).x);//*scale*amplifyNormal;
		float h10 = saturate(tex2Dlod(_DisplaceTex, float4(uv.x + realoff.y, uv.y + realoff.x,0,2)).x);//*scale*amplifyNormal;
		float h20 = saturate(tex2Dlod(_DisplaceTex, float4(uv.x + realoff.z, uv.y + realoff.x,0,2)).x);//*scale*amplifyNormal;
		float h01 = saturate(tex2Dlod(_DisplaceTex, float4(uv.x + realoff.x, uv.y + realoff.y,0,2)).x);//*scale*amplifyNormal;
		float h11 = saturate(tex2Dlod(_DisplaceTex, float4(uv.x + realoff.y, uv.y + realoff.y,0,2)).x);//*scale*amplifyNormal;
		float h21 = saturate(tex2Dlod(_DisplaceTex, float4(uv.x + realoff.z, uv.y + realoff.y,0,2)).x);//*scale*amplifyNormal;
		float h02 = saturate(tex2Dlod(_DisplaceTex, float4(uv.x + realoff.x, uv.y + realoff.z,0,2)).x);//*scale*amplifyNormal;
		float h12 = saturate(tex2Dlod(_DisplaceTex, float4(uv.x + realoff.y, uv.y + realoff.z,0,2)).x);//*scale*amplifyNormal;
		float h22 = saturate(tex2Dlod(_DisplaceTex, float4(uv.x + realoff.z, uv.y + realoff.z,0,2)).x);//*scale*amplifyNormal;
		float Gx = h00 - h20 + 2.0f * h01 - 2.0f * h21 + h02 - h22;
		float Gy = h00 + 2.0f * h10 + h20 - h02 - 2.0f * h12 - h22;
		float Gz = 0.5f * sqrt(max(1.0f - Gx * Gx - Gy * Gy, 0.0f));

		float3 originalNormal = normalize(float3(2.0f * Gx, 2.0f * Gy, Gz ));

		originalNormal = normalize(lerp(float3(0, 0, 1), originalNormal,  _SnowMaxHeight));


		o.pos = mul(UNITY_MATRIX_VP, float4(position, 1.0f));
		o.pack0.xy = uv.xy;
		float3 worldPos = position;

		normal = normalize(normal);
		tangent = normalize(tangent);
		binormal = normalize(binormal);

		o.tSpace0 = float4(-tangent.x, binormal.x, normal.x, worldPos.x);
		o.tSpace1 = float4(-tangent.y, binormal.y, normal.y, worldPos.y);
		o.tSpace2 = float4(-tangent.z, binormal.z, normal.z, worldPos.z);

		float3 worldN;


		worldN.x = dot(o.tSpace0.xyz, originalNormal);
		worldN.y = dot(o.tSpace1.xyz, originalNormal);
		worldN.z = dot(o.tSpace2.xyz, originalNormal);

		
		fixed3 worldTangent = tangent;
		//fixed tangentSign = tang.w * unity_WorldTransformParams.w;
		fixed3 worldNormal = normalize(worldN);// lerp(normalize(normal), normalize(displace.rgb * 2 - 1), displace.r);
		fixed3 worldBinormal = binormal;

		o.tSpace0 = float4(worldTangent.x, worldBinormal.x, worldN.x, worldPos.x);
		o.tSpace1 = float4(worldTangent.y, worldBinormal.y, worldN.y, worldPos.y);
		o.tSpace2 = float4(worldTangent.z, worldBinormal.z, worldN.z, worldPos.z);

		float3 viewDirForLight = UnityWorldSpaceViewDir(worldPos);

#ifndef DYNAMICLIGHTMAP_OFF
		o.lmap.zw = uv.zw * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif

		return o;

	}

#ifdef LIGHTMAP_ON
	float4 unity_LightmapFade;
#endif
	fixed4 unity_Ambient;


	// fragment shader
	void frag(FragInput IN,
		out half4 outDiffuse : SV_Target0,
		out half4 outSpecSmoothness : SV_Target1,
		out half4 outNormal : SV_Target2,
		out half4 outEmission : SV_Target3) {
		UNITY_SETUP_INSTANCE_ID(IN);
		// prepare and unpack data
		Input surfIN;
		UNITY_INITIALIZE_OUTPUT(Input,surfIN);
		surfIN.uv_MainTex.x = 1.0;
		surfIN.uv_MainTex = IN.pack0.xy;
		float3 worldPos = float3(IN.tSpace0.w, IN.tSpace1.w, IN.tSpace2.w);
#ifndef USING_DIRECTIONAL_LIGHT
		fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
#else
		fixed3 lightDir = _WorldSpaceLightPos0.xyz;
#endif
		fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
#ifdef UNITY_COMPILER_HLSL
		SurfaceOutputStandard o = (SurfaceOutputStandard)0;
#else
		SurfaceOutputStandard o;
#endif
		//o.Albedo = 0.0;
		//o.Emission = 0.0;
		//o.Alpha = 0.0;
		//o.Occlusion = 1.0;
		fixed3 normalWorldVertex = fixed3(0,0,1);

		// call surface function
		//surf(surfIN, o);

		// Shader

		//fixed4 mgoe = tex2D(_MGOE, surfIN.uv_MainTex).rgba;
		float4 displace = saturate(tex2D(_DisplaceTex, surfIN.uv_MainTex.xy));

		float2 nUV = surfIN.uv_MainTex * _MainTex_ST.xy + _MainTex_ST.zw;

		half3 emiColor = _EmiCol.rgb;
		half3 lerpColor = lerp(_Color, _BotColor, displace.x);


		half4 topNormal = lerp(tex2D(_NormalMap, nUV), float4(1, 0.5, 1, 0.5), _FlattenTopNM);
		half4 botNormal = lerp(tex2D(_SecNormalMap, nUV), float4(1, 0.5, 1, 0.5), _FlattenBotNM);
		
		half4 topAlbedo = tex2D(_MainTex, nUV) * _Color;
		half4 botAlbedo = tex2D(_SecTex, nUV) * _BotColor;

		half4 topMGOE = tex2D(_MGOE, nUV).rgba;
		half4 botMGOE = tex2D(_SecMGOE, nUV).rgba;

		half lerper = displace.x * (1 - displace.b);
		fixed4 color = lerp(topAlbedo, botAlbedo, lerper);
		fixed4 mgoe = lerp(topMGOE, botMGOE, lerper);

		// Output Shader
		//o.Albedo = float3(0, displace.g, 0);// color.rgb;
		o.Albedo =  color.rgb;

		o.Normal = UnpackNormal(lerp(topNormal, botNormal, lerper));
		o.Metallic = mgoe.r;
		o.Smoothness = mgoe.g;
		o.Occlusion = mgoe.b;

		o.Emission = _EmiMul  * color.rgb * mgoe.a * _EmiCol;
		o.Alpha = color.a * mgoe.b;

		// End Shader

		fixed3 originalNormal = o.Normal;
		fixed3 worldN;
		worldN.x = dot(IN.tSpace0.xyz, o.Normal);
		worldN.y = dot(IN.tSpace1.xyz, o.Normal);
		worldN.z = dot(IN.tSpace2.xyz, o.Normal);
		o.Normal = worldN;
		half atten = 1;

		// Setup lighting environment
		UnityGI gi;
		UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
		gi.indirect.diffuse = 0;
		gi.indirect.specular = 0;
		gi.light.color = 0;
		gi.light.dir = half3(0,1,0);
		gi.light.ndotl = LambertTerm(o.Normal, gi.light.dir);
		// Call GI (lightmaps/SH/reflections) lighting function
		UnityGIInput giInput;
		UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);
		giInput.light = gi.light;
		giInput.worldPos = worldPos;
		giInput.worldViewDir = worldViewDir;
		giInput.atten = atten;
#if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
		giInput.lightmapUV = IN.lmap;
#else
		giInput.lightmapUV = 0.0;
#endif

		giInput.ambient = IN.sh;

		giInput.probeHDR[0] = unity_SpecCube0_HDR;
		giInput.probeHDR[1] = unity_SpecCube1_HDR;
#if UNITY_SPECCUBE_BLENDING || UNITY_SPECCUBE_BOX_PROJECTION
		giInput.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
#endif
#if UNITY_SPECCUBE_BOX_PROJECTION
		giInput.boxMax[0] = unity_SpecCube0_BoxMax;
		giInput.probePosition[0] = unity_SpecCube0_ProbePosition;
		giInput.boxMax[1] = unity_SpecCube1_BoxMax;
		giInput.boxMin[1] = unity_SpecCube1_BoxMin;
		giInput.probePosition[1] = unity_SpecCube1_ProbePosition;
#endif
		LightingStandard_GI(o, giInput, gi);

		// call lighting function to output g-buffer
		outEmission = LightingStandard_Deferred(o, worldViewDir, gi, outDiffuse, outSpecSmoothness, outNormal);
#ifndef UNITY_HDR_ON
		outEmission.rgb = exp2(-outEmission.rgb);
#endif
	}

	ENDCG

	}

		// ---- shadow caster pass:
		Pass{
		Name "ShadowCaster"
		Tags{ "LightMode" = "ShadowCaster" }
		ZWrite On ZTest LEqual Cull Off

		CGPROGRAM
		// compile directives
#pragma vertex vert
#pragma fragment frag
#pragma hull hull
#pragma domain domain
#pragma target 5.0
#pragma multi_compile_shadowcaster

#include "UnityCG.cginc"
#include "AutoLight.cginc"





	struct VertInput
	{
		float4 vertex : POSITION;
		float3 normal : NORMAL;
		float2 uv : TEXCOORD0;

	};


	struct HullInput
	{
		float4 vertex : POSITION;
		float4 normal_tessFac : NORMAL;
		float2 uv : TEXCOORD0;

	};


	struct DomainInput
	{
		
		float4 vertex : SV_POSITION;
		float3 normal : NORMAL;
		float2 uv : TEXCOORD0;

	};

	struct GeomInput
	{
		float4 pos : SV_POSITION;
		float3 normal : NORMAL;
		float2 uv : TEXCOORD0;
	};



	struct FragInput {
		V2F_SHADOW_CASTER;
		float3 normal : NORMAL;
		float2 uv : ATTR0;

	};

	struct HullConstantOutput
	{
		float TessFactor[3] : SV_TESSFACTOR;
		float InsideTessFactor : SV_INSIDETESSFACTOR;
	};

	struct ShadowTrans
	{
		float3 vertex;
		float3 normal;
	};

	sampler2D _DisplaceTex;
	float4 _MainTex_ST, _DisplaceTex_ST;

	float _DisplacementIntensity;
	float _minDist,_maxDist, _MinTess, _MaxTess;
	float _SnowMaxHeight;


	HullInput vert(VertInput v)
	{
		HullInput o;
		o.vertex = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1.0f));
		o.normal_tessFac.xyz = mul((float3x3)unity_ObjectToWorld, v.normal.xyz);

		float4 objectOrigin = mul(unity_ObjectToWorld, float4(0.0, 0.0, 0.0, 1.0));
		float dist = smoothstep(max(distance(_WorldSpaceCameraPos, objectOrigin.rgb), _minDist + 0.01), _minDist, _maxDist);
		o.normal_tessFac.w = clamp(_MaxTess * (1 - dist), _MinTess, _MaxTess);
		o.uv.xy = v.uv;

		return o;

	}


	HullConstantOutput hullConstant(InputPatch<HullInput, 3> i)
	{
		HullConstantOutput o;

		o.InsideTessFactor = o.TessFactor[0] = o.TessFactor[1] = o.TessFactor[2] = _MaxTess;

		return o;

	}

	[domain("tri")]
	[partitioning("fractional_odd")]
	[outputtopology("triangle_cw")]
	[patchconstantfunc("hullConstant")]
	[outputcontrolpoints(3)]
	DomainInput hull(InputPatch < HullInput, 3> i, uint uCPID : SV_OutputControlPointID)
	{
		DomainInput o;
		o.vertex = i[uCPID].vertex;
		o.normal = i[uCPID].normal_tessFac.xyz;

		o.uv = i[uCPID].uv;

		return o;
	}



	[domain("tri")]
	FragInput domain(HullConstantOutput constantData, const OutputPatch<DomainInput, 3> i, float3 bary : SV_DomainLocation)
	{
		FragInput o;
		ShadowTrans v;
		float3 position = bary.x * i[0].vertex + bary.y * i[1].vertex + bary.z * i[2].vertex;
		float3 normal = bary.x * i[0].normal + bary.y * i[1].normal + bary.z * i[2].normal;
		float2 uv = bary.x * i[0].uv + bary.y * i[1].uv + bary.z * i[2].uv;


		float4 displace = tex2Dlod(_DisplaceTex, float4(uv.xy, 0.0f, 0.0f));

		position += normalize(float3(0,1,0)) * saturate(1 - displace.x) *  _SnowMaxHeight;






		fixed3 worldNormal = normalize(normal + (displace.rgb * 2 - 1));

		//v.vertex = mul(unity_WorldToObject, position);
		
		//o.pos = float4(position,1); 

		float3 pos2 = mul(unity_WorldToObject, float4(position, 1.0f));
		o.pos = mul(UNITY_MATRIX_VP, float4(position, 1));

		o.normal = normalize(normal);

		v.vertex = float4(pos2, 1);

		o.uv = uv;
		TRANSFER_SHADOW_CASTER(o);

		return o;

	}
	

	// fragment shader
	fixed4 frag(FragInput IN) : SV_Target{

		SHADOW_CASTER_FRAGMENT(IN)
		return float4(1,1,1,1);

	}

		ENDCG

	}

		// ---- meta information extraction pass:
		Pass{
		Name "Meta"
		Tags{ "LightMode" = "Meta" }
		Cull Off

		CGPROGRAM
		// compile directives
#pragma vertex vert_surf
#pragma fragment frag_surf
#pragma target 5.0
#pragma skip_variants FOG_LINEAR FOG_EXP FOG_EXP2
#pragma skip_variants INSTANCING_ON

#include "HLSLSupport.cginc"
#include "UnityShaderVariables.cginc"

#define UNITY_PASS_META
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "UnityPBSLighting.cginc"

#define INTERNAL_DATA half3 internalSurfaceTtoW0; half3 internalSurfaceTtoW1; half3 internalSurfaceTtoW2;
#define WorldReflectionVector(data,normal) reflect (data.worldRefl, half3(dot(data.internalSurfaceTtoW0,normal), dot(data.internalSurfaceTtoW1,normal), dot(data.internalSurfaceTtoW2,normal)))
#define WorldNormalVector(data,normal) fixed3(dot(data.internalSurfaceTtoW0,normal), dot(data.internalSurfaceTtoW1,normal), dot(data.internalSurfaceTtoW2,normal))


#ifdef DUMMY_PREPROCESSOR_TO_WORK_AROUND_HLSL_COMPILER_LINE_HANDLING
#endif




		sampler2D	_MainTex, _MGOE, _NormalMap;
	half		_EmiMul;
	float4		_EmiCol,_Color;

	struct Input {
		float2 uv_MainTex;
	};





#include "UnityMetaPass.cginc"

	// vertex-to-fragment interpolation data
	struct v2f_surf {
		float4 pos : SV_POSITION;
		float2 pack0 : TEXCOORD0; // _MainTex
		float4 tSpace0 : TEXCOORD1;
		float4 tSpace1 : TEXCOORD2;
		float4 tSpace2 : TEXCOORD3;
	};
	float4 _MainTex_ST;

	// vertex shader
	v2f_surf vert_surf(appdata_full v) {
		v2f_surf o;
		UNITY_INITIALIZE_OUTPUT(v2f_surf,o);
		//v.vertex = float4(v.vertex.xyz + v.normal, v.vertex.w);
		o.pos = UnityMetaVertexPosition(v.vertex, v.texcoord1.xy, v.texcoord2.xy, unity_LightmapST, unity_DynamicLightmapST);
		o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
		float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
		fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
		fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
		fixed tangentSign = v.tangent.w * unity_WorldTransformParams.w;
		fixed3 worldBinormal = cross(worldNormal, worldTangent) * tangentSign;
		o.tSpace0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
		o.tSpace1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
		o.tSpace2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
		return o;
	}

	// fragment shader
	fixed4 frag_surf(v2f_surf IN) : SV_Target{
		// prepare and unpack data
		Input surfIN;
	UNITY_INITIALIZE_OUTPUT(Input,surfIN);
	surfIN.uv_MainTex.x = 1.0;
	surfIN.uv_MainTex = IN.pack0.xy;
	float3 worldPos = float3(IN.tSpace0.w, IN.tSpace1.w, IN.tSpace2.w);
#ifndef USING_DIRECTIONAL_LIGHT
	fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
#else
	fixed3 lightDir = _WorldSpaceLightPos0.xyz;
#endif
#ifdef UNITY_COMPILER_HLSL
	SurfaceOutputStandard o = (SurfaceOutputStandard)0;
#else
	SurfaceOutputStandard o;
#endif

	fixed3 normalWorldVertex = fixed3(0,0,1);



	fixed4 mgoe = tex2D(_MGOE, surfIN.uv_MainTex).rgba;
	fixed4 color = tex2D(_MainTex, surfIN.uv_MainTex);


	half3 emiColor = _EmiCol.rgb;



	o.Albedo = color.rgb *_Color;

	o.Normal = UnpackNormal(tex2D(_NormalMap, surfIN.uv_MainTex));
	o.Metallic = mgoe.r;
	o.Smoothness = mgoe.g;
	o.Occlusion = mgoe.b;

	o.Emission = _EmiMul  * color.rgb * mgoe.a * _EmiCol;
	o.Alpha = color.a * mgoe.b;


	UnityMetaInput metaIN;
	UNITY_INITIALIZE_OUTPUT(UnityMetaInput, metaIN);
	metaIN.Albedo = o.Albedo;
	metaIN.Emission = o.Emission;
	return UnityMetaFragment(metaIN);
	}

		ENDCG

	}
	


	}
		FallBack "VertexLit"
}

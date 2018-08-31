Shader "Beach/DynamicTerrain/Surface_RenderTerrain_Tess" {
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

	[Header(Tesselation)]
	_EdgeLength("Edge length", Range(2,50)) = 15
	[HideInInspector]_Scale("_Scale", Float) = 1


	}
		SubShader{
		Tags{ "RenderType" = "Opaque" "SnowFloor" = "True" }
		LOD 300

		CGPROGRAM
#pragma surface surf Standard addshadow fullforwardshadows vertex:disp tessellate:tessEdge nolightmap
//#pragma target 4.6
#include "Tessellation.cginc"

	struct appdata {
		float4 vertex : POSITION;
		float4 tangent : TANGENT;
		float3 normal : NORMAL;
		float2 texcoord : TEXCOORD0;
	};

	float _EdgeLength;

	float4 tessEdge(appdata v0, appdata v1, appdata v2)
	{
		return UnityEdgeLengthBasedTess(v0.vertex, v1.vertex, v2.vertex, _EdgeLength);
	}


	sampler2D	_MainTex, _MGOE, _NormalMap, _SecNormalMap;
	sampler2D _SecTex, _SecMGOE;
	sampler2D_float _DisplaceTex;
	float4 _DisplaceTex_TexelSize;

	half		_EmiMul, _Speed, _DisplacementIntensity;
	float4		_EmiCol, _Color, _BotColor;
	float3 _SampleDist;
	float  _MinTess, _MaxTess, _Distance, _minDist, _maxDist;
	float _FlattenTopNM;
	float _FlattenBotNM;
	float _Scale;
	float _SnowMaxHeight;

	void disp(inout appdata v)
	{
		float displace = tex2Dlod(_DisplaceTex, float4(v.texcoord.xy, 0.0f, 0.0f)).x;

		v.vertex.xyz += normalize(float3(0, 1, 0)) * saturate(1 - displace.x) * (_SnowMaxHeight) * (1/_Scale);

		float2 uv = v.texcoord.xy;

		float3 realoff = float3(-1 * _DisplaceTex_TexelSize.x * _SampleDist.x, 0, 1 * _DisplaceTex_TexelSize.y * _SampleDist.z);
		float h00 = saturate(tex2Dlod(_DisplaceTex, float4(uv.x + realoff.x, uv.y + realoff.x, 0, 2)).x);//*scale*amplifyNormal;
		float h10 = saturate(tex2Dlod(_DisplaceTex, float4(uv.x + realoff.y, uv.y + realoff.x, 0, 2)).x);//*scale*amplifyNormal;
		float h20 = saturate(tex2Dlod(_DisplaceTex, float4(uv.x + realoff.z, uv.y + realoff.x, 0, 2)).x);//*scale*amplifyNormal;
		float h01 = saturate(tex2Dlod(_DisplaceTex, float4(uv.x + realoff.x, uv.y + realoff.y, 0, 2)).x);//*scale*amplifyNormal;
		float h11 = saturate(tex2Dlod(_DisplaceTex, float4(uv.x + realoff.y, uv.y + realoff.y, 0, 2)).x);//*scale*amplifyNormal;
		float h21 = saturate(tex2Dlod(_DisplaceTex, float4(uv.x + realoff.z, uv.y + realoff.y, 0, 2)).x);//*scale*amplifyNormal;
		float h02 = saturate(tex2Dlod(_DisplaceTex, float4(uv.x + realoff.x, uv.y + realoff.z, 0, 2)).x);//*scale*amplifyNormal;
		float h12 = saturate(tex2Dlod(_DisplaceTex, float4(uv.x + realoff.y, uv.y + realoff.z, 0, 2)).x);//*scale*amplifyNormal;
		float h22 = saturate(tex2Dlod(_DisplaceTex, float4(uv.x + realoff.z, uv.y + realoff.z, 0, 2)).x);//*scale*amplifyNormal;
		float Gx = h00 - h20 + 2.0f * h01 - 2.0f * h21 + h02 - h22;
		float Gy = h00 + 2.0f * h10 + h20 - h02 - 2.0f * h12 - h22;
		float Gz = 0.5f * sqrt(max(1.0f - Gx * Gx - Gy * Gy, 0.0f));

		float3 originalNormal = normalize(float3(2.0f * Gx, 2.0f * Gy, Gz ));
		originalNormal = normalize(lerp(float3(0, 0, 1), originalNormal, _SnowMaxHeight));



		float3 normal = normalize(v.normal);
		float3 tangent = normalize(v.tangent);
		float3 binormal = normalize(cross(normal, tangent));


		float3 tSpace0 = float3(-tangent.x, binormal.x, normal.x);
		float3 tSpace1 = float3(-tangent.y, binormal.y, normal.y);
		float3 tSpace2 = float3(-tangent.z, binormal.z, normal.z);

		float3 worldN;


		worldN.x = dot(tSpace0.xyz, originalNormal);
		worldN.y = dot(tSpace1.xyz, originalNormal);
		worldN.z = dot(tSpace2.xyz, originalNormal);
		
		v.normal = worldN;
		//float d = tex2Dlod(_DisplaceTex, float4(v.texcoord.xy,0,0)).r * _Displacement;
		//v.vertex.xyz += v.normal * d;
	}

	struct Input {
		float2 uv_MainTex;
		float2 uv_DisplaceTex;
	};



	void surf(Input IN, inout SurfaceOutputStandard o) {
		//fixed4 mgoe = tex2D(_MGOE, IN.uv_MainTex).rgba;
		float4 displace = saturate(tex2D(_DisplaceTex, IN.uv_DisplaceTex.xy));

		float2 nUV = IN.uv_MainTex;

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
		o.Albedo = color.rgb;

		o.Normal = UnpackNormal(lerp(topNormal, botNormal, lerper));
		o.Metallic = mgoe.r;
		o.Smoothness = mgoe.g;
		o.Occlusion = mgoe.b;

		o.Emission = _EmiMul  * color.rgb * mgoe.a * _EmiCol;
		o.Alpha = color.a * mgoe.b;
	}
	ENDCG
	}
		FallBack "Diffuse"
}
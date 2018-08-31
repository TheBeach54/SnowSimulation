Shader "Beach/DynamicTerrain/Terrain_RenderDepth"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	
	SubShader
	{
		Tags { "RenderType"="Opaque" "TerrainEffect" = "DynamicObject"}
		LOD 100

		Pass
		{
			ColorMask R
			//ZTest Always
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float depth : TEXCOORD1;
				float3 normal : NORMAL;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			sampler2D _FloorHeight;
			float4 _MainTex_ST;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex) ;
				o.vertex = float4(o.vertex.x, o.vertex.y, o.vertex.z, o.vertex.w);
				o.depth = -mul(UNITY_MATRIX_MV, v.vertex).z * _ProjectionParams.w;
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				float3 wNorm = mul((float3x3)unity_ObjectToWorld, v.normal).xyz;
				//o.normal = normalize(mul(UNITY_MATRIX_V, float4(wNorm,0.0f)).xyz);
				o.normal = normalize(wNorm);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			
			float4 frag (v2f i) : SV_Target
			{
				float4 o;			

			o.rgb = float3(1 - i.depth, 0,0);
			o.a = 0;
			return o;
			}
			ENDCG
		}

		
	}

		SubShader
			{
				Tags{ "RenderType" = "Opaque" "SnowFloor" = "True"}
				LOD 100

				Pass
			{
				ColorMask R
				Cull Front
				ZTest Always
				CGPROGRAM
#pragma vertex vert
#pragma fragment frag
				// make fog work
#pragma multi_compile_fog

#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float depth : TEXCOORD1;
				float3 normal : NORMAL;
				UNITY_FOG_COORDS(1)
					float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.vertex = float4(o.vertex.x, o.vertex.y, o.vertex.z, o.vertex.w);
				o.depth = -mul(UNITY_MATRIX_MV, v.vertex).z * _ProjectionParams.w;
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				float3 wNorm = mul((float3x3)unity_ObjectToWorld, v.normal).xyz;
				//o.normal = normalize(mul(UNITY_MATRIX_V, float4(wNorm,0.0f)).xyz);
				o.normal = normalize(wNorm);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				float4 o;

			o.rgb = float3(1 - i.depth, 0,0);
			o.a = 0;
			return o;
			}
				ENDCG
			}


			}
}

Shader "Beach/DynamicTerrain/ShowNormal"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	_pow("power", Float) = 1.0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float4 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
				
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float _pow;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);

				o.normal = mul((float3x3)unity_ObjectToWorld, v.normal.xyz);

				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 o;
				// sample the texture
				fixed4 col = tex2D(_MainTex, i.uv);

				o.a = 1.0f;
				float3 normal = i.normal;
				for (int x = 0; x < floor(_pow); x++)
				{
					normal *= normal;
				}
				i.uv = float2(cos(_pow)+ i.uv.x, sin(_pow)+ i.uv.y);
				o.rgb = float3(i.uv,0.0f);

				float radial = pow((1 - length(float2(0.5, 0.5) - i.uv)), 8);
				return o;
			}
			ENDCG
		}
	}
}

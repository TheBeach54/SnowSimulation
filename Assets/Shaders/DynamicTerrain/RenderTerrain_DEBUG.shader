Shader "Beach/DynamicTerrain/Debug/RenderTerrain"
{
	Properties
	{
		_DisplaceTex ("Texture", 2D) = "white" {}
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
			// make fog work
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			sampler2D _DisplaceTex;
			float4 _DisplaceTex_ST;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _DisplaceTex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 o;
				float2 uv = float2(i.uv.x,i.uv.y);
				// sample the texture
				float4 col = tex2D(_DisplaceTex, uv);

				float depth = col;
				// apply fog
				//o.rgb = col.rgb * 2 - 1;
				//o.a = depth;
				return col;
			}
			ENDCG
		}
	}
}

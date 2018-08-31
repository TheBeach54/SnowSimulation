Shader "Unlit/Fractal"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	_Zoom("Zoom", Range(0.1,50)) = 1
		_OffsetX("Offset X", Range(-1,1)) = 0
		_OffsetY("Offset Y", Range(-1,1)) = 0
		_ColorA("ColorA", Color) = (1,1,1,1)
		_ColorB("ColorB", Color) = (0,0,0,1)

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
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float _Zoom, _OffsetX, _OffsetY;
			float4 _ColorA, _ColorB;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float2 coord = i.uv * 2.0f - 1.0f;
				coord /= _Zoom;
				coord += float2(_OffsetX, _OffsetY);
				
				float counter = 0.0f;
				float upperLimit = 256.0f * 256.0f;
				float iterationCount = 200.0f;
				float2 z = float2(0.0f, 0.0f);

				for (int i; i < iterationCount; i++)
				{
					// z = z*z +c
					z = float2(z.x*z.x*((sin(_Time.y * 5)*0.5 + 0.5)*0.5 + 0.5) - z.y*z.y*((cos(_Time.y * 5)*0.5 + 0.5)*0.5 + 0.5), 2.0f*z.x*z.y) + coord;

					if (dot(z, z) > upperLimit)
						break;

					counter++;

				}
				counter /= iterationCount;
				

				fixed4 col = lerp(_ColorA, _ColorB, counter);

				return col;
			}
			ENDCG
		}
	}
}

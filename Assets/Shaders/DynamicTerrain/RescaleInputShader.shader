Shader "Beach/DynamicTerrain/RescaleInputShader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	_Min("Min",Float) = 0
		_Max("Max", Float) = 1
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
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float _Tilling;
			float _Min;
			float _Max;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				// We just rescale the uv's to choose the tilling
				o.uv = v.uv * _Tilling;
				return o;
			}
			
			float4 frag (v2f i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.uv);
				//We rerange the input height to the desired gradient
				float final = lerp(_Min, _Max, col.x);
				return final.xxxx;
			}
			ENDCG
		}
	}
}

//--------------------------------------------//
//------GPU Particle System for Unity 5.5-----//
//---------Made using Unity 5.5.0f3-----------//
//-----------By César Creutz------------------//
//----------------2017------------------------//
//--------------------------------------------//

Shader "Beach/ParticleGPU/ParticleShader"
{
	Properties
	{
		_Color1("Color", Color) = (1,1,1,1)
		_Color2("Color", Color) = (1,1,1,1)

		_MinScale("_MinScale",Float) = 1
		_MaxScale("_MaxScale", Float) = 1
		//_MinImpactScale("_MinImpactScale", Float) = 1
		//_MaxImpactSCale("_MaxImpactScale", Float) = 1

		_RandomTex("_RandomTex",2D) = "bump" {}
		_UseRandomAngle("_UseRandomAngle",Float) = 0

		_AngularSpeed("AngularSpeed", Float) = 0
		_VelocityStretch("Velocity", Float) = 0
		_FadeIn("Fadein", Float) = 0
		_FadeOut("FadeOut",Float) = 0
		_MainTex("Texture", 2D) = "white" {}
		_Scale("Scale", Float) = 1.0
		_AngularSpeed("_AngularSpeed", Float) = 1.0
		_Off("_Off", Float) = 1.0
		_Slo("_Slo", Float) = 1.0
		[Enum(UnityEngine.Rendering.CompareFunction)]_ZTest("_ZTest", Float) = 0
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("_SrcBlend", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("_DstBlend", Float) = 1




	}
		SubShader
		{
			Tags{"Queue" = "Transparent+10"  "RenderType" = "Transparent" "SnowEffect" = "A" }

			Pass
			{

				Blend[_SrcBlend][_DstBlend]
				ZWrite Off
				ZTest[_ZTest]
				Offset[_Off],[_Slo]

				CGPROGRAM
				#pragma vertex vert
				#pragma geometry geom
				#pragma fragment frag
				#pragma target 5.0	

				#include "UnityCG.cginc"

				struct Particle
				{
					float4 position; // xyz = wPos, w = Life duration 
					float4 speedLife; // xyz = Speed, w = Life expectancy
					float4 color;
					float4 seed;
				};

				StructuredBuffer<Particle> particleBuffer;


				struct GeomInput
				{
					float4 position : POSITION;
					float4 color : COLOR;
					float4 speed : TEXCOORD0;
					float4 seed : TEXCOORD1;
				};

				struct FragInput
				{
					float4 position : SV_POSITION;
					float4 color : COLOR;
					float2 uv : TEXCOORD0;
				};

				sampler2D _MainTex;
				sampler2D _RandomTex;
				float4 _MainTex_ST;
				float4 _Color1;
				float4 _Color2;
				float _UseRandomAngle;
				float _MinScale, _MaxScale;
				float _AngularSpeed;
				float _VelocityStretch;
				float _FadeIn;
				float _FadeOut;

				GeomInput vert(uint inst : SV_InstanceID)
				{
					GeomInput geo;
					float4 color = particleBuffer[inst].color;
					float4 position = particleBuffer[inst].position;
					float4 speedLife = particleBuffer[inst].speedLife;
					float4 seed = particleBuffer[inst].seed;

					geo.position = position;
					geo.color = color;
					geo.speed = speedLife;
					geo.seed = seed;

					return geo;
				}


				void AddPoint(float3 pos, float4 col, float2 uv, inout TriangleStream<FragInput> stream)
				{
					FragInput output;

					output.color = col;
					//From world to projection
					output.position = mul(UNITY_MATRIX_VP,float4(pos, 1.0f));
					output.uv = uv;
					stream.Append(output);

				}

				[maxvertexcount(4)]
				void geom(point GeomInput p[1], inout TriangleStream<FragInput> triStream)
				{
					if (p[0].speed.w <= 0.0f)
						return;

					const float pi = 3.1415;
					const float hp = pi*0.5;
					const float phi = pi * 2;

					float4 randomSeed = tex2Dlod(_RandomTex, float4(p[0].seed.xy,0,0));

					// Setting up the lifetime lerper
					float lifeDuration = p[0].position.w;
					float lifeExpectancy = p[0].speed.w;
					float life01 = (lifeDuration - lifeExpectancy) / lifeDuration;

					// Setting up the vector for drawing the points
					float3 up = UNITY_MATRIX_IT_MV[1].xyz;
					float3 look = _WorldSpaceCameraPos - p[0].position.xyz;
					look = normalize(look);
					float3 right = cross(up,look);



					// Add rotation and random angle
					float randomAngle = p[0].seed.y * phi * _UseRandomAngle + _Time.x * _AngularSpeed * sign(p[0].seed.z * 2 - 1);

					float scale = lerp(_MinScale, _MaxScale, p[0].seed.y);

					// Setting up speed deformer ( will be used later )
					float4 viewSpeed = mul(UNITY_MATRIX_MV,float4(p[0].speed.xyz, 0.0f));
					float speed = length(viewSpeed.xy);
					float2 speedDir = normalize(viewSpeed.xy);

					float halfSize = 0.5f * scale;

					float3 newRight = right *(-speedDir.x) + up * (speedDir.y);
					float3 newUp = cross(look, newRight);
					float3 offset = speed * newRight * _VelocityStretch;



					//Apply vector from position
					float3 position = p[0].position.xyz;
					float4 v[4];
					float2 uv[4];

					v[0] = float4(position + offset + halfSize * newRight - halfSize* newUp, 1.0f);
					v[1] = float4(position + offset + halfSize * newRight + halfSize* newUp, 1.0f);
					v[2] = float4(position - halfSize * newRight - halfSize* newUp, 1.0f);
					v[3] = float4(position - halfSize * newRight + halfSize* newUp, 1.0f);


					float x;


					x = randomAngle;
					uv[0].x = min((-asin(cos(x - hp)) / pi) * 2 + 1, 1) + min((asin(cos(x - pi)) / pi) * 2, 0);
					uv[0].y = min((-asin(cos(x)) / pi) * 2 + 1, 1) + min((asin(cos(x - hp)) / pi) * 2, 0);

					x = randomAngle - hp;
					uv[1].x = min((-asin(cos(x - hp)) / pi) * 2 + 1, 1) + min((asin(cos(x - pi)) / pi) * 2, 0);
					uv[1].y = min((-asin(cos(x)) / pi) * 2 + 1, 1) + min((asin(cos(x - hp)) / pi) * 2, 0);

					x = randomAngle - hp * 2;
					uv[3].x = min((-asin(cos(x - hp)) / pi) * 2 + 1, 1) + min((asin(cos(x - pi)) / pi) * 2, 0);
					uv[3].y = min((-asin(cos(x)) / pi) * 2 + 1, 1) + min((asin(cos(x - hp)) / pi) * 2, 0);

					x = randomAngle - hp * 3;
					uv[2].x = min((-asin(cos(x - hp)) / pi) * 2 + 1, 1) + min((asin(cos(x - pi)) / pi) * 2, 0);
					uv[2].y = min((-asin(cos(x)) / pi) * 2 + 1, 1) + min((asin(cos(x - hp)) / pi) * 2, 0);


					// Random Color for each particle
					float4 color = lerp(_Color1, _Color2, p[0].seed.w);

					// Modify Color Over Lifetime
					float alphaOverLife = smoothstep(1.0f, _FadeOut, life01) * smoothstep(0.0f,_FadeIn, life01);
					color *= alphaOverLife;



					//Add Point to the Stream
					AddPoint(v[0], color,uv[0], triStream);
					AddPoint(v[1], color,uv[1], triStream);
					AddPoint(v[2], color,uv[2], triStream);
					AddPoint(v[3], color,uv[3], triStream);
					triStream.RestartStrip();

					return;

				}

				fixed4 frag(FragInput i) : SV_Target
				{
					fixed4 o;
				// Sample the texture
				fixed4 col = tex2D(_MainTex,i.uv);
				// Add color computed in the Geom
				fixed4 lerpColor = i.color;
				fixed4 finalColor = i.color * col;

				o.rgb = finalColor.xyz;
				o.a = finalColor.w;

				return o;
			}
			ENDCG
		}
		}
}

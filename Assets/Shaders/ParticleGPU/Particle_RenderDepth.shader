Shader "Beach/ParticleGPU/Particle_RenderDepth"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
	_FloorHeight("_FloorHeight",2D) = "white" {}
	}
		SubShader
	{
		Tags{ "RenderType" = "Opaque" "SnowEffect" = "A" }

		Pass
	{
		ColorMask G
		//Blend One One
		ZWrite Off
		ZTest LEqual
		//Offset[_Off],[_Slo]
		
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
		float3 depth_sUV : TEXCOORD1;
		float3 uv_seed : TEXCOORD0;
		
	};

	sampler2D _MainTex;
	sampler2D _RandomTex;
	sampler2D _FloorHeight;

	float _SnowMaxHeight;
	float _SnowFarPlane;
	float4 _MainTex_ST;
	float4 _Color1;
	float4 _Color2;
	float _UseRandomAngle;
	float _MinScale, _MaxScale;
	float _MinImpactScale, _MaxImpactScale;
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


	void AddPoint(float3 pos, float4 col, float3 uv, inout TriangleStream<FragInput> stream)
	{
		FragInput output;

		output.color = col;
		//From world to projection
		output.depth_sUV.x = -mul(UNITY_MATRIX_V, float4(pos, 1.0f)).z * _ProjectionParams.w;
		output.depth_sUV.yz = ComputeScreenPos(float4(pos, 1.0f)).xy;
		output.position = mul(UNITY_MATRIX_VP,float4(pos, 1.0f));
		output.uv_seed = uv;
		stream.Append(output);

	}

	[maxvertexcount(4)]
	void geom(point GeomInput p[1], inout TriangleStream<FragInput> triStream)
	{
		if (p[0].speed.w <= 0.0f)
			return;


		float4 randomSeed = tex2Dlod(_RandomTex, float4(p[0].seed.xy,0,0));

		// Setting up the lifetime lerper
		float lifeDuration = p[0].position.w;
		float lifeExpectancy = p[0].speed.w;
		float life01 = (lifeDuration - lifeExpectancy) / lifeDuration;

		// Setting up the vector for drawing the polys
		float3 up = UNITY_MATRIX_IT_MV[1].xyz;
		float3 look = UNITY_MATRIX_IT_MV[2].xyz;// _WorldSpaceCameraPos - p[0].position.xyz;
		look = normalize(look);
		float3 right = cross(up,look);



		// Add rotation and random angle
		float randomAngle = p[0].seed.y * 2.0f * 3.1415f * _UseRandomAngle + _Time.x * _AngularSpeed * sign(p[0].seed.z * 2 - 1);
		//float3 newRight = normalize(sin(randomAngle) * right + cos(randomAngle) * up);
		//float3 newUp = cross(look, newRight);

		float scale = lerp(_MinScale * _MinImpactScale, _MaxScale * _MaxImpactScale, frac(randomSeed.x));


		// Setting up speed deformer ( will be used later )
		float4 viewSpeed = mul(UNITY_MATRIX_MV,float4(p[0].speed.xyz, 0.0f));
		float speed = length(viewSpeed.xy);
		float2 speedDir = normalize(viewSpeed.xy);

		float halfSize = 0.5f * scale;

		float3 newRight = right + up;
		//float3 newRight = right *(-speedDir.x) + up * (speedDir.y);
		float3 newUp = cross(look, newRight);
		float3 offset = speed * newRight * _VelocityStretch;



		//Apply vector from position
		float3 position = p[0].position.xyz;
		float4 v[4];

		v[0] = float4(position + offset + halfSize * newRight - halfSize* newUp, 1.0f);
		v[1] = float4(position + offset + halfSize * newRight + halfSize* newUp, 1.0f);
		v[2] = float4(position - halfSize * newRight - halfSize* newUp, 1.0f);
		v[3] = float4(position - halfSize * newRight + halfSize* newUp, 1.0f);


		//up *= scale;
		//right *= scale;
		//
		//up += up * p[0].seed.x;
		//right += right * p[0].seed.x;


		//float3 stretchUp = speedDir.xyz * _VelocityStretch * speed;

		// Random Color for each particle
		float4 color = lerp(_Color1, _Color2, randomSeed.y);

		// Modify Color Over Lifetime
		float alphaOverLife = smoothstep(1.0f, _FadeOut, life01) * smoothstep(0.0f,_FadeIn, life01);
		color *= alphaOverLife;

		//Add Point to the Stream
		AddPoint(v[0], color,  float3(0, 0,p[0].seed.x), triStream);
		AddPoint(v[1],	color, float3(0, 1,p[0].seed.x), triStream);
		AddPoint(v[2],	color, float3(1, 0,p[0].seed.x), triStream);
		AddPoint(v[3],	color, float3(1, 1,p[0].seed.x), triStream);
		triStream.RestartStrip();

		return;

	}

	float4 frag(FragInput i) : SV_Target
	{
		float4 o;
	// Sample the texture
	fixed4 col = tex2D(_MainTex,i.uv_seed.xy);
	float floor = tex2D(_FloorHeight, i.depth_sUV.yz);
	float radial = saturate(pow((1 - length(float2(0.5, 0.5) - i.uv_seed.xy)), 8));
	if (radial < 0.05f)
		discard;

	float depth = 1 - i.depth_sUV.x;

	if (depth < floor)
		discard;

	// Add color computed in the Geom
	fixed4 lerpColor = i.color;
	fixed4 finalColor = i.color * col;


	o.rgb = float3(0, 1 - i.depth_sUV.x, 0);// finalColor.xyz;
	o.a = 1.0;//finalColor.w;
	return o;				

	}
		ENDCG
	}
	}
}

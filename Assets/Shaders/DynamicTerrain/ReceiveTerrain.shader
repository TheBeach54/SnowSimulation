//--------------------------------------------//
//-------Snow Simulation for Unity 5.5--------//
//---------Made using Unity 5.5.0f3-----------//
//-----------By Cesar Creutz------------------//
//----------------2017------------------------//
//--------------------------------------------//

Shader "Beach/DynamicTerrain/ReceiveTerrain"
{
	Properties
	{
		_MainTex("Texture", 2D) = "black" {}
		_SnowState("Snow State", 2D) = "black" {}
		_FloorHeight("_FloorHeight", 2D) = "white" {}
		_SnowMaxHeight("_SnowMaxHeight", Float) = 1
		_SnowFarPlane("_SnowFarPlane", Float) = 10
		_ColorImpactStrength("_ColorImpactStrength", Float) = 0.5
		_HeightImpactStrength("_HeightImpactStrength", Float) = 1
			_SnowSmoothMultiplier("_SnowSmoothMultiplier", Float )= 1

	}
		SubShader
	{
		Tags{ "RenderType" = "Opaque" }
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
	sampler2D _SnowState;
	sampler2D _FloorHeight;
	float4 _MainTex_ST;
	float4 _MainTex_TexelSize;
	float _SnowMaxHeight;
	float _SnowFarPlane;
	float _ColorImpactStrength;
	float _HeightImpactStrength;
	float _SnowSmoothMultiplier;

	v2f vert(appdata v)
	{
		//Nothing interesting here
		v2f o;
		o.vertex = UnityObjectToClipPos(v.vertex);
		o.uv = v.uv;
		return o;
	}

	float4 frag(v2f i) : SV_Target
	{
		fixed4 o;
	// All the depth value used here are from 0 to 1 in reverse order compared to an height map
	// It represents depth at which the object has penetrated the surface, not the actual depth of the object in camera space
	// It's was a good idea at first but in the end it's really unconvenient so i'll change that in the future

	// Setup uv's ; uv2 is the mirrored uv cause the camera render from the bottom
	float2 uv = float2(i.uv.x,i.uv.y);
	float2 uv2 = float2(i.uv.x, 1-i.uv.y);

	// (_FloorHeight)
	// We sample the depth of the floor
	// The depth of the floor is calculated using the backface of the terrain at the first frame
	// So we assume here that the floor wont move
	// We use the mirrored uv cause it's a fresh camera blit
	float floor = tex2D(_FloorHeight, uv2).x;
	
	// (_SnowState)
	// We sample the new object depth texture, it contains the depth of this frame only
	// We use the flipped uv cause it's a fresh camera blit
	float4 current = tex2D(_SnowState, uv2);

	// (_MainTex) 
	// We sample the current state of the snow with regular uv's cause it's already flip from the last frame 
	// The red channel contains the state of the snow
	// The green one contains the depth of the new particle arrived
	// --- We could write in the green channel to move a particle across the surface
	// --- by sampling the particle with an offset if the slope is too hard for a particle to stick
	// The blue contains the particle that as already falled down, it's use to apply a different texture to fresh snow
	// Alpha is free for now
	float4 receive = tex2D(_MainTex, uv);

	// Here we just sample the particle with a mirrored uv's cause like we said it's a fresh blit
	float receivePart = tex2D(_MainTex, uv2).g;

	// Here we rerange the depth of the object captured this frame between 0 and 1 depending on the floor height 
	// and the floor height + the maximum height of the snow
	float currentFloorBias = (current.x - floor) / ((floor - (_SnowMaxHeight / _SnowFarPlane)) - floor);
	float particleFloorBias =(receivePart - floor) / ((floor - (_SnowMaxHeight / _SnowFarPlane)) - floor);

	// We apply the rerange
	receive.y = 1-particleFloorBias;
	current.x = 1-currentFloorBias;

	// We sample the current state of the snow multiple time to evaluate the slope
	// The algorithm used here is just an average of the sourrounding pixel but in the futur it would be good
	// to really evaluate the slope and make some cool conditions to build a realistic surface across time
	float3 realoff = float3(-1 * _MainTex_TexelSize.x , 0, 1 * _MainTex_TexelSize.y);
	float3 h00 = saturate(tex2D(_MainTex, float2(uv.x + realoff.x, uv.y + realoff.x)).xyz);//*scale*amplifyNormal;
	float3 h10 = saturate(tex2D(_MainTex, float2(uv.x + realoff.y, uv.y + realoff.x)).xyz);//*scale*amplifyNormal;
	float3 h20 = saturate(tex2D(_MainTex, float2(uv.x + realoff.z, uv.y + realoff.x)).xyz);//*scale*amplifyNormal;
	float3 h01 = saturate(tex2D(_MainTex, float2(uv.x + realoff.x, uv.y + realoff.y)).xyz);//*scale*amplifyNormal;
	float3 h11 = saturate(tex2D(_MainTex, float2(uv.x + realoff.y, uv.y + realoff.y)).xyz);//*scale*amplifyNormal;
	float3 h21 = saturate(tex2D(_MainTex, float2(uv.x + realoff.z, uv.y + realoff.y)).xyz);//*scale*amplifyNormal;
	float3 h02 = saturate(tex2D(_MainTex, float2(uv.x + realoff.x, uv.y + realoff.z)).xyz);//*scale*amplifyNormal;
	float3 h12 = saturate(tex2D(_MainTex, float2(uv.x + realoff.y, uv.y + realoff.z)).xyz);//*scale*amplifyNormal;
	float3 h22 = saturate(tex2D(_MainTex, float2(uv.x + realoff.z, uv.y + realoff.z)).xyz);//*scale*amplifyNormal;

	float3 maxNH = max(max(max(max(max(max(max(max(h00, h10), h20),	h01), h11), h21), h02), h12), h22);
	float3 minNH = min(min(min(min(min(min(min(min(h00, h10), h20), h01), h11), h21), h02), h12), h22);
	float3 nH = h00 + h10 + h20 + h01 + h21 + h02 + h12 + h22;
	nH /= 8;

	//Use the difference between the average surrounding texel with the current pixel to lerp between them
	
		receive.xyz = lerp(receive.xyz, nH.xyz, abs(h11.x - nH.x) * _SnowSmoothMultiplier);


	
	//float Gx = h00 - h20 + 2.0f * h01 - 2.0f * h21 + h02 - h22;
	//float Gy = h00 + 2.0f * h10 + h20 - h02 - 2.0f * h12 - h22;
	//float Gz = 0.5f * sqrt(max(1.0f - Gx * Gx - Gy * Gy, 0.0f));

		//float3 originalNormal = normalize(float3(2.0f * Gx, 2.0f * Gy, Gz));

	// Setup receiveDepth (object depth at this frame)
	float receiveDepth = current.r;
	// Setup receiveParticle (particle depth at this frame)
	float receiveParticle = receive.g;	

	// Height added by a particle must be depend of the max height, this way it's constant whatever the MaxHeight
	float part = 1.0f / (_SnowMaxHeight);// smoothstep(0, 0.1, receiveParticle);

	// We check if the particle collide with the floor with a threshold ( 0.1 is an arbitrary threshold )
	// We could use a properties cause it highly rely on the speed of the particle
	// Compute the condition  [ if (!(abs(receive.x - receiveParticle) < 0.1)) ]
	// if the particle collide then let part unchanged, if it's not just set it to 0
	float partCheck = 1  -step(0.1, abs(receive.x - receiveParticle));
	part = part * partCheck;

	// The same logic apply here, we want to erase the particle added when an object crush it
	// when can't direclty used the depth to substract to the particle already on the floor 
	// because it can capture things that dont touch the floor, so we check if it actually collide with the floor level
	// by comparing the new depth receive to the actual state of the floor
	// Compute the condition [ if ((receive.x - current.x) > 0) ]
	// if the object collide then let the input unchanged, else just set it to 0
	float heightCheck = 1 - step(0, receive.x - current.x);
	
	current.x *= heightCheck;

	// Here we premultiply a properties, we could do that in the script but for clarity sake I put it here
	_HeightImpactStrength *= 0.01;

	// We compute the new height, the max function allow us to always keep the largest depth 
	// We then add the particule that collides with the floor
	float height = max(receiveDepth, receive.x) - _HeightImpactStrength * part;

	// We accumulate the particle that felt down by keeping the previous value and adding the new particles
	// We then substract the current object
	float groundedParticle = saturate(receive.z + part *_ColorImpactStrength) - current.x;

	//Output
	// We set the new height for the next frame
	o.r = height;
	// We set the new arrived particle for the next frame we could use this to slide particle on the surface
	o.g = 0.0f;
	// We set the new grounded particle
	o.b = groundedParticle;
	// Alpha could be used for another thing
	o.a = 0;

	return o;

	}
		ENDCG
	}
	}
}




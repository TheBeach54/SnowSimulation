// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Beach/Other/S_SkyDome"
{
	Properties
	{
		_Exposure("Global Exposure", Float) = 1

		[Header(Clouds)]
		_MainTex("Texture", 2D) = "white" {}
		_CloudSpeed("Cloud Speed", Range(-1,1)) = 0.1
		_CloudOccludeMin("Cloud Occlude Max" ,Float) = 0.2

		[Header(Sun)]
		[HDR]_SunColor("Sun Color", Color) = (1,1,1,1)
		_SunIntensity("Sun Intensity" , Float) = 0.5
		_SunSize("Sun Size", Float) = 1

		[Header(Sun Impact)]
		_SunExposure("Sun Impact",Float) = 1
		_SunSpread("Sun Impact Spread", Float) = 3
		_SunFalloff("Sun Impact Falloff", Range(-1,1)) = 0.8

		[Header(Sky)]
		_ShadeSky("Is Sky Shaded ?", Range(0,1)) = 1
		_ShadingSpread("_ShadingSpread", Float) = 1
		_ShadingIntensity("_ShadingIntensity", Float) = 1
		_ShadingFalloff("_ShadingFalloff", Float) = -1
		//_WorldDirectionalLightPos("_WorldDirectionalLightPos", Vector) = (1,1,1,1)

			[Header(Shadow)]
		_ShadowLevel("Shadow Cutout Level", Range(0,1)) = 1
	}
	SubShader
	{

		Pass
		{
			//Name "FORWARD"
			Tags{ "Queue" = "Background" "RenderType" = "Background"  "LightMode" = "ForwardBase" "PassFlags" = "OnlyDirectional" }

			//ZWrite On
			LOD 200

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
#pragma multi_compile_fwdbase
			
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
//#include "AutoLight.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 N : NORMAL;
				float4 sun_UV : ATTR4;
				float4 objVert : ATTR5;
				//LIGHTING_COORDS(4, 5)
			};

			sampler2D _MainTex;
			float4 _MainTex_ST, _SunColor;
			float4 _WorldDirectionalLightPos;
			float _Exposure, _SunExposure, _CloudSpeed;
			float _ShadingIntensity, _ShadingSpread, _ShadingFalloff;
			float _SunSpread, _SunIntensity, _SunFalloff;
			float _ShadeSky, _SunSize, _CloudOccludeMin;
			
			half getMiePhase(half eyeCos, half eyeCos2)
			{
				float MIE_G = -0.990;
				float MIE_G2 = 0.9801;

				half temp = 1.0 + MIE_G2 - 2.0 * MIE_G * eyeCos;
				temp = pow(temp, pow(_SunSize, 0.65) * 10);
				temp = max(temp, 1.0e-4); // prevent division by zero, esp. in half precision
				temp = 1.5 * ((1.0 - MIE_G2) / (2.0 + MIE_G2)) * (1.0 + eyeCos2) / temp;
//if defined(UNITY_COLORSPACE_GAMMA) && SKYBOX_COLOR_IN_TARGET_COLOR_SPACE
//				temp = pow(temp, .454545);
//endif
				return temp;
			}



			v2f vert (appdata v)
			{
				v2f o;
				half4 vertex = mul(unity_ObjectToWorld, v.vertex);
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.objVert = -v.vertex;
				half3 N = normalize(mul(unity_ObjectToWorld, float4(v.normal, 0)));

				o.N = N;

				o.sun_UV.x = pow(smoothstep(_SunFalloff, 1, dot(-N, _WorldDirectionalLightPos))*0.5, _SunSpread);
				o.sun_UV.y = pow(smoothstep(_ShadingFalloff, 1, dot(-N, _WorldDirectionalLightPos))*_ShadingIntensity, _ShadingSpread);
				o.sun_UV.zw = v.uv;





				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float4 o;

			_SunSize *= 0.01;
				// sample the texture
			float2 uvPan = float2(i.sun_UV.z + _Time.x * _CloudSpeed, i.sun_UV.w);
				fixed4 col = tex2D(_MainTex, uvPan) *_Exposure;



				fixed3 skyColor = col.rgb;
				fixed skyOcclud = smoothstep(_CloudOccludeMin, 1, col.a);
			
				// apply fog
				half3 ray = normalize(mul((float3x3)unity_ObjectToWorld, i.objVert.xyz));

				half eyeCos = dot(_WorldDirectionalLightPos.xyz, ray);
				half eyeCos2 = eyeCos * eyeCos;
				half mie = getMiePhase(eyeCos, eyeCos2);

				//return mie.xxxx;
				//Final result
				half3 result = lerp(col, col * _SunColor, _ShadeSky * skyOcclud * i.sun_UV.y *  _SunColor);
				half3 sun = mie * (skyOcclud)* _SunColor * _SunIntensity;
				half3 sunImpact = (i.sun_UV.x* _SunColor * (1+	skyOcclud)) *_SunExposure;
				//float sun = pow(smoothstep(0.95, 1.01, dot(-i.N_NdotL.xyz, _WorldSpaceLightPos0)),4)*4;
				//return float4(sun.xxx, 1.0);
				//o.rgb = lerp(lerp(result, fogCol, i.UV_fog.z), _LightColor0, i.sun);
				o.rgb = result + sunImpact + sun;
				o.a = 1.0;
				//half c = NdotL;
				//o.rgb = float3(c, c, c);
				//o.a = 1;
				return o;


			}
			ENDCG
		}



		Pass
			{
				// Définition de la passe shadowcaster
				Name "ShadowCaster"
				Tags{ "LightMode" = "ShadowCaster" }

				Fog{ Mode Off }
				ZWrite On ZTest LEqual Cull Front

				CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
#include "AutoLight.cginc"

				sampler2D _MainTex;
		float _CloudSpeed, _ShadowLevel;


			struct pixelInput
			{
				float2 uv0 : TEXCOORD5;
				// Définition des paramètres utilisés pour passer du vertex shader
				// au fragment shader.
				// Cette macro utilise SV_POSITION & TEXCOORD0 donc, n'utilisez pas TEXCOORD0 pour passer quoi que ce soit
				V2F_SHADOW_CASTER;
			};

			pixelInput vert(appdata_base v)
			{
				pixelInput o;
				o.uv0 = v.texcoord;
				
				// Transfert des données nécessaires au calcul de la projection d'ombre dans le structure définie
				// plus haut.
				TRANSFER_SHADOW_CASTER(o)
					return o;
			}

			float4 frag(pixelInput i) : COLOR
			{
				float2 uvPan = float2(i.uv0.x + _Time.x * _CloudSpeed, i.uv0.y);
				float cutout = tex2D(_MainTex,uvPan).a;
				
				if (cutout > _ShadowLevel)discard;

			// Calcul de la projection d'ombre
			SHADOW_CASTER_FRAGMENT(i)
			}
				ENDCG
			} //Pass


	}
	//Fallback "Diffuse"
}

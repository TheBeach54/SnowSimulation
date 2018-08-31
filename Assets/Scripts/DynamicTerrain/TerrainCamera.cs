using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TerrainCamera : MonoBehaviour {

    private RenderTexture _rT1;
    private RenderTexture _rT2;
    private RenderTexture _rTFloor;



    private bool rtFlag = true;
    private bool firstFrame = true;
    private Camera cam;

    [Header("Materials & Shaders")]
    [Tooltip("Material that accumulate the depth, should use the ReceiveTerrain shader")]
    public Material snowReceiveMat;

    [Tooltip("Material that render the actual snow, should use a tesselation shader with : (sampler2D) _DisplaceTex , (float) _SnowMaxHeight  as input")]
    private Material snowRenderMat;

    [Tooltip("Shader that render depth from (far plane) 0 to (near plane) 1")]
    public Shader showDepthShader;

    [Tooltip("String that will be used to replace all shader in the scene, only object using shader with this tag will affects the terrain, make sure you correclty setup the Terrain_RenderDepth and your shader with the same tag and value")]
    public string replacementShaderTag = "TerrainEffect";


    [Header("Terrain")]
    [Tooltip("GameObject that contains the terrain renderer and transform")]
    public GameObject floorObj;

    [Tooltip("EXPENSIVE : Collider to update. You don't want to use that.")]
    public TerrainDeformCollider snowCollider;

    [Header("Initial HeightMap")]
    [Tooltip("Initial height [0,1]")]
    public Texture initHeight;

    [Tooltip("Tilling of the initial height")]
    public float tillingInit;

    [Tooltip("At which height should be the 0 of the initHeight in the final initial terrain height")]
    [Range(0.0f,1.0f)]public float initMin = 0.0f;

    [Tooltip("At which height should be the 1 of the initHeight in the final initial terrain height")]
    [Range(0.0f,1.0f)]public float initMax = 1.0f;

    [Tooltip("Material that resize the input texture uv's and value using the settings above. Should use the DynamicTerrain/RescaleInputShader")]
    public Material tillingInitMat;

    [Header("General Settings")]
    [Tooltip("Max height that the snow can reach")]
    [Range(0.001f,100.0f)]public float snowThickness = 1.0f;

    [Tooltip("Beyond this value the camera will not render the objects. Make sure that it's always more than [Height of the highest vertex of the terrain] + [SnowThickness] + 1")]
    public float snowFarPlane = 10.0f;

    [Tooltip("Size of the terrain. (WIP) Should be a square for now")]
    public Vector2 planeSize = new Vector2(10.0f, 10.0f);

    [Tooltip("Size of the renderTextures in which the depth will be render (Inscreasing the size beyond 1024 will make the rendering really slow)")]
    public int renderTextureSize = 512;
    [Tooltip("Multiply the smooth algorithm apply to all the surface at everyframe, 0 desactivate it")]
    public float snowSmoothMultiplier = 1.5f;

    //public ParticleRendererGPU pRGPU;
    [Header("Collect Particles Setup")]
    [Tooltip("It doesn't disable the reception of particle but will change the depthBuffer of the renderTexture, some issues exist only when the depthBuffer is set to 0 (WIP) ")]
    public bool useParticle = false;
    [Tooltip("How many height add when a particle hit the floor")]
    public float heightImpactStrength = 1.0f;
    [Tooltip("How quickly the top color of the terrain will replace the bottom color when particle hit the floor")]
    public float colorImpactStrength = 1.0f;

    void Start()
    {

        cam = GetComponent<Camera>();
        if (cam == null)
            cam = gameObject.AddComponent<Camera>();

        snowRenderMat = floorObj.GetComponent<Renderer>().material;

        // Init cam and place it on the right spot with the right direction
        cam.transform.position = floorObj.transform.position - floorObj.transform.up;
        cam.transform.LookAt(floorObj.transform.position + floorObj.transform.up, floorObj.transform.forward);


        int zBuffSize;

        // WIP : Particles won't work properly with a zbuffer (fixeable), and the dynamic terrain wont work properly without.. 
        if (useParticle)
            zBuffSize = 0;
        else
            zBuffSize = 16;

        // Create the two render texture we'll need each frame
        _rT1 = new RenderTexture(renderTextureSize, renderTextureSize, zBuffSize);
        _rT2 = new RenderTexture(renderTextureSize, renderTextureSize, zBuffSize);
        // Create a third one that will not be update each frame
        _rTFloor = new RenderTexture(renderTextureSize, renderTextureSize, 0);

        //Setup them
        SetupRenderToTexture(_rT1);
        SetupRenderToTexture(_rT2);
        SetupRenderToTexture(_rTFloor);

        //Apply tilling and rerange values of the init height and blit it in the first renderTexture. 
        //This way at the first frame it's like something collide with the terrain, using the same algorithm
        tillingInitMat.SetFloat("_Tilling", tillingInit);
        tillingInitMat.SetFloat("_Max", initMax);
        tillingInitMat.SetFloat("_Min", initMin);

        Graphics.Blit(initHeight, _rT1, tillingInitMat);

        //Setup the camera

        cam.nearClipPlane = 0.0f;
        cam.orthographic = true;
        cam.aspect = 1.0f;
        cam.clearFlags = CameraClearFlags.Color;
        cam.backgroundColor = Color.black;


    }
    void SetupRenderToTexture(RenderTexture rt)
    {
        // For an odd reason we need antiAliasing set to 2 in order for the shaders to work
        rt.antiAliasing = 2;
        rt.format = RenderTextureFormat.ARGBFloat;
        rt.useMipMap = false;
    }
    void UpdateCamera()
    {

        
        cam.farClipPlane = snowFarPlane;
        cam.orthographicSize = planeSize.x / 2;

        // Pass the configuration to the shader
        snowReceiveMat.SetFloat("_SnowMaxHeight", snowThickness);
        snowReceiveMat.SetFloat("_SnowFarPlane", snowFarPlane);
        snowReceiveMat.SetFloat("_HeightImpactStrength", heightImpactStrength);
        snowReceiveMat.SetFloat("_ColorImpactStrength", colorImpactStrength);
        snowReceiveMat.SetFloat("_SnowSmoothMultiplier", snowSmoothMultiplier);

        snowRenderMat.SetFloat("_SnowMaxHeight", snowThickness);
        snowRenderMat.SetFloat("_Scale", floorObj.transform.lossyScale.y);

        // We apply the init height calculated in the Start() and pass the floor height to the receiveSnow shader
        if (firstFrame)
        {


            //here we render the backface Depth of the floor to get the height of the terrain
            //We then pass it to the shader
            //In our case we dont need it te be render every frame. 

            cam.SetReplacementShader(showDepthShader, "SnowFloor");
            snowReceiveMat.SetTexture("_FloorHeight", _rTFloor);
            //Shader.SetGlobalTexture("_FloorHeight", _rTFloor);
            cam.targetTexture = _rTFloor;
                cam.Render();
        
        }
        else
        {
        // We want to render every dynamic object with a specific shader, other object will be ignore
        cam.SetReplacementShader(showDepthShader, replacementShaderTag);

            if (snowCollider != null)
                snowCollider.SetMaxHeight(snowThickness);

            // We setup the target texture and pass the right texture to the shader
            // Each frame we swap the target texture to always keep the result of the shader
            if (rtFlag)
            {
                if(snowCollider !=null)
                snowCollider.SetHeightTexture(_rT2);

                snowRenderMat.SetTexture("_DisplaceTex", _rT2);
                snowReceiveMat.SetTexture("_SnowState", _rT2);
                snowReceiveMat.SetTexture("_MainTex", _rT1);
                cam.targetTexture = _rT2;
            }
            else
            {
                if (snowCollider != null)
                    snowCollider.SetHeightTexture(_rT1);

                snowRenderMat.SetTexture("_DisplaceTex", _rT1);
                snowReceiveMat.SetTexture("_SnowState", _rT1);
                snowReceiveMat.SetTexture("_MainTex", _rT2);
                cam.targetTexture = _rT1;
            }
            
        }

    }

    void Update()
    {
        // Each frame we update the camera
        UpdateCamera();
        
    }

    void OnPostRender()
    {

        // after rendering we blit the first RT in the second and switch the flag
        if(!firstFrame)
        {
            if (rtFlag)
            {
                Graphics.Blit(_rT1, _rT2, snowReceiveMat);
            }
            else
            {
                Graphics.Blit(_rT2, _rT1, snowReceiveMat);
            }
            rtFlag = !rtFlag;
        }

        firstFrame = false; // not the first frame anymore
        
    }

    public Texture GetFloorHeight()
    {
        return _rTFloor;
    }


}

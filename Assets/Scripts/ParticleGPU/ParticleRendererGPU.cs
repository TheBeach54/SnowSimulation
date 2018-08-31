#define _FLOOR_IMPACT_ON

using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;


public class ParticleRendererGPU : MonoBehaviour
{
    #region struct
    struct Particle
    {
        public Vector4 position; // xyz = wPos, w = unused 
        public Vector4 speedLife; // xyz = Speed, w = Life expectancy
        public Vector4 color;
        public Vector4 seed;
    }

    struct SphereColliderGPU
    {
        public Vector4 position_rad;
    }

    struct BoxColliderGPU
    {
        public Vector4 position;
        public Matrix4x4 unity_WorldToObject;
        public Matrix4x4 unity_ObjectToWorld;

    }

    struct CapsuleColliderGPU
    {
        public Vector4 position_rad;
        public Vector4 rotation_height;
    }

    struct EffectorGPU
    {
        public Vector4 position_rad;
        public Vector4 direction_force;
        public float attraction;
        public int effectorType; // 0 : Blow ; 1 : Suck ; 2 : Tornado
    }
    #endregion

    #region private

    private SphereColliderGPU[] sphereCol;
    private int sphereColliderCount;
    ComputeBuffer sphereColliderBuffer;

    private BoxColliderGPU[] boxCol;
    private int boxColliderCount;
    ComputeBuffer boxColliderBuffer;

    private CapsuleColliderGPU[] capsuleCol;
    private int capsuleColliderCount;
    ComputeBuffer capsuleColliderBuffer;

    private EffectorGPU[] effectors;
    private int effectorCount;
    ComputeBuffer effectorBuffer;

    ComputeBuffer particlesBuffer;
    ComputeBuffer feedParticlesBuffer;

    private Particle[] initialState;
    private int particleCount;

    private Vector3 emitterSpeed;
    private Vector3 emitterPreviousPos;
    private Vector3 emitterPos;
    private Vector3 emitterDir;


    private int oldShape;
#if _FLOOR_IMPACT_ON
    private Camera cameraTerrainDepth;
    private CommandBuffer bufSpecial;
#endif

    private const int warpSize = 32;

    #endregion
    
    #region public

    [Header("Particle System")]
    [Tooltip("Number of particle GPU thread, particleCount = particlesLoad * 32")]
    public int particlesLoad = 200;

    public ComputeShader updateParticles;
    //public ComputeShader feedParticles;

    [Tooltip("Material to render the particles, should be using a Shader with a geometry shader that draw quad with point as input")]
    public Material particleMaterial;
    [Tooltip("Random Noise to amplify the randomness ( Deprecated )")]
    public Texture randomTex;
    [Tooltip("Particle sprite")]
    public Texture particleTex;

    [Tooltip("Pass Buffer and Parameter as global values")]
    public bool isBufferGlobalProperties = false;

    [Header("Emitter")]

    [Tooltip("The Emitter position")]
    public Transform emitterTransform;
    public EmitterShape emitterShape;
    [Tooltip("Should the particles spawn in the shape or just on the shell")]
    [Range(0.0f, 1.0f)]
    public float fillShape;
    [Tooltip("World space scale of the emitter shape. For Spot : X and Z are used for the angle of the spot (destination disk), Y setup the size of the spawning disk (start disk). Sphere and box colliders are in World Space without rotation (WIP)")]
    public Vector3 emitterSize = new Vector3(10.0f,10.0f,10.0f);
    [Range(0.0f, 1.0f)]
    public float randomizeInitDir = 0.0f;



    [Header("Particles Options")]

    public float minLifeTime = 2.0f;
    public float maxLifeTime = 6.0f;

    [Range(0.01f,2.0f)]
    public float fadeIn = 0.2f;
    [Range(-1.0f,0.99f)]
    public float fadeOut = 0.8f;


    public float gravity = 9.81f;

    [ColorUsage(true,true,0.0f,10.0f,0.0f,10.0f)]
    public Color color1 = Color.white;
    [ColorUsage(true, true, 0.0f, 10.0f, 0.0f, 10.0f)]
    public Color color2 = Color.white;
    [Range(0.0f, 50.0f)]
    public float minDrag = 0.1f;
    [Range(0.0f, 50.0f)]
    public float maxDrag = 0.2f;
    [Range(0.0f, 0.99f)]
    public float minFloorDrag = 0.5f;
    [Range(0.0f, 0.99f)]
    public float maxFloorDrag = 0.5f;
    public float minFloorSpread = 1.0f;
    public float maxFloorSpread = 1.0f;

    public float minBounciness = 0.1f;
    public float maxBounciness = 0.1f;

    public float bounceSlideThreshold = 100.0f;

    public float minInheritSpeedMultiplier = 1.0f;
    public float maxInheritSpeedMultiplier = 1.0f;

    public float initSpeed = 1.0f;

    public float minInitSpeed = 1.0f;
    public float maxInitSpeed = 1.0f;

    [Range(0.0f,1.0f)]public float useRandomAngle = 1.0f;
    public float angularSpeed = 1.0f;
    public float minScale = 1.0f;
    public float maxScale = 1.0f;
    public float velocityStretch = 0.0f;

    [Header("Collisions")]
    [Tooltip("Radius of the particles")]
    public float radius = 0.1f;
    public float groundThreshold = 0.1f;
    public float groundLevel = 0.0f;
    public SphereCollider[] sphereArray;
    public BoxCollider[] boxArray;
    public CapsuleCollider[] capsuleArray;

    [Header("Effector")]
    public ParticleEffectorGPU[] effectorArray;

#if _FLOOR_IMPACT_ON

    [Header("Floor Impact")]
    [Tooltip("Material that uses a shader to display depth of the particle")]
    public Material particleDepthMat;
    [Tooltip("Link the dynamic terrain camera here")]
    public TerrainCamera snowCam;
    [Tooltip("Min Scale of the particles render with the dynamic terrain camera")]
    public float minImpactScale = 1.0f;
    [Tooltip("Max Scale of the particles render with the dynamic terrain camera")]
    public float maxImpactScale = 1.0f;

#endif

    [Tooltip("When enabled every values and buffers are send to the compute shader every frame, you need it to move your colliders and tweak parameters at runtime. Emitter's position will be updated anyways")]
    public bool updateValues = true;

    #endregion

    
    void Start()
    {
        if (particlesLoad <= 0)
            particlesLoad = 1;

        //emitterShape is used for the multiple variant of the compute shader including all different shapes of the emitter available 
        oldShape = (int)emitterShape;

        
        
        particleCount = warpSize * particlesLoad;
        Debug.Log("Particles count :" + particleCount);

        //Set Particle Buffer data
        initialState = new Particle[particleCount];
        for (int i = 0; i < particleCount; i++)
        {
            initialState[i].position = Vector4.zero;
            initialState[i].speedLife = Vector4.zero;
            initialState[i].color = Vector4.zero;
            initialState[i].seed = new Vector4(Random.Range(0.0f, 1.0f), Random.Range(0.0f, 1.0f), Random.Range(0.0f, 1.0f), Random.Range(0.0f, 1.0f));
        }

        particlesBuffer = new ComputeBuffer(particleCount, 64); // 3* Vector4           = 48 bytes
                                                                // Vector4 = 4 * float  = 16 bytes
                                                                // float = 32 bits      = 4 bytes
        particlesBuffer.SetData(initialState);
        

        sphereColliderCount = sphereArray.Length;
        Debug.Log("SphereCollider count : " + sphereColliderCount);

        //Set Sphere Collider Buffer Data
        if (sphereColliderCount > 0)
        {
            sphereColliderBuffer = new ComputeBuffer(sphereColliderCount, 16);
            SetSphereColliderBuffer(out sphereCol, sphereArray);
            sphereColliderBuffer.SetData(sphereCol);
        }
        else
        {
            sphereColliderBuffer = null;
        }


        boxColliderCount = boxArray.Length;
        Debug.Log("BoxCollider count : " + boxColliderCount);


        if (boxColliderCount > 0)
        {
            boxColliderBuffer = new ComputeBuffer(boxColliderCount, 144);
            SetBoxColliderBuffer(out boxCol, boxArray);
            boxColliderBuffer.SetData(boxCol);
        }
        else
        {
            boxColliderBuffer = null;
        }

        capsuleColliderCount = capsuleArray.Length;
        Debug.Log("CapsuleCollider count : " + capsuleColliderCount);

        if(capsuleColliderCount > 0)
        {
            capsuleColliderBuffer = new ComputeBuffer(capsuleColliderCount, 32);
            SetCapsuleColliderBuffer(out capsuleCol, capsuleArray);
            capsuleColliderBuffer.SetData(capsuleCol);
        }
        else
        {
            capsuleColliderBuffer = null;
        }

            effectorCount = effectorArray.Length;
            Debug.Log("Effector count : " + effectorCount);

        if(effectorCount > 0)
        {
            effectorBuffer = new ComputeBuffer(effectorCount, 40);
            SetEffectorBuffer(out effectors, effectorArray);
            effectorBuffer.SetData(effectors);
        }
        else
        {
            effectorBuffer = null;
        }




        if(isBufferGlobalProperties)
        {
            Shader.SetGlobalBuffer("particleBuffer", particlesBuffer);
        }

        if(sphereColliderBuffer != null)
        updateParticles.SetBuffer((int)emitterShape, "sphereColliderBuffer", sphereColliderBuffer);
        if(boxColliderBuffer != null)
        updateParticles.SetBuffer((int)emitterShape, "boxColliderBuffer", boxColliderBuffer);
        if(capsuleColliderBuffer != null)
        updateParticles.SetBuffer((int)emitterShape, "capsuleColliderBuffer", capsuleColliderBuffer);
        if(effectorBuffer != null)
        updateParticles.SetBuffer((int)emitterShape, "effectorBuffer", effectorBuffer);

        updateParticles.SetBuffer((int)emitterShape, "particleBuffer", particlesBuffer);
        particleMaterial.SetBuffer("particleBuffer", particlesBuffer);


        if (emitterTransform == null)
            emitterTransform = transform;

        emitterPreviousPos = emitterTransform.position;
        emitterPos = emitterTransform.position;

        UpdateParticles(updateParticles);
       // UpdateParticles(feedParticles);



#if _FLOOR_IMPACT_ON

        if(particleDepthMat != null)
            particleDepthMat.SetBuffer("particleBuffer", particlesBuffer);

        if (snowCam != null)
        cameraTerrainDepth = snowCam.gameObject.GetComponent<Camera>();

        if (cameraTerrainDepth != null)
            SetupCommandBuffer(bufSpecial, cameraTerrainDepth, particleDepthMat);
#endif

    }

   
    void SetupCommandBuffer(CommandBuffer buffer, Camera cam, Material mat)
    {

        buffer = new CommandBuffer();
        UpdateParticlesMaterial(mat);
        buffer.name = buffer.ToString();
        buffer.DrawProcedural(Matrix4x4.identity, mat, 0, MeshTopology.Points, 1, particleCount);
    
        cam.AddCommandBuffer(UnityEngine.Rendering.CameraEvent.BeforeImageEffects, buffer);
    }

    void OnRenderObject()
    {
#if _FLOOR_IMPACT_ON

        // Render normally only on the editor or every other camera not involve here
        if (Camera.current != cameraTerrainDepth)
        {
#endif
            particleMaterial.SetPass(0);
        Graphics.DrawProcedural(MeshTopology.Points,1, particleCount);

#if _FLOOR_IMPACT_ON

        }
#endif


    }

    void Update()
    {

        emitterPos = emitterTransform.position;

        emitterSpeed = (emitterPos - emitterPreviousPos) / Time.deltaTime;

        emitterPreviousPos = emitterTransform.position;
       
        updateParticles.SetFloat("deltaTime", Time.deltaTime);
        updateParticles.SetFloat("time", Time.time);
        updateParticles.SetVector("emitterPos", emitterPos);
        updateParticles.SetVector("emitterSpeed", emitterSpeed);
        updateParticles.SetVector("emitterDir", emitterTransform.forward);

        //feedParticles.SetFloat("deltaTime", Time.deltaTime);
        //feedParticles.SetFloat("time", Time.time);
        //feedParticles.SetVector("emitterPos", emitterPos);
        //feedParticles.SetVector("emitterSpeed", emitterSpeed);

        //feedParticles.Dispatch(0, particlesLoad, 1, 1);
          
        updateParticles.Dispatch((int) emitterShape, particlesLoad, 1, 1);

        if(updateValues)
        {
            UpdateParticles(updateParticles);
            //UpdateParticles(feedParticles);
            UpdateParticlesMaterial(particleMaterial);

#if _FLOOR_IMPACT_ON
            
            if(particleDepthMat != null)
                UpdateParticlesMaterial(particleDepthMat);
#endif
        }

    }

    void UpdateParticlesMaterial(Material particleMat)
    {
        if (isBufferGlobalProperties)
        {
            Shader.SetGlobalFloat("_MinScale", minScale);
            Shader.SetGlobalFloat("_MaxScale", maxScale);
            Shader.SetGlobalFloat("_AngularSpeed", angularSpeed);
            Shader.SetGlobalFloat("_VelocityStretch", velocityStretch);
            Shader.SetGlobalFloat("_UseRandomAngle", useRandomAngle);
            Shader.SetGlobalFloat("_FadeIn", fadeIn);
            Shader.SetGlobalFloat("_FadeOut", fadeOut);

            Shader.SetGlobalTexture("_RandomTex", randomTex);

            Shader.SetGlobalColor("_Color1", color1);
            Shader.SetGlobalColor("_Color2", color2);

            Shader.SetGlobalBuffer("particleBuffer", particlesBuffer);

            if (particleTex != null)
                Shader.SetGlobalTexture("_MainTex", particleTex);
        }
        else
        {
            particleMat.SetFloat("_MinScale", minScale);
            particleMat.SetFloat("_MaxScale", maxScale);
            particleMat.SetFloat("_AngularSpeed", angularSpeed);
            particleMat.SetFloat("_VelocityStretch", velocityStretch);
            particleMat.SetFloat("_UseRandomAngle", useRandomAngle);
            particleMat.SetFloat("_FadeIn", fadeIn);
            particleMat.SetFloat("_FadeOut", fadeOut);
            
            particleMat.SetTexture("_RandomTex", randomTex);

            particleMat.SetColor("_Color1", color1);
            particleMat.SetColor("_Color2", color2);

            if (particleTex != null)
                particleMat.SetTexture("_MainTex", particleTex);

#if _FLOOR_IMPACT_ON
    
            particleMat.SetFloat("_MinImpactScale", minImpactScale);
            particleMat.SetFloat("_MaxImpactScale", maxImpactScale);
            if (snowCam != null)
            particleMat.SetTexture("_FloorHeight", snowCam.GetFloorHeight());

#endif
        }
    }

#if _FLOOR_IMPACT_ON
    public void DrawPart(Material mat)
    {

        mat.SetFloat("_MinScale", minScale);
        mat.SetFloat("_MaxScale", maxScale);
        mat.SetFloat("_AngularSpeed", angularSpeed);
        mat.SetFloat("_VelocityStretch", velocityStretch);
        mat.SetFloat("_UseRandomAngle", useRandomAngle);
        mat.SetFloat("_FadeIn", fadeIn);
        mat.SetFloat("_FadeOut", fadeOut);
        mat.SetTexture("_RandomTex", randomTex);
        if(particleTex != null)
        mat.SetTexture("_MainTex", particleTex);
        mat.SetColor("_Color1", color1);
        mat.SetColor("_Color2", color2);
        mat.SetBuffer("particleBuffer", particlesBuffer);
        mat.SetPass(0);
        Graphics.DrawProcedural(MeshTopology.Points, 1, particleCount);
    }
#endif

    void UpdateParticles(ComputeShader compShader)
    {


        //Set Sphere Collider Buffer Data
        if (sphereColliderCount > 0)
        {
            SetSphereColliderBuffer(out sphereCol, sphereArray);
            sphereColliderBuffer.SetData(sphereCol);
        }


        if (boxColliderCount > 0)
        {
            SetBoxColliderBuffer(out boxCol, boxArray);
            boxColliderBuffer.SetData(boxCol);
        }

        if (capsuleColliderCount > 0)
        {
            SetCapsuleColliderBuffer(out capsuleCol, capsuleArray);
            capsuleColliderBuffer.SetData(capsuleCol);
        }

        if (effectorCount > 0)
        {
            SetEffectorBuffer(out effectors, effectorArray);
            effectorBuffer.SetData(effectors);
        }

        if (gravity == 0.0f)
            gravity = 0.001f;

        if(oldShape != (int)emitterShape)
        {
            if (sphereColliderBuffer != null)
                updateParticles.SetBuffer((int)emitterShape, "sphereColliderBuffer", sphereColliderBuffer);

            if (boxColliderBuffer != null)
                updateParticles.SetBuffer((int)emitterShape, "boxColliderBuffer", boxColliderBuffer);

            if (particlesBuffer != null)
                updateParticles.SetBuffer((int)emitterShape, "particleBuffer", particlesBuffer);

            if(effectorBuffer != null)
                updateParticles.SetBuffer((int)emitterShape, "effectorBuffer", effectorBuffer);
            
            oldShape = (int) emitterShape;
        }

        compShader.SetFloat("gravity", gravity);
        compShader.SetFloat("groundLevel", groundLevel);
        compShader.SetFloat("groundThreshold", groundThreshold);
        compShader.SetFloat("minDrag", minDrag);
        compShader.SetFloat("maxDrag", maxDrag);
        compShader.SetFloat("minFloorDrag", minFloorDrag);
        compShader.SetFloat("maxFloorDrag", maxFloorDrag);
        compShader.SetFloat("minBounciness", minBounciness);
        compShader.SetFloat("maxBounciness", maxBounciness);
        compShader.SetFloat("radius", radius);
        compShader.SetFloat("minLifeTime", minLifeTime);
        compShader.SetFloat("maxLifeTime", maxLifeTime);
        compShader.SetFloat("minInitSpeed", minInitSpeed);
        compShader.SetFloat("maxInitSpeed", maxInitSpeed);
        compShader.SetFloat("randomizeInitDir", randomizeInitDir);
        compShader.SetFloat("bounceSlideThreshold", bounceSlideThreshold);
        compShader.SetFloat("minInheritSpeedMultiplier", minInheritSpeedMultiplier);
        compShader.SetFloat("maxInheritSpeedMultiplier", maxInheritSpeedMultiplier);
        compShader.SetFloat("minFloorSpread", minFloorSpread);
        compShader.SetFloat("maxFloorSpread", maxFloorSpread);
        compShader.SetFloat("fillShape", fillShape);

        compShader.SetVector("emitterSize", emitterSize);

        compShader.SetInt("shape", (int) emitterShape);

        compShader.SetTexture(0,"randomTex", randomTex);

    }

    void SetBoxColliderBuffer(out BoxColliderGPU[] gpuCollider, BoxCollider[] collider)
    {

       

        int colCount = collider.Length;
        //Set Box Collider Buffer Data
        gpuCollider = new BoxColliderGPU[colCount];
        for (int i = 0; i < colCount; i++)
        {

            gpuCollider[i].position = new Vector4(collider[i].transform.position.x,
                                                    collider[i].transform.position.y,
                                                    collider[i].transform.position.z,
                                                    1.0f);

            gpuCollider[i].unity_ObjectToWorld = collider[i].transform.localToWorldMatrix;
            gpuCollider[i].unity_WorldToObject = collider[i].transform.worldToLocalMatrix;

            
            
        }
    }

    void SetSphereColliderBuffer(out SphereColliderGPU[] gpuCollider, SphereCollider[] collider)
    {
        int colCount = collider.Length;
        //Set Sphere Collider Buffer Data
        gpuCollider = new SphereColliderGPU[colCount];
        for (int i = 0; i < sphereColliderCount; i++)
        {

            gpuCollider[i].position_rad = new Vector4(collider[i].transform.position.x,
                                                    collider[i].transform.position.y,
                                                    collider[i].transform.position.z,
                                                    collider[i].radius * Mathf.Abs(collider[i].transform.lossyScale.x));
        }
    }
    void SetCapsuleColliderBuffer(out CapsuleColliderGPU[] gpuCollider, CapsuleCollider[] collider)
    {
        int colCount = collider.Length;
        //Set Capsule Collider Buffer Data
        gpuCollider = new CapsuleColliderGPU[colCount];
        for (int i = 0; i < colCount; i++)
        {
            gpuCollider[i].position_rad = new Vector4(collider[i].transform.position.x,
                                                     collider[i].transform.position.y,
                                                     collider[i].transform.position.z,
                                                     collider[i].radius * collider[i].transform.lossyScale.x);


            gpuCollider[i].rotation_height = new Vector4(collider[i].transform.rotation.x,
                                                        collider[i].transform.rotation.y,
                                                        collider[i].transform.rotation.z,
                                                        collider[i].height * collider[i].transform.lossyScale.y);

            
        }
    }

    void SetEffectorBuffer(out EffectorGPU[] gpuEffector, ParticleEffectorGPU[] effector)
    {
        int effCount = effector.Length;
        //Set Effector Buffer Data
        gpuEffector = new EffectorGPU[effCount];
        for(int i = 0; i< effCount; i++)
        {
            gpuEffector[i].position_rad = new Vector4(effector[i].GetPosition().x,
                                                    effector[i].GetPosition().y,
                                                    effector[i].GetPosition().z,
                                                    effector[i].GetRadius());

            gpuEffector[i].direction_force = new Vector4(effector[i].GetDirection().x,
                                                       effector[i].GetDirection().y,
                                                       effector[i].GetDirection().z,
                                                       effector[i].GetForce());

            gpuEffector[i].attraction = effector[i].GetAttraction();
            gpuEffector[i].effectorType = (int) effector[i].GetEffectorType();


        }
    }

    void OnDestroy()
    {

        particlesBuffer.Dispose();
        particlesBuffer.Release();

        if (boxColliderBuffer != null)
        {
            boxColliderBuffer.Dispose();
            boxColliderBuffer.Release();
        }

        if (sphereColliderBuffer != null)
        {
            sphereColliderBuffer.Dispose();
            sphereColliderBuffer.Release();
        }

        if (capsuleColliderBuffer != null)
        {
            capsuleColliderBuffer.Dispose();
            capsuleColliderBuffer.Release();
        }

        if (effectorBuffer != null)
        {
            effectorBuffer.Dispose();
            effectorBuffer.Release();
        }
    }

    public int GetCount()
    {
        return particleCount;
    }

    public enum EmitterShape
    {
        Spot,
        Sphere,
        Box,
    }
}

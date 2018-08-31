using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TerrainDeformCollider : MonoBehaviour {

    struct VertexInput
    {
        public Vector3 position;
        public Vector2 texcoord;
    }

    struct VertexOutput
    {
        public Vector3 position;
    }

    VertexInput[] vData;
    VertexOutput[] vDataOut;


    Vector2[] texcoords;
    Vector3[] normals;
    Vector3[] positions;
    int[] triangles;


    MeshCollider _meshCol;
    Mesh _mesh;

    ComputeBuffer _vertBufferIn;
    ComputeBuffer _vertBufferOut;
    public ComputeShader _vertCompute;
    public Texture heightMap;

    public TerrainCamera snowController;

    float snowMaxHeight;

    int _vertCount;
    int _vertLoad;
    const int _warpSize = 32;




	// Use this for initialization
	void Start () {

        _meshCol = GetComponent<MeshCollider>();

        _mesh = new Mesh();
        
        _vertCount = _meshCol.sharedMesh.vertexCount;
        _vertLoad = _vertCount / _warpSize + 1;

        _vertBufferIn = new ComputeBuffer(_vertCount, 20);
        _vertBufferOut = new ComputeBuffer(_vertCount, 12);

        vData = new VertexInput[_vertCount];
        vDataOut = new VertexOutput[_vertCount];

        positions = _meshCol.sharedMesh.vertices;
        triangles = _meshCol.sharedMesh.triangles;
        texcoords = _meshCol.sharedMesh.uv;
        normals = _meshCol.sharedMesh.normals;

        for (int i = 0; i < _meshCol.sharedMesh.vertices.Length; i++)
        {
            vData[i].position = positions[i];
            vData[i].texcoord = texcoords[i];
        }
        for (int i = 0; i < _meshCol.sharedMesh.vertices.Length; i++)
        {
            vDataOut[i].position = positions[i];
        }

        _vertBufferIn.SetData(vData);
        _vertBufferOut.SetData(vDataOut);

        _vertCompute.SetBuffer(0, "vertexBuffer", _vertBufferIn);
        _vertCompute.SetBuffer(0, "vertexBufferOut", _vertBufferOut);
        _vertCompute.SetTexture(0, "heightMap", heightMap);

	}
	
	// Update is called once per frame
	void Update () {
       _vertCompute.Dispatch(0, _vertLoad, 1, 1);
        _vertCompute.SetTexture(0, "_SnowHeightTex", heightMap);
        _vertCompute.SetFloat("_SnowMaxHeight", snowMaxHeight);
        _vertBufferOut.GetData(vDataOut);

        for (int i = 0; i < positions.Length; i++)
        {
            positions[i] = vDataOut[i].position;// normals[i] * Mathf.Sin(Time.time); ; ; //vData[i].position;
           // Debug.Log(_mesh.vertices[i]);
        }
            _mesh.Clear();
            _mesh.vertices = positions;
            _mesh.uv = texcoords;
            _mesh.normals = normals;
            _mesh.triangles = triangles;
            //_mesh.triangles = triangles;
        //_mesh.UploadMeshData(false);

        _meshCol.sharedMesh = _mesh;
        
    }

    public void SetHeightTexture(Texture tex)
    {
        heightMap = tex;
    }
    public void SetMaxHeight(float max)
    {
        snowMaxHeight = max;
    }

    void OnDestroy()
    {
        _vertBufferIn.Release();
    }
}

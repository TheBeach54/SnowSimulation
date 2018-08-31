using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
public class PassSunDir : MonoBehaviour {

	// Use this for initialization
	void Start () {

        Shader.SetGlobalVector("_WorldDirectionalLightPos", -transform.forward.normalized);
	}
	
	// Update is called once per frame
	void Update () {
        Shader.SetGlobalVector("_WorldDirectionalLightPos", -transform.forward.normalized);
    }
}

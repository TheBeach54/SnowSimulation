using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public class ParticleEffectorGPU : MonoBehaviour {

    private Vector3 _effectorPosition;
    private Vector3 _effectorDirection;
    public ParticleEffectorType effectorType;
    public float radius;
    public float force;
    public float attraction;

    void Update()
    {
        _effectorDirection = transform.forward;
        _effectorPosition = transform.position;
    }

    public Vector3 GetPosition()
    {
        return _effectorPosition;
    }

    public float GetRadius()
    {
        return radius;
    }
    public float GetAttraction()
    {
        return attraction;
    }
    public float GetForce()
    {
        return force;
    }

    public Vector3 GetDirection()
    {
        return _effectorDirection;
    }

    public ParticleEffectorType GetEffectorType()
    {
        return effectorType;
    }

    public enum ParticleEffectorType
    {
        Directional,
        Spherical,
        Tornado,
    }
}

using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(ParticleEmitterGPU))]
public class DrawParticleEmitter : Editor
{
    // draw lines between a chosen game object
    // and a selection of added game objects

    void OnSceneGUI()
    {
        // get the chosen game object
        ParticleEmitterGPU t = target as ParticleEmitterGPU;


        if (t == null || t.gameObject == null)
            return;

        // grab the center of the parent
        Vector3 center = t.transform.position;
        Vector3 forward = t.transform.forward;
        Quaternion quatForw = t.transform.rotation;



                Handles.DrawWireDisc(center, forward, 1.0f);
        Handles.ArrowHandleCap(0, center, quatForw, 1.0f, EventType.Repaint);



    }
}

[CustomEditor(typeof(ParticleRendererGPU))]
public class DrawParticleRender : Editor
{
    // draw lines between a chosen game object
    // and a selection of added game objects

    void OnSceneGUI()
    {
        // get the chosen game object
        ParticleRendererGPU t = target as ParticleRendererGPU;


        if (t == null || t.gameObject == null)
            return;

        // grab the center of the parent
        Vector3 center = t.emitterTransform.position;
        Vector3 forward = t.emitterTransform.forward;
        Quaternion quatForw = t.emitterTransform.rotation;



        Handles.DrawWireDisc(center, forward, 1.0f);
        Handles.ArrowHandleCap(0, center, quatForw, 1.0f, EventType.Repaint);



    }
}

[CustomEditor(typeof(ParticleEffectorGPU))]
public class DrawParticleEffector : Editor
{
    // draw lines between a chosen game object
    // and a selection of added game objects

    void OnSceneGUI()
    {
        // get the chosen game object
        ParticleEffectorGPU t = target as ParticleEffectorGPU;


        if (t == null || t.gameObject == null)
            return;

        // grab the center of the parent
        Vector3 center = t.transform.position;
        Vector3 forward = t.transform.forward;
        Vector3 upward = t.transform.up;
        Vector3 right = t.transform.right;
        Quaternion quatForw = t.transform.rotation;
        float radius = t.GetRadius() * 0.5f;

        
        Handles.DrawWireDisc(center, forward, radius);
        Handles.DrawWireDisc(center, upward, radius);
        Handles.DrawWireDisc(center, right, radius);

        Handles.ArrowHandleCap(0, center, quatForw, 1.0f, EventType.Repaint);
        


    }
}
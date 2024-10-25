/*

Simple shader to display a ProTV video screen on an avatar, if available in the world.

A few snippets derived from Poiyomi.

Ideally, the face you apply this texture to should occupy 100% of the UV map
tile.  Any tiling/offset settings applied to the default texture in the
material will apply to the world screen texture as well.

*/

Shader "SophieBlue/ProTVScreen" {

    Properties {
        [HideInInspector] shader_is_using_thry_editor("", Float)=0
        [HideInInspector] shader_master_label ("<color=#ff6600>ProTV Screen 1.0.0</color>", Float) = 0
        [HideInInspector] footer_github ("{texture:{name:icon-github,height:16},action:{type:URL,data:https://github.com/SophieBlueVR/shaders},hover:GITHUB}", Float) = 0


        [ThryWideEnum(Opaque, 0, Cutout, 1, Transparent, 2)]_Mode("Rendering Preset--{on_value_actions:[
            {value:0,actions:[
                {type:SET_PROPERTY,data:render_queue=2000},
                {type:SET_PROPERTY,data:_AlphaForceOpaque=1},
                {type:SET_PROPERTY,data:render_type=Opaque},
                {type:SET_PROPERTY,data:_Cutoff=0},
                {type:SET_PROPERTY,data:_BlendOp=0},
                {type:SET_PROPERTY,data:_BlendOpAlpha=4},
                {type:SET_PROPERTY,data:_ZWrite=1},
                {type:SET_PROPERTY,data:_ZTest=4},
            ]},
            {value:1,actions:[
                {type:SET_PROPERTY,data:render_queue=2450},
                {type:SET_PROPERTY,data:_AlphaForceOpaque=0},
                {type:SET_PROPERTY,data:render_type=TransparentCutout},
                {type:SET_PROPERTY,data:_Cutoff=.5},
                {type:SET_PROPERTY,data:_BlendOp=0},
                {type:SET_PROPERTY,data:_BlendOpAlpha=4},
                {type:SET_PROPERTY,data:_ZWrite=1},
                {type:SET_PROPERTY,data:_ZTest=4},
            ]},
            {value:2,actions:[
                {type:SET_PROPERTY,data:render_queue=3000},
                {type:SET_PROPERTY,data:_AlphaForceOpaque=0},
                {type:SET_PROPERTY,data:render_type=Transparent},
                {type:SET_PROPERTY,data:_Cutoff=0},
                {type:SET_PROPERTY,data:_BlendOp=5},
                {type:SET_PROPERTY,data:_BlendOpAlpha=10},
                {type:SET_PROPERTY,data:_ZWrite=0},
                {type:SET_PROPERTY,data:_ZTest=4},
            ]},
	]}", Int) = 0


        [HideInInspector] m_mainCategory ("Texture", Float) = 0
            [SmallTexture] _MainTex ("Default Texture--{reference_properties:[_MainTexUV,]}", 2D) = "black" {}
            [HideInInspector][ThryWideEnum(UV0, 0, UV1, 1, UV2, 2, UV3, 3)] _MainTexUV ("UV", Int) = 0

        [HideInInspector] m_colorCategory ("Color Adjustments", Float) = 0
            _Color ("Color & Alpha", Color) = (1, 1, 1, 1)
            [Gamma] _Brightness("Brightness", Range(0, 10)) = 1
            _Cutoff ("Alpha Cutoff", Range(0,1)) = 0

        [HideInInspector] m_renderingCategory ("Rendering", Float) = 0
            [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 2
            [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("ZTest", Float) = 4
            [Enum(Off, 0, On, 1)] _ZWrite ("ZWrite", Int) = 1

            [HideInInspector] m_start_blending ("Blending", Float) = 0
                [Enum(Thry.BlendOp)]_BlendOp ("RGB Blend Op", Int) = 0
                [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("RGB Source Blend", Int) = 1
                [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("RGB Destination Blend", Int) = 0
            [HideInInspector] m_end_blending ("Blending", Float) = 0

    }
    CustomEditor "Thry.ShaderEditor"

    SubShader {
        Tags {
            "RenderType"        = "Transparent"
            "Queue"             = "Transparent"
            "IgnoreProjector"   = "true"
            "VRCFallback"       = "Standard"
        }

        Cull [_Cull]
        ZTest [_ZTest]
        ZWrite [_ZWrite]
        BlendOp [_BlendOp]
        Blend [_SrcBlend] [_DstBlend]

        Pass {
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            // GPU Instancing support https://docs.unity3d.com/2022.3/Documentation/Manual/gpu-instancing-shader.html
            #pragma multi_compile_instancing
            #include "UnityCG.cginc"

            #define RENDER_MODE_OPAQUE 0
            #define RENDER_MODE_CUTOUT 1
            #define RENDER_MODE_TRANSPARENT 2

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _MainTexUV;

            float _Brightness;
            float _Cutoff;
            float4 _Color;
            float _AlphaForceOpaque;
            float _Mode;

            // here's the actual video texture
            uniform sampler2D _Udon_VideoTex;
            float4 _Udon_VideoTex_TexelSize;
            float4 _Udon_VideoTex_ST;

            struct VertexInput {
                float4 pos : POSITION;
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
                float2 uv3 : TEXCOORD3;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VertexOutput {
                float4 pos : SV_POSITION;
                float4 uv[2] : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            // calculate texture UVs including offset/scale
            float2 calcUV(float2 uv, float4 tex_st) {
                return uv * tex_st.xy + tex_st.zw;
            }

            VertexOutput vert(VertexInput v) {
                VertexOutput o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_OUTPUT(VertexOutput, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.pos = UnityObjectToClipPos(v.pos);
                o.uv[0] = float4(v.uv0.xy, v.uv1.xy);
                o.uv[1] = float4(v.uv2.xy, v.uv3.xy);
                return o;
            }

            float4 frag(const VertexOutput i) : SV_Target {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                // remap UVs
                float2 allUVs[4];
                allUVs[0] = i.uv[0].xy;
                allUVs[1] = i.uv[0].zw;
                allUVs[2] = i.uv[1].xy;
                allUVs[3] = i.uv[1].zw;
                // choose the one we need
                float2 uv = allUVs[_MainTexUV];

                // sample the texture
                float4 tex = float4(0,0,0,1);
                if (_Udon_VideoTex_TexelSize.z <= 16) {
                    // no video texture, use default
                    tex = tex2D(_MainTex, TRANSFORM_TEX(uv, _MainTex));
                } else {
                    // video texture present
                    tex = tex2D(_Udon_VideoTex, TRANSFORM_TEX(uv, _Udon_VideoTex));
                }

                // apply color adjustment
                tex.rgb *= _Color.rgb;

                // if we're in opaque mode, alpha is always 1
                if (_Mode == RENDER_MODE_OPAQUE) {
                    tex.a = 1;
                }
                else {
                    // apply alpha adjustment
                    tex.a *= _Color.a;

                    // discard under alpha threshold
                    clip(tex.a - _Cutoff);

                    // if not in transparent mode, remaining alpha must be 1
                    if (_Mode != RENDER_MODE_TRANSPARENT)
                        tex.a = 1;
                }

                // final color output
                tex.rgb *= _Brightness;

                return tex;
            }
            ENDCG
        }
    }
}

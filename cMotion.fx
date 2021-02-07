
/*
    This work is licensed under a Creative Commons Attribution 3.0 Unported License.
    https://creativecommons.org/licenses/by/3.0/us/

    pFlowBlur() from Jose Negrete AKA BlueSkyDefender [https://github.com/BlueSkyDefender/AstrayFX]
*/

#include "ReShade.fxh"

uniform float kLambda <
    ui_type = "drag";
    ui_label = "Lambda";
> = 4.0;

uniform int kDebug <
    ui_type = "combo";
    ui_items = "Off\0Direction\0";
    ui_label = "Debug View";
> = 0;

#define size 1024 // Textures need to be powers of 2 for elegent mipmapping
#define lod 5.0

texture2D r_lod    { Width = size; Height = size; Format = R16F; MipLevels = 6.0; };
texture2D r_cframe { Width = size; Height = size; Format = R16F; };
texture2D r_pframe { Width = size; Height = size; Format = R16F; };

sampler2D s_source
{
    Texture = ReShade::BackBufferTex;
    #if BUFFER_COLOR_BIT_DEPTH != 10
        SRGBTexture = true;
    #endif
};

sampler2D s_lod    { Texture = r_lod; };
sampler2D s_cframe { Texture = r_cframe; };
sampler2D s_pframe { Texture = r_pframe; };

struct v2f
{
    float4 vpos : SV_POSITION;
    float2 uv : TEXCOORD0;
};

/* [ Pixel Shaders ] */

// Empty shader to generate brightpass, mipmaps, and previous frame
// Exposure algorithm from [https://github.com/TheRealMJP/BakingLab] [MIT]
void ps_lod(v2f input, out float c : SV_Target0, out float p : SV_Target1)
{
    float3 col = tex2Dlod(s_source, float4(input.uv, 0.0, 0.0)).rgb;
    c = rcp(dot(col, rcp(3.0)) + 0.0001);
    c = log2(c);
    p = tex2D(s_cframe, input.uv).x; // Output the c_Frame we got from last frame
}

/*
    - Color optical flow, by itself, is too small to make motion blur
    - BSD's eMotion does not have this issue because depth texture colors are flat
    - Gaussian blur is expensive and we do not want more passes

    Question: What is the fastest way to smoothly blur a picture?
    Answer: Cubic-filtered texture LOD

    Taken from [https://github.com/haasn/libplacebo/blob/master/src/shaders/sampling.c] [GPL 2.1]
    How bicubic scaling with 4 texel fetches is done [http://www.mate.tue.nl/mate/pdfs/10318.pdf]
    'Efficient GPU-Based Texture Interpolation using Uniform B-Splines'
*/

float4 calcweights(float s)
{
    const float4 a = float4(-0.5, 0.1666, 0.3333, -0.3333);
    const float4 b = float4(1.0, 0.0, -0.5, 0.5);
    const float4 c = float4(-0.6666, 0.0, 0.8333, 0.1666);
    float4 t = mad(a, s, b);
    t = mad(t, s, b.yyzw);
    t = mad(t, s, c);
    t.xy = mad(t.xy, rcp(t.zw), 1.0);
    t.x += s;
    t.y -= s;
    return t;
}

// NOTE: This is a grey cubic filter. Cubic.fx is the RGB version of this ;)
void ps_cubic(v2f input, out float c : SV_Target0)
{
    const float2 texsize = ldexp(size, -lod);
    const float2 pt = 1.0 / texsize;
    float2 fcoord = frac(input.uv * texsize + 0.5);
    float4 parmx = calcweights(fcoord.x);
    float4 parmy = calcweights(fcoord.y);
    float4 cdelta;
    cdelta.xz = parmx.rg * float2(-pt.x, pt.x);
    cdelta.yw = parmy.rg * float2(-pt.y, pt.y);
    // first y-interpolation
    float3 a;
    a.r = tex2Dlod(s_lod, float4(input.uv + cdelta.xy, 0.0, lod)).x;
    a.g = tex2Dlod(s_lod, float4(input.uv + cdelta.xw, 0.0, lod)).x;
    a.b = lerp(a.g, a.r, parmy.b);
    // second y-interpolation
    float3 b;
    b.r = tex2Dlod(s_lod, float4(input.uv + cdelta.zy, 0.0, lod)).x;
    b.g = tex2Dlod(s_lod, float4(input.uv + cdelta.zw, 0.0, lod)).x;
    b.b = lerp(b.g, b.r, parmy.b);
    // x-interpolation
    c = lerp(b.b, a.b, parmx.b).x;
}

/*
    Algorithm from [https://github.com/mattatz/unity-optical-flow] [MIT]
    Optimization from [https://www.shadertoy.com/view/3l2Gz1] [CC BY-NC-SA 3.0]

    ISSUE:
    mFlow combines the optical flow result of the current AND previous frame.
    This means there are blurred ghosting that happens frame-by-frame
*/

float2 mFlow(float curr, float prev)
{
    float dt = distance(curr, prev); // distance between current and previous frame
    float4 d; // Edge detection
    d.x = ddx(curr + prev);
    d.y = ddy(curr + prev);
    d.xy *= 0.5;
    d.z = kLambda;
    d.w = length(d.xyz); // magnitude :: length() uses 1 dp3add instead of mul + mad
    return dt * (d.xy / d.w);
}

void ps_flow(v2f input, out float3 c : SV_Target0)
{
    // Calculate optical flow and blur direction
    // BSD did this in another pass, but this should be cheaper
    // Putting it here also means the values are not clamped!
    float curr = tex2D(s_cframe, input.uv).x; // cubic from this frame
    float prev = tex2D(s_pframe, input.uv).x; // cubic from last frame
    float2 oFlow = mFlow(curr, prev);

    // Interleaved Gradient Noise by Jorge Jimenez to smoothen blur samples
    // [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]
    const float3 m = float3(52.9829189, 0.06711056, 0.00583715);
    float ign = frac(m.x * frac(dot(input.vpos.xy, m.yz)));

    // From [http://john-chapman-graphics.blogspot.com/2013/01/per-object-motion-blur.html]
    c  = tex2D(s_source, input.uv + oFlow * (ign + 1)).rgb * 0.125;
    c += tex2D(s_source, input.uv + oFlow * (ign + 2)).rgb * 0.125;
    c += tex2D(s_source, input.uv + oFlow * (ign + 3)).rgb * 0.125;
    c += tex2D(s_source, input.uv + oFlow * (ign + 4)).rgb * 0.125;
    c += tex2D(s_source, input.uv + oFlow * (ign + 5)).rgb * 0.125;
    c += tex2D(s_source, input.uv + oFlow * (ign + 6)).rgb * 0.125;
    c += tex2D(s_source, input.uv + oFlow * (ign + 7)).rgb * 0.125;
    c += tex2D(s_source, input.uv + oFlow * (ign + 8)).rgb * 0.125;
}

technique cMotionBlur < ui_tooltip = "Color-Based Motion Blur"; >
{
    pass LOD
    {
        VertexShader = PostProcessVS;
        PixelShader = ps_lod;
        RenderTarget0 = r_lod;
        RenderTarget1 = r_pframe; // Store previous frame's cubic for mFlow()
    }

    pass CubicFrame
    {
        VertexShader = PostProcessVS;
        PixelShader = ps_cubic;
        RenderTarget0 = r_cframe;
    }

    pass FlowBlur
    {
        VertexShader = PostProcessVS;
        PixelShader = ps_flow;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
    }
}


/*
    This work is licensed under a Creative Commons Attribution 3.0 Unported License.
    https://creativecommons.org/licenses/by/3.0/us/

    pFlowBlur() from Jose Negrete AKA BlueSkyDefender [https://github.com/BlueSkyDefender/AstrayFX]
*/

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

texture2D r_color  : COLOR;
texture2D r_lod    { Width = size; Height = size; Format = R16F; MipLevels = 7.0; };
texture2D r_cframe { Width = size; Height = size; Format = R16F; };
texture2D r_pframe { Width = size; Height = size; Format = R16F; };

sampler2D s_color
{
    Texture = r_color;
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

struct p2mrt
{
	float4 cframe : SV_Target0;
	float4 pframe : SV_Target1;
};

v2f vs_basic(const uint id : SV_VertexID)
{
    v2f o;
    o.uv.x = (id == 2) ? 2.0 : 0.0;
    o.uv.y = (id == 1) ? 2.0 : 0.0;
    o.vpos = float4(o.uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    return o;
}

/* [ Pixel Shaders ] */

// Empty shader to generate brightpass, mipmaps, and previous frame
// Exposure algorithm from [https://github.com/TheRealMJP/BakingLab] [MIT]
p2mrt ps_lod(v2f input)
{
	p2mrt o;
    float4 col = tex2D(s_color, input.uv);
    o.cframe = dot(col, rcp(3.0)) + 1e-4;
    o.cframe = log2(-o.cframe);
    o.pframe = tex2D(s_cframe, input.uv).x; // Output the c_Frame we got from last frame
    return o;
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
float4 ps_cframe(v2f input) : SV_Target0
{
    const float2 texsize = tex2Dsize(s_lod, 6.0);
    const float2 pt = 1.0 / texsize;
    float2 fcoord = frac(input.uv * texsize + 0.5);
    float4 parmx = calcweights(fcoord.x);
    float4 parmy = calcweights(fcoord.y);
    float4 cdelta;
    cdelta.xz = parmx.rg * float2(-pt.x, pt.x);
    cdelta.yw = parmy.rg * float2(-pt.y, pt.y);
    // first y-interpolation
    float3 a;
    a.r = tex2Dlod(s_lod, float4(input.uv + cdelta.xy, 0.0, 6.0)).x;
    a.g = tex2Dlod(s_lod, float4(input.uv + cdelta.xw, 0.0, 6.0)).x;
    a.b = lerp(a.g, a.r, parmy.b);
    // second y-interpolation
    float3 b;
    b.r = tex2Dlod(s_lod, float4(input.uv + cdelta.zy, 0.0, 6.0)).x;
    b.g = tex2Dlod(s_lod, float4(input.uv + cdelta.zw, 0.0, 6.0)).x;
    b.b = lerp(b.g, b.r, parmy.b);
    // x-interpolation
    return lerp(b.b, a.b, parmx.b);
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
    float dt = length(curr - prev); // distance between current and previous frame
    float4 d; // Edge detection
    d.x = ddx(curr + prev);
    d.y = ddy(curr + prev);
    d.z = kLambda;
    d.w = length(d.xyz); // magnitude :: length() uses 1 dp3add instead of mul + mad
	return dt * (d.xy / d.w);
}

float2 calcFlow(float2 uv, float2 vpos, float2 flow, float i)
{
    // Interleaved Gradient Noise by Jorge Jimenez to smoothen blur samples
    // [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]
    const float3 m = float3(52.9829189, 0.06711056, 0.00583715);
    float ign = frac(m.x * frac(dot(vpos.xy, m.yz)));

    // From [http://john-chapman-graphics.blogspot.com/2013/01/per-object-motion-blur.html]
    const float kSamples = 1.0 / (16.0 - 1.0);
    float2 kCalc = (ign * 2.0 + i) * kSamples - 0.5;
	return flow * kCalc + uv;
}

float4 ps_flowblur(v2f input) : SV_Target0
{
    // Calculate optical flow and blur direction
    // BSD did this in another pass, but this should be cheaper
    // Putting it here also means the values are not clamped!
    float curr = tex2D(s_cframe, input.uv).x; // cubic from this frame
    float prev = tex2D(s_pframe, input.uv).x; // cubic from last frame
    float2 oFlow = mFlow(curr, prev);

	const float kWeights = 1.0 / 8.0;
	float4 color = 0.0;
    color  = tex2D(s_color, calcFlow(input.uv, input.vpos.xy, oFlow, 2.0)) * kWeights;
    color += tex2D(s_color, calcFlow(input.uv, input.vpos.xy, oFlow, 4.0)) * kWeights;
    color += tex2D(s_color, calcFlow(input.uv, input.vpos.xy, oFlow, 6.0)) * kWeights;
    color += tex2D(s_color, calcFlow(input.uv, input.vpos.xy, oFlow, 8.0)) * kWeights;
    color += tex2D(s_color, calcFlow(input.uv, input.vpos.xy, oFlow, 10.0)) * kWeights;
    color += tex2D(s_color, calcFlow(input.uv, input.vpos.xy, oFlow, 12.0)) * kWeights;
    color += tex2D(s_color, calcFlow(input.uv, input.vpos.xy, oFlow, 14.0)) * kWeights;
    color += tex2D(s_color, calcFlow(input.uv, input.vpos.xy, oFlow, 16.0)) * kWeights;
    return color;
}

technique cMotionBlur < ui_tooltip = "Color-Based Motion Blur"; >
{
    pass
    {
        VertexShader = vs_basic;
        PixelShader = ps_lod;
        RenderTarget0 = r_lod;
        RenderTarget1 = r_pframe; // Store previous frame's cubic for mFlow()
    }

    pass
    {
        VertexShader = vs_basic;
        PixelShader = ps_cframe;
        RenderTarget0 = r_cframe;
    }

    pass
    {
        VertexShader = vs_basic;
        PixelShader = ps_flowblur;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
    }
}

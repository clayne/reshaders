/*

*/

#include "ReShade.fxh"

texture t_ComputeLum < pooled = true; > { Width = BUFFER_WIDTH/32; Height = BUFFER_HEIGHT/32; };
texture t_Push < pooled = true; > { Width = BUFFER_WIDTH/32; Height = BUFFER_HEIGHT/32; };
texture t_ComputeGradent < pooled = true; > { Width = BUFFER_WIDTH/32; Height = BUFFER_HEIGHT/32; };

sampler s_Linear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };
sampler s_ComputeLum { Texture = t_ComputeLum; MipLODBias = 125; };
sampler s_Push { Texture = t_Push; };
sampler s_ComputeGradent { Texture = t_ComputeGradent; };

/* [ Common.hlsl ] */

struct vs_out { float4 vpos : SV_POSITION; float2 uv : TEXCOORD; };
float MinA(float4 a, float4 b, float4 c) { return min(min(a.a, b.a), c.a); }
float MaxA(float4 a, float4 b, float4 c) { return max(max(a.a, b.a), c.a); }
float MinA(float4 a, float4 b, float4 c, float4 d) { return min(min(min(a.a, b.a), c.a), d.a); }
float MaxA(float4 a, float4 b, float4 c, float4 d) { return max(max(max(a.a, b.a), c.a), d.a); }

/* [ ComputeLum.hlsl ] */

// LinearRgbToLuminance() from UnityCG.cginc
float Luminance(float3 linearRgb) { return dot(linearRgb, float3(0.2126729f,  0.7151522f, 0.0721750f)); }

float4 ComputeLum(vs_out o) : SV_Target
{
    float4 c = tex2D(s_Linear, o.uv);
    return float4(c.rgb, Luminance(c.rgb));
}

/* [ Push.hlsl ] */

float4 Largest(float4 mc, float4 lightest, float4 a, float4 b, float4 c)
{
    float4 abc = lerp(mc, (a + b + c) / 3, 0.3);
    return abc.a > lightest.a ? abc : lightest;
}

static const float2 _MainTex_TexelSize = BUFFER_PIXEL_SIZE * 8;

float4 Push(vs_out o) : SV_Target
{
    // [tl tc tr]
    // [ml mc mr]
    // [bl bc br]

    float4 duv = _MainTex_TexelSize.xyxy * float4(1, 1, -1, 0);

    float4 tl = tex2D(s_ComputeLum, o.uv - duv.xy);
    float4 tc = tex2D(s_ComputeLum, o.uv - duv.wy);
    float4 tr = tex2D(s_ComputeLum, o.uv - duv.zy);

    float4 ml = tex2D(s_ComputeLum, o.uv - duv.xw);
    float4 mc = tex2D(s_ComputeLum, o.uv);
    float4 mr = tex2D(s_ComputeLum, o.uv + duv.xw);

    float4 bl = tex2D(s_ComputeLum, o.uv + duv.zy);
    float4 bc = tex2D(s_ComputeLum, o.uv + duv.wy);
    float4 br = tex2D(s_ComputeLum, o.uv + duv.xy);

    float4 lightest = mc;

    // Kernel 0 and 4
    if (MinA(tl, tc, tr) > MaxA(mc, br, bc, bl))
        lightest = Largest(mc, lightest, tl, tc, tr);
    else if (MinA(br, bc, bl) > MaxA(mc, tl, tc, tr))
        lightest = Largest(mc, lightest, br, bc, bl);

    // Kernel 1 and 5
    if (MinA(mr, tc, tr) > MaxA(mc, ml, bc))
        lightest = Largest(mc, lightest, mr, tc, tr);
    else if (MinA(bl, ml, bc) > MaxA(mc, mr, tc))
        lightest = Largest(mc, lightest, bl, ml, bc);

    // Kernel 2 and 6
    if (MinA(mr, br, tr) > MaxA(mc, ml, tl, bl))
        lightest = Largest(mc, lightest, mr, br, tr);
    else if (MinA(ml, tl, bl) > MaxA(mc, mr, br, tr))
        lightest = Largest(mc, lightest, ml, tl, bl);

    //Kernel 3 and 7
    if (MinA(mr, br, bc) > MaxA(mc, ml, tc))
        lightest = Largest(mc, lightest, mr, br, bc);
    else if (MinA(tc, ml, tl) > MaxA(mc, mr, bc))
        lightest = Largest(mc, lightest, tc, ml, tl);

    return lightest;
}

/* [ ComputeGradient.hlsl ] */

float4 ComputeGradient(vs_out o) : SV_Target
{
    float4 c0 = tex2D(s_Push, o.uv);

    // [tl tc tr]
    // [ml    mr]
    // [bl bc br]

    float4 duv = _MainTex_TexelSize.xyxy * float4(1, 1, -1, 0);

    float tl = tex2D(s_Push, o.uv - duv.xy).a;
    float tc = tex2D(s_Push, o.uv - duv.wy).a;
    float tr = tex2D(s_Push, o.uv - duv.zy).a;

    float ml = tex2D(s_Push, o.uv - duv.xw).a;
    float mr = tex2D(s_Push, o.uv + duv.xw).a;

    float bl = tex2D(s_Push, o.uv + duv.zy).a;
    float bc = tex2D(s_Push, o.uv + duv.wy).a;
    float br = tex2D(s_Push, o.uv + duv.xy).a;

    // Horizontal gradient
    // [-1  0  1]
    // [-2  0  2]
    // [-1  0  1]

    // Vertical gradient
    // [-1 -2 -1]
    // [ 0  0  0]
    // [ 1  2  1]

    float2 grad = float2(tr + mr * 2 + br - (tl + ml * 2 + bl),
                         bl + bc * 2 + br - (tl + tc * 2 + tr));

    // Computes the luminance's gradient and saves it in the unused alpha channel
    return float4(c0.rgb, 1 - saturate(length(grad)));
}

/* [PushGrad.hlsl] */

float4 Average(float4 mc, float4 a, float4 b, float4 c)
{
    return float4(lerp(mc, (a + b + c) / 3, 1).rgb, 1);
}

float4 PushGrad(vs_out o) : SV_Target
{
    // [tl tc tr]
    // [ml mc mr]
    // [bl bc br]

    float4 duv = _MainTex_TexelSize.xyxy * float4(1, 1, -1, 0);

    float4 tl = tex2D(s_ComputeGradent, o.uv - duv.xy);
    float4 tc = tex2D(s_ComputeGradent, o.uv - duv.wy);
    float4 tr = tex2D(s_ComputeGradent, o.uv - duv.zy);

    float4 ml = tex2D(s_ComputeGradent, o.uv - duv.xw);
    float4 mc = tex2D(s_ComputeGradent, o.uv);
    float4 mr = tex2D(s_ComputeGradent, o.uv + duv.xw);

    float4 bl = tex2D(s_ComputeGradent, o.uv + duv.zy);
    float4 bc = tex2D(s_ComputeGradent, o.uv + duv.wy);
    float4 br = tex2D(s_ComputeGradent, o.uv + duv.xy);

    // Kernel 0 and 4
    if (MinA(tl, tc, tr) > MaxA(mc, br, bc, bl)) return Average(mc, tl, tc, tr);
    if (MinA(br, bc, bl) > MaxA(mc, tl, tc, tr)) return Average(mc, br, bc, bl);

    // Kernel 1 and 5
    if (MinA(mr, tc, tr) > MaxA(mc, ml, bc    )) return Average(mc, mr, tc, tr);
    if (MinA(bl, ml, bc) > MaxA(mc, mr, tc    )) return Average(mc, bl, ml, bc);

    // Kernel 2 and 6
    if (MinA(mr, br, tr) > MaxA(mc, ml, tl, bl)) return Average(mc, mr, br, tr);
    if (MinA(ml, tl, bl) > MaxA(mc, mr, br, tr)) return Average(mc, ml, tl, bl);

    // Kernel 3 and 7
    if (MinA(mr, br, bc) > MaxA(mc, ml, tc    )) return Average(mc, mr, br, bc);
    if (MinA(tc, ml, tl) > MaxA(mc, mr, bc    )) return Average(mc, tc, ml, tl);

    return float4(mc.rgb, 1);
}

/* [ Techniques ] */

technique Anime4k
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = ComputeLum;
        RenderTarget = t_ComputeLum;
    }
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = Push;
        RenderTarget = t_Push;
    }
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = ComputeGradient;
        RenderTarget = t_ComputeGradent;
    }
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PushGrad;
        SRGBWriteEnable = true;
    }
}

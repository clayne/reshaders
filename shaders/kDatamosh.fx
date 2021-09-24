
/*
    Color + BlendOp version of KinoDatamosh https://github.com/keijiro/KinoDatamosh

    Copyright (C) 2016 Keijiro Takahashi

    Permission is hereby granted, free of charge, to any person obtaining a copy of
    this software and associated documentation files (the "Software"), to deal in
    the Software without restriction, including without limitation the rights to
    use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
    the Software, and to permit persons to whom the Software is furnished to do so,
    subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
    FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
    COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
    IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
    CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

uniform float uTime < source = "timer"; >;

uniform int uBlockSize <
    ui_category = "Datamosh";
    ui_type = "slider";
    ui_label = "Block Size";
    ui_min = 4;
    ui_max = 32;
> = 16;

uniform float uEntropy <
    ui_category = "Datamosh";
    ui_type = "slider";
    ui_label = "Entropy";
    ui_tooltip = "The larger value stronger noise and makes mosh last longer.";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.5;

uniform float uContrast <
    ui_category = "Datamosh";
    ui_type = "slider";
    ui_label = "Contrast";
    ui_tooltip = "Contrast of stripe-shaped noise.";
    ui_min = 0.5;
    ui_max = 4.0;
> = 1.0;

uniform float uScale <
    ui_category = "Datamosh";
    ui_type = "slider";
    ui_label = "Scale";
    ui_tooltip = "Scale factor for velocity vectors.";
    ui_min = 0.0;
    ui_max = 2.0;
> = 0.8;

uniform float uDiffusion <
    ui_category = "Datamosh";
    ui_type = "slider";
    ui_label = "Diffusion";
    ui_tooltip = "Amount of random displacement.";
    ui_min = 0.0;
    ui_max = 2.0;
> = 0.4;

uniform float uDetail <
    ui_category = "Motion Vectors";
    ui_type = "drag";
    ui_label = "Blockiness";
    ui_tooltip = "How blocky the motion vectors should be.";
    ui_min = 0.0;
> = 0.0;

uniform float uConst <
    ui_category = "Motion Vectors";
    ui_type = "drag";
    ui_label = "Constraint";
    ui_tooltip = "Higher = Smoother flow";
    ui_min = 0.0;
> = 1.0;

uniform float uBlend <
    ui_category = "Motion Vectors";
    ui_type = "drag";
    ui_label = "Temporal Smoothing";
    ui_tooltip = "Higher = Less temporal noise";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.5;

#ifndef LINEAR_SAMPLING
    #define LINEAR_SAMPLING 0
#endif

#if LINEAR_SAMPLING == 1
    #define MFILTER MinFilter = LINEAR; MagFilter = LINEAR
#else
    #define MFILTER MinFilter = POINT; MagFilter = POINT
#endif

#define CONST_LOG2(x) (\
    (uint((x)  & 0xAAAAAAAA) != 0) | \
    (uint(((x) & 0xFFFF0000) != 0) << 4) | \
    (uint(((x) & 0xFF00FF00) != 0) << 3) | \
    (uint(((x) & 0xF0F0F0F0) != 0) << 2) | \
    (uint(((x) & 0xCCCCCCCC) != 0) << 1))

#define BIT2_LOG2(x)  ((x) | (x) >> 1)
#define BIT4_LOG2(x)  (BIT2_LOG2(x) | BIT2_LOG2(x) >> 2)
#define BIT8_LOG2(x)  (BIT4_LOG2(x) | BIT4_LOG2(x) >> 4)
#define BIT16_LOG2(x) (BIT8_LOG2(x) | BIT8_LOG2(x) >> 8)
#define LOG2(x)       (CONST_LOG2((BIT16_LOG2(x) >> 1) + 1))
#define RMAX(x, y)     x ^ ((x ^ y) & -(x < y)) // max(x, y)

#define DSIZE uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)
#define RSIZE LOG2(RMAX(DSIZE.x, DSIZE.y)) + 1
#define FSIZE LOG2(RMAX(DSIZE.x / 2, DSIZE.y / 2)) + 1

texture2D r_color  : COLOR;

texture2D r_pbuffer
{
    Width = DSIZE.x;
    Height = DSIZE.y;
    Format = RG16F;
    MipLevels = RSIZE;
};

texture2D r_cbuffer
{
    Width = DSIZE.x;
    Height = DSIZE.y;
    Format = R16F;
    MipLevels = RSIZE;
};

texture2D r_cuddxy
{
    Width = DSIZE.x;
    Height = DSIZE.y;
    Format = RG16F;
    MipLevels = RSIZE;
};

texture2D r_coflow
{
    Width = DSIZE.x;
    Height = DSIZE.y;
    Format = RG16F;
    MipLevels = RSIZE;
};

texture2D r_caccum
{
    Width = DSIZE.x;
    Height = DSIZE.y;
    Format = R16F;
    MipLevels = RSIZE;
};

texture2D r_copy
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA8;
};

sampler2D s_color
{
    Texture = r_color;
    AddressU = MIRROR;
    AddressV = MIRROR;
    SRGBTexture = TRUE;
};

sampler2D s_pbuffer
{
    Texture = r_pbuffer;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

sampler2D s_cbuffer
{
    Texture = r_cbuffer;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

sampler2D s_cuddxy
{
    Texture = r_cuddxy;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

sampler2D s_coflow
{
    Texture = r_coflow;
    MFILTER;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

sampler2D s_caccum
{
    Texture = r_caccum;
    MFILTER;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

sampler2D s_copy
{
    Texture = r_copy;
    AddressU = MIRROR;
    AddressV = MIRROR;
    SRGBTexture = TRUE;
};

/* [Vertex Shaders] */

void vs_generic(in uint id : SV_VERTEXID,
                out float4 position : SV_POSITION,
                out float2 texcoord : TEXCOORD)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [Pixel Shaders ] */

void ps_convert(float4 vpos : SV_POSITION,
                float2 uv : TEXCOORD0,
                out float2 r0 : SV_TARGET0)
{
    // r0.xy = normalize current frame
    // r0.zw = get normalized frame from last pass
    float3 c0 = max(tex2D(s_color, uv).rgb, 1e-7);
    c0 /= dot(c0, 1.0);
    c0 /= max(max(c0.r, c0.g), c0.b);
    r0.x = dot(c0, 1.0 / 3.0);
    r0.y = tex2D(s_cbuffer, uv).x;
}

void ps_filter(float4 vpos : SV_POSITION,
               float2 uv : TEXCOORD0,
               out float r0 : SV_TARGET0,
               out float2 r1 : SV_TARGET1)
{
    r0 = tex2D(s_pbuffer, uv).x;
    const float2 psize = 1.0 / tex2Dsize(s_pbuffer, 0.0);
    float2 s0 = tex2D(s_pbuffer, uv + float2(-psize.x, +psize.y)).rg;
    float2 s1 = tex2D(s_pbuffer, uv + float2(+psize.x, +psize.y)).rg;
    float2 s2 = tex2D(s_pbuffer, uv + float2(-psize.x, -psize.y)).rg;
    float2 s3 = tex2D(s_pbuffer, uv + float2(+psize.x, -psize.y)).rg;
    float4 dx0;
    dx0.xy = s1 - s0;
    dx0.zw = s3 - s2;
    float4 dy0;
    dy0.xy = s0 - s2;
    dy0.zw = s1 - s3;
    r1.x = dot(dx0, 0.25);
    r1.y = dot(dy0, 0.25);
}

/*
    https://www.cs.auckland.ac.nz/~rklette/CCV-CIMAT/pdfs/B08-HornSchunck.pdf
    - Use a regular image pyramid for input frames I(., .,t)
    - Processing starts at a selected level (of lower resolution)
    - Obtained results are used for initializing optic flow values at a
      lower level (of higher resolution)
    - Repeat until full resolution level of original frames is reached
*/

float4 ps_flow(float4 vpos : SV_POSITION,
               float2 uv : TEXCOORD0) : SV_TARGET
{
    const float uRegularize = max(4.0 * pow(uConst * 1e-2, 2.0), 1e-10);
    const int pyramids = RSIZE - 1;
    float2 cFlow = 0.0;

    for(float i = pyramids; i >= 0; i--)
    {
        float4 ucalc = float4(uv, 0.0, i);
        float cFrame = tex2Dlod(s_cbuffer, ucalc).x;
        float pFrame = tex2Dlod(s_pbuffer, ucalc).y;
        float2 ddxy = tex2Dlod(s_cuddxy, ucalc).xy;

        float dt = cFrame - pFrame;
        float dCalc = dot(ddxy.xy, cFlow) + dt;
        float dSmooth = rcp(dot(ddxy.xy, ddxy.xy) + uRegularize);
        cFlow = cFlow - ((ddxy.xy * dCalc) * dSmooth);
    }

    return float4(cFlow.xy, 0.0, uBlend);
}

float urand(float2 uv)
{
    float f = dot(float2(12.9898, 78.233), uv);
    return frac(43758.5453 * sin(f));
}

float4 ps_accum(float4 vpos : SV_POSITION,
                float2 uv : TEXCOORD0) : SV_TARGET
{
    float uQuality = 1.0 - uEntropy;
    float2 t0 = float2(uTime, 0.0);

    // Random numbers
    float3 rand;
    rand.x = urand(uv + t0.xy);
    rand.y = urand(uv + t0.yx);
    rand.z = urand(uv.yx - t0.xx);

    // Motion vector
    float2 mv = tex2Dlod(s_coflow, float4(uv, 0.0, uDetail)).xy;
    mv *= uScale;

    // Normalized screen space -> Pixel coordinates
    mv = mv * (DSIZE / 2);

    // Small random displacement (diffusion)
    mv += (rand.xy - 0.5)  * uDiffusion;

    // Pixel perfect snapping
    mv = round(mv);

    float4 acc;

    // Accumulates the amount of motion.
    float mv_len = length(mv);
    // - Simple update
    float acc_update = min(mv_len, uBlockSize) * 0.005;
    acc_update += rand.z * lerp(-0.02, 0.02, uQuality);
    // - Reset to random level
    float acc_reset = rand.z * 0.5 + uQuality;

    // - Reset if the amount of motion is larger than the block size.
    if(mv_len > uBlockSize)
    {
        acc.rgb = saturate(acc_reset);
        acc.a = 0.0;
    } else {
        // This should work given law of addition
        acc.rgb = saturate(acc_update);
        acc.a = 1.0;
    }

    return acc;
}

float4 ps_output(float4 vpos : SV_POSITION,
                 float2 uv : TEXCOORD0) : SV_TARGET
{
    const float2 disptexel = 1.0 / (DSIZE.xy / 2.0);
    float uQuality = 1.0 - uEntropy;
    float2 mvec = tex2Dlod(s_coflow, float4(uv, 0.0, uDetail)).xy * disptexel;
    float4 src = tex2D(s_color, uv); // Color from the original image
    float disp = tex2D(s_caccum, uv).r; // Displacement vector
    float4 work = tex2D(s_copy, uv - mvec * 0.98);

    // Generate some pseudo random numbers.
    float mrand = urand(uv + length(mvec));
    float4 rand = frac(float4(1.0, 17.37135, 841.4272, 3305.121) * mrand);

    // Generate noise patterns that look like DCT bases.
    // - Frequency
    float2 uv1 = uv * disptexel * (rand.x * 80.0 / uContrast);
    // - Basis wave (vertical or horizontal)
    float dct = cos(lerp(uv1.x, uv1.y, 0.5 < rand.y));
    // - Random amplitude (the high freq, the less amp)
    dct *= rand.z * (1.0 - rand.x) * uContrast;

    // Conditional weighting
    // - DCT-ish noise: acc > 0.5
    float cw = (disp > 0.5) * dct;
    // - Original image: rand < (Q * 0.8 + 0.2) && acc == 1.0
    cw = lerp(cw, 1.0, rand.w < lerp(0.2, 1.0, uQuality) * (disp > 1.0 - 1e-3));
    // - If the conditions above are not met, choose work.

    return float4(lerp(work.rgb, src.rgb, cw), src.a);
}

float4 ps_copy(float4 vpos : SV_POSITION,
               float2 uv : TEXCOORD0) : SV_Target
{
    return float4(tex2D(s_color, uv).rgb, 1.0);
}

technique KinoDatamosh
{
    pass cNormalize
    {
        VertexShader = vs_generic;
        PixelShader = ps_convert;
        RenderTarget0 = r_pbuffer;
    }

    pass cProcessFrame
    {
        VertexShader = vs_generic;
        PixelShader = ps_filter;
        RenderTarget0 = r_cbuffer;
        RenderTarget1 = r_cuddxy;
    }

    /*
        Smooth optical flow with BlendOps
        How it works:
            Src = Current optical flow
            Dest = Previous optical flow
            SRCALPHA = Blending weight between Src and Dest
            If SRCALPHA = 0.25, the blending would be
            Src * (1.0 - 0.25) + Dest * 0.25
            The previous flow's output gets quartered every frame
        Note:
            Disable ClearRenderTargets to blend with existing
            data in r_cflow before rendering
    */

    pass cOpticalFlow
    {
        VertexShader = vs_generic;
        PixelShader = ps_flow;
        RenderTarget0 = r_coflow;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVSRCALPHA;
        DestBlend = SRCALPHA;
    }

    /*
        I rewrote the last code so the GPU's ROP handles the accumulation:
            saturate(mv_len > _BlockSize ? acc_reset : acc_update);

        Remember...
            Src = PixelShader result
            Dest = Data from pointed RenderTarget
            (Src * SrcBlend) BlendOp (Dest * DestBlend)

        Therefore, pseudocode:
            if(mv_len > _BlockSize)
            {
                // Clear previous result, but output the reset
                (OUTPUT * ONE) + (Previous * ZERO);
            } else {
                // Accumulate if false
                (OUTPUT * ONE) + (Previous * ONE);
            }
    */

    pass cAccumulate
    {
        VertexShader = vs_generic;
        PixelShader = ps_accum;
        RenderTarget0 = r_caccum;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = ONE;
        DestBlend = SRCALPHA; // The result about to accumulate
    }

    pass cOutput
    {
        VertexShader = vs_generic;
        PixelShader = ps_output;
        SRGBWriteEnable = TRUE;
    }

    pass cBlit
    {
        VertexShader = vs_generic;
        PixelShader = ps_copy;
        RenderTarget = r_copy;
        SRGBWriteEnable = TRUE;
    }
}

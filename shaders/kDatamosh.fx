
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

#define uOption(option, udata, utype, ucategory, ulabel, uvalue, umin, umax, utooltip)  \
        uniform udata option <                                                  		\
        ui_category = ucategory; ui_label = ulabel;                             		\
        ui_type = utype; ui_min = umin; ui_max = umax; ui_tooltip = utooltip;   		\
        > = uvalue

uOption(uBlockSize, int, "slider", "Datamosh", "Block Size", 16, 4, 32,
"Size of compression macroblock.");

uOption(uEntropy, float, "slider", "Datamosh", "Entropy", 0.5, 0.0, 1.0,
"The larger value stronger noise and makes mosh last longer.");

uOption(uContrast, float, "slider", "Datamosh", "Contrast", 1.0, 0.5, 4.0,
"Contrast of stripe-shaped noise.");

uOption(uScale, float, "slider", "Datamosh", "Scale", 0.8, 0.0, 2.0,
"Scale factor for velocity vectors.");

uOption(uDiffusion, float, "slider", "Datamosh", "Diffusion", 0.4, 0.0, 2.0,
"Amount of random displacement.");

uOption(uDetail, float, "slider", "Datamosh", "Blockiness", 2.0, 0.0, FSIZE - 1,
"How blocky the motion vectors should be.");

uOption(uConst, float, "slider", "Optical Flow", "Constraint", 1.000, 0.000, 2.000,
"Regularization: Higher = Smoother flow");

uOption(uBlend, float, "slider", "Optical Flow", "Temporal Smoothing", 0.5, 0.0, 1.0,
"Temporal Smoothing: Higher = Less temporal noise");

#ifndef LINEAR_SAMPLING
    #define LINEAR_SAMPLING 0
#endif

#if LINEAR_SAMPLING == 1
    #define MFILTER MinFilter = LINEAR; MagFilter = LINEAR
#else
    #define MFILTER MinFilter = POINT; MagFilter = POINT
#endif

texture2D r_color  : COLOR;
texture2D r_pbuffer { Width = DSIZE.x; Height = DSIZE.y; Format = RGBA16; MipLevels = RSIZE; };
texture2D r_cbuffer { Width = DSIZE.x; Height = DSIZE.y; Format = RG16; MipLevels = RSIZE; };
texture2D r_cuddxy  { Width = DSIZE.x; Height = DSIZE.y; Format = RG16F; MipLevels = RSIZE; };
texture2D r_coflow  { Width = DSIZE.x / 2; Height = DSIZE.y / 2; Format = RG16F; MipLevels = FSIZE; };
texture2D r_caccum  { Width = DSIZE.x / 2; Height = DSIZE.y / 2; Format = R16F;  MipLevels = FSIZE; };
texture2D r_copy    { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };

sampler2D s_color   { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_pbuffer { Texture = r_pbuffer; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cbuffer { Texture = r_cbuffer; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cuddxy  { Texture = r_cuddxy;  AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_coflow  { Texture = r_coflow; MFILTER; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_caccum  { Texture = r_caccum; MFILTER; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_copy    { Texture = r_copy;  SRGBTexture = TRUE; };

/* [Vertex Shaders] */

void vs_generic(in uint id : SV_VERTEXID,
                inout float2 uv : TEXCOORD0,
                inout float4 vpos : SV_POSITION)
{
    uv.x = (id == 2) ? 2.0 : 0.0;
    uv.y = (id == 1) ? 2.0 : 0.0;
    vpos = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [Pixel Shaders ] */

void ps_convert(float4 vpos : SV_POSITION,
                float2 uv : TEXCOORD0,
                out float4 r0 : SV_TARGET0)
{
    // r0.xy = copy blurred frame from last run
    // r0.zw = blur current frame, than blur + copy at ps_filter
    // r1 = get derivatives from previous frame
    float3 uImage = tex2D(s_color, uv.xy).rgb;
    float3 output = uImage.rgb / dot(uImage.rgb , 1.0);
    r0.xy = tex2D(s_cbuffer, uv).xy;
    r0.zw = output.rg / max(max(output.r, output.g), output.b);
}

void ps_filter(float4 vpos : SV_POSITION,
               float2 uv : TEXCOORD0,
               out float4 r0 : SV_TARGET0,
               out float4 r1 : SV_TARGET1)
{
    float4 uImage = tex2D(s_pbuffer, uv);
    r0 = uImage.zw;
    float2 cGrad;
    float2 pGrad;
    cGrad.x = dot(ddx(uImage.zw), 1.0);
    cGrad.y = dot(ddy(uImage.zw), 1.0);
    pGrad.x = dot(ddx(uImage.xy), 1.0);
    pGrad.y = dot(ddy(uImage.xy), 1.0);
    r1 = cGrad + pGrad;
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
    const float pyramids = log2(max(DSIZE.x, DSIZE.y));
    float2 cFlow = 0.0;

    for(float i = pyramids - 0.5; i >= 0; i--)
    {
        float4 ucalc = float4(uv, 0.0, i);
        float2 cFrame = tex2Dlod(s_cbuffer, ucalc).xy;
        float2 pFrame = tex2Dlod(s_pbuffer, ucalc).xy;

        float2 ddxy = tex2Dlod(s_cuddxy, ucalc).xy;
        float dt = dot(cFrame - pFrame, 1.0);
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

uniform float uTime < source = "timer"; >;

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

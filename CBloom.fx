
/*
    CBloom, by copingMechanism with good help from CeeJayDK! :)
    - Mix of ThinMatrix's traditional progressive downscaling with mipmap levels
    - Blur optimized for bilinear filtering

    Why MipMap?
    - Mipmaps progressively downsample the texture - more blurry and accurate than direct downscaling
    - Mipmaps also reduces aliasing at the expense of memory and a little more CPU
    Passes:
    1. Threshold pass -> downscale to 1/2 resolution texture (tBlurA). No mipmaps because 1/2 resolution samples 4 pixels
    2. Horizontally blur tBlurA to tBlurB
    3. Vertically blur tBlurB -> make 3 mipmap levels (1/4-1/6-1/8) -> use 4th level to downscale to 1/8 resolution texture (tBlurC)
    4. Horizontally blur tBlurC to tBlurD
    5. Vertically blur tBlurD and do a BlendOp to the source buffer
*/

#include "ReShade.fxh"

texture tBlurA < pooled = true; > { Width = BUFFER_WIDTH/2.0; Height = BUFFER_HEIGHT/2.0; Format = RGB10A2; };
texture tBlurB < pooled = true; > { Width = BUFFER_WIDTH/2.0; Height = BUFFER_HEIGHT/2.0; Format = RGB10A2; MipLevels = 4; };
texture tBlurC < pooled = true; > { Width = BUFFER_WIDTH/8.0; Height = BUFFER_HEIGHT/8.0; Format = RGB10A2; };
texture tBlurD < pooled = true; > { Width = BUFFER_WIDTH/8.0; Height = BUFFER_HEIGHT/8.0; Format = RGB10A2; };

// NOTE: Process display-referred images into linear light, no matter the shader
sampler sLinear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };
sampler sBlurA { Texture = tBlurA; };
sampler sBlurB { Texture = tBlurB; };
sampler sBlurC { Texture = tBlurC; };
sampler sBlurD { Texture = tBlurD; };

struct vs_out { float4 vpos : SV_POSITION; float2 uv : TEXCOORD; };

/* [ Seperated Blur :: https://www.shadertoy.com/view/ltBcDm :: Bilinear Adaption by CeeJayDK] */

static const float samples = 16.0;
#define sigma sqrt(samples)

float gaussian(float x) { return exp(-(x*x) / (2.0*sigma*sigma)); } // Simple(r) gaussian hill curve - start with horizontal (x), turn direction 180 degrees

float3 blur(sampler src,  float2 uv, float2 ps, bool horizontal)
{
    // Initialize 3 starters that will accumilate overtime, then divided
    float3 color;
    float accum;
    float weight;

    const float iter = samples * 0.5; // We're halving the amount of samples we got to loop

    /*  Why 0.5 offset? Sample on the center of each pixel, then account for the adjacent directions:
        110   011   [121]   000   000   [121]
        110 + 011 = [121] + 110 + 011 = [242]
        000   000   [000]   110   011   [121]
                      ^ Pass 1 Accum      ^ Pass 2 Accum
    */

    [loop] for (float i = -iter + 0.5; i <= iter; i+=2.0)
    {
        float2 direction;

        if (horizontal)
            direction = float2(i, 0.0);
        else
            direction = float2(0.0, i);

        weight = gaussian(length(direction));
        color.rgb += tex2D(src, direction * ps + uv).rgb * weight;
        accum += weight;
    }

    return color.rgb /= accum;
}

/* [ Pixel Shaders -> Techniques ] */

float max3(float3 i) { return max(max(i.r, i.g), i.b); }
float3 PS_Light0(vs_out op) : SV_Target { float3 c = tex2D(sLinear, op.uv).rgb; return (c - 0.666) * lerp(c, dot(c, max3(c)), c) * c; }
float3 PS_BlurH1(vs_out op) : SV_Target { return blur(sBlurA, op.uv, ReShade::PixelSize * 4.0, true); }
float3 PS_BlurV1(vs_out op) : SV_Target { return blur(sBlurB, op.uv, ReShade::PixelSize * 4.0, false); }
float3 PS_BlurH2(vs_out op) : SV_Target { return blur(sBlurC, op.uv, ReShade::PixelSize * 16.0, true); }
float3 PS_BlurV2(vs_out op) : SV_Target { return blur(sBlurD, op.uv, ReShade::PixelSize * 16.0, false); }

technique cBloom < ui_label = "Bloom"; >
{
    pass { VertexShader = PostProcessVS; PixelShader = PS_Light0; RenderTarget = tBlurA; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_BlurH1; RenderTarget = tBlurB; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_BlurV1; RenderTarget = tBlurC; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_BlurH2; RenderTarget = tBlurD; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_BlurV2; SRGBWriteEnable = true; BlendEnable = true; DestBlend = INVSRCColor; }
}

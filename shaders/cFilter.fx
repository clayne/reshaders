/*
    Better texture fltering from Inigo:
    [https://www.iquilezles.org/www/articles/texture/texture.htm]
*/

uniform int kLod <
    ui_type = "drag";
    ui_label = "Level of Detail";
    ui_min = 0;
> = 0;

texture2D r_color : COLOR;
sampler2D s_color { Texture = r_color; };

texture2D r_image { Width = BUFFER_WIDTH / 2.0; Height = BUFFER_HEIGHT / 2.0; MipLevels = 11; };
sampler2D s_image
{
    Texture = r_image;
    #if BUFFER_COLOR_BIT_DEPTH != 10
        SRGBTexture = true;
    #endif
};

struct v2f
{
    float4 vpos : SV_POSITION;
    float2 uv : TEXCOORD0;
};

v2f vs_basic(const uint id : SV_VertexID)
{
    v2f output;
    output.uv.x = (id == 2) ? 2.0 : 0.0;
    output.uv.y = (id == 1) ? 2.0 : 0.0;
    output.vpos = float4(output.uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    return output;
}

// Generate mipmaps
float4 ps_image(v2f input) : SV_Target0
{
    return tex2D(s_color, input.uv);
}

float4 ps_output(v2f input): SV_Target0
{
    float2 kResolution = tex2Dsize(s_image, kLod);
    float2 kP = input.uv * kResolution + 0.5;
    float2 kI = floor(kP);
    float2 kF = kP - kI;
    kF = kF * kF * kF * (kF * (kF * 6.0 - 15.0) + 10.0);
    kP = kI + kF;
    kP = (kP - 0.5) / kResolution;
    return tex2Dlod(s_image, float4(kP, 0.0, kLod));
}

technique Filtering
{
    pass
    {
        VertexShader = vs_basic;
        PixelShader = ps_image;
        RenderTarget = r_image;
    }

    pass
    {
        VertexShader = vs_basic;
        PixelShader = ps_output;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
    }
}

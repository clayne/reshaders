
/*
    FilmGrain without texture fetches

    "Well ill believe it when i see it."
    Yoinked code by Luluco250 (RIP) [https://www.shadertoy.com/view/4t2fRz] [MIT]
*/

uniform float _Speed <
    ui_label = "Speed";
    ui_type = "drag";
> = 2.0f;

uniform float _Variance <
    ui_label = "Variance";
    ui_type = "drag";
> = 0.5f;

uniform float _Intensity <
    ui_label = "Variance";
    ui_type = "drag";
> = 0.005f;

uniform float _Time < source = "timer"; >;

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

float GaussianWeight(float x, float Sigma)
{
    const float Pi = 3.14159265359;
    Sigma = Sigma * Sigma;
    return rsqrt(Pi * Sigma) * exp(-((x * x) / (2.0 * Sigma)));
}

float4 VignettePS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0) : SV_Target
{
    float Time = rcp(1e+3 / _Time) * _Speed;
    float Seed = dot(Position.xy, float2(12.9898, 78.233));
    float Noise = frac(sin(Seed) * 43758.5453 + Time);
    return GaussianWeight(Noise, _Variance) * _Intensity;
}

technique cFilmGrain
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = VignettePS;
        // (Shader[Src] * SrcBlend) + (Buffer[Dest] * DestBlend)
        // This shader: (Shader[Src] * (1.0 - Buffer[Dest])) + Buffer[Dest]
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVDESTCOLOR;
        DestBlend = ONE;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}

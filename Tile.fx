
// Tile Effect by itsmattkc (Olive 0.1.X)

#include "ReShade.fxh"

uniform float scale <
    ui_label = "Scale";
    ui_type = "drag";
    ui_step = 0.1;
> = 100.0;

uniform float centerx <
    ui_label = "Center X";
    ui_type = "drag";
    ui_step = 0.001;
> = 0.0;

uniform float centery <
    ui_label = "Center Y";
    ui_type = "drag";
    ui_step = 0.001;
> = 0.0;

uniform bool mirrorx <
    ui_label = "Mirror X";
> = true;

uniform bool mirrory <
    ui_label = "Mirror Y";
> = true;

sampler tex0 { Texture = ReShade::BackBufferTex; SRGBTexture = true; };

// glsl style mod
#define mod(x, y) (x - y * floor(x / y))

float4 PS_Tile(float4 v : SV_POSITION, in float2 uv : TEXCOORD) : SV_Target
{
    float adj_scale = scale * 0.01;
    float2 coord = (uv/adj_scale - 0.5/adj_scale) + float2(-centerx, -centery) + 0.5;
    float2 modcoord = mod(coord, 1.0);

    if (mirrorx && mod(coord.x, 2.0) > 1.0) { modcoord.x = 1.0 - modcoord.x; }
    if (mirrory && mod(coord.y, 2.0) > 1.0) { modcoord.y = 1.0 - modcoord.y; }

    return tex2D(tex0, modcoord);
}

technique Tile
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Tile;
        SRGBWriteEnable = true;
    }
}


/*
	Tile Effect by itsmattkc (Olive 0.1.X)
*/

#include "ReShade.fxh"

uniform float scale <
    ui_label = "Scale";
    ui_type = "slider";
    ui_min = 10.0; ui_max = 1000.0;
> = 1.0;

uniform float centerx <
    ui_label = "Center X";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.0;

uniform float centery <
    ui_label = "Center Y";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.0;

uniform bool mirrorx <
    ui_label = "Mirror X";
> = true;

uniform bool mirrory <
    ui_label = "Mirror Y";
> = true;

sampler tex0 { Texture = ReShade::BackBufferTex; SRGBTexture = true; };

struct vs_out { float4 vpos : SV_POSITION; float2 uv : TEXCOORD; };

// glsl style mod
#define mod(x, y) (x - y * floor(x / y))

float4 PS_Tile(vs_out i) : SV_Target
{
	float adj_scale = scale * 0.01;

	float2 scaled_coords = (i.uv/adj_scale);
	float2 coord = scaled_coords
                   - float2(0.5/adj_scale, 0.5/adj_scale)
				   + float2(0.5, 0.5)
                   + float2(-centerx, -centery);
	float2 modcoord = mod(coord, 1.0);

	if (mirrorx && mod(coord.x, 2.0) > 1.0) { modcoord.x = 1.0 - modcoord.x; }
	if (mirrory && mod(coord.y, 2.0) > 1.0) { modcoord.y = 1.0 - modcoord.y; }

	return tex2D(tex0, modcoord);
}

technique Tile {
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Tile;
        SRGBWriteEnable = true;
    }
}

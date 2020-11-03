#include "ReShade.fxh"

sampler s_Linear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };

struct vs_in
{
	uint id : SV_VertexID;
    float4 vpos : SV_POSITION;
	float2 uv : TEXCOORD0;
};

void pChecker(vs_in input, out float2 c : SV_Target0)
{
    float scale = 0.25;
    float2 positionMod = float2(uint2(input.vpos.xy) & 1);
    c =
	( -scale + 2.0 * scale * positionMod.x ) *
	( -1.0 + 2.0 * positionMod.y );
}

technique CheckerBoard
{
	pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_CatmullRom;
        SRGBWriteEnable = true;
    }
}


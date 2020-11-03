
#include "ReShade.fxh"

uniform int A_DITHER_TYPE <
    ui_label = "DitherType";
    ui_type = "combo";
    ui_min = 0; ui_max = 1;
> = 1;

uniform int B_DITHER_SHOW <
    ui_label = "ShowMethod";
    ui_type = "combo";
    ui_min = 0; ui_max = 1;
> = 1;

uniform float2 BorderWidth <
    ui_label = "Border Width";
    ui_min = 0.0; ui_max = 1024.0;
    ui_step = 1.0;
> = float2(2.0, 2.0);

uniform float3 BorderColor <
    ui_label = "Border Color";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.01;
> = float3(0.0, 0.0, 0.0);

uniform float SHARPNESS <
    ui_label = "AA Shader 4.0 Sharpness Control";
    ui_min = 1.0; ui_max = 10.0;
    ui_step = 0.5;
> = 2.0;

struct vs_in
{
	uint id : SV_VertexID;
	float4 vpos : SV_POSITION;
	float2 uv : TEXCOORD0;
};

void AA4(vs_in input, out float4 c : SV_Target0)
{
	const float3 dt = float3(1.0, 1.0, 1.0);

	// Calculating texel coordinates
	float2 size     = SHARPNESS * BUFFER_SCREEN_SIZE;
	float2 inv_size = BUFFER_PIXEL_SIZE;

	float4 yx = float4(inv_size, -inv_size);
	
	float2 OGL2Pos = input.uv * size;

	float2 fp = frac(OGL2Pos);
	float2 dx = float2(inv_size.x, 0.0);
	float2 dy = float2(0.0, inv_size.y);
	float2 g1 = float2( inv_size.x, inv_size.y);
	float2 g2 = float2(-inv_size.x, inv_size.y);
	
	float2 pC4 = floor(OGL2Pos) * inv_size + 0.5 * inv_size;	
	
	// Reading the texels
	float3 C0 = tex2D(pC4 - g1, yx); 
	float3 C1 = tex2D(pC4 - dy, yx);
	float3 C2 = tex2D(pC4 - g2, yx);
	float3 C3 = tex2D(pC4 - dx, yx);
	float3 C4 = tex2D(pC4     , yx);
	float3 C5 = tex2D(pC4 + dx, yx);
	float3 C6 = tex2D(pC4 + g2, yx);
	float3 C7 = tex2D(pC4 + dy, yx);
	float3 C8 = tex2D(pC4 + g1, yx);
	
	float3 ul, ur, dl, dr;
	float m1, m2;
	
	m1 = dot(abs(C0-C4),dt) + 0.001;
	m2 = dot(abs(C1-C3),dt) + 0.001;
	ul = (m2*(C0+C4)+m1*(C1+C3)) / (m1+m2);  
	
	m1 = dot(abs(C1-C5),dt) + 0.001;
	m2 = dot(abs(C2-C4),dt) + 0.001;
	ur = (m2*(C1+C5)+m1*(C2+C4)) / (m1+m2);
	
	m1 = dot(abs(C3-C7),dt) + 0.001;
	m2 = dot(abs(C6-C4),dt) + 0.001;
	dl = (m2*(C3+C7)+m1*(C6+C4)) / (m1+m2);
	
	m1 = dot(abs(C4-C8),dt) + 0.001;
	m2 = dot(abs(C5-C7),dt) + 0.001;
	dr = (m2*(C4+C8)+m1*(C5+C7)) / (m1+m2);
	
	float3 c11 = 0.5 * ((dr*fp.x+dl*(1.0-fp.x))
                     * fp.y+(ur*fp.x+ul
                     * (1.0-fp.x))*(1.0-fp.y));

	c = float4(c11, 1.0);
}

technique DreamScape
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = AA4;
        RenderTarget0 = t_AA4;
    }
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = DitherPass;
        RenderTarget0 = t_DitherPass;
    }
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BorderPass;
        RenderTarget0 = t_BorderPass;
    }
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = DS1;
        RenderTarget0 = t_DS1;
    }
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = DS2;
        RenderTarget0 = t_DS2;
    }
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = DS3;
        RenderTarget0 = t_DS3;
    }
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = t_DS4;
    }
}
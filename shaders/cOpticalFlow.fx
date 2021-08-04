
/*
    Horn and Schunck optical flow without iterations
    http://www.cs.cmu.edu/~16385/s17/Slides/14.3_OF__HornSchunck.pdf
*/

#define size float2(BUFFER_WIDTH, BUFFER_HEIGHT)

texture2D r_color : COLOR;
texture2D r_current_  	  { Width = size.x / 2.0; Height = size.y / 2.0; Format = R8; };
texture2D r_previous_ 	  { Width = size.x / 2.0; Height = size.y / 2.0; Format = R8; };
texture2D r_currentflow_  { Width = size.x / 2.0; Height = size.y / 2.0; Format = RG32F; };
texture2D r_previousflow_ { Width = size.x / 2.0; Height = size.y / 2.0; Format = RG32F; };

sampler2D s_color    	  { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_current_  	  { Texture = r_current_; };
sampler2D s_previous_ 	  { Texture = r_previous_; };
sampler2D s_currentflow_  { Texture = r_currentflow_; };
sampler2D s_previousflow_ { Texture = r_previousflow_; };

/* [Vertex Shaders] */

void v2f_core(  in uint id,
                inout float2 uv,
                inout float4 vpos)
{
    uv.x = (id == 2) ? 2.0 : 0.0;
    uv.y = (id == 1) ? 2.0 : 0.0;
    vpos = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

void vs_common( in uint id : SV_VERTEXID,
                inout float4 vpos : SV_POSITION,
                inout float2 uv : TEXCOORD0)
{
    v2f_core(id, uv, vpos);
}

/* [Pixel Shaders] */

float Max3(float a, float b, float c)
{
    return max(max(a, b), c);
}

float4 ps_image(float4 vpos : SV_POSITION, float2 uv: TEXCOORD0) : SV_TARGET
{
	float3 uImage = tex2D(s_color, uv).rgb;
	float luma = Max3(uImage.r, uImage.g, uImage.b);
    return luma / dot(uImage, 1.0);
}

float4 ps_hsflow(   float4 vpos : SV_POSITION,
                    float2 uv : TEXCOORD0) : SV_TARGET
{
    float pframe = tex2D(s_previous_, uv).r;
    float cframe = tex2D(s_current_, uv).r;

    float3 dFd;
    dFd.x = ddx(cframe);
    dFd.y = ddy(cframe);
    dFd.z = cframe - pframe;

    float dConst = dot(dFd.xy, dFd.xy) + 1e-7;
    float2 cFlow = -(dFd.zz * dFd.xy) / dConst;

    return float4(cFlow, 1.0, 1.0);
}

float4 ps_hsblend(  float4 vpos : SV_POSITION,
                    float2 uv : TEXCOORD0) : SV_TARGET
{
	float2 cflow = tex2D(s_currentflow_, uv).xy;
	float2 pflow = tex2D(s_previousflow_, uv).xy;
	float2 blend = lerp(cflow, pflow, 0.25);
    return float4(blend, 1.0, 1.0);
}

void ps_previous(   float4 vpos : SV_POSITION,
					float2 uv: TEXCOORD0,
					out float4 render0 : SV_TARGET0,
					out float4 render1 : SV_TARGET1)
{
    render0 = tex2D(s_current_, uv);
    render1 = tex2D(s_currentflow_, uv);
}

technique cOpticalFlow
{
    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_image;
        RenderTarget = r_current_;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_hsflow;
        RenderTarget = r_currentflow_;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_hsblend;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_previous;
        RenderTarget0 = r_previous_;
        RenderTarget1 = r_previousflow_;
    }
}


/*
    Horn and Schunck optical flow without iterations
    http://www.cs.cmu.edu/~16385/s17/Slides/14.3_OF__HornSchunck.pdf
*/

#define size float2(BUFFER_WIDTH, BUFFER_HEIGHT)

texture2D r_color  : COLOR;
texture2D r_current  { Width = size.x; Height = size.y; Format = RGB10A2; };
texture2D r_previous { Width = size.x; Height = size.y; Format = RGB10A2; };

sampler2D s_color    { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_current  { Texture = r_current; };
sampler2D s_previous { Texture = r_previous; };

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

void vs_flow(   in uint id : SV_VERTEXID,
                inout float4 vpos : SV_POSITION,
                inout float4 uddx : TEXCOORD0,
                inout float4 uddy : TEXCOORD1)
{
    float2 uv;
    const float2 psize = rcp(size);
    v2f_core(id, uv, vpos);
    uddx = uv.xxxy + float4(-1.0, 1.0, 0.0, 0.0) * psize.xxxy;
    uddy = uv.yyxx + float4(-1.0, 1.0, 0.0, 0.0) * psize.yyxx;
}

/* [Pixel Shaders] */

float4 ps_image(float4 vpos : SV_POSITION, float2 uv: TEXCOORD0) : SV_TARGET
{
    return float4(normalize(tex2D(s_color, uv).rgb), 1.0);
}


float4 ps_hsflow(   float4 vpos : SV_POSITION,
                    float4 uddx : TEXCOORD0,
                    float4 uddy : TEXCOORD1) : SV_TARGET
{
    // Calculate optical flow
    float3 cframe = tex2D(s_current, uddx.zw).rgb; // [0, 0]
    float3 pframe = tex2D(s_previous, uddx.zw).rgb; // [0, 0]

    float3 dFdcx;
    dFdcx  = tex2D(s_current, uddx.yw).rgb; // [ 1, 0]
    dFdcx -= tex2D(s_current, uddx.xw).rgb; // [-1, 0]

    float3 dFdcy;
    dFdcy  = tex2D(s_current, uddy.zy).rgb; // [ 0, 1]
    dFdcy -= tex2D(s_current, uddy.zx).rgb; // [ 0,-1]

    float3 dFdpx;
    dFdpx  = tex2D(s_previous, uddx.yw).rgb; // [ 1, 0]
    dFdpx -= tex2D(s_previous, uddx.xw).rgb; // [-1, 0]

    float3 dFdpy;
    dFdpy  = tex2D(s_previous, uddy.zy).rgb; // [ 0, 1]
    dFdpy -= tex2D(s_previous, uddy.zx).rgb; // [ 0,-1]

    float2 dFdc;
    dFdc.x = dot(dFdcx, 1.0);
    dFdc.y = dot(dFdcy, 1.0);

    float2 dFdp;
    dFdp.x = dot(dFdpx, 1.0);
    dFdp.y = dot(dFdpy, 1.0);

    float3 dt = cframe - pframe;
    float dBrightness = dot(dFdp, dFdc) + dot(dt, 1.0);
    float dSmoothness = dot(dFdp, dFdp) + 1e-7;
    float2 cFlow = dFdc - (dFdp * dBrightness) / dSmoothness;
    return float4(cFlow, 0.0, 0.0);
}

float4 ps_previous(float4 vpos : SV_POSITION, float2 uv: TEXCOORD0) : SV_TARGET
{
    return tex2D(s_current, uv);
}

technique cOpticalFlow
{
    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_image;
        RenderTarget = r_current;
    }

    pass
    {
        VertexShader = vs_flow;
        PixelShader = ps_hsflow;
        SRGBWriteEnable = TRUE;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_previous;
        RenderTarget = r_previous;
    }
}


#include "ReShade.fxh"

uniform int Blur_Amount <
    ui_type = "drag";
    ui_min = 0; ui_max = 32;
    ui_label = "Blur Amount";
    ui_tooltip = "Blur Step Ammount";
    ui_category = "Motion Blur";
> = 32;

uniform int Debug <
    ui_type = "combo";
    ui_items = "Off\0Depth\0Direction\0";
    ui_label = "Debug View";
    ui_tooltip = "View Debug Buffers.";
    ui_category = "Debug Buffer";
> = 0;

texture2D t_LOD    { Width = BUFFER_WIDTH/2; Height = BUFFER_HEIGHT/2; Format = RGB10A2; };
texture2D t_cFrame { Width = BUFFER_WIDTH/2; Height = BUFFER_HEIGHT/2; Format = R32F; MipLevels = 4; };
texture2D t_pFrame { Width = BUFFER_WIDTH/2; Height = BUFFER_HEIGHT/2; Format = R32F; };
texture2D t_mInfo  { Width = BUFFER_WIDTH/2; Height = BUFFER_HEIGHT/2; Format = RGBA16F; };

sampler2D s_Linear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };
sampler2D s_LOD    { Texture = t_LOD; };
sampler2D s_cFrame { Texture = t_cFrame; };
sampler2D s_pFrame { Texture = t_pFrame; };
sampler2D s_mInfo  { Texture = t_mInfo; };

struct vs_in
{
    uint id : SV_VertexID;
    float4 vpos : SV_POSITION;
    float2 uv : TEXCOORD0;
};

/* [ Pixel Shaders ] */

float ds(float2 uv) { return tex2Dlod(s_cFrame, float4(uv, 0.0, 4.0)).x; }

void pLOD(vs_in input, out float3 c : SV_Target0, out float3 p : SV_Target1)
{
    const float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
    float xy_magic = dot(input.vpos.xy, magic.xy);
    float2 r = frac(magic.z * frac(xy_magic));
    r.x*=6.28305308;

    // uniform sample the circle
    float2 cr = float2(sin(r.x),cos(r.x))*sqrt(r.y);

    c = tex2D(s_Linear, input.uv + cr * (32.0/BUFFER_SCREEN_SIZE)).rgb;
    p = ds(input.uv);
}

void pCFrame(vs_in input, out float c : SV_Target0)
{
    float3 col = tex2Dlod(s_LOD, float4(input.uv, 0.0, 4.0)).rgb;
    c = length(col);
}

/*
    Algorithm from [https://github.com/mattatz/unity-optical-flow] [MIT License]
    Optimization from [https://www.shadertoy.com/view/3l2Gz1]
*/

float4 mFlow(vs_in input, float prev, float curr)
{
    const float _Scale = 16.0;
    const float _Lambda = 1.0;
    const float _Threshold = 0.002;

    float currddx = ddx(curr);
    float currddy = ddy(curr);
    float prevddx = ddx(prev);
    float prevddy = ddy(prev);

    float dt = curr - prev; // dt
    float dx = currddx + prevddx; // dx_curr + dx_prev
    float dy = currddy + prevddy; // dy_curr + dy_prev

    float gmag = sqrt(dx * dx + dy * dy + _Lambda);
    float invGmag = rcp(gmag);
    float3 vx = dt * (dx * invGmag);
    float3 vy = dt * (dy * invGmag);

    float2 flow = 0.0;
    const float inv3 = rcp(3.0);
    flow.x = -(vx.x + vx.y + vx.z) * inv3;
    flow.y = -(vy.x + vy.y + vy.z) * inv3;

    float w = length(flow);
    float nw = (w - _Threshold) / (1.0 - _Threshold);
    flow = lerp(float2(0.0, 0.0), normalize(flow) * nw * _Scale, step(_Threshold, w));
    return float4(flow, 0.0, 1.0);
}

void pMFlow(vs_in input, out float4 c : SV_Target0)
{
    float Current = ds(input.uv);
    float Past = tex2D(s_pFrame, input.uv).x;
    c = float4(mFlow(input, Past, Current).xy, 0.0, 1.0);
}

void pFlowBlur(vs_in input, out float3 c : SV_Target0)
{
    float weight = 1.0, blursamples = Blur_Amount;
    // Direction of blur and assumption that blur should be stronger near the cam.
    float2 uvoffsets = tex2Dlod(s_mInfo, float4(input.uv, 0.0, 0.0)).xy;
    // Apply motion blur
    float3 sum, accumulation, weightsum;

    [loop]
    for (float i = -blursamples; i <= blursamples; i++)
    {
      float3 currsample = tex2Dlod(s_Linear, float4(input.uv + (i * uvoffsets) * (BUFFER_PIXEL_SIZE * 2.0), 0, 0)).rgb;
      accumulation += currsample * weight;
      weightsum += weight;
    }

    if(Debug == 0)
      c = accumulation / weightsum;
    else if(Debug == 1)
      c = ds(input.uv).x;
    else
      c = float3(mad(uvoffsets, 0.5, 0.5), 0.0);
}

technique cMotionBlur < ui_tooltip = "Color-Based Motion Blur"; >
{

    pass LOD
    {
        VertexShader = PostProcessVS;
        PixelShader = pLOD;
        RenderTarget0 = t_LOD;
        RenderTarget1 = t_pFrame;
    }

    pass CopyFrame
    {
        VertexShader = PostProcessVS;
        PixelShader = pCFrame;
        RenderTarget0 = t_cFrame;
    }

    pass Flow
    {
        VertexShader = PostProcessVS;
        PixelShader = pMFlow;
        RenderTarget0 = t_mInfo;
    }

    pass MotionBlur
    {
        VertexShader = PostProcessVS;
        PixelShader = pFlowBlur;
        SRGBWriteEnable = true;
    }
}

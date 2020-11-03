
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
texture2D t_hBlur  { Width = BUFFER_WIDTH/2; Height = BUFFER_HEIGHT/2; Format = RGB10A2; };
texture2D t_cFrame { Width = BUFFER_WIDTH/2; Height = BUFFER_HEIGHT/2; Format = RGBA32F; MipLevels = 2; };
texture2D t_pFrame { Width = BUFFER_WIDTH/2; Height = BUFFER_HEIGHT/2; Format = RGBA32F; };
texture2D t_mInfo  { Width = BUFFER_WIDTH/2; Height = BUFFER_HEIGHT/2; Format = RGBA16F; };

sampler2D s_Linear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };
sampler2D s_LOD  { Texture = t_LOD; };
sampler2D s_hBlur  { Texture = t_hBlur; };
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

void pLOD(vs_in input, out float3 c : SV_Target0)
{
	const float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
	float xy_magic = dot(input.vpos.xy, magic.xy);
    float2 r = frac(magic.z * frac(xy_magic));
    r.x*=6.28305308;

    // uniform sample the circle
    float2 cr = float2(sin(r.x),cos(r.x))*sqrt(r.y);

    c = tex2D(s_Linear, input.uv + cr * (64.0/BUFFER_SCREEN_SIZE)).rgb;
}

static const int step_count = 13;
static const float weights[step_count] = { 0.07410, 0.09446, 0.08482, 0.07161,
									  	 0.05686, 0.04245, 0.02980, 0.01967,
									  	 0.01221, 0.00713, 0.00391, 0.00202,
									  	 0.00098  };
static const float offsets[step_count] = { 0.66495,  2.49035,  4.48263,  6.47493,
									 	  8.46723,  10.45955, 12.45189, 14.44425,
									  	 16.43664, 18.42906, 20.42151, 22.41399,
									  	 24.40652 };

void pBlurh(vs_in input, out float3 c : SV_Target0)
{
	float3 color;
	for (int i = 0; i < step_count; ++i) {
		const float2 uvo = offsets[i] * float2(BUFFER_PIXEL_SIZE.x * 2.0, 0.0);
		const float3 samples =
		tex2Dlod(s_LOD, float4(input.uv + uvo, 0.0, 0.0)).rgb +
		tex2Dlod(s_LOD, float4(input.uv - uvo, 0.0, 0.0)).rgb ;
		color += weights[i] * samples;
	}
	c = color;
}

void pCFrame(vs_in input, out float3 c : SV_Target0)
{
	float3 color;
	for (int i = 0; i < step_count; ++i) {
		const float2 uvo = offsets[i] * float2(0.0, BUFFER_PIXEL_SIZE.y * 2.0);
		const float3 samples =
		tex2Dlod(s_hBlur, float4(input.uv + uvo, 0.0, 0.0)).rgb +
		tex2Dlod(s_hBlur, float4(input.uv - uvo, 0.0, 0.0)).rgb ;
		color += weights[i] * samples;
	}
	c = color;
}

float3 DS(float2 uv) { return tex2Dlod(s_cFrame, float4(uv, 0.0, 0.0125)).rgb; }
void pPFrame(vs_in input, out float3 prev : SV_Target0) { prev = DS(input.uv).rgb; }

/*
	Algorithm from [https://github.com/mattatz/unity-optical-flow] [MIT License]
	Optimization from [https://www.shadertoy.com/view/3l2Gz1]
*/

float4 mFlow(vs_in input, float3 prev, float3 curr)
{
	const float _Scale = 8.0;
	const float _Lambda = 0.004;
	const float _Threshold = 0.02;

	float3 currddx = ddx(curr);
	float3 currddy = ddy(curr);
	float3 prevddx = ddx(prev);
	float3 prevddy = ddy(prev);

	float3 dt = curr - prev; // dt
	float3 dx = currddx + prevddx; // dx_curr + dx_prev
	float3 dy = currddy + prevddy; // dy_curr + dy_prev

	float3 gmag = sqrt(dx * dx + dy * dy + _Lambda);
	float3 invGmag = rcp(gmag);
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
	float3 Current = DS(input.uv);
	float3 Past = tex2D(s_pFrame, input.uv).rgb;
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
	  c = DS(input.uv).rgb;
	else
	  c = float3(mad(uvoffsets, 0.5, 0.5), 0.0);
}

technique cMotionBlur < ui_tooltip = "Color-Based MotionBlur"; >
{
	pass LOD
	{
		VertexShader = PostProcessVS;
		PixelShader = pLOD;
		RenderTarget = t_LOD;
	}

	pass hBlur
	{
		VertexShader = PostProcessVS;
		PixelShader = pBlurh;
		RenderTarget = t_hBlur;
	}

	pass CopyFrame
	{
		VertexShader = PostProcessVS;
		PixelShader = pCFrame;
		RenderTarget = t_cFrame;
	}
	
	pass Flow
	{
		VertexShader = PostProcessVS;
		PixelShader = pMFlow;
		RenderTarget = t_mInfo;
	}

	pass MotionBlur
	{
		VertexShader = PostProcessVS;
		PixelShader = pFlowBlur;
		SRGBWriteEnable = true;
	}

	pass PrevFrame
	{
		VertexShader = PostProcessVS;
		PixelShader = pPFrame;
		RenderTarget = t_pFrame;
	}
}

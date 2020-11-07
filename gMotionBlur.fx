
#include "ReShade.fxh"

#define ambRecall 0.4     // [0.0:1.0] Increases detection level of relevant smart motion blur
#define ambPrecision 0.0  // [0.0:1.0] Increases relevance level of detected smart motion blur
#define ambSoftness 3.5   // [0.0:10.0] Softness of consequential streaks
#define ambSmartMult 3.5  // [0.0:10.0] Multiplication of relevant smart motion blur
#define ambIntensity 0.07 // [0.0:1.0] Intensity of base motion blur effect
#define ambSmartInt 0.94  // [0.0:1.0] Intensity of smart motion blur effect

texture2D ambCurrBlurTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
texture2D ambPrevBlurTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
texture2D ambPrevTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };

sampler2D s_Linear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };
sampler2D ambCurrBlurColor { Texture = ambCurrBlurTex; };
sampler2D ambPrevBlurColor { Texture = ambPrevBlurTex; };
sampler2D ambPrevColor { Texture = ambPrevTex; };

float4 PS_AMBCombine(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float4 prev = tex2D(ambPrevBlurColor, texcoord);
	float4 curr = tex2D(s_Linear, texcoord);
	float4 currBlur = tex2D(ambCurrBlurColor, texcoord);
	
	float diff = (abs(currBlur.r - prev.r) + abs(currBlur.g - prev.g) + abs(currBlur.b - prev.b)) / 3.0;
	diff = min(max(diff - ambPrecision, 0.0f) * ambSmartMult, ambRecall);

	return lerp(curr, prev, min(ambIntensity + diff * ambSmartInt, 1.0f));
}

void PS_AMBCopyPreviousFrame(float4 vpos : SV_Position, float2 texcoord : TEXCOORD, out float4 prev : SV_Target0)
{
	prev = tex2D(s_Linear, texcoord);
}

void PS_AMBBlur(float4 vpos : SV_Position, float2 texcoord : TEXCOORD, out float4 curr : SV_Target0, out float4 prev : SV_Target1)
{
	

	float4 currVal = tex2D(s_Linear, texcoord);
	float4 prevVal = tex2D(ambPrevColor, texcoord);

	float weight[11] = { 0.082607, 0.040484, 0.038138, 0.034521, 0.030025, 0.025094, 0.020253, 0.015553, 0.011533, 0.008218, 0.005627 };
	currVal *= weight[0];
	prevVal *= weight[0];

	float ratio = -1.0f;

	float pixelBlur = ambSoftness/max(1.0f,1.0f+(-1.0f)*ratio) * (BUFFER_RCP_HEIGHT); 

	[unroll]
	for (int z = 1; z < 11; z++) //set quality level by user
	{
		currVal += tex2D(s_Linear, texcoord + float2(z * pixelBlur, 0.0)) * weight[z];
		currVal += tex2D(s_Linear, texcoord - float2(z * pixelBlur, 0.0)) * weight[z];
		currVal += tex2D(s_Linear, texcoord + float2(0.0, z * pixelBlur)) * weight[z];
		currVal += tex2D(s_Linear, texcoord - float2(0.0, z * pixelBlur)) * weight[z];
		
		prevVal += tex2D(ambPrevColor, texcoord + float2(z * pixelBlur, 0.0)) * weight[z];
		prevVal += tex2D(ambPrevColor, texcoord - float2(z * pixelBlur, 0.0)) * weight[z];
		prevVal += tex2D(ambPrevColor, texcoord + float2(0.0, z * pixelBlur)) * weight[z];
		prevVal += tex2D(ambPrevColor, texcoord - float2(0.0, z * pixelBlur)) * weight[z];
	}

	curr = currVal;
	prev = prevVal;
}

technique AdvancedMotionBlur < ui_tooltip = "Color-Based MotionBlur"; >
{
	pass AMBBlur
	{
		VertexShader = ReShade::VS_PostProcess;
		PixelShader = PS_AMBBlur;
		RenderTarget0 = ambCurrBlurTex;
		RenderTarget1 = ambPrevBlurTex;
	}

	pass AMBCombine
	{
		VertexShader = ReShade::VS_PostProcess;
		PixelShader = PS_AMBCombine;
        SRGBWriteEnable = true;
	}

	pass AMBPrev
	{
		VertexShader = ReShade::VS_PostProcess;
		PixelShader = PS_AMBCopyPreviousFrame;
		RenderTarget0 = ambPrevTex;
	}
}
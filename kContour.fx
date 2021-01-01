/*
	KinoContour - Contour line effect

	Copyright (C) 2015 Keijiro Takahashi

	Permission is hereby granted, free of charge, to any person obtaining a copy of
	this software and associated documentation files (the "Software"), to deal in
	the Software without restriction, including without limitation the rights to
	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
	the Software, and to permit persons to whom the Software is furnished to do so,
	subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
	FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
	COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
	IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#include "ReShade.fxh"

uniform float _Threshold <
	ui_label = "Threshold";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
> = 0.05f;

uniform float _InvRange <
	ui_label = "Inverse Range";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
> = 0.05f;

uniform float _ColorSensitivity <
	ui_label = "Color Sensitivity";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
> = 0.0f;

uniform int _FrontColorChoice <
	ui_category = "Front Color";
	ui_label = "Inverse Range";
	ui_type = "combo";
	ui_items =
	"Custom RGB\0"
	"UV-Based\0";
	ui_min = 0; ui_max = 1;
> = 0;

uniform float4 _FrontColorDefault <
	ui_category = "Front Color";
	ui_label = "Front Color - Custom RGB";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
> = float4(1.0, 1.0, 1.0, 1.0);

uniform int _BackColorChoice <
	ui_category = "Back Color";
	ui_label = "Inverse Range";
	ui_type = "combo";
	ui_items =
	"Custom RGB\0"
	"UV-Based\0";
	ui_min = 0; ui_max = 1;
> = 0;

uniform float4 _BackColorDefault <
	ui_category = "Back Color";
	ui_label = "Back Color - Custom RGB";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
> = float4(0.0, 0.0, 0.0, 0.0);

sampler2D _MainTex
{
	Texture = ReShade::BackBufferTex;
	#if BUFFER_COLOR_BIT_DEPTH != 10
		SRGBTexture = true;
	#endif
};

static const float2 _MainTex_TexelSize = BUFFER_PIXEL_SIZE;

float4 PS_Contour(in float4 vpos : SV_Position, in float2 uv : TEXCOORD) : SV_Target
{
	float4 _FrontColor, _BackColor;

	switch(_FrontColorChoice)
	{
		case 0:
			_FrontColor = _FrontColorDefault;
			break;
		case 1:
			_FrontColor = float4(uv.xyx, 1.0);
			break;
	}

	switch(_BackColorChoice)
	{
		case 0:
			_BackColor = _BackColorDefault;
			break;
		case 1:
			_BackColor = float4(uv.xyx, 1.0);
			break;
	}

	// Source color
	float4 c0 = tex2D(_MainTex, uv);

	// Four sample points of the roberts cross operator
	float2 uv0 = uv;                                   // TL
	float2 uv1 = uv + _MainTex_TexelSize.xy;           // BR
	float2 uv2 = uv + float2(_MainTex_TexelSize.x, 0.0); // TR
	float2 uv3 = uv + float2(0.0, _MainTex_TexelSize.y); // BL

	float edge = 0;

	// Color samples
	float3 c1 = tex2D(_MainTex, uv1).rgb;
	float3 c2 = tex2D(_MainTex, uv2).rgb;
	float3 c3 = tex2D(_MainTex, uv3).rgb;

	// Roberts cross operator
	float3 cg1 = c1 - c0.rgb;
	float3 cg2 = c3 - c2;
	float cg = sqrt(dot(cg1, cg1) + dot(cg2, cg2));

	edge = cg * _ColorSensitivity;

	// Thresholding
	edge = saturate((edge - _Threshold) * _InvRange);
	float3 cb = lerp(c0.rgb, _BackColor.rgb, _BackColor.a);
	float3 co = lerp(cb, _FrontColor.rgb, edge * _FrontColor.a);
	return float4(co, c0.a);
}

technique KinoContour
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_Contour;
		#if BUFFER_COLOR_BIT_DEPTH != 10
			SRGBWriteEnable = true;
		#endif
	}
}

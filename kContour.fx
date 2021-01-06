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

uniform float4 _FrontColor <
	ui_label = "Front Color";
	ui_type = "color";
	ui_min = 0.0; ui_max = 1.0;
> = float4(1.0, 1.0, 1.0, 1.0);

uniform float4 _BackColor <
	ui_label = "Back Color";
	ui_type = "color";
	ui_min = 0.0; ui_max = 1.0;
> = float4(0.0, 0.0, 0.0, 0.0);

sampler2D _MainTex
{
	Texture = ReShade::BackBufferTex;
	#if BUFFER_COLOR_BIT_DEPTH != 10
		SRGBTexture = true;
	#endif
};

struct v2f
{
	float4 vpos : SV_Position;
	float4 uv[2] : TEXCOORD0;
};

v2f vs_contour(in uint id : SV_VertexID)
{
	v2f OUT;
	float2 texcoord;
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	OUT.vpos = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

	float2 ts = BUFFER_PIXEL_SIZE.xy;
	OUT.uv[0].xy = texcoord.xy;
	OUT.uv[0].zw = texcoord.xy + ts.xy;
	OUT.uv[1].xy = texcoord.xy + float2(ts.x, 0.0);
	OUT.uv[1].zw = texcoord.xy + float2(0.0, ts.y);
	return OUT;
}

void ps_contour(v2f input, out float3 c : SV_Target0)
{
	float edge;

	// Color samples
	float3 c0 = tex2D(_MainTex, input.uv[0].xy).rgb;
	float3 c1 = tex2D(_MainTex, input.uv[0].zw).rgb;
	float3 c2 = tex2D(_MainTex, input.uv[1].xy).rgb;
	float3 c3 = tex2D(_MainTex, input.uv[1].zw).rgb;

	// Roberts cross operator
	float3 cg1  = c1 - c0;
		   cg1  = dot(cg1, cg1);
	float3 cg2  = c3 - c2;
		   cg2  = dot(cg2, cg2);
		   cg2 += cg1;
	float cg = cg2 * rsqrt(cg2); // sqrt(cg2)

	edge = cg * _ColorSensitivity;

	// Thresholding
	edge = saturate((edge - _Threshold) * _InvRange);
	float3 cb = lerp(c0, _BackColor.rgb, _BackColor.a);
			c = lerp(cb, _FrontColor.rgb, edge * _FrontColor.a);
}

technique KinoContour
{
	pass
	{
		VertexShader = vs_contour;
		PixelShader  = ps_contour;
		#if BUFFER_COLOR_BIT_DEPTH != 10
			SRGBWriteEnable = true;
		#endif
	}
}

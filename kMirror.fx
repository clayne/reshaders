
/*
	KinoContour - Mirroring and kaleidoscope effect

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

uniform float _Divisor <
	ui_label = "Divisor";
	ui_type = "drag";
> = 0.05f;

uniform float _Offset <
	ui_label = "Offset";
	ui_type = "drag";
> = 0.05f;

uniform float _Roll <
	ui_label = "Roll";
	ui_type = "drag";
> = 0.0f;

uniform bool _SYMMETRY_ON <
	ui_label = "Symmetry?";
> = true;

sampler _MainTex { Texture = ReShade::BackBufferTex; SRGBTexture = true; };

void PS_Mirror(in float4 vpos : SV_Position, in float2 uv : TEXCOORD, out float4 c : SV_Target)
{
	// Convert to the polar coordinate.
	float2 sc = uv - 0.5;
	float phi = atan2(sc.y, sc.x);
	float r = sqrt(dot(sc, sc));

	// Angular repeating.
	phi += _Offset;
	phi = phi - _Divisor * floor(phi / _Divisor);

	if(_SYMMETRY_ON) {
		phi = min(phi, _Divisor - phi);
	}

	phi += _Roll - _Offset;

	// Convert back to the texture coordinate.
	uv = float2(cos(phi), sin(phi)) * r + 0.5;

	// Reflection at the border of the screen.
	uv = max(min(uv, 2.0 - uv), -uv);

	c = tex2D(_MainTex, uv);
}

technique KinoContour
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_Mirror;
		SRGBWriteEnable = true;
	}
}

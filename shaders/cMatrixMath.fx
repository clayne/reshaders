
/*
    Simple matrix transform shader

    BSD 3-Clause License

    Copyright (c) 2022, Paul Dang <brimson.net@gmail.com>
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    1. Redistributions of source code must retain the above copyright notice, this
    list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

    3. Neither the name of the copyright holder nor the names of its
    contributors may be used to endorse or promote products derived from
    this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
    FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
    SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

uniform float _Angle <
    ui_label = "Rotate Angle";
    ui_type = "drag";
> = 0.0;

uniform float2 _Translate <
    ui_label = "Translate";
    ui_type = "drag";
> = 0.0;

uniform float2 _Scale <
    ui_label = "Scale";
    ui_type = "drag";
> = 1.0;

texture2D Render_Color : COLOR;

sampler2D Sample_Color
{
    Texture = Render_Color;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

// Vertex shaders

void Matrix_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    float RotationAngle = radians(_Angle);

    float2x2 RotationMatrix = float2x2
    (
    	cos(RotationAngle), -sin(RotationAngle),
    	sin(RotationAngle), cos(RotationAngle)
    );

    float3x3 TranslationMatrix = float3x3
    (
    	1.0, 0.0, 0.0,
    	0.0, 1.0, 0.0,
    	_Translate.x, _Translate.y, 1.0
    );
    
    float2x2 ScalingMatrix = float2x2
    (
    	_Scale.x, 0.0,
    	0.0, _Scale.y
    );

    // Scale TexCoord from [0,1] to [-1,1]
    TexCoord = TexCoord * 2.0 - 1.0;

    // Do transformations here
	TexCoord = mul(TexCoord, RotationMatrix);
	TexCoord = mul(float3(TexCoord, 1.0), TranslationMatrix).xy;
	TexCoord = mul(TexCoord, ScalingMatrix);

    // Scale TexCoord from [-1,1] to [0,1]
    TexCoord = TexCoord.xy * 0.5 + 0.5;
}

// Pixel shaders

void Matrix_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = tex2D(Sample_Color, TexCoord);
}

technique cMatrixMath
{
    pass
    {
        VertexShader = Matrix_VS;
        PixelShader = Matrix_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}

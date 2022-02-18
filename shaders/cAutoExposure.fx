
/*
    Simple adaptive exposure based on https://github.com/TheRealMJP/BakingLab

    BSD 3-Clause License

    Copyright (c) 2022, Paul Dang
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

uniform float _TimeRate <
    ui_label = "Smoothing";
    ui_type = "drag";
    ui_tooltip = "Exposure time smoothing";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.95;

uniform float _ManualBias <
    ui_label = "Exposure";
    ui_type = "drag";
    ui_tooltip = "Optional manual bias ";
    ui_min = 0.0;
> = 2.0;

texture2D RenderColor : COLOR;

sampler2D SampleColor
{
    Texture = RenderColor;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

texture2D RenderLumaLOD
{
    Width = 256;
    Height = 256;
    MipLevels = 9;
    Format = R16F;
};

sampler2D SampleLumaLOD
{
    Texture = RenderLumaLOD;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

// Vertex shaders

void PostProcessVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

// Pixel shaders

void BlitPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    float4 Color = tex2D(SampleColor, TexCoord);

    // OutputColor.rgb = Output the highest brightness out of red/green/blue component
    // OutputColor.a = Output the weight for temporal blending
    OutputColor0 = float4(max(Color.r, max(Color.g, Color.b)).rrr, _TimeRate);
}

void ExposurePS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    // Average Luma = Average value (1x1) for all of the pixels
    float AverageLuma = tex2Dlod(SampleLumaLOD, float4(TexCoord, 0.0, 8.0)).r;
    float4 Color = tex2D(SampleColor, TexCoord);

    // KeyValue is an exposure compensation curve
    // Source: https://knarkowicz.wordpress.com/2016/01/09/automatic-exposure/
    float KeyValue = 1.03 - (2.0 / (log10(AverageLuma + 1.0) + 2.0));
    float ExposureValue = log2(KeyValue / AverageLuma) + _ManualBias;
    OutputColor0 = Color * exp2(ExposureValue);
}

technique cAutoExposure
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlitPS;
        RenderTarget = RenderLumaLOD;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVSRCALPHA;
        DestBlend = SRCALPHA;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = ExposurePS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}

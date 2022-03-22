
/*
    Simple motion masking shader

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

namespace FrameDifference
{
    uniform float _BlendFactor <
        ui_type = "slider";
        ui_label = "Temporal blending factor";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.5;

    uniform float _MinThreshold <
        ui_type = "slider";
        ui_label = "Min threshold";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.0;

    uniform float _MaxThreshold <
        ui_type = "slider";
        ui_label = "Max threshold";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.5;

    uniform float _DifferenceWeight <
        ui_type = "slider";
        ui_label = "Difference Weight";
        ui_min = 0.0;
        ui_max = 2.0;
    > = 1.0;

    uniform bool _NormalizeInput <
        ui_type = "radio";
        ui_label = "Normalize Input";
    > = false;

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

    texture2D RenderCurrent
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RG8;
    };

    sampler2D SampleCurrent
    {
        Texture = RenderCurrent;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderDifference
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = R8;
    };

    sampler2D SampleDifference
    {
        Texture = RenderDifference;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderPrevious
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RG8;
    };

    sampler2D SamplePrevious
    {
        Texture = RenderPrevious;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    // Vertex shaders

    void PostProcessVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0)
    {
        TexCoord.x = (ID == 2) ? 2.0 : 0.0;
        TexCoord.y = (ID == 1) ? 2.0 : 0.0;
        Position = TexCoord.xyxy * float4(2.0, -2.0, 0.0, 0.0) + float4(-1.0, 1.0, 0.0, 1.0);
    }

    // Pixel shaders

    void BlitPS0(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        float3 Color = max(tex2D(SampleColor, TexCoord).rgb, exp2(-10.0));
        OutputColor0 = (_NormalizeInput) ? saturate(Color.xy / dot(Color, 1.0)) : max(max(Color.r, Color.g), Color.b);
    }

    void DifferencePS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        float Difference = 0.0;

        if(_NormalizeInput)
        {
            float2 Current = tex2D(SampleCurrent, TexCoord).rg;
            float2 Previous = tex2D(SamplePrevious, TexCoord).rg;
            Difference = abs(dot(Current - Previous, 1.0)) * _DifferenceWeight;
        }
        else
        {
            float Current = tex2D(SampleCurrent, TexCoord).r;
            float Previous = tex2D(SamplePrevious, TexCoord).r;
            Difference = abs(Current - Previous) * _DifferenceWeight;
        }

        if (Difference <= _MinThreshold)
        {
            OutputColor0 = 0.0;
        }
        else if (Difference > _MaxThreshold)
        {
            OutputColor0 = 1.0;
        }
        else
        {
            OutputColor0 = Difference;
        }

        OutputColor0.a = _BlendFactor;
    }

    void OutputPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = tex2D(SampleDifference, TexCoord).r;
    }

    void BlitPS1(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = tex2D(SampleCurrent, TexCoord);
    }

    technique cFrameDifference
    {
        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = BlitPS0;
            RenderTarget0 = RenderCurrent;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = DifferencePS;
            RenderTarget0 = RenderDifference;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = INVSRCALPHA;
            DestBlend = SRCALPHA;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = OutputPS;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = BlitPS1;
            RenderTarget0 = RenderPrevious;
        }
    }
}

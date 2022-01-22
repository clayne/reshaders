
/*
    Simple temporal difference shader

    BSD 3-Clause License

    Copyright (c) 2022, brimson
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
    uniform float _Blend <
        ui_type = "slider";
        ui_label = "Blending";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.5;

    uniform float _Weight <
        ui_type = "slider";
        ui_label = "Weight";
        ui_min = 0.0;
        ui_max = 2.0;
    > = 1.0;

    uniform bool _NormalizeInput <
        ui_type = "radio";
        ui_label = "Normalize Input";
    > = false;

    texture2D _RenderColor : COLOR;

    sampler2D _SampleColor
    {
        Texture = _RenderColor;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBTexture = TRUE;
        #endif
    };

    texture2D _RenderCurrent
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RG8;
    };

    sampler2D _SampleCurrent
    {
        Texture = _RenderCurrent;
    };

    texture2D _RenderDifference
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
    };

    sampler2D _SampleDifference
    {
        Texture = _RenderDifference;
    };

    texture2D _RenderPrevious
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RG8;
    };

    sampler2D _SamplePrevious
    {
        Texture = _RenderPrevious;
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
        float3 Color = tex2D(_SampleColor, TexCoord).rgb;
        float3 NColor = saturate(Color / dot(Color, 1.0));
        OutputColor0 = (_NormalizeInput) ? NColor : max(max(Color.r, Color.g), Color.b);
    }

    void DifferencePS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        if(_NormalizeInput)
        {
            float3 Current = tex2D(_SampleCurrent, TexCoord).rgb;
            Current.b = 1.0 - Current.r - Current.g;
            float3 Previous = tex2D(_SamplePrevious, TexCoord).rgb;
            Previous.b = 1.0 - Previous.r - Previous.g;
            OutputColor0.rgb = length(Current - Previous) * _Weight;
        }
        else
        {
            float Current = tex2D(_SampleCurrent, TexCoord).r;
            float Previous = tex2D(_SamplePrevious, TexCoord).r;
            OutputColor0.rgb = (Current - Previous) * _Weight;
        }

        OutputColor0.a = _Blend;
    }

    void OutputPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = tex2D(_SampleDifference, TexCoord).r;
    }

    void BlitPS1(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = tex2D(_SampleCurrent, TexCoord);
    }

    technique cFrameDifference
    {
        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = BlitPS0;
            RenderTarget0 = _RenderCurrent;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = DifferencePS;
            RenderTarget0 = _RenderDifference;
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
            RenderTarget0 = _RenderPrevious;
        }
    }
}

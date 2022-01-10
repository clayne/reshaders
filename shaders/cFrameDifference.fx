
/*
    Simple temporal difference shader

    MIT License

    Copyright (c) 2022 brimson

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
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

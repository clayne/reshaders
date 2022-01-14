
/*
    Pyramidal Horn-Schunck shader v1.0

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

namespace HornSchunck
{
    uniform float _Constraint <
        ui_type = "slider";
        ui_label = "Flow Smooth";
        ui_tooltip = "Higher = Smoother flow";
        ui_min = 0.0;
        ui_max = 2.0;
    > = 1.0;

    uniform float _Blend <
        ui_type = "slider";
        ui_label = "Blending";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.25;

    uniform float _Detail <
        ui_type = "drag";
        ui_label = "Mipmap Bias";
        ui_tooltip = "Higher = Less spatial noise";
    > = 0.0;

    texture2D _RenderColor : COLOR;

    sampler2D _SampleColor
    {
        Texture = _RenderColor;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBTexture = TRUE;
        #endif
    };

    texture2D _RenderCurrentFrame
    {
        Width = BUFFER_WIDTH / 2;
        Height = BUFFER_HEIGHT / 2;
        Format = RG8;
        MipLevels = 8;
    };

    sampler2D _SampleCurrentFrame
    {
        Texture = _RenderCurrentFrame;
    };

    texture2D _RenderDerivatives
    {
        Width = BUFFER_WIDTH / 2;
        Height = BUFFER_HEIGHT / 2;
        Format = RGBA16F;
        MipLevels = 8;
    };

    sampler2D _SampleDerivatives
    {
        Texture = _RenderDerivatives;
    };

    texture2D _RenderOpticalFlow
    {
        Width = BUFFER_WIDTH / 2;
        Height = BUFFER_HEIGHT / 2;
        Format = RG16F;
        MipLevels = 8;
    };

    sampler2D _SampleOpticalFlow
    {
        Texture = _RenderOpticalFlow;
    };

    texture2D _RenderPreviousFrame
    {
        Width = BUFFER_WIDTH / 2;
        Height = BUFFER_HEIGHT / 2;
        Format = RG8;
        MipLevels = 8;
    };

    sampler2D _SamplePreviousFrame
    {
        Texture = _RenderPreviousFrame;
    };

    // Vertex shaders

    void PostProcessVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0)
    {
        TexCoord.x = (ID == 2) ? 2.0 : 0.0;
        TexCoord.y = (ID == 1) ? 2.0 : 0.0;
        Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    }

    void DerivativesVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets : TEXCOORD0)
    {
        const float2 PixelSize = 0.5 / float2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2);
        const float4 PixelOffset = float4(PixelSize, -PixelSize);
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        Offsets = TexCoord0.xyxy + PixelOffset;
    }

    // Pixel shaders

    void NormalizePS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        float3 Color = tex2D(_SampleColor, TexCoord).rgb;
        OutputColor0 = saturate(Color.xy / dot(Color, 1.0));
    }

    void DerivativesPS(in float4 Position : SV_Position, in float4 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        float2 Sample0 = tex2D(_SampleCurrentFrame, TexCoord.zy).xy; // (-x, +y)
        float2 Sample1 = tex2D(_SampleCurrentFrame, TexCoord.xy).xy; // (+x, +y)
        float2 Sample2 = tex2D(_SampleCurrentFrame, TexCoord.zw).xy; // (-x, -y)
        float2 Sample3 = tex2D(_SampleCurrentFrame, TexCoord.xw).xy; // (+x, -y)
        OutputColor0.xz = (Sample3 + Sample1) - (Sample2 + Sample0);
        OutputColor0.yw = (Sample2 + Sample3) - (Sample0 + Sample1);
        OutputColor0 *= 4.0;
    }

    /*
        Horn Schunck
            http://6.869.csail.mit.edu/fa12/lectures/lecture16/MotionEstimation1.pdf
            - Use Gauss-Seidel from slide 52
            - Use additional constraint (normalized RG)

        Pyramid
            https://www.cs.auckland.ac.nz/~rklette/CCV-CIMAT/pdfs/B08-HornSchunck.pdf
            - Use a regular image pyramid for input frames I(., .,t)
            - Processing starts at a selected level (of lower resolution)
            - Obtained results are used for initializing optic flow values at a
            lower level (of higher resolution)
            - Repeat until full resolution level of original frames is reached
    */

    void OpticalFlowPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        const float MaxLevel = 6.5;
        float4 OpticalFlow;
        float2 Smooth;
        float3 Data;

        [unroll] for(float Level = MaxLevel; Level > 0.0; Level--)
        {
            const float Alpha = max(ldexp(_Constraint * 1e-5, Level - MaxLevel), 1e-7);

            // .xy = Normalized Red Channel (x, y)
            // .zw = Normalized Green Channel (x, y)
            float4 SampleI = tex2Dlod(_SampleDerivatives, float4(TexCoord, 0.0, Level)).xyzw;

            // .xy = Current frame (r, g)
            // .zw = Previous frame (r, g)
            float4 SampleFrames;
            SampleFrames.xy = tex2Dlod(_SampleCurrentFrame, float4(TexCoord, 0.0, Level)).rg;
            SampleFrames.zw = tex2Dlod(_SamplePreviousFrame, float4(TexCoord, 0.0, Level)).rg;
            float2 Iz = SampleFrames.xy - SampleFrames.zw;

            Smooth.x = dot(SampleI.xz, SampleI.xz) + Alpha;
            Smooth.y = dot(SampleI.yw, SampleI.yw) + Alpha;
            Data.x = dot(SampleI.xz, Iz.rg);
            Data.y = dot(SampleI.yw, Iz.rg);
            Data.z = dot(SampleI.xz, SampleI.yw);
            OpticalFlow.x = ((Alpha * OpticalFlow.x) - (OpticalFlow.y * Data.z) - Data.x) / Smooth.x;
            OpticalFlow.y = ((Alpha * OpticalFlow.y) - (OpticalFlow.x * Data.z) - Data.y) / Smooth.y;
        }

        OutputColor0.xy = OpticalFlow.xy;
        OutputColor0.ba = _Blend;
    }

    void DisplayPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target)
    {
        float2 Velocity = tex2Dlod(_SampleOpticalFlow, float4(TexCoord, 0.0, _Detail)).xy;
        float VelocityLength = saturate(rsqrt(dot(Velocity, Velocity)));
        OutputColor0.rg = (Velocity * VelocityLength) * 0.5 + 0.5;
        OutputColor0.b = -dot(OutputColor0.rg, 1.0) * 0.5 + 1.0;
        OutputColor0.a = 1.0;
    }

    void CopyPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OutputColor0 = tex2D(_SampleCurrentFrame, TexCoord).rg;
    }

    technique cHornSchunck
    {
        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = NormalizePS;
            RenderTarget0 = _RenderCurrentFrame;
        }

        pass
        {
            VertexShader = DerivativesVS;
            PixelShader = DerivativesPS;
            RenderTarget0 = _RenderDerivatives;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = OpticalFlowPS;
            RenderTarget0 = _RenderOpticalFlow;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = INVSRCALPHA;
            DestBlend = SRCALPHA;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = DisplayPS;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = CopyPS;
            RenderTarget0 = _RenderPreviousFrame;
        }
    }
}


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

namespace Motion_Mask
{
    uniform float _Blend_Factor <
        ui_type = "slider";
        ui_label = "Temporal blending factor";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.5;

    uniform float _Min_Threshold <
        ui_type = "slider";
        ui_label = "Min threshold";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.0;

    uniform float _Max_Threshold <
        ui_type = "slider";
        ui_label = "Max threshold";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.5;

    uniform float _Difference_Weight <
        ui_type = "slider";
        ui_label = "Difference Weight";
        ui_min = 0.0;
        ui_max = 2.0;
    > = 1.0;

    uniform bool _Normalize_Input <
        ui_type = "radio";
        ui_label = "Normalize Input";
    > = false;

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

    texture2D Render_Current
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RG8;
    };

    sampler2D Sample_Current
    {
        Texture = Render_Current;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D Render_Difference
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = R8;
    };

    sampler2D Sample_Difference
    {
        Texture = Render_Difference;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D Render_Previous
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RG8;
    };

    sampler2D Sample_Previous
    {
        Texture = Render_Previous;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    // Vertex shaders

    void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 Coord : TEXCOORD0)
    {
        Coord.x = (ID == 2) ? 2.0 : 0.0;
        Coord.y = (ID == 1) ? 2.0 : 0.0;
        Position = Coord.xyxy * float4(2.0, -2.0, 0.0, 0.0) + float4(-1.0, 1.0, 0.0, 1.0);
    }

    // Pixel shaders

    void Blit_0_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        float3 Color = max(tex2D(Sample_Color, Coord).rgb, exp2(-10.0));
        Output_Color_0 = (_Normalize_Input) ? saturate(Color.xy / dot(Color, 1.0)) : max(max(Color.r, Color.g), Color.b);
    }

    void Difference_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        float Difference = 0.0;

        if(_Normalize_Input)
        {
            float2 Current = tex2D(Sample_Current, Coord).rg;
            float2 Previous = tex2D(Sample_Previous, Coord).rg;
            Difference = abs(dot(Current - Previous, 1.0)) * _Difference_Weight;
        }
        else
        {
            float Current = tex2D(Sample_Current, Coord).r;
            float Previous = tex2D(Sample_Previous, Coord).r;
            Difference = abs(Current - Previous) * _Difference_Weight;
        }

        if (Difference <= _Min_Threshold)
        {
            Output_Color_0 = 0.0;
        }
        else if (Difference > _Max_Threshold)
        {
            Output_Color_0 = 1.0;
        }
        else
        {
            Output_Color_0 = Difference;
        }

        Output_Color_0.a = _Blend_Factor;
    }

    void Output_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = tex2D(Sample_Difference, Coord).r;
    }

    void Blit_1_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = tex2D(Sample_Current, Coord);
    }

    technique cMotionMask
    {
        pass
        {
            VertexShader = Basic_VS;
            PixelShader = Blit_0_PS;
            RenderTarget0 = Render_Current;
        }

        pass
        {
            VertexShader = Basic_VS;
            PixelShader = Difference_PS;
            RenderTarget0 = Render_Difference;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = INVSRCALPHA;
            DestBlend = SRCALPHA;
        }

        pass
        {
            VertexShader = Basic_VS;
            PixelShader = Output_PS;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }

        pass
        {
            VertexShader = Basic_VS;
            PixelShader = Blit_1_PS;
            RenderTarget0 = Render_Previous;
        }
    }
}

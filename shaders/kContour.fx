
/*
    Heavily modified version of KinoContour

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

/*
    https://github.com/keijiro/KinoContour

    MIT License

    Copyright (C) 2015-2017 Keijiro Takahashi

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

uniform float _Inverse_Range <
    ui_label = "Inverse Range";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.05f;

uniform float _Color_Sensitivity <
    ui_label = "Color Sensitivity";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.0f;

uniform float4 _Front_Color <
    ui_label = "Front Color";
    ui_type = "color";
    ui_min = 0.0; ui_max = 1.0;
> = float4(1.0, 1.0, 1.0, 1.0);

uniform float4 _Back_Color <
    ui_label = "Back Color";
    ui_type = "color";
    ui_min = 0.0; ui_max = 1.0;
> = float4(0.0, 0.0, 0.0, 0.0);

uniform int _Method <
    ui_type = "combo";
    ui_items = " ddx(), ddy()\0 Bilinear 3x3 Laplacian\0 Bilinear 3x3 Sobel\0 Bilinear 5x5 Prewitt\0 Bilinear 5x5 Sobel\0 3x3 Prewitt\0 3x3 Scharr\0 None\0";
    ui_label = "Method";
    ui_tooltip = "Method Edge Detection";
> = 0;

uniform bool _Scale_Derivatives <
    ui_label = "Scale Derivatives to [-1, 1] range";
    ui_type = "radio";
> = true;

uniform bool _Normalize_Output <
    ui_label = "Normalize Output";
    ui_type = "radio";
> = true;

uniform float _Normalize_Weight <
    ui_label = "Normal Weight";
    ui_type = "drag";
    ui_min = 0.0;
> = 0.1;

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

texture2D Render_Normals
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RG8;
};

sampler2D Sample_Normals
{
    Texture = Render_Normals;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

// Vertex shaders

void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 Coord : TEXCOORD0)
{
    Coord.x = (ID == 2) ? 2.0 : 0.0;
    Coord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(Coord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

void Contour_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coords[3] : TEXCOORD0)
{
    float2 VS_Coord = 0.0;
    Basic_VS(ID, Position, VS_Coord);
    const float2 PixelSize = 1.0 / int2(BUFFER_WIDTH, BUFFER_HEIGHT);

    Coords[0] = 0.0;
    Coords[1] = 0.0;
    Coords[2] = 0.0;

    switch(_Method)
    {
        case 0: // Fwidth
            Coords[0].xy = VS_Coord;
            break;
        case 1: // Bilinear 3x3 Laplacian
            Coords[0].xy = VS_Coord;
            Coords[1] = VS_Coord.xyxy + (float4(-0.5, -0.5, 0.5, 0.5) * PixelSize.xyxy);
            break;
        case 2: // Bilinear 3x3 Sobel
            Coords[0] = VS_Coord.xyxy + (float4(-0.5, -0.5, 0.5, 0.5) * PixelSize.xyxy);
            break;
        case 3: // Bilinear 5x5 Prewitt
            Coords[0] = VS_Coord.xyyy + (float4(-1.5, 1.5, 0.0, -1.5) * PixelSize.xyyy);
            Coords[1] = VS_Coord.xyyy + (float4( 0.0, 1.5, 0.0, -1.5) * PixelSize.xyyy);
            Coords[2] = VS_Coord.xyyy + (float4( 1.5, 1.5, 0.0, -1.5) * PixelSize.xyyy);
            break;
        case 4: // Bilinear 5x5 Sobel
            Coords[0] = VS_Coord.xxyy + (float4(-1.5, 1.5, -0.5, 0.5) * PixelSize.xxyy);
            Coords[1] = VS_Coord.xxyy + (float4(-0.5, 0.5, -1.5, 1.5) * PixelSize.xxyy);
            break;
        case 5: // 3x3 Prewitt
            Coords[0] = VS_Coord.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
            Coords[1] = VS_Coord.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
            Coords[2] = VS_Coord.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
            break;
        case 6: // 3x3 Scharr
            Coords[0] = VS_Coord.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
            Coords[1] = VS_Coord.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
            Coords[2] = VS_Coord.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
            break;
    }
}

// Pixel shaders
// Generate normals: https://github.com/crosire/reshade-shaders/blob/slim/Shaders/DisplayDepth.fx [MIT]
// Normal encodes: https://knarkowicz.wordpress.com/2014/04/16/octahedron-normal-vector-encoding/
// Contour pass: https://github.com/keijiro/KinoContour [MIT]

float3 Get_Screen_Space_Normal(float2 texcoord)
{
    float3 Offset = float3(BUFFER_PixelSize, 0.0);
    float2 Pos_Center = texcoord.xy;
    float2 Pos_North = Pos_Center - Offset.zy;
    float2 Pos_East = Pos_Center + Offset.xz;

    float3 Vert_Center = float3(Pos_Center - 0.5, 1.0) * ReShade::GetLinearizedDepth(Pos_Center);
    float3 Vert_North  = float3(Pos_North - 0.5,  1.0) * ReShade::GetLinearizedDepth(Pos_North);
    float3 Vert_East   = float3(Pos_East - 0.5,   1.0) * ReShade::GetLinearizedDepth(Pos_East);

    return normalize(cross(Vert_Center - Vert_North, Vert_Center - Vert_East));
}

float2 OctWrap(float2 V)
{
    return (1.0 - abs(V.yx)) * (V.xy >= 0.0 ? 1.0 : -1.0);
}

float2 Encode(float3 Normal)
{
    // max() divide based on
    Normal /= max(max(abs(Normal.x), abs(Normal.y)), abs(Normal.z));
    Normal.xy = Normal.z >= 0.0 ? Normal.xy : OctWrap(Normal.xy);
    Normal.xy = saturate(Normal.xy * 0.5 + 0.5);
    return Normal.xy;
}

float3 Decode(float2 f)
{
    f = f * 2.0 - 1.0;
    // https://twitter.com/Stubbesaurus/status/937994790553227264
    float3 Normal = float3(f.x, f.y, 1.0 - abs(f.x) - abs(f.y));
    float T = saturate(-Normal.z);
    Normal.xy += Normal.xy >= 0.0 ? -T : T;
    return normalize(Normal);
}

void Generate_Normals_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float2 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = Encode(Get_Screen_Space_Normal(Coord));
}

// 0 = Color, 1 = Normal, 2 = Depth

float3 SampleTexture(float2 Coord, int Mode)
{
    float3 Texture = 0.0;

    switch(Mode)
    {
        case 0:
            Texture = tex2D(Sample_Color, Coord).xyz;
            break;
        case 1:
            Texture = Decode(tex2D(Sample_Normals, Coord).xy);
            break;
        case 2:
            Texture = tex2D(ReShade::DepthBuffer, Coord).xyz;
            break;
    }

    return Texture;
}

float Magnitude(float3 X, float3 Y)
{
    X = (_Normalize_Output) ?  X * rsqrt(dot(X, X) + _Normalize_Weight) : X;
    Y = (_Normalize_Output) ?  Y * rsqrt(dot(Y, Y) + _Normalize_Weight) : Y;
    return sqrt(dot(X, X) + dot(Y, Y));
}

float4 Scale_Derivative(float4 Input)
{
    float ScaleWeight = 0.0;

    switch(_Method)
    {
        case 0: // Fwidth
            ScaleWeight = 1.0;
            break;
        case 1: // Bilinear 3x3 Laplacian
            ScaleWeight = 1.0;
            break;
        case 2: // Bilinear 3x3 Sobel
            ScaleWeight = 4.0;
            break;
        case 3: // Bilinear 5x5 Prewitt
            ScaleWeight = 10.0;
            break;
        case 4: // Bilinear 5x5 Sobel by CeeJayDK
            ScaleWeight = 12.0;
            break;
        case 5: // 3x3 Prewitt
            ScaleWeight = 3.0;
            break;
        case 6: // 3x3 Scharr
            ScaleWeight = 16.0;
            break;
        default:
            ScaleWeight = 1.0;
            break;
    }

    Input = (_Scale_Derivatives) ? Input / ScaleWeight : Input;
    return Input;
}

void Contour(in float4 Coords[3], in int Mode, out float4 OutputColor0)
{
    float4 Ix, Iy, Gradient;
    float4 A_0, B_0, C_0;
    float4 A_1, B_1, C_1;
    float4 A_2, B_2, C_2;

    switch(_Method)
    {
        case 0: // Fwidth
            A_0 = SampleTexture(Coords[0].xy, Mode);
            Ix = ddx(A_0);
            Iy = ddy(A_0);
            Gradient = Magnitude(Ix.rgb, Iy.rgb);
            break;
        case 1: // Bilinear 3x3 Laplacian
            // A_0    C_0
            //    B_1
            // A_2    C_2
            A_0 = SampleTexture(Coords[1].xw, Mode); // <-0.5, +0.5>
            C_0 = SampleTexture(Coords[1].zw, Mode); // <+0.5, +0.5>
            B_1 = SampleTexture(Coords[0].xy, Mode); // < 0.0,  0.0>
            A_2 = SampleTexture(Coords[1].xy, Mode); // <-0.5, -0.5>
            C_2 = SampleTexture(Coords[1].zy, Mode); // <+0.5, -0.5>

            Gradient = (A_0 + C_0 + A_2 + C_2) - (B_1 * 4.0);
            Gradient = length(Gradient) * rsqrt(3.0);
            break;
        case 2: // Bilinear 3x3 Sobel
            A_0 = SampleTexture(Coords[0].xw, Mode).rgb * 4.0; // <-0.5, +0.5>
            C_0 = SampleTexture(Coords[0].zw, Mode).rgb * 4.0; // <+0.5, +0.5>
            A_2 = SampleTexture(Coords[0].xy, Mode).rgb * 4.0; // <-0.5, -0.5>
            C_2 = SampleTexture(Coords[0].zy, Mode).rgb * 4.0; // <+0.5, -0.5>

            Ix = Scale_Derivative((C_0 + C_2) - (A_0 + A_2));
            Iy = Scale_Derivative((A_0 + C_0) - (A_2 + C_2));
            Gradient = Magnitude(Ix.rgb, Iy.rgb);
            break;
        case 3: // Bilinear 5x5 Prewitt
            // A_0 B_0 C_0
            // A_1    C_1
            // A_2 B_2 C_2
            A_0 = SampleTexture(Coords[0].xy, Mode) * 4.0; // <-1.5, +1.5>
            A_1 = SampleTexture(Coords[0].xz, Mode) * 2.0; // <-1.5,  0.0>
            A_2 = SampleTexture(Coords[0].xw, Mode) * 4.0; // <-1.5, -1.5>
            B_0 = SampleTexture(Coords[1].xy, Mode) * 2.0; // < 0.0, +1.5>
            B_2 = SampleTexture(Coords[1].xw, Mode) * 2.0; // < 0.0, -1.5>
            C_0 = SampleTexture(Coords[2].xy, Mode) * 4.0; // <+1.5, +1.5>
            C_1 = SampleTexture(Coords[2].xz, Mode) * 2.0; // <+1.5,  0.0>
            C_2 = SampleTexture(Coords[2].xw, Mode) * 4.0; // <+1.5, -1.5>

            // -1 -1  0  +1 +1
            // -1 -1  0  +1 +1
            // -1 -1  0  +1 +1
            // -1 -1  0  +1 +1
            // -1 -1  0  +1 +1
            Ix = Scale_Derivative((C_0 + C_1 + C_2) - (A_0 + A_1 + A_2));

            // +1 +1 +1 +1 +1
            // +1 +1 +1 +1 +1
            //  0  0  0  0  0
            // -1 -1 -1 -1 -1
            // -1 -1 -1 -1 -1
            Iy = Scale_Derivative((A_0 + B_0 + C_0) - (A_2 + B_2 + C_2));

            Gradient = Magnitude(Ix.rgb, Iy.rgb);
            break;
        case 4: // Bilinear 5x5 Sobel by CeeJayDK
            //   B_1 B_2
            // A_0     A_1
            // A_2     B_0
            //   C_0 C_1
            A_0 = SampleTexture(Coords[0].xw, Mode) * 4.0; // <-1.5, +0.5>
            A_1 = SampleTexture(Coords[0].yw, Mode) * 4.0; // <+1.5, +0.5>
            A_2 = SampleTexture(Coords[0].xz, Mode) * 4.0; // <-1.5, -0.5>
            B_0 = SampleTexture(Coords[0].yz, Mode) * 4.0; // <+1.5, -0.5>
            B_1 = SampleTexture(Coords[1].xw, Mode) * 4.0; // <-0.5, +1.5>
            B_2 = SampleTexture(Coords[1].yw, Mode) * 4.0; // <+0.5, +1.5>
            C_0 = SampleTexture(Coords[1].xz, Mode) * 4.0; // <-0.5, -1.5>
            C_1 = SampleTexture(Coords[1].yz, Mode) * 4.0; // <+0.5, -1.5>

            //    -1 0 +1
            // -1 -2 0 +2 +1
            // -2 -2 0 +2 +2
            // -1 -2 0 +2 +1
            //    -1 0 +1
            Ix = Scale_Derivative((B_2 + A_1 + B_0 + C_1) - (B_1 + A_0 + A_2 + C_0));

            //    +1 +2 +1
            // +1 +2 +2 +2 +1
            //  0  0  0  0  0
            // -1 -2 -2 -2 -1
            //    -1 -2 -1
            Iy = Scale_Derivative((A_0 + B_1 + B_2 + A_1) - (A_2 + C_0 + C_1 + B_0));

            Gradient = Magnitude(Ix.rgb, Iy.rgb);
            break;
        case 5: // 3x3 Prewitt
            // A_0 B_0 C_0
            // A_1     C_1
            // A_2 B_2 C_2
            A_0 = SampleTexture(Coords[0].xy, Mode);
            A_1 = SampleTexture(Coords[0].xz, Mode);
            A_2 = SampleTexture(Coords[0].xw, Mode);
            B_0 = SampleTexture(Coords[1].xy, Mode);
            B_2 = SampleTexture(Coords[1].xw, Mode);
            C_0 = SampleTexture(Coords[2].xy, Mode);
            C_1 = SampleTexture(Coords[2].xz, Mode);
            C_2 = SampleTexture(Coords[2].xw, Mode);

            Ix = Scale_Derivative((C_0 + C_1 + C_2) - (A_0 + A_1 + A_2));
            Iy = Scale_Derivative((A_0 + B_0 + C_0) - (A_2 + B_2 + C_2));
            Gradient = Magnitude(Ix.rgb, Iy.rgb);
            break;
        case 6: // 3x3 Scharr
        {
            A_0 = SampleTexture(Coords[0].xy, Mode) * 3.0;
            A_1 = SampleTexture(Coords[0].xz, Mode) * 10.0;
            A_2 = SampleTexture(Coords[0].xw, Mode) * 3.0;
            B_0 = SampleTexture(Coords[1].xy, Mode) * 10.0;
            B_2 = SampleTexture(Coords[1].xw, Mode) * 10.0;
            C_0 = SampleTexture(Coords[2].xy, Mode) * 3.0;
            C_1 = SampleTexture(Coords[2].xz, Mode) * 10.0;
            C_2 = SampleTexture(Coords[2].xw, Mode) * 3.0;

            Ix = Scale_Derivative((C_0 + C_1 + C_2) - (A_0 + A_1 + A_2));
            Iy = Scale_Derivative((A_0 + B_0 + C_0) - (A_2 + B_2 + C_2));
            Gradient = Magnitude(Ix.rgb, Iy.rgb);
            break;
        }
    }

    // Thresholding
    Gradient = Gradient * _Color_Sensitivity;
    Gradient = saturate((Gradient - _Threshold) * _Inverse_Range);

    float3 Base = 0.0;

    if(_Method == 0 || _Method == 1)
    {
        Base = tex2D(Sample_Color, Coords[0].xy).rgb;
    }
    else
    {
        Base = tex2D(Sample_Color, Coords[1].xz).rgb;
    }

    float3 Color_Background = lerp(Base, _Back_Color.rgb, _Back_Color.a);
    OutputColor0 = lerp(Color_Background, _Front_Color.rgb, Gradient.a * _Front_Color.a);
}

void Contour_Color_PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    Contour(Coords, 0, OutputColor0);
}

void Contour_Normal_PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    Contour(Coords, 1, OutputColor0);
}

technique KinoContourColor
{
    pass
    {
        VertexShader = Contour_VS;
        PixelShader = Contour_Color_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}

technique KinoContourNormal
{
    pass
    {
        VertexShader = Basic_VS;
        PixelShader = Generate_Normals_PS;
        RenderTarget0 = Render_Normals;
    }

    pass
    {
        VertexShader = Contour_VS;
        PixelShader = Contour_Normal_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}

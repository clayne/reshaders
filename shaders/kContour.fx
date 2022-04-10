
/*
    Various edge detection shaders

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

uniform int _Select <
    ui_type = "combo";
    ui_items = " Fwidth\0 Laplacian\0 Sobel\0 Prewitt\0 Robert\0 Scharr\0 Kayyali\0 Kroon\0 Bilinear Sobel\0 None\0";
    ui_label = "Method";
    ui_tooltip = "Select Edge Detection";
> = 0;

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

void Contour_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coord[4] : TEXCOORD0)
{
    float2 VS_Coord = 0.0;
    Basic_VS(ID, Position, VS_Coord);
    const float2 Pixel_Size = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    Coord[0] = VS_Coord.xyyy + float4(-Pixel_Size.x, Pixel_Size.y, 0.0, -Pixel_Size.y);
    Coord[1] = VS_Coord.xyyy + float4(0.0, Pixel_Size.y, 0.0, -Pixel_Size.y);
    Coord[2] = VS_Coord.xyyy + float4(Pixel_Size.x, Pixel_Size.y, 0.0, -Pixel_Size.y);
    Coord[3] = VS_Coord.xyxy + float4(Pixel_Size, -Pixel_Size) * 0.5;
}

float3 Normalize_Output(float3 Input)
{
    return (_Normalize_Output) ? Input * rsqrt(dot(Input, Input) + _Normalize_Weight) : Input;
}

float Magnitude(float3 X, float3 Y)
{
    X = Normalize_Output(X);
    Y = Normalize_Output(Y);
    return sqrt(dot(X, X) + dot(Y, Y));
}

// Pixel shaders
// Generate normals: https://github.com/crosire/reshade-shaders/blob/slim/Shaders/DisplayDepth.fx [MIT]
// Normal encodes: https://knarkowicz.wordpress.com/2014/04/16/octahedron-normal-vector-encoding/
// Contour pass: https://github.com/keijiro/KinoContour [MIT]

float3 Get_Screen_Space_Normal(float2 texcoord)
{
    float3 Offset = float3(BUFFER_PIXEL_SIZE, 0.0);
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

void Generate_Normals_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float2 Output_Color_0 : SV_TARGET0)
{
    Output_Color_0 = Encode(Get_Screen_Space_Normal(Coord));
}

// 0 = Color, 1 = Normal, 2 = Depth

float3 SampleTexture(float2 Coord, int Color_Normal_Depth)
{
    float3 Texture = 0.0;

    switch(Color_Normal_Depth)
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

void Contour(in float4 Coords[4], out float3 Output_Color_0, int Color_Normal_Depth)
{
    /*
        A_0 B_0 C_0
        A_1 B_1 C_1
        A_2 B_2 C_2
    */

    float3 A_0 = SampleTexture(Coords[0].xy, Color_Normal_Depth).rgb;
    float3 A_1 = SampleTexture(Coords[0].xz, Color_Normal_Depth).rgb;
    float3 A_2 = SampleTexture(Coords[0].xw, Color_Normal_Depth).rgb;

    float3 B_0 = SampleTexture(Coords[1].xy, Color_Normal_Depth).rgb;
    float3 B_1 = SampleTexture(Coords[1].xz, Color_Normal_Depth).rgb;
    float3 B_2 = SampleTexture(Coords[1].xw, Color_Normal_Depth).rgb;

    float3 C_0 = SampleTexture(Coords[2].xy, Color_Normal_Depth).rgb;
    float3 C_1 = SampleTexture(Coords[2].xz, Color_Normal_Depth).rgb;
    float3 C_2 = SampleTexture(Coords[2].xw, Color_Normal_Depth).rgb;

    float3 Bilinear_Sample_0, Bilinear_Sample_1, Bilinear_Sample_2, Bilinear_Sample_3;

    float3 Ix, Iy, Edge;

    switch(_Select)
    {
        case 0: // fwidth()
            Ix = Normalize_Output(ddx(B_1));
            Iy = Normalize_Output(ddy(B_1));
            Edge = Magnitude(Ix, Iy);
            break;
        case 1: // Laplacian
            Bilinear_Sample_0 = SampleTexture(Coords[3].zy, Color_Normal_Depth).rgb; // (-x, +y)
            Bilinear_Sample_1 = SampleTexture(Coords[3].xy, Color_Normal_Depth).rgb; // (+x, +y)
            Bilinear_Sample_2 = SampleTexture(Coords[3].zw, Color_Normal_Depth).rgb; // (-x, -y)
            Bilinear_Sample_3 = SampleTexture(Coords[3].xw, Color_Normal_Depth).rgb; // (+x, -y)
            Edge = (Bilinear_Sample_0 + Bilinear_Sample_1 + Bilinear_Sample_2 + Bilinear_Sample_3) - (B_1 * 4.0);
            Edge = Normalize_Output(Edge);
            Edge = length(Edge) / sqrt(3.0);
            break;
        case 2: // Sobel
            Ix = (-A_0 + ((-A_1 * 2.0) + -A_2)) + (C_0 + (C_1 * 2.0) + C_2);
            Iy = (-A_0 + ((-B_0 * 2.0) + -C_0)) + (A_2 + (B_2 * 2.0) + C_2);
            Edge = Magnitude(Ix, Iy);
            break;
        case 3: // Prewitt
            Ix = (-A_0 - A_1 - A_2) + (C_0 + C_1 + C_2);
            Iy = (-A_0 - B_0 - C_0) + (A_2 + B_2 + C_2);
            Edge = Magnitude(Ix, Iy);
            break;
        case 4: // Robert's Cross
            Ix = C_0 - B_1;
            Iy = B_0 - C_1;
            Edge = Magnitude(Ix, Iy);
            break;
        case 5: // Scharr
            Ix += A_0 * -3.0;
            Ix += A_1 * -10.0;
            Ix += A_2 * -3.0;
            Ix += C_0 * 3.0;
            Ix += C_1 * 10.0;
            Ix += C_2 * 3.0;

            Iy += A_0 * 3.0;
            Iy += B_0 * 10.0;
            Iy += C_0 * 3.0;
            Iy += A_2 * -3.0;
            Iy += B_2 * -10.0;
            Iy += C_2 * -3.0;
            Edge = Magnitude(Ix, Iy);
            break;
        case 6: // Kayyali
            float3 Cross = (A_0 * 6.0) + (C_0 * -6.0) + (A_2 * -6.0) + (C_2 * 6.0);
            Edge = Magnitude(Cross, -Cross);
            break;
        case 7: // Kroon
            Ix += A_0 * -17.0;
            Ix += A_1 * -61.0;
            Ix += A_2 * -17.0;
            Ix += C_0 * 17.0;
            Ix += C_1 * 61.0;
            Ix += C_2 * 17.0;

            Iy += A_0 * 17.0;
            Iy += B_0 * 61.0;
            Iy += C_0 * 17.0;
            Iy += A_2 * -17.0;
            Iy += B_2 * -61.0;
            Iy += C_2 * -17.0;
            Edge = Magnitude(Ix, Iy);
            break;
        case 8: // Bilinear Sobel
            Bilinear_Sample_0 = SampleTexture(Coords[3].zy, Color_Normal_Depth).rgb; // (-x, +y)
            Bilinear_Sample_1 = SampleTexture(Coords[3].xy, Color_Normal_Depth).rgb; // (+x, +y)
            Bilinear_Sample_2 = SampleTexture(Coords[3].zw, Color_Normal_Depth).rgb; // (-x, -y)
            Bilinear_Sample_3 = SampleTexture(Coords[3].xw, Color_Normal_Depth).rgb; // (+x, -y)
            Ix = ((-Bilinear_Sample_2 + -Bilinear_Sample_0) + (Bilinear_Sample_3 + Bilinear_Sample_1)) * 4.0;
            Iy = ((Bilinear_Sample_2 + Bilinear_Sample_3) + (-Bilinear_Sample_0 + -Bilinear_Sample_1)) * 4.0;
            Edge = Magnitude(Ix, Iy);
            break;
        default:
            Edge = SampleTexture(Coords[1].xz, Color_Normal_Depth).rgb;
            break;
    }

    // Thresholding
    Edge = Edge * _Color_Sensitivity;
    Edge = saturate((Edge - _Threshold) * _Inverse_Range);
    float3 Base = tex2D(Sample_Color, Coords[1].xz).rgb;
    float3 Color_Background = lerp(Base, _Back_Color.rgb, _Back_Color.a);
    Output_Color_0 = lerp(Color_Background, _Front_Color.rgb, Edge * _Front_Color.a);
}

void Contour_Color_PS(in float4 Position : SV_POSITION, in float4 Coords[4] : TEXCOORD0, out float3 Output_Color_0 : SV_TARGET0)
{
    Contour(Coords, Output_Color_0, 1);
}

void Contour_Normal_PS(in float4 Position : SV_POSITION, in float4 Coords[4] : TEXCOORD0, out float3 Output_Color_0 : SV_TARGET0)
{
    Contour(Coords, Output_Color_0, 1);
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

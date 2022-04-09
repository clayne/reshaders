
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
// Contour pass: https://github.com/keijiro/KinoContour [MIT]

void Contour_PS(in float4 Position : SV_POSITION, in float4 Coord[4] : TEXCOORD0, out float3 Output_Color_0 : SV_TARGET0)
{
    /*
        A_0 B_0 C_0
        A_1 B_1 C_1
        A_2 B_2 C_2
    */

    float3 A_0 = tex2D(Sample_Color, Coord[0].xy).rgb;
    float3 A_1 = tex2D(Sample_Color, Coord[0].xz).rgb;
    float3 A_2 = tex2D(Sample_Color, Coord[0].xw).rgb;

    float3 B_0 = tex2D(Sample_Color, Coord[1].xy).rgb;
    float3 B_1 = tex2D(Sample_Color, Coord[1].xz).rgb;
    float3 B_2 = tex2D(Sample_Color, Coord[1].xw).rgb;

    float3 C_0 = tex2D(Sample_Color, Coord[2].xy).rgb;
    float3 C_1 = tex2D(Sample_Color, Coord[2].xz).rgb;
    float3 C_2 = tex2D(Sample_Color, Coord[2].xw).rgb;

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
            Bilinear_Sample_0 = tex2D(Sample_Color, Coord[3].zy).rgb; // (-x, +y)
            Bilinear_Sample_1 = tex2D(Sample_Color, Coord[3].xy).rgb; // (+x, +y)
            Bilinear_Sample_2 = tex2D(Sample_Color, Coord[3].zw).rgb; // (-x, -y)
            Bilinear_Sample_3 = tex2D(Sample_Color, Coord[3].xw).rgb; // (+x, -y)
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
            Bilinear_Sample_0 = tex2D(Sample_Color, Coord[3].zy).rgb; // (-x, +y)
            Bilinear_Sample_1 = tex2D(Sample_Color, Coord[3].xy).rgb; // (+x, +y)
            Bilinear_Sample_2 = tex2D(Sample_Color, Coord[3].zw).rgb; // (-x, -y)
            Bilinear_Sample_3 = tex2D(Sample_Color, Coord[3].xw).rgb; // (+x, -y)
            Ix = ((-Bilinear_Sample_2 + -Bilinear_Sample_0) + (Bilinear_Sample_3 + Bilinear_Sample_1)) * 4.0;
            Iy = ((Bilinear_Sample_2 + Bilinear_Sample_3) + (-Bilinear_Sample_0 + -Bilinear_Sample_1)) * 4.0;
            Edge = Magnitude(Ix, Iy);
            break;
        default:
            Edge = tex2D(Sample_Color, Coord[1].xz).rgb;
            break;
    }

    // Thresholding
    Edge = Edge * _Color_Sensitivity;
    Edge = saturate((Edge - _Threshold) * _Inverse_Range);
    float3 Base = tex2D(Sample_Color, Coord[1].xz).rgb;
    float3 Color_Background = lerp(Base, _Back_Color.rgb, _Back_Color.a);
    Output_Color_0 = lerp(Color_Background, _Front_Color.rgb, Edge * _Front_Color.a);
}

technique KinoContour
{
    pass
    {
        VertexShader = Contour_VS;
        PixelShader = Contour_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}


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

uniform int _Method <
    ui_type = "combo";
    ui_items = " ddx(), ddy()\0 Bilinear 3x3 Laplacian\0 Bilinear 3x3 Sobel\0 Bilinear 5x5 Prewitt\0 Bilinear 5x5 Sobel\0 3x3 Prewitt\0 3x3 Scharr\0 None\0";
    ui_label = "Method";
    ui_tooltip = "Method Edge Detection";
> = 0;

uniform bool _Scale <
    ui_label = "Scale Gradients to [-1, 1] range";
    ui_type = "radio";
> = true;

uniform bool _Normalize <
    ui_label = "Normalize Gradients";
    ui_type = "radio";
> = true;

uniform bool _Normal <
    ui_label = "Scale Gradients to [0, 1] range";
    ui_type = "radio";
> = true;

uniform float _Normalize_Weight <
    ui_label = "Normalize Weight";
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

void Edge_Detection_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coords[3] : TEXCOORD0)
{
    float2 VS_Coord = 0.0;
    Basic_VS(ID, Position, VS_Coord);
    const float2 Pixel_Size = 1.0 / int2(BUFFER_WIDTH, BUFFER_HEIGHT);

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
            Coords[1] = VS_Coord.xyxy + (float4(-0.5, -0.5, 0.5, 0.5) * Pixel_Size.xyxy);
            break;
        case 2: // Bilinear 3x3 Sobel
            Coords[0] = VS_Coord.xyxy + (float4(-0.5, -0.5, 0.5, 0.5) * Pixel_Size.xyxy);
            break;
        case 3: // Bilinear 5x5 Prewitt
            Coords[0] = VS_Coord.xyyy + (float4(-1.5, 1.5, 0.0, -1.5) * Pixel_Size.xyyy);
            Coords[1] = VS_Coord.xyyy + (float4( 0.0, 1.5, 0.0, -1.5) * Pixel_Size.xyyy);
            Coords[2] = VS_Coord.xyyy + (float4( 1.5, 1.5, 0.0, -1.5) * Pixel_Size.xyyy);
            break;
        case 4: // Bilinear 5x5 Sobel
            Coords[0] = VS_Coord.xxyy + (float4(-1.5, 1.5, -0.5, 0.5) * Pixel_Size.xxyy);
            Coords[1] = VS_Coord.xxyy + (float4(-0.5, 0.5, -1.5, 1.5) * Pixel_Size.xxyy);
            break;
        case 5: // 3x3 Prewitt
            Coords[0] = VS_Coord.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * Pixel_Size.xyyy);
            Coords[1] = VS_Coord.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * Pixel_Size.xyyy);
            Coords[2] = VS_Coord.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * Pixel_Size.xyyy);
            break;
        case 6: // 3x3 Scharr
            Coords[0] = VS_Coord.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * Pixel_Size.xyyy);
            Coords[1] = VS_Coord.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * Pixel_Size.xyyy);
            Coords[2] = VS_Coord.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * Pixel_Size.xyyy);
            break;
    }
}

void Edge_Operator(in sampler2D Source, in float4 Coords[3], inout float4 Ix, inout float4 Iy, inout float4 Gradient)
{
    float4 A_0, B_0, C_0;
    float4 A_1, B_1, C_1;
    float4 A_2, B_2, C_2;

    switch(_Method)
    {
        case 0: // Fwidth
            A_0 = tex2D(Source, Coords[0].xy);

            Ix = ddx(A_0);
            Iy = ddy(A_0);
            break;
        case 1: // Bilinear 3x3 Laplacian
            // A_0    C_0
            //    B_1
            // A_2    C_2
            A_0 = tex2D(Source, Coords[1].xw); // <-0.5, +0.5>
            C_0 = tex2D(Source, Coords[1].zw); // <+0.5, +0.5>
            B_1 = tex2D(Source, Coords[0].xy); // < 0.0,  0.0>
            A_2 = tex2D(Source, Coords[1].xy); // <-0.5, -0.5>
            C_2 = tex2D(Source, Coords[1].zy); // <+0.5, -0.5>

            Gradient = (A_0 + C_0 + A_2 + C_2) - (B_1 * 4.0);
            break;
        case 2: // Bilinear 3x3 Sobel
            A_0 = tex2D(Source, Coords[0].xw).rgb; // <-0.5, +0.5>
            C_0 = tex2D(Source, Coords[0].zw).rgb; // <+0.5, +0.5>
            A_2 = tex2D(Source, Coords[0].xy).rgb; // <-0.5, -0.5>
            C_2 = tex2D(Source, Coords[0].zy).rgb; // <+0.5, -0.5>

            Ix = ((C_0 + C_2) - (A_0 + A_2)) * 4.0;
            Iy = ((A_0 + C_0) - (A_2 + C_2)) * 4.0;
            break;
        case 3: // Bilinear 5x5 Prewitt
            // A_0 B_0 C_0
            // A_1    C_1
            // A_2 B_2 C_2
            A_0 = tex2D(Source, Coords[0].xy) * 4.0; // <-1.5, +1.5>
            A_1 = tex2D(Source, Coords[0].xz) * 2.0; // <-1.5,  0.0>
            A_2 = tex2D(Source, Coords[0].xw) * 4.0; // <-1.5, -1.5>
            B_0 = tex2D(Source, Coords[1].xy) * 2.0; // < 0.0, +1.5>
            B_2 = tex2D(Source, Coords[1].xw) * 2.0; // < 0.0, -1.5>
            C_0 = tex2D(Source, Coords[2].xy) * 4.0; // <+1.5, +1.5>
            C_1 = tex2D(Source, Coords[2].xz) * 2.0; // <+1.5,  0.0>
            C_2 = tex2D(Source, Coords[2].xw) * 4.0; // <+1.5, -1.5>

            // -1 -1  0  +1 +1
            // -1 -1  0  +1 +1
            // -1 -1  0  +1 +1
            // -1 -1  0  +1 +1
            // -1 -1  0  +1 +1
            Ix = (C_0 + C_1 + C_2) - (A_0 + A_1 + A_2);

            // +1 +1 +1 +1 +1
            // +1 +1 +1 +1 +1
            //  0  0  0  0  0
            // -1 -1 -1 -1 -1
            // -1 -1 -1 -1 -1
            Iy = (A_0 + B_0 + C_0) - (A_2 + B_2 + C_2);
            break;
        case 4: // Bilinear 5x5 Sobel by CeeJayDK
            //   B_1 B_2
            // A_0     A_1
            // A_2     B_0
            //   C_0 C_1
            A_0 = tex2D(Source, Coords[0].xw) * 4.0; // <-1.5, +0.5>
            A_1 = tex2D(Source, Coords[0].yw) * 4.0; // <+1.5, +0.5>
            A_2 = tex2D(Source, Coords[0].xz) * 4.0; // <-1.5, -0.5>
            B_0 = tex2D(Source, Coords[0].yz) * 4.0; // <+1.5, -0.5>
            B_1 = tex2D(Source, Coords[1].xw) * 4.0; // <-0.5, +1.5>
            B_2 = tex2D(Source, Coords[1].yw) * 4.0; // <+0.5, +1.5>
            C_0 = tex2D(Source, Coords[1].xz) * 4.0; // <-0.5, -1.5>
            C_1 = tex2D(Source, Coords[1].yz) * 4.0; // <+0.5, -1.5>

            //    -1 0 +1
            // -1 -2 0 +2 +1
            // -2 -2 0 +2 +2
            // -1 -2 0 +2 +1
            //    -1 0 +1
            Ix = (B_2 + A_1 + B_0 + C_1) - (B_1 + A_0 + A_2 + C_0);

            //    +1 +2 +1
            // +1 +2 +2 +2 +1
            //  0  0  0  0  0
            // -1 -2 -2 -2 -1
            //    -1 -2 -1
            Iy = (A_0 + B_1 + B_2 + A_1) - (A_2 + C_0 + C_1 + B_0);
            break;
        case 5: // 3x3 Prewitt
            // A_0 B_0 C_0
            // A_1    C_1
            // A_2 B_2 C_2
            A_0 = tex2D(Sample_Color, Coords[0].xy);
            A_1 = tex2D(Sample_Color, Coords[0].xz);
            A_2 = tex2D(Sample_Color, Coords[0].xw);
            B_0 = tex2D(Sample_Color, Coords[1].xy);
            B_2 = tex2D(Sample_Color, Coords[1].xw);
            C_0 = tex2D(Sample_Color, Coords[2].xy);
            C_1 = tex2D(Sample_Color, Coords[2].xz);
            C_2 = tex2D(Sample_Color, Coords[2].xw);

            Ix = (C_0 + C_1 + C_2) - (A_0 + A_1 + A_2);
            Iy = (A_0 + B_0 + C_0) - (A_2 + B_2 + C_2);
            break;
        case 6: // 3x3 Scharr
        {
            A_0 = tex2D(Sample_Color, Coords[0].xy) * 3.0;
            A_1 = tex2D(Sample_Color, Coords[0].xz) * 10.0;
            A_2 = tex2D(Sample_Color, Coords[0].xw) * 3.0;
            B_0 = tex2D(Sample_Color, Coords[1].xy) * 10.0;
            B_2 = tex2D(Sample_Color, Coords[1].xw) * 10.0;
            C_0 = tex2D(Sample_Color, Coords[2].xy) * 3.0;
            C_1 = tex2D(Sample_Color, Coords[2].xz) * 10.0;
            C_2 = tex2D(Sample_Color, Coords[2].xw) * 3.0;

            Ix = (C_0 + C_1 + C_2) - (A_0 + A_1 + A_2);
            Iy = (A_0 + B_0 + C_0) - (A_2 + B_2 + C_2);
            break;
        }
    }
}

void Edge_Detection_PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    Output_Color_0 = 1.0;
    float4 Ix, Iy, Gradient;
    Edge_Operator(Sample_Color, Coords, Ix, Iy, Gradient);

    float ScaleWeight = 1.0;

    switch(_Method)
    {
        case 0:
            ScaleWeight = 1.0;
            break;
        case 1:
            ScaleWeight = 1.0;
            break;
        case 2:
            ScaleWeight = 4.0;
            break;
        case 3:
            ScaleWeight = 10.0;
            break;
        case 4:
            ScaleWeight = 12.0;
            break;
        case 5:
            ScaleWeight = 3.0;
            break;
        case 6:
            ScaleWeight = 16.0;
            break;
    }

    Ix = (_Scale) ? Ix / ScaleWeight : Ix;
    Iy = (_Scale) ? Iy / ScaleWeight : Iy;

    Ix = (_Normalize) ? Ix / sqrt(dot(Ix.rgb, Ix.rgb) + _Normalize_Weight) : Ix;
    Iy = (_Normalize) ? Iy / sqrt(dot(Iy.rgb, Iy.rgb) + _Normalize_Weight) : Iy;

    // Output Results

    if(_Method == 1) // Laplacian
    {
        Output_Color_0 = length(Gradient.rgb);
    }
    else // Edge detection
    {
        Output_Color_0.rg = float2(dot(Ix.rgb, 1.0 / 3.0), dot(Iy.rgb, 1.0 / 3.0));
        Output_Color_0.b = (_Normal) ? 1.0 : 0.0;
        Output_Color_0 = (_Normal) ? Output_Color_0 * 0.5 + 0.5 : Output_Color_0;
    }
}

technique cEdgeDetection
{
    pass
    {
        VertexShader = Edge_Detection_VS;
        PixelShader = Edge_Detection_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}

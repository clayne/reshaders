
/*
    Census transform shader (https://en.wikipedia.org/wiki/Census_transform)

    BSD 3-Clause License

    Copyright (c) 2022, Paul Dang <brimson.net@gmail.com>
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

void CensusTransform_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 TexCoords[3] : TEXCOORD0)
{
    float2 LocalTexCoord = 0.0;
    LocalTexCoord.x = (ID == 2) ? 2.0 : 0.0;
    LocalTexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(LocalTexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    // Sample locations:
    // [0].xy [1].xy [2].xy
    // [0].xz [1].xz [2].xz
    // [0].xw [1].xw [2].xw
    const float2 PixelSize = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    TexCoords[0] = LocalTexCoord.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
    TexCoords[1] = LocalTexCoord.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
    TexCoords[2] = LocalTexCoord.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
}

void CensusTransform_PS(in float4 Position : SV_POSITION, in float4 TexCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = 0.0;

    const int Neighbors = 8;

    float4 CenterSample = tex2D(Sample_Color, TexCoords[1].xz);

    float4 NeighborSample[8];
    NeighborSample[0] = tex2D(Sample_Color, TexCoords[0].xy);
    NeighborSample[1] = tex2D(Sample_Color, TexCoords[1].xy);
    NeighborSample[2] = tex2D(Sample_Color, TexCoords[2].xy);
    NeighborSample[3] = tex2D(Sample_Color, TexCoords[0].xz);
    NeighborSample[4] = tex2D(Sample_Color, TexCoords[2].xz);
    NeighborSample[5] = tex2D(Sample_Color, TexCoords[0].xw);
    NeighborSample[6] = tex2D(Sample_Color, TexCoords[1].xw);
    NeighborSample[7] = tex2D(Sample_Color, TexCoords[2].xw);
    
    // Generate 8-bit integer from the 8-pixel neighborhood
    for(int i = 0; i < Neighbors; i++)
    {
        float4 Comparison = step(NeighborSample[i], CenterSample);
        OutputColor0 += ldexp(Comparison, i);
    }

	// Convert the 8-bit integer to float, and average the results from each channel
    OutputColor0 = saturate(dot(OutputColor0.rgb * (1.0 / (exp2(8) - 1)), 1.0 / 3.0));
}

technique cCensusTransform
{
    pass
    {
        VertexShader = CensusTransform_VS;
        PixelShader = CensusTransform_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}


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

void PostProcessVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = TexCoord.xyxy * float4(2.0, -2.0, 0.0, 0.0) + float4(-1.0, 1.0, 0.0, 1.0);
}

void DerivativesVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoords[2] : TEXCOORD0)
{
    float2 TexCoord0;
    PostProcessVS(ID, Position, TexCoord0);
    const float2 PixelSize = 1.0 / uint2(BUFFER_WIDTH, BUFFER_HEIGHT);
    TexCoords[0] = TexCoord0.xxyy + float4(-1.5, 1.5, -0.5, 0.5) * PixelSize.xxyy;
    TexCoords[1] = TexCoord0.xxyy + float4(-0.5, 0.5, -1.5, 1.5) * PixelSize.xxyy;
}

void DerivativesPS(in float4 Position : SV_Position, in float4 TexCoords[2] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
{
    // Custom 5x5 bilinear edge-detection by CeeJayDK
    //   B0 B1
    // A0     A1
    //     C
    // A2     A3
    //   B2 B3
    float4 A0 = tex2D(SampleColor, TexCoords[0].xw) * 4.0; // <-1.5, +0.5>
    float4 A1 = tex2D(SampleColor, TexCoords[0].yw) * 4.0; // <+1.5, +0.5>
    float4 A2 = tex2D(SampleColor, TexCoords[0].xz) * 4.0; // <-1.5, -0.5>
    float4 A3 = tex2D(SampleColor, TexCoords[0].yz) * 4.0; // <+1.5, -0.5>

    float4 B0 = tex2D(SampleColor, TexCoords[1].xw) * 4.0; // <-0.5, +1.5>
    float4 B1 = tex2D(SampleColor, TexCoords[1].yw) * 4.0; // <+0.5, +1.5>
    float4 B2 = tex2D(SampleColor, TexCoords[1].xz) * 4.0; // <-0.5, -1.5>
    float4 B3 = tex2D(SampleColor, TexCoords[1].yz) * 4.0; // <+0.5, -1.5>

    //    -1 0 +1
    // -1 -2 0 +2 +1
    // -2 -2 0 +2 +2
    // -1 -2 0 +2 +1
    //    -1 0 +1
    float4 Ix = (B1 + A1 + A3 + B3) - (B0 + A0 + A2 + B2);

    //    +1 +2 +1
    // +1 +2 +2 +2 +1
    //  0  0  0  0  0
    // -1 -2 -2 -2 -1
    //    -1 -2 -1
    float4 Iy = (B0 + B1 + A0 + A1) - (A2 + A3 + B2 + B3);
    OutputColor0 = float2(length(Ix.rgb / 12.0), length(Iy.rgb / 12.0));
}

technique cEdgeDetection
{
    pass
    {
        VertexShader = DerivativesVS;
        PixelShader = DerivativesPS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}


texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
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

void DerivativesVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoords[3] : TEXCOORD0)
{
    float2 TexCoord0;
    PostProcessVS(ID, Position, TexCoord0);
    const float2 PixelSize = 1.0 / uint2(BUFFER_WIDTH, BUFFER_HEIGHT);
    TexCoords[0] = TexCoord0.xyyy + float4(-1.5, 1.5, 0.0, -1.5) * PixelSize.xyyy;
    TexCoords[1] = TexCoord0.xyyy + float4( 0.0, 1.5, 0.0, -1.5) * PixelSize.xyyy;
    TexCoords[2] = TexCoord0.xyyy + float4( 1.5, 1.5, 0.0, -1.5) * PixelSize.xyyy;
}

void DerivativesPS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
{
    // A0 B0 C0
    // A1    C1
    // A2 B2 C2
    float2 A0 = tex2D(_SampleColor, TexCoords[0].xy).xy;
    float2 A1 = tex2D(_SampleColor, TexCoords[0].xz).xy;
    float2 A2 = tex2D(_SampleColor, TexCoords[0].xw).xy;
    float2 B0 = tex2D(_SampleColor, TexCoords[1].xy).xy;
    float2 B2 = tex2D(_SampleColor, TexCoords[1].xw).xy;
    float2 C0 = tex2D(_SampleColor, TexCoords[2].xy).xy;
    float2 C1 = tex2D(_SampleColor, TexCoords[2].xz).xy;
    float2 C2 = tex2D(_SampleColor, TexCoords[2].xw).xy;
    OutputColor0 = 0.0;
    OutputColor0.r = length((((C0 * 4.0) + (C1 * 2.0) + (C2 * 4.0)) - ((A0 * 4.0) + (A1 * 2.0) + (A2 * 4.0))) / 10.0);
    OutputColor0.g = length((((A0 * 4.0) + (B0 * 2.0) + (C0 * 4.0)) - ((A2 * 4.0) + (B2 * 2.0) + (C2 * 4.0))) / 10.0);
    OutputColor0.rg = float2(0, length(OutputColor0.rg));
}

technique cEdgeDetect
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

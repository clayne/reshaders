
void PostProcessVS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

void ShaderPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    float2 PositionMod = Position.xy % 2.0;
    OutputColor0.r = (PositionMod.x == 1.0 && PositionMod.y == 1.0) ? 1.0 : 0.0;
    OutputColor0.g = (PositionMod.x == 0.0 && PositionMod.y == 1.0) ? 1.0 : 0.0;
    OutputColor0.b = (PositionMod.x == 1.0 && PositionMod.y == 0.0) ? 1.0 : 0.0;
    OutputColor0.a = (PositionMod.x == 0.0 && PositionMod.y == 0.0) ? 1.0 : 0.0;
}

technique Bug
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = ShaderPS;
    }
}

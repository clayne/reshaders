
void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 Coord : TEXCOORD0)
{
    Coord.x = (ID == 2) ? 2.0 : 0.0;
    Coord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(Coord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

void ShaderPS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    float2 Position_Mod = Position.xy % 2.0;
    Output_Color_0.r = (Position_Mod.x == 1.0 && Position_Mod.y == 1.0) ? 1.0 : 0.0;
    Output_Color_0.g = (Position_Mod.x == 0.0 && Position_Mod.y == 1.0) ? 1.0 : 0.0;
    Output_Color_0.b = (Position_Mod.x == 1.0 && Position_Mod.y == 0.0) ? 1.0 : 0.0;
    Output_Color_0.a = (Position_Mod.x == 0.0 && Position_Mod.y == 0.0) ? 1.0 : 0.0;
}

technique Bug
{
    pass
    {
        VertexShader = Basic_VS;
        PixelShader = ShaderPS;
    }
}

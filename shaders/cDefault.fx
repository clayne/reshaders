
/*
    Placeholder shader to initialize the pipeline for comparing shaders
*/

void PostProcessVS(out float4 Position : SV_Position)
{
    Position = float4(0.0, 0.0, 0.0, 0.0);
}

void PostProcessPS(out float4 OutputColor0 : SV_Target0)
{
    OutputColor0 = float4(0.0, 0.0, 0.0, 0.0);
}

technique cDefault
{
    pass
    {
        VertexCount = 0;
        VertexShader = PostProcessVS;
        PixelShader = PostProcessPS;
    }
}

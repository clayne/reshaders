
uniform float2 _ShiftRed <
    ui_type = "drag";
> = -1.0;

uniform float2 _ShiftBlue <
    ui_type = "drag";
> = 1.0;

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

/* [Vertex Shaders] */

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/*
    [Pixel Shaders]

    NOTE: PixelSize = 1.0 / screensize
    TexCoord + _ShiftRed * pixelsize == TexCoord + _ShiftRed / screensize

    QUESTION: "Why do we have to divide our shifting value with screensize?"
    ANSWER: Texture coordinates in window-space is between 0.0 - 1.0.
            Thus, just doing TexCoord + 1.0 moves the texture to the window's other sides, rendering it out of sight
*/

void AbberationPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    const float2 PixelSize = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    // Shift red channel
    OutputColor0.r = tex2D(_SampleColor, TexCoord + _ShiftRed * PixelSize).r;
    // Keep green channel to the center
    OutputColor0.g = tex2D(_SampleColor, TexCoord).g;
    // Shift blue channel
    OutputColor0.b = tex2D(_SampleColor, TexCoord + _ShiftBlue * PixelSize).b;
    // Write alpha value
    OutputColor0.a = 1.0;
}

technique cAbberation
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = AbberationPS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}

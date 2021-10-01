
/*
    Various edge detectors
    - Built-in fwidth()
    - Laplacian
    - Sobel
    - Prewitt
    - Robert's Cross
    - Scharr
    - Kayyali
    - Kroon

    A0 B0 C0
    A1 B1 C1
    A2 B2 C2
*/

uniform int _Select <
    ui_type = "combo";
    ui_items = " Built-in fwidth()\0 Laplacian\0 Sobel\0 Prewitt\0 Robert\0 Scharr\0 Kayyali\0 Kroon\0 None\0";
    ui_label = "Method";
    ui_tooltip = "Select Edge Detection";
> = 0;

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    SRGBTexture = TRUE;
};

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

void EdgeDetectionVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 TexCoord[3] : TEXCOORD0)
{
    float2 TexCoord0;
    PostProcessVS(ID, Position, TexCoord0);
    const float2 PixelSize = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    TexCoord[0] = TexCoord0.xyyy + float4(-PixelSize.x, +PixelSize.y, 0.0, -PixelSize.y);
    TexCoord[1] = TexCoord0.xyyy + float4(0.0, +PixelSize.y, 0.0, -PixelSize.y);
    TexCoord[2] = TexCoord0.xyyy + float4(+PixelSize.x, +PixelSize.y, 0.0, -PixelSize.y);
}

void EdgeDetectionPS(float4 Position : SV_POSITION, float4 TexCoord[3] : TEXCOORD0, out float3 OutputColor : SV_TARGET0)
{
    /*
        A0 B0 C0
        A1 B1 C1
        A2 B2 C2
    */

    float3 A0 = tex2D(_SampleColor, TexCoord[0].xy).rgb;
    float3 A1 = tex2D(_SampleColor, TexCoord[0].xz).rgb;
    float3 A2 = tex2D(_SampleColor, TexCoord[0].xw).rgb;

    float3 B0 = tex2D(_SampleColor, TexCoord[1].xy).rgb;
    float3 B1 = tex2D(_SampleColor, TexCoord[1].xz).rgb;
    float3 B2 = tex2D(_SampleColor, TexCoord[1].xw).rgb;

    float3 C0 = tex2D(_SampleColor, TexCoord[2].xy).rgb;
    float3 C1 = tex2D(_SampleColor, TexCoord[2].xz).rgb;
    float3 C2 = tex2D(_SampleColor, TexCoord[2].xw).rgb;

    float3 _ddx, _ddy;

    switch(_Select)
    {
        case 0:
            _ddx = ddx(B1);
            _ddy = ddy(B1);
            OutputColor = sqrt(dot(_ddx, _ddx) + dot(_ddy, _ddy));
            break;
        case 1:
            OutputColor = (A1 + C1 + B0 + B2) + (B1 * -4.0);
            break;
        case 2:
            _ddx = (-A0 + ((-A1 * 2.0) - A2)) + (C0 + C1 + C2);
            _ddy = (-A0 + ((-B0 * 2.0) - C0)) + (A2 + B2 + C2);
            OutputColor = sqrt(dot(_ddx, _ddx) + dot(_ddy, _ddy));
            break;
        case 3:
            _ddx = (-A0 - A1 - A2) + (C0 + C1 + C2);
            _ddy = (-A0 - B0 - C0) + (A2 + B2 + C2);
            OutputColor = sqrt(dot(_ddx, _ddx) + dot(_ddy, _ddy));
            break;
        case 4:
            _ddx = C0 - B1;
            _ddy = B0 - C1;
            OutputColor = sqrt(dot(_ddx, _ddx) + dot(_ddy, _ddy));
            break;
        case 5:
            _ddx += A0 * -3.0;
            _ddx += A1 * -10.0;
            _ddx += A2 * -3.0;
            _ddx += C0 * 3.0;
            _ddx += C1 * 10.0;
            _ddx += C2 * 3.0;

            _ddy += A0 * 3.0;
            _ddy += B0 * 10.0;
            _ddy += C0 * 3.0;
            _ddy += A2 * -3.0;
            _ddy += B2 * -10.0;
            _ddy += C2 * -3.0;
            OutputColor = sqrt(dot(_ddx, _ddx) + dot(_ddy, _ddy));
            break;
        case 6:
            float3 _ddxy = (A0 * 6.0) + (C0 * -6.0) + (A2 * -6.0) + (C2 * 6.0);
            OutputColor = sqrt(dot(_ddxy, _ddxy) + dot(-_ddxy, -_ddxy));
            break;
        case 7:
            _ddx += A0 * -17.0;
            _ddx += A1 * -61.0;
            _ddx += A2 * -17.0;
            _ddx += C0 * 17.0;
            _ddx += C1 * 61.0;
            _ddx += C2 * 17.0;

            _ddy += A0 * 17.0;
            _ddy += B0 * 61.0;
            _ddy += C0 * 17.0;
            _ddy += A2 * -17.0;
            _ddy += B2 * -61.0;
            _ddy += C2 * -17.0;
            OutputColor = sqrt(dot(_ddx, _ddx) + dot(_ddy, _ddy));
            break;
        default:
            OutputColor = B1;
            break;
    }

}

technique cEdgeDetection
{
    pass
    {
        VertexShader = EdgeDetectionVS;
        PixelShader = EdgeDetectionPS;
        SRGBWriteEnable = TRUE;
    }
}

/*
    Odd - Even pixel sort
    https://ciphrd.com/2020/04/08/pixel-sorting-on-shader-using-well-crafted-sorting-filters-glsl/
*/

uniform int _Frame < source = "framecount"; >;

uniform float _Threshold <
    ui_type = "drag";
> = 0.1;

texture2D _RenderColor : COLOR;

texture2D _RenderCopy_PixelSort
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA8;
};

sampler2D _SampleColor
{
    Texture = _RenderColor;
    SRGBTexture = TRUE;
};

sampler2D _SampleCopy_PixelSort
{
    Texture = _RenderCopy_PixelSort;
    SRGBTexture = TRUE;
};

/* [Vertex Shader] */

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [Pixel Shader] */

float GreyScale(float3 Color)
{
    return dot(Color, 1.0 / 3.0);
}

float ModALU(float X, float Y)
{
  return X - Y * floor(X / Y);
}

void PixelSortPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    if (_Frame < 10)
    {
        OutputColor0 = tex2D(_SampleColor, TexCoord);
        return;
    }

    // the frame number parity, -1 is odd 1 is even
    float FrameParity = (float(_Frame) % 2.0) * 2. - 1.;

    // we differentiate every 1/2 pixel on the horizontal axis, will be -1 or 1
    float PixelPosition = (floor(TexCoord.x * BUFFER_WIDTH) % 2.0) * 2.0 - 1.0;

    float2 Direction = float2(1.0, 0.0);
    Direction *= FrameParity * PixelPosition;
    Direction *= float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);

    // we sort
    float4 Current = tex2D(_SampleCopy_PixelSort, TexCoord);
    float4 Composite = tex2D(_SampleCopy_PixelSort, TexCoord + Direction);

    float GreyCurrent = GreyScale(Current.rgb);
    float GreyComposite = GreyScale(Composite.rgb);

    // we prevent the sort from happening on the borders
    if (TexCoord.x + Direction.x < 0.0 || TexCoord.x + Direction.x > 1.0)
    {
        OutputColor0 = Current;
        return;
    }

    // the direction of the displacement defines the order of the comparaison
    if (Direction.x < 0.0)
    {
        if (GreyCurrent > _Threshold && GreyComposite > GreyCurrent)
        {
            OutputColor0 = Composite;
        }
        else
        {
            OutputColor0 = Current;
        }
    }
    else
    {
        if (GreyComposite > _Threshold && GreyCurrent >= GreyComposite)
        {
            OutputColor0 = Composite;
        }
        else
        {
            OutputColor0 = Composite;
        }
    }
}

void BlitPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = float4(tex2D(_SampleColor, TexCoord).rgb, 1.0);
}

technique cPixelSort
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PixelSortPS;
        SRGBWriteEnable = TRUE;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlitPS;
        RenderTarget0 = _RenderCopy_PixelSort;
        SRGBWriteEnable = TRUE;
    }
}
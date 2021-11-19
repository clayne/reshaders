
uniform float _Blend <
    ui_type = "slider";
    ui_label = "Blending";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.5;

uniform float _Weight <
    ui_type = "slider";
    ui_label = "Weight";
    ui_min = 0.0;
    ui_max = 2.0;
> = 1.0;

uniform bool _NormalizeInput <
    ui_type = "radio";
    ui_label = "Normalize Input";
> = false;

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

texture2D _RenderCurrent_FrameDifference
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = R8;
};

sampler2D _SampleCurrent
{
    Texture = _RenderCurrent_FrameDifference;
};

texture2D _RenderDifference
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = R8;
};

sampler2D _SampleDifference
{
    Texture = _RenderDifference;
};

texture2D _RenderPrevious_FrameDifference
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = R8;
};

sampler2D _SamplePrevious
{
    Texture = _RenderPrevious_FrameDifference;
};

/* [Vertex Shaders] */

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = TexCoord.xyxy * float4(2.0, -2.0, 0.0, 0.0) + float4(-1.0, 1.0, 0.0, 1.0);
}

/* [Pixel Shaders] */

void BlitPS0(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float3 Color = tex2D(_SampleColor, TexCoord).rgb;
    float3 NColor = Color / dot(Color, 1.0);
    OutputColor0 = (_NormalizeInput) ? max(max(NColor.r, NColor.g), NColor.b) : max(max(Color.r, Color.g), Color.b);
}

void DifferencePS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float Current = tex2D(_SampleCurrent, TexCoord).x;
    float Previous = tex2D(_SamplePrevious, TexCoord).x;
    OutputColor0.rgb = abs(Current - Previous) * _Weight;
    OutputColor0.a = _Blend;
}

void OutputPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = tex2D(_SampleDifference, TexCoord).r;
}

void BlitPS1(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = tex2D(_SampleCurrent, TexCoord);
}

technique cFrameDifference
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlitPS0;
        RenderTarget0 = _RenderCurrent_FrameDifference;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = DifferencePS;
        RenderTarget0 = _RenderDifference;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVSRCALPHA;
        DestBlend = SRCALPHA;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OutputPS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlitPS1;
        RenderTarget0 = _RenderPrevious_FrameDifference;
    }
}

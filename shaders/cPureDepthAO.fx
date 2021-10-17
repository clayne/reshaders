
/*
    Work In-Progress
    Pure Depth Ambient Occlusion
    Source http://theorangeduck.com/page/pure-depth-ssao

    Original Port by Jose Negrete AKA BlueSkyDefender
    https://github.com/BlueSkyDefender/Depth3D
*/

#include "ReShade.fxh"

uniform float _Strength <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Total Strength";
    ui_category = "Ambient Occlusion";
> = 1.0;

uniform float _Base <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Base Amount";
    ui_category = "Ambient Occlusion";
> = 0.0;

uniform float _Area <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Area Amount";
    ui_category = "Ambient Occlusion";
> = 1.0;

uniform float _Falloff <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Falloff Amount";
    ui_category = "Ambient Occlusion";
> = 0.0;

uniform float _Radius <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Radius Amount";
    ui_category = "Ambient Occlusion";
> = 0.007;

uniform float _MipLevel <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Occlusion MipMap";
    ui_category = "Ambient Occlusion";
> = 0.0;

uniform float _DepthMapAdjust <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Depth Map Adjustment";
    ui_tooltip = "This allows for you to adjust the DM precision.\n"
                 "Adjust this to keep it as low as possible.\n"
                 "Default is 7.5";
    ui_category = "Depth Buffer";
> = 0.1;

uniform int _Debug <
    ui_type = "combo";
    ui_items = "Off\0Depth\0AO\0Direction\0";
    ui_label = "Debug View";
    ui_tooltip = "View Debug Buffers.";
    ui_category = "Debug Buffer";
> = 0;

#define PixelSize float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    SRGBTexture = TRUE;
};

texture2D _RenderOcclusion
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    MipLevels = 9;
    Format = R16F;
};

sampler2D _SampleOcclusion
{
    Texture = _RenderOcclusion;
};

/* [Pixel Shaders] */

float2 DepthMap(float2 TexCoord)
{
    float ZBuffer = ReShade::GetLinearizedDepth(TexCoord).x;
    ZBuffer /= _DepthMapAdjust;
    return float2(ZBuffer, smoothstep(-1.0, 1.0, ZBuffer));
}

float4 GetNormal(float2 TexCoord)
{
    const float2 Offset1 = float2(0.0, PixelSize.y);
    const float2 Offset2 = float2(PixelSize.x, 0.0);

    float Depth1 = DepthMap(TexCoord + Offset1).x;
    float Depth2 = DepthMap(TexCoord + Offset2).x;

    float3 Product1 = float4(Offset1, Depth1 - DepthMap(TexCoord).x);
    float3 Product2 = float4(Offset2, Depth2 - DepthMap(TexCoord).x);

    float3 Normal = cross(Product1, Product2);
    Normal.z = -Normal.z;

    return normalize(Normal);
}

void GradientNoise(in float2 Position, in float2 Offset, inout float Noise)
{
    Noise = frac(52.9829189 * frac(dot(Position.xy, float2(0.06711056, 0.00583715) * Offset)));
}

static const int Samples = 16;

/*
    Stored random vectors inside a sphere unit
    TODO: Use Vogel sphere disc for dynamic samples
    http://blog.marmakoide.org/?p=1
*/

float3 SphereSamples[Samples] =
{
    float3( 0.5381, 0.1856,-0.4319),
    float3( 0.1379, 0.2486, 0.4430),
    float3( 0.3371, 0.5679,-0.0057),
    float3(-0.6999,-0.0451,-0.0019),
    float3( 0.0689,-0.1598,-0.8547),
    float3( 0.0560, 0.0069,-0.1843),
    float3(-0.0146, 0.1402, 0.0762),
    float3( 0.0100,-0.1924,-0.0344),
    float3(-0.3577,-0.5301,-0.4358),
    float3(-0.3169, 0.1063, 0.0158),
    float3( 0.0103,-0.5869, 0.0046),
    float3(-0.0897,-0.4940, 0.3287),
    float3( 0.7119,-0.0154,-0.0918),
    float3(-0.0533, 0.0596,-0.5411),
    float3( 0.0352,-0.0631, 0.5460),
    float3(-0.4776, 0.2847,-0.0271)
};

void OcclusionPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    const int Samples = 16;
    float3 Noise;
    GradientNoise(TexCoord, float2(1.0, 1.0), Noise.x);
    GradientNoise(TexCoord, float2(2.0, 2.0), Noise.y);
    GradientNoise(TexCoord, float2(3.0, 3.0), Noise.z);

    // Use Random Noise for Montecarlo
    float3 Random = normalize(Noise);

    // Grab Depth Buffer
    float Depth = DepthMap(TexCoord).x;

    // Take current texcoords in screen space for sim world position
    float3 TexPosition = float3(TexCoord.xy, Depth);

    // Take a normals for reflecting the sample rays in the code below.
    float3 Normal = GetNormal(TexCoord);

    // Pre adjustment for Depth sailing that changes the avg radius.
    float DepthRadius = _Radius / Depth;

    float4 Occlusion = 0;

    for(int i = 0; i < Samples; i++)
    {
        // Grabs a vetor from a texture
        // Reflect it with in the randomized sphere with radius of 1.0
        float3 Ray = DepthRadius * reflect(SphereSamples[i], Random); // This why the above vetors is sub [-1.0, 1.0]

        // So if the ray is outside the hemisphere then change direction of that ray.
        float3 HemiRay = TexPosition + sign(dot(Ray, Normal)) * Ray;

        // Get the depth of the occluder fragment
        float OccluderDepth = DepthMap(saturate(HemiRay.xy)).x;

        // So if Difference between Depth is negative then it means the occluder is behind current fragment.
        float Difference = Depth - OccluderDepth;

        //Implament your own Z THICCness with area this also is falloff equation
        Occlusion += step(_Falloff, Difference) * (1.0 - smoothstep(_Falloff, _Area, Difference));

        // Can also be done with smoothstep I will add that code later.
    }

    float AmbientOcclusion = 1.0 - Occlusion.w * (1.0 / Samples);

    // float3 GlobalIllumination = Occlusion.rgb * (1.0 / Samples);
    // return float4(GlobalIllumination, saturate(AmbientOcclusion));

    OutputColor0 = saturate(AmbientOcclusion + _Base);
}

void DisplayPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float3 OutputColor0 : SV_TARGET0)
{
    switch(_Debug)
    {
        case 0:
            OutputColor0 = tex2D(_SampleColor, TexCoord).rgb * tex2Dlod(_SampleOcclusion, float4(TexCoord, 0.0, _MipLevel)).x;
            break;
        case 1:
            OutputColor0 = DepthMap(TexCoord).x;
            break;
        case 2:
            OutputColor0 = tex2Dlod(_SampleOcclusion, float4(TexCoord, 0.0, _MipLevel));
            break;
        default:
            GetNormal(TexCoord);
            break;
    }
}

technique cPureDepthAO
{
    pass AmbientOcclusion
    {
        VertexShader = PostProcessVS;
        PixelShader = OcclusionPS;
        RenderTarget0 = _RenderOcclusion;
    }

    pass Output
    {
        VertexShader = PostProcessVS;
        PixelShader = DisplayPS;
        SRGBWriteEnable = TRUE;
    }
}

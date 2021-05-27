
/*
    Unlimited 16-Tap blur using mipmaps
    Based on https://github.com/spite/Wagner/blob/master/fragment-shaders/box-blur-fs.glsl [MIT]
    Special Thanks to BlueSkyDefender for help and patience
*/

uniform float kRadius <
    ui_label = "Radius";
    ui_type = "slider";
    ui_max = 512.0;
    ui_min = 0.001;
> = 0.1;

texture2D r_color : COLOR;
texture2D r_blur { Width = BUFFER_WIDTH/2; Height = BUFFER_HEIGHT/2; Format = RGB10A2; MipLevels = 11; };

sampler2D s_color { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_blur  { Texture = r_blur; };

struct v2f
{
    float4 vpos : SV_Position;
    float2 uv : TEXCOORD0;
};

v2f vs_common(const uint id : SV_VertexID)
{
    v2f output;
    output.uv.x = (id == 2) ? 2.0 : 0.0;
    output.uv.y = (id == 1) ? 2.0 : 0.0;
    output.vpos = float4(output.uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    return output;
}

float nrand(float2 n)
{
    const float3 value = float3(52.9829189, 0.06711056, 0.00583715);
    return frac(value.x * frac(dot(n.xy, value.yz)));
}

float2 rotate2D(float2 p, float a)
{
    float2 output;
    float2 sc;
    sincos(a, sc.x, sc.y);
    output.x = dot(p, float2(sc.y, -sc.x));
    output.y = dot(p, float2(sc.x,  sc.y));
    return output.xy;
}

float4 ps_blur(v2f input) : SV_TARGET
{
    const int uTaps = 12;
    const float uSize = kRadius;

    float2 cTaps[uTaps];
    cTaps[0]  = float2(-0.326,-0.406);
    cTaps[1]  = float2(-0.840,-0.074);
    cTaps[2]  = float2(-0.696, 0.457);
    cTaps[3]  = float2(-0.203, 0.621);
    cTaps[4]  = float2( 0.962,-0.195);
    cTaps[5]  = float2( 0.473,-0.480);
    cTaps[6]  = float2( 0.519, 0.767);
    cTaps[7]  = float2( 0.185,-0.893);
    cTaps[8]  = float2( 0.507, 0.064);
    cTaps[9]  = float2( 0.896, 0.412);
    cTaps[10] = float2(-0.322,-0.933);
    cTaps[11] = float2(-0.792,-0.598);

    float4 uOutput = 0.0;
    float  uRand = 6.28 * nrand(input.vpos.xy);
    float4 uBasis;
    uBasis.xy = rotate2D(float2(1.0, 0.0), uRand);
    uBasis.zw = rotate2D(float2(0.0, 1.0), uRand);

    for (int i = 0; i < uTaps; i++)
    {
        float2 ofs = cTaps[i];
        ofs.x = dot(ofs, uBasis.xz);
        ofs.y = dot(ofs, uBasis.yw);
        float2 uv = input.uv + uSize * ofs / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
        float4 uColor = tex2Dlod(s_color, float4(uv, 0.0, 0.0));
        uOutput = lerp(uOutput, uColor, 1.0 / float(i + 1));
    }

    return uOutput;
}

float4 calcweights(float s)
{
    const float4 w1 = float4(-0.5, 0.1666, 0.3333, -0.3333);
    const float4 w2 = float4( 1.0, 0.0, -0.5, 0.5);
    const float4 w3 = float4(-0.6666, 0.0, 0.8333, 0.1666);
    float4 t = mad(w1, s, w2);
    t = mad(t, s, w2.yyzw);
    t = mad(t, s, w3);
    t.xy = mad(t.xy, rcp(t.zw), 1.0);
    t.x += s;
    t.y -= s;
    return t;
}

float4 ps_smooth(v2f input) : SV_TARGET
{

    const float kPi = 3.14159265359f;
    float area   = kPi * (kRadius * kRadius);
          area   = area / 12; // area per sample
    float lod    = ceil(log2(sqrt(area)))-1; // select mip level with similar area to the sample

    float2 texsize = tex2Dsize(s_blur, lod);
    float2 pt = 1.0 / texsize;
    float2 fcoord = frac(input.uv * texsize + 0.5);
    float4 parmx = calcweights(fcoord.x);
    float4 parmy = calcweights(fcoord.y);
    float4 cdelta;
    cdelta.xz = parmx.rg * float2(-pt.x, pt.x);
    cdelta.yw = parmy.rg * float2(-pt.y, pt.y);
    // first y-interpolation
    float4 ar = tex2Dlod(s_blur, float4(input.uv + cdelta.xy, 0.0, lod));
    float4 ag = tex2Dlod(s_blur, float4(input.uv + cdelta.xw, 0.0, lod));
    float4 ab = lerp(ag, ar, parmy.b);
    // second y-interpolation
    float4 br = tex2Dlod(s_blur, float4(input.uv + cdelta.zy, 0.0, lod));
    float4 bg = tex2Dlod(s_blur, float4(input.uv + cdelta.zw, 0.0, lod));
    float4 aa = lerp(bg, br, parmy.b);
    // x-interpolation
    return lerp(aa, ab, parmx.b);
}

technique cBlur
{
    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_blur;
        RenderTarget = r_blur;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_smooth;
        SRGBWriteEnable = TRUE;
    }
}


/*
    Optical flow motion blur using color by Brimson
    Special Thanks to
    - MartinBFFan and Pao on Discord for reporting bugs
    - BSD for bug propaganda and helping to solve my issue
    - Lord of Lunacy, KingEric1992, and Marty McFly for power of 2 function
*/

#define CONST_LOG2(x) (\
    (uint((x)  & 0xAAAAAAAA) != 0) | \
    (uint(((x) & 0xFFFF0000) != 0) << 4) | \
    (uint(((x) & 0xFF00FF00) != 0) << 3) | \
    (uint(((x) & 0xF0F0F0F0) != 0) << 2) | \
    (uint(((x) & 0xCCCCCCCC) != 0) << 1))

#define BIT2_LOG2(x)  ((x) | (x) >> 1)
#define BIT4_LOG2(x)  (BIT2_LOG2(x) | BIT2_LOG2(x) >> 2)
#define BIT8_LOG2(x)  (BIT4_LOG2(x) | BIT4_LOG2(x) >> 4)
#define BIT16_LOG2(x) (BIT8_LOG2(x) | BIT8_LOG2(x) >> 8)
#define LOG2(x)       (CONST_LOG2((BIT16_LOG2(x) >> 1) + 1))
#define RMAX(x, y)     x ^ ((x ^ y) & -(x < y)) // max(x, y)

#define uOption(option, udata, utype, ucategory, ulabel, uvalue, umin, umax, utooltip)  \
        uniform udata option <                                                  		\
        ui_category = ucategory; ui_label = ulabel;                             		\
        ui_type = utype; ui_min = umin; ui_max = umax; ui_tooltip = utooltip;   		\
        > = uvalue

uOption(uConst, float, "slider", "Optical Flow", "Constraint", 1.000, 0.000, 2.000,
"Regularization: Higher = Smoother flow");

uOption(uBlend, float, "slider", "Post Process", "Temporal Smoothing", 0.250, 0.000, 0.500,
"Temporal Smoothing: Higher = Less temporal noise");

uOption(uDetail, float, "slider", "Post Process", "Flow Mipmap Bias", 1.500, 0.000, 7.000,
"Postprocess Blur: Higher = Less spatial noise");

uOption(uNormal, bool, "radio", "Display", "Lines Normal Direction", true, 0, 0,
"Normal to velocity direction");

#define DSIZE uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)
#define RSIZE LOG2(RMAX(DSIZE.x, DSIZE.y)) + 1
#define ISIZE 128.0

texture2D r_color  : COLOR;
texture2D r_buffer { Width = DSIZE.x; Height = DSIZE.y; Format = RG8; MipLevels = RSIZE; };
texture2D r_cinfo0 { Width = ISIZE; Height = ISIZE; Format = RGBA16; MipLevels = 8; };
texture2D r_cinfo1 { Width = ISIZE; Height = ISIZE; Format = RG16; };
texture2D r_cddxy  { Width = ISIZE; Height = ISIZE; Format = RG16F; MipLevels = 8; };
texture2D r_cflow  { Width = ISIZE; Height = ISIZE; Format = RG16F; MipLevels = 8; };

sampler2D s_cflow  { Texture = r_cflow; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_color  { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_buffer { Texture = r_buffer; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cinfo0 { Texture = r_cinfo0; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cinfo1 { Texture = r_cinfo1; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cddxy  { Texture = r_cddxy; AddressU = MIRROR; AddressV = MIRROR; };

/* [Vertex Shaders] */

void vs_generic(in uint id : SV_VERTEXID,
                out float4 position : SV_POSITION,
                out float2 texcoord : TEXCOORD)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [Pixel Shaders] */

float gauss1D(const int position, const int kernel)
{
    const float sigma = kernel / 3.0;
    const float pi = 3.1415926535897932384626433832795f;
    float output = rsqrt(2.0 * pi * (sigma * sigma));
    return output * exp(-0.5 * position * position / (sigma * sigma));
}

float4 blur2D(sampler2D src, float2 uv, float2 direction, float2 psize)
{
    float2 sampleuv;
    const float kernel = 14;
    const float2 usize = (1.0 / psize) * direction;
    float4 output = tex2D(src, uv) * gauss1D(0.0, kernel);
    float total = gauss1D(0.0, kernel);

    [unroll]
    for(float i = 1.0; i < kernel; i += 2.0)
    {
        const float offsetD1 = i;
        const float offsetD2 = i + 1.0;
        const float weightD1 = gauss1D(offsetD1, kernel);
        const float weightD2 = gauss1D(offsetD2, kernel);
        const float weightL = weightD1 + weightD2;
        const float offsetL = ((offsetD1 * weightD1) + (offsetD2 * weightD2)) / weightL;

        sampleuv = uv - offsetL * usize;
        output += tex2D(src, sampleuv) * weightL;
        sampleuv = uv + offsetL * usize;
        output += tex2D(src, sampleuv) * weightL;
        total += 2.0 * weightL;
    }

    return output / total;
}

void ps_normalize(float4 vpos : SV_POSITION,
                  float2 uv : TEXCOORD0,
                  out float2 r0 : SV_TARGET0)
{
    float3 c0 = max(tex2D(s_color, uv).rgb, 1e-3);
    c0 /= dot(c0, 1.0);
    r0 = c0.xy / max(max(c0.r, c0.g), c0.b);
}

void ps_blit(float4 vpos : SV_POSITION,
             float2 uv : TEXCOORD0,
             out float4 r0 : SV_TARGET0)
{
    r0.xy = tex2D(s_buffer, uv).xy;
    r0.zw = tex2D(s_cinfo1, uv).xy;
}

void ps_hblur(float4 vpos : SV_POSITION,
              float2 uv : TEXCOORD0,
              out float2 r0 : SV_TARGET0)
{
    r0 = blur2D(s_cinfo0, uv, float2(1.0, 0.0), ISIZE).xy;
}

void ps_vblur(float4 vpos : SV_POSITION,
              float2 uv : TEXCOORD0,
              out float2 r0 : SV_TARGET0)
{
    r0 = blur2D(s_cinfo1, uv, float2(0.0, 1.0), ISIZE).xy;
}

void ps_ddxy(float4 vpos : SV_POSITION,
             float2 uv : TEXCOORD0,
             out float2 r0 : SV_TARGET0,
             out float2 r1 : SV_TARGET1)
{
    const float2 psize = 1.0 / tex2Dsize(s_cinfo0, 0.0);
    float4 s_dx0 = tex2D(s_cinfo0, uv + float2(psize.x, 0.0));
    float4 s_dx1 = tex2D(s_cinfo0, uv - float2(psize.x, 0.0));
    float4 s_dy0 = tex2D(s_cinfo0, uv + float2(0.0, psize.y));
    float4 s_dy1 = tex2D(s_cinfo0, uv - float2(0.0, psize.y));
    r0.x = dot(s_dx0 - s_dx1, 1.0);
    r0.y = dot(s_dy0 - s_dy1, 1.0);
    r1 = tex2D(s_cinfo0, uv).rg;
}

void ps_oflow(float4 vpos: SV_POSITION,
              float2 uv : TEXCOORD0,
              out float4 r0 : SV_TARGET0)
{
    const float lambda = max(4.0 * pow(uConst * 1e-3, 2.0), 1e-10);
    const float pyramids = log2(ISIZE);
    float2 cFlow = 0.0;

    for(float i = pyramids; i >= 0; i -= 0.5)
    {
        float4 ucalc = float4(uv, 0.0, i);
        float4 frame = tex2Dlod(s_cinfo0, ucalc);
        float2 ddxy = tex2Dlod(s_cddxy, ucalc).xy;

        float dt = dot(frame.xy - frame.zw, 1.0);
        float dCalc = dot(ddxy.xy, cFlow) + dt;
        float dSmooth = rcp(dot(ddxy.xy, ddxy.xy) + lambda);
        cFlow = cFlow - ((ddxy.xy * dCalc) * dSmooth);
    }

    r0 = float4(cFlow.xy, 0.0, uBlend);
}

/*
    Uniforms: https://github.com/diwi/PixelFlow/blob/master/src/com/thomasdiewald/pixelflow/java/imageprocessing/DwOpticalFlow.java#L230
    Vertex Shader : https://github.com/diwi/PixelFlow/blob/master/src/com/thomasdiewald/pixelflow/glsl/OpticalFlow/renderVelocityStreams.vert
    Pixel Shader : https://github.com/diwi/PixelFlow/blob/master/src/com/thomasdiewald/pixelflow/glsl/OpticalFlow/renderVelocityStreams.frag
*/

#ifndef VERTEX_SPACING
    #define VERTEX_SPACING 10
#endif

#define LINES_X uint(BUFFER_WIDTH / VERTEX_SPACING)
#define LINES_Y uint(BUFFER_HEIGHT / VERTEX_SPACING)
#define NUM_LINES (LINES_X * LINES_Y)
#define SPACE_X (BUFFER_WIDTH / LINES_X)
#define SPACE_Y (BUFFER_HEIGHT / LINES_Y)
#define VELOCITY_SCALE (SPACE_X + SPACE_Y) * 1

void vs_output(in uint id : SV_VERTEXID,
               inout float4 position : SV_POSITION,
               inout float2 velocity : TEXCOORD0)
{
    // get line index / vertex index
    int line_id = id / 2;
    int vtx_id  = id % 2; // either 0 (line-start) or 1 (line-end)

    // get position (xy)
    int row = line_id / LINES_X;
    int col = line_id - LINES_X * row;

    // compute origin (line-start)
    const float2 spacing = float2(SPACE_X, SPACE_Y);
    float2 offset = spacing * 0.5;
    float2 origin = offset + float2(col, row) * spacing;

    // get velocity from texture at origin location
    const float2 wh_rcp = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    velocity = tex2Dlod(s_cflow, float4(origin.x * wh_rcp.x, 1.0 - origin.y * wh_rcp.y, 0.0, uDetail)).xy;

    // SCALE velocity
    float2 dir = velocity * VELOCITY_SCALE;

    float len = length(dir + 1e-5);
    dir = dir / sqrt(len * 0.1);

    // for fragmentshader ... coloring
    velocity = dir * 0.2;

    // compute current vertex position (based on vtx_id)
    float2 vtx_pos = (0.0);

    if(uNormal)
    {
        // lines, normal to velocity direction
        dir *= 0.5;
        float2 dir_n = float2(dir.y, -dir.x);
        vtx_pos = origin + dir - dir_n + dir_n * vtx_id * 2;
        // line_domain = 1.0;
    } else {
        // lines,in velocity direction
        vtx_pos = origin + dir * vtx_id;
        // line_domain = 1.0 - float(vtx_id);
    }

    // finish vertex coordinate
    float2 vtx_pos_n = (vtx_pos + 0.5) * wh_rcp; // [0, 1]
    position = float4(vtx_pos_n * 2.0 - 1.0, 0.0, 1.0); // ndc: [-1, +1]
}

float4 ps_output(float4 position : SV_POSITION,
                 float2 velocity : TEXCOORD0) : SV_Target
{
    float len = length(velocity) * VELOCITY_SCALE * 0.05;
    float3 outp;
    outp.rg = 0.5 * (1.0 + velocity.xy / (len + 1e-4));
    outp.b = 0.5 * (2.0 - dot(outp.rg, 1.0));
    return float4(outp, 1.0);
}

technique cOpticalFlow
{
    pass normalize
    {
        VertexShader = vs_generic;
        PixelShader = ps_normalize;
        RenderTarget0 = r_buffer;
    }

    pass scale_storeprevious
    {
        VertexShader = vs_generic;
        PixelShader = ps_blit;
        RenderTarget0 = r_cinfo0;
    }

    pass horizontalblur
    {
        VertexShader = vs_generic;
        PixelShader = ps_hblur;
        RenderTarget0 = r_cinfo1;
    }

    pass verticalblur
    {
        VertexShader = vs_generic;
        PixelShader = ps_vblur;
        RenderTarget0 = r_cinfo0;
        RenderTargetWriteMask = 1 | 2;
    }

    pass derivatives_copy
    {
        VertexShader = vs_generic;
        PixelShader = ps_ddxy;
        RenderTarget0 = r_cddxy;
        RenderTarget1 = r_cinfo1;
    }

    /*
        Smooth optical flow with BlendOps
        How it works:
            Src = Current optical flow
            Dest = Previous optical flow
            SRCALPHA = Blending weight between Src and Dest
            If SRCALPHA = 0.25, the blending would be
            Src * (1.0 - 0.25) + Dest * 0.25
            The previous flow's output gets quartered every frame
        Note:
            Disable ClearRenderTargets to blend with existing
            data in r_cflow before rendering
    */

    pass opticalflow
    {
        VertexShader = vs_generic;
        PixelShader = ps_oflow;
        RenderTarget0 = r_cflow;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVSRCALPHA;
        DestBlend = SRCALPHA;
    }

    pass output
    {
        PrimitiveTopology = LINELIST;
        VertexCount = NUM_LINES * 2;
        VertexShader = vs_output;
        PixelShader = ps_output;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = SRCALPHA;
        DestBlend = INVSRCALPHA;
        SrcBlendAlpha = ONE;
        DestBlendAlpha = ONE;
    }
}

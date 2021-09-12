
/*
    Optical flow motion blur using color by Brimson
    Special Thanks to
    - MartinBFFan and Pao on Discord for reporting bugs
    - BSD for bug propaganda and helping to solve my issue
    - Lord of Lunacy, KingEric1992, and Marty McFly for power of 2 function
*/

#include "cFunctions.fxh"

#define uOption(option, udata, utype, ucategory, ulabel, uvalue, umin, umax, utooltip)  \
        uniform udata option <                                                  		\
        ui_category = ucategory; ui_label = ulabel;                             		\
        ui_type = utype; ui_min = umin; ui_max = umax; ui_tooltip = utooltip;   		\
        > = uvalue

uOption(uConst, float, "slider", "Optical Flow", "Constraint", 1.000, 0.000, 2.000,
"Regularization: Higher = Smoother flow");

uOption(uBlend, float, "slider", "Post Process", "Temporal Smoothing", 0.250, 0.000, 0.500,
"Temporal Smoothing: Higher = Less temporal noise");

uOption(uDetail, float, "slider", "Post Process", "Flow Mipmap Bias", 4.500, 0.000, 7.000,
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
sampler2D s_lodbia { Texture = r_buffer; AddressU = MIRROR; AddressV = MIRROR; MipLODBias = 1.0; };
sampler2D s_cinfo0 { Texture = r_cinfo0; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cinfo1 { Texture = r_cinfo1; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cddxy  { Texture = r_cddxy; AddressU = MIRROR; AddressV = MIRROR; };

static const int step_count = 6;

static const float weights[step_count] =
{
	0.16501, 0.17507, 0.10112,
	0.04268, 0.01316, 0.00296
};

static const float offsets[step_count] =
{
	0.65772, 2.45017, 4.41096,
	6.37285, 8.33626, 10.30153
};

/* [ Pixel Shaders ] */

float4 blur2D(sampler2D src, float2 uv, float2 direction, float2 psize)
{
    float4 output;

    for (int i = 0; i < step_count; ++i) {
        const float2 texcoord_offset = offsets[i] * direction / psize;
        const float4 samples =
        tex2D(src, uv + texcoord_offset) +
        tex2D(src, uv - texcoord_offset);
        output += weights[i] * samples;
    }

    return output;
}

void ps_normalize(float4 vpos : SV_POSITION,
                  float2 uv : TEXCOORD0,
                  out float2 r0 : SV_TARGET0)
{
	r0 = normalize(tex2D(s_color, uv).rgb).xy;
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
              out float2 r0 : SV_TARGET0,
              out float2 r1 : SV_TARGET1)
{
    r0 = blur2D(s_cinfo1, uv, float2(0.0, 1.0), ISIZE).xy;
    r1.x = dot(ddx(r0), 1.0);
    r1.y = dot(ddy(r0), 1.0);
}

void ps_oflow(float4 vpos: SV_POSITION,
              float2 uv : TEXCOORD0,
              out float4 r0 : SV_TARGET0,
              out float4 r1 : SV_TARGET1)
{
    const float uRegularize = max(4.0 * pow(uConst * 1e-3, 2.0), 1e-10);
    const float pyramids = log2(ISIZE);
    float2 cFlow = 0.0;

    for(float i = pyramids; i >= 0; i -= 0.5)
    {
        float4 ucalc = float4(uv, 0.0, i);
        float4 frame = tex2Dlod(s_cinfo0, ucalc);
        float2 ddxy = tex2Dlod(s_cddxy, ucalc).xy;

        float dt = dot(frame.xy - frame.zw, 1.0);
        float dCalc = dot(ddxy.xy, cFlow) + dt;
        float dSmooth = rcp(dot(ddxy.xy, ddxy.xy) + uRegularize);
        cFlow = cFlow - ((ddxy.xy * dCalc) * dSmooth);
    }

    r0 = float4(cFlow.xy, 0.0, uBlend);
    r1 = float4(tex2D(s_cinfo0, uv).rgb, 0.0);
}

/*
    Uniforms: https://github.com/diwi/PixelFlow/blob/master/src/com/thomasdiewald/pixelflow/java/imageprocessing/DwOpticalFlow.java#L230
    Vertex Shader : https://github.com/diwi/PixelFlow/blob/master/src/com/thomasdiewald/pixelflow/glsl/OpticalFlow/renderVelocityStreams.vert
    Pixel Shader : https://github.com/diwi/PixelFlow/blob/master/src/com/thomasdiewald/pixelflow/glsl/OpticalFlow/renderVelocityStreams.frag
*/

#ifndef VERTEX_SPACING
    #define VERTEX_SPACING 8
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

    pass copy
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

    pass verticalblur_ddxy
    {
        VertexShader = vs_generic;
        PixelShader = ps_vblur;
        RenderTarget0 = r_cinfo0;
        RenderTarget1 = r_cddxy;
        RenderTargetWriteMask = 1 | 2;
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
        RenderTarget1 = r_cinfo1;
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

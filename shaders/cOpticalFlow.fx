
/*
    Optical flow motion blur using color by Brimson
    Special Thanks to
    - MartinBFFan and Pao on Discord for reporting bugs
    - BSD for bug propaganda and helping to solve my issue
    - Lord of Lunacy, KingEric1992, and Marty McFly for power of 2 function
*/

#include "cFunctions.fxh"

#define DSIZE uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)
#define RSIZE LOG2(RMAX(DSIZE.x, DSIZE.y)) + 1
#define FSIZE LOG2(RMAX(DSIZE.x / 2, DSIZE.y / 2)) + 1

#define uOption(option, udata, utype, ucategory, ulabel, uvalue, umin, umax, utooltip)  \
        uniform udata option <                                                  		\
        ui_category = ucategory; ui_label = ulabel;                             		\
        ui_type = utype; ui_min = umin; ui_max = umax; ui_tooltip = utooltip;   		\
        > = uvalue

uOption(uConst, float, "slider", "Optical Flow", "Constraint", 2.000, 0.000, 4.000,
"Regularization: Higher = Smoother flow");

uOption(uBlend, float, "slider", "Post Process", "Temporal Smoothing", 0.250, 0.000, 0.500,
"Temporal Smoothing: Higher = Less temporal noise");

uOption(uDetail, float, "slider", "Post Process", "Flow Mipmap Bias", 0.000, 0.000, FSIZE - 1,
"Postprocess Blur: Higher = Less spatial noise");

uOption(uNormal, bool, "radio", "Display", "Lines Normal Direction", false, 0, 0,
"Normal to velocity direction");

texture2D r_color  : COLOR;
texture2D r_pbuffer { Width = DSIZE.x; Height = DSIZE.y; Format = RGBA16; MipLevels = RSIZE; };
texture2D r_cbuffer { Width = DSIZE.x; Height = DSIZE.y; Format = RG16; MipLevels = RSIZE; };
texture2D r_cuddxy  { Width = DSIZE.x; Height = DSIZE.y; Format = RG16F; MipLevels = RSIZE; };
texture2D r_coflow  { Width = DSIZE.x / 2; Height = DSIZE.y / 2; Format = RG16F; MipLevels = FSIZE; };

sampler2D s_coflow  { Texture = r_coflow; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_color   { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_pbuffer { Texture = r_pbuffer; };
sampler2D s_cbuffer { Texture = r_cbuffer; };
sampler2D s_cuddxy  { Texture = r_cuddxy; };

/* [ Pixel Shaders ] */

void ps_convert(float4 vpos : SV_POSITION,
                float2 uv : TEXCOORD0,
                out float4 r0 : SV_TARGET0)
{
    // r0.xy = copy blurred frame from last run
    // r0.zw = blur current frame, than blur + copy at ps_filter
    // r1 = get derivatives from previous frame
    float3 uImage = tex2D(s_color, uv.xy).rgb;
    float3 output = uImage.rgb / dot(uImage.rgb , 1.0);
    float obright = max(max(output.r, output.g), output.b);
    r0.xy = tex2D(s_cbuffer, uv).xy;
    r0.zw = output.rg / obright;
}

void ps_filter(float4 vpos : SV_POSITION,
               float2 uv : TEXCOORD0,
               out float4 r0 : SV_TARGET0,
               out float4 r1 : SV_TARGET1)
{
    float4 uImage = tex2D(s_pbuffer, uv);
    r0 = uImage.zw;
    float2 cGrad;
    float2 pGrad;
    cGrad.x = dot(ddx(uImage.zw), 1.0);
    cGrad.y = dot(ddy(uImage.zw), 1.0);
    pGrad.x = dot(ddx(uImage.xy), 1.0);
    pGrad.y = dot(ddy(uImage.xy), 1.0);
    r1 = cGrad + pGrad;
}

/*
    https://www.cs.auckland.ac.nz/~rklette/CCV-CIMAT/pdfs/B08-HornSchunck.pdf
    - Use a regular image pyramid for input frames I(., .,t)
    - Processing starts at a selected level (of lower resolution)
    - Obtained results are used for initializing optic flow values at a
      lower level (of higher resolution)
    - Repeat until full resolution level of original frames is reached
*/

float4 ps_flow(float4 vpos : SV_POSITION,
               float2 uv : TEXCOORD0) : SV_Target
{
    const float uRegularize = max(4.0 * pow(uConst * 1e-2, 2.0), 1e-10);
    const float pyramids = (FSIZE) - 0.5;
    float2 cFlow = 0.0;

    for(float i = pyramids; i >= 0; i--)
    {
        float4 ucalc = float4(uv, 0.0, i);
        float2 cFrame = tex2Dlod(s_cbuffer, ucalc).xy;
        float2 pFrame = tex2Dlod(s_pbuffer, ucalc).xy;

        float2 ddxy = tex2Dlod(s_cuddxy, ucalc).xy;
        float dt = dot(cFrame - pFrame, 1.0);
        float dCalc = dot(ddxy.xy, cFlow) + dt;
        float dSmooth = rcp(dot(ddxy.xy, ddxy.xy) + uRegularize);
        cFlow = cFlow - ((ddxy.xy * dCalc) * dSmooth);
    }

    return float4(cFlow.xy, 0.0, uBlend);
}

/*
    Not working port of rendering flow streams
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
    const float2 wh_rcp = 0.5 / DSIZE;
    velocity = tex2Dlod(s_coflow, float4(origin.x * wh_rcp.x, 1.0 - origin.y * wh_rcp.y, 0.0, uDetail)).xy;

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
    outp.b = 0.5 * (2.0 - (outp.r + outp.g));
    return float4(outp, 1.0);
}

technique cOpticalFlow
{
    pass cNormalize
    {
        VertexShader = vs_generic;
        PixelShader = ps_convert;
        RenderTarget0 = r_pbuffer;
    }

    pass cProcessFrame
    {
        VertexShader = vs_generic;
        PixelShader = ps_filter;
        RenderTarget0 = r_cbuffer;
        RenderTarget1 = r_cuddxy;
    }

    pass cOpticalFlow
    {
        VertexShader = vs_generic;
        PixelShader = ps_flow;
        RenderTarget0 = r_coflow;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVSRCALPHA;
        DestBlend = SRCALPHA;
    }

    pass cOutput
    {
        PrimitiveTopology = LINELIST;
        VertexCount = NUM_LINES * 2;
        VertexShader = vs_output;
        PixelShader = ps_output;
    }
}

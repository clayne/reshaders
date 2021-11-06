/*
    Lite SMAA port for ReShade 4.0+
    - Color and medium setting exclusive
    - Depth rendertarget yoinked
    - Stripped so I can learn about AA better
*/

#include "cSMAA.fxh"

#define dTex(a, b, c) Width = ##a; Height = ##b; Format = ##c

texture2D colorTex : COLOR;

sampler2D colorLinearSampler
{
    Texture = colorTex;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

texture2D edgesTex < pooled = true; >
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RG8;
};

sampler2D edgesSampler
{
    Texture = edgesTex;
};

texture2D blendTex < pooled = true; >
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA8;
};

sampler2D blendSampler
{
    Texture = blendTex;
};

texture2D areaTex < source = "AreaTex.dds"; >
{
    Width = 160;
    Height = 560;
    Format = RG8;
};

sampler2D areaSampler
{
    Texture = areaTex;
};

texture2D searchTex < source = "SearchTex.dds"; >
{
    Width = 64;
    Height = 16;
    Format = R8;
};

sampler2D searchSampler
{
    Texture = searchTex;
    MipFilter = Point;
    MinFilter = Point;
    MagFilter = Point;
};

/*
    Color Edge Detection Pixel Shaders (First Pass)

    IMPORTANT NOTICE: color edge detection requires gamma-corrected colors, and
    thus 'colorTex' should be a non-sRGB texture.
*/

struct v2f_1
{
    float4 vpos   : SV_Position;
    float2 uv0    : TEXCOORD0;
    float4 uv1[3] : TEXCOORD1;
};

v2f_1 SMAAEdgeDetectionWrapVS(in uint id : SV_VertexID)
{
    v2f_1 o;

    float2 coord;
    coord.x = (id == 2) ? 2.0 : 0.0;
    coord.y = (id == 1) ? 2.0 : 0.0;
    o.vpos = float4(coord.xy * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    o.uv0 = coord;
    o.uv1[0] = mad(SMAA_RT_METRICS.xyxy, float4(-1.0, 0.0, 0.0, -1.0), coord.xyxy);
    o.uv1[1] = mad(SMAA_RT_METRICS.xyxy, float4( 1.0, 0.0, 0.0,  1.0), coord.xyxy);
    o.uv1[2] = mad(SMAA_RT_METRICS.xyxy, float4(-2.0, 0.0, 0.0, -2.0), coord.xyxy);
    return o;
}

float2 SMAAEdgeDetectionWrapPS(v2f_1 input) : SV_Target
{
    // Calculate the threshold:
    float2 threshold = float2(SMAA_THRESHOLD, SMAA_THRESHOLD);

    // Calculate color deltas:
    float4 delta;
    float3 C = tex2D(colorLinearSampler, input.uv0).rgb;

    float3 Cleft = tex2D(colorLinearSampler, input.uv1[0].xy).rgb;
    float3 t = abs(C - Cleft);
    delta.x = max(max(t.r, t.g), t.b);

    float3 Ctop  = tex2D(colorLinearSampler, input.uv1[0].zw).rgb;
    t = abs(C - Ctop);
    delta.y = max(max(t.r, t.g), t.b);

    // We do the usual threshold:
    float2 edges = step(threshold, delta.xy);

    // Then discard if there is no edge:
    if (dot(edges, float2(1.0, 1.0)) == 0.0) discard;

    // Calculate right and bottom deltas:
    float3 Cright = tex2D(colorLinearSampler, input.uv1[1].xy).rgb;
    t = abs(C - Cright);
    delta.z = max(max(t.r, t.g), t.b);

    float3 Cbottom  = tex2D(colorLinearSampler, input.uv1[1].zw).rgb;
    t = abs(C - Cbottom);
    delta.w = max(max(t.r, t.g), t.b);

    // Calculate the maximum delta in the direct neighborhood:
    float2 maxDelta = max(delta.xy, delta.zw);

    // Calculate left-left and top-top deltas:
    float3 Cleftleft  = tex2D(colorLinearSampler, input.uv1[2].xy).rgb;
    t = abs(Cleft - Cleftleft);
    delta.z = max(max(t.r, t.g), t.b);

    float3 Ctoptop = tex2D(colorLinearSampler, input.uv1[2].zw).rgb;
    t = abs(Ctop - Ctoptop);
    delta.w = max(max(t.r, t.g), t.b);

    // Calculate the final maximum delta:
    maxDelta = max(maxDelta.xy, delta.zw);
    float finalDelta = max(maxDelta.x, maxDelta.y);

    // Local contrast adaptation:
    edges.xy *= step(finalDelta, SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR * delta.xy);

    return edges;
}

/* Blending Weight Calculation Pixel Shader (Second Pass) */

struct v2f_2
{
    float4 vpos   : SV_Position;
    float4 uv0    : TEXCOORD0;
    float4 uv1[3] : TEXCOORD1;
};

v2f_2 SMAABlendingWeightCalculationWrapVS(in uint id : SV_VertexID)
{
    v2f_2 o;
    float2 coord;
    coord.x = (id == 2) ? 2.0 : 0.0;
    coord.y = (id == 1) ? 2.0 : 0.0;
    o.vpos = float4(coord.xy * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    o.uv0.xy = coord;
    o.uv0.zw = o.uv0.xy * SMAA_RT_METRICS.zw;

    // We will use these offsets for the searches later on (see @PSEUDO_GATHER4):
    o.uv1[0] = mad(SMAA_RT_METRICS.xyxy, float4(-0.25, -0.125,  1.25, -0.125), coord.xyxy);
    o.uv1[1] = mad(SMAA_RT_METRICS.xyxy, float4(-0.125, -0.25, -0.125,  1.25), coord.xyxy);

    // And these for the searches, they indicate the ends of the loops:
    o.uv1[2] = mad(SMAA_RT_METRICS.xxyy,
                    float2(-2.0, 2.0).xyxy * float(SMAA_MAX_SEARCH_STEPS),
                    float4(o.uv1[0].xz, o.uv1[1].yw));
    return o;
}

float4 SMAABlendingWeightCalculationWrapPS(v2f_2 input) : SV_Target
{
    float4 weights = float4(0.0, 0.0, 0.0, 0.0);
    float2 e = tex2D(edgesSampler, input.uv0.xy).rg;

    [branch]
    if (e.g > 0.0) { // Edge at north
        float2 d;

        // Find the distance to the left:
        float3 coords;
        coords.x = SMAASearchXLeft(edgesSampler, searchSampler, input.uv1[0].xy, input.uv1[2].x);
        coords.y = input.uv1[1].y;
        d.x = coords.x;

        // Now fetch the left crossing edges, two at a time using bilinear
        // filtering. Sampling at -0.25 (see @CROSSING_OFFSET) enables to
        // discern what value each edge has:
        float e1 = tex2Dlod(edgesSampler, coords.xyxy).r;

        // Find the distance to the right:
        coords.z = SMAASearchXRight(edgesSampler, searchSampler, input.uv1[0].zw, input.uv1[2].y);
        d.y = coords.z;

        // We want the distances to be in pixel units (doing this here allow to
        // better interleave arithmetic and memory accesses):
        d = abs(round(mad(SMAA_RT_METRICS.zz, d, -input.uv0.zz)));

        // SMAAArea below needs a sqrt, as the areas texture is compressed
        // quadratically:
        float2 sqrt_d = sqrt(d);

        // Fetch the right crossing edges:
        float e2 = tex2Dlod(edgesSampler, coords.zyzy, int2(1, 0)).r;

        // Ok, we know how this pattern looks like, now it is time for getting
        // the actual area:
        weights.rg = SMAAArea(areaSampler, sqrt_d, e1, e2, 0.0);

        // Fix corners:
        coords.y = input.uv0.y;
    }

    [branch]
    if (e.r > 0.0) { // Edge at west
        float2 d;

        // Find the distance to the top:
        float3 coords;
        coords.y = SMAASearchYUp(edgesSampler, searchSampler, input.uv1[1].xy, input.uv1[2].z);
        coords.x = input.uv1[0].x;
        d.x = coords.y;

        // Fetch the top crossing edges:
        float e1 = tex2Dlod(edgesSampler, coords.xyxy).g;

        // Find the distance to the bottom:
        coords.z = SMAASearchYDown(edgesSampler, searchSampler, input.uv1[1].zw, input.uv1[2].w);
        d.y = coords.z;

        // We want the distances to be in pixel units:
        d = abs(round(mad(SMAA_RT_METRICS.ww, d, -input.uv0.ww)));

        // SMAAArea below needs a sqrt, as the areas texture is compressed
        // quadratically:
        float2 sqrt_d = sqrt(d);

        // Fetch the bottom crossing edges:
        float e2 = tex2Dlod(edgesSampler, coords.xzxz, int2(0, 1)).g;

        // Get the area for this direction:
        weights.ba = SMAAArea(areaSampler, sqrt_d, e1, e2, 0.0);

        // Fix corners:
        coords.x = input.uv0.x;
    }

    return weights;
}

/* Neighborhood Blending Pixel Shader (Third Pass) */

struct v2f_3
{
    float4 vpos : SV_Position;
    float2 uv0  : TEXCOORD0;
    float4 uv1  : TEXCOORD1;
};

v2f_3 SMAANeighborhoodBlendingWrapVS(in uint id : SV_VertexID)
{
    v2f_3 o;
    float2 coord;
    coord.x = (id == 2) ? 2.0 : 0.0;
    coord.y = (id == 1) ? 2.0 : 0.0;
    o.vpos = float4(coord.xy * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    o.uv0 = coord;
    o.uv1 = mad(SMAA_RT_METRICS.xyxy, float4( 1.0, 0.0, 0.0,  1.0), coord.xyxy);
    return o;
}

float4 SMAANeighborhoodBlendingWrapPS(v2f_3 input) : SV_Target
{
    // Fetch the blending weights for current pixel:
    float4 a;
    a.x = tex2D(blendSampler, input.uv1.xy).a; // Right
    a.y = tex2D(blendSampler, input.uv1.zw).g; // Top
    a.wz = tex2D(blendSampler, input.uv0).xz; // Bottom / Left

    // Is there any blending weight with a value greater than 0.0?

    [branch]
    if (dot(a, float4(1.0, 1.0, 1.0, 1.0)) < 1e-5)
    {
        return tex2Dlod(colorLinearSampler, input.uv0.xyxy);
    } 
    else 
    {
        bool h = max(a.x, a.z) > max(a.y, a.w); // max(horizontal) > max(vertical)

        // Calculate the blending offsets:
        float4 blendingOffset = float4(0.0, a.y, 0.0, a.w);
        float2 blendingWeight = a.yw;
        SMAAMovc(bool4(h, h, h, h), blendingOffset, float4(a.x, 0.0, a.z, 0.0));
        SMAAMovc(bool2(h, h), blendingWeight, a.xz);
        blendingWeight /= dot(blendingWeight, float2(1.0, 1.0));

        // Calculate the texture coordinates:
        float4 blendingCoord = mad(blendingOffset, float4(SMAA_RT_METRICS.xy, -SMAA_RT_METRICS.xy), input.uv0.xyxy);

        // We exploit bilinear filtering to mix current pixel with the chosen neighbor:
        float4 color = blendingWeight.x * tex2Dlod(colorLinearSampler, blendingCoord.xyxy);
        color += blendingWeight.y * tex2Dlod(colorLinearSampler, blendingCoord.zwzw);
        return color;
    }
}

technique SMAA
{
    pass EdgeDetectionPass
    {
        VertexShader = SMAAEdgeDetectionWrapVS;
        PixelShader = SMAAEdgeDetectionWrapPS;
        RenderTarget = edgesTex;
        ClearRenderTargets = TRUE;
        StencilEnable = TRUE;
        StencilPass = REPLACE;
        StencilRef = 1;
    }

    pass BlendWeightCalculationPass
    {
        VertexShader = SMAABlendingWeightCalculationWrapVS;
        PixelShader = SMAABlendingWeightCalculationWrapPS;
        RenderTarget = blendTex;
        ClearRenderTargets = TRUE;
        StencilEnable = TRUE;
        StencilPass = KEEP;
        StencilFunc = EQUAL;
        StencilRef = 1;
    }

    pass NeighborhoodBlendingPass
    {
        VertexShader = SMAANeighborhoodBlendingWrapVS;
        PixelShader = SMAANeighborhoodBlendingWrapPS;
        StencilEnable = FALSE;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}

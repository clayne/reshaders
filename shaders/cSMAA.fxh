/*
    SMAA has three passes, chained together as follows:

    (input)-----------------------------+
    v                                   |
    [SMAA * EdgeDetection]              |
    v                                   |
    (edgesTex)                          |
    v                                   |
    [SMAABlendingWeightCalculation]     |
    v                                   |
    (blendTex)                          |
    v                                   |
    [SMAANeighborhoodBlending] <--------+
    v
    (output)

    Copyright (C) 2013 Jorge Jimenez (jorge@iryoku.com)
    Copyright (C) 2013 Jose I. Echevarria (joseignacioechevarria@gmail.com)
    Copyright (C) 2013 Belen Masia (bmasia@unizar.es)
    Copyright (C) 2013 Fernando Navarro (fernandn@microsoft.com)
    Copyright (C) 2013 Diego Gutierrez (diegog@unizar.es)

    Permission is hereby granted, free of charge, to any person obtaining a copy
    this software and associated documentation files (the "Software"), to deal in
    the Software without restriction, including without limitation the rights to
    use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
    of the Software, and to permit persons to whom the Software is furnished to
    do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software. As clarification, there
    is no requirement that the copyright notice and permission be included in
    binary distributions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
*/

#define SMAA_RT_METRICS float4(1.0 / BUFFER_WIDTH, 1.0 / BUFFER_HEIGHT, BUFFER_WIDTH, BUFFER_HEIGHT)
#define SMAA_THRESHOLD 0.1
#define SMAA_MAX_SEARCH_STEPS 8

/*
    If there is an neighbor edge that has SMAA_LOCAL_CONTRAST_FACTOR times
    bigger contrast than current edge, current edge will be discarded.

    This allows to eliminate spurious crossing edges, and is based on the fact
    that, if there is too much contrast in a direction, that will hide
    perceptually contrast in the other neighbors.
*/

#ifndef SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR
    #define SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR 2.0
#endif

// Non-Configurable Defines

#define SMAA_AREATEX_MAX_DISTANCE 16
#define SMAA_AREATEX_MAX_DISTANCE_DIAG 20
#define SMAA_AREATEX_PIXEL_SIZE (1.0 / float2(160.0, 560.0))
#define SMAA_AREATEX_SUBTEX_SIZE (1.0 / 7.0)
#define SMAA_SEARCHTEX_SIZE float2(66.0, 33.0)
#define SMAA_SEARCHTEX_PACKED_SIZE float2(64.0, 16.0)
#define SMAA_CORNER_ROUNDING_NORM (float(SMAA_CORNER_ROUNDING) / 100.0)

/* Misc functions */

/* Conditional move: */

void SMAAMovc(bool2 cond, inout float2 variable, float2 value)
{
    [flatten] if (cond.x) variable.x = value.x;
    [flatten] if (cond.y) variable.y = value.y;
}

void SMAAMovc(bool4 cond, inout float4 variable, float4 value)
{
    SMAAMovc(cond.xy, variable.xy, value.xy);
    SMAAMovc(cond.zw, variable.zw, value.zw);
}

/*
    Horizontal/Vertical Search Functions

    This allows to determine how much length should we add in the last step
    of the searches. It takes the bilinearly interpolated edge (see
    @PSEUDO_GATHER4), and adds 0, 1 or 2, depending on which edges and
    crossing edges are active.
*/

float SMAASearchLength( sampler2D searchTex, float2 e, float offset)
{
    // The texture is flipped vertically, with left and right cases taking half
    // of the space horizontally:
    float2 scale = SMAA_SEARCHTEX_SIZE * float2(0.5, -1.0);
    float2 bias = SMAA_SEARCHTEX_SIZE * float2(offset, 1.0);

    // Scale and bias to access texel centers:
    scale += float2(-1.0,  1.0);
    bias  += float2( 0.5, -0.5);

    // Convert from pixel coordinates to texcoords:
    // (We use SMAA_SEARCHTEX_PACKED_SIZE because the texture is cropped)
    scale *= 1.0 / SMAA_SEARCHTEX_PACKED_SIZE;
    bias *= 1.0 / SMAA_SEARCHTEX_PACKED_SIZE;

    // Lookup the search texture:
    return tex2Dlod(searchTex, mad(scale, e, bias).xyxy).r;
}


/* Horizontal/vertical search functions for the 2nd pass. */

float SMAASearchXLeft(sampler2D edgesTex, sampler2D searchTex, float2 texcoord, float end)
{
    /*
        @PSEUDO_GATHER4
        This texcoord has been offset by (-0.25, -0.125) in the vertex shader to
        sample between edge, thus fetching four edges in a row.
        Sampling with different offsets in each direction allows to disambiguate
        which edges are active from the four fetched ones.
    */

    float2 e = float2(0.0, 1.0);
    while (texcoord.x > end &&
           e.g > 0.8281 && // Is there some edge not activated?
           e.r == 0.0) { // Or is there a crossing edge that breaks the line?
        e = tex2Dlod(edgesTex, texcoord.xyxy).rg;
        texcoord = mad(-float2(2.0, 0.0), SMAA_RT_METRICS.xy, texcoord);
    }

    float offset = mad(-(255.0 / 127.0), SMAASearchLength(searchTex, e, 0.0), 3.25);
    return mad(SMAA_RT_METRICS.x, offset, texcoord.x);
}

float SMAASearchXRight(sampler2D edgesTex, sampler2D searchTex, float2 texcoord, float end)
{
    float2 e = float2(0.0, 1.0);
    while (texcoord.x < end &&
           e.g > 0.8281 && // Is there some edge not activated?
           e.r == 0.0) { // Or is there a crossing edge that breaks the line?
        e = tex2Dlod(edgesTex, texcoord.xyxy).rg;
        texcoord = mad(float2(2.0, 0.0), SMAA_RT_METRICS.xy, texcoord);
    }
    float offset = mad(-(255.0 / 127.0), SMAASearchLength(searchTex, e, 0.5), 3.25);
    return mad(-SMAA_RT_METRICS.x, offset, texcoord.x);
}

float SMAASearchYUp(sampler2D edgesTex, sampler2D searchTex, float2 texcoord, float end)
{
    float2 e = float2(1.0, 0.0);
    while (texcoord.y > end &&
           e.r > 0.8281 && // Is there some edge not activated?
           e.g == 0.0) { // Or is there a crossing edge that breaks the line?
        e = tex2Dlod(edgesTex, texcoord.xyxy).rg;
        texcoord = mad(-float2(0.0, 2.0), SMAA_RT_METRICS.xy, texcoord);
    }
    float offset = mad(-(255.0 / 127.0), SMAASearchLength(searchTex, e.gr, 0.0), 3.25);
    return mad(SMAA_RT_METRICS.y, offset, texcoord.y);
}

float SMAASearchYDown(sampler2D edgesTex, sampler2D searchTex, float2 texcoord, float end)
{
    float2 e = float2(1.0, 0.0);
    while (texcoord.y < end &&
           e.r > 0.8281 && // Is there some edge not activated?
           e.g == 0.0) { // Or is there a crossing edge that breaks the line?
        e = tex2Dlod(edgesTex, texcoord.xyxy).rg;
        texcoord = mad(float2(0.0, 2.0), SMAA_RT_METRICS.xy, texcoord);
    }
    float offset = mad(-(255.0 / 127.0), SMAASearchLength(searchTex, e.gr, 0.5), 3.25);
    return mad(-SMAA_RT_METRICS.y, offset, texcoord.y);
}

/*
    Ok, we have the distance and both crossing edges. So, what are the areas
    at each side of current edge?
*/

float2 SMAAArea(sampler2D areaTex, float2 dist, float e1, float e2, float offset)
{
    // Rounding prevents precision errors of bilinear filtering:
    float2 texcoord = mad(float2(SMAA_AREATEX_MAX_DISTANCE, SMAA_AREATEX_MAX_DISTANCE), round(4.0 * float2(e1, e2)), dist);

    // We do a scale and bias for mapping to texel space:
    texcoord = mad(SMAA_AREATEX_PIXEL_SIZE, texcoord, 0.5 * SMAA_AREATEX_PIXEL_SIZE);

    // Move to proper place, according to the subpixel offset:
    texcoord.y = mad(SMAA_AREATEX_SUBTEX_SIZE, offset, texcoord.y);

    // Do it!
    return tex2Dlod(areaTex, texcoord.xyxy).rg;
}

/*

    https://marcelsheeny.files.wordpress.com/2016/06/screen-space-anti.pdf
*/

// use backbuffer for now and get the normiemap from bsd

texture2D r_source : COLOR
texture2D r_normal { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };

sampler2D s_source { Texture = r_source; };
sampler2D s_normal { Texture = r_normal; };

struct vs2ps
{
    float4 vpos : SV_POSITION;
    float2 uv : TEXCOORD0;
};

// Algorithm 6: Neighbourhood blending
vs2ps vs_sraa(const uint id : SV_VERTEXID)
{
    vs2ps output;
    output.uv.x = (id == 2) ? 2.0 : 0.0;
    output.uv.y = (id == 1) ? 2.0 : 0.0;
    output.vpos = float4(output.uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

// Algorithm 8: SRAA filter

float Bilateral(
    float3 kCenterNormal,
    float  fCenterDepth,
    float3 kSampleNormal,
    float  fTapDepth)
{
    float dNormal = 1.0 - dot(kCenterNormal, kSampleNormal);
    float dDepth = abs(fCenterDepth - fTapDepth);
    const float T = 50.0;
    return exp(-T * max(dNormal, dDepth));
}

// Wait a second, this is done in one pass ?!?

float4 ps_sraa(vs2ps input) : COLOR
{
    /*
        Algorithm 7: Getting the information of the surrounding pixels
    */

    float afWeights[9];
    float fSum = 0.0f;
    int2 kCenterSample = int2(input.uv);

    // First geometric sample in pixel
    float4 kNormalDepth = tex2D(s_normal, kCenterSample);
    float3 kNormal = kNormalDepth.xyz;

    // Sample geometry of surrounding shaded samples and compute weight for each
    for (int j = 0; j < 3; j++)
    {
        for (int i = 0; i < 3; i++)
        {
            int2 kSample = kCenterSample + int2(i-1, j-1);

            // Sample tap
            int2 kSampleNormalDepth = tex2D(s_normal, kSample);

            // Compute weight
            float3 kSampleNormal = kSampleNormalDepth.xyz;
    
            float fW = Bilateral(kNormal, kNormalDepth.w, kSampleNormal, kSampleNormalDepth.w);
            afWeights[i + j * 3] = fW;
            fSum += fW;
        }
    }

    /*
        Algorithm 9: Reconstructing the final color
    */

    // Reconstruct color for this sample
    float3 kReconstructedColor = 0.0;
    for (int j = -1; j < 2; j++)
    {
        for (int i = -1; i < 2; i++)
        {
            int2 kSample = input.uv + int2(i, j) * kTexelSize;
            kReconstructedColor += afWeights[(i+1) + (j+1) * 3] / fSum *
            tex2D(s_source, kSample).xyz;
        }
    }

    return kReconstructedColor;
}

technique SRAA 
{
    /*
        {
            VertexShader = vs_sraa;
            PixelShader = ps_sraa_normals;
            RenderTarget = r_normal;
        }
    */
    pass
    {
        VertexShader = vs_sraa;
        PixelShader = ps_sraa;
    }
}
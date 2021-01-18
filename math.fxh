// From https://github.com/crosire/reshade-shaders/wiki/Shader-Tips-Tricks-and-Optimizations

namespace math
{
    // sqrt(a)
    float  sqrt(float  a) { return a * rsqrt(a); }
    float2 sqrt(float2 a) { return a * rsqrt(a); }
    float3 sqrt(float3 a) { return a * rsqrt(a); }
    float4 sqrt(float4 a) { return a * rsqrt(a); }

    // a.x + a.y + a.z + a.w
    float2 dpadd(float2 a) { return dot(a, 1.0); }
    float3 dpadd(float3 a) { return dot(a, 1.0); }
    float4 dpadd(float4 a) { return dot(a, 1.0); }

    // smoothstep(0.0, 1.0, a)
    float  smoothstep(float  a) { return a * a * (3.0 - 2.0 * a); }
    float2 smoothstep(float2 a) { return a * a * (3.0 - 2.0 * a); }
    float3 smoothstep(float3 a) { return a * a * (3.0 - 2.0 * a); }
    float4 smoothstep(float4 a) { return a * a * (3.0 - 2.0 * a); }

    // cross(a, cross(b, c))
    float2 ccross(float2 a, float2 b, float2 c) { return b * dot(a, c) - c * dot(a, b); }
    float3 ccross(float3 a, float3 b, float3 c) { return b * dot(a, c) - c * dot(a, b); }
    float4 ccross(float4 a, float4 b, float4 c) { return b * dot(a, c) - c * dot(a, b); }

    namespace exp
    {
        // exp(a) * exp(b)
        float  mul(float  a, float  b) { return exp(a + b); }
        float2 mul(float2 a, float2 b) { return exp(a + b); }
        float3 mul(float3 a, float3 b) { return exp(a + b); }
        float4 mul(float4 a, float4 b) { return exp(a + b); }

        // pow(pow(a, b), c)
        float  pow(float  a, float  b, float  c) { return math::pow(a, b * c); }
        float2 pow(float2 a, float2 b, float2 c) { return math::pow(a, b * c); }
        float3 pow(float3 a, float3 b, float3 c) { return math::pow(a, b * c); }
        float4 pow(float4 a, float4 b, float4 c) { return math::pow(a, b * c); }
    }

    namespace pow
    {
        // pow(a, 1.5)
        float  _15(float  a) { return (a * a) * rsqrt(a); }
        float2 _15(float2 a) { return (a * a) * rsqrt(a); }
        float3 _15(float3 a) { return (a * a) * rsqrt(a); }
        float4 _15(float4 a) { return (a * a) * rsqrt(a); }

        // a / pow(b, c)
        float  div(float  a, float  b, float  c) { return a * math::pow(b, -c); }
        float2 div(float2 a, float2 b, float2 c) { return a * math::pow(b, -c); }
        float3 div(float3 a, float3 b, float3 c) { return a * math::pow(b, -c); }
        float4 div(float4 a, float4 b, float4 c) { return a * math::pow(b, -c); }
    }

    namespace log
    {
        // log(a) + log(b)
        float  add(float  a, float  b) { return log(a * b); }
        float2 add(float2 a, float2 b) { return log(a * b); }
        float3 add(float3 a, float3 b) { return log(a * b); }
        float4 add(float4 a, float4 b) { return log(a * b); }

        // log(a / b)
        float  div(float  a, float  b) { return log(a) - log(b); }
        float2 div(float2 a, float2 b) { return log(a) - log(b); }
        float3 div(float3 a, float3 b) { return log(a) - log(b); }
        float4 div(float4 a, float4 b) { return log(a) - log(b); }

        // log(pow(a, b))
        float  pow(float  a, float  b) { return b * log(a); }
        float2 pow(float2 a, float2 b) { return b * log(a); }
        float3 pow(float3 a, float3 b) { return b * log(a); }
        float4 pow(float4 a, float4 b) { return b * log(a); }

        // log(sqrt(a))
        float  sqrt(float  a) { return log(a) * 0.5; }
        float2 sqrt(float2 a) { return log(a) * 0.5; }
        float3 sqrt(float3 a) { return log(a) * 0.5; }
        float4 sqrt(float4 a) { return log(a) * 0.5; }
    }
}

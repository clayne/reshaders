// From https://github.com/crosire/reshade-shaders/wiki/Shader-Tips-Tricks-and-Optimizations

namespace math
{
	// sqrt(a)
	float  sqrt(float  a) { return a * rsqrt(a); }
	float2 sqrt(float2 a) { return a * rsqrt(a); }
	float3 sqrt(float3 a) { return a * rsqrt(a); }
	float4 sqrt(float4 a) { return a * rsqrt(a); }

	// pow(a, b)
	float  pow(float  a, float  b) { return exp2(log2(a) * b); }
	float2 pow(float2 a, float2 b) { return exp2(log2(a) * b); }
	float3 pow(float3 a, float3 b) { return exp2(log2(a) * b); }
	float4 pow(float4 a, float4 b) { return exp2(log2(a) * b); }

	// a.x + a.y + a.z + a.w
	float2 dpadd(float2 a) { return dot(a, 1.0); }
	float3 dpadd(float3 a) { return dot(a, 1.0); }
	float4 dpadd(float4 a) { return dot(a, 1.0); }

	// smoothstep(0.0, 1.0, a)
	float  smoothstep(float  a) { return a * a * (3.0 - 2.0 * a); }
	float2 smoothstep(float2 a) { return a * a * (3.0 - 2.0 * a); }
	float3 smoothstep(float3 a) { return a * a * (3.0 - 2.0 * a); }
	float4 smoothstep(float4 a) { return a * a * (3.0 - 2.0 * a); }

	// pow(a, 1.5)
	float  pow15(float  a) { return (a * a) * rsqrt(a); }
	float2 pow15(float2 a) { return (a * a) * rsqrt(a); }
	float3 pow15(float3 a) { return (a * a) * rsqrt(a); }
	float4 pow15(float4 a) { return (a * a) * rsqrt(a); }

	// exp(a) * exp(b)
	float  expmul(float  a, float  b) { return exp(a + b); }
	float2 expmul(float2 a, float2 b) { return exp(a + b); }
	float3 expmul(float3 a, float3 b) { return exp(a + b); }
	float4 expmul(float4 a, float4 b) { return exp(a + b); }

	// pow(pow(a, b), c)
	float  exppow(float  a, float  b, float  c) { return math::pow(a, b * c); }
	float2 exppow(float2 a, float2 b, float2 c) { return math::pow(a, b * c); }
	float3 exppow(float3 a, float3 b, float3 c) { return math::pow(a, b * c); }
	float4 exppow(float4 a, float4 b, float4 c) { return math::pow(a, b * c); }

	// a / pow(b, c)
	float  divpow(float  a, float  b, float  c) { return a * math::pow(b, -c); }
	float2 divpow(float2 a, float2 b, float2 c) { return a * math::pow(b, -c); }
	float3 divpow(float3 a, float3 b, float3 c) { return a * math::pow(b, -c); }
	float4 divpow(float4 a, float4 b, float4 c) { return a * math::pow(b, -c); }

	// log(a) + log(b)
	float  logadd(float  a, float  b) { return log(a * b); }
	float2 logadd(float2 a, float2 b) { return log(a * b); }
	float3 logadd(float3 a, float3 b) { return log(a * b); }
	float4 logadd(float4 a, float4 b) { return log(a * b); }

	// log(a / b)
	float  logdiv(float  a, float  b) { return log(a) - log(b); }
	float2 logdiv(float2 a, float2 b) { return log(a) - log(b); }
	float3 logdiv(float3 a, float3 b) { return log(a) - log(b); }
	float4 logdiv(float4 a, float4 b) { return log(a) - log(b); }

	// log(pow(a, b))
	float  logpow(float  a, float  b) { return b * log(a); }
	float2 logpow(float2 a, float2 b) { return b * log(a); }
	float3 logpow(float3 a, float3 b) { return b * log(a); }
	float4 logpow(float4 a, float4 b) { return b * log(a); }

	// log(sqrt(a))
	float  logsqrt(float  a) { return log(a) * 0.5; }
	float2 logsqrt(float2 a) { return log(a) * 0.5; }
	float3 logsqrt(float3 a) { return log(a) * 0.5; }
	float4 logsqrt(float4 a) { return log(a) * 0.5; }

	// cross(a, cross(b, c))
	float2 ccross(float2 a, float2 b, float2 c) { return b * dot(a, c) - c * dot(a, b); }
	float3 ccross(float3 a, float3 b, float3 c) { return b * dot(a, c) - c * dot(a, b); }
	float4 ccross(float4 a, float4 b, float4 c) { return b * dot(a, c) - c * dot(a, b); }
}

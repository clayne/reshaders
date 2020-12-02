// From https://github.com/crosire/reshade-shaders/wiki/Shader-Tips-Tricks-and-Optimizations

namespace math
{
    dp2add(float4 a) { return dot(a, 1.0); }
    dp3add(float4 a) { return dot(a, 1.0); }

}
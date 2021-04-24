
/*
    https://github.com/keijiro/Kino :: Unlicense

    This is free and unencumbered software released into the public domain.

    Anyone is free to copy, modify, publish, use, compile, sell, or
    distribute this software, either in source code form or as a compiled
    binary, for any purpose, commercial or non-commercial, and by any
    means.

    In jurisdictions that recognize copyright laws, the author or authors
    of this software dedicate any and all copyright interest in the
    software to the public domain. We make this dedication for the benefit
    of the public at large and to the detriment of our heirs and
    successors. We intend this dedication to be an overt act of
    relinquishment in perpetuity of all present and future rights to this
    software under copyright law.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
    OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
    ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
    OTHER DEALINGS IN THE SOFTWARE.

    For more information, please refer to <http://unlicense.org/>
*/

uniform float intensity <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "Sharpen";
    ui_tooltip = "Increase to sharpen details within the image.";
> = 0.05;

texture2D r_color : COLOR;
sampler2D s_color
{
    Texture = r_color;
    #if BUFFER_COLOR_BIT_DEPTH != 10
        SRGBTexture = true;
    #endif
};

struct v2f { float4 vpos  : SV_Position; float4 uv[5] : TEXCOORD0; };

static const float2 s = float2(BUFFER_WIDTH, BUFFER_HEIGHT);

int2 offset(int2 i) { return min(max(0, i), s - 1); }

v2f vs_sharpen(in uint id : SV_VertexID)
{
    v2f o;
    float2 texcoord;
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    o.vpos = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    const float2 p = 1.0 / s;
    o.uv[0].xy = offset(int2(-1, -1)) * p + texcoord; // (-1,-1)
    o.uv[0].zw = offset(int2( 0, -1)) * p + texcoord; // ( 0,-1)
    o.uv[1].xy = offset(int2(+1, -1)) * p + texcoord; // ( 1,-1)
    o.uv[1].zw = offset(int2(-1,  0)) * p + texcoord; // ( 1, 0)
    o.uv[2].xy = offset(int2( 0,  0)) * p + texcoord; // (-1, 1)
    o.uv[2].zw = offset(int2(+1,  0)) * p + texcoord; // ( 1, 0)
    o.uv[3].xy = offset(int2(-1, +1)) * p + texcoord; // ( 0, 1)
    o.uv[3].zw = offset(int2( 0, +1)) * p + texcoord; // ( 1, 1)
    o.uv[4].xy = offset(int2(+1, +1)) * p + texcoord; // ( 0, 0)
    o.uv[4].zw = 0.0;
    return o;
}

void ps_sharpen(v2f input, out float4 c : SV_Target)
{
    float4 c0 = tex2D(s_color, input.uv[0].xy);
    float4 c1 = tex2D(s_color, input.uv[0].zw);
    float4 c2 = tex2D(s_color, input.uv[1].xy);

    float4 c3 = tex2D(s_color, input.uv[1].zw);
    float4 c4 = tex2D(s_color, input.uv[2].xy);
    float4 c5 = tex2D(s_color, input.uv[2].zw);

    float4 c6 = tex2D(s_color, input.uv[3].xy);
    float4 c7 = tex2D(s_color, input.uv[3].zw);
    float4 c8 = tex2D(s_color, input.uv[4].xy);

    c = c4 - (c0 + c1 + c2 + c3 - 8 * c4 + c5 + c6 + c7 + c8) * intensity;
}

technique KinoSharpen
{
    pass
    {
        VertexShader = vs_sharpen;
        PixelShader = ps_sharpen;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
    }
}

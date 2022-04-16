
# Shaders and More

## ...Why?

+ Fun
+ New developers can learn
+ Coping mechanism

## Goals

+ More mosiac shapes
+ Cascade multigrid fluid simulation

## Shaders

> Visit [my gist](https://gist.github.com/brimson) if you want ShaderToy ports

Name|Description
----|-----------
buggyassshaderlmao  | Shader that seems to cause problems on ReShade
cAbberation         | Chromatic abberation using vertex shader offset
cAutoExposure       | 2-pass automatic exposure
cBloom              | Dual-filtering bloom
cBlur               | Convolution using Vogel spiral sampling
cCheckerBoard       | Customizable 2-pattern checkerboard
cColorBlendOp       | Blend to backbuffer without copying textures
cColorNormalization | Various color normalization algoritms
cDefault            | Initialize graphics pipeline (useful for comparing effects)
cDualFilter         | Pyramidal convolutions (box, Jorge Jimenez, and Kawase)
cEdgeDetection      | Edge detection kernels (4 bilinear, 2 discrete)
cFilmGrain          | Film grain without copying texture
cFrameBlending      | Frame blending using the previous result
cGaussianBlur       | HLSL implementation of RasterGrid's linear Gaussian blur
cInterpolation      | Optical flow frame blending
cLetterBox          | LetterBox without copying textures
cLuminance          | Various grayscale algoritms
cMedian             | 3x3 median filter
cMotionBlur         | Color motion blur
cMotionMask         | Frame masking based on temporal derivative
cNoiseConvolution   | Convolution using rotated gradient noise sampling
cOpticalFlow        | HLSL implementation of pyramidal Horn Schunck with visualization
cOverlay            | Simple backbuffer overlay
cPingPong           | Gaussian blur approximation using ping-pong box blurs
cScale              | Buffer scaling using vertex shaders
cShard              | Simple unmask sharpening
cSimplexNoise       | Simple noise and noise warp shader
cSMAA               | Minimalist version of SMAA, medium setting
cSrcDestBlend       | Backbuffer blending
cThreshold          | Quadratic color thresholding
kContour            | Contour line effect
kDatamosh           | Simulates video compression artifacts
kMirror             | Mirroring and kaleidoscope effect
kVignette           | Natural vignetting effect

## Coding Convention

Practice | Variable
-------- | --------
**ALLCAPS**     | System-Value semantics, state parameters
**ALL_CAPS**    | Preprocessor macros and parameters
**SnakeCase**   | Discrete local and global data
**Snake_Case**  | Namespace, structs, functions, textures, sampler, and packed data (i.e. `float4 TexCoord_Base_Water` stores 2 UVs for 2 textures, base and water)
**_Snake_Case** | Uniform data
Suffix `VS` and `PS` | `PixelShader` and `VertexShader`

## Acknowledgements

+ MartinBFFan and Pao on Discord for reporting bugs
+ BSD for bug propaganda and helping to solve my issue
+ TheGordinho for listening ear and funnies

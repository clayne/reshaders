
# Shaders and More

## ...Why?

+ Fun
+ New developers can learn
+ Coping mechanism
+ **Goals**
  + More mosiac shapes
  + Fluid simulation
  + V-Cycle multigrid algorithm

## Shaders

> Visit [my gist](https://gist.github.com/brimson) if you want ShaderToy ports

Name|Description
----|-----------
buggyassshaderlmao  | Shader that seems to cause problems on ReShade
cAbberation         | Chromatic abberation using vertex shader offset
cAutoExposure       | 2-pass automatic exposure
cBloom              | Dual-filtering bloom
cCheckerBoard       | Customizable 2-pattern checkerboard
cColorBlendOp       | Blend to backbuffer without copying textures
cColorNormalization | Various color normalization algoritms
cDefault            | Initialize graphics pipeline (useful for comparing effects)
cFilmGrain          | Film grain without copying texture
cFrameBlending      | Frame blending using the previous result
cFrameDifference    | Frame differencing
cGaussianBlur       | HLSL implementation of RasterGrid's linear Gaussian blur
cInterpolation      | Optical flow frame blending
cLetterBox          | LetterBox without copying textures
cLuminance          | Various grayscale algoritms
cMedian             | 3x3 median filter
cMotionBlur         | Optical flow motion blur
cOpticalFlow        | Display optical flow with lines or shading
cPingPong           | Gaussian blur approximation using ping-pong box blurs
cSMAA               | Minimalist version of SMAA, medium setting
cShard              | Simple unmask sharpening
cSrcDestBlend       | Backbuffer blending
cThreshold          | Quadratic color thresholding
cTile               | Buffer scaling using vertex shaders
kContour            | Contour line effect
kDatamosh           | Simulates video compression artifacts
kMirror             | Mirroring and kaleidoscope effect
kVignette           | Natural vignetting effect

## Coding Convention

Practice | Variable
-------- | --------
Prefix `_` | Global objects and parameters
Respectively suffix `VS` and `PS` | `PixelShader and VertexShader`
**ALLCAPS** | Semantics and state parameters
**Pascal_Case** | System-Value Semantics (`SV_Position`)
**PascalCase** | Namespaces, structs, methods, and local parameters
**SNAKE_CASE** | Macros and preprocessor defines

## Acknowledgements

+ MartinBFFan and Pao on Discord for reporting bugs
+ BSD for bug propaganda and helping to solve my issue


# Shaders and More

## ...Why?

+ Fun
+ New developers can learn
+ Coping mechanism
+ **Goals**
  + More mosiac shapes
  + Fluid simulation
  + V-Cycle multigrid algorithm

## Shader List

Name|Description
----|-----------
cAbberation         | Chromatic abberation using vertex shader offset
cAutoExposure       | 2-pass automatic exposure
cBloom              | Dual-filtering bloom
cColorBlendOp       | Blend to backbuffer without copying textures
cColorNormalization | Various color normalization algoritms
cFilmGrain          | Film grain without copying texture
cFrameBlending      | Frame blending using the previous result
cFrameDifference    | Frame differencing
cInterpolation      | Optical flow frame blending
cLetterBox          | LetterBox without copying textures
cLuminance          | Various grayscale algoritms
cMipLevels          | Manual mipmap calculation
cMosaic             | Few mosiac algorithms with mipmaps
cMotionBlur         | Optical flow motion blur
cOpticalFlow        | Display optical flow with lines or shading
cPingPong           | Gaussian blur approximation using ping-pong box blurs
cPureDepthAO        | **Experimental** ambient occlusion
cSMAA               | Minimalist version of SMAA, medium setting
cShard              | Simple unmask sharpening
cSrcDestBlend       | Backbuffer blending
cThreshold          | Quadratic color thresholding
cTile               | Buffer scaling using vertex shaders
cTonemap            | Watch Dog's tonemapping with gamma correction
kContour            | Contour line effect
kDatamosh           | Simulates video compression artifacts
kMirror             | Mirroring and kaleidoscope effect
kVignette           | Natural vignetting effect

## Coding Convention

Coded with [ReShadeFX Conventions](https://github.com/crosire/reshade-shaders/blob/slim/REFERENCE.md)



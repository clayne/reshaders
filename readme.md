
# Shaders and More

## ...Why?
- Fun
- New developers can learn
- Coping mechanism
- **Goals**
  - Pyramid optical flow
  - General greyscale
  - Datamoshing
  - Particles (maybe)
  - Fluid simulation (maybe)
  - cFunctions.fxh with namespaces

## Shader Descriptions
- Original: Shaders I made
- Original+: Shaders I also made, also for people who want to learn shaders
- keijiro: [keijiro](https://github.com/keijiro) ports
- Misc: Shaders I modified as what-ifs

Type|Name|Description
----|----|-----------
Original|cBloom      |Dual-filtering bloom
Original|cBlur       |Blur approximation using vogel disks
Original|cInterpolate|Optical flow frame blending
Original|cMotionBlur |Optical flow motion blur
Original|cOpticalFlow|Horn-Schunck optical flow without weighted average
Original+|cAbberation   |Chromatic abberation using vertex shader offset
Original+|cAutoExposure |2-pass automatic exposure
Original+|cColorBlendOp |Blend to backbuffer without copying textures
Original+|cFilmGrain    |Film grain without copying texture
Original+|cFrameBlending|Frame blending using the previous result
Original+|cLuminance    |Simple greyscale comparison
Original+|cLetterBox    |LetterBox without copying textures
Original+|cScale        |Buffer scaling using vertex shaders
keijiro|kContour |Contour line effect
keijiro|kMirror  |Mirroring and kaleidoscope effect
keijiro|kVignette|Natural vignetting effect
Misc|cCAS    |SweetFX's CAS but using vertex shader as offset
Misc|cSMAA   |Minimalist version of SMAA, medium setting
Misc|cTonemap|Watch Dog's tonemapping with gamma correction

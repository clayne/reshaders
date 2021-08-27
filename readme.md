
# Shaders and More

## ...Why?
- Fun
- New developers can learn
- Coping mechanism
- **Goals**
  - Datamoshing
  - Particles (maybe)
  - Fluid simulation (maybe)

## Shader Descriptions
- (!) : Original shader
- (+) : Shaders I made for people who want to learn shaders
- (k) : [keijiro](https://github.com/keijiro) ports
- (~) : Shaders I modified as what-ifs

Name|Description
----|-----------
(+) cAbberation     | Chromatic abberation using vertex shader offset
(+) cAutoExposure   | 2-pass automatic exposure
(!) cBloom          | Dual-filtering bloom
(!) cBlur           | Blur approximation using vogel disks
(~) cCAS            | SweetFX's CAS but using vertex shader as offset
(+) cColorBlendOp   | Blend to backbuffer without copying textures
(!) cDatamosh       | Simulates video compression artifacts
(+) cDMipmap        | Dumb difference of gaussians using mipmaps
(+) cFilmGrain      | Film grain without copying texture
(+) cFrameBlending  | Frame blending using the previous result
(!) cInterpolate    | Optical flow frame blending
(+) cLetterBox      | LetterBox without copying textures
(+) cLuminance      | Simple greyscale comparison
(!) cMotionBlur     | Optical flow motion blur
(!) cOpticalFlow    | Horn-Schunck optical flow without weighted average
(+) cScale          | Buffer scaling using vertex shaders
(+) cShard          | Simple unmask sharpening filter
(~) cSMAA           | Minimalist version of SMAA, medium setting
(~) cTonemap        | Watch Dog's tonemapping with gamma correction
(!) cWarping        | Optical flow distortion
(k) kContour        | Contour line effect
(k) kDatamosh       | Simulates video compression artifacts
(k) kMirror         | Mirroring and kaleidoscope effect
(k) kVignette       | Natural vignetting effect

%videoWriter_ffmpegPopen2
%  This is a videoWriter pluging that uses libraries from the ffmpeg
%  project (libavcodec, libavformat, etc.) to encode video files on
%  GNU/Linux platforms.  
%
%  Users should not call this function directly.  Instead they should use
%  the videoWriter constructor and specify the 'ffmpegPopen2' plugin.
%
%  Like videoReader_ffmpegPopen2 (the 'ffmpegPopen2' plugin for
%  videoReader), this videoWriter plugin creates a separate server
%  process to communicate with the ffmpeg libraries.  In contrast,
%  videoWriter_ffmpegDirect (the 'ffmpegDirect' plugin for videoWriter)
%  loads the ffmpeg libraries directly in the MEX function.  For more
%  information, type "help videoReader_ffmpegPopen2".
%
%  Before using this plugin, the ffmpeg libraries must be installed (see
%  INSTALL.ffmpeg.txt) and the plugin MEX functions must be built using
%  BUILDVIDEOIO (type "help buildVideoIO" for details).
%
%  vr = videoWriter(filename, 'ffmpegPopen2', ...)
%  vr = videoWriter(filename, ..., 'plugin','ffmpegPopen2',...)
%    Opens FILENAME for writing using the ffmpeg libraries.  
%
%    The set of allowable container formats (AVI, MPG, MP4, etc.) depend
%    on how the ffmpeg libraries were compiled.  To see which container
%    formats can be used, run 
%      ffmpeg -formats
%    at a shell prompt, look for the "File formats" section, and look for
%    lines with the "E" (encoder) flag set.
%
%  vr = videoWriter(..., 'width',W, ...)
%  vr = videoWriter(..., 'height',H, ...)
%    Video files store frames that all must be of the same size.  W and H
%    are the width and height of the encoded video, respectively.  The
%    ADDFRAME method will automatically resize any images to be this 
%    size. 
%
%    Most codecs require these values to be divisible by 2, 4, 8, or 16.
%    If these parameters are not explicitly set, the first frame to be
%    added via ADDFRAME will be used to set the width and height.
%
%  vr = videoWriter(..., 'codec',CODECNAME, ...)
%    When compressing videos, a compression method must be selected.
%    CODECNAME is a string specifying ffmpeg's name for the encoder to
%    use. The CODECNAME often differs from the FOURCC code that
%    Microsoft's DirectShow uses.  Most users will want to explicitly
%    pass this parameter. 
%
%    The exact set of possible codecs is highly system-dependent.  Most
%    users will want to explicitly pass this parameter.  To see a list of
%    available codecs on a specific machine, run:
%      codecs = videoWriter([], 'ffmpegPopen2', 'codecs');
%
%  vr = videoWriter(..., 'fps',FPS, ...)
%  vr = videoWriter(..., 'framesPerSecond',FPS, ...)
%    FPS is the frame rate of the recorded video in frames per second.
%    Note that some codecs only work with some frame rates.  15, 23.976,
%    24/1.001, 24, 25, 29.97, 30/1.001 and 30 should work with most
%    codecs.  30fps is the default.
%
%  vr = videoWriter(..., 'fpsNum',NUM,'fpsDenom',DENOM ...)
%  vr = videoWriter(..., 'framesPerSecond_num',NUM,...
%                        'framesPerSecond_denom',DENOM ...)
%    Frame rates may also be specified as rational numbers where
%    FPS=NUM/DENOM.  
%
%  vr = videoWriter(..., 'bitRateTolerance',TOL, ...)
%    For codecs that support this parameter, the actual bit rate is
%    allowed to vary by +/- TOL bits per second.  This parameter is
%    ignored for codecs that do not support a tolerance.
%
%  vr = videoWriter(..., 'bitRate',BPS, ...)
%    BPS is the target bits/sec of the encoded video.  
%
%    Note: This parameter is supported by most of the common lossy ffmpeg
%    encoders.  To see which codecs uses the 'bitRate' parameter, run the
%    testBitRate function in the 'tests/' subdirectory of videoIODir. 
%
%  vr = videoWriter(..., 'gopSize',GOP, ...)
%    GOP is the maximum period between keyframes.  GOP stands for "group
%    of pictures" in MPEG lingo. 
%
%    Note: This parameter is supported by most of the common lossy ffmpeg
%    encoders.  To see which codecs uses the 'gopSize' parameter, run the
%    testGopSize function in the 'tests/' subdirectory of videoIODir. 
%
%  vr = videoWriter(..., 'maxBFrames',B, ...)
%    For MPEG-based codecs, B gives the maximum number of bidirectional
%    frames in a group of pictures (GOP).
%
% SEE ALSO:
%   buildVideoIO             : how to build the plugin
%   videoWriter              : overview, usage examples, other plugins
%   videoWriter_ffmpegDirect : a lower-overhead version of this plugin
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

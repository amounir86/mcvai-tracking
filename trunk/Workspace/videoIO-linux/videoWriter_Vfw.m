%videoWriter_Vfw
%  This is a videoWriter pluging that uses Microsoft's Video for Windows 
%  (Vfw) API to encode video files on Windows platforms.  
%
%  Users should not call this function directly.  Instead they should use
%  the videoWriter constructor and specify the 'Vfw' plugin.
%
%  Note that if using 64-bit Matlab, only 64-bit codecs may be used.  If
%  using 32-bit Matlab (on 32-bit or 64-bit Windows), only 32-bit codecs
%  may be used.  See INSTALL.dshow.html for details and installation
%  instructions.  
%
%  NOTE: the current implementation outputs AVI 1.0 files, not AVI 2.0
%  OpenDML files.  Files are truncated at 4GB and files with more than
%  1GB in size may not be playable on all platforms.  Use the 'DirectShow'
%  plugin for writing large videos on Windows.
%
%  vr = videoWriter(filename, 'Vfw', ...)
%  vr = videoWriter(filename, ..., 'plugin','Vfw',...)
%    Opens FILENAME for writing using VfW.  Currently, we assume
%    that the desired filetype is an AVI file.  As a convenience, all
%    forward slashes ('/') in FILENAME are automatically converted to
%    backslashes ('\'). 
%
%  vr = videoWriter(..., 'width',W, ...)
%  vr = videoWriter(..., 'height',H, ...)
%    AVI files store frames that all must be of the same size.  W and H
%    are the width and height of the encoded video, respectively.  The
%    ADDFRAME method will automatically resize any images to be this 
%    size. 
%
%    Most codecs require these values to be divisible by 2, 4, 8, or 16.
%    If these parameters are not explicitly set, the first frame to be
%    added via ADDFRAME will be used to set the width and height.
%
%  vr = videoWriter(..., 'codec',FOURCC, ...)
%  vr = videoWriter(..., 'fourcc',FOURCC, ...)
%    When compressing videos, a compression method must be selected.
%    FOURCC is a 4-character string specifying the encoder type to use.
%    It is not necessarily the name of the encoder.  Most users will want
%    to explicitly pass this parameter.   If no codec is given by the 
%    user, an uncompressed video will be created.
%
%    The exact set of possible codecs is highly system-dependent.  To see
%    a list of available codecs on a specific machine, run:
%      codecs = videoWriter([], 'codecs', 'Vfw');
%
%  vr = videoWriter(..., 'fps',FPS, ...)
%  vr = videoWriter(..., 'framesPerSecond',FPS, ...)
%    FPS is the frame rate of the recorded video in frames per second.
%    Note that some codecs only work with some frame rates.  15, 23.976,
%    24/1.001, 24, 25, 29.97, 30/1.001 and 30 should work with most
%    codecs.  30/1.001 fps is the default.
%
%  vr = videoWriter(..., 'fpsNum',NUM,'fpsDenom',DENOM ...)
%  vr = videoWriter(..., 'framesPerSecond_num',NUM,...
%                        'framesPerSecond_denom',DENOM ...)
%    Frame rates may also be specified as rational numbers where
%    FPS=NUM/DENOM.  
%
%  vr = videoWriter(..., 'showCompressionDialog',SHOW, ...)
%    If SHOW is true (a non-zero number), a dialog box is presented to
%    the user allowing precise manual selection of the codec and its
%    parameters.  The 'codec' or 'fourcc' parameter may be used to set
%    the initial Compressor, which the user may override via the GUI.
%
%    After closing the dialog using the "OK" button, the user may save
%    the codec selection and configuration by examining the 'codec' and
%    'codecParams' fields of the struct returned by the GET method.  
%
%  vr = videoWriter(..., 'codecParams',PARAMS, ...)
%    PARAMS is a MIME Base64-encoded string describing the codec
%    selection and setup parameters for a VfW codec.  The contents
%    of this string are very codec-specific.  Often, the best way to
%    come up with a string like this is to first create a videoWriter
%    with the 'showCompressionDialog' option enabled, choose the desired
%    settings, then use the GET method to extract the 'codec' and
%    'codecParams' values.  
%
%    Note that this MIME Base64 representation is the same as used by
%    VirtualDub in its Sylia Script files.  Nearly all useful VfW and
%    DirectShow codecs can only be configured with 'codecParams' and they
%    ignore the separate 'bitRate' and 'gopSize' parameters given below.
%
%  vr = videoWriter(..., 'bitRate',BPS, ...)
%    BPS is the target bits/sec of the encoded video. 
%
%    Note: Very few DirectShow codecs pay attention to the 'bitRate'
%    parameter.  To see which codecs uses the 'bitRate' parameter, run
%    the testBitRate function in the 'tests/' subdirectory of videoIODir.
%
%  vr = videoWriter(..., 'gopSize',GOP, ...)
%    GOP is the maximum period between keyframes.  GOP stands for "group
%    of pictures" in MPEG lingo. 
%
%    Note: Very few DirectShow codecs pay attention to the 'gopSize'
%    parameter.  To see which codecs uses the 'gopSize' parameter, run
%    the testGopSize function in the 'tests/' subdirectory of videoIODir. 
%
%  vr = videoWriter(..., 'quality',Q, ...)
%    Q is the target quality of the encoded video. 
%
%    Note: Very few DirectShow codecs pay attention to the 'quality'
%    parameter.  To see which codecs uses the 'quality' parameter, run
%    the testQuality function in the 'tests/' subdirectory of videoIODir.
%
% SEE ALSO:
%   buildVideoIO             : how to build the plugin
%   videoWriter              : overview, usage examples, other plugins
%   videoWriter_DirectShow   : allows usage of DirectShow encoders too
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

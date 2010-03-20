%videoWriter_DirectShow
%  This is a videoWriter pluging that uses Microsoft's DirectShow API to
%  encode video files on Windows platforms.  It supports encoders written
%  for the Video for Windows (VfW), DirectShow, and DirectX Media
%  Objects (DMO) APIs.
%
%  Users should not call this function directly.  Instead they should use
%  the videoWriter constructor and specify the 'DirectShow' plugin.
%
%  Note that if using 64-bit Matlab, only 64-bit codecs may be used.  If
%  using 32-bit Matlab (on 32-bit or 64-bit Windows), only 32-bit codecs
%  may be used.  See INSTALL.dshow.html for details and installation
%  instructions.  
%
%  vr = videoWriter(filename, 'DirectShow', ...)
%  vr = videoWriter(filename, ..., 'plugin','DirectShow',...)
%    Opens FILENAME for writing using DirectShow.  Currently, we assume
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
%  vr = videoWriter(..., 'codec',NAME, ...)
%  vr = videoWriter(..., 'fourcc',NAME, ...)
%    When compressing videos, a compression method must be selected.
%    NAME is a string specifying the encoder type to use.  Most users 
%    will want to explicitly pass this parameter.  
%    
%    Use NAME='NONE' or NAME='' to explicitly request no compression.
%
%    If no codec is given by the user (or if NAME='DEFAULT'), a 
%    default codec is chosen.  If the following registry string value
%    exists, it gives the name of the default codec:
%       HKCU\Software\dalleyg\videoIO\DefaultCodecName
%    If that key does not exist, the most recently used codec is the
%    default.  If there are any errors accessing the Windows registry, 
%    a randomly-selected codec becomes the default.
%
%    The exact set of possible codecs is highly system-dependent.  To see
%    a list of available codecs on a specific machine, run:
%      codecs = videoWriter([], 'codecs', 'DirectShow');
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
%    If SHOW is true (a non-zero number), the plugin attempts to present 
%    a dialog box that allows the user to configure the codec.  Currently,
%    this only works for Video for Windows and DirectShow encoders.  DMO
%    and some VfW encoders do not provide dialog boxes via a standard API.
%
%    For most VfW and DirectShow codecs, the user may save the codec's 
%    configuration by examining the 'codec' and 'codecParams' fields of 
%    the struct returned by the GET method.  
%
%  vr = videoWriter(..., 'codecParams',PARAMS, ...)
%    PARAMS is a MIME Base64-encoded string describing the codec
%    selection and setup parameters for a VfW or DirectShow codec.  
%    The contents of this string are very codec-specific.  Often, the 
%    best way to come up with a string like this is to first create a 
%    videoWriter with the 'showCompressionDialog' option enabled, choose 
%    the desired settings, then use the GET method to extract the 
%    'codec' and 'codecParams' values.  
%
%    Note that this MIME Base64 representation is the same as used by
%    VirtualDub in its Sylia Script files. 
%
% SEE ALSO:
%   buildVideoIO     : how to build the plugin
%   videoWriter      : overview, usage examples, other plugins
%   videoWriter_VfW  : slightly better support for VfW encoders
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

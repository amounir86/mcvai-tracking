%videoReader_DirectShow
%  This is a videoReader plugin that uses Microsoft's DirectShow API to
%  decode video files on Windows platforms.  Virtually any DRM-free video
%  file that can be played in Microsoft's Windows Media Player can be
%  loaded with this plugin.
%  
%  Users should not call this function directly.  Instead they should use
%  the videoReader constructor and specify the 'DirectShow' plugin.
%
%  Note that if using 64-bit Matlab, only 64-bit codecs may be used.  If
%  using 32-bit Matlab (on 32-bit or 64-bit Windows), only 32-bit codecs
%  may be used.  See INSTALL.dshow.html for details and installation
%  instructions.  
%
%  vr = videoReader(filename, 'DirectShow', ...)
%  vr = videoReader(filename, ..., 'plugin','DirectShow',...)
%    Loads the FILENAME using DirectShow.  As a convenience, all forward
%    slashes ('/') in FILENAME are automatically converted to backslashes
%    ('\'). 
%
%  vr = videoReader(..., 'preciseFrames',PF, ...)
%    For forward seeks smaller or equal to this integer value, the seek
%    is guaranteed to be precise.  Precise seeking means that if you seek
%    to frame 1032, you will always go exactly to frame 1032.  Imprecise
%    seeks allow a codec to (optionally) jump to approximately the
%    requested frame without worrying about whether it goes exactly
%    there.  
%
%    For forward seeks of less than or equal to PF frames, we override
%    the codec's default behavior to ensure preciseness.  Choosing a
%    small value for 'preciseFrames' can result in much faster seeks
%    (often O(1) for imprecise versus O(n) for precise, where n is the
%    seek distance) with the risk of not going to exactly the requested
%    frame.  If the value of PF is negative, precise seeks are always
%    guaranteed, even for backward seeks.  Note that for many codecs,
%    "imprecise" seeks will actually be precise. 
%
%  vr = videoReader(..., 'frameTimeoutMS',FT, ...)
%    When interfacing with DirectShow, we schedule requests that are
%    fulfilled in a collection of DirectShow-controlled threads.  If it
%    takes more than FT milliseconds per frame to fulfill a request, we
%    assume the request will never be fulfilled and we return with an
%    error from methods such as NEXT and GETFRAME.  Use -1 for an
%    infinite timeout period.
%
%  vr = videoReader(..., 'dfilters',FILT, ...)
%    ADVANCED FEATURE: Sometimes it's useful to add DirectShow filters to
%    perform postprocessing on the videos.  FILT is a colon-delimited
%    list of filter "friendly names".  For example, 
%       'ffdshow raw video filter' 
%    can be used for a wide array of postprocessing such as smoothing,
%    rescaling, and pulldown removal.  See doc/pulldownRemoval.html for
%    an example.  
%
% SEE ALSO:
%   buildVideoIO             : how to build the plugin
%   videoReader              : overview, usage examples, other plugins
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

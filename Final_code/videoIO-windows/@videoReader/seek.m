function worked = seek(vr,fnum)
%WORKED=SEEK(VR,FNUM)
%  Attempts to go to frame number FNUM in video VR.  Returns 0 if the user
%  attempts to seek past the end of the video.  For most video plugins, the
%  first frame is 0 (not 1).
%
%  FNUM should be an integer.
%
%  After the videoReader constructor is called, NEXT, SEEK, or STEP should
%  be called at least once before GETFRAME is called. 
% 
%  See videoReader/get for more details on how many frames can be read
%  from a video. 
%
%  Example:
%    % both IM1 and IM2 should be the same for most plugins
%    vr = videoReader(...);
%    if (~next(vr)), error('couldn''t read first frame'); end
%    im1 = getframe(vr);
%    if (~seek(vr,0)), error('could not seek to frame 0'); end
%    im2 = getframe(vr);
%    if (any(im1 ~= im2)), 
%      error('first frame and frame 0 are not the same'); 
%    end
%    ...
%    vr = close(vr);
%
%SEE ALSO
%  videoReader
%  videoReader/getframe
%  videoReader/get
%  videoReader/getnext
%  videoReader/next
%  videoReader/step
%
%Copyright (c) 2006 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

worked = logical(feval(vr.plugin, 'seek', vr.handle, fnum));


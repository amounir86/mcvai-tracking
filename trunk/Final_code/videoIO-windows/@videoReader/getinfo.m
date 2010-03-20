function info = getinfo(vr,varargin)
%INFO=GETINFO(VR)
%  DEPRECATED METHOD.  Use GET instead.  Future versions of videoIO may
%  remove GETINFO. 
%
%  Since this method was originally much less capable than traditional
%  Matlab GET methods, we used a different name.  It now has the most
%  common features of a Matlab GET function, so we have changed the name
%  from GETINFO to GET.
%
%SEE ALSO:
%  videoReader/get
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

warning('videoIO:deprecated', ...
        'Please use the new GET method instead of GETINFO');
info = get(vr, varargin{:});
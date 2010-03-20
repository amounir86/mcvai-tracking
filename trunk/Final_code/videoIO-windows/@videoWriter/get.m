function info = get(vw,varargin)
%INFO=GET(VW)
%  Returns a structure whose fields contain information about the opened
%  video object.  This structure may be flattened to a cell array and used 
%  with the videoWriter constructor to recreate the current video file.
%
%  Each call to GET makes a fresh call to the plugin, so be aware of
%  potential performance costs if calling it in an inner loop.
%
%VAL=GET(VW,FIELDNAME)
%  Returns the value of FIELDNAME.  The code
%    VAL = get(VW, FIELDNAME);
%  is equivalent to
%    INFO = get(VW);
%    VAL  = INFO.FIELDNAME;
%
%EXAMPLES:
%  vw = videoWriter('test.avi');
%  info = get(vw) % give all relevant configuration info for vw
%  get(vw,'width')
%
%SEE ALSO
%  videoWriter
%
%Copyright (c) 2006 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

% Without this, it can be easy for users to try to disp the object and 
% the error messages in that case are very cryptic.
if isnan(vw.handle)
  info = struct('status','closed');
  return
end

% Get information from the plugin
[names, vals] = feval(vw.plugin, 'get', vw.handle);
pinfo = cell2struct({vals{:}}, {names{:}}, 2);

% be nice and convert anything that looks like a number into one.
for i=1:length(names)
  name = names{i};
  if (length(pinfo.(name)) < 64) && ischar(pinfo.(name))
    [num,ok] = str2num(pinfo.(name)); %#ok<ST2NM> (these can be matrices)
    if ok
      pinfo.(name) = num;
    end
  end
end

% merge Matlab-side and plugin-side metadata
ctor = class(vw);
info = struct(vw);
fnames = fieldnames(pinfo);
for i=1:length(fnames)
  fname = fnames{i};
  info.(fname) = pinfo.(fname);
end
info = orderfields(info);

% make pretty plugin name...the way the constructor expects it
if isfield(info, 'plugin') && strmatch([ctor '_'], info.plugin) 
  info.plugin = info.plugin(length(ctor)+2:end);
end

% Return what was requested
switch length(varargin)
 case 0
  % do nothing -- return the whole struct
 case 1
  info = info.(varargin{1});
 otherwise
  error('Too many arguments.');
end

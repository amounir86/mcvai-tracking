function [out,out2] = videoReader_matrix(cmd, handle, varargin)
%[...] = videoReader_matrix(cmd, handle, varargin)
%  This is a videoReader plugin for treating an in-memory 3D or 4D matrix
%  as video frames.  This plugin is most useful when users wish to handle
%  in-memory data using the same API as is used for file-based I/O of
%  videos. 
%
%  This function provides the documentation and implementation for the
%  plugin.  Users should not call this function directly.  Instead they
%  should use the videoReader constructor and specify the 'matrix'
%  plugin.
%
%  vr = videoReader(MATRIX, 'matrix',...)
%  vr = videoReader(MATRIX, 'plugin','matrix',...)
%    If MATRIX is a 3D matrix, it is treated as a HxWxT sequence of T
%    grayscale frames with height H and width W.  If it is a 4D matrix,
%    it is treated as a HxWx3xT truecolor sequence.  
%
%    To create a single-frame RGB video, make a HxWx3x1 matrix (not a
%    HxWx3 matrix).
%
%  vr = videoReader(FILENAME, 'matrix',...)
%  vr = videoReader(FILENAME, 'plugin','matrix',...)
%  vr = videoReader(...[as above]..., 'varname',VARNAME)
%    This is a convenience facility to first load the 3D or 4D matrix
%    from a file, then treat it as a video, as described above.  
%
%    If VARNAME is specified, the variable with that name is the one loaded
%    by the videoReader.  For example, the FILENAME file has variables
%    'stats' and 'image' and VARNAME is set to 'image', then the 'image'
%    variable is loaded and the 'stats' variable in the .mat file is
%    ignored.
%
%    If VARNAME is not specified, a set of heuristics are used to guess
%    which variable was desired.  Variables that look like image sequences
%    (are 3D or 4D numeric matrices) are more likely to be chosen.
%    Variables with more elements are also more likely to be chosen.
%
%    This plugin is similar to the 'load' plugin, but this one assumes
%    that the entire video is stored in a single matrix.  When the 'load' 
%    loads data from a collection of files, it assumes that each .mat
%    file contains exactly one frame. 
%
%    This plugin is implemented as an M-file, so no compilation is
%    required. 
%
% EXAMPLE:
%   % make a few video frames -- a rotating gradient
%   for i=1:10
%     frames(:,:,i) = repmat(mod([0:99]/99 + (i-1)/10, 1), [75,1]);
%   end
% 
%   % read in the video and show it as a movie
%   vr = videoReader(frames, 'plugin','matrix');
%   for i=1:10
%     seek(vr,i);
%     imshow(getframe(vr));
%     title(sprintf('frame %d', i));
%     pause(1);
%   end
%   vr = close(vr);
%
% SEE ALSO:
%   videoReader
%   videoReader_load
%
%Copyright (c) 2008 Michael Siracusa and Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

% We use private/handleManager under the covers to map handles to objects.

if strcmp(cmd, 'open')
  %........................................................................
  % OPEN COMMAND
  
  video = varargin{1};
  args  = {varargin{2:end}};
  
  if isstr(video) %#ok<FDEPR> -- backward compatibility
    [varname,args] = argExtract(args, 'varname', '');
    video = loadMat(varname, video, false);
  end
  
  sz = size(video);
  if ~isnumeric(video) || length(sz)<3 || length(sz)>4 || (length(sz)==4 && sz(3) ~= 3)
    error(['"open" only accepts numeric arrays of size [h w numFrames] or ' ...
           '[h w 3 numFraes]']); 
  end
  
  if length(sz) == 4 
    trueColor = 1;
    numFrames = sz(4);
  else
    trueColor = 0;
    numFrames = sz(3);
  end
  
  if ~isempty(args)
    error(['Unrecognized optional parameter name: ', args{1}]);
  end
   
  obj = struct;
  obj.currFrame = -1;
  obj.mat       = video;
  obj.info      = struct(...
      'url',                'passed in mat', ...
      'fps',               -1, ...
      'height',             sz(1), ...
      'width',              sz(2), ...
      'numFrames',          numFrames, ...
      'isTrueColor',        trueColor, ...
      'fourcc',             '',...
      'nHiddenFinalFrames', 0);
   out = handleManager([], obj);
      
elseif strcmp(cmd, 'close'),
  %........................................................................
  % CLOSE COMMAND
  if ~isempty(varargin)
    error('The "close" command does not take any optional arguments');
  end
  handleManager(handle, 'close');
  
elseif strcmp(cmd, 'getframe')
  %........................................................................
  % GETFRAME COMMAND
  if ~isempty(varargin)
    error('The "getframe" command does not take any optional arguments');
  end

  obj  = handleManager(handle);
  indx = obj.currFrame+1;
  try
    if obj.info.isTrueColor
      out = obj.mat(:,:,:,indx);
    else
      out = obj.mat(:,:,indx);
    end
  catch
    out = [];
  end
  
elseif strcmp(cmd, 'get')
  %........................................................................
  % GET COMMAND
  if ~isempty(varargin)
    error('The "get" command does not take any optional arguments');
  end
  obj  = handleManager(handle);
  out  = fieldnames(obj.info);
  out2 = struct2cell(obj.info);
  
elseif strcmp(cmd, 'next')
  %........................................................................
  % NEXT COMMAND
  if ~isempty(varargin)
    error('The "next" command does not take any optional arguments');
  end
  obj = handleManager(handle);
  obj.currFrame = obj.currFrame + 1;
  if obj.currFrame < obj.info.numFrames
    out = int32(1);
  else
    out = int32(0);
  end
  handleManager(handle, obj);
  
elseif strcmp(cmd, 'seek')
  %........................................................................
  % SEEK COMMAND
  if length(varargin) ~= 1
    error('The "seek" command takes exactly one argument');
  end
  obj           = handleManager(handle);
  obj.currFrame = varargin{1};
  if obj.currFrame < obj.info.numFrames 
    out = int32(1);
  else
    out = int32(0);
  end
  handleManager(handle, obj);
  
elseif strcmp(cmd, 'step')
  %........................................................................
  % STEP COMMAND
  if length(varargin) ~= 1
    error('The "step" command takes exactly one argument');
  end
  obj = handleManager(handle);
  obj.currFrame = obj.currFrame + varargin{1};
  if obj.currFrame < obj.info.numFrames 
    out = int32(1);
  else
    out = int32(0);
  end
  handleManager(handle, obj);
  
else
  error(['Unrecognized command: "' cmd '"']);
end

function [out,out2] = videoReader_load(cmd, handle, varargin)
%videoReader_load
%  This is a videoReader plugin that uses Matlab's LOAD function to read
%  one variable from an individual .mat as if it were a video frame.
%
%  This function provides the documentation and implementation for the
%  plugin.  Users should not call this function directly.  Instead they
%  should use the videoReader constructor and specify the 'load'
%  plugin.
%
%  vr = videoReader(FILEPATTERN,'load',...)
%  vr = videoReader(FILEPATTERN,...,'plugin','load',...)
%  vr = videoReader(...[as above]..., 'varname',VARNAME)
%    Indexes a set of .mat files so they can be accessed via the
%    videoReader interface.  FILEPATTERN is treated the same way as it is
%    for the 'imread' plugin (type "help videoReader_imread" without
%    quotes for details).  It may either use wildcards or a sprintf-like
%    string. 
%
%    If VARNAME is specified, the variable with that name is the one
%    loaded by the videoReader.  For example, if the .mat files in
%    question have variables 'stats' and 'image' and VARNAME is set to
%    'image', then the 'image' variable is loaded and the 'stats'
%    variable in the .mat files is ignored.
%
%    If VARNAME is not specified, a set of heuristics are used to guess
%    which variable was desired.   Variables that look like images (are
%    2D or 3D numeric matrices) are more likely to be chosen.  Variables
%    with more elements are also more likely to be chosen.
%
%    This plugin is similar to the 'matrix' plugin, but this one assumes
%    that each .mat file contains exactly one frame.  When the 'matrix'
%    loads data from a file, it assumes the entire video is stored in a
%    single data structure.  
%
%    This plugin is implemented as an M-file, so no compilation is
%    required. 
%
% EXAMPLE:
%     % make a few video frames -- a rotating gradient
%     for i=1:10
%       frame = repmat(mod([0:99]/99 + (i-1)/10, 1), [75,1]);
%       save(sprintf('%04d.mat', i), 'frame');
%     end
%
%     % read in the video and show it as a movie
%     vr = videoReader('%04d.mat', 'plugin','load');
%     for i=1:10
%       seek(vr,i);
%       imshow(getframe(vr));
%       title(sprintf('frame %d', i));
%       pause(1);
%     end
%     vr = close(vr);
%
% SEE ALSO:
%     load
%     videoReader
%     videoReader_imread
%     videoReader_matrix
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details
%(especially when using this library on GNU/Linux). 

% We use private/handleManager under the covers to map handles to objects.

if strcmp(cmd, 'open')
  %........................................................................
  % OPEN COMMAND
  
  if (mod(length(varargin)-1,2) ~= 0)
    error('Optional arguments must come in name-value pairs');
  end
  
  filepattern = varargin{1};
  
  [varname,args] = argExtract({varargin{2:end}}, 'varname', '');
  if ~isempty(args)
    error(['Unrecognized optional parameter name: ', args{1}]);
  end
  
  [dirname, filenames] = getFileList(filepattern);
  img = loadMat(varname, fullfile(dirname, filenames{end}), true);

  obj = struct;
  obj.currFrame = -1;
  obj.varname   = varname;
  obj.dirname   = dirname;
  obj.filenames = filenames;
  obj.info = struct(...
      'url',                varargin{1}, ...
      'fps',               -1, ...
      'height',             size(img,1), ...
      'width',              size(img,2), ...
      'numFrames',          length(filenames), ...
      'fourcc',             '',...
      'nHiddenFinalFrames', 0,...
      'varname',            varname);
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
  obj     = handleManager(handle);
  dirname = obj.dirname;
  fname   = obj.filenames{obj.currFrame+1};
  out     = loadMat(obj.varname, fullfile(dirname, fname), true);
  
elseif strcmp(cmd, 'get')
  %........................................................................
  % GET COMMAND
  if ~isempty(varargin)
    error('The "get" command does not take any optional arguments');
  end
  obj                 = handleManager(handle);
  info                = obj.info;
  info.currFrame      = obj.currFrame;
  info.approxFrameNum = obj.currFrame;
  out                 = fieldnames(info);
  out2                = struct2cell(info);
  
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

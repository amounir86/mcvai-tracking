function [out,out2] = videoReader_concat(cmd, handle, varargin)
%videoReader_concat
%  This is a videoReader plugin that acts as if several individual video
%  clips are a single clip.  This is especially useful when a long video
%  has been broken up into several separate files, but you wish to treat
%  that entire sequence of files as if it were one video.  For example,
%  if you have "clip1.avi" and "clip2.avi", 
%    videoReader({'clip1.avi','clip2.avi'},'concat') 
%  will start reading frames from "clip1.avi".  When it reaches the end,
%  frames from "clip2.avi" are used.
%
%  This function provides the documentation and implementation for the
%  plugin.  Users should not call this function directly.  Instead they
%  should use the videoReader constructor and specify the 'concat'
%  plugin.
%
%  vr = videoReader(CLIPS,'concat',...)
%  vr = videoReader(CLIPS,...,'plugin','concat',...)
%    Indexes a sequence of videos so they can be accessed as if they were
%    one video file, using the videoReader interface.
%
%    CLIPS is a cell array listing the video clips to virtually
%    concatenate.  The entries of CLIPS may take the following forms:
%      1) video file names, e.g.
%           videoReader({...
%               'tests/numbers.x264.avi',
%               'tests/intersection300.orig.revel.avi',
%             }, 'concat')
%      2) existing videoReader objects, e.g.
%           videoReader({...
%               videoReader('tests/numbers.x264.avi'),
%               videoReader('tests/frames/numbers.%04d.png','imread'),
%             }, 'concat') 
%      3) cell arrays of videoReader constructor arguments, e.g.
%           videoReader({...
%               {'tests/numbers.x264.avi', 'ffmpegPopen2'},...
%               {'tests/frames/numbers.%04d.png', 'imread'},...
%             }, 'concat');
%      4) or any combination of the above forms, e.g.
%           videoReader({...
%               'tests/numbers.x264.avi',
%               {'tests/frames/numbers.%04d.png', 'imread'},...
%             }, 'concat');
%    Whenever CLIPS is given an existing videoReader object, the
%    concatenating reader takes full control over that videoReader
%    object.  The user should not access the reader any more and should
%    not close it.
%
%  vr = videoReader(...[as above]..., 'maxFrames',MAXFRAMES)
%    Causes the concatenating reader to pretend that each video clip has
%    at most MAXFRAMES in it.  By default, MAXFRAMES=INF.
%
%    One may choose to specify and/or override the maximum number of
%    frames for a particular clip by adding a 'maxFrames' specification
%    to form 3 of the CLIPS argument.  For example, 
%      videoReader({...
%          {'test/numbers.x264.avi','maxFrames',30}, ... 
%          {'tests/frames/numbers.%04d.png','imread','maxFrames',40},...
%        }, 'concat');
%    will return a videoReader object whose first 30 frames (at most)
%    come from 'tests/numbers.x264.avi' and whose next 40 frames (at
%    most) come from the individual frame files.  
%
%    Motivation: many decoders cannot access the last few frames of a
%    video (see the nHiddenFinalFrames discussion by typing 
%    'help videoReader/get' in Matlab for more details).  A workaround is
%    to encode each video clip with a few duplicate or extra frames at
%    the end.  MAXFRAMES can then be used to prevent the concatenating
%    reader from using those padding frames if a particular reader can
%    access to them. 
%
%  vr = videoReader(...[as above]..., NAME,VALUE)
%    Adds a name-value pair to the constructor arguments when making new
%    clips.  For example, each of these produces the same result:
%      videoReader({'test/numbers.x264.avi','plugin','ffmpegPopen2'},...
%                  'concat');
%      videoReader({'test/numbers.x264.avi'},...
%                  'concat', 'plugin','ffmpegPopen2');
%      videoReader({'test/numbers.x264.avi','plugin','ffmpegPopen2'},...
%                  'concat', 'plugin','ffmpegPopen2');
%      videoReader({'test/numbers.x264.avi','plugin','ffmpegPopen2'},...
%                  'concat', 'plugin','ffmpegDirect');
%    Note that in the last statement, the 'ffmpegDirect' plugin
%    specification gets overridden in favor of 'ffmpegPopen2'.
%
%  vr = videoReader(...[as above]..., 'defaultPlugin',DEFAULTPLUGIN)
%    Sets the default plugin for any videoReader objects created for the
%    CLIPS.  
%
% COMPLEX EXAMPLE:
%  Suppose we have the following files:
%
%    filename                              # readable frames
%    --------                              -----------------
%    tests/intersection147.25fps.xvid.avi  146
%    tests/intersection300.orig.revel.avi  300
%    tests/frames/numbers.*.mat            100
%
%  Then the following code
%  
%     inter146   = 'tests/intersection147.25fps.xvid.avi';
%     inter300   = 'tests/intersection300.orig.revel.avi';
%     frames100  = 'tests/frames/numbers.*.mat';
%     
%     vr = videoReader({...
%              inter146,...
%              {inter300,'maxFrames',200},...
%              videoReader({...
%                  inter146, ...
%                  {inter300, 'maxFrames',125},...
%                },'concat','maxFrames',100),...
%              {frames100, 'load', 'varname','frame'},...
%            }, 'concat');
%
%  produces a videoReader object whose:
%    first 146 frames come from 'tests/intersection147.25fps.xvid.avi', 
%    next  200 frames come from 'tests/intersection300.orig.revel.avi', 
%    next  100 frames come from 'tests/intersection147.25fps.xvid.avi', 
%    next  125 frames come from 'tests/intersection300.orig.revel.avi', and
%    last  100 frames come from 'tests/frames/numbers.*.mat'.
%
%
% SEE ALSO:
%     videoReader
%  
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details
%(especially when using this library on GNU/Linux). 

if strcmp(cmd,'open')
  %........................................................................
  % OPEN COMMAND
  
  if (mod(length(varargin)-1,2) ~= 0)
    error('Optional arguments must come in name-value pairs');
  end
  
  % basic argument parsing
  clips = varargin{1};
  defaultArgs = {varargin{2:end}};
  [defaultPlugin,defaultArgs] = ...
      argExtract(defaultArgs, 'defaultPlugin',...
                 defaultVideoIOPlugin('videoReader'));
  [maxFrames,defaultArgs] = argExtract(defaultArgs, 'maxFrames', inf);
  
  if ~iscell(clips)
    error(['The CLIPS argument for a ''concat'' videoReader plugin must ' ...
           'be a cell array.']);
  end
  if isscalar(maxFrames)
    maxFrames = repmat(maxFrames, [1 numel(clips)]);
  end
  if numel(maxFrames) ~= numel(clips)
    error(['maxFrames must be a scalar or have the same number of elements '...
           'as CLIPS.  There are %d elements in maxFrames, and %d CLIPS.'],...
          numel(maxFrames), numel(clips));
  end
  
  % open each clip
  for i=1:length(clips)
    if ischar(clips{i})
      clips{i} = videoReader(clips{i}, defaultPlugin, defaultArgs{:});
      
    elseif isa(clips{i}, 'videoReader')
      % do nothing
      
    elseif iscell(clips{i})
      % Figure out which plugin to use (defaultPlugin was extracted from
      % defaultArgs). 
      [plugin,args] = ... 
          pvtVideoIO_parsePlugin({clips{i}{2:end}}, defaultPlugin);
      % We need to merge any default arguments, but the defaultArgs may
      % still have a 'plugin' arg embedded, so we take care to throw it
      % away if necessary.
      [dummy,args] = argExtract({defaultArgs{:} args{:}}, 'plugin','N/A');
      % Strip out maxFrames argument: it's for our use, not for the
      % underlying object.
      [maxFrames(i),args] = argExtract(args,'maxFrames',maxFrames(i)); 
      % Now create the clip's reader
      clips{i} = videoReader(clips{i}{1}, plugin, args{:});
      
    else
      error(['Clip %d must be a string, a videoReader, or a cell array.  ' ...
             'It is a %s.'], i, class(clips{i}));
    end
  end
  
  % Update maxFrames with real data.  For now, we require each clip's
  % reader to supply a 'numFrames' field.  If that becomes a problem, in
  % the future, we could require that, for those clips, maxFrames must be
  % finite, or something similar.
  for i=1:length(clips)
    maxFrames(i) = min(maxFrames(i), get(clips{i}, 'numFrames'));
  end
  
  % compose the internal reader object
  obj = struct;
  obj.clips          =  clips;
  obj.approxFrameNum = -1;
  obj.maxFrames      =  maxFrames;
  out = handleManager([], obj);
  
elseif strcmp(cmd, 'close'),
  %........................................................................
  % CLOSE COMMAND
  if ~isempty(varargin)
    error('The "close" command does not take any optional arguments');
  end
  
  obj = handleManager(handle);
  for i=1:length(obj.clips)
    obj.clips{i} = close(obj.clips{i});
  end
  handleManager(handle, 'close');

elseif strcmp(cmd, 'getframe')
  %........................................................................
  % GETFRAME COMMAND
  if ~isempty(varargin)
    error('The "getframe" command does not take any optional arguments');
  end
  obj = handleManager(handle);
  clipIdx = getClipIdx(obj);
  if clipIdx < 1 || clipIdx > length(obj.clips)
    out = [];
  else
    out = getframe(obj.clips{getClipIdx(obj)});
  end
  
elseif strcmp(cmd, 'get')
  %........................................................................
  % GET COMMAND
  % Here we give mostly whole-video information and we stuff stuff the
  % low-level information in a 'clipInfo' field when available.
  if ~isempty(varargin)
    error('The "get" command does not take any optional arguments');
  end
  obj  = handleManager(handle);
  info = struct;
  info.url = '';
  info.nHiddenFinalFrames = 0;
  info.clipIdx  = getClipIdx(obj);
  if info.clipIdx < 1 || info.clipIdx > length(obj.clips)
    info.clipInfo = struct;
    info.fps    = nan;
    info.height = nan;
    info.width  = nan;
    info.fourcc = '';
  else
    info.clipInfo = get(obj.clips{info.clipIdx});
    info.fps    = info.clipInfo.fps;
    info.height = info.clipInfo.height;
    info.width  = info.clipInfo.width;
    info.fourcc = info.clipInfo.fourcc;
  end  
  info.plugin         = 'concat';
  info.maxFrames      = obj.maxFrames;
  info.numFrames      = sum(obj.maxFrames);
  info.approxFrameNum = obj.approxFrameNum;
    
  out  = fieldnames(info);
  out2 = struct2cell(info);

elseif strcmp(cmd, 'next')
  %........................................................................
  % NEXT COMMAND
  if ~isempty(varargin)
    error('The "next" command does not take any optional arguments');
  end
  obj = handleManager(handle);
  out = doSeek(handle, obj, obj.approxFrameNum+1);
  
elseif strcmp(cmd, 'seek')
  %........................................................................
  % SEEK COMMAND
  if length(varargin) ~= 1
    error('The "seek" command takes exactly one argument');
  end
  obj = handleManager(handle);
  out = doSeek(handle, obj, varargin{1});

elseif strcmp(cmd, 'step')
  %........................................................................
  % STEP COMMAND
  if length(varargin) ~= 1
    error('The "step" command takes exactly one argument');
  end
  obj = handleManager(handle);
  out = doSeek(handle, obj, obj.approxFrameNum+varargin{1});
  
else
  error(['Unrecognized command: "' cmd '"']);
end

%--------------------------------------------
function out = doSeek(handle, obj, toFrame)
%out = doSeek(obj, toFrame)
%  Consolidated SEEK function used by NEXT, STEP, and SEEK.  Updates the
%  handleManager after performing the seek.

obj.approxFrameNum  = toFrame;
[clipIdx,clipFrame] = getClipIdx(obj);
%fprintf('i:%d, f:%d\n', clipIdx, clipFrame);
if clipIdx > length(obj.clips)
  out = int32(0);
elseif clipIdx < 1
  % for now, doing next before the video starts is okay...we may change
  % this in the future
  out = int32(1);
else
  out = seek(obj.clips{clipIdx}, clipFrame);
end
handleManager(handle, obj);

%--------------------------------------------
function [idx,fr] = getClipIdx(obj)
%Computes the clip index for a concat object
if obj.approxFrameNum < 0
  idx =  0;
  fr  = -1;
else
  frameStarts = cumsum([0 obj.maxFrames]);
  %fprintf('%d ', frameStarts); fprintf('  vs.  %d', obj.approxFrameNum);
  idx = find(obj.approxFrameNum >= frameStarts);
  %fprintf('  --> [ '); fprintf('%d ', idx); fprintf('] ');
  idx = idx(end);
  fr  = obj.approxFrameNum - frameStarts(idx);
  %fprintf('  clipframe = %d\n', fr);
end

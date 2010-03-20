function [out] = handleManager(varargin)
%HANDLEMANAGER
%  This function encapsulates the management of a global mapping of
%  integer handles to arbitrary Matlab objects.  This allows
%  pass-by-reference mutable objects.  
%
%  Limitations and caveats:
%   * Matlab 2008a adds a handle-based object system to the M language.
%     If your application will be exclusively using 2008a or later, use
%     the official system instead of this one.
%   * This system circumvents Matlab's garbage collection, so users must
%     explicitly close handles or they will continue to consume memory.   
%   * Most operations are linear in the number of open handles.  The
%     implementation is simple and reasonably performant for small
%     numbers of objects, but something more sophisticated is needed for
%     very large numbers of open handles (1e3? 1e6?).
%
%newHandle = handleManager([], instanceData)
%  Create: creates a new handle and associates it with the given instance
%          data.
%
%handleManager(handle, instanceData)
%  Update: reassociates a handle with new instance data
%
%instanceData = handleManager(handle)
%  Get: retrieves the instance data given a handle
%
%handleManager(handle,'close')
%  Close: closes a handle

% Registry of data.  Each HANDLES entry is a handle ID.  the
% corresponding entry in INSTANCES is its corresponding data.  When a new
% handle is created, its value will be NEXTHANDLE.  We initialize
% NEXTHANDLE with NOW to discourage people from thinking they start with 0
persistent nextHandle handles instances;
if isempty(nextHandle)
  nextHandle = int32(now);           % handle to use for the next open command
  handles    = int32(zeros(0,0));    % list of currently-active handles
  instances  = {};                   % The actual object instances
end

if nargin==2 && isempty(varargin{1})
  % newHandle = handleManager([], instanceData)
  i            = length(handles)+1;
  handles(i)   = nextHandle;
  out          = nextHandle;
  nextHandle   = int32(double(nextHandle)+1);
  instances{i} = varargin{2};
  
elseif nargin==2 && (~ischar(varargin{2}) || ~strcmpi('close',varargin{2}))
  % handleManager(handle, instanceData)
  i            = validateHandle(varargin{1},handles);
  instances{i} = varargin{2};
  
elseif nargin==1
  % instanceData = handleManager(handle)
  i   = validateHandle(varargin{1},handles);
  out = instances{i};
  
elseif nargin==2 && ischar(varargin{2}) && strcmpi('close',varargin{2})
  % handleManager(handle,'close')
  i         = validateHandle(varargin{1},handles);
  handles   = handles([1:i-1, i+1:end]);
  instances = {instances{[1:i-1, i+1:end]}};
  
else
  error('Invalid arguments');
end
  
%--------------------------------------------
function i = validateHandle(handle,handles)
[tst,i] = ismember(handle,handles);
if ~tst
  error('Invalid handle: %d', handle);
end

function ienter(varargin)
%IENTER(...)
%  Calls IPRINTF on the input arguments then increases the indentation
%  level.  If no input args are used, a message is created using the
%  caller's function or script name.  Useful for debugging/tracing.
%
%  If an unhandled error occurs between calls to ienter and iexit, the
%  indentation level will not be properly reset.  To reset it, type
%     clear all
%
%Example:
%  function d = foo
%  ienter;
%  d = 2+2;
%  iprintf('2+2=%d', d);
%  iexit;

global videoIO_test_indentLevel;
if (isempty(videoIO_test_indentLevel))
  videoIO_test_indentLevel = 0;
end

if (nargin == 0)
  [st] = dbstack;
  ienter('%s...', st(2).name);
elseif (nargin == 1 && isnumeric(varargin{1}))
  [st] = dbstack;
  ienter(varargin{1}, '%s...', st(2).name);
else
  iprintf(varargin{:});
  videoIO_test_indentLevel = videoIO_test_indentLevel + 1;
end


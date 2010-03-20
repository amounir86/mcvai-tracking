function iprintf(varargin)
%IPRINTF(...)
%  Same as FPRINTF, but the current indentation level (as regulated by
%  IENTER and IEXIT) is used to prepend whitespace to the beginning of each
%  line.  A newline is always added to the end.
%
%Example:
%  ienter('foo...');
%  iprintf('2+2=%d', 4);
%  iexit('...foo');

global videoIO_test_indentLevel;
if (isempty(videoIO_test_indentLevel))
  videoIO_test_indentLevel = 0;
end

if nargin < 1
  return
end

if (isnumeric(varargin{1}))
  fid = varargin{1};
  varargin = {varargin{2:end}};
else
  fid = 1; %stdout
end

indentationString = char(ones(1,videoIO_test_indentLevel*2)*' ');

preindented = sprintf(varargin{:});
newlinesIndented = strrep(preindented, sprintf('\n'), ...
  [sprintf('\n'), indentationString]);

fprintf(fid, '%s%s\n', indentationString, newlinesIndented);


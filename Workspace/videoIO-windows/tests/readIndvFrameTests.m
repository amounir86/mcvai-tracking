function readIndvFrameTests(plugin,ext,varargin)
%readIndvFrameTests(plugin,ext,...)
%  This function is like readTests, but it has been customized to work
%  with videoReader plugins that work on individual frame numbers.  Reads
%  in data produced by EXTRACTFRAMES.
%
%         plugin: which plugin to use (must be specified)
%            ext: extension ('png' or 'mat') to read
%  other args...: are passed to the videoReader constructor, as-is.
%
%Examples:
%  readIndvFrameTests('load','mat');
%  readIndvFrameTests('imread','png');

ienter

if nargin < 2, 
  error 'too few arguments';
end

% generate the data, if needed
extractFrames; 

% sprintf-style
doPreciseSeekTests(['frames/numbers.%04d.' ext], plugin, varargin{:});

% wildcard style
doPreciseSeekTests(['frames/numbers.*.' ext], plugin, varargin{:});

% cause an exception in the .m file
vr = videoReader(['frames/numbers.*.' ext], plugin, varargin{:});
try
  vrassert seek(vr, struct('abc', sparse(10)));
  error('The previous seek command should have failed');
  %vr = close(vr);
catch
  vr = close(vr); %#ok<NASGU>
end

iexit

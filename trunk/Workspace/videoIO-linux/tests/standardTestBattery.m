function standardTestBattery(plugin)
%standardTestBattery(plugin)
%  Performs a standard battery of tests on a given plugin
%
%Examples:
%  standardTestBattery
%  standardTestBattery ffmpegPopen2  % linux & similar
%  standardTestBattery ffmpegDirect  % ...if system's gcc is compatible w/ Matlab's
%  standardTestBattery DirectShow    % Windows
%

ienter

if nargin < 1, plugin = defaultVideoIOPlugin; end

readTests(plugin);
concatReadTests; % without a plugin specified
concatReadTests(plugin); % with an explicit default
writeTests(plugin);
if ispc
  testGet(plugin);
end
if ~strcmpi(plugin, 'DirectShow') % DShow doesn't support these options now
  testBitRate(plugin);
  testGopSize(plugin);
  testQuality(plugin);
end
longWriteTest(plugin);

iexit

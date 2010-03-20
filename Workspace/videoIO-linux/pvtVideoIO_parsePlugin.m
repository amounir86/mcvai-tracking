function [plugin,pluginArgs] = pvtVideoIO_parsePlugin(args, defaultPlugin)
%[plugin,pluginArgs] = pvtVideoIO_parsePlugin(args, defaultPlugin)
%  PRIVATE function for the VideoIO Library.  Typical users should not use
%  this function.  This function is shared by multiple components in a way
%  that it cannot sit in a private/ directory, hence the verbose name.
%
%  Takes the varargin part of a videoReader/videoWriter constructor call
%  (ARGS) and parses out the plugin.  If no plugin is specified, then we
%  use the DEFAULTPLUGIN.
%
%  If the plugin is specified multiple times, the last choice is used.
%
%  Any arguments in ARGS that specify the plugin are removed from the
%  returned PLUGINARGS.  
%
%Example:
%  [plugin,pluginArgs] = pvtVideoIO_parsePlugin(...
%    {'codec','xvid', 'plugin','ffmpegDirect'}, 'ffmpegPopen2')
%  --> plugin='ffmpegDirect'; pluginArgs={'codec','xvid'};
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

if (mod(length(args),2)==0)
  plugin = defaultPlugin; 
else
  plugin = args{1};
  args   = {args{2:end}};
end
[plugin,pluginArgs] = argExtract(args, 'plugin', plugin);

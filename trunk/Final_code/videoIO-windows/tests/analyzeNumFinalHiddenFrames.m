%analyzeNumFinalHiddenFrames
% This script is used to examine all files in the current directory and
% determine which ones appear to be fully readable.  When completed, it
% prints out a table of all videos that appear to be readable, their FourCC
% code (essentially it says what codec was used to compress the file), and
% an estimate of the number of frames at the end of the file that could not
% be read.
%
% We do this for two reasons... first this lets users know which files can
% be accessed.  If a video exists in the current directory but isn't
% reported by this script, it's likely that there is either some bug in
% videoReader, the codec has not been properly installed, or the file is in
% an unsupported format.  
%
% The second reason for this script deals with what appears to be some
% deficiencies in current encoders.  Various encoders seem to create AVI
% files such that the last few frames cannot be read.  The rest of this
% comment block explains why the encoders are likely to blame.
%
% As of June 2007, all of the supplied test files were created with the 
% VirtualDub application (http://www.virtualdub.org).  VirtualDub is a
% very mature piece of software with great attention paid to robustness
% and correctness, so it is unlikely that the VirtualDub application is
% to blame.  As further evidence, other encoder applications yield the
% same results when using the same codecs that VirtualDub uses.
%
% While it's certainly possible that videoReader was implemented 
% incorrectly, there are reasons to doubt this is the cause.  The same
% issues arise when decoding a given vido using the avifile API on 
% Linux (something we no longer support), the ffmpeg API on Linux, and
% the DirectShow API on Windows.  The way of extracting frames from each 
% of these is quite different (look at FfmpegIVideo::next and 
% DirectShowIVideo::next if you're curious).  We have also separately
% written a test application in DirectShow and were unable to obtain 
% the last frame's data no matter what we've done.  We also see the same
% problems when using the mplayer application to decode the videos.
%
% Codec bugs?  Given a codec binary, the problems are very repoduceable 
% with different source files, different encoder applications (except 
% strangely the revel library produces proper XviD-encoded AVIs but the 
% XviD Video for Windows codec doesn't), different video lengths, and 
% different decoder implementations (ffmpeg on Linux, Microsoft's own 
% DirectShow on Windows, and the mplayer application on Linux).  This 
% suggest that the problem might actually lie in the codec internals and 
% our workaround solution that avoids the last few frames may be the 
% only real solution. 
%
%Examples:
%  analyzeNumFinalHiddenFrames
%
%Copyright (c) 2006 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

loadables     = cell(0);
fourccs       = cell(0);
nHiddenFrames = [];
nEst          = [];
nFramesActual = [];

files = dir('.');
for i=1:length(files)
  try
    % Try opening it
    vr = videoReader(files(i).name);
    
    % Can we get basic stream info?
    info = get(vr);
    
    % Does it look valid?
    if (info.width     <= 0), error('bad width');     end
    if (info.height    <= 0), error('bad height');    end
    if (info.bpp       <= 0), error('bad bpp');       end
    if (info.numFrames <= 0), error('bad numFrames'); end
    
    if isfield(info, 'nHiddenFinalFrames')
      nEst(end+1) = info.nHiddenFinalFrames; %#ok<AGROW> (there aren't that many files and we don't know how many errors will occur above this)
    else
      nEst(end+1) = nan; %#ok<AGROW>
    end
    
    % Can we read the first frame?
    if (~next(vr)), error('first next call failed'); end
    
    % Is it at least the right size?
    frame = getframe(vr);
    if (~all(size(frame) == [info.height info.width info.bpp/8])), 
      error('returned frame is the wrong size'); 
    end
    
    % Undo nHiddenFinalFrames so we can really test how many frames there
    % are.  The videoReader plugins will all let us attempt to read at
    % least info.numFrames + info.nHiddenFinalFrames frames.
    info.numFrames = info.numFrames + info.nHiddenFinalFrames;
    
    % Can we actually read every frame?
    hFrames = info.numFrames - 1;
    for fnum=2:info.numFrames
      try
        if (~next(vr)), break; end
        hFrames = hFrames - 1;
      catch
        break
      end
    end
    % Close it since we're done with it for now.
    vr = close(vr);
    
    % It looks good, so squirrel the name away
    loadables{end+1} = files(i).name; %#ok<AGROW>
    if (isempty(info.fourcc)), info.fourcc = '    '; end % for formatting
    fourccs{end+1} = info.fourcc; %#ok<AGROW>
    nHiddenFrames(end+1) = hFrames; %#ok<AGROW>
    nFramesActual(end+1) = info.numFrames - hFrames; %#ok<AGROW>
  catch
  end
end

fprintf('\n\n');
fprintf('# actual  nHiddenFrames    fcc     file\n');
fprintf('  frames     est actual    code    name\n');
fprintf('--------  ------ ------    ----   -----\n');
for i=1:length(loadables)
  fprintf('% 8d % 7d % 6d    %s   %s\n', ...
          nFramesActual(i), nEst(i), nHiddenFrames(i), fourccs{i}, ...
          loadables{i});
end

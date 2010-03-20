function [loadables,nonloadables,errors] = getLoadableFiles(varargin)
%loadables = getLoadableFiles(...)
%  Returns a cell array containing the names of files in the current
%  directory that can be read with videoReader.  
%
%  Any arguments passed to this function are passed along directly to the
%  videoReader constructor (e.g. allowing the caller to pick a non-default
%  plugin). 
%
%  If a file is not listed in LOADABLES, then either it contains some error
%  or the appropriate codec is not installed.
%
%[loadables,nonloadables] = getLoadableFiles(...)
%  Also returns a list of the rest of the files in the current directory
%  that were not loadable.
%
%[loadables,nonloadables,errors] = getLoadableFiles(...)
%  For each entry in NONLOADABLES, the corresponding error message
%  describing its problem is given in ERRORS.
%
%Example:
%  loadables = getLoadableFiles;
%
%Copyright (c) 2006 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

loadables    = cell(0);
nonloadables = cell(0);
errors       = cell(0);

files = dir('.');
for i=1:length(files)
  try
    % Try opening it
    vr = videoReader(files(i).name, varargin{:});
    % Can we get basic stream info?
    info = get(vr);
    % Does it look valid?
    if (info.width     <= 0), error('bad width');     end
    if (info.height    <= 0), error('bad height');    end
    if (info.bpp       <= 0), error('bad bpp');       end
    %if (info.numFrames <= 0), error('bad numFrames'); end
    % Can we read the first frame?
    if (~next(vr)), error('first next call failed'); end
    % Is it at least the right size?
    frame = getframe(vr);
    if (~all(size(frame) == [info.height info.width info.bpp/8])), 
      error('returned frame is the wrong size'); 
    end
    % Can we actually read every frame?
    if (info.numFrames >= 0)
      % number of frames supplied
      for fnum=2:info.numFrames
        try
          if (~next(vr)), error('Could not read frame %d', fnum-1); end
        catch
          le = lasterror;
          error('Could not read frame %d: %s', fnum-1, le.message);
        end
      end
    else
      % plugin (probalby ffmpeg) didn't tell us how many frames, so guess
      % based on some hard-coded knowledge of files in the test/
      % directory. 
      fnum = 2;
      while 1
        try
          if (~next(vr)), error('Could not read frame %d', fnum-1); end
        catch
          le = lasterror;
          nframes = inf;
          if (~isempty(strmatch('intersection', files(i).name)))
            nframes = sscanf(files(i).name, 'intersection%d');
          elseif (~isempty(strmatch('numbers.', files(i).name)))
            nframes = 300;
          end
          if fnum < nframes-4
            error(['Could not read frame %d (the file has %d frames): ' ...
                   '%s'], fnum-1, nframes, le.message);
          end
          break;
        end
        fnum = fnum+1;
      end
    end
    % Close it since we're done with it for now.
    vr = close(vr); %#ok<NASGU>
    
    % It looks good, so squirrel the name away
    loadables{end+1} = files(i).name; %#ok<AGROW>
  catch
    % do nothing... if there's an error, it's just not a loadable file
    nonloadables{end+1} = files(i).name; %#ok<AGROW>
    le = lasterror;
    errors{end+1} = strrep(le.message, sprintf('\n'), '\n'); %#ok<AGROW>
  end
end

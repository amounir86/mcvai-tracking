function [dirname,filenames] = getFileList(filepattern)
%[dirname,filenames] = getFileList(filepattern)
%  Given a file pattern, splits out the directory name (if present)
%  and a sorted list of all files fitting that pattern.  Think of
%  this function as a specialized DIR function.
% 
%  filepattern may use wildcards, e.g. 'mydir/*.png', or it may use
%  an sprintf-like '%d' string, e.g. 'mydir/%04d.png'.  The wildcard
%  or sprintf substitution must be in the filename, not in a directory
%  name (e.g. neither 'mydir/%04d/pic.png' nor 'mydir/*/pic.png' is
%  allowed).
%
%  For sprintf strings, we assume that the substituted number is the
%  frame number.  Currently, only non-negative numbers are supported.
%  Only frames that are found when the open command is executed can 
%  be read.
%
%  For wildcard strings, all files matching the pattern are examined
%  and they are sorted in alphabetic order.  The alphabetically-first
%  frame is used as frame 0.  Only frames that are found when the
%  open command is executed can be read.
%
%  Both the percent character (%) and wildcards (?,*) cannot appear 
%  in the same file pattern at the present time (e.g. 
%  'mydir/*/%04d.png' is not allowed).  The percent character may
%  appear at most once (e.g. 'mydir/%04d_%04d.png' is not allowed). 
%
%  TODO: actually prevent substitutions in the directory portion (or change
%        the docs)

% Look for sprintf-style strings
pctLoc = find(filepattern == '%');
if length(pctLoc) > 1
  error('Only one sprintf substitution is allowed right now');
elseif length(pctLoc) == 1
  wildcardPathname = '';
  for i=pctLoc+1:length(filepattern)
    if (filepattern(i)>='0') && (filepattern(i)<='9')
      % do nothing
    elseif filepattern(i)=='d'
      wildcardPathname = [filepattern(1:pctLoc-1) '*' filepattern(i+1:end)];
      break;
    else
      error('Only integer (%%d-style) substititions are permitted'); 
    end
  end
else
  % wildcard style--do nothing special here
end

parts = split('/', strrep(filepattern, '\', '/'));
dirname = filepattern(1:end-length(parts{end})-1);
filepatt = filepattern(end-length(parts{end})+1:end);

if isempty(pctLoc)
  % wildcard style (handled natively by the DIR function)
  d = dir(filepattern);
  filenames = sort({d.name});
else
  d = dir(wildcardPathname);
  filenames = {};
  for ii=1:length(d)
    frameNum = sscanf(d(ii).name, filepatt);
    if ~isempty(frameNum)
      filenames{frameNum+1} = d(ii).name; %#ok<AGROW> 
    end
  end
end

function mexe = isMFileWithCode(pathname)
%mexe = isMFileWithCode(pathname)
%  This is a convenience function that determines whether the supplied
%  pathname refers to a Matlab M-file that appears to have some
%  executable code in it.  If the pathname does not end in '.m', then
%  false is returned.  If it does end in '.m' and it only contains
%  whitespace and comments, then false is returned.  Otherwise true is
%  returned. 

if isempty(pathname)
  mexe = 0;
else
  [pathstr,name,ext] = fileparts(pathname);
  if ~strcmpi('.m',ext)
    % not a .m file
    mexe = 0;
  elseif exist(pathname,'file')
    mexe = 0;
    F = fopen(pathname,'rt');
    while 1
      line = fgetl(F);
      if ~ischar(line), break; end
      
      % strtrim doesn't exist in old versions, so we reimplement it
      % here.  Since this is not called often, we use an easy yet
      % slow-in-old-matlab loop pair.
      %line = strtrim(line);
      while ~isempty(line) && isspace(line(1))
        line = line(2:end);
      end
      while ~isempty(line) && isspace(line(end))
        line = line(1:end-1);
      end
      
      if ~isempty(line) && line(1)~='%'
        % we found a line that's not just whitespace and/or
        % comments...assume it's code.
        mexe = 1;
        return;
      end
    end
    fclose(F);
    
  else
    % file doesn't exist
    mexe = 0;
  end
end

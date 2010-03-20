function out = loadMat(varname, fname, asframe)
%out = loadMat(varname, fname, asframe)
%  Tries to load the variable VARNAME from the file FNAME as a frame (if
%  ASFRAME is true) or as a whole video (if ASFRAME is false).  If
%  VARNAME is empty, this function uses the GETVARIABLESCORE heuristics
%  to choose a single variable to load.
%

if ~exist(fname, 'file')
  % Treat a missing file as a dropped frame.  If this is a problem
  % for people, we could make an optional constructor argument that
  % decides whether to silently drop frames (as we do here) or whether
  % to trigger an error message.
  out = []; 
else
  if isempty(varname)
    tmp = load(fname);
    % choose the biggest 2D or 3D matrix
    fnames = fieldnames(tmp);
    scores = zeros(numel(fnames),1);
    vals = struct2cell(tmp);
    for j=1:length(scores)
      scores(j) = getVariableScore(vals{j}, asframe);
    end
    [dummy,fieldIdx] = max(scores);
    out = getfield(tmp, fnames{fieldIdx}); %#ok<GFLD> -- better backward compatibility
  else
    out = getfield(load(fname, varname), varname); %#ok<GFLD> -- better backward compatibility
  end
end

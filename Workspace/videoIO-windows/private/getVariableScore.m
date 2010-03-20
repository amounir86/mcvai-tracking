function score = getVariableScore(x, asframe)
%score = getVariableScore(x, asframe) 
%  Assigns a heuristic score to the variable x.  Variables that look like
%  images (are 2D or 3D numeric matrices if ASFRAME is true, or 3D or 4D
%  numeric matrices if ASFRAME is false) receive very high scores.  Bigger
%  variables get higher scores that smaller ones.  All variables receive a
%  non-zero score.
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

% soft-decision bias (makes desired features soft constraints)
soft = 1e-10; 

asvid = ~asframe;

score = ...
    ((((ndims(x)==3+asvid)+soft) * ...
      ((size(x,3)==3)+soft)) +...        % rgb or
     ((ndims(x)==2+asvid)+soft)) * ...   %  grayscale
    (numel(x)+soft) * ...                % and big
    (isnumeric(x)+soft);                 % and numeric

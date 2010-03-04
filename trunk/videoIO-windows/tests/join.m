function s = join(d,varargin)
%S=JOIN(D,L) joins a cell array of strings L by inserting string D in
%            between each element of L.  Meant to work roughly like the
%            PERL join function (but without any fancy regular expression
%            support).  L may be any recursive combination of a list 
%            of strings and a cell array of lists.
%
%Examples:
%    % For any of the following examples,
%    >> join('_', {'this', 'is', 'a', 'string'} )
%    >> join('_', 'this', 'is', 'a', 'string' )
%    >> join('_', {'this', 'is'}, 'a', 'string' )
%    >> join('_', {{'this', 'is'}, 'a'}, 'string' )
%    >> join('_', 'this', {'is', 'a', 'string'} )
%
%    % ...the result is:
%    ans = 
%        'this_is_a_string'
%
%Copyright (c) 2006 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

if (isempty(varargin)), 
    s = '';
else
    if (iscell(varargin{1}))
        s = join(d, varargin{1}{:});
    else
        s = varargin{1};
    end
    
    for ss = 2:length(varargin)
        s = [s d join(d, varargin{ss})]; %#ok<AGROW>
    end
end

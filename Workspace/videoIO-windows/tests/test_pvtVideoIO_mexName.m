% This is a regression test for the pseudo-private pvtVideoIO_mexName
% function.  Normal users should have little use for this test.
%
% Sometimes it can be easy to forget to run buildVideoIO.  We introduced
% a "private" function pvtVideoIO_mexName.m to try to detect this
% situation to produce more user-friendly error messages.  As videoIO has
% developed, we have introduced both MEX-based and M-file-based plugins.
% For the MEX-based ones, we are allowing pure-documentation M-files.
% This has made pvtVideoIO_mexName more complex.  This regression test is
% meant to verify that we correctly detect all different combinations
% that need to be considered.

ienter;

w = warning;
warning off; %#ok<WNOFF>

% we use some fake constructor and plugin names to avoid name conflicts.
ctor   = 'test';
plugin = strrep(mfilename, '_', '');

for implPresent = 0:1
  for implIsMex = 0:1
    for hasMDoc = 0:implIsMex
      for hasOtherMex = 0:implIsMex
        n = [ctor '_' plugin];
        % clean up from old runs
        delete([n '*']);
        
        % write implementation file
        if implPresent
          if implIsMex
            dlmwrite([n '.' mexext], []);
          else
            dlmwrite([n '.m'], 'executable', 'delimiter',' ');
          end
        end
        
        % write doc file
        if hasMDoc
          dlmwrite([n '.m'], '% comment', 'delimiter',' ');
        end
        
        % write other mex files
        if hasOtherMex
          try
            exts = mexext('all'); exts = {exts.ext};
          catch
            % mexext('all') was introduced in Matlab R14sp3 (at least 
            % on linux). Use all known extensions.
            exts = {'mex', ... % really old versions 
                    'mexsol','mexhpux','mexglx','mexi64','mexmac','dll',...
                    'mexhp7','mexa64','mexs64','mexw32','mexw64','mexmaci'...
                   };
          end
          
          otherExts = setdiff(exts, mexext);
          otherExt = otherExts{1};
          
          dlmwrite([n '.' otherExt], []);
        end
      
        % test pvtVideoIO_mexName
        errDescr = '';
        try
          pvtVideoIO_mexName(ctor,plugin);
          if ~implPresent
            errDescr = ['Implementation file does not exist, but ' ...
                        'pvtVideoIO_mexName thinks it does.'];
          end
        catch
          if implPresent
            errDescr = ['Implementation file does exist, but ' ...
                        'pvtVideoIO_mexName thinks it does not.'];
          elseif hasOtherMex
            err = lasterror;
            if isempty(strfind(err.message, otherExt))
              errDescr = ['A "' otherExt '" MEX file for another ' ...
                          'platform is present, but it was not ' ...
                          'found by pvtVideoIO_mexName.'];
            end
          end
        end
        
        if ~isempty(errDescr)
          error(sprintf(...
              ['ERROR: ' errDescr '\n'...
               '  implementation is present:   ' num2str(implPresent) '\n'...
               '  implementation is mex:       ' num2str(implIsMex) '\n'...
               '  has .m documentation if mex: ' num2str(hasMDoc) '\n'...
               '  other mex is present:        ' num2str(hasOtherMex) '\n'...
              ])); %#ok<SPERR> -- backward compatability
        end
      
        % clean up from this run
        delete([n '*']);
        clear otherExt otherExts;
      end
    end
  end
end

warning(w);

iexit;

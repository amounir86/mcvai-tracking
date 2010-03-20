function testEcho
%testEcho
%  Runs tests on the mex functions created about echo.cpp.  
%    echoDirect calls echo.cpp's handleMexRequest by having a mexFunction
%      do some variable munging and then directly calling handleMexRequest.
% 
%    echoPopen2 calls echo.cpp's handleMexRequest by starting a server
%      process and communicating to it with a set of pipes.  The
%      mexFunction serializes its data across the pipes.  The data are then
%      deserialized and handleMexRequest is called in the server process.
%      handleMexRequest's lhs results are then serialized, piped to the
%      mexFunction, then deserialized and returned to Matlab.
% 
%   These tests are meant to verify the architecture used here which allows
%   for fairly generic mexFunction proxy implementations (handleMexRequest
%   implementations).  These implementations may either be embedded in the
%   mexFunction's shared library for performance and convenience reasons.
%   For times when there are library or linker compatability problems with
%   the implementation and Matlab (common when doing things like video
%   processing), the implementation can be shifted to a separate server
%   process seemlessly (as long as it does not directly require access to
%   Matlab functions).
%
%Example:
%   testEcho
% 
%As of 31 May 2007, this test only works on GNU/Linux.  There isn't
%a strong need for a popen2-like protocol on Windows.

ienter;

if exist('buildVideoIO', 'file') == 2, buildVideoIO('echo'); end 

t(@echoPopen2);
t(@echoDirect);

iexit

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
function t(e)
  e();          vrassert ~exist('ans', 'var');
  e(10:20);     vrassert all(ans == [10:20]);
  a = e(11:21); vrassert all(a == [11:21]); %#ok<NASGU>
  
  [a,b] = e('asdf', eye(50)*10);  %#ok<NASGU>
  vrassert strcmp(a, 'asdf'); 
  vrassert all(all(b == eye(50)*10));  
  
  a = e({99}); eqtest(a, {99}); 
  
  a = e({1 2 3}); eqtest(a, {1 2 3});
  
  [a,b] = e({'asdf'}, {[1 2 3], {'def', 5, [6 7]}});
  eqtest(a, {'asdf'});
  eqtest(b, {[1 2 3], {'def', 5, [6 7]}});
  
  % structs are not supported yet by the backend
  %e(struct('a',1, 'b',[2 3])); eqtest(ans, struct('a',1, 'b',[2 3]));
  
  iprintf('Success!');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
function eqtest(c1,c2)

vrassert strcmp(class(c1), class(c2));
vrassert all(size(c1) == size(c2));
if iscell(c1)
  for i=1:numel(c1)
    eqtest(c1{i}, c2{i});
  end
elseif isstruct(c1)
  n1 = fieldnames(c1);
  n2 = fieldnames(c2);
  vrassert all(size(n1) == size(n2));
  vrassert isempty(setdiff(n1, n2));
  for i=1:numel(n1)
    eqtest(c1.(n1(i)), c2.(n2(i)));
  end
else
  vrassert c1 == c2;
end

end

end

function d=imageDiff(a,b)
%d=imageDiff(a,b)
%  Computes a "robust" distance between two images, A and B.  Since we
%  periodically need to tweak the exact algorithm, we do not publicly
%  document the exact one used here (it's likely to change over time).
%
%  Units of D are intensity values (the same units of the values in A and
%  B). 
%
%  Motivation:
%  When testing our videoReader objects, we often need to check to see if
%  frames from different videoReaders are the "same".  Unfortunately,
%  many decoders will produce slightly different images when decoding the
%  same frame from the same source video, even when on the same machine.
%  As such, we cannot just check pure equality.  Instead, we need to
%  tolerate small differences.  This function is designed to allow for
%  decoder inconsistencies while still producing non-zero differences for
%  intensity differences that might be meaningful.  
%
%  This function has been customized for use with the videoIO tests.

vrassert ndims(a)==ndims(b);
vrassert all(size(a)==size(b));
vrassert isa(a,'uint8'); % We'd need to adjust thresholds for other types
vrassert strcmp(class(a),class(b));

ad = clipper(mydiff(a,b));
if isempty(ad)
  d = 0;
else
  rms = sqrt(mean(ad.^2));
  d = rms;
end

%-------------------------------------------------------------
function out = mydiff(a,b) 
% right now: absolute differences
out = abs(double(a(:)) - double(b(:)));

%-------------------------------------------------------------
function out = clipper(d) 
% right now: ignore small pixel intensity differences
dontCareErrThresh = 2;
out = d;
out(d<=dontCareErrThresh) = 0;

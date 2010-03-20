function assertSimilarImages(a,b)  %#ok<INUSD>
%assertSimilarImages(a,b) 
%  Checks to see if A and B are similar in an IMAGEDIFF sense using a
%  hand-tuned threshold.  
%
%  This function has been customized for use with the videoIO tests.

maxMeaninglessRms = 4; %#ok<NASGU>
vrassert imageDiff(a,b) < maxMeaninglessRms;

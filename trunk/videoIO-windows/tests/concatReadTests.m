function concatReadTests(plugin)
%concatReadTests
%concatReadTests(plugin)
%  Unit test for the 'concat' videoReader plugin.  We use a complex 
%  nested clip configuration.
%
%SEE ALSO:
%  videoReader
%  videoReader_concat
%
%  testAll

ienter

if nargin < 1,
  defaultPluginArgs = {};
  plugin = defaultVideoIOPlugin('videoReader');
else
  defaultPluginArgs = {'defaultPlugin',plugin};
end

% make sure the data are ready
extractFrames;

% Construct the "complex example" from the docs (adapted here slightly). 
inter146   = 'intersection147.25fps.xvid.avi';
inter300   = 'intersection300.orig.revel.avi';
numbers100 = 'numbers.uncompressed.avi';
frames100  = 'frames/numbers.*.mat';

vrConcat = videoReader({...
    inter146,...                                % ~146 frames
    {inter300,'maxFrames',200},...              %  200 frames
    videoReader({...                            %  275 frames aggregate
        inter146, ...                           %    100 frames
        {numbers100, 'maxFrames', 50},...       %     50 frames
        {inter300, 'maxFrames',125},...         %    125 frames
      },'concat','maxFrames',100),...
    {frames100, 'load', 'varname','frame'},...  %  100 frames
  }, 'concat', defaultPluginArgs{:});

vrClip = videoReader(inter146, plugin);
n146 = get(vrClip, 'numFrames');
close(vrClip); clear vrClip;

% Use hard-coding to test reading the whole thing using NEXT
checkNextNFrames(vrConcat, inter146,   plugin, n146);
checkNextNFrames(vrConcat, inter300,   plugin,  200);
checkNextNFrames(vrConcat, inter146,   plugin,  100);
checkNextNFrames(vrConcat, numbers100, plugin,   50);
checkNextNFrames(vrConcat, inter300,   plugin,  125);
checkNextNFrames(vrConcat, frames100,  'load',  100);

% Random seek tests, again using hard-coding to avoid just duplicating
% the 'concat' plugin logic here.  
iInter146   = doFullRead(inter146,   plugin);
iInter300   = doFullRead(inter300,   plugin);
iNumbers100 = doFullRead(numbers100, plugin);
iFrames100  = doFullRead(frames100,  'load');
totalFrames = (n146+200+50+100+125+100);
for i=1:1000  
  % We randomly sample a bunch of frame positions and lookup the results
  % from directly reading the videos.
  f = min(floor(rand(1)*totalFrames), totalFrames-1);
  vrassert seek(vrConcat, f);
  testFrame = getframe(vrConcat);
  testFrame = uint8(sum(double(testFrame), 3) / size(testFrame,3));
  if f<n146
    shouldBePrecise = 0;  
    cmpName  = inter146;
    cmpClip  = iInter146;
    cmpFrame = f;
  elseif f<n146+200
    shouldBePrecise = 0;  
    cmpName  = inter300;
    cmpClip  = iInter300;
    cmpFrame = f-n146;
  elseif f<n146+200+100
    shouldBePrecise = 0;  
    cmpName  = inter146;
    cmpClip  = iInter146;
    cmpFrame = f-n146-200;
  elseif f<n146+200+100+50
    shouldBePrecise = 1; % uncompressed has no excuse for being imprecise
    cmpName  = numbers100;
    cmpClip  = iNumbers100;
    cmpFrame = f-n146-200-100;
  elseif f<n146+200+100+50+125
    shouldBePrecise = 0;  
    cmpName  = inter300;
    cmpClip  = iInter300;
    cmpFrame = f-n146-200-100-50;
  elseif f<n146+200+100+50+125+100
    shouldBePrecise = 1; % by-frame always should be precise
    cmpName  = frames100;
    cmpClip  = iFrames100;
    cmpFrame = f-n146-200-100-50-125;
  else
    error('bad random frame number: bug in the test code');
  end
  
  try
    assertSimilarImages(testFrame, cmpClip(:,:,cmpFrame+1));
  catch %#ok<CTCH>: backward compatability
    msgId = 'videoio:tests:concatReadTest:imprecise';
    msg = sprintf(['Frame %d from the concatenated source looks ' ...
                   'different from frame %d from "%s" (randomly '...
                   'selected frame #%d).  This is either because the '...
                   'decoder jumped to the wrong frame (imprecise '...
                   'seeking) and/or it used a low-quality decode to '...
                   'make the random seek faster.'], ...
                   f, cmpFrame, cmpName, i);
    
    % Change showErrors if you want to compare the two frames
    showErrors = 0;
    if showErrors
      clf;
      subplot(121); imshow(testFrame); 
      title(sprintf('concat frame %d', f));
      subplot(122); imshow(cmpClip(:,:,cmpFrame+1)); 
      title(sprintf('expected frame (%d from %s)', cmpFrame, cmpName));     
      drawnow
    end

    % For the mpeg4 videos, we'll just issue warnings for mismatched frames.
    if shouldBePrecise
      error(msgId, '%s', msg);
    else
      warning(msgId, '%s', msg);
    end
  end
end

% clean up
close(vrConcat);

iexit

%-----------------------------------------
function checkNextNFrames(vrConcat, clipName, plugin, nFrames)
%checkNextNFrames(vrConcat, clipName, plugin, nFrames)
%  Check the next NFRAMES frames from VRCONCAT and make sure they look
%  like the first NFRAMES from the CLIPNAME when loaded with the
%  requested PLUGIN.  If NFRAMES is omitted, we use all frames from
%  CLIPNAME. 

vrClip = videoReader(clipName, plugin);
if nargin<4
  nFrames = get(vrClip,'numFrames');
end

%ienter('>>> checkNextNFrames(...,''%s'',''%s'',%d)', clipName,plugin,nFrames);

for i=1:nFrames
  try
    vrassert next(vrConcat);
    vrassert next(vrClip);

    assertSimilarImages(getframe(vrConcat), getframe(vrClip));
  catch %#ok<CTCH>: backward compatability
    err = lasterror; %#ok<LERR>: backward compatability
    error(['Error checking frame %d of %s against the\ncorresponding ' ...
           'concatenated source.\n\n%s'], i-1, clipName, err.message);
  end
end
close(vrClip);

%iexit;

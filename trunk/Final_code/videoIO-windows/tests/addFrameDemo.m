function addFrameDemo
%addFrameDemo
%  A script demonstrating various ways of using the videoWriter/addframe
%  method.  For a simpler example with extensive comments, see
%  videoWriterDemo.
%
%Example:
%  addFrameDemo

ienter;

if exist('buildVideoIO', 'file') == 2, buildVideoIO; end

N = 10;       % number of frames in each video
W=320; H=240; % size of all our videos

%==========================================================================
% Standard approach: individual RGB frames
vw = openVid('rgb',W,H, 'It should have swirling ellipses and the frame number printed in pixelated numerals in the lower right.');
for i=0:N
  frame = genTestFrame(W,H,i,N*2);
  addframe(vw, frame);
end
vw = closeVid(vw); %#ok<NASGU>

%==========================================================================
% individual grayscale frames
vw = openVid('gray',W,H, 'It should look like the RGB example, except the output will be grayscale.');
for i=0:N
  frame = rgb2gray(genTestFrame(W,H,i,N*2)); % NOTE: rgb2gray
  addframe(vw, frame);
end
vw = closeVid(vw); %#ok<NASGU>

%==========================================================================
% auto-resizing
vw = openVid('resize',W,H, 'The pixelated numbers should be twice as wide as usual.');
for i=0:N
  frame = genTestFrame(W/2,H,i,N*2); % NOTE: W/2
  addframe(vw, frame);
end
vw = closeVid(vw); %#ok<NASGU>

%==========================================================================
% multiple frames all at once
vw = openVid('multiframe',W,H, 'This should be identical to the RGB example.');
frames = cell(1,N);
for i=0:N
  frames{i+1} = genTestFrame(W,H,i,N*2);
end
addframe(vw, frames{:}); % NOTE: adding all at once
vw = closeVid(vw); %#ok<NASGU>

%==========================================================================
% offscreen rendering of a multi-plot figure
vw = openVid('figure',W,H, 'The frames are extracted from a figure with subplots.  The video will probably have a warped aspect ratio.');
fig = figure;
for i=0:N
  frame = genTestFrame(W,H,i,N*2);
  subplot(121); 
  imagesc(frame);
  title(sprintf('frame %d', i));
  
  subplot(122);
  plot(rand(5));
  title('some random lines');
  xlabel('x axis');
  ylabel('y axis');
  
  drawnow; % just so the user can see the animation
    
  addframe(vw, gcf); % NOTE: figure handle
end
vw = closeVid(vw); %#ok<NASGU>
close(fig);

%==========================================================================
% hidden offscreen rendering
vw = openVid('fancyFig',W,H, 'Offscreen rendering with no border, and some vector drawings added.');
fig = figure; 
clf;
% NOTE: keep the window hidden so it doesn't bother the user and they can't
%       accidentally change focus to a new figure window.
set(fig, 'Visible','off');     
% NOTE: lock down the figure size so there will be no IMRESIZE call needed
%       in ADDFRAME.
set(fig,'Units','pixels', 'Position',[0 0 W H]); 
% NOTE: Eliminates the padding around the axis client are used for the
%       title, xlabel, ylabel, etc.  
subplot('Position',[0 0 1 1]); 
houseX = [ 0  0  2  2  1  0  2 nan  0.75  0.75  1.25  1.25] / 3 * H/4;
houseY = [-2  0  0 -2 -3 -2 -2 nan  0    -1.25 -1.25  0   ] / 3 * H/4 + H/2;
for i=0:N
  frame = genTestFrame(W,H,i,N*2);
  imshow(frame);
  % NOTE: adding drawing elements
  line(houseX+(i+1)*(W-max(houseX))/(N+1), houseY, ...
    'LineWidth',5, 'Marker','.'); 
  text(10,25, 'a flying house!', 'FontSize',16);
  addframe(vw, gcf); % NOTE: figure handle
end
vw = closeVid(vw); %#ok<NASGU>
close(fig);

%==========================================================================
vw = openVid('getframe',W,H, 'Same as fancyFig, but GETFRAME is used.  Note that depending on a number of factors, GETFRAME may use screen capturing instead of off-screen rendering, so anything sitting atop the window may be captured.');
fig = figure; 
clf;
set(fig, 'Visible','off');     
set(fig,'Units','pixels', 'Position',[0 0 W H]); 
subplot('Position',[0 0 1 1]); 
houseX = [ 0  0  2  2  1  0  2 nan  0.75  0.75  1.25  1.25] / 3 * H/4;
houseY = [-2  0  0 -2 -3 -2 -2 nan  0    -1.25 -1.25  0   ] / 3 * H/4 + H/2;
for i=0:N
  frame = genTestFrame(W,H,i,N*2);
  imshow(frame);
  line(houseX+(i+1)*(W-max(houseX))/(N+1), houseY, ...
    'LineWidth',5, 'Marker','.'); 
  text(10,25, 'a flying house!', 'FontSize',16);
  movFrame = getframe(gcf); % NOTE: as of R2007a, this causes the frame to be displayed even though 'visible' is 'off'...a feature request has been submitted to MathWorks.
  addframe(vw, movFrame); % NOTE: getframe used here to obtain a mov structure
end
vw = closeVid(vw); %#ok<NASGU>
close(fig);

%==========================================================================
iprintf(['View ' mfilename '_*.avi in your favorite image viewer, ' ...
         'then delete them if you do not want to keep them.']);
iexit;
return

%==========================================================================
%==========================================================================
%==========================================================================
%==========================================================================

%-----------------------------
function vw = openVid(name,W,H,desc)
ienter(['Creating "' mfilename '_' name '.avi".  ' desc]);
close all;
vw = videoWriter([mfilename '_' name '.avi'], 'width',W, 'height',H);

%-----------------------------
function vw = closeVid(vw)
vw = close(vw);
iexit('');

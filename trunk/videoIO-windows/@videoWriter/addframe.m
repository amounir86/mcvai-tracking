function addframe(vw,varargin)
%ADDFRAME  Add video frame to VIDEOWRITER stream.
%   ADDFRAME(VW,IMG) appends the data in IMG to VW, which is created
%     with VIDEOWRITER.  IMG can be either a grayscale image (M-by-N) or a
%     truecolor image (M-by-N-by-3) of logical, double, or uint8  precision.
%     IMG is autoconverted to a uint8 image as follows:  
%
%          type     assumed range
%          ----     -------------
%          uint8    0 to 255
%          double   0 to 1
%          logical  0 to 1
%
%     If IMG is a different size than needed for the video file, it will be
%     resized with the highest quality method available of IMRESIZE. 
%
%     Returns 0 on failure and 1 on success.
%
%     STANDARD EXAMPLE:
%       vw = videoWriter('example1.avi');
%       for i=1:10
%         addframe(vw, rand(100)); % a double grayscale image
%       end
%       vw = close(vw);
%
%   ADDFRAME(VW,IMG1,IMG2,IMG3,...) adds multiple frames to a video stream.
%
%   ADDFRAME(VW,MOV) appends the frame(s) contained in the MATLAB movie MOV
%     to the AVI file.  The CDATA field is interpreted in the same way that
%     ADDFRAME(VW,IMG) interprets images.
%
%   ADDFRAME(VW,H) captures a frame from the figure handle H, and appends
%     this frame to the video stream. The frame is rendered into an
%     offscreen array before it is appended to the video stream.  This
%     syntax should not be used if the graphics in the animation are using
%     XOR graphics. 
%
%     FIGURE HANDLE EXAMPLE:
%       fig = gcf;
%       hax = gca;
%       vw = videoWriter('example2.avi', 'width',320, 'height',240);
%       for i=1:10
%         image(k.*peaks,'parent',hax);
%         set(gca,'Zlim',[-20 20]); 
%         addframe(vw,fig);
%       end
%       vw = close(vw);
%
%     If the animation is using XOR graphics, use GETFRAME instead to
%     capture the graphics into one frame of a MATLAB movie and then use
%     the syntax ADDFRAME(VW,MOV) as in the example below. GETFRAME will
%     perform a snapshot of the onscreen image. 
%
%     GETFRAME/MOV EXAMPLE:
%       fig=figure;
%       set(fig,'DoubleBuffer','on');
%       set(gca,'xlim',[-80 80],'ylim',[-80 80],...
%           'nextplot','replace','Visible','off')
%       vw = videoWriter('example3.avi', 'width',320, 'height',240);
%       x = -pi:.1:pi;
%       radius = [0:length(x)];
%       for i=1:length(x)
%         h = patch(sin(x)*radius(i),cos(x)*radius(i),[abs(cos(x(i))) 0 0]);
%         set(h,'EraseMode','xor');
%         frame = getframe(gca);
%         addframe(vw,frame);
%       end
%       vw = close(vw);
%
%   COMPARISON WITH AVIFILE/ADDFRAME
%     This version of VIDEOWRITER/ADDFRAME was initially adapted from
%     MathWorks's AVIFILE/ADDFRAME.  We use undocumented features of Matlab
%     to allow capturing images from figure handles.  This method works
%     largely the same as MathWork's, with the following differences:
%
%     Unlike AVIFILE/ADDFRAME, this method does not support indexed images:
%     2D arrays are treated as grayscale images, not as indexed ones.  The
%     user may use Matlab's IND2RGB or IND2GRAY to convert indexed images
%     to rgb or grayscale images.
%
%     VIDEOWRITER/ADDFRAME also does not currently pad frames that are not
%     a multiple of 4 in width.  If the width and height do not match the
%     expected, the frame is rescaled instead using the highest known
%     quality method of IMRESIZE.
%
%     Matlab's AVIFILE/ADDFRAME allows the user to supply an axis handle or
%     a figure handle; however, when supplying an axis handle, the entire
%     figure is captured, not just the axis in question.  Since we consider
%     this to be counter-intuitive, we do not support capturing based on
%     the axis handle.  Furthermore, we would like to reserve the right to
%     actually cropping out just the axis in question if we add axis handle
%     support in the future.  If you have an axis handle and need the
%     figure handle, use GET(MYAXISHANDLE,'parent').
%
%     As of Matlab R2007a, AVIFILE/ADDFRAME makes a number of assumptions
%     when using the figure handle method.  It also modifies properties
%     of the figure window without restoring them.  We restore all
%     changed properties and we are robust to the figure 'units' property.
%
%   SEE ALSO
%     videoWriter
%     videoWriter/close
%     avifile/addframe
%     tests/addFrameDemo
%     tests/videoWriterDemo
%
%Copyright (c) 2008 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux). 

numframes = nargin - 1;
error(nargoutchk(0,0,nargout));
if ~isa(vw,'videoWriter')
  error('First input must be an videoWriter object.');
end

for i = 1:numframes
  MovieLength = 1;
  mlMovie = 0;
  % Obtain frame(s) from this input arg
  inputType = getInputType(varargin{i});
  switch inputType
    case 'axes'
      error(['Axis handles are not supported at the current time.  See ' ...
        mfilename '''s documentation for the reasons.']);
      %frame = extractFrameFromFigure(get(varargin{i},'parent'));
    case 'figure'
      frame = extractFrameFromFigure(varargin{i});
    case 'movie'
      mlMovie = 1;
      MovieLength = length(varargin{i});
      % no need to handle indexed images here either
    case 'data'
      frame = varargin{i};
    otherwise
      error('Unrecognized input type: %s', inputType);
  end
  
  % Add each frame extracted from this input arg
  for j = 1:MovieLength
    if mlMovie
      frame = varargin{i}(j).cdata;
    end
    addSingleDataFrame(vw, frame);
  end
end
return;

% ------------------------------------------------------------------------
function addSingleDataFrame(vw,img)
% Handles type conversion, rescaling, and grayscale->RGB conversion, as
% necessary.  Then, the backend is called to add the frame.

[h,w,d] = size(img);

% If the width and height were not set in the constructor, assume that
% the incoming image can be handled by the backend without rescaling
% here.  Note: since we don't return vw, these values do not persist, for
% now. 
if vw.w < 0, vw.w = w; end
if vw.h < 0, vw.h = h; end

if (isa(img, 'uint8'))
  if (h ~= vw.h || w ~= vw.w)
    img = uint8(255*imresize(double(img)/255, [vw.h vw.w]));
  else
    % no changes needed
  end
  
elseif (isa(img, 'double') || islogical(img))
  if (h ~= vw.h || w ~= vw.w)
    img = uint8(255*imresize(img, [vw.h vw.w], defaultResizeMethod));
  else
    img = uint8(255*img);
  end
  
else
  error('Invalid image type.');
end

if (d == 1)
  img = repmat(img, [1 1 3]);
end

feval(vw.plugin, 'addframe', vw.handle, img);
return;

% ------------------------------------------------------------------------
function m = defaultResizeMethod

verdata = ver('Matlab');
verparts = sscanf(verdata.Version,'%d.');
vernum = dot(logspace(0,(1-length(verparts))*2, length(verparts)), verparts);

if vernum>7.0400 % R2007a or later -- lanczos3 is allowed
  m = 'lanczos3';
else
  m = 'bicubic';
end
return;

% ------------------------------------------------------------------------
function inputType = getInputType(frame)
if isscalar(frame) && ishandle(frame) && (frame > 0)
  inputType = get(frame,'type');
  
elseif isstruct(frame) && isfield(frame,'cdata')
  % we do not support indexed images
  if isfield(frame(1),'colormap') && ~isempty(frame(1).colormap)
    error('Indexed frames are not supported at this time.');
  end
  inputType = 'movie';
  
elseif isa(frame,'numeric')
  inputType = 'data';
  
else
  error('Invalid input argument.  Each frame must be a numeric matrix, a MATLAB movie structure, or a handle to a figure or axis.');
end
return;

% ------------------------------------------------------------------------
function frame = extractFrameFromFigure(fig)

% The renderer requires DPI units.  Get the necessary conversion factor.
pixelsperinch = get(0,'screenpixelsperinch');

% The easiest way to obtain the conversion is to switch to pixel units.
% This provides robustness to whatever units the user was using previously.
oldUnits = get(fig,'units');
set(fig,'units','pixels');

% Now we obtain the figure size
pos = get(fig,'position');
oldPaperPosition = get(fig,'paperposition');
set(fig, 'paperposition', pos./pixelsperinch);

% Upgrade no renderer and painters renderer to OpenGL for the off-screen
% rendering, because that's what AVIFILE/ADDFRAME does.
renderer = get(fig,'renderer');
if strcmp(renderer,'painters') || strcmp(renderer,'None')
  renderer = 'opengl';
end

% Temporarily turn off warning in case opengl is not supported and
% hardcopy needs to use zbuffer
warnstate = warning('off', 'MATLAB:addframe:warningsTurnedOff');
noanimate('save',fig);
frame = hardcopy(fig, ['-d' renderer],['-r' num2str(round(pixelsperinch))]);
noanimate('restore',fig);
warning(warnstate);

% Restore figure state.  We do it in the opposite order that it was changed
% so dependent state elements work correctly (esp. paperposition's
% interplay with units).
set(fig, 'paperposition', oldPaperPosition);
set(fig, 'units',oldUnits); 

return

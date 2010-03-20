%function vp = videoPlayer(varargin)
% 
% A GUI for @videoReader .
%
% vp = videoPlayer() creates the GUI and returns a videoPlayer object
% 
% vp = videoPlayer(varargin) is equivalent to
% vp = videoPlayer(); vp.open(varargin{:});
%
% This object has the following member functions:
%
% - vp.open(vararing) 
% opens a video by calling videoReader(vararing{:})
%
% - vp.close() 
% closes the video
%
% - vp.quit() 
% destroys the GUI. Note vp is no longer usable after it quits
%
% - frameNum = vp.currentFrame() 
% returns the current frame number
%
% - vp.seek(fn) 
% seeks to frame number fn
%
% - vp.actualSize()
% resizes teh GUI to the native video res
%
% - vp.setFilters(filters)
% sets up filters to be appled to frames filters should be a function
% handle (or cell array of them) of the form:
% imageOut = f(imageIn)
% filters aare applied in order filter{n}(filter{n-1}(...filter{1}(img)..)
%
% - label = vp.addRectRegion(pos)
% Adds an imrect selector to the video, if no position is specified it
% lets the user click and drag region. This function returns a label for
% the region
% 
% - vp.deleteRegion(label)
% Removes the labeled region
%
% - vp.deleteAllRegions()
% deletes all the regions
%
% - labels = vp.regionLabels
% returns an array of region labels currently active
%
% - vp.getRegionInfo(labels=[],getImagePatch=1)
% returns a cell array with each element ii being infromation about region
% labels(ii) (if it exists). If you pass in an empty array for labels it
% will return all region information. Pass in 0 for getImagePatch if you
% don't want to return the current frame within each region.
%
%
% Simple Example:
% This opens a vieo specified by videoPath, and sets up a filter to blur it
%
% vp = videoPlayer();
% vp.open(videoPath)
% 
% blur = @(img) imfilter(img,fspecial('gaussian',5,5));
% vp.setFilters(blur);

% Michael Siracusa
% Version b1  3/31/08

function vp = videoPlayer(varargin)
  
  
  % Setup Local Variables
  vr = [];
  vrInfo = [];
  
  regions.numRegions = 0;
  regions.handles = [];
  regions.labels = [];
  regions.labelHandles = [];
  
  frameNumber = 0;
  totalFrames = 0;
  
  currentImage = [];
  
  width = 300;
  height = 65;
   
  isPlaying   = 0;
  
  filters = {};
  
  % Create the GUI
  handles = createGUI();

  % Setup callbacks
  set(handles.figure,'DeleteFcn',{@close_Callback});
  set(handles.figure,'ResizeFcn',{@resize_Callback});
  set(handles.bttnPlayPause,'Callback',{@playPause_Callback});
  set(handles.sldrTime,'Callback',{@timeLine_Callback});

  updateGUIState();
  
  if nargin > 0
    openVideo(varargin{:});
  end
  
  layoutGUI();
  set(handles.figure,'Visible','on');
  
  % Make "object", supply member functions
  vp.open = @(varargin) openVideo(varargin{:});
  vp.close = @() closeVideo();
  vp.quit = @() close(handles.figure);
  vp.currentFrame = @currentFrame;
  vp.seek = @(fn) goToFrame(fn);
  vp.setFilters = @(f) setFilters(f);
  vp.actualSize = @() actualSize();
  
  vp.addRectRegion = @(varargin) addRectRegion(varargin{:});
  vp.regionLabels = @() getRegionLabels(); 
  vp.deleteAllRegions = @deleteAllRegions;
  vp.deleteRegion = @(label) deleteRegion(label);
  vp.getRegionInfo = @(varargin) getRegionInfo(varargin{:});
  
  function h = createGUI()
    % Make figure
    h.figure = figure('Visible','off','Menubar','None','Tag','VideoPlayer');

    % Make the video/image axis
    h.axesImage = axes('Units','pixels');
    axis(h.axesImage,'off');
    
    % Place the Pause/Play button
    h.bttnPlayPause = uicontrol('Style','pushbutton','String','Play');

    % Add time line slider
    h.sldrTime = uicontrol('Style','Slider');
    
    % Set the image handle to empty, indicated nothing has been plotted yet
    h.image = [];
    
    % Add a File->Open and Close
    h.menuFile = uimenu('Label','File');
    uimenu(h.menuFile,'Label','Open ...','Callback',{@menuOpen_Callback},'Accelerator','o');
    uimenu(h.menuFile,'Label','Close','Callback',{@menuClose_Callback},'Accelerator','w');
    uimenu(h.menuFile,'Label','Quit','Callback',{@menuQuit_Callback},'Accelerator','q','Separator','on');
   
    % Add a view menu
    h.menuView = uimenu('Label','View');
    uimenu(h.menuView,'Label','Actual Size','Callback',{@menuActualSize_Callback},'Accelerator','=');
    uimenu(h.menuView,'Label','Next Frame','Callback',{@menuNextFrame_Callback},'Accelerator','n','Separator','on');
    uimenu(h.menuView,'Label','Previous Frame','Callback',{@menuPreviousFrame_Callback},'Accelerator','p');   
    uimenu(h.menuView,'Label','Frame Number...','Callback',{@menuViewFrame_Callback},'Accelerator','f','Separator','on');
    
    % add a tool menu
    h.menuTools = uimenu('Label','Tools');
    uimenu(h.menuTools,'Label','Add Rect Region','Callback',{@menuAddRectRegion_Callback},'Accelerator','r');
    uimenu(h.menuTools,'Label','Delete All Regions','Callback',{@menuDeleteAllRegions_Callback},'Separator','on');
    
  end

  function layoutGUI()
    % Layout Figure
    p = get(handles.figure,'Position');
    set(handles.figure,'Position',[p(1) p(2), width height]);

    set(handles.axesImage,'Position',[5 40 width-10 height-60]);
    axis(handles.axesImage,'off');

    set(handles.bttnPlayPause,'Position',[5 5 60 30]);
   
    set(handles.sldrTime,'Position',[70 5 width-70 30],...
                         'SliderStep',[1/max(1,totalFrames) min(1,10/totalFrames)]);
  
  end


  function updateGUIState
    if ~videoIsOpen()
      set(handles.bttnPlayPause,'Enable','off');
      set(handles.sldrTime,'Enable','off');
      axes(handles.axesImage); cla;
      title('');
      set(handles.menuView,'Enable','off');
      set(handles.menuTools,'Enable','off');
    else
      set(handles.bttnPlayPause,'Enable','on');
      set(handles.sldrTime,'Enable','on');
      set(handles.axesImage,'Visible','on');
      set(handles.menuView,'Enable','on');
       set(handles.menuTools,'Enable','on');
    end
  end

  
  function fn =  currentFrame()
    fn = frameNumber;
  end

  function tf = videoIsOpen()
    tf = ~isempty(vr);
  end

  function goToFrame(fn)
    
    if videoIsOpen()
      frameNumber = min(totalFrames-1,max(0,frameNumber));
      
      % Seek to specified frame
      frameNumber = fn;
      seek(vr,frameNumber);

      % Update display
      img = getframe(vr);

      % if there are filters apply them
      img = applyFilters(img);

      currentImage = img;
      
      if ishandle(handles.image)
        set(handles.image,'CData',img);
      else
        axes(handles.axesImage);
        handles.image = imshow(img);
      end
      
      title(['Frame ' num2str(frameNumber) ' of ' num2str(totalFrames-1)]);
      drawnow;

      % Update timeline
      set(handles.sldrTime,'Value',frameNumber/(totalFrames-1));
    
    else
      axes(handles.axesImage); imshow([ 0 0 0]);
    end
  end

  function setFilters(filts)
    if ~iscell(filts)
      filters = {filts};
    else
      filters = filts;
    end
    goToFrame(currentFrame());
    
    
    if size(currentImage,3) == 1,
      set(handles.image,'CDataMapping','scaled');
    else
      set(handles.image,'CDataMapping','direct');
    end
      
  end

  function out = applyFilters(in)
    out = in;
    for k=1:length(filters)
      out = filters{k}(out);
    end
  end

  function openVideo(varargin)
    
    if nargin < 1 || ~ischar(varargin{1})
      error('You must supply a url to open');
    end
    
    if videoIsOpen()
      closeVideo();
    end
    
    if nargin == 1
    
      % My little hack to handle .toc files
      fname = varargin{1};
      [a,b,ext] = fileparts(fname);
      
       switch lower(ext)
         case '.toc'
           vr = videoReader(fname,'libmpeg3Direct');
         otherwise
           vr = videoReader(fname);
       end
       
    else
      
      vr = videoReader(varargin{:});
    
    end
    
    vrInfo = get(vr);
  
    frameNumber = vrInfo.approxFrameNum;
    totalFrames = vrInfo.numFrames;
    
    goToFrame(0);
    
    updateGUIState();
    actualSize();
  end

  function closeVideo(varargin)
    if videoIsOpen()
      close(vr);
    end
    
    deleteAllRegions();
    vr = [];   
    handles.image =[];
    
    width = 300;
    height = 65;
    layoutGUI();
    updateGUIState();
    
  end

  function actualSize()
    if videoIsOpen()
      width = vrInfo.width + 10;
      height = vrInfo.height + 60;
    end
    
    layoutGUI();
    
  end

  function label = addRectRegion(posSize)
    if nargin == 0
      posSize = [];
    end
    
    % Create the region
    regions.handles(end+1) = imrect(handles.axesImage,posSize);
   
    indx = length(regions.handles);
   
    % Give it a label
    
    if indx == 1
      regions.labels(1) = 1; 
    else
      regions.labels(indx) = max(regions.labels)+1;
    end
    
    label = regions.labels(indx);
    
    % Get its api
    api = iptgetapi(regions.handles(indx));
    
    
    % Get the position
    posSize = api.getPosition();
    
    % Put a regionLabel in the center of it
    cx = posSize(1) + posSize(3)/2;
    cy = posSize(2) + posSize(4)/2;
    
    regions.labelHandles(indx) = text(cx,cy,num2str(label),...
                                    'FontSize',14,'BackgroundColor','white');
    
    % Add a context menu for deleting    
    cm = uicontextmenu;
    uimenu(cm,'Label',['Delete Region ' num2str(label)],'Callback',{@deleteRegion_Callback,label});
    set(regions.labelHandles(indx),'UIContextMenu',cm);
   
    % Keep region within image limits
    fcn = makeConstrainToRectFcn('imrect',get(handles.axesImage,'XLim'),get(handles.axesImage,'YLim'));
    api.setDragConstraintFcn(fcn);
   
    % Move the label with the rect
    api.addNewPositionCallback(@(p) updateRegionLabelPosition(label));
    
    regions.numRegions = regions.numRegions + 1;
    
  end

  function labels = getRegionLabels()
    labels = regions.labels;
  end

  function deleteRegion(label)
  
    indx = find(regions.labels == label,1,'first');
    deleteRegionAtIndex(indx);
  end

  function deleteRegionAtIndex(indx)
    api = iptgetapi(regions.handles(indx));
    
    api.delete();
    delete(get(regions.labelHandles(indx),'UIContextMenu'));
    delete(regions.labelHandles(indx));
    
    regions.handles(indx) = [];
    regions.labels(indx) = [];
    regions.labelHandles(indx) = [];
    
    regions.numRegions = regions.numRegions - 1;
      
  end

  function deleteAllRegions()
    
    nr = regions.numRegions;
    for k=1:nr
      deleteRegionAtIndex(1);
    end
  end


  function updateRegionLabelPosition(label)

    indx = find(regions.labels == label,1,'first');
    
    api = iptgetapi(regions.handles(indx));
    
    posSize = api.getPosition();
    
    % Put a regionLabel in the center of it
    cx = posSize(1) + posSize(3)/2;
    cy = posSize(2) + posSize(4)/2;
    
    
    set(regions.labelHandles(indx),'Position',[cx cy 0]);
  end

  function regionInfo = getRegionInfo(varargin)
    
    labels = [];
    getImagePatch = 1;
    
    if nargin >= 1, labels = varargin{1}; end
    if nargin == 2, getImagePatch = varargin{2}; end
    
    if isempty(labels), labels = regions.labels; end
    
    indx = 1; 
    regionInfo = cell(length(labels),1);
    for l=labels
      clear r;
      
      k = find(regions.labels == l,1,'first');
      
      if isempty(k), continue; end
      
      r.type = 'rect';
      r.label = l;
      
      api = iptgetapi(regions.handles(k));
      posSize = api.getPosition();
      
      r.x = posSize(1);
      r.y = posSize(2);
      r.width = posSize(3);
      r.height = posSize(4);
      r.center = [r.x + r.width/2; r.y + r.height/2];
      r.indexX  = round(r.x):round(r.x+r.width);
      r.indexY  = round(r.y):round(r.y+r.height);
      
      if getImagePatch
        r.image = currentImage(r.indexY,r.indexX,:);
      end
      
      regionInfo{indx} = r; 
      
      indx = indx + 1;
    end
    
  end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Callbacks


  function playPause_Callback(source,eventdata) %#ok<INUSD>
    
    isPlaying = ~isPlaying;
    

    if isPlaying
      set(handles.bttnPlayPause,'String','Pause');
    else
      set(handles.bttnPlayPause,'String','Play');
    end
    
    while isPlaying && frameNumber < (totalFrames-1)
      goToFrame(frameNumber + 1);
      pause(1/vrInfo.fps);
    end
    
    if frameNumber >= (totalFrames-1)
      isPlaying = 0;
      set(handles.bttnPlayPause,'String','Play');
    end
    
  end

  function timeLine_Callback(source,eventdata) %#ok<INUSD>
    v = get(handles.sldrTime,'Value');
    
    goToFrame(round(v*(totalFrames-1)));
    
  end

  function close_Callback(source,eventdata) %#ok<INUSD>
    closeVideo();
  end

  function resize_Callback(source,eventdata) %#ok<INUSD>
    p = get(handles.figure,'Position');
    
    width = max([p(3)  100]);
    height = max([p(4) 65]);
    
    layoutGUI();
    
  end

  function menuClose_Callback(source,eventdata) %#ok<INUSD>
    closeVideo();
  end

  function menuOpen_Callback(source,eventdata) %#ok<INUSD>
     [fname,pname] = uigetfile('*.*','Select the a Video File');
     
     if ~isequal(fname,0)
       openVideo([pname fname]);
     end
  end

  function menuActualSize_Callback(source,eventdata) %#ok<INUSD>
    actualSize();
  end

  function menuQuit_Callback(source,eventdata) %#ok<INUSD>
    close(handles.figure);
  end

  function menuNextFrame_Callback(source,eventdata) %#ok<INUSD>
    goToFrame(frameNumber-1);
  end

  function menuViewFrame_Callback(source,eventdata) %#ok<INUSD>
    prompt = ['Go to Frame [0 ' num2str(totalFrames) ']'];
    ttl = 'View Frame';
    
    answer = inputdlg(prompt,ttl,1);
    
    if length(answer) == 1
      goToFrame(str2double(answer{1}));
    end
    
  end

  function menuPreviousFrame_Callback(source,eventdata) %#ok<INUSD>
    goToFrame(frameNumber+1);
  end

  function menuAddRectRegion_Callback(source,eventdata) %#ok<INUSD>
    addRectRegion();
  end

  function menuDeleteAllRegions_Callback(source,eventdata) %#ok<INUSD>
    deleteAllRegions();
  end


  function deleteRegion_Callback(source,eventdata,label) %#ok<INUSL,INUSD>
    deleteRegion(label);
  end



end

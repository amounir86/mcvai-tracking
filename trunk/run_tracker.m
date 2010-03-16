function T = run_tracker(fname, T)

vr = videoReader(fname);
p = findstr(fname,'.');
fnameOut = strcat(fname(1:p-1),'Tracker','.avi')
% vw = videoWriter(fnameOut);

T.time         = 0;
T.frame_number = 0;
T.fps          = getfield(get(vr), 'fps');
T.num_frames   = getfield(get(vr), 'numFrames');

while next(vr)
  T.frame_number = T.frame_number + 1;
  frame = getframe(vr);
  
  if isfield(T, 'segmenter')
    T = T.segmenter.segment(T, frame);
  end
  
  if isfield(T, 'recognizer')
    T = T.recognizer.recognize(T, frame);
  end
  
  if isfield(T, 'representer')
    T = T.representer.represent(T, frame);
  end
  
  if isfield(T, 'tracker')
    T = T.tracker.track(T, frame);
  end
  
  if isfield(T, 'visualizer')
    T = T.visualizer.visualize(T, frame);
  end

%   addframe(vw, T.visualizer.imageFinal );
  pause(0.01);
  T.time = T.time + 1/T.fps;
  
end
close(vr);
% close(vw);
return

function T = visualize_kalman(T, frame)

% Initialize the figure and setup pause callback.
if ~isfield(T.visualizer, 'init');
  figure(1),
  h = gcf;
  set(h, 'KeyPressFcn', {@pauseHandler, h});
  setappdata(h, 'paused', false);
  T.visualizer.init = true;
end

image(frame)

% Draw the current measurement in red.
if isfield(T.representer, 'all')
    for mBB = 1:length(T.representer.all)
        rectangle('Position', T.representer.all(mBB).BoundingBox, 'EdgeColor', 'r');
    end
end

% And the current prediction in green
if isfield(T.tracker.TObjs, 'm_k1k1');
    for kBB = 1:length(T.tracker.TObjs)
        rectangle('Position', T.tracker.TObjs(kBB).m_BB, 'EdgeColor', 'g');
    end
end
drawnow;


% If we're paused, wait (but draw).
while (getappdata(gcf, 'paused'))
  drawnow;
end
h = getframe;

T.visualizer.imageFinal = h.cdata;

return

% This is a callback function that toggles the pause state.
function pauseHandler(a, b, h)
setappdata(h, 'paused', xor(getappdata(h, 'paused'), true));
return


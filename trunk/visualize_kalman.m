function T = visualize_kalman(T, frame)

% Initialize the figure and setup pause callback.
if ~isfield(T.visualizer, 'init');
  figure;
  h = gcf;
  set(h, 'KeyPressFcn', {@pauseHandler, h});
  setappdata(h, 'paused', false);
  T.visualizer.init = true;
end

% Display the current frame.
subplot(2,2,1); image(frame);
subplot(2,2,2); imshow(T.segmenter.segmented,[]);
subplot(2,2,3); imshow(T.segmenter.background,[]);

% Draw the current measurement in red.
if isfield(T.representer, 'BoundingBox')
  rectangle('Position', T.representer.BoundingBox, 'EdgeColor', 'r');
end

% And the current prediction in green
if isfield(T.tracker, 'BBm_k1k1');
  rectangle('Position', T.tracker.BBm_k1k1, 'EdgeColor', 'g');
end
drawnow;

% If we're paused, wait (but draw).
while (getappdata(gcf, 'paused'))
  drawnow;
end
return

% This is a callback function that toggles the pause state.
function pauseHandler(a, b, h)
setappdata(h, 'paused', xor(getappdata(h, 'paused'), true));
return


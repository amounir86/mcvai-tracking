function T = visualize_kalman(T, frame)

% Initialize the figure and setup pause callback.
if ~isfield(T.visualizer, 'init');
  figure(1),
  h = gcf;
  set(h, 'KeyPressFcn', {@pauseHandler, h});
  setappdata(h, 'paused', false);
  T.visualizer.init = true;
end

% Display the current frame.
% subplot(2,3,1); 
image(frame);
% subplot(2,3,2); imshow(T.segmenter.segmented,[]);
% subplot(2,3,3); imshow(T.segmenter.background,[]);
% if isfield(T.representer,'real_frame_segmented');
%     subplot(2,3,4); imshow(T.representer.real_frame_segmented,[]);
%     rectangle('Position', T.representer.BoundingBox, 'EdgeColor', 'r');
%     subplot(2,3,5); image(frame);
%     subplot(2,3,6); stem(T.representer.histogram); axis([1 768 0 max(T.representer.histogram)]); 
% end

% Draw the current measurement in red.
if isfield(T.representer, 'BoundingBox')
    for mBB = 1:size(T.representer.BoundingBox, 1)
        rectangle('Position', T.representer.BoundingBox(mBB, :), 'EdgeColor', 'r');
    end
end

% And the current prediction in green
if isfield(T.tracker, 'BBm_k1k1');
    for kBB = 1:size(T.tracker.BBm_k1k1, 2)
        rectangle('Position', T.tracker.BBm_k1k1(:, kBB)', 'EdgeColor', 'g');
    end
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


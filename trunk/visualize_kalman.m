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
 subplot(2,3,1); image(frame);
 subplot(2,3,4); imshow(T.segmenter.color,[]);
 if length(T.segmenter.reconstruct) ~= 0
     subplot(2,3,3); imshow(uint8(reshape(T.segmenter.reconstruct,240,320)));
 end
 %subplot(2,3,3); imshow(reshape(T.segmenter.background(:,1),240,320),[]);
 subplot(2,3,2); imshow(T.segmenter.segmented,[]);
 

 
%  if isfield(T.representer,'real_frame_segmented');
%      subplot(2,3,4); imshow(T.representer.real_frame_segmented,[]);
%      rectangle('Position', T.representer.BoundingBox, 'EdgeColor', 'r');
%      subplot(2,3,5); image(frame);
%      subplot(2,3,6); stem(T.representer.histogram); axis([1 768 0 max(T.representer.histogram)]); 
%  end

% Draw the current measurement in red.
if isfield(T.representer, 'all')
    for mBB = 1:size(T.representer.all, 1)
        if(T.representer.all(mBB).isEmpty == 0)
            rectangle('Position', T.representer.all(mBB).BoundingBox, 'EdgeColor', 'r');
        end
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


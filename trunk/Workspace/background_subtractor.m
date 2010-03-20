function T = background_subtractor(T, frame)

% Do everything in grayscale.
frame_grey = double(rgb2gray(frame));

% Check to see if we're initialized
if ~isfield(T.segmenter, 'background');
  T.segmenter.background = frame_grey
end

% Pull local state out.
gamma  = T.segmenter.gamma;
tau    = T.segmenter.tau;
radius = T.segmenter.radius;

% Rolling average update.
T.segmenter.background = gamma * frame_grey + (1 - gamma) * ...
    T.segmenter.background;

% And threshold to get the foreground.
T.segmenter.segmented = abs(T.segmenter.background - frame_grey) > tau;
T.segmenter.segmented = imclose(T.segmenter.segmented, strel('disk', radius));

return
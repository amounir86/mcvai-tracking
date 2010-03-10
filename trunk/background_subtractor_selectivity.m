function T = background_subtractor_selectivity(T, frame)

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

T.segmenter.segmented = abs(T.segmenter.background - frame_grey) > tau;
T.segmenter.segmented = imclose(T.segmenter.segmented, strel('disk', radius));

% Rolling average update.
background = gamma * frame_grey + (1 - gamma) * ...
    T.segmenter.background;
background(find(T.segmenter.segmented == 1)) = T.segmenter.background(find(T.segmenter.segmented == 1));
T.segmenter.background = background;

sprintf('frame %d',T.frame_number)
return
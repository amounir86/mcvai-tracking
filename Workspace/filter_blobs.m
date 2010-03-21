function T = filter_blobs(T, frame)

if T.frame_number == 286
    x = 0;
end

% Make sure at lease one blob was recognized
if sum(sum(T.recognizer.blobs))
  % Extract the BoundingBox and Area of all blobs
  R = regionprops(T.recognizer.blobs, 'BoundingBox', 'Area');
  
  % And only keep the biggest one
  [I, IX] = max([R.Area]);
  for i = 1:length(R)
    T.representer.BoundingBox(i, :) = R(i).BoundingBox;
  end
else
  T.representer.BoundingBox = [];
end
return
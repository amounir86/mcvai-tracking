function T = filter_blobs(T, frame)

% Make sure at lease one blob was recognized
if sum(sum(T.recognizer.blobs))
  % Extract the BoundingBox and Area of all blobs
  R = regionprops(T.recognizer.blobs, 'BoundingBox', 'Area');
  
  % And only keep the biggest one
  [I, IX] = max([R.Area]);
  T.representer.BoundingBox = R(IX(size(IX,2))).BoundingBox;
end
return
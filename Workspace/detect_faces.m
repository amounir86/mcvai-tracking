function T = detect_faces(T, frame)
% This function is a detector for faces. It will only label blobs that are
% corresponding to a face. It labels as many faces as it finds in the
% image.

%% Label the blobs
T = find_blob(T, frame);

%% Make sure at lease one blob was recognized
if sum(sum(T.recognizer.blobs))
  
  oldBlobs = T.recognizer.blobs;
  newBlobs = zeros(size(oldBlobs));
  blobsLen = max(oldBlobs(:));

  %% Extract the BoundingBox of the blobs
  R = regionprops(T.recognizer.blobs, 'BoundingBox');

  % This index will keep the indexes of the faces being tracked
  fInd = 1;

  %% Iterate on the blobs and check if they contain faces
  for bIter = 1:length(R)
     
    if (T.frame_number >= 300)
       x = 7;
    end
    
    BB = ceil(R(bIter).BoundingBox);

    % Now get the part of this blob from the original image
    orgBlob = frame(BB(2):min(BB(2)+BB(4), size(frame, 1)), ...
                    BB(1):min(BB(1)+BB(3), size(frame, 2)), :);
                
    if (length(orgBlob(:)) < 200)
        continue;
    end
                
    % Change to gray scale to apply the face detector
    orgBlob = double(rgb2gray(orgBlob));


    %% Apply the face detector
    % Technique: Open CV Viola-Jones Face Detector
    % Code source: Matlab central.
    % URL: http://www.mathworks.com/matlabcentral/fileexchange/19912-open-
    %      cv-viola-jones-face-detection-in-matlab
    % Last Visited: 03/10/2010
    faces = FaceDetect('haarcascade_frontalface_alt2.xml',orgBlob);
    
    %% Check that we found any faces. If so, label it
    if (length(faces(:)) == 1) % We didn't find a face
        continue;
    end

    for fCount = 1:size(faces, 1)
      % A face was found
      % In any case we will only take 1 face from the blob
      % Add the label of the face to the final blobs result
      newBlobs(BB(2) + faces(fCount, 2):BB(2) + faces(fCount, 2) + ...
          faces(fCount, 4), BB(1) + faces(fCount, 1):BB(1) + ...
          faces(fCount, 1) + faces(fCount, 3)) = fInd;

      fInd = fInd + 1;
    end

  end
  
  % Assign the new blobs to the recognizer blobs
  T.recognizer.blobs = newBlobs;
end
return
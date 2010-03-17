function T = detect_recognize_faces(T, frame)
% This function is a detector for faces. It will only label blobs that are
% corresponding to a face. It labels as many faces as it finds in the
% image.

%% Label the blobs
T = find_blob(T, frame);

%% Reinitialize the state variables
T.detectorK = [];
T.detectorUK = [];

%% Make sure at lease one blob was recognized
if sum(sum(T.recognizer.blobs))
  
  oldBlobs = T.recognizer.blobs;
  newBlobs = zeros(size(oldBlobs));
  blobsLen = max(oldBlobs(:));

  %% Extract the BoundingBox of the blobs
  R = regionprops(T.recognizer.blobs, 'BoundingBox', 'Centroid');

  %% Iterate on the blobs and check if they contain faces
  for bIter = 1:length(R)
     
    if (T.frame_number >= 300)
       x = 7;
    end
    
    BB = round(R(bIter).BoundingBox);
    cen = R(bIter).Centroid;

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
        
        if(BB(3) + BB(4) > 50)
            detector.BoundingBox = BB;
            detector.Centroid = cen;
            detector.name = 'unknown';

            % Unknown detected information
            T.detectorUK = [T.detectorUK detector];
            
        end
        continue;
    end

    for fCount = 1:size(faces, 1)
      % A face was found
      % We have to check it's a recognizable face
      detFace = frame(BB(2) + faces(fCount, 2):BB(2) + faces(fCount, 2) + ...
          faces(fCount, 4), BB(1) + faces(fCount, 1):BB(1) + ...
          faces(fCount, 1) + faces(fCount, 3));
      
      % Resize the face and get the projected face.
      detFace = imresize(detFace, [25 25]);
      prjFace = double(detFace(:)') * T.eigenfaces;
      imClass = svmOAA(T.classifiers, prjFace);
      
      isTracked = 0;
      for tInd = 1:length(T.names)
          if (strcmp(imClass, T.names(tInd)))
              isTracked = 1;
              break;
          end
      end
      
      if isTracked == 0
          continue;
      end
      
      % Now as we recognize the face we should label it
      % We label it as the index of this face in the names array
      faceBB = [BB(1)+faces(fCount, 1) BB(2)+faces(fCount, 2) faces(fCount, 3) faces(fCount, 4)];
      faceCen = [faceBB(1)+faceBB(3)/2  faceBB(2)+faceBB(4)/2];
      detector.BoundingBox = faceBB;
      detector.Centroid = faceCen;
      detector.name = T.names(tInd);
      
      % Known detected information
      T.detectorK = [T.detectorK detector];

%       newBlobs(BB(2) + faces(fCount, 2):BB(2) + faces(fCount, 2) + ...
%           faces(fCount, 4), BB(1) + faces(fCount, 1):BB(1) + ...
%           faces(fCount, 1) + faces(fCount, 3)) = tInd;

    end

  end
  
  % Assign the new blobs to the recognizer blobs
  T.recognizer.blobs = newBlobs;
end
return
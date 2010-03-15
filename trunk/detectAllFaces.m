function [ output_args ] = detectAllFaces( fname )
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

vr = videoReader(fname);

ind = 0

while next(vr)
    
    orgFrame = getframe(vr);
    frame = double(rgb2gray(orgFrame));
    faces = FaceDetect('haarcascade_frontalface_alt2.xml',frame);
    %% Check that we found any faces. If so, label it
    if (length(faces(:)) == 1) % We didn't find a face
        continue;
    end

    for fCount = 1:size(faces, 1)
      % A face was found
      % In any case we will only take 1 face from the blob
      % Add the label of the face to the final blobs result
      theFace = orgFrame(faces(fCount, 2):faces(fCount, 2) + faces(fCount, 4), ...
          faces(fCount, 1):faces(fCount, 1) + faces(fCount, 3));
      
      imshow(theFace);
      name = input('Name? ', 's');
      if (strcmp(name, ''))
          name = 'garbage';
      end
      
      s = sprintf('Faces/%d%s.BMP',ind, name);

      ind = ind + 1
      imwrite(theFace, s, 'BMP');
    end
end

close(vr);
end


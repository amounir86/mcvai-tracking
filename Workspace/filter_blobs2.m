function T = filter_blobs2(T, frame)

% This function takes the bigest blob obtained from the detection and it
% gets its boundingbox and the new representation of the object [x y xv yv]
% It also computes the local histogram for this blob.

% If we detect something from the detection we can go inside
if sum(sum(T.recognizer.blobs))             
   
    % If it is not the first time we represent a blob we're able to
    % calculate its velocity
    if isfield(T.representer,'previous')
                
        R = regionprops(T.recognizer.blobs, 'BoundingBox', 'Area','Centroid');
        [I, IX] = max([R.Area]);
        T.representer.BoundingBox = R(IX(size(IX,2))).BoundingBox;
        T.representer.Centroid = R(IX(size(IX,2))).Centroid;
        
        % The velocity is taken by the difference with the previous frame
        % in terms of xv yv
        velocity = [T.representer.Centroid(1)-T.representer.previous(1) T.representer.Centroid(2)-T.representer.previous(2)];
        
        % The new representation to kalman is [x y xv yv] where x y is the
        % centroid position and xv yv is the velocity in each coordinates
        T.representer.Velocity = [T.representer.Centroid velocity];
        
        % The actual representation is stored for being able to get the
        % velocity in the next frame
        T.representer.previous = T.representer.Velocity;
        
        % Once we have the representation, we calculate the colour
        % histogram for the blob. We take the BoundingBox and calculate the
        % histogram for each RGB channel. After that, we concatenate all the histograms 
        figure(2),
%         imshow(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),:));
        [count1, x1] = imhist(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),1));
        [count2, x2] = imhist(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),2));
        [count3, x3] = imhist(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),3));
        count_total = [count1 count2 count3];
        stem(count_total);
        
    else
        
        % If it is the first time that the detector was able to detect a
        % tracking blob we're not able to know the velocity of the object
        
        R = regionprops(T.recognizer.blobs, 'BoundingBox', 'Area','Centroid');
        [I, IX] = max([R.Area]);
        T.representer.BoundingBox = R(IX(size(IX,2))).BoundingBox;
        T.representer.Centroid = R(IX(size(IX,2))).Centroid;
        
        % The representation for kalman is [x y 0 0] where x y are the
        % centroid of the object and the velocity is 0
        T.representer.Velocity = [T.representer.Centroid 0 0];
        T.representer.previous = T.representer.Velocity;
        
        % Once we have the representation, we calculate the colour
        % histogram for the blob. We take the BoundingBox and calculate the
        % histogram for each RGB channel. After that, we concatenate all
        % the histograms 
        figure(2),
%         imshow(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),:));
        [count1, x1] = imhist(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),1));
        [count2, x2] = imhist(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),2));
        [count3, x3] = imhist(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),3));
        count_total = [count1 count2 count3];
        stem(count_total);
  
    end
end

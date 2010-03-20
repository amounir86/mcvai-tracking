function T = filter_blobs2(T, frame)

% This function takes the bigest blob obtained from the detection and it
% gets its boundingbox and the new representation of the object [x y xv yv]
% It also computes the normalized local histogram for this blob but this time, deleting 
% the part of the backgroun included in the BoundingBox.

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
        
        % Take from the segmented image the region of interest
        bound_segmented = T.segmenter.segmented(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)));
        
        % From the region of interest thos pixels that belong to the
        % background
        index = find(bound_segmented == 0);
        
        % Take from the real frame the region of interest
        real_frame_bounding = frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),:);
        
        % Get the three channels separately
        chanel1 = real_frame_bounding(:,:,1);
        chanel2 = real_frame_bounding(:,:,2);
        chanel3 = real_frame_bounding(:,:,3);
        
        % Those pixels that belong to the background in the real region of
        % interest are 0
        chanel1(index) = 0;
        chanel2(index) = 0;
        chanel3(index) = 0;
        
        % Get the three histograms, 1 for channel
        [count1,x] = imhist(chanel1);
        [count2,x] = imhist(chanel2);
        [count3,x] = imhist(chanel3);
        
        % All the pixels in the first position count 0
        count1(1) = 0;
        count2(1) = 0;
        count3(1) = 0;
        
        % Join the three histograms in one
        T.representer.histogram = [count1; count2; count3];
        
        % Normalization of the histogram
        T.representer.histogram = T.representer.histogram/max(T.representer.histogram);
        
        % get the new real region of interest without those pixels that belong
        % to the background
        real_frame_segmented(:,:,1) = chanel1;
        real_frame_segmented(:,:,2) = chanel2;
        real_frame_segmented(:,:,3) = chanel3;
        
        T.representer.real_frame_segmented = real_frame_segmented;
            
        
        
        
%         figure(2),
%         imshow(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),:));
%         [count1, x1] = imhist(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),1));
%         [count2, x2] = imhist(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),2));
%         [count3, x3] = imhist(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),3));
%         count_total = [count1 count2 count3];
%         stem(count_total);
        
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

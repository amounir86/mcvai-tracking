function T = filter_blobs2(T, frame)

% This function takes the closest blob obtained from the detection to the previous
% representation and it gets its boundingbox and the new representation of
% the object [x y xv yv]. It also computes the normalized local histogram for
% this blob but this time, deleting the part of the backgroun included in 
% the BoundingBox.

% If we have already detected a blob in the previous frame
if (T.representer.found_blobs ~= 0)
    
    if sum(sum(T.recognizer.blobs))             

        % If it is not the first time we represent a blob we're able to
        % calculate its velocity
      
        R = regionprops(T.recognizer.blobs, 'BoundingBox','Centroid');

        % If we have detected more than one blob we should track the
        % closest to the tracked in the previous frame
        if (size(R,1)>1)
            
            % nearest_blobs returns the index of the closest blob to the
            % previous tracked
            nearest_blob = find_nearest_blob(R,T.representer.Centroid);
            T.representer.BoundingBox = R(nearest_blob).BoundingBox;
            T.representer.Centroid = R(nearest_blob).Centroid;
        else
            
            T.representer.BoundingBox = R.BoundingBox;
            T.representer.Centroid = R.Centroid;
        end

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

      end

%         figure(2),
%         imshow(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),:));
%         [count1, x1] = imhist(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),1));
%         [count2, x2] = imhist(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),2));
%         [count3, x3] = imhist(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),3));
%         count_total = [count1 count2 count3];
%         stem(count_total);

        
%     else
%         % What happens if we didn't detect a blob that we detected before
%         
%         % Two main reasons: The blob pass away from the frame, or the blob
%         % is ocluded by some object
%         
% 
%         x = T.representer.Velocity(1);
%         y = T.representer.Velocity(2);
%         xv = T.representer.Velocity(3);
%         yv = T.representer.Velocity(4);
% 
%         xnew = x + xv;
%         ynew = y + yv;
%         
%         if (blob_in_frame(xnew, ynew, frame))
% 
%             T.representer.Velocity = [xnew ynew xv yv];
%             T.representer.BoundingBox = [T.representer.BoundingBox(1)+xv...
%                 T.representer.BoundingBox(2)+yv T.representer.BoundingBox(3)...
%                 T.representer.BoundingBox(4)]
%         
%         else
%             
%             T.representer.previous = [];
%             T.representer.found_blobs = T.representer.found_blobs - 1; 
%         end
     
else

    if sum(sum(T.recognizer.blobs))
        % If it is the first time that the detector was able to detect a
        % tracking blob we're not able to know the velocity of the object

        R = regionprops(T.recognizer.blobs, 'BoundingBox','Area','Centroid');
        [I, IX] = max([R.Area]);
        T.representer.BoundingBox = R(IX(size(IX,2))).BoundingBox;
        T.representer.Centroid = R(IX(size(IX,2))).Centroid;

        % The representation for kalman is [x y 0 0] where x y are the
        % centroid of the object and the velocity is 0
        T.representer.Velocity = [T.representer.Centroid 0 0];
        T.representer.previous = T.representer.Velocity;
        T.representer.found_blobs = T.representer.found_blobs + 1;

        % Once we have the representation, we calculate the colour
        % histogram for the blob. We take the BoundingBox and calculate the
        % histogram for each RGB channel. After that, we concatenate all
        % the histograms 
       
        [count1, x1] = imhist(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),1));
        [count2, x2] = imhist(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),2));
        [count3, x3] = imhist(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),3));
        count_total = [count1 count2 count3];
        stem(count_total);
        
    end

end

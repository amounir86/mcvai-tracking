function T = filter_blobs2(T, frame)

if sum(sum(T.recognizer.blobs))
   
    if isfield(T.representer,'previous')
                
        R = regionprops(T.recognizer.blobs, 'BoundingBox', 'Area','Centroid');
        [I, IX] = max([R.Area]);
        T.representer.BoundingBox = R(IX(size(IX,2))).BoundingBox;
        T.representer.Centroid = R(IX(size(IX,2))).Centroid;
        velocity = [T.representer.Centroid(1)-T.representer.previous(1) T.representer.Centroid(2)-T.representer.previous(2)];
        T.representer.Velocity = [T.representer.Centroid velocity];
        T.representer.previous = T.representer.Velocity;
        figure(3),
        subplot(2,2,1),subimage(T.segmenter.segmented);
        subplot(2,2,3),subimage(T.segmenter.background);
        
%         imshow(double(rgb2gray(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),:))))
%         imhist(rgb2gray(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),:)));        
%         T.representer.hist = imhist(rgb2gray(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),:)));
        
    else
        
        R = regionprops(T.recognizer.blobs, 'BoundingBox', 'Area','Centroid');
        [I, IX] = max([R.Area]);
        T.representer.BoundingBox = R(IX(size(IX,2))).BoundingBox;
        T.representer.Centroid = R(IX(size(IX,2))).Centroid;
        T.representer.Velocity = [T.representer.Centroid 0 0];
        T.representer.previous = T.representer.Velocity;
        figure(3),
        subplot(2,2,1),subimage(T.segmenter.segmented);   
        subplot(2,2,3),subimage(T.segmenter.background);
             

%         imshow(double(rgb2gray(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),:))))
%         imhist(rgb2gray(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),:)));        
%         T.representer.hist = imhist(rgb2gray(frame(T.representer.BoundingBox(2):floor(T.representer.BoundingBox(2)+T.representer.BoundingBox(4)),T.representer.BoundingBox(1):floor(T.representer.BoundingBox(1)+T.representer.BoundingBox(3)),:)));        

    end
end

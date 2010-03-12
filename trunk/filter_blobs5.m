function T = filter_blobs2(T, frame)

% This function takes all the blobs detected from the detection step for
% tracking.

if sum(sum(T.recognizer.blobs))
    
    if isfield(T.representer,'all')
        
        R = regionprops(T.recognizer.blobs, 'BoundingBox','Centroid');
        
        %% We have the same number of blobs
        if ( size(T.representer.all,1) == size(R,1) )
            
            all = T.representer.all;
            r = R;
            
            allcen = [all(:).Centroids];
            rcen = [R(:).Centroids];
            
            all_correlated = find_corelation(allcen,
            
            
        
    else
        
        R = regionprops(T.recognizer.blobs, 'BoundingBox','Centroid');
        T.representers.all = R;
        
        for i = 1 : size(T.representes.all,1)
        
            T.representers.all(i).Velocity = [T.representers.all(i).Centtroid 0 0];
        
        end
        
        end
    end
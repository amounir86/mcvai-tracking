function T = filter_blobs2(T, frame)

% This function takes all the blobs detected from the detection step for
% tracking.

if sum(sum(T.recognizer.blobs))
    
    if isfield(T.representer,'all')
        
        new_centroids = [];
        pre_centroids = [];
        pre_velocities = [];
        est_centroids = [];
        
        R = regionprops(T.recognizer.blobs, 'BoundingBox','Centroid');
                
        for i = 1 : size(R,1)
           new_centroids = [new_centroids; R(i).Centroid];
        end
        pre_blobs = T.representer.all;
        for i = 1 : size(T.representer.all,1)
            pre_centroids = [pre_centroids; pre_blobs(i).Centroid];
            pre_velocities = [pre_velocities; pre_blobs(i).Velocity(3) pre_blobs(i).Velocity(4)];
            est_centroids = [est_centroids; [pre_centroids(i,1) + pre_velocities(i,1) pre_centroids(i,2) + pre_velocities(i,2)]];
        end
            
        distances = calc_distances(est_centroids,new_centroids);
        
        belong = calc_belongs(distances);
        
        for i = 1 : size(belongs,1)
            
            if(belongs(i) == 0)
                                
                handle_struct = struct('isEmpty', 1,'BoundingBox',[],'Centroid',[],'Velocity',[]);
            else
                velocity = [pre_centroids(i,1) - new_centroids(belongs(i),1) pre_centroids(i,2) - new_centroids(belongs(i),2)];
                handle_struct = struct('isEmpty', 0,'BoundingBox', R(belongs(i)).BoundingBox,...
                 'Velocity', [R(belongs(i)).Centroid velocity]);
            end
            
            all_representer = [all_representer; handle_struct];
            
        end
        
        T.representer.all = all_representer;
            
    else
    %% If there is not blob previous    
        
        R = regionprops(T.recognizer.blobs, 'BoundingBox','Centroid');
        T.represente.all = struct(R.BoundingBox);
        for i = 1 : size(T.representer.all,1)

            T.representer.all(i).isEmpty = 0;
            T.representer.all(i).Velocity = [T.representer.all(i).Centroid 0 0];

        end


    end
end
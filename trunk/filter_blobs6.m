function T = filter_blobs6(T, frame)
%% This function takes all the blobs detected from the detection step for
% tracking.

if ~isfield(T.representer,'all')
    T.representer.all = [];
end

%% 
for repInd = 1:length(T.representer.all)
    found = 0;
    
    %% Try to find a detected match
    for kDet = 1:length(T.detectorK)
        if (strcmp(T.detectorK.name, T.representer.all.name))
            found = 1;
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%
            %%   UPDATE THE REPRESENTER INFORMATION
            %%
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % Remove the entry from the detected blobs
            T.detectorK = [T.detectorK(1:kDet - 1) T.detectorK(kDet + 1:end)];
            break;
        end
    end
    
    if ~found
        %% Try to find an undetected match
        for ukDet = 1:length(T.detectorUK)
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%
            %% JUST TRY TO LOOK FOR A MATCH
            %%
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
        end
    end
end

%% Add the remaining not-added detected blobs
for kDet = 1:length(T.detectorK)
    representer.BoundingBox = T.detector.BoundingBox;
    representer.Centroid = T.detector.Centroid;
    representer.name = T.detector.name;
    representer.Velocity = [representer.Centroid 0 0];
    T.representer.all = [T.representer.all representer];
end

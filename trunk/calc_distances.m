function distances = calc_distances(esp,new)

% This function calculates the distance between each especulative centroid
% ESP and the centroids that we obtain from the detection NEW. DISTANCES is
% a matrix where each file is a especulation centroid and the colums are
% the distances to the new centroids

distances = [];
local_dist = [];

for j = 1 : size(esp,1)
    for i = 1 : size(new,1)
    
    local_dist = [local_dist, abs(norm(esp(j)-new(i)))];
    
    end
    distances = [distances; local_dist];
    local_dist = [];
end

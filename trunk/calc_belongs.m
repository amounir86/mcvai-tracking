function [z,h] = calc_belongs(distances)

% This functions takes the distances from each especulative centroid to reals centroids and
% returns a vector with the index that each blob belongs to

z = zeros(1,size(distances,1));
h = ones(1,size(distances,2));
for i = 1 : size(distances,2)
    
    [row,col] = find(distances == min(min(distances)));
    distances(row,:) = NaN;
    h(col) = 0;
    z(1,row) = col;
    
end
    
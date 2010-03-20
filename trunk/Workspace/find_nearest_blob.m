function nearest = find_nearest_blob(R,previous)

distance = [];

for i = 1 : size(R,1)
    
    distance = [distance abs(norm((R(i).Centroid - previous)))]
end

nearest = find(distance==min(distance));

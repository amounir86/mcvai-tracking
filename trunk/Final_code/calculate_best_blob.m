function index_best_blob = calculate_best_blob(representer, unk)

% Calculate the distance between the representer and all the unknow
% recognizers

index_best_blob = -1;
ThrH = 75;
total_normal = [];

for i = 1 : length(unk)
    
    distance = representer - unk(i).Centroid;
    normal = norm(distance);
    
    total_normal = [total_normal normal];
    
end

minim = find(total_normal == min(total_normal));

if (total_normal(minim) < ThrH)
    
    index_best_blob = minim

end
    
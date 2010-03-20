function [class] = svmOAA(SVMs, newData)
%SVMOAA Multiclass One-against-all SVM classifier
%   - SVMs: vector with all classifiers
%   - labels: vector of the same size as SMVs, indicating the label of the
%   class which each classifier is specialized
%   - newData: data point to be classified

fVals = zeros(size(SVMs));
class = cell(size(SVMs));

% Compute the distance from the new data point to the boundary of each
% classifier
for i=1:length(SVMs)
    class(i) = svmclassify(SVMs(i),newData);      
end

% Discard the classifiers with negative results
candidates = setdiff(1:length(SVMs), strmatch('NONE',class));

for i=1:length(candidates)
[out, fVals(candidates(i))] = svmdecision((newData + SVMs(candidates(i)).ScaleData.shift).*SVMs(candidates(i)).ScaleData.scaleFactor,SVMs(candidates(i)));
fVals(candidates(i)) = abs(fVals(candidates(i)));
end
% Find the classifier which gives the highest output
[maxVal, indMax] = max(fVals);

if (isempty(candidates))
    class = 'unknown';
else
% Classify the data with found classifier (winner-takes-all)
class = class{indMax};
end

end
function [classifiers] = trainClassifiers(trainingImages, imageLabels)
% trainClassifiers, This function trains the SVM classifiers using the one
% against all strategy and returns the result as a vector of trained
% classifiers.
%
% INPUT: originalImages, the images that we should train the system with.
%        imageLabels, the label of each image so that we can enforce the
%                     one against all classifier training.
%
% OUTPUT: classifiers, a vector of trained classifiers.

    % Choose the distinct labels.
    distinctLabels = setdiff(unique(imageLabels),{'unknown'});

    % Iterate on every distinct labels
    for i = 1:size(distinctLabels)

        % Initialize the classifier labels
        clLabels = imageLabels;

        % Choose the images that don't have this label
               
        index = strmatch(distinctLabels{i}, clLabels);
        diferences = setdiff(1:length(imageLabels),index);
        
        for j=1:length(diferences)
            clLabels{diferences(j)} = 'NONE';
        end

        % Build the One-Against-All classifier
        classifiers(i) = svmtrain(trainingImages, clLabels, 'METHOD', 'LS');

    end

end


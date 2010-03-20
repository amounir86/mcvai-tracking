function [ eigenfaces, classifiers ] = getClassifiers()
%% This function trains classifiers for the face recognition
%   It returns a set of trained classifiers where we apply the One Against
%   All strategy to get the class the training data belongs to

% Load images (each row is an image) DONE BY LLUIS AND EKAIN
[faces, faceLabels] = imageOnMatrix();

faces=double(faces);
%   Eigenfaces decomposition (eigenvectors num choice)
eigenfaces = getEigenFaces(double(faces(:,:)'), size(faces, 1));

%  Training Data projection
projectedTrainingFaces = faces(:,:) * eigenfaces;

%   In the case of SVM, train the classifier
classifiers = trainClassifiers(projectedTrainingFaces, faceLabels(:));
    
% %   Classification
% im = imresize(im, [25 25]);
% prjIm = double(im(:)') * eigenfaces;
% imClass = svmOAA(classifiers, prjIm);

end


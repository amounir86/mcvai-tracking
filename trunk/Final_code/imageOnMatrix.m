function [imgMatrix, labeledArray] = imageOnMatrix()
%IMAGEONMATRIX Summary of this function goes here
%   Detailed explanation goes here
imgnames = file_list('../Faces','bmp');
imgvector = [];
labeledArray = cell(length(imgnames),1);
w = 25;
h = 25;
for i = 1 : length(imgnames) 

    name = imgnames{i};
    if(strfind(name,'ahmed'))
        labeledArray{i} = 'ahmed';
    elseif (strfind(name,'toni'))
        labeledArray{i} = 'toni';
    elseif (strfind(name, 'monica'))
        labeledArray{i} = 'monica';
    elseif (strfind(name, 'lluis'))
        labeledArray{i} = 'lluis';
    elseif (strfind(name, 'ekain'))
        labeledArray{i} = 'ekain';
    else
        labeledArray{i} = 'unknown';
    end
    image = imread(name);
    image = imresize(image, [w h]);
    imgvector = reshape(image,1,prod(size(image)));
    imgMatrix(i,:) = imgvector;

end

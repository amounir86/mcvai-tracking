function y=greyWorld(Image)

% Perform grayworld assumtion color balancing.

r=Image(:,:,1);
g=Image(:,:,2);
b=Image(:,:,3);

avgR = mean(mean(r));
avgG = mean(mean(g));
avgB = mean(mean(b));

avgRGB = [avgR avgG avgB];
grayValue = (avgR + avgG + avgB)/3;

scaleValue = grayValue./avgRGB;

y(:,:,1) = scaleValue(1) * r;
y(:,:,2) = scaleValue(2) * g;
y(:,:,3) = scaleValue(3) * b;

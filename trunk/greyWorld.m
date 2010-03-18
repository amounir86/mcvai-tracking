function newImage=greyWorld(frame)
R=frame(:,:,1); %extract RGB the frame
G=frame(:,:,2);
B=frame(:,:,3);

meanR = mean(mean(R)); %mean of R
meanG = mean(mean(G));
meanB = mean(mean(B));

meanRGB = [meanR meanG meanB];
grayValue = (meanR + meanG + meanB)/3; %mean of grey

rgbPrima = grayValue./meanRGB; %ex: Rgrey/Rmean 

newImage(:,:,1) = rgbPrima(1) * R;
newImage(:,:,2) = rgbPrima(2) * G;
newImage(:,:,3) = rgbPrima(3) * B;

function T = background_subtractor_eigenbackground(T, frame)

T.segmenter.color = greyWorld(frame);
N = (T.num_frames * 10)/100;
N = floor(N);

frame_grey = double(rgb2gray(T.segmenter.color));

if (T.segmenter.backgroundBool == 1) %N first image are the set of trainning
    if (T.frame_number<N) 
        T.segmenter.A(:,T.frame_number) = reshape(frame_grey,[],1);
        T.segmenter.background = reshape(frame_grey,[],1);
    else %PCA
        T.segmenter.psi = mean(T.segmenter.A')'; %extract the mean in A
        for i=1:size(T.segmenter.A,2)
            T.segmenter.A(:,i) = T.segmenter.A(:,i) - T.segmenter.psi;
        end
        L = T.segmenter.A'*T.segmenter.A; 
        [eigenvectors, eigenvalues] = eig(L);%eigenvalues & eigenvectors
        eigenvectors = T.segmenter.A * eigenvectors; %projection
        eigenvectors = eigenvectors/norm(eigenvectors);
        v = max(eigenvalues); %sort the eigenvectors
        [svals inds] = sort(v,'descend');
        eigenvectors = eigenvectors(:,inds);
        T.segmenter.background = eigenvectors(:,1:15); %give only the first 15 eigenvectors
        T.segmenter.backgroundBool = 0; %0 is true
    end
end

T.segmenter.segmented = zeros(size(frame_grey));

if (T.segmenter.backgroundBool == 0) %if exist the eigenbackground
   [w,h] = size(frame_grey);
   tau = T.segmenter.tau;
   frame_grey = reshape(frame_grey,[],1); %reshape the frame
   Ipro = T.segmenter.background' * (frame_grey-T.segmenter.psi); %project
   T.segmenter.reconstruct = T.segmenter.background*Ipro+T.segmenter.psi; %reconstruct and the 
   %result image is the "background"
   T.segmenter.segmented = reshape((abs(frame_grey - T.segmenter.reconstruct)>tau),w,h);
   %segmented save the foreground in the frame
   T.segmenter.segmented = imclose(T.segmenter.segmented, strel('disk', 3));
   %delete the little blobs
end
return
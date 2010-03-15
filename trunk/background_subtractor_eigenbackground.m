function T = background_subtractor_eigenbackground(T, frame)

T.segmenter.color = greyWorld(frame);
N = (T.num_frames * 20)/100;
N = floor(N);

frame_grey = double(rgb2gray(T.segmenter.color));

if (T.segmenter.backgroundBool == 1)
    if (T.frame_number<N) 
        T.segmenter.A(:,T.frame_number) = reshape(frame_grey,[],1);
        T.segmenter.background = reshape(frame_grey,[],1);
    else
        T.segmenter.psi = mean(T.segmenter.A')';
        for i=1:size(T.segmenter.A,2)
            T.segmenter.A(:,i) = T.segmenter.A(:,i) - T.segmenter.psi;
        end
        L = T.segmenter.A'*T.segmenter.A;
        [eigenvectors, eigenvalues] = eig(L);
        eigenvectors = T.segmenter.A * eigenvectors;
        eigenvectors = eigenvectors/norm(eigenvectors);
        v = max(eigenvalues);
        [svals inds] = sort(v,'descend');
        eigenvectors = eigenvectors(:,inds);
        T.segmenter.background = eigenvectors(:,1:15);
        T.segmenter.backgroundBool = 0; %0 is true
    end
end

T.segmenter.segmented = zeros(size(frame_grey));

if (T.segmenter.backgroundBool == 0)
   [w,h] = size(frame_grey);
   frame_grey = reshape(frame_grey,[],1);
   Ipro = T.segmenter.background' * (frame_grey-T.segmenter.psi); 
   T.segmenter.reconstruct = T.segmenter.background*Ipro+T.segmenter.psi;
   T.segmenter.segmented = reshape((abs(frame_grey - T.segmenter.reconstruct)>20),w,h);
end
return
function T = find_blob(T, frame)
T.recognizer.blobs = bwlabel(T.segmenter.segmented);
return
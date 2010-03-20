function is_in_frame = blob_in_frame(x, y, frame)

if(x<0 || y<0)
    
    is_in_frame = false;
    
elseif (x > size(frame,1) || y >size(frame,2))
    
    is_in_frame = false;
    
else
    
    is_in_frame = true;
    
end
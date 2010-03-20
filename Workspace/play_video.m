function play_video(fname);
vr = videoReader(fname);  
while (next(vr))  
  img = getframe(vr);  
  imshow(img);  
  pause(0.01);  
end  
vr = close(vr);
return
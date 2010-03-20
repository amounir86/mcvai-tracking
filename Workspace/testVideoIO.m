vr = videoReader('videoIO-windows/tests/intersection300.25fps.xvid.avi');
vw = videoWriter('foo.avi');
while (next(vr))
  img = getframe(vr);
  addframe(vw, img);
  imshow(img);
  pause(0.01);
end
vw = close(vw);
vr = close(vr);

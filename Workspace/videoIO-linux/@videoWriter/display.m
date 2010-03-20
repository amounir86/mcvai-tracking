function display(vr)
%DISPLAY(VR) display for a videoReader object

if isequal(get(0,'FormatSpacing'),'compact')
   disp([inputname(1) ' =']);
   disp(vr)
else
   disp(' ')
   disp([inputname(1) ' =']);
   disp(' ');
   disp(vr)
end
function disp(vw)
%DISP(vw) displays a videoWriter object without printing its name.

ctor = class(vw);
info = get(vw);

% actual display
disp(['  ' ctor ' object']);
if ~isequal(get(0,'FormatSpacing'),'compact')
  disp(' ');
end
disp(info);

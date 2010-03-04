function disp(vr)
%DISP(vr) displays a videoReader object without printing its name.

ctor = class(vr);
info = get(vr);

% actual display
disp(['  ' ctor ' object']);
if ~isequal(get(0,'FormatSpacing'),'compact')
  disp(' ');
end
disp(info);

function testGet(plugin)
%testGet
%  Script that does some minimal testing of the get functions.  Windows
%  only.
%
%Example:
%  testGet
%
%Copyright (c) 2006 Gerald Dalley
%See "MIT.txt" in the installation directory for licensing details (especially
%when using this library on GNU/Linux).

ienter

if nargin < 1, plugin = defaultVideoIOPlugin; end

if ispc
  frames = rand(100,100, 10);

  try
    tmpDir = tempname; mkdir(tmpDir);

    codecs = videoWriter([], 'codecs', 'plugin',plugin);
    
    codecA = listdlg('PromptString', {'Choose a VfW or ', 'DirectShow codec:'}, ...
      'ListString', codecs, 'SelectionMode', 'single');
    codecA = codecs{codecA};
    
    fname = fullfile(tmpDir, 'testGetA.avi');
    vw = videoWriter(fname, 'plugin',plugin, 'showCompressionDialog',1, 'codec',codecA);
    infoA = get(vw);
    for i=1:size(frames,3), addframe(vw, frames(:,:,i)); end
    close(vw);
    dirA = dir(fname);
    a = fopen(fname);  dataA = fread(a, 'uint8');  fclose(a); %#ok<NASGU>

    codecB = listdlg('PromptString', {'Choose a different codec','(or configure it differently):'}, ...
      'ListString', codecs, 'SelectionMode', 'single');
    codecB = codecs{codecB};
    fname = fullfile(tmpDir, 'testGetB.avi');
    vw = videoWriter(fname, 'plugin',plugin, 'showCompressionDialog',1, 'codec',codecB);
    infoB = get(vw);
    if strcmp(infoA.codecParams, infoB.codecParams) && strcmp(infoA.codec, infoB.codec)
      error('You were supposed to change either the codec and/or at least one compression parameter.');
    end
    for i=1:size(frames,3), addframe(vw, frames(:,:,i)); end
    close(vw);
    dirB = dir(fname);
    b = fopen(fname);  dataB = fread(b, 'uint8');  fclose(b); %#ok<NASGU>

    if dirA.bytes == dirB.bytes
      if all(a == b)
        error('The two files are identical.  Try adjusting the compression parameters more.');
      end
    end

    fname = fullfile(tmpDir, 'testGetC.avi');
    vw = videoWriter(fname, 'plugin',plugin, ...
      'codec',infoA.codec, 'codecParams',infoA.codecParams, ...
      'width',infoA.width, 'height',infoA.height);
    infoC = get(vw); %#ok<NASGU>
    for i=1:size(frames,3), addframe(vw, frames(:,:,i)); end
    close(vw);
    dirC = dir(fname); %#ok<NASGU>
    c = fopen(fname);  dataC = fread(c, 'uint8');  fclose(c); %#ok<NASGU>

    vrassert strcmp(infoA.codecParams, infoC.codecParams);
    vrassert dirA.bytes == dirC.bytes;
    vrassert all(dataA == dataC);

    rmdir(tmpDir, 's');
  catch %#ok<CTCH>: backward compatibility
    e = lasterror; %#ok<LERR>: backward compatibility
    try close(vw); catch end %#ok<CTCH>: backward compatibility
    rmdir(tmpDir, 's');
    rethrow(e);
  end
else
  iprintf('skipping testGet on non-Windows boxes');
end

iexit

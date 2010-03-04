function [val,args] = argExtract(args, key, defaultVal)
%[val,args] = argExtract(args, key, defaultVal)
%  Looks through a name-value ARGS list for a KEY.  If found, VAL is the
%  key's value.  If KEY is not found in the names, DEFAULTVAL is
%  returned.  If the KEY occurs multiple times, only the last instance is
%  extracted. All matched name-value pairs are removed from the ARGS list.

if (mod(length(args),2) ~= 0)
  error('arguments must come in name-value pairs');
end

val     = defaultVal;
outargs = {};
for j=1:2:length(args)
  if (strcmpi(args{j}, key))
    val = args{j+1};
  else
    outargs = { outargs{:} args{j+[0 1]} };
  end
end
args = outargs;
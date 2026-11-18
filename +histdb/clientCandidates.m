function c = clientCandidates()
%HISTDB.CLIENTCANDIDATES The folders a CarasLabDB checkout (with +labclient) is looked for in, in order.
%   The folder CARASLABDB_DIR names (the variable ephys_analysis uses too),
%   then a CarasLabDB folder beside this checkout.
%
% See also HISTDB.AVAILABLE.

repo = string(fileparts(fileparts(mfilename("fullpath"))));
c = [string(getenv("CARASLABDB_DIR")), string(fullfile(fileparts(repo), "CarasLabDB"))];
c = c(strlength(c) > 0);
end

function v = safeCol(T, name, defaultVal)
%SAFECOL Return table column T.(name) if it exists; otherwise default.
% - defaultVal defaults to 1s (column vector) sized to height(T).
% - Always returns a numeric column, NaNs filled with 1.
    if nargin < 3 || isempty(defaultVal)
        defaultVal = 1;
    end
    if ismember(name, T.Properties.VariableNames)
        v = T.(name);
        if ~isnumeric(v)
            v = str2double(string(v));
        end
    else
        v = repmat(defaultVal, height(T), 1);
    end
    v = double(v);
    v(~isfinite(v)) = 1;
end
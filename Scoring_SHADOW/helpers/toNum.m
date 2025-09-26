function v = toNum(x)
    % Coerce any input into a single numeric column (double).
    if isnumeric(x) || islogical(x)
        v = double(x(:));
    else
        v = str2double(string(x(:)));
    end
end
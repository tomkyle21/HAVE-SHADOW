
function T = local_norm_keys(T, keys3)
    for k = 1:numel(keys3)
        v = keys3{k};
        if ~ismember(v, T.Properties.VariableNames)
            T.(v) = strings(height(T),1);
        end
        % cast to string and trim
        if ~isstring(T.(v))
            T.(v) = string(T.(v));
        end
        T.(v) = strtrim(T.(v));
    end
    % dedupe by keys
    [~, ia] = unique(T(:, keys3), 'rows', 'stable');
    T = T(ia, :);
end


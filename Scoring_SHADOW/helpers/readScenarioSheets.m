function S = readScenarioSheets(filename)
    % Returns a struct with one table per sheet, after cleaning.
    [~, sheetNames] = xlsfinfo(filename);
    S = struct();
    for i = 1:numel(sheetNames)
        sh = sheetNames{i};

        % Build import options
        opts = detectImportOptions(filename, 'Sheet', sh, ...
                                   'VariableNamingRule','preserve', ...
                                   'ReadVariableNames', true);

        % Treat blank-like entries as missing
        opts = setvaropts(opts, opts.VariableNames, 'TreatAsMissing', {'', 'NA', 'N/A', 'NaN', ' '});

        % Read table
        T = readtable(filename, opts);

        % Canonicalize names (Lead Pilot -> Lead_Pilot, etc.)
        [T, nameMap] = canonicalizeVarNames(T);

        % Clean rows
        T = cleanTable(T, nameMap);

        % Store
        validFieldName = matlab.lang.makeValidName(sh);
        S.(validFieldName) = T;

        fprintf('Loaded & cleaned sheet: %s (%d rows, %d vars)\n', sh, height(T), width(T));
    end
end

function [T, nameMap] = canonicalizeVarNames(T)
    vnames   = T.Properties.VariableNames;
    newNames = matlab.lang.makeValidName(regexprep(vnames,'\W','_'));
    nameMap  = containers.Map(vnames, newNames);
    T.Properties.VariableDescriptions = vnames;
    T.Properties.VariableNames = newNames;
end

function T = cleanTable(T, nameMap)
    % Remove rows that are fully empty
    allMissing = all(ismissing(T),2);
    T(allMissing,:) = [];

    % Drop duplicate header rows (row where entries == column names)
    vnames = T.Properties.VariableNames;
    headerLike = false(height(T),1);
    for r = 1:height(T)
        matchCount = 0;
        for c = 1:width(T)
            val = string(T{r,c});
            if strlength(val)>0 && strcmpi(val, vnames{c})
                matchCount = matchCount + 1;
            end
        end
        if matchCount >= max(2, ceil(width(T)/2))
            headerLike(r) = true;
        end
    end
    T(headerLike,:) = [];
end
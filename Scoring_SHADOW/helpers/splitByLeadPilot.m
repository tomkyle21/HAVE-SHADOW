%% ==== Helper: split rows by Lead_Pilot with robust type unification ====
function [outStruct, pilotNames] = splitByLeadPilot(prefix, allDataStruct, createVars)
    % Gather tables from the struct (each sheet already read as a table)
    allTables = struct2cell(allDataStruct);
    if isempty(allTables)
        warning('No tables found for scenario %s.', prefix);
        outStruct = struct(); 
        pilotNames = string.empty(0,1); 
        return;
    end

    % Unify variable sets & types so vertcat works
    allTables = unifyTables(allTables);

    % Concatenate all sheets
    bigT = vertcat(allTables{:});

    % Guard: need Lead_Pilot
    if ~ismember('Lead_Pilot', bigT.Properties.VariableNames)
        error('Lead_Pilot column not found for scenario %s.', prefix);
    end

    % Normalize pilot names
    lp = string(bigT.Lead_Pilot);
    lp = strtrim(lp);
    lp(lp=="") = "UNKNOWN";

    % Group by pilot
    [pilotNames, ~, idx] = unique(lp, 'stable');

    outStruct = struct();
    for k = 1:numel(pilotNames)
        thisPilot = pilotNames(k);
        rowsK     = (idx == k);
        pilotTbl  = bigT(rowsK, :);

        safeName = matlab.lang.makeValidName(sprintf('%s_%s', prefix, thisPilot));
        outStruct.(safeName) = pilotTbl;

        if createVars
            assignin('base', safeName, pilotTbl);
        end
    end
end

%% ===== Subfunctions =====
function tablesOut = unifyTables(tablesIn)
    % Build union of variable names across all sheets
    nT = numel(tablesIn);
    allVars = {};
    for i = 1:nT
        allVars = union(allVars, tablesIn{i}.Properties.VariableNames);
    end

    % Decide target type for each variable using only non-missing values
    targetType = containers.Map('KeyType','char','ValueType','char');
    for v = 1:numel(allVars)
        vn = allVars{v};
        targetType(vn) = decideTargetType(vn, tablesIn);
    end

    % Add missing columns, cast to target type, and reorder
    tablesOut = tablesIn;
    for i = 1:nT
        T = tablesOut{i};
        H = height(T);

        % Add missing columns with appropriate missing values
        miss = setdiff(allVars, T.Properties.VariableNames);
        for m = 1:numel(miss)
            vn = miss{m};
            T.(vn) = makeMissing(targetType(vn), H);
        end

        % Cast each column to its target type
        for v = 1:numel(allVars)
            vn = allVars{v};
            T.(vn) = castTo(T.(vn), targetType(vn));
        end

        % Reorder columns for consistency
        T = T(:, allVars);
        tablesOut{i} = T;
    end
end

function t = decideTargetType(vn, tablesIn)
    % Determine target type from non-missing values across sheets:
    % - datetime/duration if present
    % - string if any non-missing is non-numeric text
    % - otherwise double (numbers + NaN/empties or numeric-looking text)
    hasDatetime = false;
    hasDuration = false;
    forceString = false;  % true if any non-missing is non-numeric text
    sawNumeric  = false;  % true if any non-missing numeric/logical seen

    for i = 1:numel(tablesIn)
        T = tablesIn{i};
        if ~ismember(vn, T.Properties.VariableNames), continue; end
        col = T.(vn);

        if isdatetime(col)
            hasDatetime = true; 
            continue;
        end
        if isduration(col)
            hasDuration = true; 
            continue;
        end

        if isnumeric(col) || islogical(col)
            vals = double(col(:));
            if any(~isnan(vals))  % count only non-NaN as evidence of numeric
                sawNumeric = true;
            end
            continue;
        end

        % Text-like: inspect only non-missing and non-empty entries
        s = string(col(:));
        nonmiss = ~(ismissing(s) | s=="");
        if any(nonmiss)
            nums = str2double(s(nonmiss));
            if any(isnan(nums))   % any non-numeric text present
                forceString = true;
            else
                sawNumeric = true; % numeric-looking text is fine
            end
        end
    end

    if hasDatetime, t = 'datetime'; return; end
    if hasDuration, t = 'duration'; return; end
    if forceString, t = 'string';   return; end
    if sawNumeric,  t = 'double';   return; end
    % If everything is missing/empty everywhere, default to string
    t = 'string';
end

function col = makeMissing(ttype, n)
    switch ttype
        case 'string'
            col = strings(n,1);
            col(:) = missing;
        case 'datetime'
            col = NaT(n,1);
        case 'duration'
            col = seconds(n,1);
            col(:) = seconds(NaN);
        otherwise % 'double'
            col = NaN(n,1);
    end
end

function out = castTo(in, ttype)
    % Convert a column to the target type. Non-convertible entries become missing.
    switch ttype
        case 'string'
            out = string(in);
            out(ismissing(out) | out=="") = missing;

        case 'datetime'
            if isdatetime(in)
                out = in;
            else
                s = string(in);
                % First pass: unspecified format, no timezone
                out = datetime(s, 'InputFormat','', 'TimeZone','');
                bad = isnat(out);
                if any(bad)
                    % Second pass: let MATLAB guess
                    try
                        out(bad) = datetime(s(bad));
                    catch
                        % If still bad, leave as NaT
                    end
                end
            end

        case 'duration'
            if isduration(in)
                out = in;
            else
                s = string(in);
                % Try HH:MM:SS first
                try
                    out = duration(s, 'InputFormat','hh:mm:ss');
                catch
                    % Some MATLAB versions use 'Format' not 'InputFormat' for parsing
                    out = duration(s);
                end
                bad = isnat(out);
                if any(bad)
                    % Fallback: numeric seconds
                    nums = str2double(s(bad));
                    out(bad) = seconds(nums); % NaN -> missing
                end
            end

        otherwise % 'double'
            if isnumeric(in) || islogical(in)
                out = double(in);
            else
                s = string(in);
                out = str2double(s); % non-numeric text -> NaN (missing)
            end
    end
end
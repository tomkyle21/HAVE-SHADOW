function outT = buildCorrectSortAndProportion(allDataStruct, scenarioLabel)
% BUILD CORRECT SORT (Y/N) & PROPORTION COMPLETED FROM SHEETS
% Returns one row per raw record (per sheet row), with:
%   Scenario, Configuration, Lead_Pilot,
%   Correct_Sort, Correct_Sort_Score (2 if Y else 1),
%   Proportion_CMs_Intercepted, Proportion_Score (= proportion + 1, clamped)

    sheets = fieldnames(allDataStruct);
    rows = [];

    for i = 1:numel(sheets)
        sh = sheets{i};
        T  = allDataStruct.(sh);

        if ~ismember("Lead_Pilot", T.Properties.VariableNames)
            fprintf('%s: sheet %s skipped (missing Lead_Pilot)\n', string(scenarioLabel), sh);
            continue;
        end

        hasCorrect = ismember("Correct_Sort", T.Properties.VariableNames);
        hasProp    = ismember("Proportion_CMs_Intercepted", T.Properties.VariableNames);
        if ~hasCorrect && ~hasProp, continue; end

        n = height(T);
        sub = table();
        sub.Scenario      = repmat(string(scenarioLabel), n, 1);
        sub.Configuration = repmat(string(sh), n, 1);
        sub.Lead_Pilot    = string(T.Lead_Pilot);

        % ---- Correct_Sort raw & score ----
        if hasCorrect
            csRaw = string(T.Correct_Sort);
            csRaw(ismissing(csRaw)) = "N";
        else
            csRaw = repmat("N", n, 1);
        end
        sub.Correct_Sort = csRaw;

        isYes = csRaw == "Y" | csRaw == "y" | csRaw == "Yes" | csRaw == "YES" | ...
                csRaw == "True" | csRaw == "true" | csRaw == "1";
        csScore = ones(n,1);    % default 1
        csScore(isYes) = 2;
        sub.Correct_Sort_Score = csScore;

        % ---- Proportion_CMs_Intercepted raw & score ----
        if hasProp
            p = double(T.Proportion_CMs_Intercepted);
            p(~isfinite(p)) = 0;
            p = max(0, min(1, p));   % clamp to [0,1]
        else
            p = zeros(n,1);
        end
        sub.Proportion_CMs_Intercepted = p;

        pScore = p + 1;
        pScore = min(max(pScore, 1), 2);
        sub.Proportion_Score = pScore;

        rows = [rows; sub]; %#ok<AGROW>
    end

    outT = rows;
end
function outT = buildSAMID_exp_twoPoint(allDataStruct, scenarioLabel, b_t, tau_t, useLog)
% Outputs table with:
%   Scenario, Configuration, Lead_Pilot,
%   Avg_SAM_ID_Time_s, Proportion_SAMs_Identified,
%   SAM_ID_Time_Score, SAM_ID_Proportion_Score

    sheets = fieldnames(allDataStruct);
    rows = [];

    for i = 1:numel(sheets)
        sh = sheets{i};
        T  = allDataStruct.(sh);

        need = ["Avg_SAM_ID_Time_s","Proportion_SAMs_Identified","Lead_Pilot"];
        if ~all(ismember(need, T.Properties.VariableNames))
            % skip quietly if missing columns
            continue;
        end

        n = height(T);
        sub = table();
        sub.Scenario   = repmat(string(scenarioLabel), n, 1);
        sub.Configuration = repmat(string(sh),         n, 1);
        sub.Lead_Pilot = string(T.Lead_Pilot(:));

        % Raw columns coerced numeric
        time_s  = toNum(T.Avg_SAM_ID_Time_s);           time_s  = time_s(:);
        prop_id = toNum(T.Proportion_SAMs_Identified);  prop_id = prop_id(:);

        sub.Avg_SAM_ID_Time_s        = time_s;
        sub.Proportion_SAMs_Identified= prop_id;

        % ---- Scores ----
        % (1) Proportion: 1 + p, clamped to [1,2]
        p = prop_id;
        p(~isfinite(p)) = 0;                   % treat missing as 0 identified
        propScore = 1 + max(0,min(1,p));
        propScore = min(max(propScore,1),2);

        % (2) Time: exponential around fitted baseline, higher is better (faster)
        teff = time_s;
        if useLog, teff = log1p(max(time_s,0)); end
        delta = max(0, teff - b_t);
        timeScore = 1 + exp(-(delta + 1e-9) ./ max(tau_t, eps)); % tiny epsilon avoids exact 2 pileup
        timeScore = min(max(timeScore,1),2);

        sub.SAM_ID_Proportion_Score = propScore;
        sub.SAM_ID_Time_Score       = timeScore;

        rows = [rows; sub]; %#ok<AGROW>
    end

    varNames = {'Scenario','Configuration','Lead_Pilot', ...
                'Avg_SAM_ID_Time_s','Proportion_SAMs_Identified', ...
                'SAM_ID_Time_Score','SAM_ID_Proportion_Score'};
    if isempty(rows)
        outT = table('Size',[0 numel(varNames)], ...
            'VariableTypes',{'string','string','string','double','double','double','double'}, ...
            'VariableNames',varNames);
    else
        outT = rows(:,varNames);
    end
end
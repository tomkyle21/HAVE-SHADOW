function outT = buildComms_exp_twoPoint(allDataStruct, scenarioLabel, b_t, tau_t, useLog)
% Outputs:
%   Scenario, Configuration, Lead_Pilot,
%   Num_Tactical_Comms, Comms_Density_Score  (in [1,2])

    sheets = fieldnames(allDataStruct);
    rows = [];

    for i = 1:numel(sheets)
        sh = sheets{i};
        T  = allDataStruct.(sh);

        need = ["Num_Tactical_Comms","Lead_Pilot"];
        if ~all(ismember(need, T.Properties.VariableNames)), continue; end

        n = height(T);

        sub = table();
        sub.Scenario     = repmat(string(scenarioLabel), n, 1);
        sub.Configuration= repmat(string(sh),            n, 1);
        sub.Lead_Pilot   = string(T.Lead_Pilot(:));

        cnt = toNum(T.Num_Tactical_Comms); cnt = cnt(:);
        sub.Num_Tactical_Comms = cnt;

        % Score (lower is better)
        xeff = cnt;
        if useLog, xeff = log1p(max(cnt,0)); end
        delta = max(0, xeff - b_t);
        score = 1 + exp(-(delta + 1e-9) ./ max(tau_t, eps));  % tiny eps avoids exact 2 pile-up
        score = min(max(score, 1), 2);

        sub.Comms_Density_Score = score;

        rows = [rows; sub]; %#ok<AGROW>
    end

    varNames = {'Scenario','Configuration','Lead_Pilot','Num_Tactical_Comms','Comms_Density_Score'};
    varTypes = {'string','string','string','double','double'};
    if isempty(rows)
        outT = table('Size',[0 numel(varNames)], 'VariableTypes',varTypes, 'VariableNames',varNames);
    else
        outT = rows(:,varNames);
    end
end
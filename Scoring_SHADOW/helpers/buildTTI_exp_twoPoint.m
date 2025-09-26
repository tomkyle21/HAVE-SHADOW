function outT = buildTTI_exp_twoPoint(allDataStruct, scenarioLabel, interceptNums, ...
                                      b_t, tau_t, useLog)
% Apply score = 1 + exp(-(t_eff - b_t)/tau_t), where t_eff is TTI or log1p(TTI)
    sheets = fieldnames(allDataStruct);
    rows = [];

    for i = 1:numel(sheets)
        sh = sheets{i};
        T  = allDataStruct.(sh);

        if ~ismember("Lead_Pilot", T.Properties.VariableNames)
            fprintf('TTI: Sheet %s skipped (missing Lead_Pilot)\n', sh);
            continue;
        end

        n = height(T);
        scenarioCol = repmat(string(scenarioLabel), n, 1);
        configCol   = repmat(string(sh),            n, 1);
        pilotCol    = string(T.Lead_Pilot(:));

        for k = interceptNums
            vTTI = sprintf('CM%d_MOP_Time_to_Intercept_s', k);
            if ~ismember(vTTI, T.Properties.VariableNames), continue; end

            tti = toNum(T.(vTTI)); tti = tti(:);
            t_eff = tti;
            if useLog, t_eff = log1p(max(tti,0)); end

            delta = max(0, t_eff - b_t);
            score = 1 + exp(-delta ./ max(tau_t, eps));
            score = min(max(score,1),2);

            sub = table();
            sub.Scenario            = scenarioCol;
            sub.Configuration       = configCol;
            sub.Lead_Pilot          = pilotCol;
            sub.Intercept_Num       = repmat(k, n, 1);
            sub.TimeToIntercept_s   = tti;
            sub.TTI_Score           = score;

            rows = [rows; sub]; %#ok<AGROW>
        end
    end

    varNames = {'Scenario','Configuration','Lead_Pilot','Intercept_Num', ...
                'TimeToIntercept_s','TTI_Score'};
    varTypes = {'string','string','string','double','double','double'};

    if isempty(rows)
        outT = table('Size',[0 numel(varNames)], ...
                     'VariableTypes',varTypes, ...
                     'VariableNames',varNames);
    else
        outT = rows(:,varNames);
    end
end
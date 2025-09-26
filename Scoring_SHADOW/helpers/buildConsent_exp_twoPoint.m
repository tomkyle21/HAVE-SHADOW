function outT = buildConsent_exp_twoPoint(allDataStruct, scenarioLabel, interceptNums, ...
                                          b_t, tau_t, useLog)
% Score = 1 + exp(-(t_eff - b_t)/tau_t), clipped to [1,2)

    sheets = fieldnames(allDataStruct);
    rows = [];

    for i = 1:numel(sheets)
        sh = sheets{i};
        T  = allDataStruct.(sh);

        if ~ismember("Lead_Pilot", T.Properties.VariableNames)
            fprintf('TTC: Sheet %s skipped (missing Lead_Pilot)\n', sh);
            continue;
        end

        n = height(T);
        scenarioCol = repmat(string(scenarioLabel), n, 1);
        configCol   = repmat(string(sh),            n, 1);
        pilotCol    = string(T.Lead_Pilot(:));

        for k = interceptNums
            vTTC = sprintf('CM%d_MOP_Time_to_Consent_s', k);
            if ~ismember(vTTC, T.Properties.VariableNames), continue; end

            ttc   = toNum(T.(vTTC)); 
            ttc   = ttc(:);

            % transform if requested
            t_eff = ttc; 
            if useLog, t_eff = log1p(max(ttc,0)); end

            % exponential scoring
            delta = max(0, t_eff - b_t);
            score = 1 + exp(-delta ./ max(tau_t, eps));
            score = min(max(score, 1), 2);   % clamp

            % pack sub-table
            sub = table();
            sub.Scenario        = scenarioCol;
            sub.Configuration   = configCol;
            sub.Lead_Pilot      = pilotCol;
            sub.Intercept_Num   = repmat(k, n, 1);
            sub.TimeToConsent_s = ttc;
            sub.Consent_Score   = score;

            rows = [rows; sub]; %#ok<AGROW>
        end
    end

    varNames = {'Scenario','Configuration','Lead_Pilot','Intercept_Num', ...
                'TimeToConsent_s','Consent_Score'};
    varTypes = {'string','string','string','double','double','double'};

    if isempty(rows)
        outT = table('Size',[0 numel(varNames)], ...
                     'VariableTypes',varTypes, ...
                     'VariableNames',varNames);
    else
        outT = rows(:,varNames);
    end
end

% function outT = buildConsent_exp_twoPoint(allDataStruct, scenarioLabel, interceptNums, ...
%                                           b_t, tau_t, useLog, epsTop)
% % Score = 1 + (1 - epsTop) * exp(-(t_eff - b_t)/tau_t), clipped to [1, 2-eps]
%     if nargin < 7 || isempty(epsTop), epsTop = 0.03; end
% 
%     sheets = fieldnames(allDataStruct);
%     rows = [];
% 
%     for i = 1:numel(sheets)
%         sh = sheets{i};
%         T  = allDataStruct.(sh);
% 
%         if ~ismember("Lead_Pilot", T.Properties.VariableNames)
%             fprintf('TTC: Sheet %s skipped (missing Lead_Pilot)\n', sh);
%             continue;
%         end
% 
%         n = height(T);
%         scenarioCol = repmat(string(scenarioLabel), n, 1);
%         configCol   = repmat(string(sh),            n, 1);
%         pilotCol    = string(T.Lead_Pilot(:));
% 
%         for k = interceptNums
%             vTTC = sprintf('CM%d_MOP_Time_to_Consent_s', k);
%             if ~ismember(vTTC, T.Properties.VariableNames), continue; end
% 
%             ttc   = toNum(T.(vTTC)); ttc = ttc(:);
%             t_eff = ttc; if useLog, t_eff = log1p(max(ttc,0)); end
% 
%             delta = max(0, t_eff - b_t);
%             score = 1 + (1 - epsTop) * exp(-delta ./ max(tau_t, eps));
%             score = min(max(score, 1), 2 - 1e-6);   % clamp
% 
%             sub = table();
%             sub.Scenario             = scenarioCol;
%             sub.Configuration        = configCol;
%             sub.Lead_Pilot           = pilotCol;
%             sub.Intercept_Num        = repmat(k, n, 1);
%             sub.TimeToConsent_s      = ttc;
%             sub.Consent_Score        = score;
% 
%             rows = [rows; sub]; %#ok<AGROW>
%         end
%     end
% 
%     varNames = {'Scenario','Configuration','Lead_Pilot','Intercept_Num', ...
%                 'TimeToConsent_s','Consent_Score'};
%     varTypes = {'string','string','string','double','double','double'};
% 
%     if isempty(rows)
%         outT = table('Size',[0 numel(varNames)], ...
%                      'VariableTypes',varTypes, ...
%                      'VariableNames',varNames);
%     else
%         outT = rows(:,varNames);
%     end
% end
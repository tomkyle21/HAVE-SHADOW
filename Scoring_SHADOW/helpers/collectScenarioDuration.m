function T = collectScenarioDuration(allData, scenarioLabel)
    % Walk every sheet in the scenario struct and pull Scenario_Duration_s (if present).
    % allData.<SheetName> is expected to be a table. The sheet name is the Configuration label.
    T = table();
    if isempty(allData), return; end
    fns = fieldnames(allData);
    for k = 1:numel(fns)
        cfgName = fns{k};
        S = allData.(cfgName);
        if ~istable(S), continue; end
        if ismember('Scenario_Duration_s', S.Properties.VariableNames)
            % Require Lead_Pilot (consistent with rest of pipeline)
            if ~ismember('Lead_Pilot', S.Properties.VariableNames)
                warning('[%s:%s] missing Lead_Pilot; skipping rows for Scenario_Duration_s.', string(scenarioLabel), cfgName);
                continue;
            end
            % Build rows
            tmp = table( repmat(string(scenarioLabel), height(S),1), ...
                         repmat(string(cfgName),        height(S),1), ...
                         string(S.Lead_Pilot), ...
                         double(S.Scenario_Duration_s), ...
                         'VariableNames', {'Scenario','Configuration','Lead_Pilot','Scenario_Duration_s'});
            % Keep only finite durations
            tmp = tmp(isfinite(tmp.Scenario_Duration_s), :);
            T = [T; tmp]; %#ok<AGROW>
        end
    end
end


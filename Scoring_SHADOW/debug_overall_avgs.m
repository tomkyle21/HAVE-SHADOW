%% ===================== DEBUG: PLOT ALL AVERAGE-BASED OVERALLS =====================
% Uses the averages flow (not per-intercept products):
%   - AvgTerminalOverall (Avg_Terminal_Overall_Score)
%   - AvgTimeEfficiencyOverall (Avg_Time_Efficiency_Score)
%   - S_sam (SAM_Subtask_Overall_Score)
%   - ScenarioWide (Scenario_Wide_Overall_Score)
%   - CfgOverall (prefer Unweighted column if present)
%
% Requires on path:
%   makePlotsOverallNamed(T, scenarioLabel, scoreVar, titleSuffix, useLift)

fprintf('\n=== DEBUG: Creating average-based overall plots ===\n');

useLiftOverall = false;     % plot raw averages (no lift)
scenarios = {'C','D'};

% 1) Average Terminal Conditions Overall
T_term = table(); colTerm = '';
if exist('AvgTerminalOverall','var') && istable(AvgTerminalOverall)
    if ismember('Avg_Terminal_Overall_Score', AvgTerminalOverall.Properties.VariableNames)
        T_term = AvgTerminalOverall; colTerm = 'Avg_Terminal_Overall_Score';
    end
end
if ~isempty(T_term)
    for s = 1:numel(scenarios)
        try
            makePlotsOverallNamed(T_term, scenarios{s}, colTerm, 'Avg Terminal Conditions Overall', useLiftOverall);
        catch ME
            warning('Avg Terminal plot failed for scenario %s: %s', scenarios{s}, ME.message);
        end
    end
else
    warning('AvgTerminalOverall.Avg_Terminal_Overall_Score not found; skipping.');
end

% 2) Average Time Efficiency Overall (TTI × TTC averages)
T_time = table(); colTime = '';
if exist('AvgTimeEfficiencyOverall','var') && istable(AvgTimeEfficiencyOverall)
    if ismember('Avg_Time_Efficiency_Score', AvgTimeEfficiencyOverall.Properties.VariableNames)
        T_time = AvgTimeEfficiencyOverall; colTime = 'Avg_Time_Efficiency_Score';
    end
end
if ~isempty(T_time)
    for s = 1:numel(scenarios)
        try
            makePlotsOverallNamed(T_time, scenarios{s}, colTime, 'Avg Time Efficiency Overall', useLiftOverall);
        catch ME
            warning('Avg Time Efficiency plot failed for scenario %s: %s', scenarios{s}, ME.message);
        end
    end
else
    warning('AvgTimeEfficiencyOverall.Avg_Time_Efficiency_Score not found; skipping.');
end

% 3) SAM Subtask Overall (proportion × time)
T_sam = table(); colSAM = '';
if exist('S_sam','var') && istable(S_sam)
    if ismember('SAM_Subtask_Overall_Score', S_sam.Properties.VariableNames)
        T_sam = S_sam; colSAM = 'SAM_Subtask_Overall_Score';
    end
end
if ~isempty(T_sam)
    for s = 1:numel(scenarios)
        try
            makePlotsOverallNamed(T_sam, scenarios{s}, colSAM, 'SAM Subtask Overall', useLiftOverall);
        catch ME
            warning('SAM Subtask plot failed for scenario %s: %s', scenarios{s}, ME.message);
        end
    end
else
    warning('S_sam.SAM_Subtask_Overall_Score not found; skipping.');
end

% 4) Scenario-Wide Overall (AltDev × Correct Sort × %Completed × Comms)
T_sw = table(); colSW = '';
if exist('ScenarioWide','var') && istable(ScenarioWide)
    if ismember('Scenario_Wide_Overall_Score', ScenarioWide.Properties.VariableNames)
        T_sw = ScenarioWide; colSW = 'Scenario_Wide_Overall_Score';
    end
end
if ~isempty(T_sw)
    for s = 1:numel(scenarios)
        try
            makePlotsOverallNamed(T_sw, scenarios{s}, colSW, 'Scenario-Wide Overall', useLiftOverall);
        catch ME
            warning('Scenario-Wide plot failed for scenario %s: %s', scenarios{s}, ME.message);
        end
    end
else
    warning('ScenarioWide.Scenario_Wide_Overall_Score not found; skipping.');
end

% 5) Configuration Overall (built from averages) — prefer unweighted if available
T_cfg = table(); colCfg = '';
if exist('CfgOverall','var') && istable(CfgOverall)
    if ismember('Configuration_Overall_Score_Unweighted', CfgOverall.Properties.VariableNames)
        T_cfg = CfgOverall; colCfg = 'Configuration_Overall_Score_Unweighted';
    elseif ismember('Configuration_Overall_Score', CfgOverall.Properties.VariableNames)
        % fall back to whatever exists (should already be without lift/weights per your latest build)
        T_cfg = CfgOverall; colCfg = 'Configuration_Overall_Score';
    end
end
if ~isempty(T_cfg)
    for s = 1:numel(scenarios)
        try
            makePlotsOverallNamed(T_cfg, scenarios{s}, colCfg, 'Configuration Overall', useLiftOverall);
        catch ME
            warning('Configuration Overall plot failed for scenario %s: %s', scenarios{s}, ME.message);
        end
    end
else
    warning('CfgOverall.*Configuration_Overall_* not found; skipping Configuration Overall plots.');
end

fprintf('=== DEBUG: Done creating average-based overall plots ===\n');
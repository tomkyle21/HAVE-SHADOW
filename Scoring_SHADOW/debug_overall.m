%% ===================== DEBUG: PLOT ALL OVERALLS AT ONCE =====================
% Assumes your plotting helpers are on path:
%   - makePlotsCombined(T, scenarioLabel, useLift)
%   - makePlotsOverallNamed(T, scenarioLabel, scoreVar, titleSuffix, useLift)

fprintf('\n=== DEBUG: Creating all overall plots ===\n');

useLiftOverall = false;                 % overall products can exceed 2: plot raw
scenarios = {'C','D'};


% 2) Overall Intercept (combined across intercepts)
T_oi = table(); colOI = '';
if exist('G','var') && istable(G) && ismember('Overall_Intercept_Product', G.Properties.VariableNames)
    T_oi = G;  colOI = 'Overall_Intercept_Product';
elseif exist('OverallScores','var') && istable(OverallScores) ...
        && ismember('Overall_Intercept_Score', OverallScores.Properties.VariableNames)
    T_oi = OverallScores;  colOI = 'Overall_Intercept_Score';
end
if ~isempty(T_oi)
    for s = 1:numel(scenarios)
        try
            makePlotsOverallNamed(T_oi, scenarios{s}, colOI, 'Overall Intercept (Combined)', useLiftOverall);
        catch ME
            warning('Overall Intercept plot failed for scenario %s: %s', scenarios{s}, ME.message);
        end
    end
else
    warning('No Overall Intercept table/column found (G or OverallScores); skipping.');
end

% 3) SAM Subtask Overall
T_sam = table(); colSAM = '';
if exist('S_sam','var') && istable(S_sam)
    if ismember('SAM_Subtask_Overall_Score', S_sam.Properties.VariableNames)
        T_sam = S_sam; colSAM = 'SAM_Subtask_Overall_Score';
    elseif ismember('SAM_Subtask_Overall_Score_Weighted', S_sam.Properties.VariableNames)
        T_sam = S_sam; colSAM = 'SAM_Subtask_Overall_Score_Weighted';
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
    warning('S_sam.*SAM_Subtask_Overall* not found; skipping SAM Subtask plots.');
end

% 4) Scenario-Wide Overall
T_sw = table(); colSW = '';
if exist('ScenarioWide','var') && istable(ScenarioWide)
    if ismember('Scenario_Wide_Overall_Score', ScenarioWide.Properties.VariableNames)
        T_sw = ScenarioWide; colSW = 'Scenario_Wide_Overall_Score';
    elseif ismember('Scenario_Wide_Overall_Score_Weighted', ScenarioWide.Properties.VariableNames)
        T_sw = ScenarioWide; colSW = 'Scenario_Wide_Overall_Score_Weighted';
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
    warning('ScenarioWide.*Scenario_Wide_Overall* not found; skipping Scenario-Wide plots.');
end

% 5) Configuration Overall
T_cfg = table(); colCfg = '';
if exist('CfgOverall','var') && istable(CfgOverall)
    if ismember('Configuration_Overall_Score', CfgOverall.Properties.VariableNames)
        T_cfg = CfgOverall; colCfg = 'Configuration_Overall_Score';
    elseif ismember('Configuration_Overall_Score_Weighted_NoLift', CfgOverall.Properties.VariableNames)
        T_cfg = CfgOverall; colCfg = 'Configuration_Overall_Score_Weighted_NoLift';
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
    warning('CfgOverall.*Configuration_Overall* not found; skipping Configuration Overall plots.');
end

fprintf('=== DEBUG: Done building overall plots ===\n');


%% Scoring Functions for MOPs
% Maria-Elena Sisneroz
% 20 Sept 2025

%% ========================= MAIN SCORING PIPELINE (REORDERED) =========================
% Order:
% 1) Altitude deviation
% 2) Correct target sort + % intercepts completed
% 3) Terminal condition error
% 4) TTI
% 5) TTC
% EXTRA) Averages for TCE, TTI, TTC (rather than per intercept)
% 6) SAM (% ID'd + time to ID)
% 7) Communication density
% 8) Overall intercept (single = per-intercept product)
% 9) Overall intercept (combined across intercepts)
% EXTRA) Overall Average
% 10) SAM Subtask Overall (NEW)
% 11) Scenario-Wide Overall (NEW)
% 12) Configuration Overall (Weighted + Lift) (NEW)
% ======================================================================================

%% Input data from excel sheets

clear; clc;

% --- NEW: where to put all CSV reference tables ---
refDir = fullfile(pwd,'Ref_Tables');
if ~exist(refDir,'dir'), mkdir(refDir); end

% Scenario C
% Excel file name
filenameC = 'Scenario_C.xlsx';
filenameD = 'Scenario_D.xlsx';

% Replace both loops with these two lines:
c_allData = readScenarioSheets(filenameC);
d_allData = readScenarioSheets(filenameD);

%% ==== Split by Lead_Pilot into C_<Lead_Pilot> / D_<Lead_Pilot> ====

% Toggle this to also create standalone workspace variables (C_<Pilot>, D_<Pilot>)
createWorkspaceVars = true;

[C_byPilot, C_pilotNames] = splitByLeadPilot('C', c_allData, createWorkspaceVars);
[D_byPilot, D_pilotNames] = splitByLeadPilot('D', d_allData, createWorkspaceVars);

%% ===== PRE-FLIGHT VALIDATOR (raw inputs) =====
% % Uncomment as required
% % Put this right after splitByLeadPilot(...)
% validateInputsForScoring(c_allData, d_allData);
% 
% function validateInputsForScoring(c_allData, d_allData)
%     fprintf('\n[VALIDATE] Raw input fields check (C & D)\n');
% 
%     % Terminal-condition required field stems per CMk
%     termStems = { ...
%         'Distance_from_CM_at_Intercept_nm', ...
%         'Altitude_Offset_at_Intercept_ft', ...
%         'Airspeed_Diff_at_Intercept_kt', ...
%         'Heading_Diff_at_Intercept_deg'};
% 
%     % Time metrics
%     ttiStem = 'MOP_Time_to_Intercept_s';
%     ttcStem = 'MOP_Time_to_Consent_s';
% 
%     checkScenario('C', c_allData, 1:5, termStems, ttiStem, ttcStem);
%     checkScenario('D', d_allData, 1:8, termStems, ttiStem, ttcStem);
%     fprintf('[VALIDATE] Done.\n');
% 
%     function checkScenario(tag, S, cmIdx, stems, tti, ttc)
%         % S is a struct of sheets; each sheet is a table
%         missing = false;
%         sheetNames = fieldnames(S);
%         for s = 1:numel(sheetNames)
%             T = S.(sheetNames{s});
%             % Build expected names for each intercept k that might exist on this sheet.
%             for k = cmIdx
%                 % Terminal 4 fields
%                 for j = 1:numel(stems)
%                     need = sprintf('CM%d_%s', k, stems{j});
%                     if ~ismember(need, T.Properties.VariableNames)
%                         warning('[%s:%s] missing column: %s', tag, sheetNames{s}, need);
%                         missing = true;
%                     end
%                 end
%                 % TTI/TTC
%                 needTTI = sprintf('CM%d_%s', k, tti);
%                 needTTC = sprintf('CM%d_%s', k, ttc);
%                 if ~ismember(needTTI, T.Properties.VariableNames)
%                     warning('[%s:%s] missing column: %s', tag, sheetNames{s}, needTTI);
%                     missing = true;
%                 end
%                 if ~ismember(needTTC, T.Properties.VariableNames)
%                     warning('[%s:%s] missing column: %s', tag, sheetNames{s}, needTTC);
%                     missing = true;
%                 end
%             end
%         end
%         if ~missing
%             fprintf('  [%s] OK: required CM columns present across sheets checked.\n', tag);
%         end
%     end
% end
% 
% fprintf('C scenario: created %d pilot groups.\n', numel(C_pilotNames));
% fprintf('D scenario: created %d pilot groups.\n', numel(D_pilotNames));


%% Altitude deviation (scores, not averages)

% ===== Build long table from C & D =====
C_alt = grabAltDev(c_allData,'C');      % expects columns below + Scenario/Configuration/Lead_Pilot
D_alt = grabAltDev(d_allData,'D');
AltDev = [C_alt; D_alt];

% Expect these exact columns in AltDev:
%   Lead_Altitude_Deviation_Count
%   Wingman_Altitude_Deviation_Count
%   Lead_Altitude_Deviation_Integrated_ft_s
%   Wingman_Altitude_Deviation_Integrated_ft_s

% ===== Compute totals =====
AltDev.Total_Altitude_Deviation_Count = AltDev.Lead_Altitude_Deviation_Count + AltDev.Wingman_Altitude_Deviation_Count;
AltDev.Integrated_Altitude_Deviation_ft_s = AltDev.Lead_Altitude_Deviation_Integrated_ft_s + AltDev.Wingman_Altitude_Deviation_Integrated_ft_s;

% ===== Scores in [1,2] (higher is better) =====
% Integrated: smaller integrated is better. Exponential decay from the global best.
x = AltDev.Integrated_Altitude_Deviation_ft_s;
b = min(x,[], 'omitnan');                 % best (global min across all pilots/configs)
x75 = prctile(x(~isnan(x)), 65);
targetScoreAt75 = 1.25;                   % tune if you want more/less down-spread
tau_int = max((x75 - b) / log(1/(targetScoreAt75 - 1)), eps);
AltDev.Integrated_Score = 1 + exp(-(x - b) ./ tau_int);
AltDev.Integrated_Score = min(max(AltDev.Integrated_Score, 1), 2);

% Total deviations count: 0 -> score 2, heavy initial penalty with diminishing effect.
c = AltDev.Total_Altitude_Deviation_Count;
targetScoreAt1 = 1.8;                    % "heavy" first penalty; tune 1.35–1.5
tau_cnt = 1 / log(1/(targetScoreAt1 - 1));% solves 1 + exp(-1/tau_cnt) = targetScoreAt1
AltDev.Count_Score = 1 + exp(-max(0, c) ./ tau_cnt);
AltDev.Count_Score = min(max(AltDev.Count_Score, 1), 2);

% ===== Save the combined table (now includes scores) =====
writetable(AltDev, fullfile(refDir,'AltDev_byPilot_byConfig.csv'));
fprintf('Saved AltDev_byPilot_byConfig.csv (%d rows)\n',height(AltDev));

% ===== Plotting for Scenario C and D separately (scatter, no averaging) =====
makePlotsAltScores(AltDev(AltDev.Scenario=="C",:),'C');
makePlotsAltScores(AltDev(AltDev.Scenario=="D",:),'D');

%% ===== Correct Target Sort & Percent Intercepts Completed =====
% Build from cleaned sheet structs (already loaded earlier)
CS_Prop_C = buildCorrectSortAndProportion(c_allData, 'C');
CS_Prop_D = buildCorrectSortAndProportion(d_allData, 'D');
CS_Prop_All = [CS_Prop_C; CS_Prop_D];

% --- Standardize names for downstream consumers ---
Sort_All = CS_Prop_All;  % alias to expected name

% Correct target sort score -> expected name
if ismember('Correct_Sort_Score', Sort_All.Properties.VariableNames)
    Sort_All.Correct_Target_Sort_Score = Sort_All.Correct_Sort_Score;
elseif ismember('Correct_Target_Sort_Score', Sort_All.Properties.VariableNames)
    % already correct
else
    % fallback from raw proportion/flag
    if ismember('Correct_Sort', Sort_All.Properties.VariableNames)
        Sort_All.Correct_Target_Sort_Score = 1 + toNum(Sort_All.Correct_Sort);
    elseif ismember('Correct_Target_Sort', Sort_All.Properties.VariableNames)
        Sort_All.Correct_Target_Sort_Score = 1 + toNum(Sort_All.Correct_Target_Sort);
    else
        Sort_All.Correct_Target_Sort_Score = ones(height(Sort_All),1);
    end
end

% % Intercepts completed score -> expected name
if ismember('Proportion_Score', Sort_All.Properties.VariableNames)
    Sort_All.Pct_Intercepts_Completed_Score = Sort_All.Proportion_Score;
elseif ismember('Pct_Intercepts_Completed_Score', Sort_All.Properties.VariableNames)
    % already correct
else
    % fallback from raw proportion
    candNames = {'Proportion_CMs_Intercepted','Proportion_Intercepts_Completed'};
    found = candNames(ismember(candNames, Sort_All.Properties.VariableNames));
    if ~isempty(found)
        Sort_All.Pct_Intercepts_Completed_Score = 1 + toNum(Sort_All.(found{1}));
    else
        Sort_All.Pct_Intercepts_Completed_Score = ones(height(Sort_All),1);
    end
end

% Clamp to [1,2] defensively
Sort_All.Correct_Target_Sort_Score      = min(max(Sort_All.Correct_Target_Sort_Score,1),2);
Sort_All.Pct_Intercepts_Completed_Score = min(max(Sort_All.Pct_Intercepts_Completed_Score,1),2);

% Save audit CSVs
writetable(CS_Prop_All(:,{'Scenario','Configuration','Lead_Pilot','Correct_Sort','Correct_Sort_Score'}), ...
    fullfile(refDir,'CorrectSort_Scores_byPilot_byScenario_byConfig.csv'));
fprintf('Saved CorrectSort_Scores_byPilot_byScenario_byConfig.csv (%d rows)\n', height(CS_Prop_All));

writetable(CS_Prop_All(:,{'Scenario','Configuration','Lead_Pilot','Proportion_CMs_Intercepted','Proportion_Score'}), ...
    fullfile(refDir,'ProportionInterceptsCompleted_byPilot_byScenario_byConfig.csv'));
fprintf('Saved ProportionInterceptsCompleted_byPilot_byScenario_byConfig.csv (%d rows)\n', height(CS_Prop_All));

% Plots (like usual)
plotScoreByConfig(CS_Prop_All, 'C', 'Correct_Sort_Score', 'Correct Target Sort (1 = N, 2 = Y)', [0.8 2.2], [1 2], {'N','Y'});
plotScoreByConfig(CS_Prop_All, 'D', 'Correct_Sort_Score', 'Correct Target Sort (1 = N, 2 = Y)', [0.8 2.2], [1 2], {'N','Y'});

plotScoreByConfig(CS_Prop_All, 'C', 'Proportion_Score', 'Percent Intercepts Completed (score = proportion + 1)', [1 2], 1:0.25:2, []);
plotScoreByConfig(CS_Prop_All, 'D', 'Proportion_Score', 'Percent Intercepts Completed (score = proportion + 1)', [1 2], 1:0.25:2, []);
%% ===== Scenario Duration =====
% Expected column present on each sheet (per pilot/config):
%   Scenario_Duration_s     (smaller is better)
%
% Scoring: 1 + exp( - (x_eff - b_eff) / tau ), where x_eff is either (x-b) or log1p(x-b)
% Parameters are fit using two anchor percentiles and a small baseline quantile (not absolute min).

% -------- tunables (kept consistent with other time metrics) --------
useLog  = false;    % set true to compress long tails (like optional TTI/TTC usage)
basePct = 0.01;     % "near-best" baseline (5th–10th pct recommended; keep small)
q1 = 0.25;  s1 = 1.70;   % upper anchor: 25th pct -> ~1.70
q2 = 0.65;  s2 = 1.15;   % lower anchor: 65th–70th pct -> ~1.25

% -------- collect raw durations from the sheet structs --------
Dur_C = collectScenarioDuration(c_allData, 'C');   % columns: Scenario, Configuration, Lead_Pilot, Scenario_Duration_s
Dur_D = collectScenarioDuration(d_allData, 'D');
ScenarioDur_All = [Dur_C; Dur_D];

if isempty(ScenarioDur_All)
    warning('No Scenario_Duration_s found in any sheet; skipping Scenario Duration scoring/plots.');
else
    % -------- fit exp params globally (C + D), baseline quantile (no min pegging) --------
    xAll = ScenarioDur_All.Scenario_Duration_s;
    xAll = xAll(isfinite(xAll));
    if isempty(xAll)
        warning('Scenario_Duration_s vector is empty; skipping scoring.');
    else
        b0   = quantile(xAll, basePct, 'all');                 % baseline
        x1   = quantile(xAll, q1, 'all');
        x2   = quantile(xAll, q2, 'all');

        % effective distances (with/without log1p)
        dist = @(x) (useLog) * log1p(max(0, x - b0)) + (~useLog) * max(0, x - b0);
        d1   = dist(x1);  d2 = dist(x2);

        % Solve tau from both anchors; average (geom mean is stable)
        tau1 = d1 / max(-log(max(s1-1, eps)), eps);
        tau2 = d2 / max(-log(max(s2-1, eps)), eps);
        tau  = max(sqrt(max(tau1, eps) * max(tau2, eps)), eps);

        % -------- score each row --------
        z = dist(ScenarioDur_All.Scenario_Duration_s);
        ScenarioDur_All.Scenario_Duration_Score = 1 + exp( - z ./ tau );
        ScenarioDur_All.Scenario_Duration_Score = min(max(ScenarioDur_All.Scenario_Duration_Score,1),2);

        % -------- save flat CSV --------
        writetable(ScenarioDur_All, fullfile(refDir,'ScenarioDuration_Scores_byPilot_byConfig.csv'));
        fprintf('Saved ScenarioDuration_Scores_byPilot_byConfig.csv (%d rows)\n', height(ScenarioDur_All));

        % -------- optional: C/D plots (scatter + box like others) --------
        if exist('makePlotsOverallNamed','file')
            try
                makePlotsOverallNamed(ScenarioDur_All, 'C', 'Scenario_Duration_Score', 'Scenario Duration Score', false);
            catch ME
                warning('Plot:ScenarioDuration:C', 'Scenario Duration plot failed for C: %s', ME.message);
            end
            try
                makePlotsOverallNamed(ScenarioDur_All, 'D', 'Scenario_Duration_Score', 'Scenario Duration Score', false);
            catch ME
                warning('Plot:ScenarioDuration:D', 'Scenario Duration plot failed for D: %s', ME.message);
            end
        end

        % -------- final deliverable: workbook with sheets by configuration (XLSX stays in current folder) --------
        cfgOrder = {'HH','HA','AH','AA'};
        xlsxOut  = 'ScenarioDuration_byConfig.xlsx';
        if exist(xlsxOut,'file'), delete(xlsxOut); end  % overwrite cleanly

        for i = 1:numel(cfgOrder)
            cfg = cfgOrder{i};
            Tcfg = ScenarioDur_All(string(ScenarioDur_All.Configuration)==cfg, ...
                                   {'Lead_Pilot','Scenario_Duration_s'});
            % Sort pilots stable for nice ordering
            if ~isempty(Tcfg)
                [~, ia] = unique(Tcfg.Lead_Pilot, 'stable');   % if multiple rows per pilot, keep first
                Tcfg = Tcfg(ia,:);
            end
            if isempty(Tcfg)
                % write a header-only table to keep the sheet present
                Tcfg = cell2table(cell(0,2), 'VariableNames', {'Lead_Pilot','Scenario_Duration_s'});
            end
            writetable(Tcfg, xlsxOut, 'Sheet', cfg, 'WriteMode', 'overwritesheet');
        end
        fprintf('Saved workbook with per-config sheets: %s\n', xlsxOut);

        % (Optional) Also emit one CSV per configuration, if you want easy diffs:
        for i = 1:numel(cfgOrder)
            cfg = cfgOrder{i};
            Tcfg = ScenarioDur_All(string(ScenarioDur_All.Configuration)==cfg, ...
                                   {'Lead_Pilot','Scenario_Duration_s'});
            if ~isempty(Tcfg)
                [~, ia] = unique(Tcfg.Lead_Pilot, 'stable');
                Tcfg = Tcfg(ia,:);
            else
                Tcfg = cell2table(cell(0,2), 'VariableNames', {'Lead_Pilot','Scenario_Duration_s'});
            end
            writetable(Tcfg, fullfile(refDir, sprintf('ScenarioDuration_%s.csv', cfg)));
        end
    end
end


%% ===== Terminal condition error: build tables + simple plots (CM# loop) =====
% Exact headers expected (must exist for each CM# that is present on a sheet):
%   CM<#>_Distance_from_CM_at_Intercept_nm
%   CM<#>_Altitude_Offset_at_Intercept_ft
%   CM<#>_Airspeed_Diff_at_Intercept_kt
%   CM<#>_Heading_Diff_at_Intercept_deg
%
% Scenario C has up to CM1..CM5; Scenario D has up to CM1..CM8
maxC = 5;
maxD = 8;

% Build long tables from C & D (uses sheet name as Configuration; skips missing CM#)
C_term = grabTerminal_multi(c_allData, 'C', maxC);
D_term = grabTerminal_multi(d_allData, 'D', maxD);
TermAll = [C_term; D_term];

% Save raw + scores table
if height(TermAll) == 0
    warning('No terminal-condition rows found across scenarios.');
else
    writetable(TermAll, fullfile(refDir,'TerminalScores_AllIntercepts_byPilot_byConfig.csv'));
    fprintf('Saved TerminalScores_AllIntercepts_byPilot_byConfig.csv (%d rows)\n', height(TermAll));

    % Plots per scenario (scatter-only)
    makePlotsTerminal(TermAll(TermAll.Scenario=="C",:), 'C');
    makePlotsTerminal(TermAll(TermAll.Scenario=="D",:), 'D');
end

% % ORIGINAL FOR SINGLE INTERCEPT!!
% % (kept commented, but if re-enabled, ensure CSV path uses refDir)

%% ===== TTI (exponential with two-point tuning) =====
% Choose anchors:
%  - 25th percentile -> score ~1.90 (not pegged at 2)
%  - 75th percentile -> score ~1.15 (push meaningful mass below ~1.3)
% Tunings that de-peg the top and keep good spread
useLog  = false;   % recommended for long tails
basePct = 0.01;   % 5th percentile as "near-best" baseline

q1 = 0.25;  s1 = 1.7;
q2 = 0.65;  s2 = 1.25;

intsC = 1:5; 
intsD = 1:8;

varTemplate_TTI = 'CM%d_MOP_Time_to_Intercept_s';

[b_t, tau_t] = fitExpTwoPointBaseQuantile( ...
    c_allData, d_allData, intsC, intsD, varTemplate_TTI, ...
    q1, s1, q2, s2, basePct, useLog);

C_tti = buildTTI_exp_twoPoint(c_allData, 'C', intsC, b_t, tau_t, useLog);
D_tti = buildTTI_exp_twoPoint(d_allData, 'D', intsD, b_t, tau_t, useLog);
TTI_All = [C_tti; D_tti];% Fit on CM1..CM5 for C and CM1..CM8 for D (adjust if your data differ)

% Save (headers + values)
if ~isempty(TTI_All)
    writecell([TTI_All.Properties.VariableNames; table2cell(TTI_All)], ...
        fullfile(refDir,'TTI_Scores_AllIntercepts_byPilot_byConfig.csv'));
    fprintf('Saved TTI_Scores_AllIntercepts_byPilot_byConfig.csv (%d rows)\n', height(TTI_All));
else
    warning('No TTI rows built — nothing to save.');
end

% Plots (same style as others)
if ~isempty(C_tti), makePlotsTTI(C_tti,'C'); end
if ~isempty(D_tti), makePlotsTTI(D_tti,'D'); end

%% ===== Time to Consent (TTC) Score — exponential, two-point tuned (baseline quantile) =====
intsC = 1:5;            % CM1..CM5 (Scenario C)
intsD = 1:8;            % up to CM8 (Scenario D)

useLog  = false;
basePct = 0.01;

% Keep your anchors the same:
q1 = 0.20;  s1 = 1.7;
q2 = 0.70;  s2 = 1.35;

% Fit b,tau using baseline quantile (no min pegging)
varTemplate_TTC = 'CM%d_MOP_Time_to_Consent_s';
[b_ttc, tau_ttc] = fitExpTwoPointBaseQuantile( ...
    c_allData, d_allData, intsC, intsD, varTemplate_TTC, ...
    q1, s1, q2, s2, basePct, useLog);

% Build TTC tables with your existing builder
C_ttc = buildConsent_exp_twoPoint(c_allData, 'C', intsC, b_ttc, tau_ttc, useLog);
D_ttc = buildConsent_exp_twoPoint(d_allData, 'D', intsD, b_ttc, tau_ttc, useLog);
TTC_All = [C_ttc; D_ttc];

% Save
if ~isempty(TTC_All)
    writecell([TTC_All.Properties.VariableNames; table2cell(TTC_All)], ...
        fullfile(refDir,'TTC_Scores_AllIntercepts_byPilot_byConfig.csv'));
    fprintf('Saved TTC_Scores_AllIntercepts_byPilot_byConfig.csv (%d rows)\n', height(TTC_All));
else
    warning('No TTC rows built — nothing to save.');
end

% Plots (same style as others)
if ~isempty(C_ttc), makePlotsConsent(C_ttc,'C'); end
if ~isempty(D_ttc), makePlotsConsent(D_ttc,'D'); end

%% ===== POST-BUILD VALIDATOR (derived tables) =====
% (unchanged; no CSVs written here)

%% ===== Averages across intercepts (per Scenario–Configuration–Lead_Pilot) =====
% ... (logic unchanged)

% --- Build a master key of all (Scenario, Configuration, Lead_Pilot, Intercept_Num)
keyCols4 = {'Scenario','Configuration','Lead_Pilot','Intercept_Num'};
K = table();

if exist('TermAll','var') && ~isempty(TermAll)
    K = [K; TermAll(:, keyCols4)];
end
if exist('TTI_All','var') && ~isempty(TTI_All)
    K = [K; TTI_All(:, keyCols4)];
end
if exist('TTC_All','var') && ~isempty(TTC_All)
    K = [K; TTC_All(:, keyCols4)];
end

if isempty(K)
    warning('No intercept-level rows available to average.');
else
    [~, ia] = unique(K, 'rows', 'stable');
    K = K(ia, :);

    % ---------- Terminal condition error averages ----------
    TermJoin = K;
    if exist('TermAll','var') && ~isempty(TermAll)
        keepT = {'Scenario','Configuration','Lead_Pilot','Intercept_Num', ...
                 'Distance_Score','Altitude_Score','Airspeed_Score','Heading_Score'};
        Tsub = TermAll(:, intersect(keepT, TermAll.Properties.VariableNames));
        TermJoin = outerjoin(TermJoin, Tsub, 'Keys', keyCols4, 'MergeKeys', true, 'Type','left');
    else
        TermJoin.Distance_Score = nan(height(TermJoin),1);
        TermJoin.Altitude_Score = nan(height(TermJoin),1);
        TermJoin.Airspeed_Score = nan(height(TermJoin),1);
        TermJoin.Heading_Score  = nan(height(TermJoin),1);
    end

    f1 = @(v) fillmissing(v,'constant',1);
    TermJoin.Distance_Score = f1(TermJoin.Distance_Score);
    TermJoin.Altitude_Score = f1(TermJoin.Altitude_Score);
    TermJoin.Airspeed_Score = f1(TermJoin.Airspeed_Score);
    TermJoin.Heading_Score  = f1(TermJoin.Heading_Score);

    TermJoin.Terminal_Product = TermJoin.Distance_Score .* TermJoin.Altitude_Score .* ...
                                TermJoin.Airspeed_Score .* TermJoin.Heading_Score;

    keyCols3 = {'Scenario','Configuration','Lead_Pilot'};
    [g, S, C, P] = findgroups(TermJoin.Scenario, TermJoin.Configuration, TermJoin.Lead_Pilot);

    TermAvg = table();
    TermAvg.Scenario      = S;
    TermAvg.Configuration = C;
    TermAvg.Lead_Pilot    = P;

    TermAvg.Avg_Distance_Score = splitapply(@(x) mean(x,'omitnan'), TermJoin.Distance_Score, g);
    TermAvg.Avg_Altitude_Score = splitapply(@(x) mean(x,'omitnan'), TermJoin.Altitude_Score, g);
    TermAvg.Avg_Airspeed_Score = splitapply(@(x) mean(x,'omitnan'), TermJoin.Airspeed_Score, g);
    TermAvg.Avg_Heading_Score  = splitapply(@(x) mean(x,'omitnan'), TermJoin.Heading_Score,  g);
    TermAvg.Avg_Terminal_Product = splitapply(@(x) mean(x,'omitnan'), TermJoin.Terminal_Product, g);

    writetable(TermAvg, fullfile(refDir,'AvgAcrossIntercepts_Terminal_byPilot_byConfig.csv'));
    fprintf('Saved AvgAcrossIntercepts_Terminal_byPilot_byConfig.csv (%d rows)\n', height(TermAvg));

    % ---------- TTI averages ----------
    TTIJoin = K;
    if exist('TTI_All','var') && ~isempty(TTI_All)
        keepTTI = {'Scenario','Configuration','Lead_Pilot','Intercept_Num','TTI_Score'};
        Tsub = TTI_All(:, intersect(keepTTI, TTI_All.Properties.VariableNames));
        TTIJoin = outerjoin(TTIJoin, Tsub, 'Keys', keyCols4, 'MergeKeys', true, 'Type','left');
    else
        TTIJoin.TTI_Score = nan(height(TTIJoin),1);
    end
    TTIJoin.TTI_Score = f1(TTIJoin.TTI_Score);

    [g2, S2, C2, P2] = findgroups(TTIJoin.Scenario, TTIJoin.Configuration, TTIJoin.Lead_Pilot);
    TTI_Avg = table();
    TTI_Avg.Scenario      = S2;
    TTI_Avg.Configuration = C2;
    TTI_Avg.Lead_Pilot    = P2;
    TTI_Avg.Avg_TTI_Score = splitapply(@(x) mean(x,'omitnan'), TTIJoin.TTI_Score, g2);

    writetable(TTI_Avg, fullfile(refDir,'AvgAcrossIntercepts_TTI_byPilot_byConfig.csv'));
    fprintf('Saved AvgAcrossIntercepts_TTI_byPilot_byConfig.csv (%d rows)\n', height(TTI_Avg));

    % ---------- TTC averages ----------
    TTCJoin = K;
    if exist('TTC_All','var') && ~isempty(TTC_All)
        keepTTC = {'Scenario','Configuration','Lead_Pilot','Intercept_Num','Consent_Score'};
        Tsub = TTC_All(:, intersect(keepTTC, TTC_All.Properties.VariableNames));
        TTCJoin = outerjoin(TTCJoin, Tsub, 'Keys', keyCols4, 'MergeKeys', true, 'Type','left');
    else
        TTCJoin.Consent_Score = nan(height(TTCJoin),1);
    end
    TTCJoin.Consent_Score = f1(TTCJoin.Consent_Score);

    [g3, S3, C3, P3] = findgroups(TTCJoin.Scenario, TTCJoin.Configuration, TTCJoin.Lead_Pilot);
    TTC_Avg = table();
    TTC_Avg.Scenario        = S3;
    TTC_Avg.Configuration   = C3;
    TTC_Avg.Lead_Pilot      = P3;
    TTC_Avg.Avg_TTC_Score   = splitapply(@(x) mean(x,'omitnan'), TTCJoin.Consent_Score, g3);

    writetable(TTC_Avg, fullfile(refDir,'AvgAcrossIntercepts_TTC_byPilot_byConfig.csv'));
    fprintf('Saved AvgAcrossIntercepts_TTC_byPilot_byConfig.csv (%d rows)\n', height(TTC_Avg));
end

% ===== Plots for the per-pilot, per-config AVERAGES (C & D) =====
cfgOrder = {'HH','HA','AH','AA'};
plotOne = @(T,scn,col,ttl) local_plotAvgByCfg(T, scn, col, ttl, cfgOrder);

if exist('TermAvg','var') && ~isempty(TermAvg)
    plotOne(TermAvg,'C','Avg_Distance_Score', 'Avg Distance Score (Terminal)');
    plotOne(TermAvg,'D','Avg_Distance_Score', 'Avg Distance Score (Terminal)');

    plotOne(TermAvg,'C','Avg_Altitude_Score', 'Avg Altitude Score (Terminal)');
    plotOne(TermAvg,'D','Avg_Altitude_Score', 'Avg Altitude Score (Terminal)');

    plotOne(TermAvg,'C','Avg_Airspeed_Score','Avg Airspeed Score (Terminal)');
    plotOne(TermAvg,'D','Avg_Airspeed_Score','Avg Airspeed Score (Terminal)');

    plotOne(TermAvg,'C','Avg_Heading_Score','Avg Heading Score (Terminal)');
    plotOne(TermAvg,'D','Avg_Heading_Score','Avg Heading Score (Terminal)');

    plotOne(TermAvg,'C','Avg_Terminal_Product','Avg Terminal Product');
    plotOne(TermAvg,'D','Avg_Terminal_Product','Avg Terminal Product');
else
    warning('TermAvg missing/empty; skipping terminal-average plots.');
end

if exist('TTI_Avg','var') && ~isempty(TTI_Avg)
    plotOne(TTI_Avg,'C','Avg_TTI_Score','Avg TTI Score');
    plotOne(TTI_Avg,'D','Avg_TTI_Score','Avg TTI Score');
else
    warning('TTI_Avg missing/empty; skipping TTI-average plots.');
end

if exist('TTC_Avg','var') && ~isempty(TTC_Avg)
    plotOne(TTC_Avg,'C','Avg_TTC_Score','Avg TTC Score');
    plotOne(TTC_Avg,'D','Avg_TTC_Score','Avg TTC Score');
else
    warning('TTC_Avg missing/empty; skipping TTC-average plots.');
end

% =================== local function ===================
function local_plotAvgByCfg(Tin, scenarioLabel, scoreCol, titleText, cfgOrder)
    T = Tin(string(Tin.Scenario)==string(scenarioLabel), :);
    if isempty(T), return; end

    if ~ismember(scoreCol, T.Properties.VariableNames)
        warning('Column %s not in table for scenario %s', scoreCol, scenarioLabel);
        return;
    end

    T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    T = T(~isundefined(T.Configuration), :);
    if isempty(T), return; end

    if isnumeric(T.(scoreCol))
        y = T.(scoreCol);
    else
        y = str2double(string(T.(scoreCol)));
    end

    xnum = double(T.Configuration);
    pilots = unique(string(T.Lead_Pilot),'stable');
    cols   = lines(max(numel(pilots),7));
    marks  = {'o','s','^','d','v','>','<','p','h','x','+'};

    figure('Color','w','Name',sprintf('%s – %s', scenarioLabel, titleText)); hold on; grid on;
    rng(1); jit = (rand(size(xnum)) - 0.5) * 0.22;

    legObjs = gobjects(0); legLabs = strings(0,1);
    for p = 1:numel(pilots)
        m = string(T.Lead_Pilot)==pilots(p);
        if ~any(m), continue; end
        c = cols(mod(p-1,size(cols,1))+1, :);
        mk = marks{mod(p-1,numel(marks))+1};
        h = scatter(xnum(m) + jit(m), y(m), 40, c, 'filled', ...
            'Marker', mk, 'MarkerEdgeColor','k', 'LineWidth', 0.25, 'MarkerFaceAlpha', 0.8);
        legObjs(end+1) = h; %#ok<AGROW>
        legLabs(end+1) = pilots(p); %#ok<AGROW>
    end

    xlim([0.5, numel(cfgOrder)+0.5]); xticks(1:numel(cfgOrder)); xticklabels(cfgOrder);
    xlabel('Configuration'); ylabel(strrep(scoreCol,'_',' '));
    title(sprintf('%s – %s', scenarioLabel, titleText), 'Interpreter','none');

    if ~isempty(legObjs)
        lg = legend(legObjs, legLabs, 'Location','bestoutside');
        set(lg,'Interpreter','none');
    end
    hold off;
end

%% ===== SAM Identification Scores =====
% Exact headers expected in each sheet:
%   Avg_SAM_ID_Time_s
%   Proportion_SAMs_Identified

% --- Fit exponential params globally (C + D) for Avg_SAM_ID_Time_s ---
useLog = false;       % log1p compresses tail (set false if you prefer raw)
q1 = 0.28;  s1 = 1.70;   % "near-top" anchor: 25th percentile -> ~1.80
q2 = 0.75;  s2 = 1.25;   % lower anchor: 75th percentile -> ~1.15
[b_sam, tau_sam] = computeSAMTimeExpParamsTwoPoint(c_allData, d_allData, q1, s1, q2, s2, useLog);

% --- Build per-scenario SAM tables with scores ---
C_sam = buildSAMID_exp_twoPoint(c_allData, 'C', b_sam, tau_sam, useLog);
D_sam = buildSAMID_exp_twoPoint(d_allData, 'D', b_sam, tau_sam, useLog);
SAM_All = [C_sam; D_sam];

% Save for audit
if ~isempty(SAM_All)
    writetable(SAM_All, fullfile(refDir,'SAM_ID_Scores_byPilot_byConfig.csv'));
    fprintf('Saved SAM_ID_Scores_byPilot_byConfig.csv (%d rows)\n', height(SAM_All));
else
    warning('No SAM ID rows built — nothing to save.');
end

% Plots (scatter, no averaging)
if ~isempty(C_sam), makePlotsSAMID(C_sam,'C'); end
if ~isempty(D_sam), makePlotsSAMID(D_sam,'D'); end

%% ===== Communication Density Score (Num_Tactical_Comms) =====
% Exact header required in each sheet:
%   Num_Tactical_Comms

% --- Fit params globally across C & D ---
useLog = false;
q1 = 0.20;  s1 = 1.85;
q2 = 0.70;  s2 = 1.25;
[b_comms, tau_comms] = computeCommsExpParamsTwoPoint(c_allData, d_allData, q1, s1, q2, s2, useLog);

% --- Build per-scenario tables with scores ---
C_comms = buildComms_exp_twoPoint(c_allData, 'C', b_comms, tau_comms, useLog);
D_comms = buildComms_exp_twoPoint(d_allData, 'D', b_comms, tau_comms, useLog);
Comms_All = [C_comms; D_comms];

% Save audit CSV
if ~isempty(Comms_All)
    writetable(Comms_All, fullfile(refDir,'Comms_Density_Scores_byPilot_byConfig.csv'));
    fprintf('Saved Comms_Density_Scores_byPilot_byConfig.csv (%d rows)\n', height(Comms_All));
else
    warning('No Comms rows built — nothing to save.');
end

% Plots (scatter, no averaging)
if ~isempty(C_comms), makePlotsComms(C_comms,'C'); end
if ~isempty(D_comms), makePlotsComms(D_comms,'D'); end


%% ===== Combined Intercept Score (Product, with audit + completion flag) =====
% Requires TermAll, TTI_All, TTC_All

keys = unique([TermAll(:,{'Scenario','Configuration','Lead_Pilot','Intercept_Num'});
               TTI_All(:,{'Scenario','Configuration','Lead_Pilot','Intercept_Num'});
               TTC_All(:,{'Scenario','Configuration','Lead_Pilot','Intercept_Num'})]);

n = height(keys);

% Preallocate output with audit columns
CombinedScores = keys;
CombinedScores.Distance_Score            = nan(n,1);
CombinedScores.Altitude_Score            = nan(n,1);
CombinedScores.Airspeed_Score            = nan(n,1);
CombinedScores.Heading_Score             = nan(n,1);
CombinedScores.TTI_Score                 = nan(n,1);
CombinedScores.Consent_Score             = nan(n,1);
CombinedScores.Completed_Flag            = zeros(n,1);  % 1 = completed, 0 = not completed
CombinedScores.Intercept_Combined_Score  = nan(n,1);

% Clamp helper
clamp12 = @(v) min(max(v,1),2);

for i = 1:n
    scn   = keys.Scenario(i);
    cfg   = keys.Configuration(i);
    plyt  = keys.Lead_Pilot(i);
    intN  = keys.Intercept_Num(i);

    tTerm = TermAll(TermAll.Scenario==scn & TermAll.Configuration==cfg & ...
                    TermAll.Lead_Pilot==plyt & TermAll.Intercept_Num==intN, :);

    tTTI  = TTI_All( TTI_All.Scenario==scn  & TTI_All.Configuration==cfg  & ...
                     TTI_All.Lead_Pilot==plyt & TTI_All.Intercept_Num==intN, :);

    tTTC  = TTC_All( TTC_All.Scenario==scn  & TTC_All.Configuration==cfg  & ...
                     TTC_All.Lead_Pilot==plyt & TTC_All.Intercept_Num==intN, :);

    hasTerm = ~isempty(tTerm);
    hasTTI  = ~isempty(tTTI);
    hasTTC  = ~isempty(tTTC);

    if hasTerm
        d  = tTerm.Distance_Score(1);
        a  = tTerm.Altitude_Score(1);
        sp = tTerm.Airspeed_Score(1);
        h  = tTerm.Heading_Score(1);
    else
        d = NaN; a = NaN; sp = NaN; h = NaN;
    end

    if hasTTI, tti = tTTI.TTI_Score(1); else, tti = NaN; end
    if hasTTC, ttc = tTTC.Consent_Score(1); else, ttc = NaN; end

    termVec = [d a sp h];
    isTermValid = all(isfinite(termVec));
    isTTIValid  = isfinite(tti);
    isTTCValid  = isfinite(ttc);
    isCompleted = hasTerm && hasTTI && hasTTC && isTermValid && isTTIValid && isTTCValid;

    if ~isCompleted
        d = 1; a = 1; sp = 1; h = 1; tti = 1; ttc = 1;
        CombinedScores.Completed_Flag(i) = 0;
    else
        d   = clamp12(d);
        a   = clamp12(a);
        sp  = clamp12(sp);
        h   = clamp12(h);
        tti = clamp12(tti);
        ttc = clamp12(ttc);
        CombinedScores.Completed_Flag(i) = 1;
    end

    CombinedScores.Distance_Score(i) = d;
    CombinedScores.Altitude_Score(i) = a;
    CombinedScores.Airspeed_Score(i) = sp;
    CombinedScores.Heading_Score(i)  = h;
    CombinedScores.TTI_Score(i)      = tti;
    CombinedScores.Consent_Score(i)  = ttc;
    CombinedScores.Intercept_Combined_Score(i) = d * a * sp * h * tti * ttc;
end

% Save CSV
writetable(CombinedScores, fullfile(refDir,'InterceptCombinedScores_byPilot_byConfig.csv'));
fprintf('Saved InterceptCombinedScores_byPilot_byConfig.csv (%d rows)\n', height(CombinedScores));

% === Combined-score plots ===
makePlotsCombined(CombinedScores, 'C');
makePlotsCombined(CombinedScores, 'D');

% === Overall Scenario/Config Score (product across intercepts) ===
scores = CombinedScores.Intercept_Combined_Score;
scores(~isfinite(scores)) = 1;

[grp, gpPilot, gpScenario, gpConfig] = findgroups( ...
    CombinedScores.Lead_Pilot, ...
    CombinedScores.Scenario, ...
    CombinedScores.Configuration);

nGroups = max(grp);
overallProd       = nan(nGroups,1);
detailStrings     = strings(nGroups,1);
interceptsIncluded = strings(nGroups,1);
numIntercepts     = zeros(nGroups,1);

for g = 1:nGroups
    idx = (grp == g);
    vals = scores(idx);
    cms  = CombinedScores.Intercept_Num(idx);
    [cms, order] = sort(cms);
    vals = vals(order);
    overallProd(g) = prod(vals);
    parts = compose("CM%d=%.3f", cms, vals);
    detailStrings(g) = strjoin(parts, " * ");
    numIntercepts(g) = numel(cms);
    interceptsIncluded(g) = "[" + strjoin(string(cms), ", ") + "]";
end

OverallScores = table(gpPilot, gpScenario, gpConfig, overallProd, numIntercepts, interceptsIncluded, detailStrings, ...
    'VariableNames', {'Lead_Pilot','Scenario','Configuration','Overall_Intercept_Score','N_Intercepts','Intercepts_Included','Intercept_Score_Factors'});

writetable(OverallScores, fullfile(refDir,'OverallInterceptScore_withAudit_byPilot_byScenario_byConfig.csv'));
fprintf('Saved OverallInterceptScore_withAudit_byPilot_byScenario_byConfig.csv (%d rows)\n', height(OverallScores));

% === Plot Overall Scores by Configuration (scatter) ===
scenarios = unique(string(OverallScores.Scenario), 'stable');
for s = 1:numel(scenarios)
    thisScn = scenarios{s};
    Gs = OverallScores(string(OverallScores.Scenario) == thisScn, :);
    if isempty(Gs), continue; end

    figure('Color','w'); hold on; grid on;
    title(sprintf('Overall Intercept Scores by Configuration — Scenario %s', thisScn));
    xlabel('Configuration');
    ylabel('Overall Intercept Score (product of intercepts)');

    cfgStr  = string(Gs.Configuration);
    cfgCats = unique(cfgStr, 'stable');

    xIdx = zeros(height(Gs),1);
    for i = 1:numel(cfgCats)
        xIdx(cfgStr == cfgCats(i)) = i;
    end

    jitter = (rand(size(xIdx)) - 0.5) * 0.15;
    colors = lines(numel(cfgCats));

    for i = 1:numel(cfgCats)
        idx = (xIdx == i);
        if any(idx)
            scatter(xIdx(idx) + jitter(idx), Gs.Overall_Intercept_Score(idx), ...
                60, colors(i,:), 'filled', 'MarkerEdgeColor','k');
        end
    end

    xlim([0.5, numel(cfgCats)+0.5]);
    xticks(1:numel(cfgCats));
    xticklabels(cfgCats);
end

%% ===== NEW OVERALLS FROM AVERAGES (Terminal & Time Efficiency) =====
keysVars = {'Scenario','Configuration','Lead_Pilot'};

%% EXTRA!! - Average values
% --- (1) Average Terminal Conditions Overall ---
if exist('TermAvg','var') && ~isempty(TermAvg)
    T = TermAvg;
    needCols = {'Avg_Distance_Score','Avg_Altitude_Score','Avg_Airspeed_Score','Avg_Heading_Score'};
    for c = 1:numel(needCols)
        if ~ismember(needCols{c}, T.Properties.VariableNames)
            T.(needCols{c}) = ones(height(T),1);
        end
        T.(needCols{c}) = min(max(double(T.(needCols{c})),1),2);
        T.(needCols{c}) = fillmissing(T.(needCols{c}),'constant',1);
    end

    AvgTerminalOverall = T(:, [keysVars, needCols]);
    AvgTerminalOverall.Avg_Terminal_Overall_Score = ...
          AvgTerminalOverall.Avg_Distance_Score ...
        .* AvgTerminalOverall.Avg_Altitude_Score ...
        .* AvgTerminalOverall.Avg_Airspeed_Score ...
        .* AvgTerminalOverall.Avg_Heading_Score;

    writetable(AvgTerminalOverall, fullfile(refDir,'AvgTerminalOverall_byPilot_byConfig.csv'));
    fprintf('Saved AvgTerminalOverall_byPilot_byConfig.csv (%d rows)\n', height(AvgTerminalOverall));

    if exist('makePlotsOverallNamed','file')
        makePlotsOverallNamed(AvgTerminalOverall,'C','Avg_Terminal_Overall_Score','Avg Terminal Conditions – Overall', false);
        makePlotsOverallNamed(AvgTerminalOverall,'D','Avg_Terminal_Overall_Score','Avg Terminal Conditions – Overall', false);
    end
else
    warning('TermAvg missing/empty; skipping Average Terminal Conditions Overall.');
    AvgTerminalOverall = table();
end

% --- (2) Average Time Efficiency Overall (Avg_TTI * Avg_TTC) ---
haveTTI = exist('TTI_Avg','var') && ~isempty(TTI_Avg);
haveTTC = exist('TTC_Avg','var') && ~isempty(TTC_Avg);

if haveTTI || haveTTC
    if haveTTI
        A = TTI_Avg(:, [keysVars, {'Avg_TTI_Score'}]);
    else
        A = table();
    end
    if haveTTC
        B = TTC_Avg(:, [keysVars, {'Avg_TTC_Score'}]);
    else
        B = table();
    end

    if isempty(A) && ~isempty(B)
        AvgTimeEfficiencyOverall = B;
    elseif ~isempty(A) && isempty(B)
        AvgTimeEfficiencyOverall = A;
    else
        AvgTimeEfficiencyOverall = outerjoin(A, B, 'Keys', keysVars, 'MergeKeys', true, 'Type','full');
    end

    if ~ismember('Avg_TTI_Score', AvgTimeEfficiencyOverall.Properties.VariableNames)
        AvgTimeEfficiencyOverall.Avg_TTI_Score = ones(height(AvgTimeEfficiencyOverall),1);
    end
    if ~ismember('Avg_TTC_Score', AvgTimeEfficiencyOverall.Properties.VariableNames)
        AvgTimeEfficiencyOverall.Avg_TTC_Score = ones(height(AvgTimeEfficiencyOverall),1);
    end

    AvgTimeEfficiencyOverall.Avg_TTI_Score = min(max(double(fillmissing(AvgTimeEfficiencyOverall.Avg_TTI_Score,'constant',1)),1),2);
    AvgTimeEfficiencyOverall.Avg_TTC_Score = min(max(double(fillmissing(AvgTimeEfficiencyOverall.Avg_TTC_Score,'constant',1)),1),2);

    AvgTimeEfficiencyOverall.Avg_Time_Efficiency_Score = ...
        AvgTimeEfficiencyOverall.Avg_TTI_Score .* AvgTimeEfficiencyOverall.Avg_TTC_Score;

    writetable(AvgTimeEfficiencyOverall, fullfile(refDir,'AvgTimeEfficiencyOverall_byPilot_byConfig.csv'));
    fprintf('Saved AvgTimeEfficiencyOverall_byPilot_byConfig.csv (%d rows)\n', height(AvgTimeEfficiencyOverall));

    if exist('makePlotsOverallNamed','file')
        makePlotsOverallNamed(AvgTimeEfficiencyOverall,'C','Avg_Time_Efficiency_Score','Avg Time Efficiency – Overall', false);
        makePlotsOverallNamed(AvgTimeEfficiencyOverall,'D','Avg_Time_Efficiency_Score','Avg Time Efficiency – Overall', false);
    end
else
    warning('TTI_Avg and TTC_Avg both missing/empty; skipping Average Time Efficiency Overall.');
    AvgTimeEfficiencyOverall = table();
end

%% ===== A) SAM Subtask Overall (raw product per pilot/config) =====
if exist('SAM_All','var') && ~isempty(SAM_All)
    T = SAM_All;
    T.Row_SAM_Subtask = T.SAM_ID_Time_Score .* T.SAM_ID_Proportion_Score;

    keepVars = {'Scenario','Configuration','Lead_Pilot', ...
                'SAM_ID_Time_Score','SAM_ID_Proportion_Score','Row_SAM_Subtask'};
    T = T(:, keepVars);
    [~, ia] = unique(T(:, {'Scenario','Configuration','Lead_Pilot'}), 'rows', 'stable');
    S_sam = T(ia, :);
    S_sam.Properties.VariableNames{'Row_SAM_Subtask'} = 'SAM_Subtask_Overall_Score';

    writetable(S_sam, fullfile(refDir,'SAM_Subtask_Overall_byPilot_byConfig.csv'));
    fprintf('Saved SAM_Subtask_Overall_byPilot_byConfig.csv (%d rows)\n', height(S_sam));

    makePlotsOverallNamed(S_sam,'C','SAM_Subtask_Overall_Score','SAM Subtask Overall');
    makePlotsOverallNamed(S_sam,'D','SAM_Subtask_Overall_Score','SAM Subtask Overall');
else
    warning('SAM_All not found or empty; skipping SAM subtask overall.');
    S_sam = table();
end

%% ===== B) Scenario-Wide Overall (per pilot/config, robust to missing pieces) =====
AltAgg = table();
if exist('AltDev','var') && ~isempty(AltDev)
    A = AltDev;
    A.Row_AltDev_Overall = A.Integrated_Score .* A.Count_Score;
    A = A(:, {'Scenario','Configuration','Lead_Pilot','Row_AltDev_Overall'});
    [~, ia] = unique(A(:, {'Scenario','Configuration','Lead_Pilot'}), 'rows', 'stable');
    AltAgg = A(ia, :);
    AltAgg.Properties.VariableNames{'Row_AltDev_Overall'} = 'AltDev_Overall_Score';
end

SortAgg = table();
if exist('Sort_All','var') && ~isempty(Sort_All)
    Srt = Sort_All;
    if ismember('Correct_Target_Sort_Score', Srt.Properties.VariableNames)
        Srt.Correct_Target_Sort_Score = min(max(Srt.Correct_Target_Sort_Score,1),2);
    elseif ismember('Correct_Target_Sort', Srt.Properties.VariableNames)
        Srt.Correct_Target_Sort_Score = min(max(1 + toNum(Srt.Correct_Target_Sort),1),2);
    else
        Srt.Correct_Target_Sort_Score = ones(height(Srt),1);
        warning('Sort_All missing Correct Target Sort — defaulted to score=1.');
    end

    if ismember('Pct_Intercepts_Completed_Score', Srt.Properties.VariableNames)
        Srt.Pct_Intercepts_Completed_Score = min(max(Srt.Pct_Intercepts_Completed_Score,1),2);
    elseif ismember('Proportion_Intercepts_Completed', Srt.Properties.VariableNames)
        Srt.Pct_Intercepts_Completed_Score = min(max(1 + toNum(Srt.Proportion_Intercepts_Completed),1),2);
    else
        Srt.Pct_Intercepts_Completed_Score = ones(height(Srt),1);
        warning('Sort_All missing %% Intercepts Completed — defaulted to score=1.');
    end

    Srt = Srt(:, {'Scenario','Configuration','Lead_Pilot', ...
                  'Correct_Target_Sort_Score','Pct_Intercepts_Completed_Score'});
    [~, ia] = unique(Srt(:, {'Scenario','Configuration','Lead_Pilot'}), 'rows', 'stable');
    SortAgg = Srt(ia, :);
end

CommsAgg = table();
if exist('Comms_All','var') && ~isempty(Comms_All)
    Cc = Comms_All(:, {'Scenario','Configuration','Lead_Pilot','Comms_Density_Score'});
    [~, ia] = unique(Cc(:, {'Scenario','Configuration','Lead_Pilot'}), 'rows', 'stable');
    CommsAgg = Cc(ia, :);
end

keysVars = {'Scenario','Configuration','Lead_Pilot'};
baseKeys = table();

candidates = {};
if ~isempty(AltAgg),   candidates{end+1} = AltAgg(:, keysVars); end 
if ~isempty(SortAgg),  candidates{end+1} = SortAgg(:, keysVars); end 
if ~isempty(CommsAgg), candidates{end+1} = CommsAgg(:, keysVars); end 
if isempty(candidates)
    if exist('CombinedScores','var') && ~isempty(CombinedScores)
        candidates{end+1} = unique(CombinedScores(:, keysVars)); 
    elseif exist('SAM_All','var') && ~isempty(SAM_All)
        candidates{end+1} = unique(SAM_All(:, keysVars)); 
    else
        warning('No source tables to build Scenario-Wide keys; skipping Scenario-Wide overall.');
        ScenarioWide = table();
    end
end

if ~exist('ScenarioWide','var') || isempty(ScenarioWide)
    allKeys = vertcat(candidates{:});
    [~, ia] = unique(allKeys, 'rows', 'stable');
    baseKeys = allKeys(ia, :);
end

if isempty(baseKeys)
    ScenarioWide = table();
else
    ScenarioWide = baseKeys;
    if ~isempty(AltAgg)
        ScenarioWide = outerjoin(ScenarioWide, AltAgg, 'Keys', keysVars, 'MergeKeys', true, 'Type','left');
    else
        ScenarioWide.AltDev_Overall_Score = ones(height(ScenarioWide),1);
    end
    if ~ismember('AltDev_Overall_Score', ScenarioWide.Properties.VariableNames)
        ScenarioWide.AltDev_Overall_Score = ones(height(ScenarioWide),1);
    end

    if ~isempty(SortAgg)
        ScenarioWide = outerjoin(ScenarioWide, SortAgg, 'Keys', keysVars, 'MergeKeys', true, 'Type','left');
    else
        ScenarioWide.Correct_Target_Sort_Score      = ones(height(ScenarioWide),1);
        ScenarioWide.Pct_Intercepts_Completed_Score = ones(height(ScenarioWide),1);
    end
    if ~ismember('Correct_Target_Sort_Score', ScenarioWide.Properties.VariableNames)
        ScenarioWide.Correct_Target_Sort_Score = ones(height(ScenarioWide),1);
    end
    if ~ismember('Pct_Intercepts_Completed_Score', ScenarioWide.Properties.VariableNames)
        ScenarioWide.Pct_Intercepts_Completed_Score = ones(height(ScenarioWide),1);
    end

    if ~isempty(CommsAgg)
        ScenarioWide = outerjoin(ScenarioWide, CommsAgg, 'Keys', keysVars, 'MergeKeys', true, 'Type','left');
    else
        ScenarioWide.Comms_Density_Score = ones(height(ScenarioWide),1);
    end
    if ~ismember('Comms_Density_Score', ScenarioWide.Properties.VariableNames)
        ScenarioWide.Comms_Density_Score = ones(height(ScenarioWide),1);
    end

    ScenarioWide.AltDev_Overall_Score            = fillmissing(ScenarioWide.AltDev_Overall_Score, 'constant', 1);
    ScenarioWide.Correct_Target_Sort_Score       = fillmissing(ScenarioWide.Correct_Target_Sort_Score, 'constant', 1);
    ScenarioWide.Pct_Intercepts_Completed_Score  = fillmissing(ScenarioWide.Pct_Intercepts_Completed_Score, 'constant', 1);
    ScenarioWide.Comms_Density_Score             = fillmissing(ScenarioWide.Comms_Density_Score, 'constant', 1);

    ScenarioWide.Scenario_Wide_Overall_Score = ...
        ScenarioWide.AltDev_Overall_Score .* ...
        ScenarioWide.Correct_Target_Sort_Score .* ...
        ScenarioWide.Pct_Intercepts_Completed_Score .* ...
        ScenarioWide.Comms_Density_Score;

    writetable(ScenarioWide, fullfile(refDir,'ScenarioWide_Overall_byPilot_byConfig.csv'));
    fprintf('Saved ScenarioWide_Overall_byPilot_byConfig.csv (%d rows)\n', height(ScenarioWide));

    makePlotsOverallNamed(ScenarioWide,'C','Scenario_Wide_Overall_Score','Scenario-Wide Overall');
    makePlotsOverallNamed(ScenarioWide,'D','Scenario_Wide_Overall_Score','Scenario-Wide Overall');
end

%% ===== C) Configuration Overall (per pilot/config: raw PRODUCT) =====
keys = {'Scenario','Configuration','Lead_Pilot'};

if exist('AvgTerminalOverall','var') && ~isempty(AvgTerminalOverall)
    [~, ia] = unique(AvgTerminalOverall(:,keys), 'rows','stable');
    AvgTerminalOverall = AvgTerminalOverall(ia,:);
else
    AvgTerminalOverall = cell2table(cell(0,numel(keys)+1), ...
        'VariableNames',[keys,{'Avg_Terminal_Overall_Score'}]);
end

if exist('AvgTimeEfficiencyOverall','var') && ~isempty(AvgTimeEfficiencyOverall)
    [~, ia] = unique(AvgTimeEfficiencyOverall(:,keys), 'rows','stable');
    AvgTimeEfficiencyOverall = AvgTimeEfficiencyOverall(ia,:);
else
    AvgTimeEfficiencyOverall = cell2table(cell(0,numel(keys)+1), ...
        'VariableNames',[keys,{'Avg_Time_Efficiency_Score'}]);
end

if exist('S_sam','var') && ~isempty(S_sam)
    [~, ia] = unique(S_sam(:,keys), 'rows','stable');
    S_sam = S_sam(ia,:);
else
    S_sam = cell2table(cell(0,numel(keys)+1), ...
        'VariableNames',[keys,{'SAM_Subtask_Overall_Score'}]);
end

if exist('ScenarioWide','var') && ~isempty(ScenarioWide)
    [~, ia] = unique(ScenarioWide(:,keys), 'rows','stable');
    ScenarioWide = ScenarioWide(ia,:);
else
    ScenarioWide = cell2table(cell(0,numel(keys)+1), ...
        'VariableNames',[keys,{'Scenario_Wide_Overall_Score'}]);
end

allKeys = vertcat(AvgTerminalOverall(:,keys), AvgTimeEfficiencyOverall(:,keys), ...
                  S_sam(:,keys), ScenarioWide(:,keys));
[~, ia] = unique(allKeys, 'rows','stable');
CfgOverall = allKeys(ia,:);

CfgOverall = outerjoin(CfgOverall, AvgTerminalOverall, ...
    'Keys',keys,'MergeKeys',true,'Type','left');
CfgOverall = outerjoin(CfgOverall, AvgTimeEfficiencyOverall, ...
    'Keys',keys,'MergeKeys',true,'Type','left');
CfgOverall = outerjoin(CfgOverall, S_sam, ...
    'Keys',keys,'MergeKeys',true,'Type','left');
CfgOverall = outerjoin(CfgOverall, ScenarioWide, ...
    'Keys',keys,'MergeKeys',true,'Type','left');

fill1 = @(v) fillmissing(v,'constant',1);
colList = {'Avg_Terminal_Overall_Score','Avg_Time_Efficiency_Score', ...
           'SAM_Subtask_Overall_Score','Scenario_Wide_Overall_Score'};
for c = colList
    if ~ismember(c{1},CfgOverall.Properties.VariableNames)
        CfgOverall.(c{1}) = ones(height(CfgOverall),1);
    else
        CfgOverall.(c{1}) = fill1(CfgOverall.(c{1}));
    end
end

CfgOverall.Configuration_Overall_Score = ...
    CfgOverall.Avg_Terminal_Overall_Score .* ...
    CfgOverall.Avg_Time_Efficiency_Score .* ...
    CfgOverall.SAM_Subtask_Overall_Score .* ...
    CfgOverall.Scenario_Wide_Overall_Score;

writetable(CfgOverall, fullfile(refDir,'Configuration_Overall_byPilot_byConfig.csv'));
fprintf('Saved Configuration_Overall_byPilot_byConfig.csv (%d rows)\n', height(CfgOverall));

makePlotsOverallNamed(CfgOverall,'C','Configuration_Overall_Score','Configuration Overall Score',false);
makePlotsOverallNamed(CfgOverall,'D','Configuration_Overall_Score','Configuration Overall Score',false);

%% ===== FINAL EXPORT (robust keyed lookups; no joins) =====
% Produces:
%   SCORES_Scenario_C_Summary.xlsx
%   SCORES_Scenario_D_Summary.xlsx
% (XLSX files remain in current folder; only CSVs go to Ref_Tables)

cfgOrder = {'HH','HA','AH','AA'};
keys3 = {'Scenario','Configuration','Lead_Pilot'};

% --- helpers ---
normKeys = @(T) local_norm_keys(T, keys3);
mkkey    = @(S,C,P) strcat(string(S), "|", string(C), "|", string(P));
pullcol  = @(R, T, col) local_pull_col(R, T, col);

% 0) REQUIRED base with Overall Score
if ~(exist('CfgOverall','var') && istable(CfgOverall) && ...
      ismember('Configuration_Overall_Score', CfgOverall.Properties.VariableNames))
    warning('CfgOverall.Configuration_Overall_Score missing; skipping export.');
    return;
end
Base = normKeys(CfgOverall(:, [keys3, {'Configuration_Overall_Score'}]));

% 1) Optional sources (normalize keys if present)
T_term   = table();
if exist('TermAvg','var') && istable(TermAvg) && ~isempty(TermAvg)
    T_term = normKeys(TermAvg(:, [keys3, ...
        {'Avg_Distance_Score','Avg_Altitude_Score','Avg_Airspeed_Score','Avg_Heading_Score','Avg_Terminal_Product'}]));
end

T_termOvr = table();
if exist('AvgTerminalOverall','var') && istable(AvgTerminalOverall) && ~isempty(AvgTerminalOverall)
    T_termOvr = normKeys(AvgTerminalOverall(:, [keys3, {'Avg_Terminal_Overall_Score'}]));
end

T_tti = table();
if exist('TTI_Avg','var') && istable(TTI_Avg) && ~isempty(TTI_Avg)
    T_tti = normKeys(TTI_Avg(:, [keys3, {'Avg_TTI_Score'}]));
end

T_ttc = table();
if exist('TTC_Avg','var') && istable(TTC_Avg) && ~isempty(TTC_Avg)
    T_ttc = normKeys(TTC_Avg(:, [keys3, {'Avg_TTC_Score'}]));
end

T_timeEff = table();
if exist('AvgTimeEfficiencyOverall','var') && istable(AvgTimeEfficiencyOverall) && ~isempty(AvgTimeEfficiencyOverall)
    T_timeEff = normKeys(AvgTimeEfficiencyOverall(:, [keys3, {'Avg_Time_Efficiency_Score'}]));
end

T_sam = table();
if exist('S_sam','var') && istable(S_sam) && ~isempty(S_sam)
    keep = intersect([keys3, {'SAM_ID_Proportion_Score','SAM_ID_Time_Score','SAM_Subtask_Overall_Score'}], ...
                     S_sam.Properties.VariableNames);
    T_sam = normKeys(S_sam(:, keep));
end

T_sam_time = table(); % raw seconds, if you want it
if exist('SAM_All','var') && istable(SAM_All) && ~isempty(SAM_All) && ...
   ismember('Avg_SAM_ID_Time_s', SAM_All.Properties.VariableNames)
    T_sam_time = normKeys(SAM_All(:, [keys3, {'Avg_SAM_ID_Time_s'}]));
end

T_alt = table();
if exist('AltAgg','var') && istable(AltAgg) && ~isempty(AltAgg)
    T_alt = normKeys(AltAgg(:, [keys3, {'AltDev_Overall_Score'}]));
end

T_sort = table();
if exist('SortAgg','var') && istable(SortAgg) && ~isempty(SortAgg)
    T_sort = normKeys(SortAgg(:, [keys3, {'Correct_Target_Sort_Score','Pct_Intercepts_Completed_Score'}]));
end

T_comms = table();
if exist('CommsAgg','var') && istable(CommsAgg) && ~isempty(CommsAgg)
    T_comms = normKeys(CommsAgg(:, [keys3, {'Comms_Density_Score'}]));
end

T_sw = table();
if exist('ScenarioWide','var') && istable(ScenarioWide) && ~isempty(ScenarioWide)
    T_sw = normKeys(ScenarioWide(:, [keys3, {'Scenario_Wide_Overall_Score'}]));
end

% 2) Write per-scenario workbooks (XLSX in current folder)
for scn = ["C","D"]
    B = Base(Base.Scenario==scn, :);
    if isempty(B), continue; end
    outXlsx = sprintf('SCORES_Scenario_%s_Summary.xlsx', scn);
    if exist(outXlsx,'file'), delete(outXlsx); end

    for ci = 1:numel(cfgOrder)
        cfg = cfgOrder{ci};
        R = B(B.Configuration==cfg, :);
        if isempty(R)
            headers = [{'Lead_Pilot'}, ...
                       {'Relative Distance (Terminal Conditions)', ...
                        'Relative Altitude (Terminal Conditions)', ...
                        'Closing Velocity (Terminal Conditions)', ...
                        'Heading Crossing Angle (Terminal Conditions)', ...
                        'Terminal Condition', ...
                        'Time to Intercept', ...
                        'Time to Consent', ...
                        'Time Efficiency', ...
                        'Percent SAM ID', ...
                        'Average Time to SAM ID', ...
                        'SAM Identification', ...
                        'Altitude Deviation', ...
                        'Correct Sort', ...
                        'Communication Density', ...
                        'Percent Intercepted', ...
                        'Engagement-Wide Measures', ...
                        'Overall Score'}];
            writetable(cell2table(cell(0,numel(headers)),'VariableNames',headers), outXlsx, 'Sheet', cfg);
            continue;
        end

        out = table();
        out.Lead_Pilot = string(R.Lead_Pilot);

        out.("Relative Distance (Terminal Conditions)")      = pullcol(R, T_term,   'Avg_Distance_Score');
        out.("Relative Altitude (Terminal Conditions)")      = pullcol(R, T_term,   'Avg_Altitude_Score');
        out.("Closing Velocity (Terminal Conditions)")       = pullcol(R, T_term,   'Avg_Airspeed_Score');
        out.("Heading Crossing Angle (Terminal Conditions)") = pullcol(R, T_term,   'Avg_Heading_Score');

        v_termOvr = pullcol(R, T_termOvr, 'Avg_Terminal_Overall_Score');
        v_termPrd = pullcol(R, T_term,    'Avg_Terminal_Product');
        out.("Terminal Condition") = v_termOvr; 
        m = isnan(v_termOvr) & ~isnan(v_termPrd); 
        out.("Terminal Condition")(m) = v_termPrd(m);

        out.("Time to Intercept")  = pullcol(R, T_tti,     'Avg_TTI_Score');
        out.("Time to Consent")    = pullcol(R, T_ttc,     'Avg_TTC_Score');
        out.("Time Efficiency")    = pullcol(R, T_timeEff, 'Avg_Time_Efficiency_Score');

        out.("Percent SAM ID")     = pullcol(R, T_sam,      'SAM_ID_Proportion_Score');

        v_samSec = pullcol(R, T_sam_time, 'Avg_SAM_ID_Time_s');
        if all(isnan(v_samSec))
            v_samSec = pullcol(R, T_sam, 'SAM_ID_Time_Score');
        end
        out.("Average Time to SAM ID") = v_samSec;

        out.("SAM Identification") = pullcol(R, T_sam, 'SAM_Subtask_Overall_Score');
        out.("Altitude Deviation") = pullcol(R, T_alt, 'AltDev_Overall_Score');

        v_sort = pullcol(R, T_sort, 'Correct_Target_Sort_Score');
        out.("Correct Sort") = v_sort;

        out.("Communication Density")   = pullcol(R, T_comms, 'Comms_Density_Score');
        out.("Percent Intercepted")     = pullcol(R, T_sort,  'Pct_Intercepts_Completed_Score');
        out.("Engagement-Wide Measures")= pullcol(R, T_sw,    'Scenario_Wide_Overall_Score');

        out.("Overall Score") = R.Configuration_Overall_Score;

        [~,ord] = sort(lower(string(out.Lead_Pilot)));
        out = out(ord,:);
        writetable(out, outXlsx, 'Sheet', cfg);
    end
    fprintf('Wrote per-config sheets to %s\n', outXlsx);
end
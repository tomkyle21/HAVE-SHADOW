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
% 6) SAM (% ID'd + time to ID)
% 7) Communication density
% 8) Overall intercept (single = per-intercept product)
% 9) Overall intercept (combined across intercepts)
% 10) SAM Subtask Overall (NEW)
% 11) Scenario-Wide Overall (NEW)
% 12) Configuration Overall (Weighted + Lift) (NEW)
% ======================================================================================

%% Input data from excel sheets

clear; clc;

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

fprintf('C scenario: created %d pilot groups.\n', numel(C_pilotNames));
fprintf('D scenario: created %d pilot groups.\n', numel(D_pilotNames));


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
writetable(AltDev,'AltDev_byPilot_byConfig.csv');
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
    'CorrectSort_Scores_byPilot_byScenario_byConfig.csv');
fprintf('Saved CorrectSort_Scores_byPilot_byScenario_byConfig.csv (%d rows)\n', height(CS_Prop_All));

writetable(CS_Prop_All(:,{'Scenario','Configuration','Lead_Pilot','Proportion_CMs_Intercepted','Proportion_Score'}), ...
    'ProportionInterceptsCompleted_byPilot_byScenario_byConfig.csv');
fprintf('Saved ProportionInterceptsCompleted_byPilot_byScenario_byConfig.csv (%d rows)\n', height(CS_Prop_All));

% Plots (like usual)
plotScoreByConfig(CS_Prop_All, 'C', 'Correct_Sort_Score', 'Correct Target Sort (1 = N, 2 = Y)', [0.8 2.2], [1 2], {'N','Y'});
plotScoreByConfig(CS_Prop_All, 'D', 'Correct_Sort_Score', 'Correct Target Sort (1 = N, 2 = Y)', [0.8 2.2], [1 2], {'N','Y'});

plotScoreByConfig(CS_Prop_All, 'C', 'Proportion_Score', 'Percent Intercepts Completed (score = proportion + 1)', [1 2], 1:0.25:2, []);
plotScoreByConfig(CS_Prop_All, 'D', 'Proportion_Score', 'Percent Intercepts Completed (score = proportion + 1)', [1 2], 1:0.25:2, []);

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
    writetable(TermAll, 'TerminalScores_AllIntercepts_byPilot_byConfig.csv');
    fprintf('Saved TerminalScores_AllIntercepts_byPilot_byConfig.csv (%d rows)\n', height(TermAll));

    % Plots per scenario (scatter-only)
    makePlotsTerminal(TermAll(TermAll.Scenario=="C",:), 'C');
    makePlotsTerminal(TermAll(TermAll.Scenario=="D",:), 'D');
end

% % ORIGINAL FOR SINGLE INTERCEPT!!
% %% ===== Terminal condition error: build tables + simple plots (no normalization) =====
% % Exact headers expected (must exist in each sheet we use):
% % CM1_Distance_from_CM_at_Intercept_nm
% % CM1_Altitude_Offset_at_Intercept_ft
% % CM1_Airspeed_Diff_at_Intercept_kt
% % CM1_Heading_Diff_at_Intercept_deg
% 
% % Build long tables from C & D
% C_term = grabTerminal(c_allData,'C');   % uses sheet name as Configuration
% D_term = grabTerminal(d_allData,'D');
% TermAll = [C_term; D_term];
% 
% % Save raw + scores table
% writetable(TermAll, 'TerminalScores_byPilot_byConfig.csv');
% fprintf('Saved TerminalScores_byPilot_byConfig.csv (%d rows)\n', height(TermAll));
% 
% % Plots per scenario
% makePlotsTerminal(TermAll(TermAll.Scenario=="C",:), 'C');
% makePlotsTerminal(TermAll(TermAll.Scenario=="D",:), 'D');

%% ===== TTI (exponential with two-point tuning) =====
intsC = 1:5;  intsD = 1:8;

% Choose anchors:
%  - 25th percentile -> score ~1.90 (not pegged at 2)
%  - 75th percentile -> score ~1.15 (push meaningful mass below ~1.3)
% Tunings that de-peg the top and keep good spread
useLog  = false;   % recommended for long tails
basePct = 0.01;   % 5th percentile as "near-best" baseline

q1 = 0.25;  s1 = 1.7;   % 25th percentile maps to ~1.75  (reduces ceiling clump)
q2 = 0.65;  s2 = 1.25;   % 70th percentile maps to ~1.25  (pushes mid downward)

intsC = 1:5; 
intsD = 1:8;

varTemplate_TTI = 'CM%d_MOP_Time_to_Intercept_s';

[b_t, tau_t] = fitExpTwoPointBaseQuantile( ...
    c_allData, d_allData, intsC, intsD, varTemplate_TTI, ...
    q1, s1, q2, s2, basePct, useLog);

C_tti = buildTTI_exp_twoPoint(c_allData, 'C', intsC, b_t, tau_t, useLog);
D_tti = buildTTI_exp_twoPoint(d_allData, 'D', intsD, b_t, tau_t, useLog);
TTI_All = [C_tti; D_tti];% Fit on CM1..CM5 for C and CM1..CM8 for D (adjust if your data differ)

% (Optional) tiny soft ceiling just for plotting:
% epsTop = 0.03; TTI_All.TTI_Score = 1 + (1 - epsTop) * (TTI_All.TTI_Score - 1);
% Save (headers + values)
if ~isempty(TTI_All)
    writecell([TTI_All.Properties.VariableNames; table2cell(TTI_All)], ...
        'TTI_Scores_AllIntercepts_byPilot_byConfig.csv');
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

useLog  = false;         % log1p compresses tail; set false to disable
basePct = 0.01;         % <-- 5th percentile as the "near-best" baseline (tweak 0.03–0.08)

% Keep your anchors the same:
q1 = 0.20;  s1 = 1.7;   % upper anchor: 20th pct -> ~1.7
q2 = 0.70;  s2 = 1.35;   % lower anchor: 70th pct -> ~1.3

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
        'TTC_Scores_AllIntercepts_byPilot_byConfig.csv');
    fprintf('Saved TTC_Scores_AllIntercepts_byPilot_byConfig.csv (%d rows)\n', height(TTC_All));
else
    warning('No TTC rows built — nothing to save.');
end

% Plots (same style as others)
if ~isempty(C_ttc), makePlotsConsent(C_ttc,'C'); end
if ~isempty(D_ttc), makePlotsConsent(D_ttc,'D'); end

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
    writetable(SAM_All, 'SAM_ID_Scores_byPilot_byConfig.csv');
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
%
% Scoring: fewer comms = better (higher score); more comms = lower score.
% Uses exponential two-point tuning like TTI/TTC.

% --- Fit params globally across C & D ---
useLog = false;            % counts usually don't need log; set true if tail is huge
q1 = 0.20;  s1 = 1.85;     % 20th pct ≈ 1.85  (reduces pile-up at 2)
q2 = 0.70;  s2 = 1.25;     % 70th pct ≈ 1.25  (pushes middle upward)
[b_comms, tau_comms] = computeCommsExpParamsTwoPoint(c_allData, d_allData, q1, s1, q2, s2, useLog);

% --- Build per-scenario tables with scores ---
C_comms = buildComms_exp_twoPoint(c_allData, 'C', b_comms, tau_comms, useLog);
D_comms = buildComms_exp_twoPoint(d_allData, 'D', b_comms, tau_comms, useLog);
Comms_All = [C_comms; D_comms];

% Save audit CSV
if ~isempty(Comms_All)
    writetable(Comms_All, 'Comms_Density_Scores_byPilot_byConfig.csv');
    fprintf('Saved Comms_Density_Scores_byPilot_byConfig.csv (%d rows)\n', height(Comms_All));
else
    warning('No Comms rows built — nothing to save.');
end

% Plots (scatter, no averaging)
if ~isempty(C_comms), makePlotsComms(C_comms,'C'); end
if ~isempty(D_comms), makePlotsComms(D_comms,'D'); end


%% ===== Combined Intercept Score (Product, with audit + completion flag) =====
% Requires:
%   TermAll : Distance_Score, Altitude_Score, Airspeed_Score, Heading_Score
%   TTI_All : TTI_Score
%   TTC_All : Consent_Score

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

    % --- Pull rows for this key ---
    tTerm = TermAll(TermAll.Scenario==scn & TermAll.Configuration==cfg & ...
                    TermAll.Lead_Pilot==plyt & TermAll.Intercept_Num==intN, :);

    tTTI  = TTI_All( TTI_All.Scenario==scn  & TTI_All.Configuration==cfg  & ...
                     TTI_All.Lead_Pilot==plyt & TTI_All.Intercept_Num==intN, :);

    tTTC  = TTC_All( TTC_All.Scenario==scn  & TTC_All.Configuration==cfg  & ...
                     TTC_All.Lead_Pilot==plyt & TTC_All.Intercept_Num==intN, :);

    hasTerm = ~isempty(tTerm);
    hasTTI  = ~isempty(tTTI);
    hasTTC  = ~isempty(tTTC);

    % Terminal subscores
    if hasTerm
        d  = tTerm.Distance_Score(1);
        a  = tTerm.Altitude_Score(1);
        sp = tTerm.Airspeed_Score(1);
        h  = tTerm.Heading_Score(1);
    else
        d = NaN; a = NaN; sp = NaN; h = NaN;
    end

    % TTI / TTC subscores
    if hasTTI
        tti = tTTI.TTI_Score(1);
    else
        tti = NaN;
    end
    if hasTTC
        ttc = tTTC.Consent_Score(1);
    else
        ttc = NaN;
    end

    % Completion check: all groups present and all six finite
    termVec = [d a sp h];
    isTermValid = all(isfinite(termVec));
    isTTIValid  = isfinite(tti);
    isTTCValid  = isfinite(ttc);
    isCompleted = hasTerm && hasTTI && hasTTC && isTermValid && isTTIValid && isTTCValid;

    if ~isCompleted
        % Incomplete → all subscores = 1, overall = 1
        d = 1; a = 1; sp = 1; h = 1; tti = 1; ttc = 1;
        CombinedScores.Completed_Flag(i) = 0;
    else
        % Completed → clamp to [1,2]
        d   = clamp12(d);
        a   = clamp12(a);
        sp  = clamp12(sp);
        h   = clamp12(h);
        tti = clamp12(tti);
        ttc = clamp12(ttc);
        CombinedScores.Completed_Flag(i) = 1;
    end

    % Save subscores
    CombinedScores.Distance_Score(i) = d;
    CombinedScores.Altitude_Score(i) = a;
    CombinedScores.Airspeed_Score(i) = sp;
    CombinedScores.Heading_Score(i)  = h;
    CombinedScores.TTI_Score(i)      = tti;
    CombinedScores.Consent_Score(i)  = ttc;

    % Overall product
    CombinedScores.Intercept_Combined_Score(i) = d * a * sp * h * tti * ttc;
end

% Save CSV
writetable(CombinedScores, 'InterceptCombinedScores_byPilot_byConfig.csv');
fprintf('Saved InterceptCombinedScores_byPilot_byConfig.csv (%d rows)\n', height(CombinedScores));

% === Combined-score plots: one figure per config, per scenario ===
makePlotsCombined(CombinedScores, 'C');
makePlotsCombined(CombinedScores, 'D');

% === Overall Scenario/Config Score (product across intercepts, with audit & checks) ===
% Uses CombinedScores built earlier:
% Required columns in CombinedScores:
%   Scenario, Configuration, Lead_Pilot, Intercept_Num, Intercept_Combined_Score

% 1) Fill incomplete intercepts with score = 1 (your rule)
scores = CombinedScores.Intercept_Combined_Score;
scores(~isfinite(scores)) = 1;

% 2) Group by Pilot–Scenario–Configuration
[grp, gpPilot, gpScenario, gpConfig] = findgroups( ...
    CombinedScores.Lead_Pilot, ...
    CombinedScores.Scenario, ...
    CombinedScores.Configuration);

nGroups = max(grp);
overallProd       = nan(nGroups,1);
detailStrings     = strings(nGroups,1);
interceptsIncluded = strings(nGroups,1);   % e.g. "[1, 2, 3, 4, 5, 6, 7, 8]"
numIntercepts     = zeros(nGroups,1);

for g = 1:nGroups
    idx = (grp == g);
    vals = scores(idx);
    cms  = CombinedScores.Intercept_Num(idx);     % which intercept numbers were present

    % Sort by Intercept_Num for readability
    [cms, order] = sort(cms);
    vals = vals(order);

    % Product across all intercepts present for this Pilot–Scenario–Config
    overallProd(g) = prod(vals);

    % Build labeled factor string, e.g. "CM1=1.523 * CM2=1.943 * ..."
    parts = compose("CM%d=%.3f", cms, vals);
    detailStrings(g) = strjoin(parts, " * ");

    % Save audit info
    numIntercepts(g) = numel(cms);
    interceptsIncluded(g) = "[" + strjoin(string(cms), ", ") + "]";
end

% 3) Build result table and save CSV
OverallScores = table(gpPilot, gpScenario, gpConfig, overallProd, numIntercepts, interceptsIncluded, detailStrings, ...
    'VariableNames', {'Lead_Pilot','Scenario','Configuration','Overall_Intercept_Score','N_Intercepts','Intercepts_Included','Intercept_Score_Factors'});

writetable(OverallScores, 'OverallInterceptScore_withAudit_byPilot_byScenario_byConfig.csv');
fprintf('Saved OverallInterceptScore_withAudit_byPilot_byScenario_byConfig.csv (%d rows)\n', height(OverallScores));

% 4) Quick integrity checks & warnings
%   - What Intercept_Num exist per Scenario?
scnList = unique(CombinedScores.Scenario);
for s = 1:numel(scnList)
    scn = scnList(s);
    cmsAll = unique(CombinedScores.Intercept_Num(CombinedScores.Scenario==scn));
    fprintf('Scenario %s has intercept numbers present: %s\n', string(scn), mat2str(cmsAll(:).'));
end

%   - Scenario D: warn if we are missing any of 6..8 anywhere
if any(CombinedScores.Scenario=="D")
    cmsD = unique(CombinedScores.Intercept_Num(CombinedScores.Scenario=="D"));
    missingD = setdiff(6:8, cmsD);
    if ~isempty(missingD)
        warning('Scenario D is missing intercept(s) CM%s in CombinedScores. Upstream generators may be dropping these.', mat2str(missingD));
    end
end

%% === Plot Overall Scores by Configuration (scatter), one figure per scenario ===
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

%% ===== A) SAM Subtask Overall (raw product per pilot/config) =====
% Needs: SAM_All with columns SAM_ID_Time_Score, SAM_ID_Proportion_Score, Scenario, Configuration, Lead_Pilot
if exist('SAM_All','var') && ~isempty(SAM_All)
    T = SAM_All;
    T.Row_SAM_Subtask = T.SAM_ID_Time_Score .* T.SAM_ID_Proportion_Score;

    % Keep only needed cols, then take first row per key (raw per pilot/config)
    keepVars = {'Scenario','Configuration','Lead_Pilot', ...
                'SAM_ID_Time_Score','SAM_ID_Proportion_Score','Row_SAM_Subtask'};
    T = T(:, keepVars);
    [~, ia] = unique(T(:, {'Scenario','Configuration','Lead_Pilot'}), 'rows', 'stable');
    S_sam = T(ia, :);
    S_sam.Properties.VariableNames{'Row_SAM_Subtask'} = 'SAM_Subtask_Overall_Score';

    writetable(S_sam, 'SAM_Subtask_Overall_byPilot_byConfig.csv');
    fprintf('Saved SAM_Subtask_Overall_byPilot_byConfig.csv (%d rows)\n', height(S_sam));

    makePlotsOverallNamed(S_sam,'C','SAM_Subtask_Overall_Score','SAM Subtask Overall');
    makePlotsOverallNamed(S_sam,'D','SAM_Subtask_Overall_Score','SAM Subtask Overall');
else
    warning('SAM_All not found or empty; skipping SAM subtask overall.');
    S_sam = table();
end

%% ===== B) Scenario-Wide Overall (per pilot/config, robust to missing pieces) =====
% Scenario_Wide_Overall_Score =
%   AltDev_Overall_Score * Correct_Target_Sort_Score * Pct_Intercepts_Completed_Score * Comms_Density_Score

% --- Build each component (raw per pilot/config) ---

% AltDev overall from AltDev (Integrated_Score * Count_Score)
AltAgg = table();
if exist('AltDev','var') && ~isempty(AltDev)
    A = AltDev;
    A.Row_AltDev_Overall = A.Integrated_Score .* A.Count_Score;
    A = A(:, {'Scenario','Configuration','Lead_Pilot','Row_AltDev_Overall'});
    [~, ia] = unique(A(:, {'Scenario','Configuration','Lead_Pilot'}), 'rows', 'stable');
    AltAgg = A(ia, :);
    AltAgg.Properties.VariableNames{'Row_AltDev_Overall'} = 'AltDev_Overall_Score';
end

% Sort / Completion from Sort_All (score columns in [1,2]); may be absent
SortAgg = table();
if exist('Sort_All','var') && ~isempty(Sort_All)
    Srt = Sort_All;

    % Correct target sort -> score in [1,2]
    if ismember('Correct_Target_Sort_Score', Srt.Properties.VariableNames)
        Srt.Correct_Target_Sort_Score = min(max(Srt.Correct_Target_Sort_Score,1),2);
    elseif ismember('Correct_Target_Sort', Srt.Properties.VariableNames)
        Srt.Correct_Target_Sort_Score = min(max(1 + toNum(Srt.Correct_Target_Sort),1),2);
    else
        Srt.Correct_Target_Sort_Score = ones(height(Srt),1);
        warning('Sort_All missing Correct Target Sort — defaulted to score=1.');
    end

    % % intercepts completed -> score in [1,2]
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

% Comms density from Comms_All (score in [1,2]); may be absent
CommsAgg = table();
if exist('Comms_All','var') && ~isempty(Comms_All)
    Cc = Comms_All(:, {'Scenario','Configuration','Lead_Pilot','Comms_Density_Score'});
    [~, ia] = unique(Cc(:, {'Scenario','Configuration','Lead_Pilot'}), 'rows', 'stable');
    CommsAgg = Cc(ia, :);
end

% --- Establish a base key set from whatever exists ---
keysVars = {'Scenario','Configuration','Lead_Pilot'};
baseKeys = table();

candidates = {};
if ~isempty(AltAgg),   candidates{end+1} = AltAgg(:, keysVars); end 
if ~isempty(SortAgg),  candidates{end+1} = SortAgg(:, keysVars); end 
if ~isempty(CommsAgg), candidates{end+1} = CommsAgg(:, keysVars); end 
if isempty(candidates)
    % fallbacks if all three components are missing
    if exist('CombinedScores','var') && ~isempty(CombinedScores)
        candidates{end+1} = unique(CombinedScores(:, keysVars)); 
    elseif exist('SAM_All','var') && ~isempty(SAM_All)
        candidates{end+1} = unique(SAM_All(:, keysVars)); 
    else
        warning('No source tables to build Scenario-Wide keys; skipping Scenario-Wide overall.');
        ScenarioWide = table();  % nothing to do
    end
end

if ~exist('ScenarioWide','var') || isempty(ScenarioWide)
    % unify candidates
    allKeys = vertcat(candidates{:});
    [~, ia] = unique(allKeys, 'rows', 'stable');
    baseKeys = allKeys(ia, :);
end

% If still empty, bail out gracefully
if isempty(baseKeys)
    ScenarioWide = table();  % no rows
else
    % --- Assemble ScenarioWide table with defaults of 1 for missing components ---
    ScenarioWide = baseKeys;
    % AltDev
    if ~isempty(AltAgg)
        ScenarioWide = outerjoin(ScenarioWide, AltAgg, ...
            'Keys', keysVars, 'MergeKeys', true, 'Type','left');
    else
        ScenarioWide.AltDev_Overall_Score = ones(height(ScenarioWide),1);
    end
    if ~ismember('AltDev_Overall_Score', ScenarioWide.Properties.VariableNames)
        ScenarioWide.AltDev_Overall_Score = ones(height(ScenarioWide),1);
    end

    % Sort / % Completed
    if ~isempty(SortAgg)
        ScenarioWide = outerjoin(ScenarioWide, SortAgg, ...
            'Keys', keysVars, 'MergeKeys', true, 'Type','left');
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

    % Comms
    if ~isempty(CommsAgg)
        ScenarioWide = outerjoin(ScenarioWide, CommsAgg, ...
            'Keys', keysVars, 'MergeKeys', true, 'Type','left');
    else
        ScenarioWide.Comms_Density_Score = ones(height(ScenarioWide),1);
    end
    if ~ismember('Comms_Density_Score', ScenarioWide.Properties.VariableNames)
        ScenarioWide.Comms_Density_Score = ones(height(ScenarioWide),1);
    end

    % Fill any residual NaNs with 1 (neutral)
    ScenarioWide.AltDev_Overall_Score            = fillmissing(ScenarioWide.AltDev_Overall_Score, 'constant', 1);
    ScenarioWide.Correct_Target_Sort_Score       = fillmissing(ScenarioWide.Correct_Target_Sort_Score, 'constant', 1);
    ScenarioWide.Pct_Intercepts_Completed_Score  = fillmissing(ScenarioWide.Pct_Intercepts_Completed_Score, 'constant', 1);
    ScenarioWide.Comms_Density_Score             = fillmissing(ScenarioWide.Comms_Density_Score, 'constant', 1);

    % Final product
    ScenarioWide.Scenario_Wide_Overall_Score = ...
        ScenarioWide.AltDev_Overall_Score .* ...
        ScenarioWide.Correct_Target_Sort_Score .* ...
        ScenarioWide.Pct_Intercepts_Completed_Score .* ...
        ScenarioWide.Comms_Density_Score;

    % Save + plots
    writetable(ScenarioWide, 'ScenarioWide_Overall_byPilot_byConfig.csv');
    fprintf('Saved ScenarioWide_Overall_byPilot_byConfig.csv (%d rows)\n', height(ScenarioWide));

    makePlotsOverallNamed(ScenarioWide,'C','Scenario_Wide_Overall_Score','Scenario-Wide Overall');
    makePlotsOverallNamed(ScenarioWide,'D','Scenario_Wide_Overall_Score','Scenario-Wide Overall');
end

%% ===== C) Configuration Overall (per pilot/config, WEIGHTED) =====
% = (Overall Intercept Product)^w_int
%   * (SAM Subtask Overall)^w_sam
%   * (Scenario-Wide Overall)^w_scen
% Choose w_scen > others to emphasize Scenario-Wide.

% --- Build Overall Intercept (combined across intercepts) if needed (product across intercepts) ---
if ~exist('G','var') || isempty(G)
    if exist('CombinedScores','var') && ~isempty(CombinedScores)
        keys = {'Scenario','Configuration','Lead_Pilot'};
        [Gkeys, ~, idx] = unique(CombinedScores(:,keys), 'rows','stable');
        prodVals = accumarray(idx, CombinedScores.Intercept_Combined_Score, [], @prod);
        G = Gkeys;
        G.Overall_Intercept_Product = prodVals;
    else
        warning('CombinedScores missing; cannot compute Overall Intercept Product.');
        G = table();
    end
end

% --- Dedup inputs we're joining ---
if exist('S_sam','var') && ~isempty(S_sam)
    [~, ia] = unique(S_sam(:, {'Scenario','Configuration','Lead_Pilot'}), 'rows', 'stable');
    S_sam = S_sam(ia,:);
end
if exist('ScenarioWide','var') && ~isempty(ScenarioWide)
    [~, ia] = unique(ScenarioWide(:, {'Scenario','Configuration','Lead_Pilot'}), 'rows', 'stable');
    ScenarioWide = ScenarioWide(ia,:);
end

% --- Join components ---
CfgOverall = G;
if exist('S_sam','var') && ~isempty(S_sam)
    CfgOverall = outerjoin(CfgOverall, S_sam, ...
        'Keys',{'Scenario','Configuration','Lead_Pilot'}, 'MergeKeys',true, 'Type','left');
end
if exist('ScenarioWide','var') && ~isempty(ScenarioWide)
    CfgOverall = outerjoin(CfgOverall, ScenarioWide, ...
        'Keys',{'Scenario','Configuration','Lead_Pilot'}, 'MergeKeys',true, 'Type','left');
end

% --- Ensure required columns exist; fill missing with neutral 1s ---
fill1 = @(v) fillmissing(v,'constant',1);

if ~ismember('Overall_Intercept_Product', CfgOverall.Properties.VariableNames)
    CfgOverall.Overall_Intercept_Product = 1;
end
if ~ismember('SAM_Subtask_Overall_Score', CfgOverall.Properties.VariableNames)
    CfgOverall.SAM_Subtask_Overall_Score = 1;
end
if ~ismember('Scenario_Wide_Overall_Score', CfgOverall.Properties.VariableNames)
    CfgOverall.Scenario_Wide_Overall_Score = 1;
end

CfgOverall.Overall_Intercept_Product    = fill1(CfgOverall.Overall_Intercept_Product);
CfgOverall.SAM_Subtask_Overall_Score    = fill1(CfgOverall.SAM_Subtask_Overall_Score);
CfgOverall.Scenario_Wide_Overall_Score  = fill1(CfgOverall.Scenario_Wide_Overall_Score);

% --- Weights (tune here). Put more weight on Scenario-Wide. ---
w_int  = 2.0;   % Overall Intercept (combined across intercepts)
w_sam  = 1.0;   % SAM Subtask Overall
w_scen = 3.0;   % Scenario-Wide Overall  (heavier)

% --- Log-lift to expand low-end spread for each component (keeps [1,2]) ---
loglift = @(s,k) 1 + log1p(k * max(0, s - 1)) ./ log1p(k);  % s in [1,2] -> [1,2]
k_lift  = 5;   % spread knob: 3..10 are reasonable; higher => more separation near 1

I = loglift(CfgOverall.Overall_Intercept_Product,   k_lift);
S = loglift(CfgOverall.SAM_Subtask_Overall_Score,   k_lift);
W = loglift(CfgOverall.Scenario_Wide_Overall_Score, k_lift);

% --- Unweighted (for audit) and Weighted products (after lift) ---
CfgOverall.Configuration_Overall_Score_Unweighted = ...
    CfgOverall.Overall_Intercept_Product .* ...
    CfgOverall.SAM_Subtask_Overall_Score .* ...
    CfgOverall.Scenario_Wide_Overall_Score;

CfgOverall.Configuration_Overall_Score = ...
    (I .^ w_int) .* (S .^ w_sam) .* (W .^ w_scen);

% --- Save + plots (plot the weighted score) ---
writetable(CfgOverall, 'Configuration_Overall_byPilot_byConfig.csv');
fprintf('Saved Configuration_Overall_byPilot_byConfig.csv (%d rows)\n', height(CfgOverall));

makePlotsOverallNamed(CfgOverall,'C','Configuration_Overall_Score','Configuration Overall (Weighted + Lift)');
makePlotsOverallNamed(CfgOverall,'D','Configuration_Overall_Score','Configuration Overall (Weighted + Lift)');


% %% ===== C) Configuration Overall (per pilot/config) =====
% % = Overall Intercept (combined across intercepts) * SAM Subtask Overall * Scenario-Wide Overall
% 
% % Overall Intercept (combined across intercepts) — build if not already present
% if ~exist('G','var') || isempty(G)
%     if exist('CombinedScores','var') && ~isempty(CombinedScores)
%         keys = {'Scenario','Configuration','Lead_Pilot'};
%         % group by keys
%         [Gkeys, ~, idx] = unique(CombinedScores(:,keys), 'rows','stable');
%         prodVals = accumarray(idx, CombinedScores.Intercept_Combined_Score, [], @prod);
%         G = Gkeys;
%         G.Overall_Intercept_Product = prodVals;
%     else
%         warning('CombinedScores missing; cannot compute Overall Intercept Product.');
%         G = table();
%     end
% end
% 
% % Join the three components (dedup any accidental mult-rows first)
% if exist('S_sam','var') && ~isempty(S_sam)
%     [~, ia] = unique(S_sam(:, {'Scenario','Configuration','Lead_Pilot'}), 'rows', 'stable');
%     S_sam = S_sam(ia,:);
% end
% if exist('ScenarioWide','var') && ~isempty(ScenarioWide)
%     [~, ia] = unique(ScenarioWide(:, {'Scenario','Configuration','Lead_Pilot'}), 'rows', 'stable');
%     ScenarioWide = ScenarioWide(ia,:);
% end
% 
% CfgOverall = outerjoin(G, S_sam,       'Keys',{'Scenario','Configuration','Lead_Pilot'}, 'MergeKeys',true);
% CfgOverall = outerjoin(CfgOverall, ScenarioWide, 'Keys',{'Scenario','Configuration','Lead_Pilot'}, 'MergeKeys',true);
% 
% % Fill missing components with 1 (neutral)
% fill1 = @(v) fillmissing(v,'constant',1);
% if ~ismember('Overall_Intercept_Product', CfgOverall.Properties.VariableNames), CfgOverall.Overall_Intercept_Product = 1; end
% if ~ismember('SAM_Subtask_Overall_Score', CfgOverall.Properties.VariableNames), CfgOverall.SAM_Subtask_Overall_Score = 1; end
% if ~ismember('Scenario_Wide_Overall_Score', CfgOverall.Properties.VariableNames), CfgOverall.Scenario_Wide_Overall_Score = 1; end
% 
% CfgOverall.Overall_Intercept_Product  = fill1(CfgOverall.Overall_Intercept_Product);
% CfgOverall.SAM_Subtask_Overall_Score  = fill1(CfgOverall.SAM_Subtask_Overall_Score);
% CfgOverall.Scenario_Wide_Overall_Score= fill1(CfgOverall.Scenario_Wide_Overall_Score);
% 
% % Final product
% CfgOverall.Configuration_Overall_Score = ...
%     CfgOverall.Overall_Intercept_Product .* ...
%     CfgOverall.SAM_Subtask_Overall_Score .* ...
%     CfgOverall.Scenario_Wide_Overall_Score;
% 
% writetable(CfgOverall, 'Configuration_Overall_byPilot_byConfig.csv');
% fprintf('Saved Configuration_Overall_byPilot_byConfig.csv (%d rows)\n', height(CfgOverall));
% 
% makePlotsOverallNamed(CfgOverall,'C','Configuration_Overall_Score','Configuration Overall');
% makePlotsOverallNamed(CfgOverall,'D','Configuration_Overall_Score','Configuration Overall');
% 
%% ===================== DEBUG: PLOT ALL OVERALLS AT ONCE =====================
% Requires the plotting helpers on path:
%   - makePlotsCombined(T, scenarioLabel, useLift)
%   - makePlotsOverallNamed(T, scenarioLabel, scoreVar, titleSuffix, useLift)
%
% And (optionally) these tables if you built them earlier:
%   CombinedScores  : Intercept-level combined subscores/products
%   G               : Overall Intercept Product across intercepts
%   OverallScores   : Alternate overall intercept table (if you used it)
%   S_sam           : SAM Subtask overall per pilot/config
%   ScenarioWide    : Scenario-wide overall per pilot/config
%   CfgOverall      : Configuration overall per pilot/config (weighted)

fprintf('\n=== DEBUG: Creating all overall plots ===\n');

% Choose whether to apply plotting "lift" (spread near 1..2). For overall products,
% it's usually best to see raw values (can exceed 2), so default = false.
useLiftOverall = false;

% Helper to check table existence and a given column
hasTbl = @(name) evalin('base', sprintf('exist(''%s'',''var'') && ~isempty(%s)', name,name));
hasCol = @(name,col) evalin('base', sprintf('ismember(''%s'', %s.Properties.VariableNames)', col, name));

% Scenarios to render
scenarios = {'C','D'};


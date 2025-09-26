%% ================= DEBUG B (Scenario C): ALL-PILOTS SCATTER + BOX =================
fprintf('\n=== DEBUG B (C): All-pilots scatter for component scores (with boxplots) ===\n');

cfgOrder = {'HH','HA','AH','AA'};
yL = [1 2];   % component scores live in [1,2]

% ---------- 1) ALTITUDE DEVIATION ----------
if exist('AltDev','var') && istable(AltDev) && any(AltDev.Scenario=="C")
    T = AltDev(AltDev.Scenario=="C",:);
    doAllPilotsScatterBox_C(T, cfgOrder, 'Integrated_Score', 'C – All Pilots: AltDev Integrated Score', 'Integrated Score', yL);
    doAllPilotsScatterBox_C(T, cfgOrder, 'Count_Score',      'C – All Pilots: AltDev Count Score',      'Count Score',      yL);
else
    warning('AltDev missing/empty for Scenario C.');
end

% ---------- 2) CORRECT TARGET SORT + %% INTERCEPTS COMPLETED ----------
T = table();
if exist('CS_Prop_All','var') && istable(CS_Prop_All) && any(CS_Prop_All.Scenario=="C")
    T = CS_Prop_All(CS_Prop_All.Scenario=="C",:);
elseif exist('Sort_All','var') && istable(Sort_All) && any(Sort_All.Scenario=="C")
    T = Sort_All(Sort_All.Scenario=="C",:);
end
if ~isempty(T)
    if ismember('Correct_Sort_Score', T.Properties.VariableNames)
        colSort = 'Correct_Sort_Score';
    else
        colSort = 'Correct_Target_Sort_Score';
    end
    if ismember('Proportion_Score', T.Properties.VariableNames)
        colProp = 'Proportion_Score';
    else
        colProp = 'Pct_Intercepts_Completed_Score';
    end
    doAllPilotsScatterBox_C(T, cfgOrder, colSort, 'C – All Pilots: Correct Target Sort (score)', 'Correct Sort',     yL);
    doAllPilotsScatterBox_C(T, cfgOrder, colProp, 'C – All Pilots: Percent Intercepts Completed (score)', 'Percent Completed', yL);
else
    warning('Correct Sort / %% Completed missing/empty for Scenario C.');
end

% ---------- 3) TERMINAL CONDITION ----------
if exist('TermAll','var') && istable(TermAll) && any(TermAll.Scenario=="C")
    T = TermAll(TermAll.Scenario=="C",:);
    doAllPilotsScatterBox_C(T, cfgOrder, 'Distance_Score', 'C – All Pilots: Terminal Distance Score', 'Score', yL);
    doAllPilotsScatterBox_C(T, cfgOrder, 'Altitude_Score', 'C – All Pilots: Terminal Altitude Score', 'Score', yL);
    doAllPilotsScatterBox_C(T, cfgOrder, 'Airspeed_Score', 'C – All Pilots: Terminal Airspeed Score', 'Score', yL);
    doAllPilotsScatterBox_C(T, cfgOrder, 'Heading_Score',  'C – All Pilots: Terminal Heading Score',  'Score', yL);
else
    warning('TermAll missing/empty for Scenario C.');
end

% ---------- 4) TTI ----------
if exist('TTI_All','var') && istable(TTI_All) && any(TTI_All.Scenario=="C")
    T = TTI_All(TTI_All.Scenario=="C",:);
    doAllPilotsScatterBox_C(T, cfgOrder, 'TTI_Score', 'C – All Pilots: TTI Score', 'TTI Score', yL);
else
    warning('TTI_All missing/empty for Scenario C.');
end

% ---------- 5) TTC ----------
if exist('TTC_All','var') && istable(TTC_All) && any(TTC_All.Scenario=="C")
    T = TTC_All(TTC_All.Scenario=="C",:);
    doAllPilotsScatterBox_C(T, cfgOrder, 'Consent_Score', 'C – All Pilots: TTC (Consent) Score', 'TTC Score', yL);
else
    warning('TTC_All missing/empty for Scenario C.');
end

% ---------- 6) SAM ----------
if exist('SAM_All','var') && istable(SAM_All) && any(SAM_All.Scenario=="C")
    T = SAM_All(SAM_All.Scenario=="C",:);
    doAllPilotsScatterBox_C(T, cfgOrder, 'SAM_ID_Proportion_Score', 'C – All Pilots: SAM %% ID''d Score', '%% ID''d Score', yL);
    doAllPilotsScatterBox_C(T, cfgOrder, 'SAM_ID_Time_Score',       'C – All Pilots: SAM Time-to-ID Score', 'Time Score', yL);
else
    warning('SAM_All missing/empty for Scenario C.');
end

% ---------- 7) COMMS ----------
if exist('Comms_All','var') && istable(Comms_All) && any(Comms_All.Scenario=="C")
    T = Comms_All(Comms_All.Scenario=="C",:);
    doAllPilotsScatterBox_C(T, cfgOrder, 'Comms_Density_Score', 'C – All Pilots: Comms Density Score', 'Comms Score', yL);
else
    warning('Comms_All missing/empty for Scenario C.');
end

fprintf('=== DEBUG B (C): Done ===\n');

% ========================= LOCAL HELPER (with boxplot) =========================
function doAllPilotsScatterBox_C(Tin, cfgOrder, scoreVar, figName, yLab, yLims)
    if isempty(Tin) || ~istable(Tin) || ~ismember(scoreVar, Tin.Properties.VariableNames), return; end
    T = Tin;
    % enforce config order as categorical, then drop undefined
    T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    T = T(~isundefined(T.Configuration),:);
    if isempty(T), return; end

    xnum = double(T.Configuration);    % numeric positions 1..K
    y    = double(T.(scoreVar));
    K    = numel(cfgOrder);

    figure('Name', figName, 'Color','w'); hold on;

    % ---- Box & whisker underlay (one box per config position) ----
    try
        % Use numeric grouping (xnum) and fix positions so boxes align with 1..K
        boxplot(y, xnum, ...
            'Positions', 1:K, ...
            'Symbol','', ...                    % hide outlier markers to reduce clutter
            'Colors',[0.25 0.25 0.25], ...
            'Whisker',1.5, ...
            'PlotStyle','traditional', ...
            'Widths',0.5);
        % prettify
        set(findobj(gca,'Tag','Box'),   'LineWidth',1.0);
        set(findobj(gca,'Tag','Median'),'LineWidth',1.2);
    catch ME
        warning('boxplot failed; continuing with scatter only. (%s)', ME.message);
    end

    % ---- Scatter overlay (all pilots, jittered) ----
    rng(1); jit = (rand(size(xnum)) - 0.5) * 0.25;
    scatter(xnum + jit, y, 32, 'k', 'filled', ...
            'MarkerFaceAlpha', 0.6, 'MarkerEdgeColor','k','LineWidth',0.25);

    % axes & labels
    grid on;
    xlim([0.5, K+0.5]); xticks(1:K); xticklabels(cfgOrder);
    if nargin >= 6 && ~isempty(yLims), ylim(yLims); end
    xlabel('Configuration'); ylabel(yLab); title(figName);
    hold off;
end
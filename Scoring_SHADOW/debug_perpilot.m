%% ================= DEBUG A (Scenario C): PER-PILOT SUBPLOTS =================
fprintf('\n=== DEBUG A (C): Per-pilot subplots for component scores ===\n');

cfgOrder = {'HH','HA','AH','AA'};
yL = [1 2];                     % component scores live in [1,2]
cmapBase = lines(10);           % color bank

% ---------- 1) ALTITUDE DEVIATION ----------
if exist('AltDev','var') && istable(AltDev) && any(AltDev.Scenario=="C")
    T = AltDev(AltDev.Scenario=="C",:);
    T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    T = T(~isundefined(T.Configuration),:);
    pilots = unique(string(T.Lead_Pilot),'stable'); nP = numel(pilots);
    cmap = cmapBase(1:max(nP,1),:); K = numel(cfgOrder);

    % Integrated_Score per pilot
    figure('Name', 'C – AltDev Integrated Score per Pilot', 'Color','w');
    for p = 1:nP
        tp = T(string(T.Lead_Pilot)==pilots(p),:);
        xnum = double(tp.Configuration); rng(1); jit = (rand(size(xnum))-0.5)*0.25;
        subplot(nP,1,p);
        scatter(xnum+jit, tp.Integrated_Score, 32, cmap(p,:), 'filled', 'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k', 'LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yL); xticks(1:K); xticklabels(cfgOrder);
        ylabel('Integrated Score'); title(sprintf('C – %s', pilots(p)));
    end

    % Count_Score per pilot
    figure('Name', 'C – AltDev Count Score per Pilot', 'Color','w');
    for p = 1:nP
        tp = T(string(T.Lead_Pilot)==pilots(p),:);
        xnum = double(tp.Configuration); rng(1); jit = (rand(size(xnum))-0.5)*0.25;
        subplot(nP,1,p);
        scatter(xnum+jit, tp.Count_Score, 32, cmap(p,:), 'filled', 'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k', 'LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yL); xticks(1:K); xticklabels(cfgOrder);
        ylabel('Count Score'); title(sprintf('C – %s', pilots(p)));
    end
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
    T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    T = T(~isundefined(T.Configuration),:);
    pilots = unique(string(T.Lead_Pilot),'stable'); nP = numel(pilots);
    cmap = cmapBase(1:max(nP,1),:); K = numel(cfgOrder);

    % Decide which columns exist
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

    % Correct sort
    figure('Name', 'C – Correct Target Sort per Pilot', 'Color','w');
    for p = 1:nP
        tp = T(string(T.Lead_Pilot)==pilots(p),:);
        xnum = double(tp.Configuration); rng(1); jit = (rand(size(xnum))-0.5)*0.25;
        subplot(nP,1,p);
        scatter(xnum+jit, tp.(colSort), 32, cmap(p,:), 'filled', 'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k', 'LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yL); xticks(1:K); xticklabels(cfgOrder);
        ylabel('Correct Sort'); title(sprintf('C – %s', pilots(p)));
    end

    % Proportion completed
    figure('Name', 'C – % Intercepts Completed per Pilot', 'Color','w');
    for p = 1:nP
        tp = T(string(T.Lead_Pilot)==pilots(p),:);
        xnum = double(tp.Configuration); rng(1); jit = (rand(size(xnum))-0.5)*0.25;
        subplot(nP,1,p);
        scatter(xnum+jit, tp.(colProp), 32, cmap(p,:), 'filled', 'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k', 'LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yL); xticks(1:K); xticklabels(cfgOrder);
        ylabel('% Completed'); title(sprintf('C – %s', pilots(p)));
    end
else
    warning('Correct Sort / %% Completed missing/empty for Scenario C.');
end

% ---------- 3) TERMINAL CONDITION ----------
if exist('TermAll','var') && istable(TermAll) && any(TermAll.Scenario=="C")
    T = TermAll(TermAll.Scenario=="C",:);
    T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    T = T(~isundefined(T.Configuration),:);
    if ~isempty(T)
        pilots = unique(string(T.Lead_Pilot),'stable'); nP = numel(pilots);
        cmap = cmapBase(1:max(nP,1),:); K = numel(cfgOrder);
        cols = {'Distance_Score','Altitude_Score','Airspeed_Score','Heading_Score'};
        labels = {'Terminal – Distance','Terminal – Altitude','Terminal – Airspeed','Terminal – Heading'};
        for c = 1:numel(cols)
            if ~ismember(cols{c}, T.Properties.VariableNames), continue; end
            figure('Name', ['C – ' labels{c} ' per Pilot'], 'Color','w');
            for p = 1:nP
                tp = T(string(T.Lead_Pilot)==pilots(p),:);
                xnum = double(tp.Configuration); rng(1); jit = (rand(size(xnum))-0.5)*0.25;
                subplot(nP,1,p);
                scatter(xnum+jit, tp.(cols{c}), 32, cmap(p,:), 'filled', 'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k', 'LineWidth',0.25);
                grid on; xlim([0.5 K+0.5]); ylim(yL); xticks(1:K); xticklabels(cfgOrder);
                ylabel('Score'); title(sprintf('C – %s', pilots(p)));
            end
        end
    end
else
    warning('TermAll missing/empty for Scenario C.');
end

% ---------- 4) TTI ----------
if exist('TTI_All','var') && istable(TTI_All) && any(TTI_All.Scenario=="C")
    T = TTI_All(TTI_All.Scenario=="C",:);
    T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    T = T(~isundefined(T.Configuration),:);
    pilots = unique(string(T.Lead_Pilot),'stable'); nP = numel(pilots);
    cmap = cmapBase(1:max(nP,1),:); K = numel(cfgOrder);
    figure('Name', 'C – TTI Score per Pilot', 'Color','w');
    for p = 1:nP
        tp = T(string(T.Lead_Pilot)==pilots(p),:);
        xnum = double(tp.Configuration); rng(1); jit = (rand(size(xnum))-0.5)*0.25;
        subplot(nP,1,p);
        scatter(xnum+jit, tp.TTI_Score, 32, cmap(p,:), 'filled', 'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k', 'LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yL); xticks(1:K); xticklabels(cfgOrder);
        ylabel('TTI Score'); title(sprintf('C – %s', pilots(p)));
    end
else
    warning('TTI_All missing/empty for Scenario C.');
end

% ---------- 5) TTC ----------
if exist('TTC_All','var') && istable(TTC_All) && any(TTC_All.Scenario=="C")
    T = TTC_All(TTC_All.Scenario=="C",:);
    T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    T = T(~isundefined(T.Configuration),:);
    pilots = unique(string(T.Lead_Pilot),'stable'); nP = numel(pilots);
    cmap = cmapBase(1:max(nP,1),:); K = numel(cfgOrder);
    figure('Name', 'C – TTC Score per Pilot', 'Color','w');
    for p = 1:nP
        tp = T(string(T.Lead_Pilot)==pilots(p),:);
        xnum = double(tp.Configuration); rng(1); jit = (rand(size(xnum))-0.5)*0.25;
        subplot(nP,1,p);
        scatter(xnum+jit, tp.Consent_Score, 32, cmap(p,:), 'filled', 'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k', 'LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yL); xticks(1:K); xticklabels(cfgOrder);
        ylabel('TTC Score'); title(sprintf('C – %s', pilots(p)));
    end
else
    warning('TTC_All missing/empty for Scenario C.');
end

% ---------- 6) SAM (% ID'd + Time to ID) ----------
if exist('SAM_All','var') && istable(SAM_All) && any(SAM_All.Scenario=="C")
    T = SAM_All(SAM_All.Scenario=="C",:);
    T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    T = T(~isundefined(T.Configuration),:);
    pilots = unique(string(T.Lead_Pilot),'stable'); nP = numel(pilots);
    cmap = cmapBase(1:max(nP,1),:); K = numel(cfgOrder);

    % % ID'd
    figure('Name', 'C – SAM % ID''d Score per Pilot', 'Color','w');
    for p = 1:nP
        tp = T(string(T.Lead_Pilot)==pilots(p),:);
        xnum = double(tp.Configuration); rng(1); jit = (rand(size(xnum))-0.5)*0.25;
        subplot(nP,1,p);
        scatter(xnum+jit, tp.SAM_ID_Proportion_Score, 32, cmap(p,:), 'filled', 'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k', 'LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yL); xticks(1:K); xticklabels(cfgOrder);
        ylabel('% ID''d'); title(sprintf('C – %s', pilots(p)));
    end

    % Time to ID
    figure('Name', 'C – SAM Time-to-ID Score per Pilot', 'Color','w');
    for p = 1:nP
        tp = T(string(T.Lead_Pilot)==pilots(p),:);
        xnum = double(tp.Configuration); rng(1); jit = (rand(size(xnum))-0.5)*0.25;
        subplot(nP,1,p);
        scatter(xnum+jit, tp.SAM_ID_Time_Score, 32, cmap(p,:), 'filled', 'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k', 'LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yL); xticks(1:K); xticklabels(cfgOrder);
        ylabel('Time Score'); title(sprintf('C – %s', pilots(p)));
    end
else
    warning('SAM_All missing/empty for Scenario C.');
end

% ---------- 7) COMMUNICATION DENSITY ----------
if exist('Comms_All','var') && istable(Comms_All) && any(Comms_All.Scenario=="C")
    T = Comms_All(Comms_All.Scenario=="C",:);
    T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    T = T(~isundefined(T.Configuration),:);
    pilots = unique(string(T.Lead_Pilot),'stable'); nP = numel(pilots);
    cmap = cmapBase(1:max(nP,1),:); K = numel(cfgOrder);

    figure('Name', 'C – Comms Density Score per Pilot', 'Color','w');
    for p = 1:nP
        tp = T(string(T.Lead_Pilot)==pilots(p),:);
        xnum = double(tp.Configuration); rng(1); jit = (rand(size(xnum))-0.5)*0.25;
        subplot(nP,1,p);
        scatter(xnum+jit, tp.Comms_Density_Score, 32, cmap(p,:), 'filled', 'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k', 'LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yL); xticks(1:K); xticklabels(cfgOrder);
        ylabel('Comms Score'); title(sprintf('C – %s', pilots(p)));
    end
else
    warning('Comms_All missing/empty for Scenario C.');
end

fprintf('=== DEBUG A (C): Done ===\n');
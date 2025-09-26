function makePlotsSAMID(T, scenarioLabel)
    if isempty(T) || height(T)==0
        warning('No SAM ID rows for scenario %s', scenarioLabel); return;
    end

    cfgOrder = {'HH','HA','AH','AA'};
    T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    T = T(~isundefined(T.Configuration), :);
    if isempty(T), warning('%s: All rows had undefined Configuration.', scenarioLabel); return; end

    yLims = [1, 2];  % scores live in [1,2]
    pilots = unique(string(T.Lead_Pilot),'stable');
    nP = numel(pilots);
    cmap = lines(max(nP,7));
    K = numel(cfgOrder);

    % (1) Per-pilot – SAM_ID_Time_Score
    figure('Name', sprintf('%s – SAM ID Time Score per Pilot', scenarioLabel), 'Color','w');
    for p = 1:nP
        tp = T(string(T.Lead_Pilot)==pilots(p),:);
        xnum = double(tp.Configuration);
        rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;

        subplot(nP,1,p);
        scatter(xnum+jit, tp.SAM_ID_Time_Score, 32, cmap(p,:), 'filled', ...
                'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k','LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yLims);
        xticks(1:K); xticklabels(cfgOrder);
        ylabel('Time Score'); title(sprintf('%s – %s', scenarioLabel, pilots(p)));
    end

    % (2) All pilots – SAM_ID_Time_Score
    figure('Name', sprintf('%s – All Pilots: SAM ID Time Score', scenarioLabel), 'Color','w');
    xnum = double(T.Configuration);
    rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;
    scatter(xnum+jit, T.SAM_ID_Time_Score, 32, 'k','filled','MarkerFaceAlpha',0.6);
    grid on; xlim([0.5 K+0.5]); ylim(yLims);
    xticks(1:K); xticklabels(cfgOrder);
    ylabel('Time Score'); title([scenarioLabel ' – All Pilots (Time)']);

    % (3) Per-pilot – SAM_ID_Proportion_Score
    figure('Name', sprintf('%s – SAM ID Proportion Score per Pilot', scenarioLabel), 'Color','w');
    for p = 1:nP
        tp = T(string(T.Lead_Pilot)==pilots(p),:);
        xnum = double(tp.Configuration);
        rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;

        subplot(nP,1,p);
        scatter(xnum+jit, tp.SAM_ID_Proportion_Score, 32, cmap(p,:), 'filled', ...
                'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k','LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yLims);
        xticks(1:K); xticklabels(cfgOrder);
        ylabel('Prop Score'); title(sprintf('%s – %s', scenarioLabel, pilots(p)));
    end

    % (4) All pilots – SAM_ID_Proportion_Score
    figure('Name', sprintf('%s – All Pilots: SAM ID Proportion Score', scenarioLabel), 'Color','w');
    xnum = double(T.Configuration);
    rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;
    scatter(xnum+jit, T.SAM_ID_Proportion_Score, 32, 'k','filled','MarkerFaceAlpha',0.6);
    grid on; xlim([0.5 K+0.5]); ylim(yLims);
    xticks(1:K); xticklabels(cfgOrder);
    ylabel('Prop Score'); title([scenarioLabel ' – All Pilots (Proportion)']);
end
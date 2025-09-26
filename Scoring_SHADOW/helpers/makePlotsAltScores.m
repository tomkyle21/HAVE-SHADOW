function makePlotsAltScores(T, scenarioLabel)
    if isempty(T) || height(T)==0
        warning('No AltDev rows for scenario %s', scenarioLabel); return;
    end

    % Ensure Configuration is one of HH/HA/AH/AA (sheet name)
    cfgOrder = {'HH','HA','AH','AA'};
    T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    T = T(~isundefined(T.Configuration), :);
    if isempty(T), warning('%s: no defined configurations to plot.', scenarioLabel); return; end

    yLims = [1, 2];              % scores are in [1,2]
    pilots = unique(string(T.Lead_Pilot),'stable');
    nP = numel(pilots);
    cmap = lines(max(nP,7));
    K = numel(cfgOrder); xcats = 1:K;

    % ------- (1) Per-pilot: Integrated_Score by config -------
    figure('Name', sprintf('%s – AltDev Integrated Score per Pilot', scenarioLabel), 'Color','w');
    for p = 1:nP
        tp = T(string(T.Lead_Pilot)==pilots(p),:);
        xnum = double(tp.Configuration);
        rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;

        subplot(nP,1,p);
        scatter(xnum+jit, tp.Integrated_Score, 32, cmap(p,:), 'filled', ...
                'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k','LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yLims);
        xticks(1:K); xticklabels(cfgOrder);
        ylabel('Integrated Score'); title(sprintf('%s – %s', scenarioLabel, pilots(p)));
    end

    % ------- (2) All-pilots: Integrated_Score -------
    figure('Name', sprintf('%s – All Pilots: AltDev Integrated Score', scenarioLabel), 'Color','w');
    xnum = double(T.Configuration);
    rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;
    scatter(xnum+jit, T.Integrated_Score, 32, 'k', 'filled', 'MarkerFaceAlpha',0.6);
    grid on; xlim([0.5 K+0.5]); ylim(yLims);
    xticks(1:K); xticklabels(cfgOrder);
    ylabel('Integrated Score'); title([scenarioLabel ' – All Pilots (Integrated)']);

    % ------- (3) Per-pilot: Count_Score by config -------
    figure('Name', sprintf('%s – AltDev Count Score per Pilot', scenarioLabel), 'Color','w');
    for p = 1:nP
        tp = T(string(T.Lead_Pilot)==pilots(p),:);
        xnum = double(tp.Configuration);
        rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;

        subplot(nP,1,p);
        scatter(xnum+jit, tp.Count_Score, 32, cmap(p,:), 'filled', ...
                'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k','LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yLims);
        xticks(1:K); xticklabels(cfgOrder);
        ylabel('Count Score'); title(sprintf('%s – %s', scenarioLabel, pilots(p)));
    end

    % ------- (4) All-pilots: Count_Score -------
    figure('Name', sprintf('%s – All Pilots: AltDev Count Score', scenarioLabel), 'Color','w');
    xnum = double(T.Configuration);
    rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;
    scatter(xnum+jit, T.Count_Score, 32, 'k', 'filled', 'MarkerFaceAlpha',0.6);
    grid on; xlim([0.5 K+0.5]); ylim(yLims);
    xticks(1:K); xticklabels(cfgOrder);
    ylabel('Count Score'); title([scenarioLabel ' – All Pilots (Count)']);
end
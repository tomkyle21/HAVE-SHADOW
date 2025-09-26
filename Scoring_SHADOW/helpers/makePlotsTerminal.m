function makePlotsTerminal(T, scenarioLabel)
    if isempty(T) || height(T)==0
        warning('No terminal-condition rows for scenario %s', scenarioLabel);
        return;
    end

    cfgOrder = {'HH','HA','AH','AA'};
    T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    T = T(~isundefined(T.Configuration), :);
    if isempty(T)
        warning('%s: All rows had undefined Configuration after coercion.', scenarioLabel);
        return;
    end

    yDist = [min(T.Distance_Score,[],'omitnan'), max(T.Distance_Score,[],'omitnan')];
    yAlt  = [min(T.Altitude_Score,[],'omitnan'), max(T.Altitude_Score,[],'omitnan')];
    yAir  = [min(T.Airspeed_Score,[],'omitnan'), max(T.Airspeed_Score,[],'omitnan')];
    yHdg  = [min(T.Heading_Score,[],'omitnan'), max(T.Heading_Score,[],'omitnan')];
    pad = @(lims) [0, lims(2)*1.1];
    yDist = pad(yDist); yAlt = pad(yAlt); yAir = pad(yAir); yHdg = pad(yHdg);

    pilots = unique(string(T.Lead_Pilot), 'stable');
    nP = numel(pilots);
    cmap = lines(max(nP,7));
    K = numel(cfgOrder); xcats = 1:K;

    figure('Name', sprintf('%s – Terminal Scores (Dist/Alt) per Pilot', scenarioLabel), 'Color','w');
    for p = 1:nP
        tp = T(string(T.Lead_Pilot)==pilots(p), :);
        xnum = double(tp.Configuration);
        rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;

        subplot(nP,2,2*p-1);
        scatter(xnum+jit, tp.Distance_Score, 32, cmap(p,:), 'filled', ...
                'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k','LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yDist);
        xticks(xcats); xticklabels(cfgOrder);
        ylabel('Distance Score'); title(sprintf('%s – %s (Distance)', scenarioLabel, pilots(p)));

        subplot(nP,2,2*p);
        scatter(xnum+jit, tp.Altitude_Score, 32, cmap(p,:), 'filled', ...
                'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k','LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yAlt);
        xticks(xcats); xticklabels(cfgOrder);
        ylabel('Altitude Score'); title(sprintf('%s – %s (Altitude)', scenarioLabel, pilots(p)));
    end

    figure('Name', sprintf('%s – Terminal Scores (Air/Hdg) per Pilot', scenarioLabel), 'Color','w');
    for p = 1:nP
        tp = T(string(T.Lead_Pilot)==pilots(p), :);
        xnum = double(tp.Configuration);
        rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;

        subplot(nP,2,2*p-1);
        scatter(xnum+jit, tp.Airspeed_Score, 32, cmap(p,:), 'filled', ...
                'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k','LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yAir);
        xticks(xcats); xticklabels(cfgOrder);
        ylabel('Airspeed Score'); title(sprintf('%s – %s (Airspeed)', scenarioLabel, pilots(p)));

        subplot(nP,2,2*p);
        scatter(xnum+jit, tp.Heading_Score, 32, cmap(p,:), 'filled', ...
                'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k','LineWidth',0.25);
        grid on; xlim([0.5 K+0.5]); ylim(yHdg);
        xticks(xcats); xticklabels(cfgOrder);
        ylabel('Heading Score'); title(sprintf('%s – %s (Heading)', scenarioLabel, pilots(p)));
    end

    % All-pilots scatter (no averaging)
    figure('Name', sprintf('%s – All Pilots Scatter (Dist/Alt)', scenarioLabel), 'Color','w');
    xnum = double(T.Configuration);
    rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;

    subplot(1,2,1);
    scatter(xnum+jit, T.Distance_Score, 32, 'k','filled','MarkerFaceAlpha',0.6);
    grid on; xlim([0.5 K+0.5]); ylim(yDist);
    xticks(xcats); xticklabels(cfgOrder);
    ylabel('Distance Score'); title([scenarioLabel ' – All Pilots (Distance)']);

    subplot(1,2,2);
    scatter(xnum+jit, T.Altitude_Score, 32, 'k','filled','MarkerFaceAlpha',0.6);
    grid on; xlim([0.5 K+0.5]); ylim(yAlt);
    xticks(xcats); xticklabels(cfgOrder);
    ylabel('Altitude Score'); title([scenarioLabel ' – All Pilots (Altitude)']);

    figure('Name', sprintf('%s – All Pilots Scatter (Air/Hdg)', scenarioLabel), 'Color','w');
    subplot(1,2,1);
    scatter(xnum+jit, T.Airspeed_Score, 32, 'k','filled','MarkerFaceAlpha',0.6);
    grid on; xlim([0.5 K+0.5]); ylim(yAir);
    xticks(xcats); xticklabels(cfgOrder);
    ylabel('Airspeed Score'); title([scenarioLabel ' – All Pilots (Airspeed)']);

    subplot(1,2,2);
    scatter(xnum+jit, T.Heading_Score, 32, 'k','filled','MarkerFaceAlpha',0.6);
    grid on; xlim([0.5 K+0.5]); ylim(yHdg);
    xticks(xcats); xticklabels(cfgOrder);
    ylabel('Heading Score'); title([scenarioLabel ' – All Pilots (Heading)']);
end

% %% ===== Helper: very basic plots per scenario (scatter only for all-pilots) =====
% function makePlotsTerminal(T, scenarioLabel)
%     if isempty(T)
%         warning('No terminal-condition rows for scenario %s', scenarioLabel);
%         return;
%     end
% 
%     % Config as categorical with fixed order
%     cfgOrder = {'HH','HA','AH','AA'};
%     T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
%     T = T(~isundefined(T.Configuration), :);
%     if isempty(T)
%         warning('%s: All rows had undefined Configuration after coercion.', scenarioLabel);
%         return;
%     end
% 
%     % Global y-limits (per metric) for comparability across pilots
%     yDist = [min(T.Distance_Score,[],'omitnan'), max(T.Distance_Score,[],'omitnan')];
%     yAlt  = [min(T.Altitude_Score,[],'omitnan'), max(T.Altitude_Score,[],'omitnan')];
%     yAir  = [min(T.Airspeed_Score,[],'omitnan'), max(T.Airspeed_Score,[],'omitnan')];
%     yHdg  = [min(T.Heading_Score,[],'omitnan'), max(T.Heading_Score,[],'omitnan')];
% 
%     pad = @(lims) [0, lims(2)*1.1]; % floor at 0, add 10% headroom
%     yDist = pad(yDist); yAlt = pad(yAlt); yAir = pad(yAir); yHdg = pad(yHdg);
% 
%     pilots = unique(string(T.Lead_Pilot), 'stable');
%     nP = numel(pilots);
%     cmap = lines(max(nP,7));
%     K = numel(cfgOrder); xcats = 1:K;
% 
%     % ===== (1) Per-pilot figure (Distance & Altitude)
%     figure('Name', sprintf('%s – Terminal Scores (Dist/Alt) per Pilot', scenarioLabel), 'Color','w');
%     for p = 1:nP
%         tp = T(string(T.Lead_Pilot)==pilots(p), :);
% 
%         % Jitter for scatter
%         xnum = double(tp.Configuration);
%         rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;
% 
%         % Distance
%         subplot(nP,2,2*p-1);
%         scatter(xnum+jit, tp.Distance_Score, 32, cmap(p,:), 'filled', ...
%                 'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k','LineWidth',0.25);
%         grid on; xlim([0.5 K+0.5]); ylim(yDist);
%         xticks(xcats); xticklabels(cfgOrder);
%         ylabel('Distance Score'); title(sprintf('%s – %s (Distance)', scenarioLabel, pilots(p)));
% 
%         % Altitude
%         subplot(nP,2,2*p);
%         scatter(xnum+jit, tp.Altitude_Score, 32, cmap(p,:), 'filled', ...
%                 'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k','LineWidth',0.25);
%         grid on; xlim([0.5 K+0.5]); ylim(yAlt);
%         xticks(xcats); xticklabels(cfgOrder);
%         ylabel('Altitude Score'); title(sprintf('%s – %s (Altitude)', scenarioLabel, pilots(p)));
%     end
% 
%     % ===== (2) Per-pilot figure (Airspeed & Heading)
%     figure('Name', sprintf('%s – Terminal Scores (Air/Hdg) per Pilot', scenarioLabel), 'Color','w');
%     for p = 1:nP
%         tp = T(string(T.Lead_Pilot)==pilots(p), :);
%         xnum = double(tp.Configuration);
%         rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;
% 
%         % Airspeed
%         subplot(nP,2,2*p-1);
%         scatter(xnum+jit, tp.Airspeed_Score, 32, cmap(p,:), 'filled', ...
%                 'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k','LineWidth',0.25);
%         grid on; xlim([0.5 K+0.5]); ylim(yAir);
%         xticks(xcats); xticklabels(cfgOrder);
%         ylabel('Airspeed Score'); title(sprintf('%s – %s (Airspeed)', scenarioLabel, pilots(p)));
% 
%         % Heading
%         subplot(nP,2,2*p);
%         scatter(xnum+jit, tp.Heading_Score, 32, cmap(p,:), 'filled', ...
%                 'MarkerFaceAlpha',0.65, 'MarkerEdgeColor','k','LineWidth',0.25);
%         grid on; xlim([0.5 K+0.5]); ylim(yHdg);
%         xticks(xcats); xticklabels(cfgOrder);
%         ylabel('Heading Score'); title(sprintf('%s – %s (Heading)', scenarioLabel, pilots(p)));
%     end
% 
%     % ===== (3) All-pilots scatter (no averaging, just all observed scores)
%     figure('Name', sprintf('%s – All Pilots Scatter (Dist/Alt)', scenarioLabel), 'Color','w');
%     xnum = double(T.Configuration);
%     rng(1); jit = (rand(size(xnum)) - 0.5)*0.25;
% 
%     subplot(1,2,1);
%     scatter(xnum+jit, T.Distance_Score, 32, 'k','filled','MarkerFaceAlpha',0.6);
%     grid on; xlim([0.5 K+0.5]); ylim(yDist);
%     xticks(xcats); xticklabels(cfgOrder);
%     ylabel('Distance Score'); title([scenarioLabel ' – All Pilots (Distance)']);
% 
%     subplot(1,2,2);
%     scatter(xnum+jit, T.Altitude_Score, 32, 'k','filled','MarkerFaceAlpha',0.6);
%     grid on; xlim([0.5 K+0.5]); ylim(yAlt);
%     xticks(xcats); xticklabels(cfgOrder);
%     ylabel('Altitude Score'); title([scenarioLabel ' – All Pilots (Altitude)']);
% 
%     figure('Name', sprintf('%s – All Pilots Scatter (Air/Hdg)', scenarioLabel), 'Color','w');
% 
%     subplot(1,2,1);
%     scatter(xnum+jit, T.Airspeed_Score, 32, 'k','filled','MarkerFaceAlpha',0.6);
%     grid on; xlim([0.5 K+0.5]); ylim(yAir);
%     xticks(xcats); xticklabels(cfgOrder);
%     ylabel('Airspeed Score'); title([scenarioLabel ' – All Pilots (Airspeed)']);
% 
%     subplot(1,2,2);
%     scatter(xnum+jit, T.Heading_Score, 32, 'k','filled','MarkerFaceAlpha',0.6);
%     grid on; xlim([0.5 K+0.5]); ylim(yHdg);
%     xticks(xcats); xticklabels(cfgOrder);
%     ylabel('Heading Score'); title([scenarioLabel ' – All Pilots (Heading)']);
% end
function makePlotsCombined(T, scenarioLabel, useLift, k_lift)
% Scatter + box/whisker for Intercept_Combined_Score by Configuration.
% T must include: Scenario, Configuration, Lead_Pilot, Intercept_Combined_Score

    if nargin < 3 || isempty(useLift), useLift = false; end   % overall products can exceed 2
    if nargin < 4 || isempty(k_lift),  k_lift  = 5;    end

    if isempty(T) || height(T)==0
        warning('No Combined rows for scenario %s', scenarioLabel); return;
    end

    % Keep only this scenario
    T = T(T.Scenario==scenarioLabel,:);
    if isempty(T)
        warning('No rows for scenario %s', scenarioLabel); return;
    end

    % Fixed config order (always 1..4 positions)
    cfgOrder = {'HH','HA','AH','AA'};
    xcats = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    xnum  = double(xcats);                % numeric positions 1..4 (NaN for undefined)

    % y data; keep only valid rows (defined config + finite score)
    y = toNum(T.Intercept_Combined_Score);
    valid = ~isnan(y) & ~isnan(xnum);
    T = T(valid,:); y = y(valid); xcats = xcats(valid); xnum = xnum(valid);
    if isempty(T)
        warning('All values NaN/undefined for %s (Combined)', scenarioLabel); return;
    end

    if useLift
        y = liftPreserveGT2_(y, k_lift);
    end

    % Figure
    figure('Name', sprintf('%s – Combined Score', scenarioLabel), 'Color','w'); hold on;

    % ---------- Box & whisker at correct positions for PRESENT groups ----------
    try
        % xcats already created and mapped to fixed order {'HH','HA','AH','AA'}
        % and xnum = double(xcats) for valid rows (same length as y)
    
        ug = unique(xnum(:)');            % present group indices (e.g., [1 2 4])
        % Keep only data for present groups (already true, but safe)
        keep = ismember(xnum, ug);
        y_bp = y(keep);
        x_bp = xnum(keep);
    
        % IMPORTANT: Positions length must equal number of groups:
        % use the *present* group indices as the positions, so boxes sit at 1..4 where present.
        boxplot(y_bp, x_bp, ...
            'Symbol','', 'Positions', ug, ...
            'Colors',[0.25 0.25 0.25], 'Whisker',1.5, ...
            'PlotStyle','traditional', 'Widths',0.5);
    
        set(findobj(gca,'Tag','Box'),'LineWidth',1.0);
        set(findobj(gca,'Tag','Median'),'LineWidth',1.2);
    catch ME
        warning('boxplot failed (%s); continuing with scatter only.', ME.message);
    end

    % ---------- Scatter with pilot-specific symbology (uses same xnum) ----------
    pilots  = unique(string(T.Lead_Pilot),'stable');
    markers = {'o','s','^','d','v','>','<','p','h','x','+'};
    cols    = lines(max(numel(pilots),7));
    rng(1); jit = (rand(height(T),1) - 0.5) * 0.25;

    legObjs = gobjects(0); legLabs = strings(0,1);
    for p = 1:numel(pilots)
        m = string(T.Lead_Pilot)==pilots(p);
        if ~any(m), continue; end
        col = cols(mod(p-1,size(cols,1))+1, :);
        mk  = markers{mod(p-1,numel(markers))+1};
        scatter(xnum(m)+jit(m), y(m), 38, col, 'filled', ...
                'Marker', mk, 'MarkerFaceAlpha',0.75, ...
                'MarkerEdgeColor','k','LineWidth',0.25);
        % legend proxy
        legObjs(end+1) = plot(nan,nan,'o','MarkerFaceColor',col,'MarkerEdgeColor','k','Marker',mk); %#ok<AGROW>
        legLabs(end+1) = pilots(p); %#ok<AGROW>
    end

    % Axes & labels (always show all 4 configs in order)
    grid on;
    xlim([0.5 numel(cfgOrder)+0.5]);
    xticks(1:numel(cfgOrder));
    xticklabels(cfgOrder);
    ylabel('Combined Score (product of subscores)');
    title(sprintf('%s – Combined Score', scenarioLabel));

    if ~isempty(legObjs)
        lg = legend(legObjs, legLabs, 'Location','bestoutside'); set(lg,'Interpreter','none');
    end
    hold off;
end

% helpers
function y2 = liftPreserveGT2_(y, k)
    y  = max(y, 1);
    z  = min(max(y - 1, 0), 1);
    z2 = log1p(k * z) ./ log1p(k);
    y2 = 1 + z2 + max(y - 2, 0);
end

function v = toNum(x)
    if isnumeric(x) || islogical(x)
        v = double(x(:));
    else
        v = str2double(string(x(:)));
    end
end

% function makePlotsCombined(T, scenarioLabel)
%     if isempty(T) || height(T)==0
%         warning('No Combined rows for scenario %s', scenarioLabel); return;
%     end
% 
%     % Keep only this scenario
%     T = T(T.Scenario==scenarioLabel, :);
%     if isempty(T), warning('No rows for scenario %s', scenarioLabel); return; end
% 
%     % Enforce config order
%     cfgOrder = {'HH','HA','AH','AA'};
%     T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
%     T = T(~isundefined(T.Configuration), :);
%     if isempty(T), warning('%s: All rows had undefined Configuration.', scenarioLabel); return; end
% 
%     % Intercept numbers present (for x-limits)
%     kmin = min(T.Intercept_Num);
%     kmax = max(T.Intercept_Num);
%     if ~isfinite(kmin) || ~isfinite(kmax), kmin = 1; kmax = 8; end
% 
%     % For each configuration, make a figure with all pilots' data
%     cfgs = categories(T.Configuration);
%     for c = 1:numel(cfgs)
%         cfg = cfgs{c};
%         Tc  = T(T.Configuration == cfg, :);
%         if isempty(Tc), continue; end
% 
%         % Basic scatter with jitter on x to reduce overlap
%         x = Tc.Intercept_Num;
%         rng(1); jit = (rand(size(x)) - 0.5) * 0.20;  % small jitter
%         xj = x + jit;
% 
%         figure('Name', sprintf('%s – Combined Score (%s)', scenarioLabel, cfg), 'Color','w');
%         scatter(xj, Tc.Intercept_Combined_Score, 32, 'k', 'filled', 'MarkerFaceAlpha', 0.6, ...
%                 'MarkerEdgeColor','k','LineWidth',0.25);
%         grid on;
%         xlim([kmin-0.5, kmax+0.5]);
%         xticks(unique(x));
%         xlabel('Intercept #');
%         ylabel('Combined Score (Product of 6 subscores)');
%         title(sprintf('%s – %s: All Pilots (Combined Score)', scenarioLabel, cfg));
%     end
% end
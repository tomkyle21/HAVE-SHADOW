function pilotScatterByCfg_C(Tin, pilotName, scoreCol, titleText)
% One pilot's scatter by configuration for Scenario C.
    if isempty(Tin) || ~ismember(scoreCol, Tin.Properties.VariableNames), return; end
    T = Tin(string(Tin.Scenario)=="C" & string(Tin.Lead_Pilot)==string(pilotName), :);
    if isempty(T), return; end

    cfgOrder = {'HH','HA','AH','AA'};
    T.Configuration = categorical(string(T.Configuration), cfgOrder, 'Ordinal', true);
    T = T(~isundefined(T.Configuration), :);
    if isempty(T), return; end

    xnum = double(T.Configuration);
    y    = double(T.(scoreCol));
    m    = isfinite(y);
    xnum = xnum(m); y = y(m);
    if isempty(xnum), return; end

    rng(1); jit = (rand(size(xnum)) - 0.5) * 0.25;
    figure('Color','w','Name',sprintf('C – %s – %s',string(pilotName),titleText));
    hold on; grid on;
    scatter(xnum + jit, y, 40, 'k', 'filled', 'MarkerFaceAlpha',0.7, 'MarkerEdgeColor','k');
    xlim([0.5 4.5]); xticks(1:4); xticklabels(cfgOrder);
    xlabel('Configuration'); ylabel(titleText);
    title(sprintf('C – %s — %s', string(pilotName), titleText));
    hold off;
end
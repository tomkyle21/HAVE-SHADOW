function outT = grabTerminal_multi(allDataStruct, scenarioLabel, maxIntercept)
    sheets = fieldnames(allDataStruct);
    rows = [];

    for i = 1:numel(sheets)
        sh = sheets{i};
        T  = allDataStruct.(sh);

        if ~ismember("Lead_Pilot", T.Properties.VariableNames)
            fprintf('Sheet %s skipped (missing Lead_Pilot)\n', sh);
            continue;
        end

        for k = 1:maxIntercept
            % Exact headers for this intercept number
            vDist = sprintf("CM%d_Distance_from_CM_at_Intercept_nm", k);
            vAlt  = sprintf("CM%d_Altitude_Offset_at_Intercept_ft", k);
            vSpd  = sprintf("CM%d_Airspeed_Diff_at_Intercept_kt", k);
            vHdg  = sprintf("CM%d_Heading_Diff_at_Intercept_deg", k);

            need = [vDist, vAlt, vSpd, vHdg];

            % Require the four exact headers + Lead_Pilot for THIS intercept
            if all(ismember(need, T.Properties.VariableNames))
                % Assemble base table
                sub = table();
                sub.Scenario      = repmat(string(scenarioLabel), height(T), 1);
                sub.Configuration = repmat(string(sh),            height(T), 1);  % sheet name = config (HH/HA/AH/AA)
                sub.Lead_Pilot    = string(T.Lead_Pilot);
                sub.Intercept_Num = repmat(k, height(T), 1);

                % Pull and coerce numerics (force column vectors)
                Dnm  = toNum(T.(vDist));  Dnm  = Dnm(:);
                Dzft = toNum(T.(vAlt));   Dzft = Dzft(:);
                Dkt  = toNum(T.(vSpd));   Dkt  = Dkt(:);
                Dhdg = toNum(T.(vHdg));   Dhdg = Dhdg(:);

                % Keep raw columns with standardized names
                sub.Distance_nm                = Dnm;
                sub.Altitude_Offset_ft         = Dzft;
                sub.Airspeed_Diff_kt           = Dkt;
                sub.Heading_Diff_deg           = Dhdg;

                % ----- Scores (same logic as your working code, except heading band updated) -----

                % Distance: convert NM → ft, bounded 1..2 with exponential tails
                % ===== Distance: exponential centered at 2000 ft =====
                dist_ft = Dnm * 6076.12;           % convert NM → ft
                tau_ft  = 3000;                    % tuning knob (smaller = steeper, larger = gentler)
                distScore = 1 + exp(-abs(dist_ft - 2000) ./ tau_ft);                

                % ===== Altitude: pure exponential (best at 0 offset, decays toward 1) =====
                % In general: score = 1.5 when altDelta ≈ tau_alt * ln(2)
                altDelta = abs(Dzft);         % deviation from 0 ft
                tau_alt  = 150;              % tuning knob (smaller = steeper drop, larger = gentler)
                altScore = 1 + exp(-altDelta ./ tau_alt);

                % Airspeed: 1..2 exponential around 30 kt (simple, fixed tau like your code)
                airScore = 1 + exp(-abs(30 - Dkt)./20);

                % ===== Heading: full credit inside ±0°, exponential falloff outside =====
                tol_deg  = 0;                        % good band
                tau_hdg  = 25;                        % spread knob (smaller = steeper drop)
                
                hdgDelta = abs(Dhdg);
                excess   = max(0, hdgDelta - tol_deg);   % 0 inside band, >0 outside
                hdgScore = 1 + exp(-excess ./ tau_hdg);  % 2 in band, decays smoothly toward 1

                % Add scores
                sub.Distance_Score  = distScore(:);
                sub.Altitude_Score  = altScore(:);
                sub.Airspeed_Score  = airScore(:);
                sub.Heading_Score   = hdgScore(:);

                rows = [rows; sub]; %#ok<AGROW>
            else
                % This sheet simply doesn't have this CM#; skip quietly
                % fprintf('Sheet %s missing CM%d required columns, skipped.\n', sh, k);
            end
        end
    end

    % Always return a table (even if no rows)
    if isempty(rows)
        outT = table('Size',[0 12], 'VariableTypes', ...
            {'string','string','string','double','double','double','double','double','double','double','double','double'}, ...
            'VariableNames', {'Scenario','Configuration','Lead_Pilot','Intercept_Num', ...
                              'Distance_nm','Altitude_Offset_ft','Airspeed_Diff_kt','Heading_Diff_deg', ...
                              'Distance_Score','Altitude_Score','Airspeed_Score','Heading_Score'});
    else
        outT = rows;
    end
end

function v = toNum(x)
    if isnumeric(x) || islogical(x)
        v = double(x(:));            % force column
    else
        v = str2double(string(x(:)));% non-numeric -> NaN, force column
    end
end
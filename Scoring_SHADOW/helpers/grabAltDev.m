%% ===== Helper =====
function outT = grabAltDev(allDataStruct, scenarioLabel)
    sheets = fieldnames(allDataStruct);
    rows = [];
    for i = 1:numel(sheets)
        sh = sheets{i};
        T  = allDataStruct.(sh);

        needed = ["Lead_Altitude_Deviation_Count", ...
                  "Wingman_Altitude_Deviation_Count", ...
                  "Lead_Altitude_Deviation_Integrated_ft_s", ...
                  "Wingman_Altitude_Deviation_Integrated_ft_s"];
        if all(ismember(needed, T.Properties.VariableNames))
            sub = table();
            sub.Scenario = repmat(string(scenarioLabel),height(T),1);
            sub.Sheet    = repmat(string(sh),height(T),1);

            sub.Lead_Pilot = string(T.Lead_Pilot);

            % ✅ Use the sheet name as the configuration label
            sub.Configuration = repmat(string(sh), height(T), 1);

            % Copy values
            sub.Lead_Altitude_Deviation_Count = double(T.Lead_Altitude_Deviation_Count);
            sub.Wingman_Altitude_Deviation_Count = double(T.Wingman_Altitude_Deviation_Count);
            sub.Lead_Altitude_Deviation_Integrated_ft_s = double(T.Lead_Altitude_Deviation_Integrated_ft_s);
            sub.Wingman_Altitude_Deviation_Integrated_ft_s = double(T.Wingman_Altitude_Deviation_Integrated_ft_s);

            % Totals
            sub.Total_Altitude_Deviation_Count = ...
                sub.Lead_Altitude_Deviation_Count + sub.Wingman_Altitude_Deviation_Count;
            sub.Integrated_Altitude_Deviation_ft_s = ...
                sub.Lead_Altitude_Deviation_Integrated_ft_s + sub.Wingman_Altitude_Deviation_Integrated_ft_s;

            rows = [rows; sub]; %#ok<AGROW>
        else
            fprintf('Sheet %s missing required columns, skipped.\n',sh);
        end
    end
    outT = rows;
end
"""
This module provides the infrastructure for the HAVE SHADOW TMP.
Specifically, this file and its dependencies take the .csv files from flight test and reduce the data into the pre-defined MOPs.
Here is what must be done prior to running this script:
1. Ensure that the flight test data is saved properly in a .csv file format using the proper naming convention.
2. Have either the even numbers or times associated with the scenarios flown.
"""

# import libraries
import numpy as np
import pandas as pd
import math
from Utils.DataReduction import *

if __name__ == "__main__":
    # Define file paths
    input_file_path = 'Data/'
    data_threads = {'comm':'Communications', 'CM':'CruiseMissiles', 'L':'Lead',
                    'W':'Wingman', 'ST':'SurfaceThreats', 'W':'Workload'}
    output_file_path = 'Output'

    # request input from user for the Lead pilot's name and the flight number
    lead_pilot = input("Enter Lead pilot's name (Chan, Grimmer, Jacob): ")
    flight_number = input("Enter flight number: ")

    # Load data
    flight_data = pd.read_csv('Data/Lead/Lead_{}_{}.csv'.format(lead_pilot, flight_number), low_memory=False)
    lead_airspeed_data = pd.read_csv('Data/Lead/Lead_{}_{}_Airspeed.csv'.format(lead_pilot, flight_number), low_memory=False)
    wing_airpseed_data = pd.read_csv('Data/Wingman/Wing_{}_{}_Airspeed.csv'.format(lead_pilot, flight_number), low_memory=False)

    # Merge airspeed data into flight_data
    print('Merging airspeed data into DIS data...')
    flight_data = brute_force_merge_airspeed(flight_data, lead_airspeed_data, wing_airpseed_data) # this line takes a minute ...

    # Query the user to understand how many scenarios were flown in the flight
    num_scenarios = int(input("Enter the number of scenarios flown in this flight: "))

    # generate a blank dataframe to hold the MOPs
    mops_df = pd.DataFrame()

    # define sortie_df to hold all the data from the flight
    Altitude_Col = 'Altitude'
    # Airpseed_Col = 'True_Airspeed'  # TODO - NO AIRSPEED FOR NOW!!
    cols_L29s = ['Timestamp', 'SampleDate', 'SampleTime', 'Configuration', 'Scenario', 'MarkingTxt', 'Heading', 'Roll',
                 'Latitude', 'Longitude', Altitude_Col]
    cols_CMs = ['Timestamp', 'SampleDate', 'SampleTime', 'Configuration', 'Scenario', 'MarkingTxt',
                'EntId', 'Latitude', 'Longitude', 'Heading']

    # Make sure Timestamp is sorted and in datetime format
    flight_data['Timestamp'] = pd.to_datetime(flight_data['Timestamp'])
    flight_data['SampleTime'] = pd.to_datetime(flight_data['SampleTime'])
    flight_data['SampleDate'] = pd.to_datetime(flight_data['SampleDate'])
    # wing_data['Timestamp'] = pd.to_datetime(wing_data['Timestamp'])
    # cruise_data['Timestamp'] = pd.to_datetime(cruise_data['Timestamp'])

    # OPL Naming Convention - Black is AMBUSH51, Blue is HAWK11
    # OPL Gouge - Black jet (AMBUSH51) DIS data is best.
    # OPL Convo - LinVels are in ECEF and m/s, may need to use other table and fixing column names now. 
    lead_data = flight_data[flight_data['MarkingTxt'] == 'AMBUSH51']
    wing_data = flight_data[flight_data['MarkingTxt'] == 'HAWK11']
    cruise_data = flight_data[flight_data['MarkingTxt'] == 'JASSM']
    sam_data = flight_data[flight_data['MarkingTxt'] == 'SAM']

    for scenario in range(1, num_scenarios + 1):
        print(f"Processing scenario {scenario} of {num_scenarios}...")
        # query the user for the scenario type and autonomy configuration
        scenario_type = input(f"Enter the type of scenario {scenario} (A, B, C, or D): ")
        assert scenario_type in ['A', 'B', 'C', 'D'], "Invalid scenario type. Please enter A, B, C, or D."
        autonomy_config = input(f"Enter the autonomy configuration for scenario {scenario} (HH, HA, AH, AA): ")
        assert autonomy_config in ['HH', 'HA', 'AH', 'AA'], "Invalid autonomy configuration. Please enter HH, HA, AH, or AA."
        correct_sort = input(f"Did the wingman in scenario {scenario} intercept the correct cruise missiles? (Y/N): ")
        assert correct_sort in ['Y', 'N'], "Invalid input. Please enter Y or N."
        num_tac_comms = input(f"Enter the number of tactical communications in scenario {scenario}: ")

        # Query the user for meta data: lead alt, wing alt, cruise missile airspeed
        # lead_alt = input(f"Enter Lead's assigned altitude (in feet, MSL) in scenario {scenario}: ")
        # wing_alt = input(f"Enter Wingman's assigned altitude (in feet, MSL) in scenario {scenario}: ")
        CM_airspeed = 150

        scenario_data = flight_data[(flight_data['Scenario'] == scenario_type) & (flight_data['Configuration'] == autonomy_config)].copy()
        scenario_start_time = scenario_data['SampleTime'].min()
        scenario_end_time = scenario_data['SampleTime'].max()
        # record the first lead_alt and wing_alt in the defined scenario
        lead_alt = scenario_data[scenario_data['MarkingTxt'] == 'AMBUSH51']['Altitude'].iloc[0]
        wing_alt = scenario_data[scenario_data['MarkingTxt'] == 'HAWK11']['Altitude'].iloc[0]
        
        num_CMs = scenario_data[scenario_data['MarkingTxt'] == 'JASSM']['EntId'].nunique()
        CM_EntIds = scenario_data[scenario_data['MarkingTxt'] == 'JASSM']['EntId'].unique()
        
        scenario_data['CM_Altitude_Lead'] = lead_alt
        scenario_data['CM_Altitude_Wing'] = wing_alt
        scenario_data['CM_Airspeed'] = CM_airspeed

        # --- Generate MOPs for this scenario ---
        scenario_mops = {}
        scenario_mops['Flight_Number'] = flight_number
        scenario_mops['Lead_Pilot'] = lead_pilot
        scenario_mops['Scenario_within_flight'] = scenario
        scenario_mops['Scenario_Type'] = scenario_type
        scenario_mops['Autonomy_Config'] = autonomy_config
        scenario_mops['Correct_Sort'] = correct_sort
        scenario_mops['Num_CMs'] = num_CMs
        scenario_mops['Lead_Altitude_MSL_ft'] = lead_alt
        scenario_mops['Wingman_Altitude_MSL_ft'] = wing_alt
        scenario_mops['CM_Airspeed_kt'] = CM_airspeed
        scenario_mops['Scenario_Start_Time'] = scenario_start_time
        scenario_mops['Scenario_End_Time'] = scenario_end_time
        scenario_mops['Scenario_Duration_s'] = (scenario_end_time - scenario_start_time).total_seconds()

        # --- Altitude Deviation MOPs ---
        # --- RESTART HERE ---         
        alt_devs_lead = altitude_deviation(scenario_data, role='Lead', assigned_alt=int(lead_alt), alt_block_radius=500)
        alt_devs_wing = altitude_deviation(scenario_data, role='Wingman', assigned_alt=int(wing_alt), alt_block_radius=500)

        scenario_mops['Lead_Altitude_Deviation_Count'] = alt_devs_lead[0]
        scenario_mops['Wingman_Altitude_Deviation_Count'] = alt_devs_wing[0]
        scenario_mops['Lead_Altitude_Deviation_Integrated_ft_s'] = alt_devs_lead[1]
        scenario_mops['Wingman_Altitude_Deviation_Integrated_ft_s'] = alt_devs_wing[1]

        print('Done here')
        print(scenario_mops) # DELETE ME WHEN DONE DEBUGGING

        # --- Cruise Missile Intercept MOPs ---
        CM_time_to_intercept_dict = {}
        for cm_ID in CM_EntIds:
            # if within_cone is not empty:
            if is_within_cone(scenario_data, cm_index=cm_ID, role='Lead', scenario_alt=lead_alt) is not None:
                intercept_mops = is_within_cone(scenario_data, cm_index=cm_ID, role='Lead', scenario_alt=lead_alt)
                CM_time_to_intercept_dict[cm_ID] = intercept_mops['Time_to_Intercept_s']
            elif is_within_cone(scenario_data, cm_index=cm_ID, role='Wingman', scenario_alt=wing_alt) is not None:
                intercept_mops = is_within_cone(scenario_data, cm_index=cm_ID, role='Wingman', scenario_alt=wing_alt)
                CM_time_to_intercept_dict[cm_ID] = intercept_mops['Time_to_Intercept_s']
        
        CM_time_to_intercept_dict = dict(sorted(CM_time_to_intercept_dict.items(), key=lambda item: item[1]))
        total_CMs_intercepted = len(CM_time_to_intercept_dict)
        prop_CMs_intercepted = total_CMs_intercepted / num_CMs if num_CMs > 0 else 0
        scenario_mops['Total_CMs_Intercepted'] = total_CMs_intercepted
        scenario_mops['Proportion_CMs_Intercepted'] = prop_CMs_intercepted
        # iterate through the cm_s in order of time to intercept
        for i, (cm_ID, time_to_intercept) in enumerate(CM_time_to_intercept_dict.items(), start=1):
            if is_within_cone(scenario_data, cm_index=cm_ID, role='Lead', scenario_alt=lead_alt) is not None:
                intercept_mops = is_within_cone(scenario_data, cm_index=cm_ID, role='Lead', scenario_alt=lead_alt)
                scenario_mops[f'CM{i}_EntId'] = cm_ID
                scenario_mops[f'CM{i}_Interceptor Role'] = intercept_mops['Interceptor Role']
                scenario_mops[f'CM{i}_Time_to_Intercept_s'] = intercept_mops['Time_to_Intercept_s']
                scenario_mops[f'CM{i}_Time_to_Consent_s'] = intercept_mops['Time_to_Consent_s']
                scenario_mops[f'CM{i}_Airspeed_at_Intercept_kt'] = intercept_mops['Airspeed_at_Intercept_kt']
                scenario_mops[f'CM{i}_Airspeed_Diff_at_Intercept_kt'] = intercept_mops['Airspeed_Diff_at_Intercept_kt']
                scenario_mops[f'CM{i}_Heading_at_Intercept_deg'] = intercept_mops['Heading_at_Intercept_deg']
                scenario_mops[f'CM{i}_CM_Heading_at_Intercept_deg'] = intercept_mops['CM_Heading_at_Intercept_deg']
                scenario_mops[f'CM{i}_Heading_Diff_at_Intercept_deg'] = intercept_mops['Heading_Diff_at_Intercept_deg']
                scenario_mops[f'CM{i}_Altitude_at_Intercept_ft'] = intercept_mops['Altitude_at_Intercept_ft']
                scenario_mops[f'CM{i}_Altitude_Offset_at_Intercept_ft'] = intercept_mops['Altitude_Offset_at_Intercept_ft']
                scenario_mops[f'CM{i}_Bank_Angle_at_Intercept_deg'] = intercept_mops['Bank_Angle_at_Intercept_deg']
            elif is_within_cone(scenario_data, cm_index=cm_ID, role='Wingman', scenario_alt=wing_alt) is not None:
                intercept_mops = is_within_cone(scenario_data, cm_index=cm_ID, role='Wingman', scenario_alt=wing_alt)
                scenario_mops[f'CM{i}_EntId'] = cm_ID
                scenario_mops[f'CM{i}_Interceptor Role'] = intercept_mops['Interceptor Role']
                scenario_mops[f'CM{i}_Time_to_Intercept_s'] = intercept_mops['Time_to_Intercept_s']
                scenario_mops[f'CM{i}_Time_to_Consent_s'] = intercept_mops['Time_to_Consent_s']
                scenario_mops[f'CM{i}_Airspeed_at_Intercept_kt'] = intercept_mops['Airspeed_at_Intercept_kt']
                scenario_mops[f'CM{i}_Airspeed_Diff_at_Intercept_kt'] = intercept_mops['Airspeed_Diff_at_Intercept_kt']
                scenario_mops[f'CM{i}_Heading_at_Intercept_deg'] = intercept_mops['Heading_at_Intercept_deg']
                scenario_mops[f'CM{i}_CM_Heading_at_Intercept_deg'] = intercept_mops['CM_Heading_at_Intercept_deg']
                scenario_mops[f'CM{i}_Heading_Diff_at_Intercept_deg'] = intercept_mops['Heading_Diff_at_Intercept_deg']
                scenario_mops[f'CM{i}_Altitude_at_Intercept_ft'] = intercept_mops['Altitude_at_Intercept_ft']
                scenario_mops[f'CM{i}_Altitude_Offset_at_Intercept_ft'] = intercept_mops['Altitude_Offset_at_Intercept_ft']
                scenario_mops[f'CM{i}_Bank_Angle_at_Intercept_deg'] = intercept_mops['Bank_Angle_at_Intercept_deg']

        # --- SAM Identification MOPs ---
        SAM_data = scenario_data[scenario_data['MarkingTxt'] == 'SAM']
        SAM_data['SampleTime'] = pd.to_datetime(SAM_data['SampleTime'])
        num_sams = SAM_data['EntId'].nunique()
        SAM_IDs = SAM_data['EntId'].unique()
        SAMs_Identified = input(f"Enter the number of SAMs identified by the Lead in scenario {scenario}: ")
        scenario_mops['Num_SAMs'] = num_sams
        scenario_mops['SAMs_Identified_by_Lead'] = SAMs_Identified
        scenario_mops['Proportion_SAMs_Identified'] = int(SAMs_Identified) / num_sams if num_sams > 0 else 0
        # --- COMMENTING OUT FOR NOW - MORE FUNCTIONALITY REQ'D --- 
        # bullseye_lat = 41.38494111111111
        # bullseye_lon = -91.24627944444444
        # for i, sam_ID in enumerate(SAM_IDs, start=1):
        #     scenario_mops[f'SAM{i}_EntId'] = sam_ID
        #     SAM_spawn_time = SAM_data[SAM_data['EntId'] == sam_ID]['SampleTime'].min()
        #     SAM_spawn_date = SAM_spawn_time.date()
        #     SAM_lat = SAM_data[SAM_data['EntId'] == sam_ID]['Latitude'].iloc[0]
        #     SAM_lon = SAM_data[SAM_data['EntId'] == sam_ID]['Longitude'].iloc[0]
        #     SAM_bullseye_call = bearing_range_flat(bullseye_lat, bullseye_lon, SAM_lat, SAM_lon, axis_deg=120)
        #     bullseye_bearing = SAM_bullseye_call[0]
        #     bullseye_range = SAM_bullseye_call[1]
        #     identified_SAM = input(f"Did Lead call out SAM {sam_ID} at {round(bullseye_bearing)} deg / {round(bullseye_range)} nm? (Y/N): ")
        #     if identified_SAM == 'Y':
        #         ID_time = input(f"Copt and paste the SAM ID time for {round(bullseye_bearing)} deg / {round(bullseye_range)} from the data logs: ")
        #         # add SAM_spawn_date to ID_time
        #         ID_time = pd.to_datetime(f"{SAM_spawn_date} {ID_time}")
        #         print('ID_time before adjustment:', ID_time)
        #         # add 5 hours to ID_time to convert from central to Zulu
        #         ID_time = ID_time + pd.DateOffset(hours=5)
        #         print('ID_time after adjustment:', ID_time)
        #         print('SAM spawn time:', SAM_spawn_time)
        #         time_to_ID = (ID_time - SAM_spawn_time).total_seconds()
        #         if time_to_ID < 0:
        #             ID_time = ID_time + pd.DateOffset(hours=2)
        #             time_to_ID = (ID_time - SAM_spawn_time).total_seconds()
        #         print(f"Time to ID for SAM {sam_ID} is {time_to_ID} seconds.")

        mops_df = pd.concat([mops_df, pd.DataFrame([scenario_mops])], ignore_index=True)


    # Save MOPs to CSV
    mops_df.to_csv(f'{output_file_path}/MOPs_{lead_pilot}_Flight{flight_number}.csv', index=False)

    print(f"Data reduction complete. MOPs saved to {output_file_path}.")
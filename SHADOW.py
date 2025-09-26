"""
This module provides file and its dependencies take the .csv files from flight test and reduce the data into the pre-defined MOPs.
Here is what must be done prior to running this script:
1. Ensure that the flight test data is saved properly in a .csv file format using the proper naming convention.
2. Have either the even numbers or times associated with the scenarios flown.
"""

# import libraries
import numpy as np
import pandas as pd
from Utils.DataReduction import *
pd.options.mode.chained_assignment = None

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
    tasking_data = pd.read_csv('Data/Tasking/Tasking_{}_{}.csv'.format(lead_pilot, flight_number), low_memory=False)

    # Load Inputs
    input_data = pd.read_csv('Inputs/Input_{}_{}.csv'.format(lead_pilot, flight_number), low_memory=False)

    # Merge airspeed data into flight_data
    print('Merging airspeed data into DIS data...')
    flight_data = brute_force_merge_airspeed(flight_data, lead_airspeed_data, wing_airpseed_data) # this line takes a minute ...

    # Query the user to understand how many scenarios were flown in the flight
    # num_scenarios = len(input_data)
    input_data = input_data[input_data['Scenario_Num'].notna()]
    input_data['Scenario_Num'] = input_data['Scenario_Num'].astype(int)
    num_scenarios = input_data['Scenario_Num'].max()
    print(f"Detected {num_scenarios} scenarios in the input data.")

    # generate a blank dataframe to hold the MOPs
    mops_df = pd.DataFrame()

    # define sortie_df to hold all the data from the flight
    Altitude_Col = 'Altitude'
    cols_L29s = ['Timestamp', 'SampleDate', 'SampleTime', 'Configuration', 'Scenario', 'MarkingTxt', 'Heading', 'Roll',
                 'Latitude', 'Longitude', Altitude_Col]
    cols_CMs = ['Timestamp', 'SampleDate', 'SampleTime', 'Configuration', 'Scenario', 'MarkingTxt',
                'EntId', 'Latitude', 'Longitude', 'Heading']

    # Make sure Timestamp is sorted and in datetime format
    flight_data['Timestamp'] = pd.to_datetime(flight_data['Timestamp'])
    flight_data['SampleTime'] = pd.to_datetime(flight_data['SampleTime'])
    flight_data['SampleDate'] = pd.to_datetime(flight_data['SampleDate'])

    # OPL Naming Convention - Black is AMBUSH51, Blue is HAWK11
    # OPL Gouge - Black jet (AMBUSH51) DIS data is best.
    # OPL Convo - LinVels are in ECEF and m/s
    lead_data = flight_data[flight_data['MarkingTxt'] == 'AMBUSH51']
    wing_data = flight_data[flight_data['MarkingTxt'] == 'HAWK11']
    cruise_data = flight_data[flight_data['MarkingTxt'] == 'JASSM']
    sam_data = flight_data[flight_data['MarkingTxt'] == 'SAM']

    for scenario in range(1, num_scenarios + 1):
        print(f"Processing scenario {scenario} of {num_scenarios}...")

        scenario_type = input_data[input_data['Scenario_Num'] == scenario]['Scenario'].values[0]
        autonomy_config = input_data[input_data['Scenario_Num'] == scenario]['Configuration'].values[0]
        correct_sort = input_data[input_data['Scenario_Num'] == scenario]['Correct_Acquistion'].values[0]
        num_tac_comms = input_data[input_data['Scenario_Num'] == scenario]['Tac_Comms'].values[0]

        CM_airspeed = 150

        scenario_data = flight_data[(flight_data['Scenario'] == scenario_type) & (flight_data['Configuration'] == autonomy_config)].copy()
        scenario_start_time = scenario_data['SampleTime'].min()
        scenario_end_time = scenario_data['SampleTime'].max()
        print('Scenario Type: {}, Start Time: {}, End Time: {}'.format(scenario_type, scenario_start_time, scenario_end_time))
        if scenario_type == 'D':
            scenario_end_time = scenario_start_time + pd.DateOffset(minutes=7, second=15)  # Cap Delta scenarios at 7 minutes 15 seconds
            scenario_data = scenario_data[scenario_data['SampleTime'] <= scenario_end_time]
        # record the first lead_alt and wing_alt in the defined scenario
        lead_alt = scenario_data[scenario_data['MarkingTxt'] == 'AMBUSH51']['Altitude'].iloc[0]
        wing_alt = scenario_data[scenario_data['MarkingTxt'] == 'HAWK11']['Altitude'].iloc[0]
        
        num_CMs = scenario_data[scenario_data['MarkingTxt'] == 'JASSM']['EntId'].nunique()
        if scenario_type == 'D' and num_CMs > 6:
            num_CMs = 6
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
        if autonomy_config in ['HH', 'AH']:
            scenario_mops['Num_Tactical_Comms'] = num_tac_comms
        if autonomy_config in ['AA', 'HA']:
            scenario_mops['Num_Tactical_Comms'] = 0
        scenario_mops['Correct_Sort'] = correct_sort
        scenario_mops['Num_CMs'] = num_CMs
        scenario_mops['Lead_Altitude_MSL_ft'] = lead_alt
        scenario_mops['Wingman_Altitude_MSL_ft'] = wing_alt
        scenario_mops['CM_Airspeed_kt'] = CM_airspeed
        scenario_mops['Scenario_Start_Time'] = scenario_start_time

        # --- Altitude Deviation MOPs ---      
        alt_devs_lead = altitude_deviation(scenario_data, role='Lead', assigned_alt=int(lead_alt), alt_block_radius=500)
        alt_devs_wing = altitude_deviation(scenario_data, role='Wingman', assigned_alt=int(wing_alt), alt_block_radius=500)

        scenario_mops['Lead_Altitude_Deviation_Count'] = alt_devs_lead[0]
        scenario_mops['Wingman_Altitude_Deviation_Count'] = alt_devs_wing[0]
        scenario_mops['Lead_Altitude_Deviation_Integrated_ft_s'] = alt_devs_lead[1]
        scenario_mops['Wingman_Altitude_Deviation_Integrated_ft_s'] = alt_devs_wing[1]

        # --- Cruise Missile Intercept MOPs ---
        CM_time_to_intercept_dict = {}
        for cm_ID in CM_EntIds:
            # if within_cone is not empty:
            if is_within_cone(scenario_data, cm_index=cm_ID, role='Lead', scenario_alt=lead_alt, pbu_data=tasking_data) is not None:
                intercept_mops = is_within_cone(scenario_data, cm_index=cm_ID, role='Lead', scenario_alt=lead_alt, pbu_data=tasking_data)
                CM_time_to_intercept_dict[cm_ID] = intercept_mops['Time_to_Intercept_s_from_start']
            elif is_within_cone(scenario_data, cm_index=cm_ID, role='Wingman', scenario_alt=wing_alt, pbu_data=tasking_data) is not None:
                intercept_mops = is_within_cone(scenario_data, cm_index=cm_ID, role='Wingman', scenario_alt=wing_alt, pbu_data=tasking_data)
                CM_time_to_intercept_dict[cm_ID] = intercept_mops['Time_to_Intercept_s_from_start']
        
        CM_time_to_intercept_dict = dict(sorted(CM_time_to_intercept_dict.items(), key=lambda item: item[1]))
        total_CMs_intercepted = len(CM_time_to_intercept_dict)
        prop_CMs_intercepted = total_CMs_intercepted / num_CMs if num_CMs > 0 else 0
        scenario_mops['Total_CMs_Intercepted'] = total_CMs_intercepted
        scenario_mops['Proportion_CMs_Intercepted'] = prop_CMs_intercepted
        # iterate through the cm_s in order of time to intercept
        most_recent_lead_int_time = None
        most_recent_wing_int_time = None
        for i, (cm_ID, time_to_intercept) in enumerate(CM_time_to_intercept_dict.items(), start=1):
            if is_within_cone(scenario_data, cm_index=cm_ID, role='Lead', scenario_alt=lead_alt, pbu_data=tasking_data) is not None:
                intercept_mops = is_within_cone(scenario_data, cm_index=cm_ID, role='Lead', scenario_alt=lead_alt, pbu_data=tasking_data, previous_int_time=most_recent_lead_int_time, pilot=lead_pilot, flight_num=flight_number, scenario=scenario, config=autonomy_config)
                scenario_mops[f'CM{i}_EntId'] = cm_ID
                scenario_mops[f'CM{i}_Interceptor Role'] = intercept_mops['Interceptor Role']
                scenario_mops[f'CM{i}_Time_to_Intercept_s_from_start'] = intercept_mops['Time_to_Intercept_s_from_start']
                scenario_mops[f'CM{i}_MOP_Time_to_Intercept_s'] = intercept_mops['MOP_Time_to_Intercept_s']
                scenario_mops[f'CM{i}_MOP_Time_to_Consent_s'] = intercept_mops['Time_to_Consent_s']
                scenario_mops[f'CM{i}_Airspeed_at_Intercept_kt'] = intercept_mops['Airspeed_at_Intercept_kt']
                scenario_mops[f'CM{i}_Airspeed_Diff_at_Intercept_kt'] = intercept_mops['Airspeed_Diff_at_Intercept_kt']
                scenario_mops[f'CM{i}_Heading_at_Intercept_deg'] = intercept_mops['Heading_at_Intercept_deg']
                scenario_mops[f'CM{i}_CM_Heading_at_Intercept_deg'] = intercept_mops['CM_Heading_at_Intercept_deg']
                scenario_mops[f'CM{i}_Heading_Diff_at_Intercept_deg'] = intercept_mops['Heading_Diff_at_Intercept_deg']
                scenario_mops[f'CM{i}_Altitude_at_Intercept_ft'] = intercept_mops['Altitude_at_Intercept_ft']
                scenario_mops[f'CM{i}_Altitude_Offset_at_Intercept_ft'] = intercept_mops['Altitude_Offset_at_Intercept_ft']
                scenario_mops[f'CM{i}_Bank_Angle_at_Intercept_deg'] = intercept_mops['Bank_Angle_at_Intercept_deg']
                scenario_mops[f'CM{i}_Distance_from_CM_at_Intercept_nm'] = intercept_mops['Distance_from_CM_at_Intercept_nm']
                scenario_mops[f'CM{i}_Aspect_at_MELD_Range_deg'] = intercept_mops['Aspect_Angle_at_MELD_Entry_deg']
                most_recent_lead_int_time = intercept_mops['CM_Int_Time']


            elif is_within_cone(scenario_data, cm_index=cm_ID, role='Wingman', scenario_alt=wing_alt, pbu_data=tasking_data) is not None:
                intercept_mops = is_within_cone(scenario_data, cm_index=cm_ID, role='Wingman', scenario_alt=wing_alt, previous_int_time=most_recent_wing_int_time, pbu_data=tasking_data, pilot=lead_pilot, flight_num=flight_number)
                scenario_mops[f'CM{i}_EntId'] = cm_ID
                scenario_mops[f'CM{i}_Interceptor Role'] = intercept_mops['Interceptor Role']
                scenario_mops[f'CM{i}_Time_to_Intercept_s_from_start'] = intercept_mops['Time_to_Intercept_s_from_start']
                scenario_mops[f'CM{i}_MOP_Time_to_Intercept_s'] = intercept_mops['MOP_Time_to_Intercept_s']
                scenario_mops[f'CM{i}_MOP_Time_to_Consent_s'] = intercept_mops['Time_to_Consent_s']
                scenario_mops[f'CM{i}_Airspeed_at_Intercept_kt'] = intercept_mops['Airspeed_at_Intercept_kt']
                scenario_mops[f'CM{i}_Airspeed_Diff_at_Intercept_kt'] = intercept_mops['Airspeed_Diff_at_Intercept_kt']
                scenario_mops[f'CM{i}_Heading_at_Intercept_deg'] = intercept_mops['Heading_at_Intercept_deg']
                scenario_mops[f'CM{i}_CM_Heading_at_Intercept_deg'] = intercept_mops['CM_Heading_at_Intercept_deg']
                scenario_mops[f'CM{i}_Heading_Diff_at_Intercept_deg'] = intercept_mops['Heading_Diff_at_Intercept_deg']
                scenario_mops[f'CM{i}_Altitude_at_Intercept_ft'] = intercept_mops['Altitude_at_Intercept_ft']
                scenario_mops[f'CM{i}_Altitude_Offset_at_Intercept_ft'] = intercept_mops['Altitude_Offset_at_Intercept_ft']
                scenario_mops[f'CM{i}_Bank_Angle_at_Intercept_deg'] = intercept_mops['Bank_Angle_at_Intercept_deg']
                scenario_mops[f'CM{i}_Distance_from_CM_at_Intercept_nm'] = intercept_mops['Distance_from_CM_at_Intercept_nm']
                scenario_mops[f'CM{i}_Aspect_at_MELD_Range_deg'] = intercept_mops['Aspect_Angle_at_MELD_Entry_deg']
                most_recent_wing_int_time = intercept_mops['CM_Int_Time']

        # --- Define Scenario End Time, make it robust to terminate after picture is clean --- 
        max_cm_time = scenario_data[scenario_data['MarkingTxt'] == 'JASSM']['SampleTime'].max()
        if pd.notna(max_cm_time) and max_cm_time < scenario_end_time:
            scenario_end_time = max_cm_time
        scenario_duration = (scenario_end_time - scenario_start_time).total_seconds()
        scenario_mops['Scenario_End_Time'] = scenario_end_time
        scenario_mops['Scenario_Duration_s'] = scenario_duration

        # --- SAM Identification MOPs ---
        SAM_data = scenario_data[(scenario_data['MarkingTxt'] == 'SAM') & (scenario_data['SampleTime'] <= scenario_end_time) & (scenario_data['SampleTime'] >= scenario_start_time)]
        SAM_data['SampleTime'] = pd.to_datetime(SAM_data['SampleTime'])
        num_sams = SAM_data['EntId'].nunique()
        SAM_IDs = SAM_data['EntId'].unique()
        # SAMs_Identified = input(f"Enter the number of SAMs identified by the Lead in scenario {scenario}: ")
        SAMs_Identified = input_data[input_data['Scenario_Num'] == scenario]['SAMS_ID'].values[0]
        print(f'Scenario {scenario} has {num_sams} SAMs, Lead identified {SAMs_Identified}')
        scenario_mops['Num_SAMs'] = num_sams
        scenario_mops['SAMs_Identified_by_Lead'] = SAMs_Identified
        scenario_mops['Proportion_SAMs_Identified'] = int(SAMs_Identified) / num_sams if num_sams > 0 else 0
        bullseye_lat = 41.38494111111111
        bullseye_lon = -91.24627944444444
        # record the SAM_ID_Times as stamped in the CR.
        SAM_ID_Times = []
        for i in range(1, int(SAMs_Identified) + 1):
            SAM_ID_Times.append(input_data[input_data['Scenario_Num'] == scenario][f'SAM_{i}_ID_Time_s'].values[0])
            clean_time = SAM_ID_Times[-1]
            SAM_ID_Times[-1] = pd.to_datetime(f"{scenario_start_time.date()} {clean_time}", errors="coerce") + pd.DateOffset(hours=5) # convert to Zulu
        for i, sam_ID in enumerate(SAM_IDs, start=1):
            scenario_mops[f'SAM{i}_EntId'] = sam_ID
            SAM_spawn_time = SAM_data[SAM_data['EntId'] == sam_ID]['SampleTime'].min()
            SAM_spawn_date = SAM_spawn_time.date()
            scenario_mops[f'SAM{i}_Time_to_ID_s'] = 30
            # check to see if there is a SAM_ID_Time within SAM_spawn_time to SAM_spawn_time + 30s, replace time_to_ID_s if so
            for sam_id_time in SAM_ID_Times:
                if SAM_spawn_time <= sam_id_time <= (SAM_spawn_time + pd.DateOffset(seconds=30)):
                    scenario_mops[f'SAM{i}_Time_to_ID_s'] = (sam_id_time - SAM_spawn_time).total_seconds()

        # --- Tasking MOPs ---
        if autonomy_config == 'AA':
            tasking_data_scenario = tasking_data[(tasking_data['Scenario'] == scenario_type) & (tasking_data['Configuration'] == autonomy_config)].copy()
            if scenario_type == 'D':
                tasking_data_scenario = tasking_data_scenario[tasking_data_scenario['SampleTime'] <= scenario_end_time]
            subset = tasking_data_scenario.loc[
                tasking_data_scenario['ReceivingEntityID_Site'] == 73, 
                ['RequestID', 'RequestStatus']
            ]
            num_tasking_comms = subset.drop_duplicates().shape[0]
            scenario_mops['Num_Tactical_Comms'] += num_tasking_comms
        if autonomy_config == 'HA':
            tasking_data_scenario = tasking_data[(tasking_data['Scenario'] == scenario_type) & (tasking_data['Configuration'] == autonomy_config)].copy()
            if scenario_type == 'D':
                tasking_data_scenario = tasking_data_scenario[tasking_data_scenario['SampleTime'] <= scenario_end_time]
            subset = tasking_data_scenario.loc[
                tasking_data_scenario['ReceivingEntityID_Site'] == 73, 
                ['RequestID', 'RequestStatus']
            ]
            num_tasking_comms = subset.drop_duplicates().shape[0]            
            scenario_mops['Num_Tactical_Comms'] += num_tasking_comms

        mops_df = pd.concat([mops_df, pd.DataFrame([scenario_mops])], ignore_index=True)

    # Save MOPs to CSV
    mops_df.to_csv(f'{output_file_path}/MOPs_{lead_pilot}_Flight{flight_number}.csv', index=False)

    print(f"Data reduction complete. MOPs saved to {output_file_path}.")
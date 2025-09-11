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
from datetime import datetime, timedelta

# import custom modules
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
    flight_data = pd.read_csv('Data/Lead/Lead_{}_{}.csv'.format(lead_pilot, flight_number))
    # wing_data = pd.read_csv('Data/Wingman/Wing_{}_{}.csv'.format(lead_pilot, flight_number))
    # cruise_data = pd.read_csv('Data/CruiseMissiles/CMs_{}_{}.csv'.format(lead_pilot, flight_number))
    # workload_data = pd.read_csv('Data/Workload/Workload_{}_{}.csv'.format(lead_pilot, flight_number)) # ONLY USING BLACK DIS

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
        lead_alt = input(f"Enter Lead's assigned altitude (in feet, MSL) in scenario {scenario}: ")
        wing_alt = input(f"Enter Wingman's assigned altitude (in feet, MSL) in scenario {scenario}: ")
        CM_airspeed = 150

        scenario_data = flight_data[(flight_data['Scenario'] == scenario_type) & (flight_data['Configuration'] == autonomy_config)].copy()
        scenario_start_time = scenario_data['SampleTime'].min()
        scenario_end_time = scenario_data['SampleTime'].max()
        
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
        for cm_ID in CM_EntIds:
            is_within_cone(scenario_data, cm_index=cm_ID, role='Lead')
            is_within_cone(scenario_data, cm_index=cm_ID, role='Wingman')
    
    # Save MOPs to CSV
    # mops_df.to_csv(f'{output_file_path}/MOPs_{lead_pilot}_Flight{flight_number}.csv', index=False)

    print(f"Data reduction complete. MOPs saved to {output_file_path}.")
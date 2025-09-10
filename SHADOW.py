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
    lead_data = pd.read_csv('Data/Lead/Lead_{}_{}.csv'.format(lead_pilot, flight_number))
    wing_data = pd.read_csv('Data/Wingman/Wing_{}_{}.csv'.format(lead_pilot, flight_number))
    cruise_data = pd.read_csv('Data/CruiseMissiles/CMs_{}_{}.csv'.format(lead_pilot, flight_number))
    # workload_data = pd.read_csv('Data/Workload/Workload_{}_{}.csv'.format(lead_pilot, flight_number))

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
    lead_data['Timestamp'] = pd.to_datetime(lead_data['Timestamp'])
    wing_data['Timestamp'] = pd.to_datetime(wing_data['Timestamp'])
    cruise_data['Timestamp'] = pd.to_datetime(cruise_data['Timestamp'])

    lead_data = lead_data.sort_values('Timestamp')
    wing_data = wing_data.sort_values('Timestamp')
    cruise_data = cruise_data.sort_values('Timestamp')

    lead_data = lead_data[lead_data['MarkingTxt'] == 'HAWK11']
    wing_data = wing_data[wing_data['MarkingTxt'] == 'AMBUSH51']

    # Merge wing onto lead (treat lead as "truth")
    # This is necessary since the lead aircraft is the primary source of data and the timest stamps may not match perfectly.
    sortie_df = pd.merge_asof(
        lead_data[cols_L29s].sort_values('Timestamp'),
        wing_data[cols_L29s].sort_values('Timestamp'),
        on='Timestamp',
        direction='nearest',
        suffixes=('_Lead', '_Wing'),
        tolerance=pd.Timedelta('50ms')  # adjust tolerance as needed
    )

    # Merge cruise missiles the same way
    sortie_df = pd.merge_asof(
        sortie_df,
        cruise_data[cols_CMs].sort_values('Timestamp'),
        on='Timestamp',
        direction='nearest',
        suffixes=('', '_CM'),
        tolerance=pd.Timedelta('50ms')
    )

    for scenario in range(1, num_scenarios + 1):
        print(f"Processing scenario {scenario}...")

        # query the user for the scenario type and autonomy configuration
        scenario_type = input(f"Enter the type of scenario {scenario} (A, B, C, or D): ")
        assert scenario_type in ['A', 'B', 'C', 'D'], "Invalid scenario type. Please enter A, B, C, or D."
        autonomy_config = input(f"Enter the autonomy configuration for scenario {scenario} (HH, HA, AH, AA): ")
        assert autonomy_config in ['HH', 'HA', 'AH', 'AA'], "Invalid autonomy configuration. Please enter HH, HA, AH, or AA."
        num_CMs = 2 if scenario_type == 'A' else 5
        correct_sort = input(f"Did the wingman in scenario {scenario} intercept the correct cruise missiles? (Y/N): ")
        assert correct_sort in ['Y', 'N'], "Invalid input. Please enter Y or N."

        # Query the user for meta data: lead alt, wing alt, cruise missile airspeed
        lead_alt = input(f"Enter Lead's assigned altitude (in feet, MSL) in scenario {scenario}: ")
        wing_alt = input(f"Enter Wingman's assigned altitude (in feet, MSL) in scenario {scenario}: ")
        CM_airspeed = input(f"Enter Cruise Missile's assigned airspeed (in knots) in scenario {scenario}: ")

        # determine if the data exists in the .csvs as timestamps or event numbers
        time_or_event = input(f"Is scenario {scenario} data defined using timestamps or event numbers? (T/E): ")
        if time_or_event.upper() == 'T':
            # get start and end times
            start_time = input(f"Enter the start time for scenario {scenario} (HH:MM:SS.sss): ")
            end_time = input(f"Enter the end time for scenario {scenario} (HH:MM:SS.sss): ")
            scenario_data = sortie_df[(sortie_df['SampleTime'] >= start_time) & (sortie_df['SampleTime'] <= end_time)].copy()
            scenario_start_time = datetime.strptime(start_time, '%H:%M:%S.%f')
            scenario_end_time = datetime.strptime(end_time, '%H:%M:%S.%f')
        elif time_or_event.upper() == 'E':
            scenario_data = sortie_df[(sortie_df['Scenario'] == scenario_type) & (sortie_df['Configuration'] == autonomy_config)].copy()
            scenario_start_time = scenario_data['SampleTime'].min()
            scenario_end_time = scenario_data['SampleTime'].max()
            # convert both to datetime objects
            scenario_start_time = datetime.strptime(scenario_start_time, '%H:%M:%S.%f')
            scenario_end_time = datetime.strptime(scenario_end_time, '%H:%M:%S.%f')
        
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
        alt_devs = altitude_deviation(scenario_data, int(lead_alt), int(wing_alt), alt_block_radius=1000)
        scenario_mops['Lead_Altitude_Deviation_Count'] = alt_devs[0]
        scenario_mops['Wingman_Altitude_Deviation_Count'] = alt_devs[1]
        scenario_mops['Lead_Altitude_Deviation_Integrated_ft_s'] = alt_devs[2]
        scenario_mops['Wingman_Altitude_Deviation_Integrated_ft_s'] = alt_devs[3]

        print(scenario_mops) # DELETE ME WHEN DONE DEBUGGING

        # --- Cruise Missile Intercept MOPs ---
        for cm_index in range(1, num_CMs + 1):
            # first, generate a column for each CM for each aircraft (lead or wing) that indicates whether or not it is within the intercept criteria
            # TODO - WILL NEED TO MODIFY CM INDEX TO ACTUALLY MATCH WHAT IS IN THE DATA
            # TODO - 9 SEPTEMBER, CURRENT ISSUE LIES HERE!!!!
            scenario_data[f'Lead_Intercept_{cm_index}'] = is_within_cone(scenario_data, role='Lead')
            scenario_data[f'Wing_Intercept_{cm_index}'] = is_within_cone(scenario_data, role='Wing') # TODO: Add functionality to handle multiple CMs

            # determine which aircraft intercepted the CM and when
            lead_intercept_times = scenario_data[scenario_data[f'Lead_Intercept_{cm_index}']].copy()
            wing_intercept_times = scenario_data[scenario_data[f'Wing_Intercept_{cm_index}']].copy()
            if not lead_intercept_times.empty and wing_intercept_times.empty:
                lead_first_intercept = lead_intercept_times['Timestamp'].min()
                scenario_mops[f'CM{cm_index}_Intercept_Time'] = lead_first_intercept
                scenario_mops[f'CM{cm_index}_Time_to_Intercept_s'] = (lead_first_intercept - scenario_start_time).total_seconds()
                scenario_mops[f'CM{cm_index}_Intercepted_By'] = 'Lead'
            elif not wing_intercept_times.empty and lead_intercept_times.empty:
                wing_first_intercept = wing_intercept_times['Timestamp'].min()
                scenario_mops[f'CM{cm_index}_Intercept_Time'] = wing_first_intercept
                scenario_mops[f'CM{cm_index}_Time_to_Intercept_s'] = (wing_first_intercept - scenario_start_time).total_seconds()
                scenario_mops[f'CM{cm_index}_Intercepted_By'] = 'Wing'
            elif not lead_intercept_times.empty and not wing_intercept_times.empty:
                print(f"Both lead and wing intercepted the CM {cm_index}. Determining who intercepted first...")
                lead_first_intercept = lead_intercept_times['Timestamp'].min()
                wing_first_intercept = wing_intercept_times['Timestamp'].min()
                if lead_first_intercept < wing_first_intercept:
                    scenario_mops[f'CM{cm_index}_Intercept_Time'] = lead_first_intercept
                    scenario_mops[f'CM{cm_index}_Time_to_Intercept_s'] = (lead_first_intercept - scenario_start_time).total_seconds()
                    scenario_mops[f'CM{cm_index}_Intercepted_By'] = 'Lead'
                else:
                    scenario_mops[f'CM{cm_index}_Intercept_Time'] = wing_first_intercept
                    scenario_mops[f'CM{cm_index}_Time_to_Intercept_s'] = (wing_first_intercept - scenario_start_time).total_seconds()
                    scenario_mops[f'CM{cm_index}_Intercepted_By'] = 'Wing'
            else:
                print(f"No intercept detected for CM {cm_index}.")
                scenario_mops[f'CM{cm_index}_Intercepted_By'] = 'None'
            
            # determine terminal intercept conditions if an intercept occurred
            if scenario_mops[f'CM{cm_index}_Intercepted_By'] != 'None':
                intercept_role = scenario_mops[f'CM{cm_index}_Intercepted_By']
                intercept_events = scenario_data[scenario_data[f'{intercept_role}_Intercept_{cm_index}']].copy()
                # TODO - REWORK TERMINAL CONDITION ERROR CALCULATION
                terminal_conditions = terminal_condition_error(intercept_events, intercept_role, cm_index)
                scenario_mops[f'CM{cm_index}_Terminal_Pos_Error_ft'] = terminal_conditions['Distance_to_CM_nm']
                scenario_mops[f'CM{cm_index}_Terminal_Heading_Error_deg'] = terminal_conditions['Relative_Heading_deg']
                scenario_mops[f'CM{cm_index}_Terminal_Airspeed_Error_kt'] = terminal_conditions['Relative_Airspeed_kt']
                scenario_mops[f'CM{cm_index}_Terminal_Altitude_Error_ft'] = terminal_conditions['Relative_Altitude_ft']
            
        # determine the total proportion of cruise missiles intercepted
        intercepted_cms = [scenario_mops[f'CM{cm_index}_Intercepted_By'] for cm_index in range(1, num_CMs + 1)]
        scenario_mops['Total_CMs_Intercepted'] = sum(1 for x in intercepted_cms if x != 'None')
        scenario_mops['Proportion_CMs_Intercepted'] = scenario_mops['Total_CMs_Intercepted'] / num_CMs
        
        # TODO - Surface threat position error and percent identified
        # TODO - Communications MOPs (Update Score)
        # TODO - Time to Consent

        # add scenario MOPs to the overall MOPs dataframe
        mops_df = pd.concat([mops_df, pd.DataFrame([scenario_mops])], ignore_index=True)
    
    # Save MOPs to CSV
    mops_df.to_csv(f'{output_file_path}/MOPs_{lead_pilot}_Flight{flight_number}.csv', index=False)

    print(f"Data reduction complete. MOPs saved to {output_file_path}.")
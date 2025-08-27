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
    workload_data = pd.read_csv('Data/Workload/Workload_{}_{}.csv'.format(lead_pilot, flight_number))

    # Query the user for meta data: lead alt, wing alt, cruise missile airspeed
    lead_alt = input("Enter Lead's assigned altitude (in feet, MSL): ")
    wing_alt = input("Enter Wingman's assigned altitude (in feet, MSL): ")
    CM_airspeed = input("Enter Cruise Missile's assigned airspeed (in knots): ")

    # Query the user to understand how many scenarios were flown in the flight
    num_scenarios = int(input("Enter the number of scenarios flown in this flight: "))

    # generate a blank dataframe to hold the MOPs
    mops_df = pd.DataFrame()

    # define sortie_df to hold all the data from the flight
    Altitude_Col = 'Altitude_Msl'
    Airpseed_Col = 'True_Airspeed'
    cols_L29s = ['Timestamp', 'SampleDate', 'SampleTime', 'TestCard', 'True_Heading', 'Roll',
            'Latitude', 'Longitude', 'Vertical_Speed', Altitude_Col, Airpseed_Col]
    cols_CMs = ['Timestamp', 'SampleDate', 'SampleTime', 'TestCard', 'DisSource',
                'DisTime', 'Aplication', 'EntId', 'Latitude', 'Longitude', 'Heading']
    
    # Make sure Timestamp is sorted and in datetime format
    lead_data['Timestamp'] = pd.to_datetime(lead_data['Timestamp'])
    wing_data['Timestamp'] = pd.to_datetime(wing_data['Timestamp'])
    cruise_data['Timestamp'] = pd.to_datetime(cruise_data['Timestamp'])

    lead_data = lead_data.sort_values('Timestamp')
    wing_data = wing_data.sort_values('Timestamp')
    cruise_data = cruise_data.sort_values('Timestamp')

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
            event_number = input(f"Enter the event number for scenario {scenario}: ")
            scenario_data = sortie_df[sortie_df['TestCard_Lead'] == int(event_number)].copy()
            scenario_start_time = scenario_data['SampleTime'].min()
            scenario_end_time = scenario_data['SampleTime'].max()

        


    print(f"Data reduction complete. MOPs saved to {output_file_path}.")
# import data analysis libraries
import numpy as np
import pandas as pd
from datetime import datetime

def convert_to_datetime(df, time_col):
    """Convert time column to datetime objects."""
    df[time_col] = pd.to_datetime(df[time_col], format='%H:%M:%S.%f')
    return df
    
def altitude_deviation(df, role, assigned_alt, alt_block_radius=500):
    """
    Calculate altitude deviation from assigned altitude block. Inputs are:
    df: DataFrame containing scenario data
    lead_alt: assigned altitude for lead in feet
    wing_alt: assigned altitude for wingman in feet
    alt_block_radius: radius of altitude block in feet (default ±1000ft)
    """
    alt_col = 'Altitude'
    if role == 'Lead':
        marking = 'AMBUSH51'
    elif role == 'Wingman':
        marking = 'HAWK11'

    # define a block of altitudes +- 1000ft from assigned altitude
    block_min = assigned_alt - alt_block_radius
    block_max = assigned_alt + alt_block_radius
    
    # count the number of times in df where df[df['MarkingTxt']==marking][alt_col] is outside the block
    role_df = df[df['MarkingTxt'] == marking]
    role_df['Outside_Altitude_Block'] = (role_df[alt_col] < block_min) | (role_df[alt_col] > block_max)
    role_df['Block_Transition'] = role_df['Outside_Altitude_Block'].ne(role_df['Outside_Altitude_Block'].shift())
    altitude_violations = role_df[role_df['Block_Transition'] & role_df['Outside_Altitude_Block']]
    num_violations = altitude_violations.shape[0]

    # integrate the altitude deviation over time - sum the altitude deviation from block multiplied by the time in seconds
    role_df['Altitude_Deviation'] = np.where(role_df[alt_col] < block_min, block_min - role_df[alt_col],
                                            np.where(role_df[alt_col] > block_max, role_df[alt_col] - block_max, 0))
    role_df['Time_Diff'] = role_df['Timestamp'].diff().dt.total_seconds().fillna(0)
    altitude_deviation_integral = (role_df['Altitude_Deviation'] * role_df['Time_Diff']).sum()

    return num_violations, altitude_deviation_integral


def is_within_cone(scenario_data, cm_index, role):
    """
    Determine if an aircraft (lead/wingman) is within intercept criteria:
      1) Bank angle within ±10°
      2) Within 1.5 nm aft of CM
      3) Within 30° trailing cone of CM velocity vector
      4) Heading within ±20° of CM heading
    Inputs:
    df: DataFrame containing scenario data
    cm_index: index of the CM being intercepted
    role: 'Lead' or 'Wingman'
    Returns a boolean Series indicating if the aircraft meets all criteria for a given timestamp and cm.
    """

    # for every entry in scenario_data['EntId']==cm_index, get the nearest entry in scenario_data['MarkingTxt']==role
    if role == 'Lead':
        marking = 'AMBUSH51'
    elif role == 'Wingman':
        marking = 'HAWK11'

    df_cm = scenario_data[scenario_data['EntId'] == cm_index].copy()
    df_ac = scenario_data[scenario_data['MarkingTxt'] == marking].copy()
    df = pd.merge_asof(df_ac.sort_values('Timestamp'), df_cm.sort_values('Timestamp'), on='Timestamp', suffixes=('_ac', '_cm'))
    df = df.dropna(subset=['EntId_cm'])  # drop rows where no matching CM data
    if df.empty:
        return pd.Series([False]*len(scenario_data), index=scenario_data.index)

    # relevant columns
    lat_col = 'Latitude_ac'
    lon_col = 'Longitude_ac'
    alt_col = 'Altitude_ac'
    heading_col = 'Heading_ac'
    cm_lat_col = 'Latitude_cm'
    cm_lon_col = 'Longitude_cm'
    cm_alt_col = 'Altitude_cm'
    cm_heading_col = 'Heading_cm'
    bank_col = 'Roll_ac'

    # get the SampleTime where the cm_index is last seen
    cm_last_time = df_cm['SampleTime'].max()

    # --- CONDITION 1: Bank Angle ---
    # THIS CONDITION IS MORE STRESSING THAN WE THOUGHT - MAY NEED TO RELAX
    cond1 = df[bank_col].abs() <= 10
    df['Bank_Angle_Condition'] = cond1
    
    # --- CONDITION 2: Aft + Distance ---
    # Flat-earth approximation in nautical miles
    dlat = (df[lat_col] - df[cm_lat_col]) * 60.0    # nm
    dlon = (df[lon_col] - df[cm_lon_col]) * 60.0 * np.cos(np.radians(df[cm_lat_col]))
    # Distance between aircraft and CM
    df['distance_nm'] = np.sqrt(dlat**2 + dlon**2)
    cond2 = df['distance_nm'] <= 1.5
    df['Distance_Condition'] = cond2
    
    # --- CONDITION 3a: Inside trailing cone VELOCITY ---
    vel_vector_cm = np.column_stack([df['LinVelX_cm'], df['LinVelY_cm'], df['LinVelZ_cm']])
    vel_vector_ac = np.column_stack([df['LinVelX_ac'], df['LinVelY_ac'], df['LinVelZ_ac']])
    dot = np.sum(vel_vector_cm * vel_vector_ac, axis=1)
    angle_between_vec = np.degrees(np.arccos(np.clip(dot / (np.linalg.norm(vel_vector_cm, axis=1) * np.linalg.norm(vel_vector_ac, axis=1)), -1, 1)))
    df['angle_between_vel'] = angle_between_vec
    cond_vel = angle_between_vec <= 30

    # --- CONDITION 3b: Inside trailing cone POSITION ---
    # Angle between CM heading vector and relative position vector
    # use EcefX_ac, EcefY_ac, EcefZ_ac and EcefX_cm, EcefY_cm, EcefZ_cm for the position vectors
    pos_vector_ac = np.column_stack([df['EcefX_ac'], df['EcefY_ac'], df['EcefZ_ac']])
    pos_vector_cm = np.column_stack([df['EcefX_cm'], df['EcefY_cm'], df['EcefZ_cm']])
    rel_pos = pos_vector_cm - pos_vector_ac
    dot = np.sum(rel_pos * vel_vector_cm, axis=1)
    angle_between_pos = np.degrees(np.arccos(np.clip(dot / (np.linalg.norm(rel_pos, axis=1) * np.linalg.norm(vel_vector_cm, axis=1)), -1, 1)))
    df['angle_between_pos'] = angle_between_pos
    cond3 = angle_between_pos <= 30
    df['Cone_Condition'] = cond3

    intercept_criteria = cond2 & cond3 # Q: INCLUDE COND_VEL?
    df['Intercept_Criteria'] = intercept_criteria

    if intercept_criteria.any():
        # get the min SampleTime where intercept_criteria is True
        cm_int_time = df['SampleTime_cm'][intercept_criteria].min()
        print(f"{role} meets intercept criteria for CM {cm_index} at {cm_int_time}")
        print('This CM disappears at', cm_last_time)
        print('Time to kill:', (cm_last_time - cm_int_time).total_seconds(), 'seconds')
        # save df to csv for debugging
        df.to_csv(f'{role}_CM{cm_index}_intercept_debug.csv', index=False)

    # --- Combine all conditions ---
    return intercept_criteria


def terminal_condition_error(df, role, CM_index):
    """
    Calculate terminal condition error for interception events. This includes relative altitude, heading, airspeed, and distance behind the CM at the moment of interception.
    Inputs:
    df: DataFrame containing scenario data
    role: 'Lead' or 'Wingman'
    CM_index: index of the CM being intercepted
    Returns a DataFrame summarizing the terminal conditions at interception events.
    """

    intercept_col = f'{role}_Intercept_{CM_index}'
    
    # filter to only interception events
    intercept_events = df[df[intercept_col]]
    
    # record the intercepting aircraft, its altitude, airspeed, and distance to CM at the moment of interception
    if intercept_events.empty:
        return None
    else:
        alt_col = f'Altitude_{role}'
        airspeed_col = f'True_Airspeed_{role}'
        
        # Calculate distance to CM
        R = 3440.065
        lat_ac = np.radians(intercept_events[f'Latitude_{role}'])
        lon_ac = np.radians(intercept_events[f'Longitude_{role}'])
        lat_cm = np.radians(intercept_events[f'Latitude_{CM_index}'])
        lon_cm = np.radians(intercept_events['Longitude_CM_index'])
        dlat = lat_ac - lat_cm
        dlon = lon_ac - lon_cm
        dx = R * np.cos(lat_cm) * dlon
        dy = R * dlat
        dz = (intercept_events[alt_col] - intercept_events[f'CM_Altitude_{role}']) / 6076.12
        distance_to_cm = np.sqrt(dx**2 + dy**2 + dz**2)

        # calculate relative altitude, heading, airspeed
        rel_altitude = intercept_events[alt_col] - intercept_events[f'CM_Altitude_{role}']
        rel_heading = intercept_events[f'True_Heading_{role}'] - intercept_events[f'Heading_{CM_index}']
        rel_airspeed = intercept_events[airspeed_col] - intercept_events[f'CM_Airspeed']

        intercept_summary = pd.DataFrame({
            'Timestamp': intercept_events['Timestamp'],
            'Relative_Altitude_ft': rel_altitude,
            'Relative_Heading_deg': rel_heading,
            'Relative_Airspeed_kt': rel_airspeed,
            'Distance_to_CM_nm': distance_to_cm
        })
        
        return intercept_summary



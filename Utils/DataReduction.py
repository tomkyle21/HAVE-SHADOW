# import data analysis libraries
import numpy as np
import pandas as pd
pd.options.mode.chained_assignment = None

def convert_to_datetime(df, time_col):
    """Convert time column to datetime objects."""
    df[time_col] = pd.to_datetime(df[time_col])
    return df

def brute_force_merge_airspeed(df, airspeed_df_lead, airspeed_df_wing):
    """
    For each row in df, find the nearest SampleTime in the appropriate
    airspeed dataframe (lead or wing) and copy over Calibrated_Airspeed.
    Returns df with a new column 'CalibratedAirspeed'.
    """

    # Ensure datetime
    df['SampleTime'] = pd.to_datetime(df['SampleTime'])
    airspeed_df_lead['SampleTime'] = pd.to_datetime(airspeed_df_lead['SampleTime'])
    airspeed_df_wing['SampleTime'] = pd.to_datetime(airspeed_df_wing['SampleTime'])

    # Sort
    df = df.sort_values('SampleTime').reset_index(drop=True)
    airspeed_df_lead = airspeed_df_lead.sort_values('SampleTime').reset_index(drop=True)
    airspeed_df_wing = airspeed_df_wing.sort_values('SampleTime').reset_index(drop=True)

    # Add column
    df['CalibratedAirspeed'] = np.nan

    # --- Lead (AMBUSH51) ---
    mask_lead = df['MarkingTxt'] == 'AMBUSH51'
    for idx in df[mask_lead].index:
        t = df.at[idx, 'SampleTime']
        diffs = (airspeed_df_lead['SampleTime'] - t).abs()
        nearest_idx = diffs.idxmin()
        df.at[idx, 'CalibratedAirspeed'] = airspeed_df_lead.at[nearest_idx, 'Calibrated_Airspeed']

    # --- Wingman (HAWK11) ---
    mask_wing = df['MarkingTxt'] == 'HAWK11'
    for idx in df[mask_wing].index:
        t = df.at[idx, 'SampleTime']
        diffs = (airspeed_df_wing['SampleTime'] - t).abs()
        nearest_idx = diffs.idxmin()
        df.at[idx, 'CalibratedAirspeed'] = airspeed_df_wing.at[nearest_idx, 'Calibrated_Airspeed']

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


def is_within_cone(scenario_data, cm_index, role, scenario_alt, pbu_data, previous_int_time=None):
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

    # TODO - Intercept criteria to be graded at kill (as shown in PBU)
    # TODO - Kill defn defined to be using PBU
    # TODO - Entering the cone define to be the last time the AC enters the cone before the kill time

    # for every entry in scenario_data['EntId']==cm_index, get the nearest entry in scenario_data['MarkingTxt']==role
    if role == 'Lead':
        marking = 'AMBUSH51'
        pbu_id = 48
    elif role == 'Wingman':
        marking = 'HAWK11'
        pbu_id = 73


    df_cm = scenario_data[scenario_data['EntId'] == cm_index].copy()
    df_ac = scenario_data[scenario_data['MarkingTxt'] == marking].copy()
    # df = pd.merge_asof(df_ac.sort_values('Timestamp'), df_cm.sort_values('Timestamp'), on='Timestamp', suffixes=('_ac', '_cm'),
    #                    tolerance=pd.Timedelta("1ms"),  direction='nearest')
    df = pd.merge_asof(
    df_cm.sort_values('Timestamp'), 
    df_ac.sort_values('Timestamp'),   
    on='Timestamp',
    suffixes=('_cm', '_ac'),
    tolerance=pd.Timedelta("300ms"),
    direction='nearest'
) # this merge limits data, but is necessary to avoid cm time slippage

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

    # get the scenario start time
    scenario_data['SampleTime'] = pd.to_datetime(scenario_data['SampleTime']) 
    pbu_data['SampleTime'] = pd.to_datetime(pbu_data['SampleTime'])  
    scenario_start_time = scenario_data['SampleTime'].min()

    # get the SampleTime where the cm_index is last seen
    cm_last_time = df_cm['SampleTime'].max()

    # --- CONDITION NO LONGER USED!!: Bank Angle ---
    cond_bank = df[bank_col].abs() <= 10
    df['Bank_Angle_Condition'] = cond_bank
    
    # --- CONDITION 1: Aft + Distance ---
    # Flat-earth approximation in nautical miles
    dlat = (df[lat_col] - df[cm_lat_col]) * 60.0    # nm
    dlon = (df[lon_col] - df[cm_lon_col]) * 60.0 * np.cos(np.radians(df[cm_lat_col]))
    # Distance between aircraft and CM
    df['distance_nm'] = np.sqrt(dlat**2 + dlon**2)
    cond1 = df['distance_nm'] <= 1.5
    df['Distance_Condition'] = cond1
    
    # --- CONDITION NOT USED - NICE TO HAVE: Inside trailing cone VELOCITY ---
    vel_vector_cm = np.column_stack([df['LinVelX_cm'], df['LinVelY_cm'], df['LinVelZ_cm']])
    vel_vector_ac = np.column_stack([df['LinVelX_ac'], df['LinVelY_ac'], df['LinVelZ_ac']])
    dot = np.sum(vel_vector_cm * vel_vector_ac, axis=1)
    angle_between_vec = np.degrees(np.arccos(np.clip(dot / (np.linalg.norm(vel_vector_cm, axis=1) * np.linalg.norm(vel_vector_ac, axis=1)), -1, 1)))
    df['angle_between_vel'] = angle_between_vec
    cond_vel = angle_between_vec <= 30

    # --- CONDITION 2: Inside trailing cone POSITION ---
    pos_vector_ac = np.column_stack([df['ECEF_X_ac'], df['ECEF_Y_ac'], df['ECEF_Z_ac']])
    pos_vector_cm = np.column_stack([df['ECEF_X_cm'], df['ECEF_Y_cm'], df['ECEF_Z_cm']])
    rel_pos = pos_vector_cm - pos_vector_ac
    dot = np.sum(rel_pos * vel_vector_cm, axis=1)
    angle_between_pos = np.degrees(np.arccos(np.clip(dot / (np.linalg.norm(rel_pos, axis=1) * np.linalg.norm(vel_vector_cm, axis=1)), -1, 1)))
    df['angle_between_pos'] = angle_between_pos
    cond2 = angle_between_pos <= 30
    df['Cone_Condition'] = cond2

    # --- CONDITION 3: Inside nose cone POSITION ---
    dot = np.sum(rel_pos * vel_vector_ac, axis=1)
    angle_between_pos_nose = np.degrees(np.arccos(np.clip(dot / (np.linalg.norm(rel_pos, axis=1) * np.linalg.norm(vel_vector_ac, axis=1)), -1, 1)))
    df['angle_between_pos_nose'] = angle_between_pos_nose
    cond3 = angle_between_pos_nose <= 30
    df['Nose_Cone_Condition'] = cond3

    intercept_criteria = cond1 & cond2 & cond3
    df['Intercept_Criteria'] = intercept_criteria

    if intercept_criteria.any():
        # --- SCENARIO META DATA ---
        # get the calibrated airspeed at the time of intercept
        # airspeed_at_intercept = df.loc[intercept_criteria, 'CalibratedAirspeed_ac'].values[0]
        # heading_at_intercept = df.loc[intercept_criteria, heading_col].values[0]
        # cm_heading_at_intercept = df.loc[intercept_criteria, cm_heading_col].values[0]
        # heading_diff_at_intercept = (heading_at_intercept - cm_heading_at_intercept + 180) % 360 - 180
        # altitude_at_intercept = df.loc[intercept_criteria, alt_col].values[0]
        # alt_offset_at_intercept = np.abs(altitude_at_intercept - scenario_alt)
        # airspeed_diff_at_intercept = airspeed_at_intercept - df.loc[intercept_criteria, 'CM_Airspeed_ac'].values[0]
        # bank_angle_at_intercept = df.loc[intercept_criteria, bank_col].values[0]
        # distance_from_cm_at_intercept = df.loc[intercept_criteria, 'distance_nm'].values[0]

        # 3 cases
        pbu_kill_data = pbu_data[pbu_data['PduType'] == 'KILL']
        # case 1 - FiringEntityID_Site matches pbu_id and TargetEntityID_Entity matches cm_index
        if pbu_kill_data[(pbu_kill_data['FiringEntityID_Site']==pbu_id) & (pbu_kill_data['TargetEntityID_Entity']==cm_index)].shape[0] > 0:
            cm_kill_time = pbu_kill_data[(pbu_kill_data['FiringEntityID_Site']==pbu_id) & (pbu_kill_data['TargetEntityID_Entity']==cm_index)]['SampleTime'].min()
            cm_kill_time = pd.to_datetime(cm_kill_time)
        # case 2 - FiringEntityID_Site matches pbu_id, but there is no TargetEntityID_Entity match
        elif pbu_kill_data[(pbu_kill_data['FiringEntityID_Site']==pbu_id)].shape[0] > 0:
            # find the closest SampleTime in pbu_kill_data to cm_last_time where FiringEntityID_Site matches pbu_id
            kill_times = pbu_kill_data[pbu_kill_data['FiringEntityID_Site']==pbu_id]['SampleTime']
            kill_times = pd.to_datetime(kill_times)
            diffs = (kill_times - cm_last_time).abs()
            nearest_idx = diffs.idxmin()
            cm_kill_time_potential = kill_times.loc[nearest_idx]
            if (cm_kill_time_potential - cm_last_time).total_seconds() <= 10: # make sure the kill time is within 10 seconds of last seen time
                cm_kill_time = cm_kill_time_potential
            else:
                cm_kill_time = cm_last_time
        else:
            cm_kill_time = cm_last_time
        
        # instead, define the intercept parameters at the time of kill
        df_at_kill = df[df['SampleTime_ac'] <= cm_kill_time]
        df_at_kill = df_at_kill.reset_index(drop=True)
        # airspeed at intercept is the 'CalibratedAirspeed_ac' at the max SampleTime_ac 
        airspeed_at_intercept = df_at_kill.loc[df_at_kill['SampleTime_ac'].idxmax(), 'CalibratedAirspeed_ac']
        heading_at_intercept = df_at_kill.loc[df_at_kill['SampleTime_ac'].idxmax(), heading_col]
        cm_heading_at_intercept = df_at_kill.loc[df_at_kill['SampleTime_ac'].idxmax(), cm_heading_col]
        heading_diff_at_intercept = (heading_at_intercept - cm_heading_at_intercept + 180) % 360 - 180
        altitude_at_intercept = df_at_kill.loc[df_at_kill['SampleTime_ac'].idxmax(), alt_col]
        alt_offset_at_intercept = np.abs(altitude_at_intercept - scenario_alt)
        airspeed_diff_at_intercept = airspeed_at_intercept - df_at_kill.loc[df_at_kill['SampleTime_ac'].idxmax(), 'CM_Airspeed_ac']
        bank_angle_at_intercept = df_at_kill.loc[df_at_kill['SampleTime_ac'].idxmax(), bank_col]
        distance_from_cm_at_intercept = df_at_kill.loc[df_at_kill['SampleTime_ac'].idxmax(), 'distance_nm']

        # define cm_int time as the most recent time the intercept criteria turned true before the kill time
        df_before_kill = df[df['SampleTime_ac'] <= cm_kill_time]
        df_before_kill = df_before_kill.reset_index(drop=True)
        df_before_kill['Intercept_Transition'] = df_before_kill['Intercept_Criteria'].ne(df_before_kill['Intercept_Criteria'].shift())
        if df_before_kill['Intercept_Transition'].any():
            cm_int_time = df_before_kill[df_before_kill['Intercept_Transition'] & df_before_kill['Intercept_Criteria']]['SampleTime_ac'].max()
        else:
            # if cm_int_time = df['SampleTime_ac'][intercept_criteria].min() is not NaT, then make it that
            if not df[df['Intercept_Criteria']]['SampleTime_ac'].min() is pd.NaT:
                cm_int_time = df[df['Intercept_Criteria']]['SampleTime_ac'].min()
            else:
                cm_int_time = cm_kill_time

    
        # Define MELD range
        meld_range = 2.5

        # process the meld range in the lookback_df
        lookback_df = df.copy() 
        lookback_df['In_Meld_Range'] = lookback_df['distance_nm'] <= meld_range
        if previous_int_time is not None:
            previous_int_time = pd.to_datetime(previous_int_time)
            meld_transition_time = lookback_df[lookback_df['In_Meld_Range']]['SampleTime_ac'].min()
            meld_transition_time = max(meld_transition_time, previous_int_time)
        elif previous_int_time is None:
            meld_transition_time = lookback_df[lookback_df['In_Meld_Range']]['SampleTime_ac'].min()

        MOP_time_to_intercept = (cm_kill_time - meld_transition_time).total_seconds()
        aspect_angle_at_meld = lookback_df.iloc[(lookback_df['SampleTime_ac'] - meld_transition_time).abs().argsort()[:1]]['angle_between_vel'].values[0] # to make it closest
        # aspect_angle_at_meld = lookback_df[lookback_df['SampleTime_ac'] == meld_transition_time]['angle_between_vel'].values[0] 
        aspect_angle_at_meld = np.abs((aspect_angle_at_meld + 180) % 360 - 180) # set to 180°
        
        # print meld_transition_time, cm_int_time, cm_kill_time, and cm_last_time
        print(f'Starting CM Index: {cm_index}, Role: {role}')
        print("Meld Transition Time:", meld_transition_time)
        print("CM Intercept Time:", cm_int_time)
        print("CM Kill Time:", cm_kill_time)
        print("CM Last Seen Time:", cm_last_time)

        # define a dictionary that records the intercept event
        intercept_event = {
            'Interceptor Role': role,
            'CM_Index': cm_index,
            'Intercept_Time': cm_int_time,
            'Time_to_Consent_s': (cm_kill_time - cm_int_time).total_seconds(),
            'Time_to_Intercept_s_from_start': (cm_kill_time - scenario_start_time).total_seconds(),
            'Airspeed_at_Intercept_kt': airspeed_at_intercept,
            'Airspeed_Diff_at_Intercept_kt': airspeed_diff_at_intercept,
            'Heading_at_Intercept_deg': heading_at_intercept,
            'CM_Heading_at_Intercept_deg': cm_heading_at_intercept,
            'Heading_Diff_at_Intercept_deg': heading_diff_at_intercept,
            'Altitude_at_Intercept_ft': altitude_at_intercept,
            'Altitude_Offset_at_Intercept_ft': alt_offset_at_intercept,
            'Bank_Angle_at_Intercept_deg': bank_angle_at_intercept,
            'Distance_from_CM_at_Intercept_nm': distance_from_cm_at_intercept,
            'CM_Kill_Time': cm_kill_time,
            'MOP_Time_to_Intercept_s': MOP_time_to_intercept,
            'Aspect_Angle_at_MELD_Entry_deg': aspect_angle_at_meld,
            'CM_Int_Time': cm_int_time
        }

        return intercept_event

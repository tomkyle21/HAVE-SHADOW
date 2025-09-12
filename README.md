# HAVE-SHADOW
This repository will serve as the comprehensive code and data base for the HAVE SHADOW TMP as part of USAF TPS class 25A.

The SHADOW.py file contains the main script that converts raw flight test data to MOPs. The Utils folder contains scripts with data reduction functions, and the SHADOW.py folder utilizes these extensively.

 The Inputs file contains the required inputs for a given sortie, and the Output folder contains the outputs of the SHADOW.py script, which includes all relevant MOPs for all scenarios flown in a given sortie.

The only required packages are numpy and pandas, so this should be able to run on a government laptop. 

INSTRUCTIONS FOR USE OF SHADOW.py:

1 - Save data in proper locations using the proper nomenclature:
	1a - Save the flight's dis_entity_state table for the lead aircraft only into the Data -> Lead folder. 	       Save using the convention 	Lead_Pilot_Flight.csv where Pilot is the pilot's last name with the 	       first letter capitalized, and the Flight is just the sortie number for the campaign (1 sortie is 1 	       flight for each in the 2-ship)
	1b - Save the flight's raw DAS data (located in the  vdn_flight_state table) in the Lead's folder using 	       the same naming convention. Do the same for the wingman's DAS data, using the same exact 	       naming convention for this file as well (use the lead pilot's name even though it is wingman 	       data).
	1b - Save the proper Inputs into a CSV file in the Inputs folder using the same naming convention. 	       For this step, you will need the following: Lead Pilot Name (the way it was entered for saving 	       the files), flight number (diddo), each scenario / configuration flown (a scenario will have it's 	       own row in Input_Pilot_Flight.csv), whether or not wing had the correct target acquisition (Y/N), 	       # of tactical comms, the # of SAMs Identified, and the timestamps for each SAM that was 	            	       identified. 

2 - Press play on SHADOW.py, and expect to input the Pilot's last name (as entered for saving data) and the flight number (diddo).

3 - Ensure the MOPs.csv was saved to the output folder.

Done (for now) :) 


Subject Number Mapping:
1(48): Chuck
2: Indy
3: Tars
4(74): FOD
5: Frodo
6: Elvis
7: Flash
8: Mach



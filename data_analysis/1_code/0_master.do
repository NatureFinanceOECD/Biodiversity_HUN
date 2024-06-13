* Version: 1.1
* Runs on: Stata/MP 18.0

* Master do-file
	* Created: 12/03/2024
	* Last modified: 29/05/2024
	
* Summary: This do-file is the master do-file for the project on the implementation of the Supervisory Framework for Assessing Nature-related Financial Risks for the Hungarian financial system. It runs the other do-files.

********************************************************************************
* PART 0: TABLE OF CONTENTS
********************************************************************************

*	1) SET DIRECTORIES

*	2) SELECT PROCESS

*	3) EXECUTION

********************************************************************************
* PART 1: SET DIRECTORIES
********************************************************************************

* User 1
	if c(username) == "gulersoy_g" {
		global path = "V:\BIODIVERSITY_HUN\sandbox\data_analysis"
		global rawdata = "$path\0_rawdata"
		global code = "$path\1_code"
		global processed = "$path\3_processeddata"
		global output = "$path\4_output"
	}
	
* User 2
	/*
	if c(username) == "" {
		global path = ""
		global rawdata = "$path\0_rawdata"
		global code = "$path\1_code"
		global processed = "$path\3_processeddata"
		global output = "$path\4_output"
	}
	*/
	
********************************************************************************
* PART 2: SELECT PROCESS
********************************************************************************

	* 2.1) MNB Cleaning
		local mnb_cleaning = 0
		
	* 2.2) NACE Impacts Dependencies
		local nace_impacts_dependencies = 0
		
	* 2.3) Exiobase Impacts Dependencies
		local exiobase_impacts_dependencies = 1
		
	* 2.4) Exiobase Cleaning
		local exiobase_cleaning = 1
		
	* 2.5) Exiobase Cleaning Sector
		local exiobase_cleaning_sector = 1
		
	* 2.6) Figaro Cleaning
		local figaro_cleaning = 1
		
	* 2.7) Identification and Prioritisation
		local identif_and_priorit = 1
		
	* 2.8) Economic Risk Assessment
		local econ_risk_ass = 1
		
	* 2.9) Financial Risk Assessment
		local fina_risk_ass = 1


********************************************************************************
* PART 3: EXECUTION
********************************************************************************

	* 3.1) MNB Cleaning
		if `mnb_cleaning' == 1 {
			do "$code/1_mnb_cleaning"
		}
		
	* 3.2) NACE Impacts Dependencies
		if `nace_impacts_dependencies' == 1 {
			do "$code/2_nace_impacts_dependencies"
		}
		
	* 3.3) Exiobase Impacts Dependencies
		if `exiobase_impacts_dependencies' == 1 {
			do "$code/3_exiobase_impacts_dependencies"
		}
		
	* 3.4) Exiobase Cleaning
		if `exiobase_cleaning' == 1 {
			do "$code/4_exiobase_cleaning"
		}
	
	* 3.5) Exiobase Cleaning Sector
		if `exiobase_cleaning_sector' == 1 {
			do "$code/5_exiobase_cleaning_sector"
		}

	* 3.6) Figaro Cleaning
		if `figaro_cleaning' == 1 {
			do "$code/6_figaro_cleaning"
		}

	* 3.7) Identification and Prioritisation
		if `identif_and_priorit' == 1 {
			do "$code/7_identification_and_prioritisation"
		}

	* 3.8) Economic Risk Assessment
		if `econ_risk_ass' == 1 {
			do "$code/8_economic_risk_assessment"
		}

	* 3.9) Financial Risk Assessment
		if `fina_risk_ass' == 1 {
			do "$code/9_financial_risk_assessment"
		}










* Version: 1.1
* Runs on: Stata/MP 18.0

* MNB data cleaning
	* Created: 19/09/2023
	* Last modified: 29/05/2024
	
* Summary: This do-file cleans the "instruments" and "collaterals" data sent by the MNB.

********************************************************************************
* PART 0: TABLE OF CONTENTS
********************************************************************************

*	1) SETUP

*	2) INSTRUMENTS

*	3) COLLATERALS

********************************************************************************
* PART 1: SETUP
********************************************************************************

/*
	if c(username) == "gulersoy_g" {
		global path = "G:\Biodiversity\data_analysis"
		global rawdata = "$path\0_rawdata"
		global code = "$path\1_code"
		global processed = "$path\3_processeddata"
		global output = "$path\4_output"
	}
*/

clear
cd "$path"
set type double
	
********************************************************************************
* PART 2: INSTRUMENTS
********************************************************************************
{
	
* 2.1) General cleaning

	* Import
		import sas using "$rawdata/MNB/Instruments", clear
		
	* Label variables
		label	 	var	 	VONATKOZAS	 	"Period"
		label	 	var	 	TECHNIKAI_SEGEDOSZLOP	 	"Technical column on entity type"
		label		var		INSTR_AZON_MD5	 	"Instrument identifier with MD5 function"
		label		var		SZERZ_LEJ_NAP	 	"The date of expiry of the instrument fixed in the contract"
		label		var		H_LEJ_KOD	 	"Remaining maturity"
		label		var		TIP_KOD	 	"Instrument type"
		label		var		HIT_JELLEG_KOD	 	"Loan type"
		label		var		FED_HIT_KOD	 	"Is the instrument collateralised?"
		label		var		INST_OSSZEG	 	"Sum of instrument"
		label		var		INST_DEV	 	"Sum of instrument - currency"
		label		var		AKT_KITETT_ERTEK	 	"Current (balance sheet) exposure value"
		label		var		AKT_KITETT_DEV	 	"Current (balance sheet) exposure value - currency"
		label		var		FENNALLO_TOKE_OSSZEG	 	"Outstanding capital amount"
		label		var		FENNALLO_TOKE_DEV	 	"Outstanding capital amount - currency"
		label		var		SZERZ_KAMATLAB	 	"Interest rate by contract (starting rate)"
		label		var		REF_KAMAT_KOD	 	"Reference rate"
		label		var		UGYF_JELLEG_KOD	 	"Type of customer"
		label		var		ORSZ_KOD	 	"Nationality"
		label		var		JARAS	 	"District"
		label		var		MEGYE	 	"County"
		label		var		AGAZAT_KOD	 	"NACE4 code"
		label		var		SZAKAGAZAT_4ES_SZINT	 	"NACE4 description"
		
	* Rename variables
		rename (VONATKOZAS TECHNIKAI_SEGEDOSZLOP INSTR_AZON_MD5 SZERZ_LEJ_NAP H_LEJ_KOD TIP_KOD HIT_JELLEG_KOD FED_HIT_KOD INST_OSSZEG INST_DEV AKT_KITETT_ERTEK AKT_KITETT_DEV FENNALLO_TOKE_OSSZEG FENNALLO_TOKE_DEV SZERZ_KAMATLAB REF_KAMAT_KOD UGYF_JELLEG_KOD ORSZ_KOD JARAS MEGYE AGAZAT_KOD SZAKAGAZAT_4ES_SZINT) (period ent_type ins_id exp_date rem_mat ins_type loan_type col_dum ins_sum ins_sum_cur exp exp_cur k k_cur int_rate ref_rate cust_type nationality district county nace4 nace4_d)
		
	* Dates
		drop period
		gen exp_date2 = dofc(exp_date)
		order exp_date2, a(exp_date)
		drop exp_date
		rename exp_date2 exp_date
		format %tddd/nn/CCYY exp_date
		
	* Encode
		* Manually encode rem_mat to respect sort order by time
			gen rem_mat2 = 1 if rem_mat == "0-1EV"
			replace rem_mat2 = 2 if rem_mat == "1-2EV"
			replace rem_mat2 = 3 if rem_mat == "2-5EV"
			replace rem_mat2 = 4 if rem_mat == "5-10EV"
			replace rem_mat2 = 5 if rem_mat == "10-XEV"
			replace rem_mat2 = 6 if rem_mat == "LEJART"
			order rem_mat2, a(rem_mat)
			drop rem_mat
			rename rem_mat2 rem_mat
			label define rem_mat 1 "0 - 1 year" 2 "1 - 2 years" 3 "2-5 years" 4 "5 - 10 years" 5 "10 years +" 6 "expired"
			label val rem_mat rem_mat
			label var rem_mat "Remaining maturity"
		* Encoding loop
			foreach var of varlist ins_type loan_type col_dum cust_type {
				if "`var'" == "ins_type" {
					local var_hun = "TIP_KOD"
				}
				if "`var'" == "loan_type" {
					local var_hun = "HIT_JELLEG_KOD"
				}
				if "`var'" == "col_dum" {
					local var_hun = "FED_HIT_KOD"
				}
				if "`var'" == "cust_type" {
					local var_hun = "UGYF_JELLEG_KOD"
				}
				preserve
				import excel using "$processed/MNB/data_dictionary", sheet(merged) firstrow clear
				keep if var == "`var_hun'" & val != ""
				keep val posval_en
				rename val `var'
				tempfile `var'_d
				save ``var'_d', replace
				restore
				merge m:1 `var' using ``var'_d'
				drop if _merge == 2
				replace `var' = posval_en if _merge == 3
				drop posval_en _merge
				encode `var', generate(`var'2) label(`var'_label)
				order `var'2, a(`var')
				local label : variable label `var'
				label variable `var'2 "`label'"
				drop `var'
				rename `var'2 `var'
			}
			
	* Manually clean ent_type
		replace ent_type = "Company with Hungarian tax ID" if ent_type == "BVALL_AZON"
		replace ent_type = "Company without Hungarian tax ID" if ent_type == "BVALL_TSZAM_NELK_AZON"
		replace ent_type = "Foreign company" if ent_type == "KVALL_AZON"
		replace ent_type = "Individuals" if ent_type == "LAKEV_AN_AZON"
		encode ent_type, gen(ent_type2)
		order ent_type2, a(ent_type)
		drop ent_type
		rename ent_type2 ent_type
	
	* Nationality
		preserve
		import delimited using "$rawdata/Auxiliary/iso_country_codes.csv", clear
		keep name alpha2
		rename alpha2 nationality
		tempfile iso2
		save `iso2', replace
		restore
		merge m:1 nationality using `iso2', nogen keep(master match)
		* There is one observation from XK - Kosovo. Manually enter that value.
		replace name = "Kosovo" if nationality == "XK"
		order name, a(nationality)
		drop nationality
		rename name nationality
		encode nationality, generate(nationality2) label(name)
		order nationality2, a(nationality)
		drop nationality
		rename nationality2 nationality
		label var nationality "Nationality"
		
	* Address variables
		order county district, a(nationality)
		gen county_code = substr(county,1,2)
		replace county = subinstr(ustrtitle(substr(county,6,.))," Vármegye","",1)
		destring county_code, replace
		labmask county_code, val(county)
		order county_code, a(county)
		drop county
		rename county_code county
		gen district_code = substr(district,1,3)
		replace district = ustrtitle(substr(district,7,.))
		destring district_code, replace
		labmask district_code, val(district)
		order district_code, a(district)
		drop district
		rename district_code district
			
	* Clean the NACE codes
		replace nace4 = "A foreign company, individual entrepreneur, or KSH registration number is missing or cannot be found in the organizations table" if substr(nace4_d,1,3) == "Kü"
		drop nace4_d
		
	* Currency standardization
		preserve
		* Get the list of all currencies in our data
		keep *cur
		duplicates drop
		gen id = _n
		rename (ins_sum_cur exp_cur k_cur) (cur_ins_sum cur_exp cur_k)
		reshape long cur_, i(id) j(currency) string
		keep cur_
		rename cur_ currency
		duplicates drop
		drop if currency == ""
		tempfile currency_list
		save `currency_list', replace
		import delimited using "$rawdata/Auxiliary/OECD_exchange_rates", clear
		* Choose between period average EXC, or end of period EXCE.
		keep if transact == "EXCE"
		* Keep relevant variables
		keep unitcode year value
		* Keep only the year 2022
		keep if year == 2022
		duplicates drop
		rename unitcode currency
		tempfile exchange_rates
		save `exchange_rates', replace
		merge 1:1 currency using `currency_list', nogen keep(using match)
		* According to the OECD (DOI: 10.1787/na-data-en), "On January 1, 2023, Croatia adopted the Euro as its national currency. Data related to years prior to entry into EMU have been converted using the irrevocable Euro conversion rate (7.5345)."
		sum value if currency == "EUR"
		replace value = r(mean)*7.5345 if currency == "HRK"
		drop year
		rename value exchange_rate
		label var exchange_rate "National currency per US dollar"
		* Reshepe wide to match
		gen id = 1
		reshape wide exchange_rate, i(id) j(currency) string
		rename exchange_rate* *		
		save `exchange_rates', replace
		restore
		gen id = 1
		merge m:1 id using `exchange_rates', nogen keep(master match)
		* Create standardized (USD) values of all currency variables.
		drop id		
		foreach var in ins_sum exp k {
			gen `var'_usd = .
			levelsof `var'_cur, local(levels)
			foreach currency in `levels' {
				replace `var'_usd = `var'/`currency' if `var'_cur == "`currency'"
			}
			order `var'_usd, a(`var'_cur)
		}
		order ent_type, b(cust_type)
		keep ins_id - nace4
		label var ins_sum_usd "Sum of instrument, 2022 USD"
		label var exp_usd "Current (balance sheet) exposure value, 2022 USD"
		label var k_usd "Outstanding capital amount, 2022 USD"
		compress
		
	* Include exchange rates for Forint and Euros
		preserve
		import delimited using "$rawdata/Auxiliary/OECD_exchange_rates", clear
		* Choose between period average EXC, or end of period EXCE.
		keep if transact == "EXCE"
		* Keep relevant variables
		keep unitcode year value
		* Keep only the year 2022
		keep if year == 2022
		duplicates drop
		rename unitcode currency
		keep if currency == "EUR" | currency == "HUF"
		gen i = _n
		reshape wide value, i(i) j(currency) string
		keep value*
		rename value* *
		sum HUF
		replace HUF = r(mean) in 1
		keep in 1
		gen match = 1
		tempfile exchange_rates
		save `exchange_rates', replace
		restore
		gen match = 1
		merge m:1 match using `exchange_rates', nogen keep(master match)
		drop match
		
	* Change the display format of numericals
		format %20.2gc ins_sum ins_sum_usd exp exp_usd k k_usd	
			
	* Compress
		compress
		
	* Save - to the shared folder due to its size
		save "$processed/MNB/instruments.dta", replace
		
* 2.2) Decisions		
		
	* Drop all instruments with a missing NACE code
		drop if nace4 == ""
		
			* Merge in the Nace1 categories
				merge m:1 nace4 using "$rawdata\Auxiliary\nace_rev2_1_4.dta", nogen
				order nace1 nace1_d nace4 nace4_d
				* Clean up and shorten the descriptions.
				replace nace1_d = "Agriculture, Forestry And Fishing" if nace1_d == "AGRICULTURE, FORESTRY AND FISHING"
				replace nace1_d = "Mining And Quarrying" if nace1_d == "MINING AND QUARRYING"
				replace nace1_d = "Manufacturing" if nace1_d == "MANUFACTURING"
				replace nace1_d = "Electricity, Gas, Steam" if nace1_d == "ELECTRICITY, GAS, STEAM AND AIR CONDITIONING SUPPLY"
				replace nace1_d = "Water Supply" if nace1_d == "WATER SUPPLY; SEWERAGE, WASTE MANAGEMENT AND REMEDIATION ACTIVITIES"
				replace nace1_d = "Construction" if nace1_d == "CONSTRUCTION"
				replace nace1_d = "Wholesale And Retail Trade" if nace1_d == "WHOLESALE AND RETAIL TRADE; REPAIR OF MOTOR VEHICLES AND MOTORCYCLES"
				replace nace1_d = "Transportation And Storage" if nace1_d == "TRANSPORTATION AND STORAGE"
				replace nace1_d = "Accommodation And Food Service" if nace1_d == "ACCOMMODATION AND FOOD SERVICE ACTIVITIES"
				replace nace1_d = "Information And Communication" if nace1_d == "INFORMATION AND COMMUNICATION"
				replace nace1_d = "Financial And Insurance" if nace1_d == "FINANCIAL AND INSURANCE ACTIVITIES"
				replace nace1_d = "Real Estate" if nace1_d == "REAL ESTATE ACTIVITIES"
				replace nace1_d = "Professional, Scientific And Technical" if nace1_d == "PROFESSIONAL, SCIENTIFIC AND TECHNICAL ACTIVITIES"
				replace nace1_d = "Administrative And Support Service" if nace1_d == "ADMINISTRATIVE AND SUPPORT SERVICE ACTIVITIES"
				replace nace1_d = "Public Administration And Defence" if nace1_d == "PUBLIC ADMINISTRATION AND DEFENCE; COMPULSORY SOCIAL SECURITY"
				replace nace1_d = "Education" if nace1_d == "EDUCATION"
				replace nace1_d = "Human Health And Social Work" if nace1_d == "HUMAN HEALTH AND SOCIAL WORK ACTIVITIES"
				replace nace1_d = "Arts, Entertainment And Recreation" if nace1_d == "ARTS, ENTERTAINMENT AND RECREATION"
				replace nace1_d = "Other Service Activities" if nace1_d == "OTHER SERVICE ACTIVITIES"
				replace nace1_d = "Activities Of Households" if nace1_d == "ACTIVITIES OF HOUSEHOLDS AS EMPLOYERS; UNDIFFERENTIATED GOODS- AND SERVICES-PRODUCING ACTIVITIES OF HOUSEHOLDS FOR OWN USE"
				replace nace1_d = "Extraterritorial Organisations and Bodies" if nace1_d == "ACTIVITIES OF EXTRATERRITORIAL ORGANISATIONS AND BODIES"
		
	* Drop foreign companies whose Nace codes are unknown
		drop if nace4 == "A foreign company, individual entrepreneur, or KSH registration number is missing or cannot be found in the organizations table"
		
	* Drop if outstanding capital amount is missing
		drop if k_usd == .
		
	* Drop if outstanding capital amount is negative
		drop if k_usd < 0
		
	* Drop if ins_id is not unique
		bys ins_id: gen unique = _N
		drop if unique != 1
		drop unique
		
	* Compress
		compress
	
	* Sort
		gsort - k_usd
		
	* Save
		save "$processed/MNB/instruments_firms", replace	
}

********************************************************************************
* PART 3: COLLATERALS
********************************************************************************
{

* 3.1) General cleaning

	* Import
		import sas using "$rawdata/Collaterals.sas7bdat", clear
	
	* Label vars
		label	 	var	 	VONATKOZAS	 	"Period"
		label	 	var	 	INSTR_AZON_MD5	 	"Instrument identifier with MD5 function"
		label	 	var	 	FED_AZON	 	"Collateral identifier actual"
		label	 	var	 	FED_ISIN	 	"Collateral ISIN"
		label	 	var	 	FED_ERTEKP_DB	 	"Quantity of security"
		label	 	var	 	FED_AKT_PIACI_ERTEK	 	"Present market value of collateral"
		label	 	var	 	FED_AKT_ERTEK_DEV	 	"Currency of collateral present value" 
		label	 	var	 	FED_KOD	 	"Type of collateral"
		label	 	var	 	FED_INGATLAN_KOD	 	"Type of real estate collateral"
		label	 	var	 	FED_CIM_ORSZ_KOD	 	"Address of the collateral: country"
		label	 	var	 	MEGYE	 	"Address of the collateral: county"
		label	 	var	 	JARAS	 	"Address of the collateral: district"
	
	* Rename
		rename VONATKOZAS period
		rename INSTR_AZON_MD5 ins_id
		rename FED_AZON col_id
		rename FED_ISIN col_isin
		rename FED_ERTEKP_DB quantity
		rename FED_AKT_PIACI_ERTEK value
		rename FED_AKT_ERTEK_DEV value_cur
		rename FED_KOD col_type
		rename FED_INGATLAN_KOD realcol_type
		rename FED_CIM_ORSZ_KOD realcol_country
		rename MEGYE realcol_county
		rename JARAS realcol_district
	
	* Period is redundant, drop it
		drop period

	* Format numericals	
		format %20.2g quantity value

	* Encode
	
		* Encoding loop
			foreach var of varlist col_type realcol_type {
			if "`var'" == "col_type" {
				local var_hun = "FED_KOD"
			}
			if "`var'" == "realcol_type" {
				local var_hun = "FED_INGATLAN_KOD"
			}
			preserve
			import excel using "$processed/MNB/data_dictionary", sheet(merged) firstrow clear
			keep if var == "`var_hun'" & val != ""
			keep val posval_en
			rename val `var'
			tempfile `var'_d
			save ``var'_d', replace
			restore
			merge m:1 `var' using ``var'_d'
			drop if _merge == 2
			replace `var' = posval_en if _merge == 3
			drop posval_en _merge
			encode `var', generate(`var'2) label(`var'_label)
			order `var'2, a(`var')
			local label : variable label `var'
			label variable `var'2 "`label'"
			drop `var'
			rename `var'2 `var'
		}

	 
		* Country
			preserve 
			import delimited using "$rawdata/Auxiliary/iso_country_codes.csv", clear
			keep name alpha2
			rename alpha2 realcol_country
			tempfile iso2
			save `iso2', replace
			restore
			merge m:1 realcol_country using `iso2', nogen keep(master match)
			* There is one observation from XK - Kosovo. Manually enter that value.
			replace name = "Kosovo" if realcol_country == "XK"
			order name, a(realcol_country)
			drop realcol_country
			rename name realcol_country
			encode realcol_country, generate(realcol_country2)
			order realcol_country2, a(realcol_country)
			drop realcol_country
			rename realcol_country2 realcol_country
			label var realcol_country "Address of the collateral: country"

		* County
			replace realcol_county = upper(subinstr(realcol_county, " VÁRMEGYE","",1))
			
		* District
			replace realcol_district = proper(subinstr(realcol_district, " járás","",1))
			
			* Currency standardization
		preserve
		* Get the list of all currencies in our data
		keep value_cur
		rename value_cur currency
		duplicates drop
		drop if currency == ""
		tempfile currency_list
		save `currency_list', replace
		import delimited using "$rawdata\Auxiliary\OECD_exchange_rates", clear
		* Choose between period average EXC, or end of period EXCE.
		keep if transact == "EXCE"
		* Keep relevant variables
		keep unitcode year value
		* Keep only the year 2022
		keep if year == 2022
		duplicates drop
		rename unitcode currency
		tempfile exchange_rates
		save `exchange_rates', replace
		merge 1:1 currency using `currency_list', nogen keep(using match)
		* According to the OECD (DOI: 10.1787/na-data-en), "On January 1, 2023, Croatia adopted the Euro as its national currency. Data related to years prior to entry into EMU have been converted using the irrevocable Euro conversion rate (7.5345)."
		sum value if currency == "EUR"
		replace value = r(mean)*7.5345 if currency == "HRK"
		drop year
		rename value exchange_rate
		label var exchange_rate "National currency per US dollar"
		* Reshepe wide to match
		gen id = 1
		reshape wide exchange_rate, i(id) j(currency) string
		rename exchange_rate* *		
		save `exchange_rates', replace
		restore
		gen id = 1
		merge m:1 id using `exchange_rates', nogen keep(master match)
		* Create standardized (USD) values of all currency variables.
		drop id		
		*rename value_col value
		foreach var of varlist value {
			gen `var'_usd = .
			levelsof `var'_cur, local(levels)
			foreach currency in `levels' {
				replace `var'_usd = `var'/`currency' if `var'_cur == "`currency'"
			}
			order `var'_usd, a(`var'_cur)
		}
		keep ins_id - realcol_district
		label var value_usd "Market value of collateral, 2022 USD"	

* 3.2) Decisions

	* Exclude all collaterals that have a value of 0 or below, or that have missing value.
		drop if value <= 0 | value == .
		
	* Compress
		compress
		
	* Save
		save "$processed/MNB/collaterals", replace
}		
































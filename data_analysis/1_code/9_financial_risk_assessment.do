* Version: 1.1
* Runs on: Stata/MP 18.0

* Identification and Prioritization
	* Created: 20/02/2024
	* Last modified: 29/05/2024
	
* Summary: This do-file generates the outputs to be included in the "Financial Risk Assessment" section of the paper.

********************************************************************************
* PART 0: TABLE OF CONTENTS
********************************************************************************

*	1) SETUP

*	2) OUTPUTS

********************************************************************************
* PART 1: SETUP
********************************************************************************

/*
if c(username) == "gulersoy_g" {
	global path = "V:\BIODIVERSITY_HUN\sources"
	global rawdata = "V:\BIODIVERSITY_HUN\sources\0_rawdata"
	global processed = "V:\BIODIVERSITY_HUN\results\3_processeddata"
	global output = "V:\BIODIVERSITY_HUN\results\4_output"
}
*/

clear
cd "$path"
set type double

********************************************************************************
* PART 2: OUTPUTS
********************************************************************************

* 2.1) Debt maturity by type of instrument.

	use "$processed\MNB\instruments_firms.dta", clear

	* Get the instrument categories.
		preserve
		import excel using "$rawdata\Auxiliary\ins_type_HM_Groupings.xlsx", clear
		rename (A B) (ins_type ins_cat)
		tempfile ins_cat
		save `ins_cat', replace
		restore
		decode ins_type, gen(ins_type2)
		order ins_type2, a(ins_type)
		drop ins_type
		rename ins_type2 ins_type
		merge m:1 ins_type using `ins_cat', nogen keep(master match)
		order ins_cat, a(ins_type)
		* Rename "Other" to "Corporate loans"
		replace ins_cat = "Corporate loans" if ins_cat == "Other"
		
	* Extract the year of maturity.
		gen exp_year = yofd(exp_date)
		order exp_year, a(exp_date)
		
	* Decisions
		* Exclude anything that has an expiry date before 2022.
		replace exp_year = . if exp_year <= 2022
		replace exp_year = 9999 if exp_year != . & exp_year > 2040
	
	* Calculate the sum of instrument category - year pair by billions of EUR.
		gen k_eur = k_usd * EUR
		collapse (sum) k_eur, by(ins_cat exp_year)
		
	* Check how much of the portfolio is associated with missing expiry dates.
		sum k_eur
		gen k_eur_sh = k_eur / r(sum)
		sum k_eur_sh if exp_year == .
		di r(sum)
		drop k_eur_sh
		
	* Convert to Billions of EUR.
		replace k_eur = k_eur / 1000000000

	* Reshape data for graph
		drop if exp_year == .
		reshape wide k_eur, i(ins_cat) j(exp_year)	
		rename k_eur* year_*
		foreach var of varlist year_* {
			replace `var' = 0 if `var' == .
		}
		
	* Export output to Excel
		export excel using "$output\Financial_risk_assessment\instrument_category_by_year", replace firstrow(variable)

* 2.2) Total debt and average interest rate by sector.

	use "$processed\MNB\instruments_firms.dta", clear
	
	* Calculate the total debt per sector
		gen k_eur = k_usd * EUR
		replace k_eur = k_eur / 1000000000
		keep nace1 nace1_d k_eur int_rate

	* Calculate weighted average of int_rate
		gen k_eur2 = k_eur
		replace k_eur2 = . if int_rate == .
		bys nace1: egen k_eur_sum = total(k_eur2)
		gen k_eur_sh = k_eur2 / k_eur_sum
		drop k_eur2 k_eur_sum
		gen int_rate_w = k_eur_sh * int_rate
		collapse (sum) k_eur int_rate_w, by(nace1 nace1_d)
		
	* Sort
		gsort - int_rate_w
		
	* Export output to Excel
		export excel using "$output\Financial_risk_assessment\interest_rate_by_sector", replace firstrow(variable)	

* 2.3) Outstanding debt by currency

	use "$processed\MNB\instruments_firms.dta", clear
	
	* Calculate the total debt per currency
		sum k_usd
		gen k_usd_sh = k_usd / r(sum)
		keep k_usd_sh k_cur
		
	* Collapse
		collapse (sum) k_usd_sh, by(k_cur)
		
	* Gsort - 
		gsort - k_usd_sh
		
	* Ignore currency splits if below 1%
		replace k_cur = "Other" if k_usd_sh < 0.01
		collapse (sum) k_usd_sh, by(k_cur)
		gsort - k_usd_sh

	* Export output to Excel
		export excel using "$output\Financial_risk_assessment\outstanding_debt_by_currency", replace firstrow(variable)	




















	







* Version: 1.1
* Runs on: Stata/MP 18.0

* Impacts and Dependencies of Nace codes
	* Created: 31/10/2023
	* Last modified: 29/05/2024
	
* Summary: This do-file matches the ENCORE impact and dependency materiality ratings to Nace codes.

********************************************************************************
* PART 0: TABLE OF CONTENTS
********************************************************************************

*	1) SETUP

*	2) MATCH

*	3) EXPORT

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
* PART 2: MATCH
********************************************************************************

* Import Nace code to production process correspondance table.
	use "$rawdata/ENCORE/nace_productionprocess_corrtable", clear
	drop rule_flag
	
	* Reshape
		reshape long pp_, i(nace4 nace4_d) j(pp_count)
		rename pp_ pp
		drop if pp == ""
		
	* Save as tempfile
		tempfile nace4_pp
		save `nace4_pp'

* 2.1) Impacts
{
	* Import the materiality ratings
		import excel using "$rawdata\ENCORE\impact_materialities.xlsx", firstrow clear
		rename *, lower
		drop sector subindustry
		duplicates drop
		rename productionprocess pp
	
	* Convert to numerical
		* Standard ratings
			preserve
			foreach var of varlist disturbances - biologicalinterferencesalterat {
				replace `var' = "0" if `var' == "ND"
				replace `var' = "2" if `var' == "VL"
				replace `var' = "4" if `var' == "L"
				replace `var' = "6" if `var' == "M"
				replace `var' = "8" if `var' == "H"
				replace `var' = "10" if `var' == "VH"
				destring `var', replace
			}
			* Save as tempfile
			tempfile impacts
			save `impacts', replace
			restore
		* Cautious ratings
			preserve
			foreach var of varlist disturbances - biologicalinterferencesalterat {
				replace `var' = "5" if `var' == "H"
				replace `var' = "10" if `var' == "VH"
				replace `var' = "0" if (`var' != "5") & (`var' != "10")
				destring `var', replace
			}
			* Save as tempfile
			tempfile impacts_high
			save `impacts_high', replace
			restore
		
	* Merge
		foreach rating_type in "standard" "cautious" {
			use `nace4_pp', clear
		
		if "`rating_type'" == "standard" {
			merge m:1 pp using `impacts', nogen keep(master match)
			* Collapse by Nace code
			collapse (mean) disturbances - biologicalinterferencesalterat, by(nace4 nace4_d)
			* Round to the nearest higher multiple of 0.2.
			foreach var of varlist disturbances - biologicalinterferencesalterat {
				replace `var' = 2 * ceil(`var'/2)
			}
		}
		if "`rating_type'" == "cautious" {
			merge m:1 pp using `impacts_high', nogen keep(master match)
			* Collapse by Nace code
			collapse (mean) disturbances - biologicalinterferencesalterat, by(nace4 nace4_d)
		}

		* Rename and label variables
			rename disturbances i_dist
			label var i_dist "Disturbances"
			rename freshwaterecosystemuse i_freshwater
			label var i_freshwater "Freshwater ecosystem use"
			rename ghgemissions i_ghg
			label var i_ghg "GHG emissions"
			rename marineecosystemuse i_marine
			label var i_marine "Marine ecosystem use"
			rename nonghgairpollutants i_nonghg
			label var i_nonghg "Non-GHG air pollutants"
			rename otherresourceuse i_other
			label var i_other "Other resource use"
			rename soilpollutants i_soil
			label var i_soil "Soil pollutants"
			rename solidwaste i_solid
			label var i_solid "Solid waste"
			rename terrestrialecosystemuse i_terrestrial
			label var i_terrestrial "Terrestrial ecosystem use"
			rename waterpollutants i_waterpol
			label var i_waterpol "Water pollutants"
			rename wateruse i_wateruse
			label var i_wateruse "Water use"
			rename biologicalinterferencesalterat i_biological
			label var i_biological "Biological interferences/alterations"	

		* Save as tempfile	
			if "`rating_type'" == "standard" {
				save `impacts', replace
			}
			if "`rating_type'" == "cautious" {
				save `impacts_high', replace
			}
	}
}	
		
* 2.2) Dependencies
{
	foreach rating_type in "standard" "cautious" {

	* Import the materiality ratings
		import delimited using "$rawdata\ENCORE\dependency_materialities.csv", clear varn(1) bindquote(strict) 
		drop justification
		
	* Convert to numerical
		if "`rating_type'" == "standard" {
			foreach var of varlist rating {
				replace `var' = "0" if `var' == "ND"
				replace `var' = "2" if `var' == "VL"
				replace `var' = "4" if `var' == "L"
				replace `var' = "6" if `var' == "M"
				replace `var' = "8" if `var' == "H"
				replace `var' = "10" if `var' == "VH"
				destring `var', replace
			}
		}	
		if "`rating_type'" == "cautious" {
			foreach var of varlist rating {
				replace `var' = "5" if `var' == "H"
				replace `var' = "10" if `var' == "VH"
				replace `var' = "0" if (`var' != "5") & (`var' != "10")
				destring `var', replace
			}
		}	
			
	* Reshape
		rename ecosystemservice e_
		rename rating r_
		replace e_ = substr(lower(subinstr(subinstr(e_," ","",.),"-","",.)),1,30)
		reshape wide r_, i(process) j(e_) string
		rename process pp
		
	* Replace missing values with 0.
		foreach var of varlist r_* {
			replace `var' = 0 if `var' == .
		}
			
	* Save as tempfile
		if "`rating_type'" == "standard" {
			tempfile dependencies
			save `dependencies', replace
		}
		if "`rating_type'" == "cautious" {
			tempfile dependencies_high
			save `dependencies_high', replace
		}
			
	* Merge					
		use `nace4_pp', clear
		if "`rating_type'" == "standard" {
			merge m:1 pp using `dependencies', nogen keep(master match)
			* Collapse by Nace code
			collapse (mean) r_*, by(nace4 nace4_d)
			* Round to the nearest higher multiple of 2.
			foreach var of varlist r_* {
				replace `var' = 2 * ceil(`var'/2)
			}
		}
		if "`rating_type'" == "cautious" {
			merge m:1 pp using `dependencies_high', nogen keep(master match)
			collapse (mean) r_*, by(nace4 nace4_d)
		}
		rename r_* *
			
	* Rename and label
		rename animalbasedenergy d_animal
		label var d_animal "Animal based energy"
		rename bioremediation d_bio
		label var d_bio "Bio-remediation"
		rename bufferingandattenuationofmassf d_buffering
		label var d_buffering "Buffering and attenuation of mass flows"
		rename climateregulation d_climate
		label var d_climate "Climate regulation"
		rename dilutionbyatmosphereandecosyst d_dilution
		label var d_dilution "Dilution by atmosphere and ecosystems"
		rename diseasecontrol d_disease
		label var d_disease "Disease control"
		rename fibresandothermaterials d_fibres
		label var d_fibres "Fibres and other materials"
		rename filtration d_filtration
		label var d_filtration "Filtration"
		rename floodandstormprotection d_flood
		label var d_flood "Flood and storm protection"
		rename geneticmaterials d_genetic
		label var d_genetic "Genetic materials"
		rename groundwater d_groundwater
		label var d_groundwater "Ground water"
		rename maintainnurseryhabitats d_nursery
		label var d_nursery "Maintain nursery habitats"
		rename massstabilisationanderosioncon d_erosion
		label var d_erosion "Mass stabilisation and erosion control"
		rename mediationofsensoryimpacts d_mediation
		label var d_mediation "Mediation of sensory impacts"
		rename pestcontrol d_pest
		label var d_pest "Pest control"
		rename pollination d_pollination
		rename soilquality d_soil
		label var d_pollination "Pollination"
		label var d_soil "Soil quality"
		rename surfacewater d_surfacewater
		label var d_surfacewater "Surface water"
		rename ventilation d_ventilation
		label var d_ventilation "Ventilation"
		rename waterflowmaintenance d_waterflow
		label var d_waterflow "Waterflow maintenance"
		rename waterquality d_waterquality
		label var d_waterquality "Water quality"	
			
	* Save as tempfile
		if "`rating_type'" == "standard" {
			save `dependencies', replace
		}
		if "`rating_type'" == "cautious" {
			save `dependencies_high', replace
		}
	}		
}
	
********************************************************************************
* PART 3: EXPORT
********************************************************************************
{
		use "$rawdata/ENCORE/nace_productionprocess_corrtable", clear
		export excel "$processed/ENCORE/nace_impacts_dependencies", sheet(nace_pp) firstrow(variables) replace
		export excel "$processed/ENCORE/nace_impacts_dependencies_high", sheet(nace_pp) firstrow(variables) replace
		
		use `impacts', clear
		merge 1:1 nace4 using "$rawdata/ENCORE/nace_productionprocess_corrtable", keepusing(nace1 nace1_d) nogen
		order nace1 nace1_d
		export excel "$processed/ENCORE/nace_impacts_dependencies", sheet(impacts, replace) firstrow(variables)
		save "$processed/ENCORE/nace_impacts", replace

		use `dependencies', clear
		merge 1:1 nace4 using "$rawdata/ENCORE/nace_productionprocess_corrtable", keepusing(nace1 nace1_d) nogen
		order nace1 nace1_d
		export excel "$processed/ENCORE/nace_impacts_dependencies", sheet(dependencies, replace) firstrow(variables)
		save "$processed/ENCORE/nace_dependencies", replace
		
		use `impacts_high', clear
		merge 1:1 nace4 using "$rawdata/ENCORE/nace_productionprocess_corrtable", keepusing(nace1 nace1_d) nogen
		order nace1 nace1_d
		save "$processed/ENCORE/nace_impacts_high", replace
		export excel "$processed/ENCORE/nace_impacts_dependencies_high", sheet(impacts, replace) firstrow(variables)

		use `dependencies_high', clear
		merge 1:1 nace4 using "$rawdata/ENCORE/nace_productionprocess_corrtable", keepusing(nace1 nace1_d) nogen
		order nace1 nace1_d
		export excel "$processed/ENCORE/nace_impacts_dependencies_high", sheet(dependencies, replace) firstrow(variables)
		save "$processed/ENCORE/nace_dependencies_high", replace
}
			
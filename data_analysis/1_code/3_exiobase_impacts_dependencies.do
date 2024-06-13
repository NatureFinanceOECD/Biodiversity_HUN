* Version: 1.1
* Runs on: Stata/MP 18.0

* Impacts and Dependencies of Exiobase industries
	* Created: 10/11/2023
	* Last modified: 29/05/2024
	
* Summary: This do-file matches the ENCORE impact and dependency materiality ratings to Exiobase industries.

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

* Clean the Exiobase to Nace correspondance table.
	import excel using "$rawdata\Exiobase\NACE2full_EXIOBASEp", firstrow clear
	rename *, lower
	keep if level == 4
	drop level
	foreach var of varlist * {
		tab `var'
		if r(N) == 0 {
			drop `var'
		}
	}
	replace code = substr(code,1,2)+substr(code,4,2)
	keep code exiobase - v
	local rn = 1
	foreach var of varlist exiobase - v {
		rename `var' exio_`rn'
		local rn = `rn' + 1
	}
	rename code nace4
	*Two industries are missing on the official Exiobase table of correspondance between Nace and Exiobase industries. "Re-processing of secondary glass into new glass" (potentially Nace4 3832) and "Re-processing of ash into clinker" (potentially Nace4 2369).
	replace exio_2 = "Re-processing of ash into clinker" if nace4 == "2369"
	replace exio_3 = "Re-processing of secondary glass into new glass" if nace4 == "3832"
	* Manually overwrite the names of some industries to match with Exiobase's IO tables.
	foreach var of varlist exio_* {
		replace `var' = "Biogasification of food waste, incl. land application" if `var' == "Biogasification of food waste"
		replace `var' = "Biogasification of paper, incl. land application" if `var' == "Biogasification of paper"
		replace `var' = "Biogasification of sewage slugde, incl. land application" if `var' == "Biogasification of sewage slugde"
		replace `var' = "Composting of food waste, incl. land application" if `var' == "Composting of food waste"
		replace `var' = "Composting of paper and wood, incl. land application" if `var' == "Composting of paper and wood"
		replace `var' = "Recycling of bottles by direct reuse" if `var' == "Glass bottles directly reused"
		replace `var' = "Manure treatment (biogas), storage and land application" if `var' == "Manure treatment (biogas) and land application"
		replace `var' = "Manure treatment (conventional), storage and land application" if `var' == "Manure treatment (conventional) and land application"
		replace `var' = "Re-processing of secondary aluminium into new aluminium" if `var' == "Recycling of aluminium waste"
		replace `var' = "Re-processing of secondary construction material into aggregates" if `var' == "Recycling of construction waste"
		replace `var' = "Re-processing of secondary copper into new copper" if `var' == "Recycling of copper waste"
		replace `var' = "Re-processing of secondary lead into new lead, zinc and tin" if `var' == "Recycling of lead, zinc and tin waste"
		replace `var' = "Re-processing of secondary other non-ferrous metals into new other non-ferrous metals" if `var' == "Recycling of other non-ferrous metals waste"
		replace `var' = "Re-processing of secondary preciuos metals into new preciuos metals" if `var' == "Recycling of pecious metals waste"
		replace `var' = "Re-processing of secondary plastic into new plastic" if `var' == "Recycling of plastics waste"
		replace `var' = "Re-processing of secondary steel into new steel" if `var' == "Recycling of steel scrap"
		replace `var' = "Re-processing of secondary paper into new pulp" if `var' == "Recycling of waste paper"
		replace `var' = "Re-processing of secondary wood material into new wood material" if `var' == "Woodwaste"
	}
	save "$processed\Exiobase\exiobase_nace_corrtable", replace

* Match Exiobase industries to ENCORE production processes through the Nace codes.	
	use "$rawdata\ENCORE\nace_productionprocess_corrtable.dta", clear
	merge 1:1 nace4 using "$processed\Exiobase\exiobase_nace_corrtable"
	keep exio* pp*
	order exio* pp*
	gen n = _n
	reshape long exio_ , i(n) j(exio)
	drop if exio_ == ""
	drop n exio
	gen n = _n
	reshape long pp_, i(n) j(pp)
	drop n pp
	drop if pp_ == ""
	duplicates drop
	bys exio: gen n = _n
	reshape wide pp_, i(exio) j(n)
	rename exio_ exio_ind
	save "$processed\Exiobase\exiobase_encore_corrtable", replace
	reshape long pp_, i(exio_ind) j(pp_count)
	rename pp_ pp
	drop if pp == ""
	tempfile exio_pp
	save `exio_pp', replace
	
* 2.1) Impacts
{
	* Import the materiality ratings
		import excel using "$rawdata\ENCORE\impact_materialities.xlsx", firstrow clear
		rename *, lower
		keep productionprocess - biologicalinterferencesalterat
		rename productionprocess pp
		duplicates drop
		
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
		use `exio_pp', clear
		
		if "`rating_type'" == "standard" {
			merge m:1 pp using `impacts', nogen keep(master match)
			* Collapse by Exiobase industry
			collapse (mean) disturbances - biologicalinterferencesalterat, by(exio_ind)
			* Round to the nearest higher multiple of 2. (Unlike Nace materialities, we opted not to do this for Exiobase materiality ratings.)
			/*
			foreach var of varlist disturbances - biologicalinterferencesalterat {
				replace `var' = 2 * ceil(`var'/2)
			}
			*/
		}
		if "`rating_type'" == "cautious" {
			merge m:1 pp using `impacts_high', nogen keep(master match)
			* Collapse by Nace code
			collapse (mean) disturbances - biologicalinterferencesalterat, by(exio_ind)
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
		import delimited using "$rawdata\ENCORE\dependency_materialities", clear varn(1) bindquote(strict) 
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
		use `exio_pp', clear
		if "`rating_type'" == "standard" {
			merge m:1 pp using `dependencies', nogen keep(master match)
			* Collapse by Nace code
			collapse (mean) r_*, by(exio_ind)
			* Round to the nearest higher multiple of 2. (Unlike Nace materialities, we opted not to do this for Exiobase materiality ratings.)
			/*
			foreach var of varlist disturbances - biologicalinterferencesalterat {
				replace `var' = 2 * ceil(`var'/2)
			}
			*/
		}	
		if "`rating_type'" == "cautious" {
			merge m:1 pp using `dependencies_high', nogen keep(master match)
			collapse (mean) r_*, by(exio_ind)
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

* 2.3) Merge in Exiobase industry classification numbers
{
	import delimited using "$rawdata\Exiobase\IOT_2022_ixi\industries.txt", clear
	rename name exio_ind
	keep number exio_ind
	gen str = strlen(exio_ind)
	sum str, det
	local strlen = r(max)
	drop str
	recast str`strlen' exio_ind
	tempfile exio_nr
	save `exio_nr', replace
	use `impacts', clear
	merge 1:1 exio_ind using `exio_nr', nogen
	order number
	sort number
	save `impacts', replace
	use `impacts_high', clear
	merge 1:1 exio_ind using `exio_nr', nogen
	order number
	sort number
	save `impacts_high', replace
	use `dependencies', clear
	merge 1:1 exio_ind using `exio_nr', nogen
	order number
	sort number
	save `dependencies', replace
	use `dependencies_high', clear
	merge 1:1 exio_ind using `exio_nr', nogen
	order number
	sort number
	save `dependencies_high', replace
	use "$processed\Exiobase\exiobase_encore_corrtable", clear
	merge 1:1 exio_ind using `exio_nr', nogen
	order number
	sort number
	save "$processed\Exiobase\exiobase_encore_corrtable", replace
}

********************************************************************************
* PART 3: EXPORT
********************************************************************************
{
		use "$processed\Exiobase\exiobase_encore_corrtable", clear
		export excel using "$processed/Exiobase/exiobase_impacts_dependencies/exiobase_impacts_dependencies", sheet(exio_pp) firstrow(variables) replace
		export excel using "$processed/Exiobase/exiobase_impacts_dependencies/exiobase_impacts_dependencies_high", sheet(exio_pp) firstrow(variables) replace

		use `impacts', clear
		export excel "$processed/Exiobase/exiobase_impacts_dependencies/exiobase_impacts_dependencies", sheet(impacts, replace) firstrow(varl) nolab
		save "$processed/Exiobase/exiobase_impacts_dependencies/exiobase_impacts", replace
		
		use `dependencies', clear
		export excel "$processed/Exiobase/exiobase_impacts_dependencies/exiobase_impacts_dependencies", sheet(dependencies, replace) firstrow(varl) nolab
		save "$processed/Exiobase/exiobase_impacts_dependencies/exiobase_dependencies", replace
		
		use `impacts_high', clear
		export excel "$processed/Exiobase/exiobase_impacts_dependencies/exiobase_impacts_dependencies_high", sheet(impacts, replace) firstrow(varl) nolab
		save "$processed/Exiobase/exiobase_impacts_dependencies/exiobase_impacts_high", replace
		
		use `dependencies_high', clear
		export excel "$processed/Exiobase/exiobase_impacts_dependencies/exiobase_impacts_dependencies_high", sheet(dependencies, replace) firstrow(varl) nolab
		save "$processed/Exiobase/exiobase_impacts_dependencies/exiobase_dependencies_high", replace
}
		
		
		
		




























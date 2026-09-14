*==============================================================
* 02. LOS CANALES DE LA RELACION Y LA PARTICIPACION DE REEXPORTACION
* Salida: resultados/02_canales.xlsx
*==============================================================
clear all
local xls "$out/02_canales.xlsx"
cap erase "`xls'"

*--------------------------------------------------------------
* A. Matriz anual de canales (USD millones, FOB)
*--------------------------------------------------------------
use "$aux/db_ecu_clean.dta", clear
keep if tipo=="fob"
gen str34 canal = ""
replace canal = "1 Export ECU a PAN"         if flujo=="Exportaciones" & partner=="PAN"
replace canal = "2 Export ECU al mundo"      if flujo=="Exportaciones" & partner=="WLD"
replace canal = "3 Import origen PAN"        if flujo=="Importaciones" & partner=="PAN" & registro=="origen"
replace canal = "4 Import procedencia PAN"   if flujo=="Importaciones" & partner=="PAN" & registro=="procedencia"
replace canal = "5 Import origen mundo"      if flujo=="Importaciones" & partner=="WLD" & registro=="origen"
replace canal = "6 Import procedencia mundo" if flujo=="Importaciones" & partner=="WLD" & registro=="procedencia"
drop if canal==""
collapse (sum) valor, by(canal petro anio)
replace valor = valor/1e6
reshape wide valor, i(canal petro) j(anio)
sort canal petro
export excel using "`xls'", sheet("A_canales") sheetreplace firstrow(variables)
list, noobs sepby(canal)

*--------------------------------------------------------------
* B. Participacion de Panama en cada universo
*--------------------------------------------------------------
use "$aux/db_ecu_clean.dta", clear
keep if tipo=="fob"
gen str16 universo = registro
replace universo = "exportacion" if flujo=="Exportaciones"
collapse (sum) valor, by(universo partner petro anio)
reshape wide valor, i(universo petro anio) j(partner) string
gen double share_pan = 100*valorPAN/valorWLD
replace valorPAN = valorPAN/1e6
replace valorWLD = valorWLD/1e6
sort universo petro anio
export excel using "`xls'", sheet("B_share_panama") sheetreplace firstrow(variables)
list universo petro anio share_pan, noobs sepby(universo petro)

*--------------------------------------------------------------
* C. Participacion de reexportacion  tau = 1 - origen/procedencia
*    Fraccion de lo que llega desde Panama que no es de origen panameno.
*    Es la contraparte, medida desde el registro ecuatoriano, de lo que
*    Panama contabiliza como Reexportacion ZLC.
*    tau = 0  bien de origen panameno
*    tau = 1  reexportacion pura
*    tau < 0  llega mas origen panameno que procedencia panamena
*             (pesca de flota con bandera panamena, descargada sin
*              pasar por Panama)
*--------------------------------------------------------------
* C1. Agregado por cobertura petrolera
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Importaciones" & tipo=="fob" & partner=="PAN"
collapse (sum) valor, by(registro petro anio)
replace valor = valor/1e6
reshape wide valor, i(petro anio) j(registro) string
gen double tau = 1 - valororigen/valorprocedencia
label var tau "1 - origen/procedencia"
sort petro anio
export excel using "`xls'", sheet("C1_tau_agregado") sheetreplace firstrow(variables)
list, noobs sepby(petro)

* C2. Por sector, cada anio
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Importaciones" & tipo=="fob" & partner=="PAN" & petro=="No Petrolero"
collapse (sum) valor, by(registro sector anio)
replace valor = valor/1e6
reshape wide valor, i(sector anio) j(registro) string
foreach v of varlist valororigen valorprocedencia {
    replace `v' = 0 if missing(`v')
}
gen double tau = 1 - valororigen/valorprocedencia if valorprocedencia>0
bysort anio: egen double _tp = total(valorprocedencia)
gen double share_proc = 100*valorprocedencia/_tp
drop _tp
gsort anio -valorprocedencia
export excel using "`xls'", sheet("C2_tau_sector") sheetreplace firstrow(variables)

* C3. Por subpartida, ultimo anio disponible
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Importaciones" & tipo=="fob" & partner=="PAN" & petro=="No Petrolero"
keep if anio==$T1
collapse (sum) valor (firstnm) descripcion, by(registro hs6)
replace valor = valor/1e6
reshape wide valor, i(hs6 descripcion) j(registro) string
foreach v of varlist valororigen valorprocedencia {
    replace `v' = 0 if missing(`v')
}
gen double tau = 1 - valororigen/valorprocedencia if valorprocedencia>0
gsort -valorprocedencia
export excel using "`xls'", sheet("C3_tau_hs6") sheetreplace firstrow(variables)

di as txt "-- Subpartidas con tau negativo (origen > procedencia), origen > 0.3 M --"
list hs6 descripcion valororigen valorprocedencia tau ///
     if valororigen > 0.3 & valororigen > valorprocedencia, noobs

* Cuanto pesan esas partidas en el total de origen panameno
qui summ valororigen, meanonly
local tot = r(sum)
qui summ valororigen if valororigen > valorprocedencia, meanonly
di as result "Partidas con tau<0: " %5.2f r(sum) " M de " %5.2f `tot' " M (" %4.1f 100*r(sum)/`tot' "%)"

di as result "== 02_canales.xlsx generado =="
clear all

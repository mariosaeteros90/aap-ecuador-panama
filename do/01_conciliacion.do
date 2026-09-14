*==============================================================
* 01. CONCILIACION
* Reproduce las cifras publicas y deja explicito cada recorte.
* Salida: resultados/01_conciliacion.xlsx
*==============================================================
clear all
local xls "$out/01_conciliacion.xlsx"
cap erase "`xls'"

*--------------------------------------------------------------
* A. EXPORTACIONES DEL ECUADOR (FOB)
*--------------------------------------------------------------
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Exportaciones" & tipo=="fob"
gen str8 cap98 = cond(c98==1,"HS98","Resto")
collapse (sum) valor, by(partner petro cap98 anio)
replace valor = valor/1e6
reshape wide valor, i(partner petro cap98) j(anio)
sort partner petro cap98
export excel using "`xls'", sheet("A_export_ecu") sheetreplace firstrow(variables)

* Participacion de Panama en las exportaciones ecuatorianas
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Exportaciones" & tipo=="fob"
collapse (sum) valor, by(partner petro anio)
reshape wide valor, i(petro anio) j(partner) string
gen double share_pan = 100*valorPAN/valorWLD
replace valorPAN = valorPAN/1e6
replace valorWLD = valorWLD/1e6
sort petro anio
export excel using "`xls'", sheet("A_share_pan") sheetreplace firstrow(variables)

*--------------------------------------------------------------
* B. IMPORTACIONES DEL ECUADOR
*    Universo A = origen (base de una preferencia arancelaria)
*    Universo B = procedencia (flujo logistico)
*--------------------------------------------------------------
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Importaciones"
gen str8 cap98 = cond(c98==1,"HS98","Resto")
collapse (sum) valor, by(partner registro tipo petro cap98 anio)
replace valor = valor/1e6
reshape wide valor, i(partner registro tipo petro cap98) j(anio)
sort partner registro tipo petro cap98
export excel using "`xls'", sheet("B_import_ecu") sheetreplace firstrow(variables)

* Identidad de control: al nivel mundo, el total por origen y el total
* por procedencia deben coincidir, porque ambos registros reparten las
* mismas transacciones entre paises. Si no coinciden, hay un problema
* de cobertura y hay que saberlo antes de interpretar la cuna.
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Importaciones" & partner=="WLD" & tipo=="fob"
qui count
if r(N)==0 {
    di as txt "== Importaciones ECU-mundo aun no cargadas: prueba omitida =="
}
else {
    collapse (sum) valor, by(registro anio)
    replace valor = valor/1e6
    reshape wide valor, i(anio) j(registro) string
    gen double dif_pct = 100*(valorprocedencia - valororigen)/valororigen
    list, noobs
    export excel using "`xls'", sheet("B_identidad") sheetreplace firstrow(variables)
}

* Peso de Panama en el abastecimiento ecuatoriano, en cada universo
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Importaciones" & tipo=="fob"
qui count if partner=="WLD"
if r(N)==0 {
    di as txt "== Sin mundo: participaciones de importacion omitidas =="
}
else {
    collapse (sum) valor, by(partner registro petro anio)
    reshape wide valor, i(registro petro anio) j(partner) string
    gen double share_pan = 100*valorPAN/valorWLD
    replace valorPAN = valorPAN/1e6
    replace valorWLD = valorWLD/1e6
    sort registro petro anio
    export excel using "`xls'", sheet("B_share_pan") sheetreplace firstrow(variables)
}

*--------------------------------------------------------------
* C. ESPEJO: registro ecuatoriano contra registro panameno
*--------------------------------------------------------------
* C1. Lo que Ecuador dice exportar contra lo que Panama dice importar
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Exportaciones" & tipo=="fob" & partner=="PAN"
collapse (sum) v_ecu_exporta=valor, by(petro hs2 anio)

tempfile ecux
save `ecux'

use "$aux/db_pan_clean.dta", clear
keep if inlist(flujo,"Importaciones","Importaciones ZLC")
replace petro = "No Petrolero" if petro=="No Petrolero (imputado)"
collapse (sum) v_pan_importa=valor, by(petro hs2 anio)
merge 1:1 petro hs2 anio using `ecux', nogen
foreach v of varlist v_* {
    replace `v' = 0 if missing(`v')
    replace `v' = `v'/1e6
}
gen double ratio = v_ecu_exporta/v_pan_importa if v_pan_importa>0
gen double brecha = v_ecu_exporta - v_pan_importa
gsort anio -brecha
export excel using "`xls'", sheet("C1_espejo_x") sheetreplace firstrow(variables)

* C2. Lo que Panama dice enviar contra lo que Ecuador dice recibir
use "$aux/db_pan_clean.dta", clear
keep if inlist(flujo,"Exportaciones","Reexportaciones","Reexportacion ZLC")
collapse (sum) valor, by(flujo hs2 anio)
replace valor = valor/1e6
replace flujo = "Reexportacion_ZLC" if flujo == "Reexportacion ZLC"
reshape wide valor, i(hs2 anio) j(flujo) string
tempfile panx
save `panx'

use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Importaciones" & tipo=="fob" & partner=="PAN"
collapse (sum) valor, by(registro hs2 anio)
replace valor = valor/1e6
reshape wide valor, i(hs2 anio) j(registro) string
merge 1:1 hs2 anio using `panx', nogen
foreach v of varlist valor* {
    replace `v' = 0 if missing(`v')
}
gsort anio -valorprocedencia
export excel using "`xls'", sheet("C2_espejo_m") sheetreplace firstrow(variables)

di as result "== 01_conciliacion.xlsx generado =="
clear all

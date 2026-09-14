*==============================================================
* 05. DINAMICA: MARGENES, PARTICIPACION CONSTANTE DE MERCADO
*     Y SUPERVIVENCIA CON CONTRAFACTUAL
* Salida: resultados/05_dinamica.xlsx
*==============================================================
clear all

run "$cod/_rutinas.do"   // clear all borra los programas; hay que recargarlos
local xls "$out/05_dinamica.xlsx"
cap erase "`xls'"

*--------------------------------------------------------------
* A. Margenes intensivo y extensivo, con sensibilidad al umbral
*    La contribucion de cada categoria es el delta de valor, de
*    modo que las tres suman exactamente el cambio total.
*--------------------------------------------------------------
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Exportaciones" & tipo=="fob" & partner=="PAN" & petro=="No Petrolero"
keep anio hs6 valor
tempfile xpan
save `xpan'

local primero = 1
tempfile acum
foreach u of global UMBRALES {
    tempfile r
    r_margenes, in(`xpan') t0($T0) t1($T1) umbral(`u') out(`r')
    use `r', clear
    if `primero' {
        save `acum', replace
        local primero = 0
    }
    else {
        append using `acum'
        save `acum', replace
    }
}
use `acum', clear
sort umbral categoria
export excel using "`xls'", sheet("A_margenes") sheetreplace firstrow(variables)
list umbral categoria n v0 v1 contrib share, noobs sepby(umbral)

di as txt "-- Lectura: si 'share' de la categoria Nuevos cambia mucho entre umbrales,"
di as txt "   la descomposicion no es un resultado publicable sin declarar el umbral. --"

*--------------------------------------------------------------
* B. Participacion constante de mercado
*    delta X hacia Panama = escala + composicion + competitividad + nuevos
*--------------------------------------------------------------
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Exportaciones" & tipo=="fob" & petro=="No Petrolero"
keep if inlist(partner,"PAN","WLD")
gen str3 mercado = partner
keep anio hs6 mercado valor
tempfile cmsin
save `cmsin'

local primero = 1
tempfile cmsac
foreach par in "$T0 $T1" "$T0 $TANCLA" "$TANCLA $T1" {
    local a : word 1 of `par'
    local b : word 2 of `par'
    tempfile r
    r_cms, in(`cmsin') t0(`a') t1(`b') out(`r')
    use `r', clear
    if `primero' {
        save `cmsac', replace
        local primero = 0
    }
    else {
        append using `cmsac'
        save `cmsac', replace
    }
}
use `cmsac', clear
order t0 t1 delta e_escala e_compos e_compet e_nuevos residuo
sort t0 t1
export excel using "`xls'", sheet("B_cms") sheetreplace firstrow(variables)
list, noobs

di as txt "-- e_escala: cuanto habria crecido Panama si solo hubiera acompanado"
di as txt "   el crecimiento exportador del Ecuador al mundo."
di as txt "   e_compos: sesgo de la canasta hacia productos mas o menos dinamicos."
di as txt "   e_compet: ganancia o perdida especifica en el mercado panameno. --"

*--------------------------------------------------------------
* C. Supervivencia de subpartidas nuevas, Panama contra el mundo
*    El contrafactual es imprescindible: las relaciones comerciales
*    nuevas mueren mucho en todos los destinos.
*--------------------------------------------------------------
local primero = 1
tempfile svac
foreach u in 0 10000 {
  foreach mkt in PAN WLD {
    use "$aux/db_ecu_clean.dta", clear
    keep if flujo=="Exportaciones" & tipo=="fob" & partner=="`mkt'" & petro=="No Petrolero"
    keep anio hs6 valor
    tempfile sv
    save `sv'
    foreach coh in 2022 2023 {
        tempfile r
        r_superv, in(`sv') cohorte(`coh') ymin($T0) ymax($T1) umbral(`u') out(`r')
        use `r', clear
        gen str3 mercado = "`mkt'"
        gen double umbral = `u'
        if `primero' {
            save `svac', replace
            local primero = 0
        }
        else {
            append using `svac'
            save `svac', replace
        }
    }
  }
}
use `svac', clear
bysort umbral mercado cohorte (anio): gen double n_inicial = n_vivas[1]
gen double tasa = 100*n_vivas/n_inicial
order umbral mercado cohorte anio n_vivas n_inicial tasa valor_musd
sort umbral mercado cohorte anio
export excel using "`xls'", sheet("C_supervivencia") sheetreplace firstrow(variables)
list if anio==$T1, noobs sepby(umbral)

di as txt "-- Comparar PAN contra WLD dentro de cada umbral. Si la brecha desaparece"
di as txt "   al subir el umbral, la mortalidad extra esta en operaciones minimas. --"

di as result "== 05_dinamica.xlsx generado =="
clear all

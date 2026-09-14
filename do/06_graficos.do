*==============================================================
* 06. GRAFICOS
* Prefijo g: diagnostico, para leer resultados rapido.
* Prefijo p: publicacion.
* Salida: resultados/graficos/XXXXX.png
*==============================================================
clear all

run "$cod/_rutinas.do"   // clear all borra los programas; hay que recargarlos
cap mkdir "$out/graficos"

*--------------------------------------------------------------
* G1. Participacion de Panama, origen contra procedencia
*--------------------------------------------------------------
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Importaciones" & tipo=="fob"
collapse (sum) valor, by(partner registro petro anio)
reshape wide valor, i(registro petro anio) j(partner) string
gen double share = 100*valorPAN/valorWLD
keep registro petro anio share
reshape wide share, i(petro anio) j(registro) string
label var shareorigen      "Pais de origen"
label var shareprocedencia "Pais de procedencia"

twoway (connected shareprocedencia anio, lwidth(medthick) msymbol(O)) ///
       (connected shareorigen      anio, lwidth(medthick) msymbol(O)) ///
       , by(petro, yrescale note("") ///
            title("Participacion de Panama en las importaciones del Ecuador", size(medium)) ///
            subtitle("Segun registro aduanero. FOB.", size(small))) ///
         ytitle("% de las importaciones ecuatorianas") xtitle("") ///
         xlabel($T0(1)$T1) legend(order(1 "Procedencia" 2 "Origen") rows(1) region(lstyle(none))) ///
         graphregion(color(white)) plotregion(color(white))
graph export "$out/graficos/g1_share_panama.png", replace width(1600)

*--------------------------------------------------------------
* G2. Participacion de reexportacion por sector, ultimo anio
*--------------------------------------------------------------
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Importaciones" & tipo=="fob" & partner=="PAN" & petro=="No Petrolero"
keep if anio==$T1
collapse (sum) valor, by(registro sector)
reshape wide valor, i(sector) j(registro) string
foreach v of varlist valororigen valorprocedencia {
    replace `v' = 0 if missing(`v')
}
gen double tau = 1 - valororigen/valorprocedencia if valorprocedencia>0
drop if missing(tau)
graph hbar (asis) tau, over(sector, sort(tau) label(labsize(vsmall))) ///
      title("Participacion de reexportacion por sector, $T1", size(medium)) ///
      subtitle("tau = 1 - origen/procedencia. 1 = reexportacion pura.", size(small)) ///
      ytitle("") graphregion(color(white))
graph export "$out/graficos/g2_tau_sector.png", replace width(1600)

*--------------------------------------------------------------
* G3. Sensibilidad de la descomposicion de margenes
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
graph bar (asis) contrib, over(categoria, label(labsize(vsmall))) ///
      over(umbral, label(labsize(small))) asyvars ///
      title("Descomposicion del cambio $T0-$T1 segun umbral de presencia", size(small)) ///
      subtitle("Exportaciones no petroleras a Panama, USD millones", size(small)) ///
      ytitle("") legend(rows(1)) graphregion(color(white))
graph export "$out/graficos/g3_margenes_sensibilidad.png", replace width(1600)

*--------------------------------------------------------------
* G4. Supervivencia, Panama contra el mundo
*--------------------------------------------------------------
local primero = 1
tempfile svac
foreach mkt in PAN WLD {
    use "$aux/db_ecu_clean.dta", clear
    keep if flujo=="Exportaciones" & tipo=="fob" & partner=="`mkt'" & petro=="No Petrolero"
    keep anio hs6 valor
    tempfile sv
    save `sv'
    tempfile r
    r_superv, in(`sv') cohorte(2022) ymin($T0) ymax($T1) umbral(10000) out(`r')
    use `r', clear
    gen str3 mercado = "`mkt'"
    if `primero' {
        save `svac', replace
        local primero = 0
    }
    else {
        append using `svac'
        save `svac', replace
    }
}
use `svac', clear
bysort mercado (anio): gen double tasa = 100*n_vivas/n_vivas[1]
encode mercado, gen(mkt)
twoway (connected tasa anio if mkt==1, lwidth(medthick)) ///
       (connected tasa anio if mkt==2, lwidth(medthick)) ///
       , title("Supervivencia de subpartidas que entraron en 2022", size(medium)) ///
         subtitle("Umbral 10.000 USD. Base 100 en el año de entrada.", size(small)) ///
         ytitle("% de las subpartidas de la cohorte") xtitle("") ///
         legend(order(1 "Panama" 2 "Mundo") rows(1) region(lstyle(none))) ///
         graphregion(color(white)) plotregion(color(white))
graph export "$out/graficos/g4_supervivencia.png", replace width(1600)

di as result "== graficos generados en $out/graficos =="
clear
run "$cod/_rutinas.do"   // clear all borra los programas; hay que recargarlos

*==============================================================
* GRAFICOS DE PUBLICACION
* Salen a resultados/graficos con prefijo p.
* Paleta: azul 42 120 214, naranja 235 104 52, rojo 227 73 72.
*==============================================================
local AZUL    "42 120 214"
local NARANJA "235 104 52"
local ROJO    "227 73 72"
local GRIS    "82 81 78"

*--------------------------------------------------------------
* P1. Balanza no petrolera con Panama, año por año
*     Universo de origen, que es el de la cifra oficial.
*--------------------------------------------------------------
use "$aux/db_ecu_clean.dta", clear
keep if tipo=="fob" & partner=="PAN" & petro=="No Petrolero"
keep if flujo=="Exportaciones" | (flujo=="Importaciones" & registro=="origen")
gen str1 f = cond(flujo=="Exportaciones","x","m")
collapse (sum) valor, by(f anio)
replace valor = valor/1e6
reshape wide valor, i(anio) j(f) string
gen double saldo = valorx - valorm
gen double idx   = anio - $T0 + 1
gen double px    = idx - 0.20
gen double pm    = idx + 0.20
gen double ytop  = max(valorx, valorm) + 13
gen str12 lsaldo = cond(saldo>=0,"+","-") + string(abs(saldo),"%4.1f")
gen str8  lx     = string(valorx,"%4.1f")
gen str8  lm     = string(valorm,"%4.1f")

twoway (bar valorx px, barwidth(0.38) color("`AZUL'")) ///
       (bar valorm pm, barwidth(0.38) color("`NARANJA'")) ///
       (scatter valorx px, msymbol(none) mlabel(lx) mlabpos(12) mlabsize(small) mlabcolor(black)) ///
       (scatter valorm pm, msymbol(none) mlabel(lm) mlabpos(12) mlabsize(small) mlabcolor(black)) ///
       (scatter ytop idx, msymbol(none) mlabel(lsaldo) mlabpos(0) mlabsize(medium) mlabcolor("`AZUL'")) ///
     , legend(order(1 "Exportaciones" 2 "Importaciones") rows(1) pos(12) ring(1) region(lstyle(none))) ///
       title("La balanza no petrolera con Panama, año por año", size(medium) pos(11) span) ///
       subtitle("Millones de dólares FOB. Importaciones por pais de origen." ///
                "Sobre cada par, el saldo.", size(small) pos(11) span) ///
       xlabel(1 "2021" 2 "2022" 3 "2023" 4 "2024" 5 "2025", noticks labsize(small)) ///
       xscale(range(0.4 5.6)) xtitle("") ///
       ylabel(0(25)125, angle(0) labsize(small) grid glcolor(gs14) glwidth(vthin)) ///
       yscale(range(0 150)) ytitle("") ///
       note("Fuente: Banco Central del Ecuador. Calculos propios.", size(vsmall)) ///
       graphregion(color(white)) plotregion(color(white) margin(zero))
graph export "$out/graficos/p1_balanza_no_petrolera.png", replace width(1600)

*--------------------------------------------------------------
* P2. Balanza sectorial no petrolera, ultimo año
*     Barras divergentes: azul superavit, rojo deficit.
*--------------------------------------------------------------
use "$aux/db_ecu_clean.dta", clear
keep if tipo=="fob" & partner=="PAN" & petro=="No Petrolero" & anio==$T1
keep if flujo=="Exportaciones" | (flujo=="Importaciones" & registro=="origen")
gen str1 f = cond(flujo=="Exportaciones","x","m")
collapse (sum) valor, by(f sector)
replace valor = valor/1e6
reshape wide valor, i(sector) j(f) string
foreach v of varlist valorx valorm {
    replace `v' = 0 if missing(`v')
}
* Los sectores con menos de 300 mil dolares de comercio bilateral no
* caben en la escala. Se omiten, pero se imprimen antes para que la
* omision quede registrada y se pueda citar en el pie del grafico.
qui levelsof sector if (valorx + valorm) < 0.3, local(fuera) clean
di as txt "Omitidos del grafico por tamano: `fuera'"
drop if (valorx + valorm) < 0.3
gen double bal = valorx - valorm
gsort bal
gen int    idx  = _n
gen double cero = 0
gen double pos  = bal if bal >= 0
gen double neg  = bal if bal <  0

* etiquetas del eje construidas desde los datos
local yl ""
forvalues i = 1/`=_N' {
    local s = sector[`i']
    local yl `yl' `i' "`s'"
}

twoway (rbar cero pos idx, horizontal barwidth(0.62) color("`AZUL'")) ///
       (rbar cero neg idx, horizontal barwidth(0.62) color("`ROJO'")) ///
     , legend(order(1 "Superavit" 2 "Deficit") rows(1) pos(12) ring(1) region(lstyle(none))) ///
       title("Que le vendemos y que le compramos a Panama", size(medium) pos(11) span) ///
       subtitle("Balanza sectorial no petrolera, $T1, millones de dólares." ///
                "Importaciones por pais de origen.", size(small) pos(11) span) ///
       ylabel(`yl', angle(0) labsize(small) noticks) ytitle("") ///
       xlabel(-30(10)30, labsize(small) grid glcolor(gs14) glwidth(vthin)) xtitle("") ///
       xline(0, lcolor(gs9) lwidth(thin)) ///
       note("Fuente: Banco Central del Ecuador. Calculos propios.", size(vsmall)) ///
       graphregion(color(white)) plotregion(color(white))
graph export "$out/graficos/p2_balanza_sector.png", replace width(1600)

*--------------------------------------------------------------
* P3. Tasa de cobertura sectorial
*     Cuantos dólares exporta Ecuador por cada dólar que importa.
*     Se grafican los niveles y la razon va como cifra, para no
*     necesitar escala logaritmica: alimentos da 33,8 y aplastaria
*     al resto contra el cero.
*--------------------------------------------------------------
gen double cobertura = valorx/valorm if valorm > 0
drop if missing(cobertura)
gsort cobertura
drop idx
gen int    idx = _n
gen double pxx = idx + 0.20
gen double pmm = idx - 0.20
qui summ valorm
local xmax = r(max)*1.28
gen double xlab = `xmax'*0.94
gen str10 lcob = cond(cobertura < 1, string(cobertura,"%4.2f"), string(cobertura,"%4.1f"))

local yl2 ""
forvalues i = 1/`=_N' {
    local s = sector[`i']
    local yl2 `yl2' `i' "`s'"
}

twoway (rbar cero valorx pxx, horizontal barwidth(0.34) color("`AZUL'")) ///
       (rbar cero valorm pmm, horizontal barwidth(0.34) color("`NARANJA'")) ///
       (scatter idx xlab, msymbol(none) mlabel(lcob) mlabpos(0) ///
                mlabsize(medium) mlabcolor("`GRIS'")) ///
     , legend(order(1 "Exportaciones" 2 "Importaciones") rows(1) pos(12) ring(1) region(lstyle(none))) ///
       title("Por cada dólar que le compramos a Panama, cuanto le vendemos", size(medium) pos(11) span) ///
       subtitle("Millones de dólares, $T1. La cifra de la derecha es la tasa de cobertura," ///
                "exportaciones sobre importaciones.", size(small) pos(11) span) ///
       ylabel(`yl2', angle(0) labsize(small) noticks) ytitle("") ///
       xlabel(0(10)30, labsize(small) grid glcolor(gs14) glwidth(vthin)) xtitle("") ///
       xscale(range(0 `xmax')) ///
       note("Fuente: Banco Central del Ecuador. Calculos propios.", size(vsmall)) ///
       graphregion(color(white)) plotregion(color(white))
graph export "$out/graficos/p3_cobertura_sector.png", replace width(1600)

* Aqui no va clear all: P6 y P7 necesitan las rutinas.

*--------------------------------------------------------------
* P5. Origen contra procedencia por sector, ultimo año
*     Escala lineal compartida: las barras de origen quedan
*     pequenas y esa es la comparacion que interesa.
*--------------------------------------------------------------
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Importaciones" & tipo=="fob" & partner=="PAN" & petro=="No Petrolero" & anio==$T1
collapse (sum) valor, by(registro sector)
replace valor = valor/1e6
reshape wide valor, i(sector) j(registro) string
foreach v of varlist valororigen valorprocedencia {
    replace `v' = 0 if missing(`v')
}
drop if (valororigen + valorprocedencia) < 2
gsort valorprocedencia
gen int    idx  = _n
gen double cero = 0
gen double pidx = idx + 0.20
gen double oidx = idx - 0.20
local yl ""
forvalues i = 1/`=_N' {
    local s = sector[`i']
    local yl `yl' `i' "`s'"
}
twoway (rbar cero valorprocedencia pidx, horizontal barwidth(0.34) color("`NARANJA'")) ///
       (rbar cero valororigen      oidx, horizontal barwidth(0.34) color("`AZUL'")) ///
     , legend(order(1 "Despachado desde Panama" 2 "Producido en Panama") rows(1) pos(12) ring(1) region(lstyle(none))) ///
       title("Lo que llega desde Panama no es panameno", size(medium) pos(11) span) ///
       subtitle("Importaciones no petroleras por sector, $T1, millones de dólares", size(small) pos(11) span) ///
       ylabel(`yl', angle(0) labsize(small) noticks) ytitle("") ///
       xlabel(0(50)250, labsize(small) grid glcolor(gs14) glwidth(vthin)) xtitle("") ///
       note("Fuente: Banco Central del Ecuador. Calculos propios.", size(vsmall)) ///
       graphregion(color(white)) plotregion(color(white))
graph export "$out/graficos/p5_origen_procedencia_sector.png", replace width(1600)

*--------------------------------------------------------------
* P6. De donde vino el crecimiento, por umbral de presencia
*--------------------------------------------------------------
use "$aux/db_ecu_clean.dta", clear
keep if flujo=="Exportaciones" & tipo=="fob" & partner=="PAN" & petro=="No Petrolero"
keep anio hs6 valor
tempfile xpan
save `xpan'
local primero = 1
tempfile acum2
foreach u of global UMBRALES {
    tempfile r
    r_margenes, in(`xpan') t0($T0) t1($T1) umbral(`u') out(`r')
    use `r', clear
    if `primero' {
        save `acum2', replace
        local primero = 0
    }
    else {
        append using `acum2'
        save `acum2', replace
    }
}
use `acum2', clear
keep if inlist(categoria,"1 Intensivo","2 Nuevos")
gen byte nuevo = (categoria=="2 Nuevos")
drop categoria
reshape wide contrib n v0 v1 share, i(umbral) j(nuevo)
gsort umbral
gen int idx = _n
gen double pi = idx - 0.20
gen double pn = idx + 0.20
gen str12 lu = cond(umbral==0,"sin umbral",string(umbral,"%9.0fc"))
local xl ""
forvalues i = 1/`=_N' {
    local s = lu[`i']
    local xl `xl' `i' "`s'"
}
twoway (bar contrib0 pi, barwidth(0.36) color("`AZUL'")) ///
       (bar contrib1 pn, barwidth(0.36) color("`NARANJA'")) ///
       (scatter contrib0 pi, msymbol(none) mlabel(contrib0) mlabformat(%4.1f) mlabpos(12) mlabsize(small) mlabcolor(black)) ///
       (scatter contrib1 pn, msymbol(none) mlabel(contrib1) mlabformat(%4.1f) mlabpos(12) mlabsize(small) mlabcolor(black)) ///
     , legend(order(1 "Productos que ya se exportaban" 2 "Productos nuevos") rows(1) pos(12) ring(1) region(lstyle(none))) ///
       title("De donde vino el crecimiento de las exportaciones a Panama", size(medium) pos(11) span) ///
       subtitle("Aporte al aumento entre $T0 y $T1, millones de dólares," ///
                "segun el umbral anual usado para definir presencia en el año base", size(small) pos(11) span) ///
       xlabel(`xl', noticks labsize(small)) xtitle("") xscale(range(0.4 5.6)) ///
       ylabel(0(10)50, angle(0) labsize(small) grid glcolor(gs14) glwidth(vthin)) ytitle("") ///
       note("Fuente: Banco Central del Ecuador. Calculos propios.", size(vsmall)) ///
       graphregion(color(white)) plotregion(color(white))
graph export "$out/graficos/p6_margenes_umbral.png", replace width(1600)

*--------------------------------------------------------------
* P7. Supervivencia de la cohorte 2022 contra el resto del mundo
*--------------------------------------------------------------
local primero = 1
tempfile svac2
foreach mkt in PAN WLD {
    use "$aux/db_ecu_clean.dta", clear
    keep if flujo=="Exportaciones" & tipo=="fob" & partner=="`mkt'" & petro=="No Petrolero"
    keep anio hs6 valor
    tempfile sv
    save `sv'
    tempfile r
    r_superv, in(`sv') cohorte(2022) ymin($T0) ymax($T1) umbral(10000) out(`r')
    use `r', clear
    gen str3 mercado = "`mkt'"
    if `primero' {
        save `svac2', replace
        local primero = 0
    }
    else {
        append using `svac2'
        save `svac2', replace
    }
}
use `svac2', clear
bysort mercado (anio): gen double tasa = 100*n_vivas/n_vivas[1]
gen byte mk = (mercado=="WLD")
twoway (connected tasa anio if mk==0, lwidth(medthick) color("`AZUL'") msymbol(O) mcolor("`AZUL'")) ///
       (connected tasa anio if mk==1, lwidth(medthick) color("`NARANJA'") msymbol(O) mcolor("`NARANJA'")) ///
     , legend(order(1 "A Panama" 2 "Al resto del mundo") rows(1) pos(12) ring(1) region(lstyle(none))) ///
       title("Entrar no es el problema. Quedarse si", size(medium) pos(11) span) ///
       subtitle("Supervivencia de las subpartidas que entraron en 2022 con ventas sobre diez mil dólares." ///
                "Base 100 en el año de entrada.", size(small) pos(11) span) ///
       ylabel(0(25)100, angle(0) labsize(small) grid glcolor(gs14) glwidth(vthin)) ytitle("") ///
       xlabel(2022(1)$T1, noticks labsize(small)) xtitle("") ///
       note("Fuente: Banco Central del Ecuador. Calculos propios.", size(vsmall)) ///
       graphregion(color(white)) plotregion(color(white))
graph export "$out/graficos/p7_supervivencia.png", replace width(1600)

*--------------------------------------------------------------
* P8. Asimetria de la plataforma, registro panameno
*--------------------------------------------------------------
use "$aux/db_pan_clean.dta", clear
keep if hs2 != "27" & anio == $T1PAN
gen str20 direccion = ""
replace direccion = "De Panama a Ecuador" if inlist(flujo,"Exportaciones","Reexportaciones","Reexportacion ZLC")
replace direccion = "De Ecuador a Panama" if inlist(flujo,"Importaciones","Importaciones ZLC")
drop if direccion==""
gen byte zonalibre = inlist(flujo,"Reexportacion ZLC","Importaciones ZLC")
collapse (sum) valor, by(direccion zonalibre)
bysort direccion: egen double tot = total(valor)
gen double share = 100*valor/tot
keep direccion zonalibre share
reshape wide share, i(direccion) j(zonalibre)
gen int idx = _n
gen double cero = 0
gen double cien = 100
local yl3 ""
forvalues i = 1/`=_N' {
    local s = direccion[`i']
    local yl3 `yl3' `i' "`s'"
}
twoway (rbar cero cien idx, horizontal barwidth(0.42) color("`AZUL'")) ///
       (rbar cero share1 idx, horizontal barwidth(0.42) color("`NARANJA'")) ///
       (scatter idx share1, msymbol(none) mlabel(share1) mlabformat(%3.0f) mlabpos(9) mlabsize(medium) mlabcolor(white)) ///
     , legend(order(2 "Zona Libre de Colon" 1 "Comercio regular") rows(1) pos(12) ring(1) region(lstyle(none))) ///
       title("La plataforma funciona en un solo sentido", size(medium) pos(11) span) ///
       subtitle("Comercio no petrolero en $T1PAN segun el registro panameno." ///
                "Reparto de cada flujo entre Zona Libre y comercio regular, en porcentaje.", size(small) pos(11) span) ///
       ylabel(`yl3', angle(0) labsize(small) noticks) ytitle("") ///
       xlabel(0(25)100, labsize(small)) xtitle("") ///
       note("Fuente: Instituto Nacional de Estadistica y Censo de Panama. Calculos propios.", size(vsmall)) ///
       graphregion(color(white)) plotregion(color(white))
graph export "$out/graficos/p8_asimetria_plataforma.png", replace width(1600)

di as result "== graficos de publicacion P1 a P8 generados =="
clear all
